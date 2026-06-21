#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PROJECT_DIR="${1:-}"
DEPLOY_BRANCH="${2:-main}"

if [ -z "$PROJECT_DIR" ]; then
    echo "❌ Usage: $0 <project-directory> [branch]"
    echo "   Example: $0 ~/my-project main"
    exit 1
fi

cd "$PROJECT_DIR" || { echo "❌ Directory not found: $PROJECT_DIR"; exit 1; }

LOG_FILE="$PROJECT_DIR/.vercel/recovery-$(date +%s).log"
mkdir -p "$PROJECT_DIR/.vercel"

GIT_BIN="/data/data/com.termux/files/usr/bin/git"
NPX="/data/data/com.termux/files/usr/bin/npx"

echo "🌲 Neural-Codex Recovery Pipeline"
echo "Project: $PROJECT_DIR"
echo "Log: $LOG_FILE"

# Verify git repo
if [ ! -d ".git" ]; then
    echo "❌ Not a git repository."
    exit 1
fi

# Resolve Vercel — prefer local, fallback to npx
VERCEL="./node_modules/.bin/vercel"
if [ ! -f "$VERCEL" ]; then
    echo "📦 Installing Vercel locally..."
    npm install vercel@latest --save-dev
fi
VERCEL="./node_modules/.bin/vercel"

echo "✅ Vercel: $VERCEL"
$VERCEL --version

# Ollama config
OLLAMA_URL="http://localhost:11434"
MODEL="qwen2.5:3b"  # You have this pulled already

# Check Ollama
if ! curl -s "$OLLAMA_URL/api/tags" > /dev/null; then
    echo "⚠️ Starting Ollama..."
    ollama serve &
    sleep 3
fi

echo "📋 Capturing state..."
$GIT_BIN status >> "$LOG_FILE" 2>&1
$GIT_BIN log --oneline -3 >> "$LOG_FILE" 2>&1

# Build
echo "🔨 Running build..."
if $VERCEL build >> "$LOG_FILE" 2>&1; then
    echo "✅ Build passed!"
    $GIT_BIN add -A
    $GIT_BIN commit -m "🔧 Auto-recovery: $(date '+%Y-%m-%d %H:%M')" || true
    $GIT_BIN push origin "$DEPLOY_BRANCH" || true
    $VERCEL --prod >> "$LOG_FILE" 2>&1
    echo "🚀 Deployed!"
    exit 0
fi

echo "❌ Build failed. Diagnosing..."

# Extract last 200 lines of error
ERROR_LOG=$(tail -n 200 "$LOG_FILE")
PKG=$(cat package.json 2>/dev/null || echo "{}")
VRC=$(cat vercel.json 2>/dev/null || echo "{}")

PROMPT="You are the Neural-Codex deployment recovery agent.
Analyze this Vercel build failure and output ONLY shell commands to fix it.

BUILD ERROR:
$ERROR_LOG

PACKAGE.JSON:
$PKG

VERCEL.JSON:
$VRC

RULES:
- Output only executable bash commands
- No markdown, no explanations, no code blocks
- If missing dependency: npm install <pkg>
- If env var missing: echo KEY=value >> .env.local
- If config error: output the corrected file using cat <<'F'
- If unfixable: echo exit 1"

echo "🤖 Querying Ollama ($MODEL)..."
FIX=$(curl -s "$OLLAMA_URL/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"prompt\":$(echo "$PROMPT" | jq -Rs .),\"stream\":false}" \
    | jq -r '.response')

if [ -z "$FIX" ] || [ "$FIX" = "null" ]; then
    echo "❌ Ollama failed. Check logs: $LOG_FILE"
    exit 1
fi

echo "🔧 Applying fix..."
echo "$FIX" | tee -a "$LOG_FILE"
echo "$FIX" | bash >> "$LOG_FILE" 2>&1 || {
    echo "❌ Fix failed."
    exit 1
}

echo "🔨 Rebuilding..."
if $VERCEL build >> "$LOG_FILE" 2>&1; then
    echo "✅ Fixed! Deploying..."
    $GIT_BIN add -A
    $GIT_BIN commit -m "🔧 Auto-recovery: $(date '+%Y-%m-%d %H:%M')" || true
    $GIT_BIN push origin "$DEPLOY_BRANCH" || true
    $VERCEL --prod >> "$LOG_FILE" 2>&1
    echo "🚀 Done!"
else
    echo "❌ Still failing. Log: $LOG_FILE"
    exit 1
fi
