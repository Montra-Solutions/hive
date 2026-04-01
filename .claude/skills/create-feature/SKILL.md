---
description: Create a feature tracking entry — Obsidian doc, ADO work item, and git branch
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__ado__wit_get_work_item, mcp__ado__wit_create_work_item, mcp__ado__wit_add_child_work_items, AskUserQuestion
---

You are creating a feature tracking entry. This involves creating a local Obsidian documentation file, optionally creating an Azure DevOps Feature work item, and creating a git branch for implementation. Features are higher-level than User Stories and typically decompose into multiple stories.

**Input:** $ARGUMENTS

## Parse Input Mode

First, determine the mode based on the input:

- **Existing Feature Mode**: If the input is a **number** (e.g., `3976`, `4100`), treat it as an existing ADO Feature ID. Go to **Step 1A**.
- **New Feature Mode**: If the input is **text** (a title, description, or feature request), this is a new feature. Go to **Step 1B**.

---

## Step 1A: Fetch Existing ADO Feature

Use the `mcp__ado__wit_get_work_item` tool to fetch the work item from the `montra.io` project using the provided ID. Use `expand: "relations"` to capture child stories.

Extract these fields from the response:
- **Title**: `System.Title`
- **Description**: `System.Description` (may be HTML — convert to plain markdown for the doc)
- **Priority**: `Microsoft.VSTS.Common.Priority` (map: `1` → `critical`, `2` → `high`, `3` → `medium`, `4` → `low`; default `medium` if missing)
- **Target Date**: `Microsoft.VSTS.Scheduling.TargetDate` (if present)
- **Value Area**: `Microsoft.VSTS.Common.ValueArea` (Business or Architectural; default `Business`)
- **Tags**: `System.Tags` (comma-separated string)
- **State**: `System.State`
- **Assigned To**: `System.AssignedTo` (display name)
- **Area Path**: `System.AreaPath` (use the leaf segment as `area`)
- **Iteration Path**: `System.IterationPath` (use the leaf segment as `iteration`)
- **Child Stories**: Extract child work item IDs from relations (relation type contains "Child")

If child stories are found, fetch them with `mcp__ado__wit_get_work_items_batch_by_ids` to get their titles and IDs for the documentation.

Then skip to **Step 2**, using this data to populate the template.

---

## Step 1B: Create New ADO Feature Work Item

Parse the text input intelligently:
- The first sentence or phrase is the **title**
- Everything after is the **description/details**
- If only a title is provided, that's fine — leave detail sections for the user to fill in

### Auto-assign based on platform

Detect the current platform to determine the assignee:

| Platform | Assigned To |
|---|---|
| Windows (`win32`) | Ryan Gordon (`rgordon@montra.io`) |
| macOS (`darwin`) | Jim Stott (`jstott@montra.io`) |

If platform detection is ambiguous, check the OS username via `whoami` — `Ryan Gordon` → Ryan, `jstott` → Jim.

### Create the work item

Use the `mcp__ado__wit_create_work_item` tool to create a Feature in the `montra.io` project with:
- `System.Title`: The feature title parsed from the input
- `System.Description`: The description/details from the input (if provided), formatted as HTML
- `System.Tags`: `via/feature`
- `System.AssignedTo`: The assignee determined above (e.g., `rgordon@montra.io` or `jstott@montra.io`)
- `System.State`: `Active`
- `Custom.UIChangeRequired`: `No`

Capture the returned work item ID. Then continue to **Step 2**.

---

## Step 2: Create the Obsidian Documentation File

Resolve the docs project path based on platform:
- **Windows:** `C:\Users\Ryan Gordon\Projects\docs`
- **macOS:** `/Volumes/ext2G/Developer/montraio/docs`

Create a markdown file at: `docs/Via Initiatives/Active/Features/Feature-{ADO_ID}-{kebab-case-short-title}.md`

Create the `Features` directory if it doesn't exist.

Use this template, filling in what you can from the ADO work item data (fetched or newly created):

