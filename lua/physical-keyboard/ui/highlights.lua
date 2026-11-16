local M = {
	namespace = vim.api.nvim_create_namespace("physical-keyboard-ui"),
}

local links = {
	PhyKeyboardUINormal = "NormalFloat",
	PhyKeyboardUIBorder = "FloatBorder",
	PhyKeyboardUIBorderTree = "Directory",
	PhyKeyboardUIBorderContent = "DiagnosticInfo",
	PhyKeyboardUITitle = "FloatTitle",
	PhyKeyboardUIHeader = "WinBar",
	PhyKeyboardUISection = "Title",
	PhyKeyboardUISeparator = "NonText",
	PhyKeyboardUIDivider = "WinSeparator",
	PhyKeyboardUITree = "Normal",
	PhyKeyboardUITreeBranch = "Directory",
	PhyKeyboardUITreeSelected = "Visual",
	PhyKeyboardUIFocus = "Visual",
	PhyKeyboardUITreeActive = "Identifier",
	PhyKeyboardUIKey = "Identifier",
	PhyKeyboardUIValue = "String",
	PhyKeyboardUINumber = "Number",
	PhyKeyboardUIBoolean = "Boolean",
	PhyKeyboardUIMuted = "Comment",
	PhyKeyboardUIHelp = "WinBar",
	PhyKeyboardUITab = "TabLine",
	PhyKeyboardUITabActive = "TabLineSel",
	PhyKeyboardUIBadge = "Special",
	PhyKeyboardUIOK = "DiagnosticOk",
	PhyKeyboardUIWarn = "DiagnosticWarn",
	PhyKeyboardUIError = "DiagnosticError",
	PhyKeyboardUIInfo = "DiagnosticInfo",
	PhyKeyboardUIHint = "DiagnosticHint",
	PhyKeyboardUIVisual = "Visual",
}

function M.setup()
	for name, link in pairs(links) do
		vim.api.nvim_set_hl(0, name, { link = link, default = true })
	end
end

function M.groups()
	return vim.deepcopy(links)
end

M.setup()

return M
