# Chronoflora — Project Synchronization Plan

**Project:** Chronoflora (Vertical Slice)  
**Branch:** `arena/5213ce08-game-godot`  
**Repository:** `abdalrhmansyed319-hub/Game-godot`  
**Date:** 2026-11-21

---

## Executive Summary

**Recommended solution: GitHub + Git (local clone on your PC)**

This is the industry-standard workflow for game development. It gives you incremental file-level synchronization, full Git history, merge conflict protection, and zero cost. Google Drive is **not recommended** for code projects — it lacks version history, poor conflict resolution, and syncs entire files rather than changed portions.

---

## What I Can Actually Do (Verified Capabilities)

| Capability | Status | Evidence |
|------------|--------|----------|
| `git push` to GitHub | ✅ Available | `git` and `gh` are configured and authenticated in my environment |
| Create pull requests | ✅ Available | `gh pr` commands available |
| Commit changes on branch `arena/5213ce08-game-godot` | ✅ Available | Current branch is active and tracked |
| Access user's local PC | ❌ Not available | I cannot connect to your computer directly |
| Google Drive file operations | ❌ Broken | All Drive connector calls (validate_credential, list_files, create_file, upload_file) return errors |

---

## Evaluation of All Options

### 1. GitHub with Git commits, branches, and incremental pulls

| Criterion | Rating |
|-----------|--------|
| Ease of setup | Medium (requires Git install on your PC) |
| Works with my capabilities | ✅ Yes — I can push, you can pull |
| Software on your PC | Git (command line or GitHub Desktop) |
| Incremental updates | ✅ Yes — only changed files download |
| Automatic sync | ❌ No — you run `git pull` when ready |
| Godot compatible | ✅ Yes (with proper `.gitignore`) |
| Handles deleted/renamed files | ✅ Yes — Git tracks these |
| Prevents accidental overwriting | ✅ Yes — merge conflicts block unsafe overwrites |
| Handles conflicting edits | ✅ Yes — Git merge conflict resolution |
| Preserves Git history | ✅ Yes — full commit history |
| Cost | Free |

### 2. GitHub Desktop on your local computer

| Criterion | Rating |
|-----------|--------|
| Ease of setup | High (GUI, no command line needed) |
| Works with my capabilities | ✅ Yes |
| Software on your PC | GitHub Desktop (includes Git) |
| Incremental updates | ✅ Yes |
| Automatic sync | ❌ No — you click "Pull origin" |
| Godot compatible | ✅ Yes |
| Handles deleted/renamed files | ✅ Yes |
| Prevents accidental overwriting | ✅ Yes |
| Handles conflicting edits | ✅ Yes (visual conflict resolver) |
| Preserves Git history | ✅ Yes |
| Cost | Free |

### 3. Google Drive synchronization

| Criterion | Rating |
|-----------|--------|
| Ease of setup | High |
| Works with my capabilities | ❌ No — Drive connector is broken in this environment |
| Software on your PC | Google Drive for Desktop |
| Incremental updates | ❌ No — syncs entire changed files |
| Automatic sync | ✅ Yes |
| Godot compatible | ⚠️ Partially — `.import/` folder can cause issues |
| Handles deleted/renamed files | ⚠️ Poor — Drive's version history is limited |
| Prevents accidental overwriting | ❌ No — last write wins, no merge conflicts |
| Handles conflicting edits | ❌ No — creates "Conflict" copies |
| Preserves Git history | ❌ No — no commit history |
| Cost | Free (15 GB) |

### 4. GitHub Actions or automated deployment

| Criterion | Rating |
|-----------|--------|
| Ease of setup | Low (complex YAML configuration) |
| Works with my capabilities | ⚠️ Limited — can automate builds but not push to your PC |
| Software on your PC | None for Actions, but you still need to download artifacts |
| Incremental updates | ❌ No — downloads build artifacts, not source changes |
| Automatic sync | ⚠️ Partially — automated builds, manual download |
| Godot compatible | ⚠️ Requires export template setup |
| Cost | Free (limited minutes) |

### 5. Local Git workflow with remote repository

