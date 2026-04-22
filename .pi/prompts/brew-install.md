---
description: Research package installation methods and add them as Ansible tasks to the appropriate section of macos.yml playbook (Apps or CLI).
---

# Brew Install

Add one or more packages to the macOS Ansible playbook. Agent researches how to install each package and adds the appropriate tasks to either the "Brew Install (Apps)" or "Brew Install (CLI)" section based on what the package is.

---

> **Questions:** Use the `ask_user_question` tool for every question in this prompt. Never write question lists as plain text.

## Process

### Step 1 — Gather package names

Ask:
> What package(s) should I add? (Provide one or more package names, comma-separated or one per line)

Parse the input into a list of package names.

### Step 2 — Research each package

For each package, follow this research flow:

#### 2a. Try Homebrew first

Run these commands to check if the package is available via Homebrew:

```bash
brew search <package-name>
brew info <package-name> 2>/dev/null || brew info --cask <package-name> 2>/dev/null
```

From the output, determine:
- **Is it a cask?** (GUI application) → `community.general.homebrew_cask`
- **Is it a formula?** (CLI tool) → `community.general.homebrew`
- **Does it require a custom tap?** (e.g., `nikitabobko/tap/aerospace`, `sst/tap/opencode`)
  - If yes, note the tap name — we'll add a tap task before the install task

#### 2b. If not found in Homebrew

Research the package online:
- Check the official installation docs (GitHub README, project website)
- Determine the installation method:
  - **npm package** → `community.general.npm` task
  - **Direct curl install** → `ansible.builtin.shell` with curl command
  - **Custom install script** → `ansible.builtin.shell` task
- Determine what it is:
  - **GUI application** → goes in "Brew Install (Apps)" section
  - **CLI tool or library** → goes in "Brew Install (CLI)" section

#### 2c. Classify the package

