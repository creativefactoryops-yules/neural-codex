#!/data/data/com.termux/files/usr/bin/bash
# Neural-Codex: One-shot fix + recovery pipeline
set -euo pipefail

PROJECT_DIR="${1:-/data/data/com.termux/files/home/my-project}"
DEPLOY_BRANCH="${2:-main}"

echo "🌲 Neural-Codex Recovery Pipeline"
echo "Project: $PROJECT_DIR"

# FIX 1: Reinstall Vercel CLI properly
echo "🔧 Fixing Vercel CLI..."
rm -f /data/data/com.termux/files/usr/bin/vercel
rm -rf /data/data/com.termux/files/usr/lib/node_modules/vercel
npm install -g vercel@latest --prefix /data/data/com.termux/files/usr 2>/dev/null || true

# Fallback: local install
cd "$PROJECT_DIR"
if ! command -v vercel >/dev/null 2>&1; then
    echo "📦 Installing Vercel locally..."
    npm install vercel@latest --save-dev
    VERCEL="./node_modules/.bin/vercel"
else
    VERCEL="vercel"
fi

# Verify
$VERCEL --version

# FIX 2: Ensure git repo
if [ ! -d ".git" ]; then
    echo "❌ Not a git repo. Run: git init && git remote add origin <url>"
    exit 1
fi

# FIX 3: Setup logging
mkdir -p .vercel
LOG_FILE=".vercel/recovery-$(date +%s).log"
GIT="/data/data/com.termux/files/usr/bin/git"

echo "Log: $LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

# FIX 4: Capture state
echo "📋 Capturing state..."
$GIT status >> "$LOG_FILE" 2>&1
$GIT log --oneline -3 >> "$LOG_FILE" 2>&1

# FIX 5: Check Ollama
OLLAMA="http://localhost:11434"
MODEL="qwen2.5:3b"

if ! curl -s "$OLLAMA/api/tags" >/dev/null; then
    echo "⚠️ Starting Ollama..."
    ollama serve &
    sleep 4
fi

# FIX 6: Build
echo "🔨 Building..."
if $VERCEL build >> "$LOG_FILE" 2>&1; then
    echo "✅ Build passed!"
    $GIT add -A
    $GIT commit -m "🔧 Auto-recovery: $(date '+%Y-%m-%d %H:%M')" || true
    $GIT push origin "$DEPLOY_BRANCH" || true
    $VERCEL --prod >> "$LOG_FILE" 2>&1
    echo "🚀 Deployed!"
    exit 0
fi

echo "❌ Build failed. Diagnosing with Ollama..."

# FIX 7: Ollama diagnosis
ERR=$(tail -n 200 "$LOG_FILE")
PKG=$(cat package.json 2>/dev/null || echo "{}")
VRC=$(cat vercel.json 2>/dev/null || echo "{}")

PROMPT=$(cat <<PROMPT
You are the Neural-Codex deployment recovery agent.
Analyze this Vercel build failure. Output ONLY shell commands to fix it.

BUILD ERROR:
$ERR

PACKAGE.JSON:
$PKG

VERCEL.JSON:
$VRC

RULES:
- Output only executable bash commands
- No markdown, no explanations, no code blocks
- If missing dependency: npm install <pkg>
- If env var missing: echo KEY=value >> .env.local
- If config error: output corrected file using cat
- If unfixable: echo exit 1
PROMPT
)

echo "🤖 Querying Ollama ($MODEL)..."
FIX=$(curl -s "$OLLAMA/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"prompt\":$(echo "$PROMPT" | jq -Rs .),\"stream\":false}" \
    | jq -r '.response')

if [ -z "$FIX" ] || [ "$FIX" = "null" ]; then
    echo "❌ Ollama failed. Check: $LOG_FILE"
    exit 1
fi

echo "🔧 Applying fix..."
echo "$FIX" | tee -a "$LOG_FILE"
echo "$FIX" | bash >> "$LOG_FILE" 2>&1 || {
    echo "❌ Fix failed."
    exit 1
}

# FIX 8: Rebuild and deploy
echo "🔨 Rebuilding..."
if $VERCEL build >> "$LOG_FILE" 2>&1; then
    echo "✅ Fixed! Deploying..."
    $GIT add -A
    $GIT commit -m "🔧 Auto-recovery: $(date '+%Y-%m-%d %H:%M')" || true
    $GIT push origin "$DEPLOY_BRANCH" || true
    $VERCEL --prod >> "$LOG_FILE" 2>&1
    echo "🚀 Done!"
else
    echo "❌ Still failing. Log: $LOG_FILE"
    exit 1
fi