```markdown
---
type: feature
status: active
priority: {priority from ADO, or "medium" if unknown}
value_area: {Business or Architectural, from ADO or "Business"}
target_date: {target date from ADO, or blank}
created_date: {today YYYY-MM-DD}
completed_date:
ado_project: montra.io
ado_feature_id: {ADO_ID}
ado_url: https://dev.azure.com/montraio/montra.io/_workitems/edit/{ADO_ID}
area: {area path leaf from ADO, or blank}
iteration: {iteration path leaf from ADO, or blank}
tags:
  - via/feature
  - via/active
---

# Feature-{ADO_ID}: {Title}

> [ADO Work Item {ADO_ID}](https://dev.azure.com/montraio/montra.io/_workitems/edit/{ADO_ID})

## Overview
{description from ADO or input}

## Business Value
<!--
Why this feature matters. Who benefits and how?
-->

## Scope
### In Scope
-

### Out of Scope
-

## User Stories
<!--
Child stories that implement this feature.
-->
{If child stories were fetched from ADO, list them here:}
| ID | Title | State |
|----|-------|-------|
| [{id}](https://dev.azure.com/montraio/montra.io/_workitems/edit/{id}) | {title} | {state} |

## Technical Approach
<!--
High-level architecture, design decisions, key components affected.
-->

## Dependencies
<!--
Other features, external systems, infrastructure, or team dependencies.
-->

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
|      |        |            |

## Implementation
- **Branch:** `feature-{ADO_ID}`
- **PR:**
- **ADO:** [{ADO_ID}](https://dev.azure.com/montraio/montra.io/_workitems/edit/{ADO_ID})

## Progress
<!--
Track milestones, sprint progress, blockers.
Update status to "completed" and set completed_date when done.
Move file to Via Initiatives/Completed/Features/ when closing.
-->
```

**Populating from ADO data:** When using an existing feature (Step 1A), fill in as much as possible:
- **Overview** section: Use `System.Description` content (converted to markdown)
- **User Stories** table: Populated from child work items if relations exist
- **priority** in frontmatter: Mapped from ADO priority field
- **value_area** in frontmatter: From `Microsoft.VSTS.Common.ValueArea`
- **target_date** in frontmatter: From `Microsoft.VSTS.Scheduling.TargetDate`
- **area** in frontmatter: Leaf of `System.AreaPath`
- **iteration** in frontmatter: Leaf of `System.IterationPath`
- **tags** in frontmatter: Include any additional ADO tags beyond `via/feature`

## Step 3: Create Git Branch

Determine the target repo automatically:
- **If the current working directory is inside a project other than `docs`** (e.g., `montra-via-api`, `montra-via-web`, `db`), use that repo directly — no need to ask.
- **If the current working directory is `docs`** or the montraio root, ask the user which repo needs the branch. Common repos:
  - `montra-via-api` (backend)
  - `montra-via-web` (frontend)
  - `db` (database)
  - `fn-api-automation` / `fn-api-jobs` (Azure Functions)

If the feature description clearly implies a single repo (e.g., "dashboard redesign" → `montra-via-web`, "new API module" → `montra-via-api`), suggest that repo but confirm.

Once the target repo is determined, pull latest development first, then create the branch:

```bash
cd {repo_path}
git checkout development
git pull origin development
git checkout -b feature-{ADO_ID}
```

Resolve the repo path based on platform:
- **Windows:** `/c/Users/Ryan Gordon/Projects/{repo}`
- **macOS:** `/Volumes/ext2G/Developer/montraio/{repo}`

The branch name is `feature-{ADO_ID}` (matching the create-pr branch naming convention). You may optionally append a short kebab-case suffix if the title provides a clear short description: `feature-{ADO_ID}-{short-desc}`.

If the user says "skip" or "none" for the branch, that's fine — skip this step.

## Step 4: Confirm

Report back to the user with:
- The ADO Feature ID and link
- Whether the feature was **created new** or **imported from existing**
- Number of child stories (if any were found)
- The path to the created documentation file
- The git branch name and repo (if created)
- Remind them to review and fill in any sections that couldn't be populated from ADO data
