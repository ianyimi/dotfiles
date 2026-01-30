-- Simple setup script to initialize Ghana Cozy themes
-- Run once: :lua require('setup-ghana-cozy')

print("🇬🇭 Setting up Ghana Cozy themes...")

-- Apply the dark theme immediately
local ok = pcall(vim.cmd, 'colorscheme ghana-cozy')
if ok then
  print("✅ Ghana Cozy dark theme applied!")
else
  print("❌ Error applying theme. Please restart Neovim.")
end

print("")
print("Available themes:")
print("🌙 Dark: :colorscheme ghana-cozy")
print("☀️  Light: :colorscheme ghana-cozy-light")
print("")
print("Simple variants also available:")
print("🌙 Dark: :colorscheme ghana-cozy-simple") 
print("☀️  Light: :colorscheme ghana-cozy-light-simple")
print("")
print("🎨 Use Huez to switch themes:")
print("   <leader>to - Open theme picker")
print("   <leader>tf - View favorites")
print("")
print("Ghana Cozy is now your default theme in Huez!")