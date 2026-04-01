---
description: Move all uncommitted changes (staged, unstaged, and untracked files) to a new branch
allowed-tools: Bash, AskUserQuestion
---

Move all uncommitted changes (staged, unstaged, and untracked files) to a new branch.

**Arguments:** $ARGUMENTS

Parse the arguments as: `<branch-name> [project-name]`

- **branch-name** (required): The name for the new branch. If missing, ask for one before proceeding.
- **project-name** (optional): A sibling project under `/Volumes/ext2G/Developer/montraio/` to operate on (e.g. `montra-via-api`, `via-cli4`, `fn-api-o365-jobs`). If not specified, use the current working directory.

## Steps

1. **Resolve the target directory:**
   - If a project name is provided, resolve it to `/Volumes/ext2G/Developer/montraio/<project-name>`. Confirm it exists and is a git repo. If not, report the error and stop.
   - If no project name, use the current working directory.
   - All git commands below run in the resolved target directory.

2. **Verify preconditions:**
   - Confirm there are uncommitted changes (staged, unstaged, or untracked) in the target directory. If the working tree is clean, say so and stop.
   - Confirm the branch name doesn't already exist locally. If it does, warn and stop.

3. **Stash everything** (including untracked files) with a descriptive message:
   ```
   git -C <target-dir> stash push -u -m "stash-branch: <branch-name>"
   ```

4. **Create and switch** to the new branch from the current branch:
   ```
   git -C <target-dir> checkout -b <branch-name>
   ```

5. **Pop the stash** to restore changes on the new branch:
   ```
   git -C <target-dir> stash pop
   ```

6. **Show the result:** Run `git -C <target-dir> status` and confirm the branch name and that changes are restored.

## Error handling

- If the stash fails, stop and report the error.
- If branch creation fails (e.g. invalid name), pop the stash back onto the original branch so no work is lost, then report the error.
- If stash pop has conflicts, report them clearly but do NOT resolve them automatically.
