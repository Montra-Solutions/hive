---
description: Create a user story tracking entry — Obsidian doc, ADO work item, and git branch
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__ado__wit_get_work_item, mcp__ado__wit_create_work_item, mcp__ado__wit_work_items_link, AskUserQuestion
---

You are creating a user story tracking entry. This involves creating a local Obsidian documentation file, optionally creating an Azure DevOps User Story work item, and creating a git branch for implementation.

**Input:** $ARGUMENTS

## Parse Input Mode

First, determine the mode based on the input:

- **Existing Story Mode**: If the input is a **number** (e.g., `3977`, `4201`), treat it as an existing ADO User Story ID. Go to **Step 1A**.
- **New Story Mode**: If the input is **text** (a title, description, or user story), this is a new story. Go to **Step 1B**.

---

## Step 1A: Fetch Existing ADO User Story

Use the `mcp__ado__wit_get_work_item` tool to fetch the work item from the `montra.io` project using the provided ID. Use `expand: "relations"` to capture parent/child links.

Extract these fields from the response:
- **Title**: `System.Title`
- **Description**: `System.Description` (may be HTML — convert to plain markdown for the doc)
- **Acceptance Criteria**: `Microsoft.VSTS.Common.AcceptanceCriteria` (if present — convert HTML to markdown)
- **Priority**: `Microsoft.VSTS.Common.Priority` (map: `1` → `critical`, `2` → `high`, `3` → `medium`, `4` → `low`; default `medium` if missing)
- **Story Points**: `Microsoft.VSTS.Scheduling.StoryPoints` (if present)
- **Tags**: `System.Tags` (comma-separated string)
- **State**: `System.State`
- **Assigned To**: `System.AssignedTo` (display name)
- **Area Path**: `System.AreaPath` (use the leaf segment as `area`)
- **Iteration Path**: `System.IterationPath` (use the leaf segment as `iteration`)
- **Parent**: Check relations for parent link (Feature ID if present)

Then skip to **Step 2**, using this data to populate the template.

---

## Step 1B: Create New ADO User Story Work Item

Parse the text input intelligently:
- If the input starts with "As a..." treat the whole thing as the title
- Otherwise the first sentence or phrase is the **title**
- Everything after is the **description/acceptance criteria**
- If only a title is provided, that's fine — leave detail sections for the user to fill in

### Prompt for Parent Feature

Before creating the work item, ask the user:

> **Should this story be a child of an existing Feature?**
> If yes, provide the Feature work item ID (e.g., `3976`). If no, just say "no" or "skip".

If a parent Feature ID is provided:
1. Fetch the feature with `mcp__ado__wit_get_work_item` to confirm it exists and show the title
2. Store the feature ID for linking after story creation

### Create the Work Item

### Auto-assign based on platform

Detect the current platform to determine the assignee:

| Platform | Assigned To |
|---|---|
| Windows (`win32`) | Ryan Gordon (`rgordon@montra.io`) |
| macOS (`darwin`) | Jim Stott (`jstott@montra.io`) |

If platform detection is ambiguous, check the OS username via `whoami` — `Ryan Gordon` → Ryan, `jstott` → Jim.

### Create the work item

Use the `mcp__ado__wit_create_work_item` tool to create a User Story in the `montra.io` project with:
- `System.Title`: The story title parsed from the input
- `System.Description`: The description from the input (if provided), formatted as HTML
- `System.Tags`: `via/story`
- `System.AssignedTo`: The assignee determined above (e.g., `rgordon@montra.io` or `jstott@montra.io`)
- `System.State`: `Active`
- `Custom.UIChangeRequired`: `No`

Capture the returned work item ID.

### Link to Parent Feature (if provided)

If a parent Feature ID was provided, use `mcp__ado__wit_work_items_link` to create the parent-child relationship:
```
mcp__ado__wit_work_items_link(
  project="montra.io",
  updates=[{
    "id": {new_story_id},
    "linkToId": {parent_feature_id},
    "type": "parent"
  }]
)
```

Then continue to **Step 2**, setting `parent_feature_id` in the frontmatter.

---

## Step 2: Create the Obsidian Documentation File

Resolve the docs project path based on platform:
- **Windows:** `C:\Users\Ryan Gordon\Projects\docs`
- **macOS:** `/Volumes/ext2G/Developer/montraio/docs`

