local module = {}

local ui = game.Players.LocalPlayer.PlayerGui.gameUI.interactShell

function module.show(prompt)
	prompt.Parent = script.Parent.shell
	ui.Visible = true
end

function module.hide()
	ui.Visible = false
end

module.hide()

return module
