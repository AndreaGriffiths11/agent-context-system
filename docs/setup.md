# Setup

Choose **one** method based on your agent and needs:

## Option A: GitHub Copilot (Recommended)

Use the official Copilot skill registry. Gets you updates automatically.

```bash
npx skills add AndreaGriffiths11/agent-context-system
bash .agents/skills/agent-context-system/scripts/init-agent-context.sh
```

## Option B: OpenClaw

Clone into your skills directory. Works natively with OpenClaw's skill system.

```bash
git clone https://github.com/AndreaGriffiths11/agent-context-system.git skills/agent-context-system
```

Restart your OpenClaw session. It will read `AGENTS.md` automatically.

## Option C: Manual (Any Agent)

Copy just the files you need. Good for customizing or if you don't want package managers.

```bash
# Clone to a temp location
git clone https://github.com/AndreaGriffiths11/agent-context-system.git /tmp/acs

# Copy the core files
cp /tmp/acs/AGENTS.md /tmp/acs/agent-context ./
cp -r /tmp/acs/agent_docs /tmp/acs/scripts ./

# Initialize
./agent-context init

# Cleanup
rm -rf /tmp/acs
```

Then add your agent's config file manually:
- **Claude Code:** Already handled by `init` (creates `CLAUDE.md` symlink)
- **Cursor:** Create `.cursorrules` with `Read AGENTS.md before starting`
- **Windsurf:** Create `.windsurfrules` with `Read AGENTS.md before starting`
- **Copilot:** Create `.github/copilot-instructions.md` with `Read AGENTS.md before starting`

## Option D: GitHub Template (New Project)

Start a new repo from this template, then initialize.

```bash
gh repo create my-project --template AndreaGriffiths11/agent-context-system
cd my-project
./agent-context init
```

## Option E: Fork (Contributors/Customizers)

Fork this repo if you want to customize templates or contribute back.

```bash
gh repo fork AndreaGriffiths11/agent-context-system
git clone https://github.com/YOUR_USERNAME/agent-context-system.git
```

## Which should I choose?

| If you... | Use |
|-----------|-----|
| Use GitHub Copilot and want easy updates | **Option A** |
| Use OpenClaw | **Option B** |
| Use Cursor, Claude Code, Windsurf, or multiple agents | **Option C** |
| Starting a new project from scratch | **Option D** |
| Want to customize or contribute | **Option E** |

## CLI Commands

```bash
agent-context init      # Set up context system in current project
agent-context validate  # Check setup is correct
agent-context promote   # Find patterns to move from scratchpad to AGENTS.md
agent-context promote --autopromote  # Auto-append patterns recurring 3+ times
```
