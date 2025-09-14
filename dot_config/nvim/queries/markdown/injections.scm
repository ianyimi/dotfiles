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

;; Datacorejsx - JavaScript injection with JSX support (high priority)
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^datacorejsx$")
 (#set! injection.language "javascript")
 (#set! injection.priority 110))

;; MDX fenced code blocks: js/javascript/jsx -> javascript
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^\%(js\|javascript\|jsx\)$")
 (#set! injection.language "javascript")
 (#set! injection.priority 90))

;; MDX fenced code blocks: ts/typescript -> typescript
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^\%(ts\|typescript\)$")
 (#set! injection.language "typescript")
 (#set! injection.priority 90))

;; MDX fenced code blocks: tsx -> tsx (lower priority)
((fenced_code_block
  (info_string) @_lang
  (code_fence_content) @injection.content)
 (#match? @_lang "^tsx$")
 (#set! injection.language "tsx")
 (#set! injection.priority 90))
