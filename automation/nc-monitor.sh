#!/bin/bash
inotifywait -m -r -e modify ~/repos --format '%w%f' | while read file; do
  echo "$(date): File changed: $file" >> ~/neural-codex-notification.log
done
