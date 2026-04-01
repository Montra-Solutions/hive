---
description: Create a bug tracking entry — Obsidian doc, ADO work item, and git branch
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__ado__wit_get_work_item, mcp__ado__wit_create_work_item, AskUserQuestion
---

You are creating a bug tracking entry. This involves creating a local Obsidian documentation file, optionally creating an Azure DevOps Bug work item, and creating a git branch for the fix.

**Input:** $ARGUMENTS

## Parse Input Mode

First, determine the mode based on the input:

- **Existing Bug Mode**: If the input is a **number** (e.g., `3855`, `4012`), treat it as an existing ADO Bug ID. Go to **Step 1A**.
- **New Bug Mode**: If the input is **text** (a title, description, or bug report), this is a new bug. Go to **Step 1B**.

---

## Step 1A: Fetch Existing ADO Bug

Use the `mcp__ado__wit_get_work_item` tool to fetch the work item from the `montra.io` project using the provided ID.

Extract these fields from the response:
- **Title**: `System.Title`
- **Description**: `System.Description` (may be HTML — convert to plain markdown for the doc)
- **Repro Steps**: `Microsoft.VSTS.TCM.ReproSteps` (if present — convert HTML to markdown)
- **Severity**: `Microsoft.VSTS.Common.Severity` (map: `1 - Critical` → `critical`, `2 - High` → `high`, `3 - Medium` → `medium`, `4 - Low` → `low`; default `medium` if missing)
- **Tags**: `System.Tags` (comma-separated string)
- **State**: `System.State`
- **Assigned To**: `System.AssignedTo` (display name)
- **Area Path**: `System.AreaPath` (use the leaf segment as `affected_area`)

Then skip to **Step 2**, using this data to populate the template.

---

## Step 1B: Create New ADO Bug Work Item

Parse the text input intelligently:
- The first sentence or phrase is the **title**
- Everything after is the **description/details**
- If only a title is provided, that's fine — leave description sections for the user to fill in

### Auto-assign based on platform

Detect the current platform to determine the assignee:

| Platform | Assigned To |
|---|---|
| Windows (`win32`) | Ryan Gordon (`rgordon@montra.io`) |
| macOS (`darwin`) | Jim Stott (`jstott@montra.io`) |

If platform detection is ambiguous, check the OS username via `whoami` — `Ryan Gordon` → Ryan, `jstott` → Jim.

### Create the work item

Use the `mcp__ado__wit_create_work_item` tool to create a Bug in the `montra.io` project with:
- `System.Title`: The bug title parsed from the input
- `System.Description`: The description/details from the input (if provided), formatted as HTML
- `System.Tags`: `via/bug`
- `System.AssignedTo`: The assignee determined above (e.g., `rgordon@montra.io` or `jstott@montra.io`)
- `System.State`: `Active`
- `Custom.UIChangeRequired`: `No`

Capture the returned work item ID. Then continue to **Step 2**.

---

## Step 2: Create the Obsidian Documentation File

Resolve the docs project path based on platform:
- **Windows:** `C:\Users\Ryan Gordon\Projects\docs`
- **macOS:** `/Volumes/ext2G/Developer/montraio/docs`

Create a markdown file at: `docs/Via Initiatives/Active/Bugs/Bug-{ADO_ID}-{kebab-case-short-title}.md`

Use this template, filling in what you can from the ADO work item data (fetched or newly created):

```markdown
---
type: bug
status: active
severity: {severity from ADO, or "medium" if unknown}
reported_date: {today YYYY-MM-DD}
resolved_date:
ado_project: montra.io
ado_bug_id: {ADO_ID}
ado_url: https://dev.azure.com/montraio/montra.io/_workitems/edit/{ADO_ID}
affected_area: {area path leaf from ADO, or blank}
tags:
  - via/bug
  - via/active
---

# Bug-{ADO_ID}: {Title}

> [ADO Work Item {ADO_ID}](https://dev.azure.com/montraio/montra.io/_workitems/edit/{ADO_ID})

## Symptoms
{description from ADO or input, or leave placeholder comment}

## Steps to Reproduce
{repro steps from ADO if available, otherwise:}
1.
2.
3.

## Expected Behavior


## Actual Behavior


## Environment
- **Tenant:**
- **Environment:** production | staging | local
- **Browser/Client:**

## Investigation Notes


## Root Cause


## Fix
- **PR:**
- **ADO:** [{ADO_ID}](https://dev.azure.com/montraio/montra.io/_workitems/edit/{ADO_ID})

## Resolution
<!--
Fill in when closing. Move file to Via Initiatives/Completed/Bugs/ when done.
Update status to "resolved" and set resolved_date in frontmatter.
-->
```

**Populating from ADO data:** When using an existing bug (Step 1A), fill in as much as possible:
- **Symptoms** section: Use `System.Description` content (converted to markdown)
- **Steps to Reproduce**: Use `Microsoft.VSTS.TCM.ReproSteps` if present (converted to markdown)
- **severity** in frontmatter: Mapped from ADO severity field
- **affected_area** in frontmatter: Leaf of `System.AreaPath`
- **tags** in frontmatter: Include any additional ADO tags beyond `via/bug`

## Step 3: Create Git Branch

Determine the target repo automatically:
- **If the current working directory is inside a project other than `docs`** (e.g., `montra-via-api`, `montra-via-web`, `db`), use that repo directly — no need to ask.
- **If the current working directory is `docs`** or the montraio root, ask the user which repo needs the branch. Common repos:
  - `montra-via-api` (backend)
  - `montra-via-web` (frontend)
  - `db` (database)
  - `fn-api-automation` / `fn-api-jobs` (Azure Functions)

If the bug description clearly implies a single repo (e.g., "UI button broken" → `montra-via-web`, "API returns 500" → `montra-via-api`), suggest that repo but confirm.

Once the target repo is determined, pull latest development first, then create the branch:

```bash
cd {repo_path}
git checkout development
git pull origin development
git checkout -b bug-{ADO_ID}
```

Resolve the repo path based on platform:
- **Windows:** `/c/Users/Ryan Gordon/Projects/{repo}`
- **macOS:** `/Volumes/ext2G/Developer/montraio/{repo}`

The branch name is `bug-{ADO_ID}` (matching the existing convention). You may optionally append a short kebab-case suffix if the title provides a clear short description: `bug-{ADO_ID}-{short-desc}`.

If the user says "skip" or "none" for the branch, that's fine — skip this step.

## Step 4: Confirm

Report back to the user with:
- The ADO Bug ID and link
- Whether the bug was **created new** or **imported from existing**
- The path to the created documentation file
- The git branch name and repo (if created)
- Remind them to review and fill in any sections that couldn't be populated from ADO data
