#!/data/data/com.termux/files/usr/bin/python
import json
import os

# Ensure directory exists
os.makedirs("/data/data/com.termux/files/home/storage/shared/neural-codex", exist_ok=True)

# Example task from KAI
task = {"task": "train_model", "params": {"epochs": 10}}

# Write to shared storage (Termux-accessible)
with open("/data/data/com.termux/files/home/storage/shared/neural-codex/kai_output.json", "w") as f:
    json.dump(task, f)

print("Task written to ~/storage/shared/neural-codex/kai_output.json")
