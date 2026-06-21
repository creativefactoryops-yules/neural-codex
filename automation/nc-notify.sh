#!/bin/bash
echo "$(date): $1" >> ~/neural-codex-notification.log
termux-notification --title "Neural-Codex" --content "$1" 2>/dev/null || echo "Notification: $1"
