local Layout = require("physical-keyboard.layout.Layout")
local g = require("physical-keyboard.const.Globals")

--- German QWERTZ to English QWERTY layout mapping
---@type Layout
local de_en = Layout.new()

de_en:setName("de-en")
de_en:setActive(true)
de_en:setFormMapOptions({
	"auto_capital",
	"auto_modifiers",
	"auto_shift_specials",
	"auto_altgr",
	"auto_dead_keys",
	"auto_accents",
	"auto_iso_specials",
})
de_en:setLayoutName("qwertz")
de_en:setVimMode("all")
de_en:setOnError(function(message)
	g.VimNotify:e(message)
end)

-- German QWERTZ to English QWERTY mapping
-- Note: German layout uses QWERTZ (Z and Y swapped compared to QWERTY)
de_en:setMap({
	-- Top row (numbers and special chars)
	["0"] = "0",
	["1"] = "1",
	["2"] = "2",
	["3"] = "3",
	["4"] = "4",
	["5"] = "5",
	["6"] = "6",
	["7"] = "7",
	["8"] = "8",
	["9"] = "9",

	-- Special German characters
	["ß"] = "ss",
	["´"] = "'",
	["`"] = "`",
	["^"] = "^",

	-- Main letter row (QWERTZ layout)
	["q"] = "q",
	["w"] = "w",
	["e"] = "e",
	["r"] = "r",
	["t"] = "t",
	["z"] = "y", -- Z and Y are swapped in German
	["u"] = "u",
	["i"] = "i",
	["o"] = "o",
	["p"] = "p",
	["ü"] = "u",
	["+"] = "=",
	["Ü"] = "U",

	-- Middle letter row
	["a"] = "a",
	["s"] = "s",
	["d"] = "d",
	["f"] = "f",
	["g"] = "g",
	["h"] = "h",
	["j"] = "j",
	["k"] = "k",
	["l"] = "l",
	["ö"] = "o",
	["ä"] = "a",
	["#"] = "'",
	["Ö"] = "O",
	["Ä"] = "A",

	-- Bottom letter row
	["<"] = "<",
	["y"] = "z", -- Y and Z are swapped in German
	["x"] = "x",
	["c"] = "c",
	["v"] = "v",
	["b"] = "b",
	["n"] = "n",
	["m"] = "m",
	[","] = ",",
	["."] = ".",
	["-"] = "-",
	["Y"] = "Z",
	["Z"] = "Y",

	-- Shifted special characters (German layout)
	["!"] = "!",
	["@"] = "@",
	["§"] = "$", -- German § is where $ is on US
	["%"] = "%",
	["&"] = "&",
	["/"] = "/",
	["("] = "(",
	[")"] = ")",
	["="] = ")",
	["?"] = "?",
	[":"] = ";",
	['"'] = '"',
	["*"] = "*",
	["~"] = "~",
	["|"] = "|",
	["°"] = "°",
	["²"] = "²",
	["³"] = "³",
	["€"] = "€",
})

return de_en
