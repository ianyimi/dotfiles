return {
  "mistricky/codesnap.nvim",
  build = "make",
  keys = {
    { "<leader>Y", "<cmd>CodeSnap<cr>", mode = "x", desc = "Code Snap (copy)" },
  },
  opts = {
    watermark = "",
  },
}
