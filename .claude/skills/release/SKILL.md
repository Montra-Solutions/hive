---
name: release
description: Generate cross-repo release notes by scanning git logs across montra-via-api, montra-via-web, and montra-via-db. Enriches entries with ADO work item titles, bumps the web repo version, generates release notes markdown, updates releases.json, and creates a release PR targeting development.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, mcp__ado__wit_get_work_item, mcp__ado__wit_get_work_items_batch_by_ids, mcp__ado__repo_get_repo_by_name_or_id, mcp__ado__repo_create_pull_request
---

# Cross-Repo Release Notes

This skill generates release notes by scanning git history across all three core repositories (**montra-via-api**, **montra-via-web**, **montra-via-db**), enriches commit data with Azure DevOps work item titles, bumps the web application version, writes release notes and `releases.json`, and creates a release PR in the web repo.

## Repo Paths

Detect the platform and resolve the base project directory:

```bash
if [[ -d "/c/Users/Ryan Gordon/Projects/montra-via-web" ]]; then
  BASE_DIR="/c/Users/Ryan Gordon/Projects"
elif [[ -d "/Volumes/ext2G/Developer/montraio/montra-via-web" ]]; then
  BASE_DIR="/Volumes/ext2G/Developer/montraio"
else
  echo "ERROR: Cannot locate project directories" && exit 1
fi
```

| Repo | Variable | Path |
|---|---|---|
| API | `API_DIR` | `$BASE_DIR/montra-via-api` |
| Web | `WEB_DIR` | `$BASE_DIR/montra-via-web` |
| DB | `DB_DIR` | `$BASE_DIR/montra-via-db` |

Use these resolved paths in every step below. **All git commands that read release-notes files, package.json, or releases.json operate in the Web repo.**

---

## Step 1: Determine Last Release & Current State

1. Read `$WEB_DIR/public/docs/release-notes/releases.json`
2. Extract the **first** entry's `date` and `buildId` — this is the "since" marker (most recent release)
3. Read `$WEB_DIR/package.json` to get the current `version` field
4. Ask the user:

> **Bump version before generating release notes?**
> - **Yes** (recommended) — run `npm version prerelease --no-git-tag-version` in the web repo, then `node build/generate-version.js` to sync `src/common/version.ts`
> - **No** — use the current version as-is
> - **Custom** — user provides an explicit version string; update `package.json` version field and run `node build/generate-version.js`

After this step you must have a resolved `VERSION` value (e.g. `6.0.4-5`).

---

## Step 2: Gather Changes Across Repos

For **each** of the three repos, fetch and collect commits since the last release date:

```bash
cd "$REPO_DIR"
git fetch origin
git log --oneline --no-merges --after="<last-release-date>" origin/development
```

Parse each commit line to extract:
- **Hash** (short SHA)
- **Conventional commit prefix** if present: `feat`, `fix`, `chore`, `refactor`, `perf`, `docs`, `style`, `test`, `ci`, `build`
- **Work item IDs**: look for the `AB#NNNN` pattern anywhere in the commit message
- **Repo tag**: `[API]`, `[Web]`, or `[DB]` based on which repo the commit came from

For the **DB repo** specifically, also detect new migration files added since the last release:

```bash
cd "$DB_DIR"
git diff --name-only --diff-filter=A origin/development@{"<last-release-date>"}..origin/development -- migrations/
```

If migration files are found, include them as `[DB]` entries under **Database Changes** even if the commit message itself isn't conventionally prefixed.

**Important:** Filter out noise commits:
- Skip commits that are only version bumps (message matches `^\d+\.\d+\.\d+` or starts with `Auto increment build version`)
- Skip merge commits (already excluded by `--no-merges`)

---

## Step 3: Enrich with ADO Work Item Data

1. Collect all unique work item IDs found across all three repos' commits (the numeric part of `AB#NNNN`)
2. If there are work item IDs, batch-fetch them:
   - Use `mcp__ado__wit_get_work_items_batch_by_ids` with `ids` as a comma-separated string of IDs, `project="montra.io"`
   - Process up to 200 IDs per call; if more, make multiple calls
3. Build a map: `workItemId → System.Title`
4. When generating release note bullets:
   - If a commit references a work item ID, **prefer the ADO title** as the bullet description
   - Use the raw commit message as fallback when no work item is linked
   - Group multiple commits that reference the **same** work item ID into a single bullet

---

## Step 4: Categorize & Generate Release Notes

### Categorization Rules

| Category | Commit prefixes | Fallback keywords in message |
|---|---|---|
| **New Features** | `feat` | add, new, implement, introduce, create |
| **Improvements** | `refactor`, `perf`, `style` | improve, enhance, update, optimize, upgrade |
| **Bug Fixes** | `fix` | fix, resolve, correct, patch, hotfix |
| **Database Changes** | any commit from DB repo | migration, schema, seed, alter, index |
| **Technical Changes** | `chore`, `test`, `docs`, `ci`, `build` | dependency, config, pipeline, lint, ci, devops |

**Priority:** If a commit matches multiple categories, use the first match from top to bottom. DB repo commits default to **Database Changes** unless they clearly match a higher category.

### Output Format

Generate a markdown file with this exact structure (matching existing release notes format):

```markdown
---
title: "Release <VERSION>"
description: "<1-2 sentence summary of the most impactful changes>"
excerpt: "<single sentence highlighting the top change>"
date: "<YYYY-MM-DD>"
version: "<VERSION>"
buildId: "<VERSION>"
tags: ["release", "<VERSION>"]
categories: ["releases"]
---

# Release Notes - Version <VERSION>
**Release Date:** <Month Day, Year>
**Build:** <VERSION>

## New Features
- **Feature Name** — Description `[API]`
- **Feature Name** — Description `[Web]`

## Improvements
- **Improvement** — Description `[API]`

## Bug Fixes
- **Bug Title** — Description `[Web]`

## Database Changes
- **Migration description** `[DB]`

## Technical Changes
- **Change** — Description `[API]`
```

