# Systemic 2 #
Systemic 2 is a C library for analyzing exoplanetary time series. The full distribution of Systemic also includes an R package to interface with the library, and a cross-platform GUI to perform interactive analysis.

**Try it online (no install):** https://www.stefanom.org/systemic-online/

## Run in Docker (browser GUI) ##

The recommended way to run Systemic. A native host toolchain is no longer needed
(the old manual apt/conda build, and the R-Forge rdyncall package it relied on, no
longer work).

A self-contained image builds the C library, the embedded R kernel, and the Swing
GUI, and serves the whole desktop in a browser over noVNC — no local X server,
XQuartz, or toolchain needed. Everything is compiled from this repository's own
source; nothing is downloaded from the (now dead) original distribution site.

```bash
# Build (from the repo root). Pick your host architecture:
docker build --platform linux/amd64 -t systemic:2.2000 .     # Intel / AMD, or Apple Silicon via emulation
docker build --platform linux/arm64 -t systemic:2.2000 .     # Apple Silicon / ARM, native (faster)

# Run, then open http://localhost:8080/vnc.html in a browser (no password)
docker run --rm -p 8080:8080 systemic:2.2000
```

The browser shows a full XFCE desktop; Systemic opens automatically and can be
relaunched from the Applications menu. A file manager (Thunar) and a terminal are
included.

**Getting your own data in/out.** Mount a host folder; it appears live inside the
container and writes back to your machine (use this instead of the VNC clipboard
for files):

```bash
docker run --rm -p 8080:8080 \
  -v "/path/on/host/mydata:/opt/Systemic/datafiles/external" \
  systemic:2.2000
```

Open `/opt/Systemic/datafiles/external/` from the GUI (File → Open) or Thunar.
The desktop defaults to 1920x1080; set `-e SCREEN=2560x1440x24` (or your monitor's
resolution) to fill a larger window.

### Notes on the build (fixes applied) ###

- **`Makefile.linux` uses `-std=gnu99`** (not `-std=c99`). Under `-std=c99`,
  `<string.h>` does not declare the POSIX `strdup`, so `src/kernel.c` calls it with
  an implicit `int` return and truncates the 64-bit pointer to 32 bits. That happens
  to be lossless on native x86-64 but corrupts the kernel info list on arm64 and
  under x86 emulation, segfaulting when a second RV dataset is loaded.
- **The Dockerfile rebuilds `deps/f2c` and `deps/swift` from source** (scrubbing any
  stale `.o`/`.a` first). A prebuilt, incomplete `libf2c.a` otherwise links in
  without the Fortran I/O runtime and fails at load with `undefined symbol: s_wsfe`.
- **On arm64**, rdyncall 0.7.5's bundled dyncall (v0.8) has no aarch64 backend, so
  the Dockerfile swaps in dyncall 1.4 before installing rdyncall (selected
  automatically via `TARGETARCH`).

See `Dockerfile`, `.dockerignore`, and `docker/` for the full recipe.