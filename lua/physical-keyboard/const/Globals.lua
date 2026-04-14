local vimNotify = require("physical-keyboard.utils.Message")

--- Global instances used across the plugin
---@class Globals
---@field VimNotify VimMessage Global notification instance

---@diagnostic disable-next-line: assign-type-mismatch
return {
	VimNotify = vimNotify.new(),
}
