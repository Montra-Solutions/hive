---
name: repos
description: Show a snapshot of all sibling repos — current branch, changed file count, and untracked/uncommitted file status. Also provides a standalone live dashboard script.
allowed-tools: Bash
---

# Repo Dashboard

Display a status overview of every git repository in the parent project directory.

**Arguments:** $ARGUMENTS

## Resolve Base Directory

```bash
if [[ -d "/c/Users/Ryan Gordon/Projects/montra-via-web" ]]; then
  BASE_DIR="/c/Users/Ryan Gordon/Projects"
elif [[ -d "/Volumes/ext2G/Developer/montraio/montra-via-web" ]]; then
  BASE_DIR="/Volumes/ext2G/Developer/montraio"
else
  echo "ERROR: Cannot locate project directories" && exit 1
fi
```

## Gather Status

Run a single bash script that loops through every subdirectory in `$BASE_DIR`. For each directory that contains a `.git` folder, collect:

1. **Repo name** — the directory basename
2. **Current branch** — `git -C <dir> branch --show-current` (fall back to short HEAD if detached)
3. **Changed files count** — number of lines from `git -C <dir> status --porcelain`
4. **Staged count** — lines matching `^[MADRC]` in porcelain output
5. **Unstaged count** — lines matching `^.[MADRC]` in porcelain output
6. **Untracked count** — lines matching `^\?\?` in porcelain output

Run all repos in a single bash call — do **not** make a separate tool call per repo.

## Output Format

Display a markdown table sorted alphabetically by repo name:

```
| Repo                | Branch        | Changed | Staged | Unstaged | Untracked |
|---------------------|---------------|---------|--------|----------|-----------|
| montra-via-api      | development   |       0 |      0 |        0 |         0 |
| montra-via-web      | bug-3989-fix  |       3 |      1 |        1 |         1 |
| montra-via-db       | development   |       0 |      0 |        0 |         0 |
```

After the table, add a one-line summary:

```
<total-repos> repos — <clean-count> clean, <dirty-count> with changes
```

Then remind the user about the live dashboard:

```
Tip: For a live-updating view, run in a separate terminal:
  bash "<BASE_DIR>/claude-shared/scripts/repo-dashboard.sh"
```

## Notes

- Skip non-git directories silently (e.g. `.claude`, `node_modules`)
- If a repo has a detached HEAD, show the short SHA instead of a branch name
- This is a read-only skill — it does not modify any files or repos
- A live-updating terminal dashboard is available at `claude-shared/scripts/repo-dashboard.sh` — run it in a standalone terminal for continuous monitoring
