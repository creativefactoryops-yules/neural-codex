#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
cd /data/data/com.termux/files/home/my-project

VERCEL="./node_modules/.bin/vercel"
GIT="/data/data/com.termux/files/usr/bin/git"
LOG=".vercel/recovery-$(date +%s).log"
mkdir -p .vercel

echo "🌲 Neural-Codex Recovery // Digital Forest"
echo "Log: $LOG"

if ! curl -s http://localhost:11434/api/tags >/dev/null; then
    echo "⚠️ Starting Ollama..."
    ollama serve &
    sleep 4
fi

$GIT status >> "$LOG" 2>&1 || true

if $VERCEL build >> "$LOG" 2>&1; then
    echo "✅ Build passed!"
    $GIT add -A
    $GIT commit -m "🔧 Auto-recovery: $(date '+%Y-%m-%d %H:%M')" || true
    $GIT push origin main || true
    $VERCEL --prod >> "$LOG" 2>&1
    echo "🚀 Deployed!"
    exit 0
fi

echo "❌ Build failed. Diagnosing..."

ERR=$(tail -n 200 "$LOG")
PKG=$(cat package.json 2>/dev/null || echo "{}")
VRC=$(cat vercel.json 2>/dev/null || echo "{}")

PROMPT="Neural-Codex deployment recovery agent. Analyze this Vercel build failure. Output ONLY shell commands to fix it. No markdown. No explanations.

BUILD ERROR:
$ERR

PACKAGE.JSON:
$PKG

VERCEL.JSON:
$VRC

RULES:
- Output only executable bash commands
- If missing dependency: npm install <pkg>
- If config error: output corrected file using cat
- If unfixable: echo exit 1"

echo "🤖 Querying Ollama..."
FIX=$(curl -s http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"qwen2.5:3b\",\"prompt\":$(echo "$PROMPT" | jq -Rs .),\"stream\":false}" \
    | jq -r '.response')

if [ -z "$FIX" ] || [ "$FIX" = "null" ]; then
    echo "❌ Ollama failed. Check: $LOG"
    exit 1
fi

echo "🔧 Applying fix..."
echo "$FIX" | tee -a "$LOG"
echo "$FIX" | bash >> "$LOG" 2>&1 || { echo "❌ Fix failed."; exit 1; }

if $VERCEL build >> "$LOG" 2>&1; then
    echo "✅ Fixed! Deploying..."
    $GIT add -A
    $GIT commit -m "🔧 Auto-recovery: $(date '+%Y-%m-%d %H:%M')" || true
    $GIT push origin main || true
    $VERCEL --prod >> "$LOG" 2>&1
    echo "🚀 Done!"
else
    echo "❌ Still failing. Log: $LOG"
    exit 1
fi