| Criterion | Rating |
|-----------|--------|
| Ease of setup | Medium |
| Works with my capabilities | ✅ Yes |
| Software on your PC | Git |
| Incremental updates | ✅ Yes |
| Automatic sync | ❌ No — manual pull |
| Godot compatible | ✅ Yes |
| Cost | Free |

---

## Answers to Your Important Questions

| Question | Answer |
|----------|--------|
| **Can you push changes directly to my GitHub repository?** | Yes. I have `git` and `gh` authenticated. I commit and push to branch `arena/5213ce08-game-godot`. |
| **Can I use GitHub Desktop to pull only your latest changes?** | Yes. GitHub Desktop shows you a "Pull origin" button that downloads only changed files. |
| **Can my local Godot folder be connected to the same repository?** | Yes. You clone the repository once, then it stays connected. Future updates are `git pull` only. |
| **Can I receive updates without downloading the complete project?** | Yes. After the initial clone, `git pull` downloads only the files I changed (deltas). |
| **Can we automate the process so you rarely need to do anything manually?** | Partially. I automate commits and pushes. You still need to click "Pull" (or run `git pull`) to receive changes. Full automation to your PC is not possible because I cannot access your computer. |
| **Is Google Drive synchronization better or worse than Git for this workflow?** | **Worse.** Drive syncs whole files, has no merge conflict resolution, no commit history, and the Drive connector is currently broken in my environment. Git is purpose-built for code synchronization. |
| **Can we safely work on the same project without overwriting each other's modifications?** | Yes. Git uses merge conflicts to prevent accidental overwrites. If we both edit the same lines, Git will flag a conflict for you to resolve. |

---

## Recommended Architecture

```
┌─────────────────┐         git push         ┌──────────────────┐
│  MY ENVIRONMENT │ ───────────────────────> │   GITHUB         │
│  (branch:       │                          │   (remote)       │
│  arena/...godot)│                          │                  │
└─────────────────┘                          └──────────────────┘
                                               │
                                               │ git pull / fetch
                                               ▼
                                       ┌───────────────┐
                                       │  YOUR PC      │
                                       │  (local clone)│
                                       │               │
                                       │  Godot opens  │
                                       │  updated      │
                                       │  project      │
                                       └───────────────┘
```

**Flow:**
1. I modify files in my workspace
2. I `git commit` with descriptive messages
3. I `git push origin arena/5213ce08-game-godot`
4. You see new commits on GitHub
5. You `git pull` (or click "Pull origin" in GitHub Desktop)
6. Only changed files download to your PC
7. You open Godot and continue working

---

## Exact Software You Need to Install

| Software | Purpose | Download |
|----------|---------|----------|
| **Git** | Version control | https://git-scm.com/download/ |
| **GitHub Desktop** (optional, recommended) | GUI for Git | https://desktop.github.com/ |
| **Godot 4.7.2+** | Game engine | https://godotengine.org/download |

**Minimum:** Git + Godot  
**Recommended:** Git + GitHub Desktop + Godot

---

## Step-by-Step Setup Instructions

### One-time setup on your PC:

**Option A: Command Line (Git only)**

```bash
# 1. Install Git from https://git-scm.com/download/

# 2. Clone the repository (do this once)
git clone https://github.com/abdalrhmansyed319-hub/Game-godot.git
cd Game-godot

# 3. Checkout the working branch
git checkout arena/5213ce08-game-godot

# 4. Open the folder in Godot 4.x
#    Launch Godot → Import → Select this folder → Play
```

**Option B: GitHub Desktop (GUI, recommended)**

```bash
# 1. Install GitHub Desktop from https://desktop.github.com/
# 2. Sign in with your GitHub account
# 3. Click "Clone a repository from the Internet"
# 4. Select: abdalrhmansyed319-hub / Game-godot
# 5. Choose local save location
# 6. In GitHub Desktop, click "Current branch" → select arena/5213ce08-game-godot
# 7. Open the cloned folder in Godot
```

---

## Exact Commands / Butins You Will Use

### When you want to get my latest changes:

**Command line:**
```bash
cd /path/to/Game-godot
git pull origin arena/5213ce08-game-godot
```

**GitHub Desktop:**
1. Open GitHub Desktop
2. Ensure you're on branch `arena/5213ce08-game-godot`
3. Click the **"Pull origin"** button (top bar)
4. Review the list of changed files
5. Open Godot and continue

