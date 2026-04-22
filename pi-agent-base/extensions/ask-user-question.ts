import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Editor, type EditorTheme, Key, matchesKey, Text, truncateToWidth } from "@mariozechner/pi-tui";

interface QuestionOption {
	label: string;
	description: string;
}

interface QuestionDef {
	question: string;
	header: string;
	options: QuestionOption[];
	multiSelect?: boolean;
}

interface QuestionState {
	selected: Set<number>;
	customText: string;
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "ask_user_question",
		description:
			"Ask the user one or more structured multiple-choice questions. Renders an interactive multi-tab TUI with a final Submit tab showing a summary of all answers. Each option must have a label AND a description explaining what it means.",
		parameters: {
			type: "object",
			properties: {
				questions: {
					type: "array",
					description:
						"Questions to ask the user (1-4 questions). Each is shown as a navigable tab. The user uses ←→ to switch between question tabs and a final Submit tab, ↑↓ to navigate options, Space to toggle, Enter to advance.",
					items: {
						type: "object",
						properties: {
							question: {
								type: "string",
								description:
									'The complete question text. Should be clear and end with a question mark. Example: "Which approach should we use for state management?"',
							},
							header: {
								type: "string",
								description:
									'Very short label shown as the tab chip (max 12 chars). Examples: "Approach", "Auth", "Library", "Scope".',
							},
							options: {
								type: "array",
								description:
									"The available choices (2-4 options). Do NOT include an Other/Custom option — that is added automatically. Each option MUST have both label and description.",
								items: {
									type: "object",
									properties: {
										label: {
											type: "string",
											description: "Concise display text for the option (1-5 words).",
										},
										description: {
											type: "string",
											description:
												"Explanation of what this option means, what will happen if chosen, or its trade-offs. Always provide this.",
										},
									},
									required: ["label", "description"],
								},
								minItems: 2,
								maxItems: 4,
							},
							multiSelect: {
								type: "boolean",
								description:
									"Set to true to allow selecting multiple options. Use when choices are not mutually exclusive.",
							},
						},
						required: ["question", "header", "options"],
					},
					minItems: 1,
					maxItems: 4,
				},
			},
			required: ["questions"],
		},

