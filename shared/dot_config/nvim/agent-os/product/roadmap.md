# Product Roadmap

This roadmap focuses on iterative improvements to the personal Neovim configuration. Each item represents a complete, testable enhancement to the development workflow.

## Current Priority: Workflow Optimization

1. [ ] LSP Performance Tuning — Profile and optimize LSP server startup times, add debouncing to diagnostics, and implement conditional loading for rarely-used language servers. Test with large TypeScript/Go projects. `M`

2. [ ] Enhanced Git Workflow Integration — Add inline git blame with virtual text, improve diffview.nvim keybindings, integrate git conflict resolution helpers, and create custom commands for common git operations (fixup, rebase helpers, etc.). `M`

3. [ ] Project Template System — Create telescope picker for project templates (React, Go API, etc.) that scaffolds new projects with preferred structure, initializes git worktrees, and sets up tmuxinator sessions automatically. `L`

4. [ ] Custom Statusline Components — Extend lualine with custom components for LSP status, git worktree indicator, active AI model, and performance metrics. Make it easier to see system state at a glance. `S`

5. [ ] Snippet Library Expansion — Add custom snippets for common patterns in frequently-used languages (Go error handling, React hooks, TypeScript types), organize by project type, and create snippet picker UI. `S`

6. [ ] AI Tool Workflow Refinement — Optimize Avante and OpenCode keybindings for common operations, add custom prompts for frequent tasks, integrate with project-specific context, and create toggle for AI features when not needed. `M`

7. [ ] Documentation and Code Navigation — Enhance LSP navigation with better preview windows, add custom telescope pickers for project-specific navigation patterns, integrate outline view for current file structure. `M`

8. [ ] Testing Integration — Add test runner integration (Go test, Jest, etc.) with inline results display, create keybindings for running tests under cursor/file/suite, and integrate with terminal management. `L`

9. [ ] Session Management Enhancement — Improve auto-session behavior for different project types, add session templates, create session switcher with preview, and handle tmux session integration more intelligently. `M`

10. [ ] Performance Dashboard — Create command to display startup performance, plugin load times, LSP responsiveness metrics, and provide recommendations for optimization. Add continuous monitoring. `S`

> Notes
> - Items ordered by typical workflow dependencies and architectural considerations
> - Focus is on incremental improvements that enhance daily development without major rewrites
> - Each item should be tested in the chezmoi source directory before applying to live config
> - Effort estimates based on single developer implementing in spare time
