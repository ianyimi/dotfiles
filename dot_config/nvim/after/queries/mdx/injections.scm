;; MDX fenced code block injections for JS/TS

;; JavaScript
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
  (#match? @_lang "^\%(js\|javascript\|jsx\)$")
 (#set! injection.language "javascript")
 (#set! injection.priority 110))

;; TypeScript
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
  (#match? @_lang "^\%(ts\|typescript\)$")
 (#set! injection.language "typescript")
 (#set! injection.priority 110))

;; TSX (TypeScript with JSX)
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
  (#match? @_lang "^tsx$")
 (#set! injection.language "tsx")
 (#set! injection.priority 120))
