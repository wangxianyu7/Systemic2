#!/bin/bash
# Start a headless X, a full XFCE desktop with the Systemic GUI, and serve it over the browser (noVNC).
set -e
export DISPLAY=:0
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true

# virtual framebuffer
Xvfb :0 -screen 0 "${SCREEN:-1280x800x24}" >/var/log/xvfb.log 2>&1 &
for i in $(seq 1 40); do [ -e /tmp/.X11-unix/X0 ] && break; sleep 0.25; done

# full XFCE desktop session (panel + Thunar + terminal); needs a dbus session bus.
# Systemic auto-opens via /etc/xdg/autostart and can be relaunched from the apps menu.
eval "$(dbus-launch --sh-syntax)"
startxfce4 >/var/log/xfce.log 2>&1 &
XFCE_PID=$!

# VNC mirror of :0  (-bg forks)
x11vnc -display :0 -forever -shared -nopw -rfbport 5900 -bg -quiet >/var/log/x11vnc.log 2>&1

# browser proxy on $PORT -> 5900
# (fedora:26's novnc_server can't locate a `websockify` executable; call the module directly)
python2 -m websockify.websocketproxy --web /usr/share/novnc "${PORT:-8080}" localhost:5900 >/var/log/novnc.log 2>&1 &

# keep the container alive for the whole desktop session (closing Systemic leaves the
# desktop up so you can reopen it from the menu); stop the container to exit.
wait "$XFCE_PID"
