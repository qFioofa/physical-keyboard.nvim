local Layout = require("physical-keyboard.layout.Layout")
local g = require("physical-keyboard.const.Globals")

local ru_en = Layout.new()

ru_en:setName("ru-en")
ru_en:setActive(true)
ru_en:setAutoCapical(true)
ru_en:setLayoutName("qwerty")
ru_en:setOnError(function(message)
	g.VimNotify(message)
end)

ru_en:setMap({
	["й"] = "q",
	["ц"] = "w",
	["у"] = "e",
	["к"] = "r",
	["е"] = "t",
	["н"] = "y",
	["г"] = "u",
	["ш"] = "i",
	["щ"] = "o",
	["з"] = "p",
	["х"] = "[",
	["ъ"] = "]",
	["ф"] = "a",
	["ы"] = "s",
	["в"] = "d",
	["а"] = "f",
	["п"] = "g",
	["р"] = "h",
	["о"] = "j",
	["л"] = "k",
	["д"] = "l",
	["ж"] = ";",
	["э"] = "'",
	["я"] = "z",
	["ч"] = "x",
	["с"] = "c",
	["м"] = "v",
	["и"] = "b",
	["т"] = "n",
	["ь"] = "m",
	["б"] = ",",
	["ю"] = ".",
	["."] = "/",
})

return ru_en