### If you made local changes too:

**Command line:**
```bash
git pull origin arena/5213ce08-game-godot
# If conflicts: resolve them, then
git add .
git commit -m "Resolve merge conflicts"
git push
```

**GitHub Desktop:**
1. GitHub Desktop will warn you about conflicts
2. Click "View conflicts" to resolve them visually
3. Mark as resolved, commit, and push

---

## My Workflow (What I Will Do)

Whenever I modify the game:

| Step | Action | Command |
|------|--------|---------|
| 1 | Modify files in my workspace | (editing code, assets, scenes) |
| 2 | Review changes | `git status` |
| 3 | Stage changes | `git add <changed-files>` |
| 4 | Commit with message | `git commit -m "Descriptive message"` |
| 5 | Push to GitHub | `git push origin arena/5213ce08-game-godot` |
| 6 | Notify you | (via chat message) |

I will **never** push directly to `main`. All work goes through branch `arena/5213ce08-game-godot`.

---

## Safe Rollback and Backup Strategy

### Rollback my changes (if something breaks):

**Command line:**
```bash
# View recent commits
git log --oneline -10

# Undo the last commit (keeps your changes)
git revert HEAD

# Or reset to a specific commit (discards changes after it)
git reset --hard <commit-hash>

# Push the rollback
git push origin arena/5213ce08-game-godot
```

**GitHub Desktop:**
1. Click "History" tab
2. Right-click the commit before the problem
3. Select "Revert commit"
4. Push the revert

### Backup strategy:

- **GitHub is your remote backup** — every commit is stored on GitHub
- **I will not force-push** — force-pushing rewrites history and can lose work
- **You should clone to a second location periodically** as an extra backup
- **Godot's `.import/` folder is gitignored** — your local asset cache won't be committed

---

## Method for Reviewing Changes Before Accepting

### Option A: Direct pull (fast, trust-based)

You pull my changes directly. This works well if we communicate about what I'm changing.

### Option B: Pull Request review (recommended for major changes)

1. I push my changes to the branch
2. I create a Pull Request on GitHub: `gh pr create`
3. You review the file changes on GitHub's web interface
4. You comment, approve, or request changes
5. You merge or pull the changes locally

**To create a PR from my side:**
```bash
gh pr create --base arena/5213ce08-game-godot --head arena/5213ce08-game-godot --title "Description" --body "What changed"
```

### Option C: Review before pull

Before you `git pull`, you can check what changed:
```bash
git fetch origin
git log ..origin/arena/5213ce08-game-godot --oneline
git diff ..origin/arena/5213ce08-game-godot --stat
```

---

## Why Not Google Drive?

| Issue | Why it matters for Godot |
|-------|-------------------------|
| No merge conflicts | If we both edit `GameManager.gd`, Drive creates a "Conflict" copy instead of letting us merge intelligently |
| No commit history | You can't see *what* changed, only that *something* changed |
| Syncs whole files | A 1-line change to a 1 MB file re-uploads the entire file |
| `.import/` folder | Godot's import cache can bloat Drive sync and cause conflicts |
| Connector broken | The Google Drive connector is currently returning errors in my environment |

---

## Final Recommendation

**Use GitHub + Git (Option 1 or 2).**

It is:
- ✅ Free
- ✅ Incremental (only changed files)
- ✅ Safe (merge conflicts prevent overwrites)
- ✅ Industry-standard for game development
- ✅ Compatible with Godot (with `.gitignore`)
- ✅ Fully within my capabilities (I can push; you can pull)

**Setup time:** 10–15 minutes  
**Ongoing effort:** You click "Pull" when I notify you of changes  
**Maintenance:** Near zero

---

## Next Steps (Waiting for Your Approval)

I will **not** modify the repository or change any configuration until you approve this plan.

**Please confirm:**
1. Will you install Git (and optionally GitHub Desktop) on your PC?
2. Do you approve using branch `arena/5213ce08-game-godot` as our shared working branch?
3. Would you prefer Option A (command line) or Option B (GitHub Desktop GUI)?

Once you approve, I will:
1. Ensure the `.gitignore` is complete for Godot
2. Push all current project files to the branch
3. Provide you with the exact clone URL and branch name
4. Wait for you to clone and report back