### Guidelines

- **Skip empty categories entirely** — do not include a heading with no bullets
- Each bullet: bold title, em-dash, 1-2 sentence description focused on user/developer benefit, repo tag at end
- Include `[API]`, `[Web]`, `[DB]` tags inline so readers know what area changed
- Group related items when multiple commits address the same work item into a single bullet
- Prioritize most impactful changes first within each category
- The `date` in frontmatter should be today's date (the date the release notes are generated)
- `description` and `excerpt` should be written in plain English, not include repo tags

---

## Step 5: Confirm with User

Display the full generated release notes markdown to the user and ask:

> **Does this release note look correct?**
> - **Yes** — proceed to write files and create PR
> - **Edit** — tell the user the file path and stop so they can make manual edits; they can re-invoke the skill after

If the user says **No** or **Edit**, inform them of the planned output path (`$WEB_DIR/public/docs/release-notes/<VERSION>.md`) and stop. Do not write any files.

---

## Step 6: Write Files & Update releases.json

### 6a: Write the release notes markdown

Write the release notes to:
```
$WEB_DIR/public/docs/release-notes/<VERSION>.md
```

### 6b: Update releases.json

1. Read `$WEB_DIR/public/docs/release-notes/releases.json`
2. Build a new entry object from the frontmatter:
   ```json
   {
     "filename": "<VERSION>.md",
     "path": "<VERSION>",
     "title": "Release <VERSION>",
     "description": "<from frontmatter>",
     "excerpt": "<from frontmatter>",
     "date": "<YYYY-MM-DD>",
     "version": "<VERSION>",
     "buildId": "<VERSION>",
     "tags": ["release", "<VERSION>"],
     "categories": ["releases"]
   }
   ```
3. Remove any existing entry with a matching `buildId` or `filename` (prevent duplicates)
4. **Prepend** the new entry to the beginning of the array (most recent first)
5. Write the file back with **2-space JSON indentation**

---

## Step 7: Create Release Branch & PR

### 7a: Prepare the branch

```bash
cd "$WEB_DIR"
git fetch origin
git checkout development
git pull origin development
git checkout -b "release/v<VERSION>"
```

### 7b: Stage and commit

Stage exactly these files:
- `package.json`
- `src/common/version.ts`
- `public/docs/release-notes/<VERSION>.md`
- `public/docs/release-notes/releases.json`

Commit with message:
```
chore(release): generate release notes for <VERSION>
```

### 7c: Push and create PR

```bash
git push -u origin "release/v<VERSION>"
```

Then get the web repo ID and create the PR:

```
mcp__ado__repo_get_repo_by_name_or_id(
  project="montra.io",
  repositoryNameOrId="montra-via-web"
)
```

```
mcp__ado__repo_create_pull_request(
  project="montra.io",
  repositoryId="<repo-id-from-above>",
  sourceRefName="refs/heads/release/v<VERSION>",
  targetRefName="refs/heads/development",
  title="Release: v<VERSION>",
  description="## Release Notes - v<VERSION>\n\n<summary of changes by category and repo>\n\n### Changes by Repo\n- **API:** <count> changes\n- **Web:** <count> changes\n- **DB:** <count> changes\n\n🤖 Generated by Claude Code `/release` skill"
)
```

---

## Step 8: Reset All Repos & Report

After creating the PR, reset all core repos to their default working branch so the workspace is clean for the next task.

For each repo, only switch if the working tree is clean (`git status --porcelain` is empty). Skip and warn if there are uncommitted changes.

| Repo | Default branch |
|---|---|
| `montra-via-api` | `development` |
| `montra-via-web` | `development` |
| `montra-via-db` | `development` |
| `claude-shared` | `development` |
| `docs` | `development` |

```bash
cd "$REPO_DIR"
git checkout {default_branch} 2>/dev/null && git pull 2>/dev/null
```

Then display a summary to the user:

```
Release v<VERSION> — Complete

  Version:  <VERSION>
  Notes:    public/docs/release-notes/<VERSION>.md
  PR:       <PR URL from ADO>

  Changes by repo:
    API: <count>
    Web: <count>
    DB:  <count>

  Repos reset:
    montra-via-api  → development
    montra-via-web  → development
    montra-via-db   → development
    claude-shared   → development
    docs            → development

  Review the PR and merge when ready.
```

---

## Error Handling

- **Repo not found:** If any of the three repo directories don't exist, warn the user and continue with the repos that are available. At minimum the web repo must exist.
- **No commits found:** If no commits are found across any repo since the last release, inform the user and stop — don't generate empty release notes.
- **ADO fetch failure:** If work item enrichment fails, fall back to raw commit messages and warn the user that ADO titles could not be fetched.
- **Git push failure:** If the push fails (e.g. branch already exists), inform the user and suggest they delete the existing branch or use a different version.
- **PR creation failure:** If the ADO PR creation fails, inform the user of the error. The release notes files are already written and committed locally, so they can create the PR manually.

## Notes

- This skill replaces the old web-only commands: `release.md`, `release-notes.md`, and `releases-list.md`
- Project is always `montra.io` for ADO operations
- The skill scans `origin/development` branch across all repos — it captures what will ship when development merges to main
- Version bumping uses `npm version prerelease` which increments the prerelease number (e.g. `6.0.4-4` → `6.0.4-5`)