		execute: async (
			_toolCallId: string,
			params: { questions: QuestionDef[] },
			_signal: unknown,
			_onUpdate: unknown,
			ctx: any,
		) => {
			const { questions } = params;

			if (!questions || questions.length === 0) {
				return { content: [{ type: "text", text: "No questions provided" }] };
			}

			// Non-interactive fallback
			if (!ctx.hasUI) {
				const lines: string[] = [];
				questions.forEach((q, qi) => {
					if (questions.length > 1) lines.push(`[${q.header}] ${q.question}`);
					else lines.push(q.question);
					lines.push("");
					q.options.forEach((o, i) => {
						const letter = String.fromCharCode(65 + i);
						lines.push(`${letter}) ${o.label} — ${o.description}`);
					});
					if (q.multiSelect) lines.push("", "(Select all that apply — reply with letters e.g. A, C)");
					else lines.push("", "(Select one — reply with the letter)");
					lines.push("");
				});
				return { content: [{ type: "text", text: lines.join("\n").trim() }] };
			}

			// SUBMIT_TAB is the tab index after all questions
			const SUBMIT_TAB = questions.length;

			const result = await ctx.ui.custom<Map<number, { selected: string[]; customText: string }> | null>(
				(tui: any, theme: any, _kb: unknown, done: (v: any) => void) => {
					let activeTab = 0;
					const states: QuestionState[] = questions.map(() => ({ selected: new Set<number>(), customText: "" }));
					const cursorIndices: number[] = questions.map(() => 0);
					// inEditor tracks whether the write-your-own editor is open on the active tab
					let inEditor = false;
					let cachedLines: string[] | undefined;

					const editorTheme: EditorTheme = {
						borderColor: (s) => theme.fg("accent", s),
						selectList: {
							selectedPrefix: (t) => theme.fg("accent", t),
							selectedText: (t) => theme.fg("accent", t),
							description: (t) => theme.fg("muted", t),
							scrollInfo: (t) => theme.fg("dim", t),
							noMatch: (t) => theme.fg("warning", t),
						},
					};
					const editor = new Editor(tui, editorTheme);

					editor.onSubmit = (value: string) => {
						states[activeTab].customText = value.trim();
						inEditor = false;
						refresh();
					};

					function refresh() {
						cachedLines = undefined;
						tui.requestRender();
					}

					function submitForm() {
						const answers = new Map<number, { selected: string[]; customText: string }>();
						questions.forEach((q, qi) => {
							const state = states[qi];
							const selectedLabels = Array.from(state.selected)
								.sort((a, b) => a - b)
								.map((i) => q.options[i].label);
							answers.set(qi, { selected: selectedLabels, customText: state.customText });
						});
						done(answers);
					}

					function getAnswerText(qi: number): string {
						const state = states[qi];
						const q = questions[qi];
						const labels = Array.from(state.selected)
							.sort((a, b) => a - b)
							.map((i) => q.options[i].label);
						if (state.customText) labels.push(state.customText);
						return labels.join(", ");
					}

					function handleInput(data: string) {
						// --- Submit tab ---
						if (activeTab === SUBMIT_TAB) {
							if (matchesKey(data, Key.enter)) { submitForm(); return; }
							if (matchesKey(data, Key.escape)) { done(null); return; }
							if (matchesKey(data, Key.left)) { activeTab = Math.max(0, activeTab - 1); refresh(); return; }
							return;
						}

						// --- Question tab with editor open ---
						// Up exits the editor and moves cursor to the previous option.
						// Escape closes editor without moving cursor.
						// Down does nothing (already at the bottom item).
						// All other keys go to the editor.
						if (inEditor) {
							if (matchesKey(data, Key.up)) {
								inEditor = false;
								const q = questions[activeTab];
								cursorIndices[activeTab] = Math.max(0, q.options.length - 1);
								refresh();
								return;
							}
							if (matchesKey(data, Key.down)) {
								// already at bottom, ignore
								return;
							}
							if (matchesKey(data, Key.escape)) {
								inEditor = false;
								refresh();
								return;
							}
							editor.handleInput(data);
							refresh();
							return;
						}

						// --- Tab switching (only when editor is not open) ---
						if (matchesKey(data, Key.left)) {
							activeTab = Math.max(0, activeTab - 1);
							inEditor = false;
							refresh();
							return;
						}
						if (matchesKey(data, Key.right)) {
							activeTab = Math.min(SUBMIT_TAB, activeTab + 1);
							inEditor = false;
							refresh();
							return;
						}

						const q = questions[activeTab];
						const WRITE_OWN_INDEX = q.options.length;
						const totalItems = q.options.length + 1;
						const state = states[activeTab];
						const multiSelect = q.multiSelect ?? false;
						const cursorIndex = cursorIndices[activeTab];

						// Up / Down navigation
						if (matchesKey(data, Key.up)) {
							cursorIndices[activeTab] = Math.max(0, cursorIndex - 1);
							refresh();
							return;
						}
						if (matchesKey(data, Key.down)) {
							const next = Math.min(totalItems - 1, cursorIndex + 1);
							cursorIndices[activeTab] = next;
							// Auto-open editor only when landing on Write Your Own with no text yet.
							// If text already exists, just land the cursor there — Enter will advance.
							if (next === WRITE_OWN_INDEX && !state.customText) {
								inEditor = true;
							}
							refresh();
							return;
						}

						// Space: toggle selection. On write-your-own, always open editor
						// (fresh entry or re-edit existing text).
						if (data === " ") {
							if (cursorIndex === WRITE_OWN_INDEX) {
								inEditor = true;
							} else if (multiSelect) {
								if (state.selected.has(cursorIndex)) state.selected.delete(cursorIndex);
								else state.selected.add(cursorIndex);
							} else {
								state.selected.clear();
								state.selected.add(cursorIndex);
							}
							refresh();
							return;
						}

						// Enter: advance to next tab.
						// On write-your-own: open editor if no text yet; advance if text exists.
						// For regular options: select current if nothing selected (single-select),
						// then advance.
						if (matchesKey(data, Key.enter)) {
							if (cursorIndex === WRITE_OWN_INDEX) {
								if (!state.customText) {
									inEditor = true;
								} else {
									// Text already confirmed — advance just like a normal option
									activeTab = Math.min(SUBMIT_TAB, activeTab + 1);
									inEditor = false;
								}
								refresh();
								return;
							}
							if (!multiSelect && state.selected.size === 0) {
								state.selected.add(cursorIndex);
							}
							activeTab = Math.min(SUBMIT_TAB, activeTab + 1);
							inEditor = false;
							refresh();
							return;
						}

						if (matchesKey(data, Key.escape)) {
							done(null);
							return;
						}
					}

					function renderTabBar(width: number, lines: string[]) {
						const add = (s: string) => lines.push(truncateToWidth(s, width));
						const tabParts = questions.map((q, i) => {
							const state = states[i];
							const hasAnswer = state.selected.size > 0 || state.customText;
							const isActive = i === activeTab;
							const chip = q.header.length > 12 ? q.header.slice(0, 12) : q.header;
							if (isActive) return theme.fg("accent", theme.bold(`[ ${chip} ]`));
							if (hasAnswer) return theme.fg("success", `  ${chip}  `);
							return theme.fg("dim", `  ${chip}  `);
						});
						const isSubmitActive = activeTab === SUBMIT_TAB;
						tabParts.push(
							isSubmitActive
								? theme.fg("accent", theme.bold("[ Submit ✓ ]"))
								: theme.fg("dim", "  Submit  "),
						);
						add(" " + tabParts.join(theme.fg("dim", "│")));
					}

					function renderQuestionTab(width: number, lines: string[]) {
						const add = (s: string) => lines.push(truncateToWidth(s, width));
						const q = questions[activeTab];
						const WRITE_OWN_INDEX = q.options.length;
						const state = states[activeTab];
						const multiSelect = q.multiSelect ?? false;
						const cursorIndex = cursorIndices[activeTab];

						add(theme.fg("text", ` ${q.question}`));
						lines.push("");

						for (let i = 0; i < q.options.length; i++) {
							const opt = q.options[i];
							const isCursor = i === cursorIndex;
							const isSelected = state.selected.has(i);
							const cursorStr = isCursor ? theme.fg("accent", "> ") : "  ";
							const checkbox = multiSelect
								? isSelected ? theme.fg("accent", "☑ ") : theme.fg("dim", "☐ ")
								: isSelected ? theme.fg("accent", "● ") : theme.fg("dim", "○ ");
							add(`${cursorStr}${checkbox}${theme.fg(isCursor ? "accent" : "text", opt.label)}`);
							add(`       ${theme.fg(isCursor ? "muted" : "dim", opt.description)}`);
						}

						// Write your own — editor opens automatically when cursor lands here
						lines.push("");
						const isWriteOwn = cursorIndex === WRITE_OWN_INDEX;
						const writeCursor = isWriteOwn ? theme.fg("accent", "> ") : "  ";

						if (inEditor) {
							add(`${writeCursor}${theme.fg("accent", "✎")} ${theme.fg("muted", "Write your own:")}`);
							for (const line of editor.render(width - 4)) {
								add(`    ${line}`);
							}
							add(theme.fg("dim", "    Enter to confirm · ↑ or Esc to cancel"));
						} else if (state.customText) {
							add(`${writeCursor}${theme.fg("accent", "✎ ")}${theme.fg("accent", state.customText)}`);
							add(`       ${theme.fg("dim", isWriteOwn ? "Enter to advance · Space to re-edit" : "custom answer")}`);
						} else {
							add(`${writeCursor}${theme.fg(isWriteOwn ? "muted" : "dim", "✎  Write your own...")}`);
						}

						lines.push("");
						const isLast = activeTab === questions.length - 1;
						const enterHint = isLast ? "Enter → Submit" : "Enter → next";
						add(theme.fg("dim", ` ←→ switch tab · ↑↓ navigate · Space select · ${enterHint} · Esc cancel`));
					}

					function renderSubmitTab(width: number, lines: string[]) {
						const add = (s: string) => lines.push(truncateToWidth(s, width));

						add(theme.fg("text", " Review your answers"));
						lines.push("");

						questions.forEach((q, qi) => {
							const answerText = getAnswerText(qi);
							add(theme.fg("muted", ` ${q.question}`));
							if (answerText) {
								add(theme.fg("success", `   ✓ ${answerText}`));
							} else {
								add(theme.fg("warning", "   — no answer selected"));
							}
							lines.push("");
						});

						add(theme.fg("dim", " ← go back · Enter submit · Esc cancel"));
					}

					function render(width: number): string[] {
						if (cachedLines) return cachedLines;
						const lines: string[] = [];
						const add = (s: string) => lines.push(truncateToWidth(s, width));

						add(theme.fg("accent", "─".repeat(width)));
						renderTabBar(width, lines);
						add(theme.fg("dim", "─".repeat(width)));

						if (activeTab === SUBMIT_TAB) {
							renderSubmitTab(width, lines);
						} else {
							renderQuestionTab(width, lines);
						}

						add(theme.fg("accent", "─".repeat(width)));

						cachedLines = lines;
						return lines;
					}

					return {
						render,
						invalidate: () => { cachedLines = undefined; },
						handleInput,
					};
				},
			);

			if (!result) {
				return { content: [{ type: "text", text: "User cancelled" }] };
			}

			const parts: string[] = [];
			questions.forEach((q, qi) => {
				const answer = result.get(qi);
				if (!answer) return;
				const selections = [...answer.selected];
				if (answer.customText) selections.push(answer.customText);
				if (selections.length === 0) return;

				if (questions.length > 1) {
					parts.push(`[${q.header}] ${q.question}: ${selections.join(", ")}`);
				} else {
					if (selections.length === 1) {
						parts.push(`User selected: ${selections[0]}`);
					} else {
						parts.push(`User selected: ${selections.map((p, i) => `${i + 1}. ${p}`).join(", ")}`);
					}
				}
			});

			if (parts.length === 0) {
				return { content: [{ type: "text", text: "No selection made" }] };
			}

			return { content: [{ type: "text", text: parts.join("\n") }] };
		},

		renderCall(args: any, theme: any) {
			const qs = Array.isArray(args?.questions) ? args.questions : [];
			const firstHeader = qs[0]?.header ?? "";
			const count = qs.length;
			const label = count > 1 ? `ask_user_question (${count} questions) ` : "ask_user_question ";
			return new Text(theme.fg("toolTitle", theme.bold(label)) + theme.fg("muted", firstHeader), 0, 0);
		},

		renderResult(result: any, _options: unknown, theme: any) {
			const block = result?.content?.[0];
			const text = block?.type === "text" ? block.text : "";
			if (!text || text === "User cancelled" || text === "No selection made") {
				return new Text(theme.fg("warning", text || "No result"), 0, 0);
			}
			const display = text.replace(/^User selected: /, "");
			return new Text(theme.fg("success", "✓ ") + theme.fg("accent", display), 0, 0);
		},
	});
}
