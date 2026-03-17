--- Default layout module paths
local folder = "physical-keyboard.default-layouts."

--- Default keyboard layouts included with the plugin
---@type Layout[]
return {
	require(folder .. "ru-en-qwerty"),
	require(folder .. "de-en-qwerty"),
	require(folder .. "fr-en-azerty"),
}