Create a markdown file at: `docs/Via Initiatives/Active/Features/Stories/Story-{ADO_ID}-{kebab-case-short-title}.md`

Create the `Features/Stories` directory if it doesn't exist.

Use this template, filling in what you can from the ADO work item data (fetched or newly created):

```markdown
---
type: story
status: active
priority: {priority from ADO, or "medium" if unknown}
story_points: {story points from ADO, or blank}
reported_date: {today YYYY-MM-DD}
completed_date:
ado_project: montra.io
ado_story_id: {ADO_ID}
ado_url: https://dev.azure.com/montraio/montra.io/_workitems/edit/{ADO_ID}
parent_feature_id: {parent feature ID from ADO, or blank}
area: {area path leaf from ADO, or blank}
iteration: {iteration path leaf from ADO, or blank}
tags:
  - via/story
  - via/active
---

# Story-{ADO_ID}: {Title}

> [ADO Work Item {ADO_ID}](https://dev.azure.com/montraio/montra.io/_workitems/edit/{ADO_ID})

## Parent Feature
{If parent_feature_id is set: "[Feature {parent_feature_id}: {feature_title}](https://dev.azure.com/montraio/montra.io/_workitems/edit/{parent_feature_id})" — otherwise remove this section}

## User Story
{description from ADO or input — ideally "As a [role], I want [goal] so that [benefit]"}

## Acceptance Criteria
{acceptance criteria from ADO if available, otherwise:}
- [ ]
- [ ]
- [ ]

## Technical Notes
<!--
Implementation approach, architectural considerations, dependencies, etc.
-->

## Tasks
<!--
Break down into implementation tasks if needed.
-->
- [ ]
- [ ]

## Dependencies
<!--
Other stories, features, or external dependencies.
-->

## Implementation
- **Branch:** `story-{ADO_ID}`
- **PR:**
- **ADO:** [{ADO_ID}](https://dev.azure.com/montraio/montra.io/_workitems/edit/{ADO_ID})

## Notes
<!--
Fill in when closing. Move file to Via Initiatives/Completed/Features/Stories/ when done.
Update status to "completed" and set completed_date in frontmatter.
-->
```

**Populating from ADO data:** When using an existing story (Step 1A), fill in as much as possible:
- **User Story** section: Use `System.Description` content (converted to markdown)
- **Acceptance Criteria**: Use `Microsoft.VSTS.Common.AcceptanceCriteria` if present (converted to markdown)
- **priority** in frontmatter: Mapped from ADO priority field
- **story_points** in frontmatter: From `Microsoft.VSTS.Scheduling.StoryPoints`
- **area** in frontmatter: Leaf of `System.AreaPath`
- **iteration** in frontmatter: Leaf of `System.IterationPath`
- **tags** in frontmatter: Include any additional ADO tags beyond `via/story`

## Step 3: Create Git Branch

Determine the target repo automatically:
- **If the current working directory is inside a project other than `docs`** (e.g., `montra-via-api`, `montra-via-web`, `db`), use that repo directly — no need to ask.
- **If the current working directory is `docs`** or the montraio root, ask the user which repo needs the branch. Common repos:
  - `montra-via-api` (backend)
  - `montra-via-web` (frontend)
  - `db` (database)
  - `fn-api-automation` / `fn-api-jobs` (Azure Functions)

If the story description clearly implies a single repo (e.g., "UI component" → `montra-via-web`, "API endpoint" → `montra-via-api`), suggest that repo but confirm.

Once the target repo is determined, pull latest development first, then create the branch:

```bash
cd {repo_path}
git checkout development
git pull origin development
git checkout -b story-{ADO_ID}
```

Resolve the repo path based on platform:
- **Windows:** `/c/Users/Ryan Gordon/Projects/{repo}`
- **macOS:** `/Volumes/ext2G/Developer/montraio/{repo}`

The branch name is `story-{ADO_ID}` (matching the create-pr branch naming convention). You may optionally append a short kebab-case suffix if the title provides a clear short description: `story-{ADO_ID}-{short-desc}`.

If the user says "skip" or "none" for the branch, that's fine — skip this step.

## Step 4: Confirm

Report back to the user with:
- The ADO User Story ID and link
- Whether the story was **created new** or **imported from existing**
- Parent Feature ID and title (if linked)
- The path to the created documentation file
- The git branch name and repo (if created)
- Remind them to review and fill in any sections that couldn't be populated from ADO data
