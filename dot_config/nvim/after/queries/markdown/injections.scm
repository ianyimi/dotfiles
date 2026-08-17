;; extends
;;
;; Adds mdx.nvim's inline import/export/JSX rules on top of the fenced-block
;; rules below, rather than replacing the chain.
;;
;; Cost, measured on a real 3761-line spec: +32 injected typescript regions
;; (32 -> 64) and +28% on a full injection re-resolution (63.9 -> 82.0 ms).
;;
;; That is affordable ONLY because after/ftplugin/markdown.lua stops the
;; treesitter highlighter above vim.g.markdown_ts_highlight_max_lines. Without
;; that gate the highlighter re-resolved injections roughly once per visible
;; line, so this same 28% was multiplying into ~1.1s stalls on every redraw.
;; With the gate, the only consumers are render-markdown and
;; treesitter-context -- about +48ms across a 2-minute session.
;;
;; If the gate is ever removed or its threshold raised, re-measure before
;; keeping this line. Note it does NOT control markdown_inline (428 regions in
;; that file); those are injected by Nvim core.
;; Dataviewjs - JavaScript injection (high priority)
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^dataviewjs$")
 (#set! injection.language "javascript")
 (#set! injection.priority 110))

;; Datacoretsx - TypeScript JSX injection (high priority)
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^datacoretsx$")
 (#set! injection.language "tsx")
 (#set! injection.priority 120))

;; TypeScript in fenced blocks
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^\%(ts\|typescript\)$")
 (#set! injection.language "typescript"))

;; TypeScript JSX
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^\%(tsx\|typescript\.jsx\)$")
 (#set! injection.language "tsx"))

;; JavaScript
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^\%(js\|javascript\|jsx\)$")
 (#set! injection.language "javascript"))

;; JSON
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^json5?$")
 (#set! injection.language "json"))

;; YAML
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^ya?ml$")
 (#set! injection.language "yaml"))

;; Bash/Shell
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^\%(bash\|sh\|shell\)$")
 (#set! injection.language "bash"))
