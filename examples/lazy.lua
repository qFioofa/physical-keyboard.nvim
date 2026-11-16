-- lazy.nvim spec. `opts` automatically calls setup(opts).
return {
	"qFioofa/physical-keyboard.nvim",
	event = { "VeryLazy" },
	opts = {
		active_layouts = { "ru" },
	},
}
