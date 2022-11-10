if exists("g:loaded_contributors")
	finish
endif

let g:loaded_contributors = 1

lua require("contributors").setup{ debug = false }
