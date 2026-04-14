local Layout = require("physical-keyboard.layout.Layout")
local g = require("physical-keyboard.const.Globals")

--- French AZERTY to English QWERTY layout mapping
---@type Layout
local fr_en = Layout.new()

fr_en:setName("fr-en")
fr_en:setActive(true)
fr_en:setFormMapOptions({
	"auto_capital",
	"auto_modifiers",
	"auto_shift_specials",
	"auto_altgr",
	"auto_dead_keys",
	"auto_accents",
	"auto_iso_specials",
})
fr_en:setLayoutName("azerty")
fr_en:setVimMode("all")
fr_en:setOnError(function(message)
	g.VimNotify:e(message)
end)

-- French AZERTY to English QWERTY mapping
-- Note: French layout uses AZERTY (different letter arrangement)
fr_en:setMap({
	-- Top row (numbers require Shift in French)
	["&"] = "1",
	["é"] = "2",
	['"'] = "3",
	["'"] = "4",
	["("] = "5",
	["-"] = "6",
	["è"] = "7",
	["_"] = "8",
	["ç"] = "9",
	["à"] = "0",
	["°"] = "°",

	-- Number row (shifted - produces symbols)
	["1"] = "!",
	["2"] = "@",
	["3"] = "#",
	["4"] = "$",
	["5"] = "%",
	["6"] = "^",
	["7"] = "&",
	["8"] = "*",
	["9"] = "(",
	["0"] = ")",

	-- Main letter row (AZERTY layout)
	["a"] = "q", -- A is where Q is in QWERTY
	["z"] = "w", -- Z is where W is in QWERTY
	["e"] = "e",
	["r"] = "r",
	["t"] = "t",
	["y"] = "y",
	["u"] = "u",
	["i"] = "i",
	["o"] = "o",
	["p"] = "p",
	["^"] = "[",
	["$"] = "]",
	["A"] = "Q",
	["Z"] = "W",

	-- Middle letter row
	["q"] = "a", -- Q is where A is in QWERTY
	["s"] = "s",
	["d"] = "d",
	["f"] = "f",
	["g"] = "g",
	["h"] = "h",
	["j"] = "j",
	["k"] = "k",
	["l"] = "l",
	["m"] = ";", -- M is where ; is in QWERTY
	["ù"] = "'",
	["*"] = "+",

	-- Bottom letter row
	["<"] = "<",
	["w"] = "z", -- W is where Z is in QWERTY
	["x"] = "x",
	["c"] = "c",
	["v"] = "v",
	["b"] = "b",
	["n"] = "n",
	[","] = "m", -- , is where M is in QWERTY
	[";"] = ",", -- ; is where , is in QWERTY
	[":"] = ".", -- : is where . is in QWERTY
	["!"] = "?", -- ! is where ? is in QWERTY
	["W"] = "Z",
	["M"] = ":",

	-- Special French accented characters (map to base form)
	["É"] = "E",
	["È"] = "E",
	["Ê"] = "E",
	["Ë"] = "E",
	["À"] = "A",
	["Â"] = "A",
	["Ä"] = "A",
	["Ù"] = "U",
	["Û"] = "U",
	["Ü"] = "U",
	["Î"] = "I",
	["Ï"] = "I",
	["Ô"] = "O",
	["Ö"] = "O",
	["Ç"] = "C",

	-- Dead keys and special characters
	['"'] = '"',
	["`"] = "`",
	["~"] = "~",
	["|"] = "|",
	["@"] = "@",
	["£"] = "£",
	["€"] = "€",
	["µ"] = "µ",
	["²"] = "²",
	["§"] = "§",
})

return fr_en
