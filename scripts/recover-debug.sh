#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

PROJECT="/data/data/com.termux/files/home/my-project"
cd "$PROJECT" || { echo "❌ Cannot cd to $PROJECT"; exit 1; }

echo "🌲 Neural-Codex Recovery (DEBUG MODE)"
echo "PWD: $(pwd)"

# Check git
echo "📋 Checking git..."
if [ -d ".git" ]; then
    echo "✅ Git repo found"
    git status
else
    echo "❌ NO .git directory here!"
    echo "Files in this dir:"
    ls -la
    exit 1
fi

# Check npx vercel
echo ""
echo "🔧 Checking npx vercel..."
npx vercel --version || echo "❌ npx vercel failed"

# Check package.json
echo ""
echo "📦 Checking package.json..."
if [ -f "package.json" ]; then
    echo "✅ package.json found"
    cat package.json | head -20
else
    echo "❌ NO package.json!"
fi

# Check vercel.json
echo ""
echo "⚙️ Checking vercel.json..."
if [ -f "vercel.json" ]; then
    echo "✅ vercel.json found"
    cat vercel.json
else
    echo "⚠️ No vercel.json (optional)"
fi

# Check Ollama
echo ""
echo "🧠 Checking Ollama..."
curl -s http://localhost:11434/api/tags | head -c 200 || echo "❌ Ollama not responding"

echo ""
echo "✅ Debug complete. Fix the issues above, then run the real recovery script."
