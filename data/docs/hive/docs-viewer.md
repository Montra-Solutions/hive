---
type: Feature Guide
status: active
---

# Docs Viewer

The Docs tab is a built-in markdown viewer and editor with git integration. It serves documentation straight from a directory on disk — no separate wiki or CMS needed. It supports Obsidian-compatible syntax (callouts, wiki-links, image embeds) and lets you edit, commit, and push without leaving the dashboard.

## Configuration

Set the docs directory in `dashboard.config.json`:

```json
{
  "docsDir": "data/docs"
}
```

This can be a relative path (resolved from the project root) or an absolute path. If not set, it defaults to `data/docs` inside the HIVE directory.

The directory can be its own git repo or part of a larger repo. Git operations (pull, push, commit) run against whatever repo contains the docs directory.

### Skipped Directories

These directories are excluded from the file tree by default:

- `.git`
- `node_modules`
- `.obsidian`
- `.trash`

Configure with `docsSkipDirs` in the config if you need to change these.

## File Tree

The left sidebar shows a hierarchical file tree of all `.md` files in the docs directory.

### Sorting

- Directories appear before files
- Within files, `_Index.md` always appears first (use it as a directory landing page)
- Everything else is alphabetical

### Interactions

- **Click a file** to open it in a new tab (or switch to its tab if already open)
- **Click a directory** to expand/collapse its children
- **Share button** (link icon) on each file copies a deep link URL to clipboard

### Change Indicators

When files have uncommitted git changes:

- Files get highlighted in peach/orange with a bullet (•) badge
- Directories containing changed files also show the badge
- The git status bar shows "N changed" or "clean"

## Multi-Tab Support

Open multiple documents simultaneously. Each tab tracks its own:

- Rendered content and scroll position
- Edit state (viewing vs editing)
- Raw markdown and parsed frontmatter

Tabs persist across page reloads. Drag tabs to reorder them.

## Markdown Rendering

Standard GitHub Flavored Markdown is supported — headers, bold, italic, lists, tables, blockquotes, code blocks, task lists, strikethrough. Code blocks get syntax highlighting via highlight.js with the Catppuccin Mocha theme.

### Obsidian Callouts

```markdown
> [!info] Optional Title
> Content goes here.
> Multiple lines supported.

> [!warning]
> This is a warning without a custom title.
```

Supported callout types: `info`, `warning`, `danger`, `error`, `tip`, `success`, `note`, `example`, `quote`. Each type has distinct border and background colors.

### Wiki-Links

Link to other documents in the vault:

```markdown
[[path/to/document]]              Links to path/to/document.md
[[path/to/document|Display Text]] Custom link text
[[DocumentName]]                  Searches vault by filename
```

Clicking a wiki-link opens the target document in a new tab. Links are rendered in the theme's mauve color.

### Image Embeds

```markdown
![[image.png]]
![[subfolder/screenshot.jpg]]
```

Supported formats: PNG, JPG, JPEG, GIF, SVG, WebP, BMP. The server looks for images in this order:

1. `assets/` subfolder next to the document
2. `assets/` folder at the vault root

Images are served through `/api/docs/asset`.

## Frontmatter

YAML frontmatter at the top of a file is parsed and displayed as badges:

```markdown
---
type: Architecture
status: Active
severity: High
---
```

Special fields with styled badges:

| Field | Style |
|-------|-------|
| `type` | Blue badge |
| `status` | Green badge |
| `severity: critical` | Red badge |
| `severity: high` | Orange badge |
| `severity: medium` | Yellow badge |
| `severity: low` | Teal badge |

Other frontmatter fields appear as gray badges with the key as a tooltip.

## Editing

Click **Edit** to switch to a plain-text textarea showing the raw markdown (including frontmatter). Changes are local until you save.

### Keyboard Shortcuts

- **Ctrl+S** — Save the current document
- **Tab** — Insert a tab character (Ctrl+Tab to move focus)

### Wiki-Link Autocomplete

While editing, type `[[` to trigger an autocomplete dropdown showing matching files from the vault. Navigate with arrow keys, accept with Enter or Tab, dismiss with Escape.

### Saving

Click **Save** or press Ctrl+S. The file is written to disk via `PUT /api/docs/file`. The tree cache is invalidated and git status refreshes automatically.

## Search

Type at least 2 characters in the search box at the top of the sidebar. Results show matching file names and content snippets (with surrounding context). Click a result to open that document. Clear the search box to restore the full tree.

Results are sorted with filename matches first, then content matches, up to 50 results.

## Creating Files & Folders

Use the toolbar buttons above the tree:

- **New File** — Creates a `.md` file with default frontmatter template
- **New Folder** — Creates a directory

New files start with:

```markdown
---
type:
status: active
---
```

## Git Integration

The git bar at the top of the sidebar shows the current branch and change count.

### Pull

Click **Pull** to run `git pull` in the docs directory. The tree and current document reload automatically.

### Push

Click **Push** to commit and push all changes. You'll be prompted for a commit message. The sequence is:

1. `git add -A` (stage everything)
2. `git commit -m "your message"`
3. `git push`

If there are no changes, it reports "Nothing to commit."

### Status

Shows "N changed" (in peach) when there are uncommitted changes, or "clean" (in green) when everything is committed. Only counts changes within the docs directory, not the entire repo.

## Deep Linking

Every document has a shareable URL in the format:

```
http://localhost:3333/#docs/path/to/file.md
```

Click the share button (link icon) on any file in the tree to copy its URL. Pasting this URL in a browser opens the dashboard directly to that document. Browser back/forward navigation works with the hash-based routing.

## Sidebar

The sidebar is resizable — drag the edge to adjust width (160–600px range). Your preferred width is saved to localStorage.
