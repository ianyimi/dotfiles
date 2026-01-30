return {
	"christoomey/vim-tmux-navigator",
	cmd = {
		"TmuxNavigateLeft",
		"TmuxNavigateDown",
		"TmuxNavigateUp",
		"TmuxNavigateRight",
		"TmuxNavigatePrevious",
		"TmuxNavigatorProcessList",
	},
	keys = {
		{ "<a-z>h", "<cmd><C-U>TmuxNavigateLeft<cr>" },
		{ "<a-z>j", "<cmd><C-U>TmuxNavigateDown<cr>" },
		{ "<a-z>k", "<cmd><C-U>TmuxNavigateUp<cr>" },
		{ "<a-z>l", "<cmd><C-U>TmuxNavigateRight<cr>" },
		{ "<a-z>.", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
	},
}
