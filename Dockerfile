# Systemic Console 2 (Meschiari) — reproducible Docker image with a browser desktop.
#
# Builds everything from THIS repository's own source (no external distribution
# tarball needed): the C library libsystemic.so is compiled here, and the prebuilt
# SystemicGui.jar + lib/*.jar + datafiles/ already live in the repo.
#
# The repo source already carries the gd.o fix (issue #19), the X/Y/Z #define move
# (issue #23), and the -std=gnu99 strdup fix in Makefile.linux — so no source
# patching happens in this Dockerfile. (The strdup fix is what makes it run on
# Apple Silicon under emulation and on native arm64; -std=c99 truncates strdup's
# 64-bit pointer and segfaults on the 2nd dataset load.)
#
# Build:  docker build --platform linux/amd64 -t systemic:2.2000 .
# Run:    docker run --rm -p 8080:8080 systemic:2.2000
#         then open http://localhost:8080/vnc.html  (no password)
#
# fedora:26 is EOL but its dnf repos still resolve, and it is the environment the
# old C/R/Java stack is known to build on. Pinned deliberately.
FROM fedora:26

# --- build toolchain + R + Java + browser-display stack, in one layer ---
RUN dnf -y install \
      java-1.8.0-openjdk-devel R-core R-devel \
      gcc gcc-gfortran gsl-devel make patch which tar findutils \
      R-reshape2 R-stringi R-htmltools R-rmarkdown R-markdown R-gplots R-rlang R-mvtnorm \
      xorg-x11-server-Xvfb x11vnc novnc python2-websockify python2-numpy \
      net-tools procps-ng \
      dejavu-sans-fonts dejavu-sans-mono-fonts dejavu-serif-fonts \
 && dnf clean all

# --- full XFCE desktop (panel, Thunar file manager, terminal, right-click menu) ---
# Gives a real browser desktop so data goes in/out via Thunar instead of the VNC clipboard.
RUN dnf -y install \
      xfce4-session xfwm4 xfce4-panel xfdesktop xfce4-settings xfce4-terminal Thunar dbus-x11 \
 && dnf clean all

# Systemic launcher + autostart on login + an entry in the XFCE applications menu
RUN printf '#!/bin/bash\ncd /opt/Systemic\nLD_LIBRARY_PATH=/opt/Systemic exec java -Xmx1g -Dswing.defaultlaf=com.sun.java.swing.plaf.nimbus.NimbusLookAndFeel -jar SystemicGui.jar "$@"\n' > /usr/local/bin/systemic \
 && chmod +x /usr/local/bin/systemic \
 && printf '[Desktop Entry]\nType=Application\nName=Systemic Console\nComment=Exoplanet radial-velocity fitting\nExec=/usr/local/bin/systemic\nIcon=applications-science\nTerminal=false\nCategories=Science;Education;\n' > /usr/share/applications/systemic.desktop \
 && mkdir -p /etc/xdg/autostart \
 && cp /usr/share/applications/systemic.desktop /etc/xdg/autostart/systemic.desktop \
 && dbus-uuidgen > /etc/machine-id

# --- R binding: rdyncall (done before copying source, so it stays cached) ---
# The GUI's embedded R kernel loads rdyncall to bind libsystemic. The bundled
# R/rdyncall_0.7.5.tgz is a macOS binary (useless on Linux) and CRAN dropped the
# package, so build 0.7.5 from the CRAN archive source (compiles clean on F26 / R 3.4).
#
# On arm64, rdyncall 0.7.5's bundled dyncall (v0.8) has no aarch64 call backend,
# so swap in dyncall 1.4 (which does) before installing. It is API-compatible:
# rdyncall only uses dcNewCallVM/dcArg*/dcCall*, and struct handling lives in
# rpack.c. BuildKit sets TARGETARCH automatically per --platform.
ARG TARGETARCH
ADD https://cran.r-project.org/src/contrib/Archive/rdyncall/rdyncall_0.7.5.tar.gz /tmp/rdyncall.tar.gz
ADD https://dyncall.org/r1.4/dyncall-1.4.tar.gz /tmp/dyncall-1.4.tar.gz
RUN cd /tmp && tar xzf rdyncall.tar.gz \
 && if [ "$TARGETARCH" = "arm64" ]; then \
      echo ">> arm64 build: swapping rdyncall's bundled dyncall for v1.4 (aarch64 support)"; \
      tar xzf dyncall-1.4.tar.gz && rm -rf rdyncall/src/dyncall/* && cp -r dyncall-1.4/* rdyncall/src/dyncall/; \
    fi \
 && R CMD INSTALL rdyncall \
 && R --vanilla --slave -e 'library(rdyncall)' \
 && rm -rf /tmp/rdyncall* /tmp/dyncall-1.4*

# --- remaining console packages from a pinned 2018 CRAN snapshot (also cached) ---
COPY docker/install_r_pkgs.R /tmp/
RUN R --vanilla --slave -f /tmp/install_r_pkgs.R && rm -f /tmp/install_r_pkgs.R

# --- the repo itself: source + SystemicGui.jar + lib/*.jar + datafiles/ ---
COPY . /opt/Systemic
WORKDIR /opt/Systemic

# --- compile libsystemic.so from this repo's source ---
# Drop stale object files / macOS binaries that COPY carried in, so make rebuilds
# for the image's architecture.
#
# CRITICAL: scrub ALL committed/stale build artifacts (*.o, *.a) under deps/ so f2c
# and swift rebuild fully from their .c/.f source for the image's own architecture.
#
# Why: the repo (and deps.tar.gz) ship prebuilt deps/f2c/*.o + deps/f2c/libf2c.a and
# deps/swift/**/*.o + libswift.a. The repo's committed libf2c.a is INCOMPLETE — built
# from a subset of sources, so it lacks s_wsfe (the Fortran formatted-I/O runtime).
# Makefile.linux's `./deps/lib/libf2c.a:` rule runs `cd deps/f2c; make -f makefile.u`,
# but makefile.u sees the stale .o/.a as up to date ("Nothing to be done") and just
# copies the incomplete libf2c.a. libsystemic then links (-shared defers undefined
# symbols) but fails at dlopen with "undefined symbol: s_wsfe" on EVERY arch. Deleting
# the stale .o/.a forces a true from-source compile (wsfe.c etc. are present), yielding
# a complete libf2c.a — and builds swift/f2c natively on arm64 too.
# Skip install.r (dead CRAN rdyncall) via the sentinel.
RUN tar xzf deps.tar.gz \
 && find deps -name '*.o' -delete \
 && rm -f deps/lib/*.a deps/f2c/libf2c.a $(find deps/swift -name 'libswift.a') \
 && mkdir -p objects \
 && rm -f objects/*.o libsystemic.so libsystemic.dylib R/libsystemic.so R/libsystemic.dylib \
 && touch R_packages_installed \
 && make -f Makefile.linux linux \
 && test -f libsystemic.so \
 && ( ! nm -D libsystemic.so 2>/dev/null | grep -q ' U \(s_wsfe\|whm_\|rmvs\)' || (echo "FATAL: unresolved f2c/swift symbols in libsystemic.so" && exit 1) )

RUN cp docker/entrypoint.sh /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

ENV SCREEN=1920x1080x24 PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
