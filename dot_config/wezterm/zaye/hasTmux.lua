local getOS = require("zaye.getOS")

local function hasTmux()
	local os = getOS.getName()

	if os == "Windows" then
		-- Check if tmux exists in Git Bash environment
		local handle = io.popen("C:\\Program Files\\Git\\bin\\bash.exe -c 'which tmux'")
		if handle then
			local result = handle:read("*a")
			handle:close()
			return result:match("tmux") ~= nil
		end
		return false
	else
		-- For Unix-like systems (Linux/MacOS)
		local handle = io.popen("which tmux")
		if handle then
			local result = handle:read("*a")
			handle:close()
			return result:match("tmux") ~= nil
		end
		return false
	end
end

return {
	hasTmux = hasTmux
}
