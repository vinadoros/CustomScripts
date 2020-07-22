#!/bin/bash
# Script powersaves the display every 10 seconds. Useful if a proper screensaver or power management isn't active for the current system.
sleep 2s
while true; do
	xset dpms force off
	sleep 10s
done
