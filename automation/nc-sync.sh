#!/bin/bash
cd ~/repos
for repo in $(ls); do
  if [ -d "$repo/.git" ]; then
    git -C "$repo" pull && echo "$(date): Synced $repo" >> ~/neural-codex-notification.log
  fi
done
