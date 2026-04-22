/**
 * vim-powerline combined extension
 * 
 * Combines:
 * - vim/vim-main.ts: ModalEditor with vim keybindings
 * - powerline/powerline-main.ts: Full powerline status bar
 * 
 * We've modified powerline/bash-mode/editor.ts to extend ModalEditor
 * instead of CustomEditor, so both work together natively.
 */

import powerlineExtension from "./powerline/powerline-main.ts";

// Just export powerline - it now extends ModalEditor
export default powerlineExtension;

// Re-export ModalEditor for other extensions
export { ModalEditor } from "./vim/vim-main.ts";
