---
name: detect-project-type
description: Detect the project type from code signals and reorganize standards folders to match — web app, backend API, CLI, library, dotfiles, mobile, or monorepo.
---

# Detect Project Type and Adapt Standards

Automatically detect the project type and reorganize standards folders to match the project structure. This command runs automatically during project installation but can also be run manually to update standards organization.

## Important Guidelines

- **Always use AskUserQuestion tool** when asking the user anything
- **Detect first, confirm second** — Analyze the codebase then ask user to confirm
- **Update references** — Scan numbered workflow files and update folder references

## Process

### Step 1: Analyze Project Structure

Scan the project to detect its type:

**1a. Check for package managers and frameworks:**
- `package.json` → Node.js/JavaScript project
  - Check for: React, Next.js, Vue, Angular, Svelte (frontend frameworks)
  - Check for: Express, Fastify, NestJS (backend frameworks)
- `Gemfile` → Ruby/Rails project
- `requirements.txt`/`pyproject.toml` → Python/Django/Flask project
- `go.mod` → Go project
- `Cargo.toml` → Rust project
- `composer.json` → PHP/Laravel project
- `.zshrc`, `.bashrc`, `dot_*` files → Dotfiles/Shell configuration project

**1b. Analyze directory structure:**
- Presence of `src/`, `app/`, `pages/` → Web application
- Presence of `cmd/`, `internal/`, `pkg/` → Go application
- Presence of `dot_*`, `run_*`, `.chezmo*` → Chezmoi dotfiles
- Presence of shell scripts, config files → System configuration

**1c. Count file types:**
- `.ts/.tsx/.js/.jsx` files → JavaScript/TypeScript project
- `.py` files → Python project
- `.rb` files → Ruby project
- `.sh/.zsh/.bash` files → Shell script project
- `.yml/.yaml/.toml` config files → Configuration management

### Step 2: Determine Project Type

Based on analysis, classify the project:

**Web Application** (frontend + backend)
- → Use folders: `frontend/`, `backend/`, `global/`, `testing/`

**Backend API**
- → Use folders: `api/`, `database/`, `global/`, `testing/`

**CLI Tool**
- → Use folders: `cli/`, `commands/`, `global/`, `testing/`

**Library/Package**
- → Use folders: `api/`, `implementation/`, `global/`, `testing/`

**Dotfiles/System Configuration**
- → Use folders: `shell/`, `configs/`, `global/`, `tools/`

**Mobile Application**
- → Use folders: `mobile/`, `backend/`, `global/`, `testing/`

**Monorepo/Multi-project**
- → Use folders: `frontend/`, `backend/`, `shared/`, `global/`, `testing/`

### Step 3: Confirm with User

Use AskUserQuestion to verify the detected type:

```
I analyzed your project and detected it as: **[Detected Type]**

Based on this, I'll organize standards into these folders:
- [folder1]/
- [folder2]/
- global/
- [folder3]/

Is this correct?

Options:
1. Yes, that's correct
2. No, it's actually a [different type] project
3. Custom - let me specify the folders
```

If they choose option 2, ask what type it actually is.
If they choose option 3, ask them to specify the folder names.

### Step 4: Reorganize Standards Folders

**4a. Create new folder structure:**

Create `agent-os/standards/` with the determined folders.

**4b. Map existing standards to new folders:**

For Dotfiles/System Configuration:
- `shell/` ← Map from: global/coding-style.md → shell/scripting-style.md
- `configs/` ← Map from: backend/api.md → configs/file-structure.md
- `global/` ← Keep: conventions.md, best-practices.md
- `tools/` ← Map from: frontend/components.md → tools/utilities.md

For CLI Tool:
- `cli/` ← Map from: frontend/components.md → cli/commands.md
- `commands/` ← Map from: backend/api.md → commands/arguments.md
- `global/` ← Keep global standards
- `testing/` ← Keep testing standards

For Backend API:
- `api/` ← Map from: frontend/components.md → api/endpoints.md, backend/api.md
- `database/` ← Keep: backend/models.md, backend/queries.md
- `global/` ← Keep global standards
- `testing/` ← Keep testing standards

**4c. Copy and adapt files:**

For each mapping:
1. Read the source standard file
2. If needed, adapt the content for the new context
3. Write to the new location
4. Delete the old file if it doesn't apply

### Step 5: Update Numbered Workflow Files

Scan all skill/command files that reference standards folders. For each file:
1. Read the content
2. Find all references to old folder paths
3. Replace with new folder paths based on mapping
4. Write updated content back

### Step 6: Update Standards Index

Update `agent-os/standards/index.yml` with the new folder structure.

### Step 7: Report Results

```
✓ Project type detected: [Type]

Standards reorganized:
  - [old-folder]/ → [new-folder]/ ([N] files)
  - global/ (unchanged)

Workflow files updated: [N] files

Standards are now organized for your [project type] project!
```

## Usage

Run manually to reorganize existing standards:
```
/detect-project-type
```

Or called automatically by `/pi-project-setup` during new project bootstrap.