Based on what the package **is** (not how it's installed):

| What it is | Section | Examples |
|------------|---------|----------|
| GUI application, desktop app | "Brew Install (Apps)" | Spotify, Arc, Obsidian, Ghostty, Docker Desktop |
| CLI tool, library, language runtime | "Brew Install (CLI)" | git, fzf, neovim, tmux, kubectl, npm packages |

**Exception:** Fonts go in "Brew Install (Fonts)" section (if adding fonts, create tasks in that section)

### Step 3 — Check for duplicates

Read `dot_bootstrap/macos.yml` and search for the package name in task names.

If found:
- Note: "Package `<name>` is already in the playbook, skipping."
- Continue to next package

### Step 4 — Generate Ansible task(s)

For each package not already in the playbook, generate the appropriate task block(s).

#### Homebrew cask (GUI app)

```yaml
    - name: Check Install - <App Name>
      community.general.homebrew_cask:
        name: <cask-name>
        state: present
      ignore_errors: true
```

#### Homebrew formula (CLI tool)

```yaml
    - name: Check Install - <Tool Name>
      community.general.homebrew:
        name: <formula-name>
        state: present
```

#### Custom tap (add BEFORE the install task)

```yaml
    - name: Tap <tap-name>
      become: true
      become_user: "{{ brew_user }}"
      community.general.homebrew_tap:
        name: <tap-name>
        state: present
```

#### npm package (global)

```yaml
    - name: Check Install - <package-name>
      community.general.npm:
        name: <package-name>
        global: true
        state: present
```

#### Direct curl/shell install

```yaml
    - name: Check if <Package> is installed
      ansible.builtin.command: which <command-name>
      register: <package>_check
      failed_when: false
      changed_when: false

    - name: Install <Package>
      ansible.builtin.shell: <installation command from docs>
      when: <package>_check.rc != 0
```

### Step 5 — Insert into the correct section

Read `dot_bootstrap/macos.yml` and locate the appropriate section:

- **"Brew Install (Apps)"** — for GUI applications (starts at line with `- name: Brew Install (Apps)`)
- **"Brew Install (CLI)"** — for CLI tools (starts at line with `- name: Brew Install (CLI)`)
- **"Brew Install (Fonts)"** — for fonts (if applicable)
- **"Brew Install (Languages)"** — for language runtimes (if applicable)

**Insertion strategy:**
- Append new tasks to the end of the `tasks:` list in the appropriate section
- Maintain consistent indentation (2-space indent for YAML)
- Add a blank line before each new task block for readability

**Custom taps:**
- If a package requires a tap, add the tap task **before** the install task
- If the tap task already exists in the file, skip it

### Step 6 — Write the updated playbook

Save the modified `dot_bootstrap/macos.yml` with the new tasks added.

### Step 7 — Report completion

Summarize what was added:

```
✓ Added to macos.yml:

Apps (Brew Install (Apps)):
- <App 1>
- <App 2>

CLI (Brew Install (CLI)):
- <Tool 1> (requires tap: <tap-name>)
- <Tool 2> (npm package)
- <Tool 3> (direct install)

Skipped (already installed):
- <Package 4>

Changes saved to dot_bootstrap/macos.yml
```

---

## Inputs

| Input | Source |
|-------|--------|
| Package name(s) | Ask user (one or more, comma-separated or line-separated) |
| Installation method | Auto-detected via `brew search` + `brew info` + online research |
| Section (Apps vs CLI) | Auto-classified based on what the package is |

## Output

- **Updated file:** `dot_bootstrap/macos.yml`
- **Changes:** New Ansible tasks added to the appropriate section(s)
- **Report:** Summary of what was added, what was skipped

---

## Edge Cases

**Package not found anywhere:**
- Report: "Could not find installation method for `<package>`. Please verify the package name or provide installation instructions."
- Skip that package, continue with others

**Package requires special configuration:**
- Add the basic install task
- Note in the report: "Package `<name>` may require additional configuration. Check the official docs."

**Multiple packages with the same base name:**
- If `brew search` returns multiple matches (e.g., `neovim` vs `neovim-nightly`), ask which one to install

**Platform-specific packages:**
- If a package is macOS-only or has platform-specific variants, note it in the task name
- Example: "Check Install - <Package> (macOS)" if it's not available on Linux

**Version pinning:**
- If the package is typically version-pinned (like flyctl, pulumi), suggest adding a var:
  - Add to `vars:` section at the top of "Brew Install (CLI)" play
  - Reference in the task: `name: <package>@{{ <package>_version }}`

**Packages installed via Ansible blocks:**
- Some packages use `block:` with multiple tasks (like gh, pnpm, Claude Code)
- If the package requires multi-step installation, create a full block structure

---

## Examples

### Example 1: Simple Homebrew cask

**Input:** `raycast`

**Research:**
```bash
brew search raycast
# → Found: raycast (cask)
brew info --cask raycast
# → GUI app, productivity tool
```

**Classification:** GUI app → "Brew Install (Apps)"

**Generated task:**
```yaml
    - name: Check Install - Raycast
      community.general.homebrew_cask:
        name: raycast
        state: present
      ignore_errors: true
```

---

### Example 2: CLI tool with custom tap

**Input:** `aerospace`

**Research:**
```bash
brew search aerospace
# → Found: nikitabobko/tap/aerospace (cask)
```

**Classification:** Window manager (GUI-ish, but listed under system config) → Could go in "Brew Install (Apps)" but check existing pattern in playbook (it's at the end under its own play)

**Generated tasks:**
```yaml
    - name: Tap nikitabobko/tap
      community.general.homebrew_tap:
        name: nikitabobko/tap
        state: present

    - name: Check Install - Aerospace
      community.general.homebrew_cask:
        name: nikitabobko/tap/aerospace
        state: present
```

---

### Example 3: npm package

**Input:** `typescript`

**Research:**
- Not in Homebrew (or available but typically installed via npm)
- Official docs recommend: `npm install -g typescript`

**Classification:** CLI tool → "Brew Install (CLI)"

**Generated task:**
```yaml
    - name: Check Install - TypeScript
      community.general.npm:
        name: typescript
        global: true
        state: present
```

---

### Example 4: Direct curl install

**Input:** `bun`

**Research:**
- Not in Homebrew (or outdated)
- Official install: `curl -fsSL https://bun.sh/install | bash`

**Classification:** CLI tool → "Brew Install (CLI)"

**Generated tasks:**
```yaml
    - name: Check if Bun is installed
      ansible.builtin.command: which bun
      register: bun_check
      failed_when: false
      changed_when: false

    - name: Install Bun
      ansible.builtin.shell: curl -fsSL https://bun.sh/install | bash
      when: bun_check.rc != 0
```

---

## Research Strategy

1. **Always try `brew search` first** — it's the fastest way to check availability
2. **Check `brew info`** — tells you if it's a cask or formula, and lists dependencies
3. **If not in Homebrew:**
   - Search GitHub for the package name
   - Check the README for "Installation" or "Getting Started"
   - Look for package managers mentioned (npm, cargo, go install, pip, etc.)
4. **Classify by what it is, not how it installs:**
   - Does it have a GUI? → App
   - Is it a command-line tool? → CLI
   - Is it a font? → Fonts
   - Is it a language runtime? → Languages (if a dedicated section exists)

---

## What to avoid

- Never add duplicate tasks (always check existing playbook first)
- Never modify existing tasks (only add new ones)
- Never remove or reorder existing tasks
- Never add packages to the wrong section (Apps vs CLI matters for organization)
- Never add tasks without researching the correct installation method
- Never assume installation method without verifying (some packages are NOT in Homebrew)
