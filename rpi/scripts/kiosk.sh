#!/usr/bin/env bash
# EMA Touchscreen Kiosk Display Script
# Launches Chromium in fullscreen kiosk mode pointing to the local dashboard.

xset s off || true
xset -dpms || true
xset s noblank || true

# Hide mouse pointer when inactive
which unclutter >/dev/null 2>&1 && unclutter -idle 1 -root &

# Wait for local dashboard to be accessible
until curl -sSf http://localhost:8080 >/dev/null 2>&1; do
    echo "Waiting for EMA dashboard on http://localhost:8080..."
    sleep 2
done

# Clear previous session crashes to avoid "restore session" prompt
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences 2>/dev/null || true
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences 2>/dev/null || true

# Start Chromium in kiosk mode
exec chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-features=Translate \
    --check-for-update-interval=31536000 \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    --autoplay-policy=no-user-gesture-required \
    --incognito \
    http://localhost:8080
