-- lualine component.
local function pkb()
	return require("physical-keyboard").statusline()
end

return {
	"nvim-lualine/lualine.nvim",
	opts = {
		sections = {
			lualine_x = { pkb, "encoding", "filetype" },
		},
	},
}
