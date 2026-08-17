return {
  "diegoulloao/nvim-file-location",
  enabled = true,
  config = function()
    local status, nvim_file_location = pcall(require, "nvim-file-location")
    if not status then
      return
    end

    nvim_file_location.setup({
      keymap = "<leader>fy",
      model = "workdir",
      add_line = false,
      add_column = false,
      defaultRegister = "*"
    })
  end
}
