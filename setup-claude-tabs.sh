#!/bin/sh
# Install the Claude Code remote-session open command into the current
# project — Linux/WSL version. Run from the TARGET project root:
#   sh <path-to-claude-remote-tabs>/setup-claude-tabs.sh
# Idempotent: safe to run multiple times.
set -e
root="$(pwd)"
claudeDir="$root/.claude"
srcDir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$claudeDir"

for f in open-remote-tab.sh; do
    [ "$srcDir/$f" = "$claudeDir/$f" ] || cp "$srcDir/$f" "$claudeDir/$f"
done
chmod +x "$claudeDir/open-remote-tab.sh"

# settings.json: allow rules + defaultMode auto (merge, keep existing)
python3 - "$claudeDir" <<'EOF'
import json, os, sys
claude_dir = sys.argv[1]
path = os.path.join(claude_dir, 'settings.json')
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
perms = data.setdefault('permissions', {})
allow = perms.setdefault('allow', [])
for rule in (
    'Bash(' + claude_dir + '/open-remote-tab.sh)',
    'AskUserQuestion',
):
    if rule not in allow:
        allow.append(rule)
perms.setdefault('defaultMode', 'auto')
with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
print('settings.json: rules ok')
EOF

# CLAUDE.md section (only when missing)
claudeMd="$root/CLAUDE.md"
if [ -f "$claudeMd" ] && grep -q 'open-remote-tab.sh' "$claudeMd"; then
    echo 'CLAUDE.md: section exists'
else
    cat >> "$claudeMd" <<EOF

## 📱 Remote sessions (background, for mobile control)

- "Open a new session" / "open a new tab" → run \`$claudeDir/open-remote-tab.sh\` (each call starts a new remote-control session)
- Install in another project: from the target project root, run
  \`sh $srcDir/setup-claude-tabs.sh\` (idempotent)
EOF
    echo 'CLAUDE.md: section added'
fi
echo "setup done: $root"
