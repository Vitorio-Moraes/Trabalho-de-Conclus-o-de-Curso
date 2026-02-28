local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ENEMY_COLOR = Color3.fromRGB(255, 0, 0)
local HIGHLIGHT_NAME = "EnemyHighlight"

local function ApplyHighlight(character)
	-- 1. Verificações básicas
	if not character or character == LocalPlayer.Character then return end

	-- 2. PEQUENO DELAY (Essencial para Respawn)
	-- Isso dá tempo para o motor do jogo estabilizar o novo personagem no Workspace
	task.defer(function() 
		if not character.Parent then character.AncestryChanged:Wait() end

		-- Evita duplicatas
		local existing = character:FindFirstChild(HIGHLIGHT_NAME)
		if existing then existing:Destroy() end

		local highlight = Instance.new("Highlight")
		highlight.Name = HIGHLIGHT_NAME
		highlight.Adornee = character

		-- Configurações de Aparência
		highlight.FillColor = ENEMY_COLOR
		highlight.OutlineColor = ENEMY_COLOR
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

		highlight.Parent = character
	end)
end

-- Monitorar jogadores atuais e futuros
local function SetupPlayer(player)
	if player == LocalPlayer then return end

	-- Conecta ao CharacterAdded (para quando ele spawnar/respawnar)
	player.CharacterAdded:Connect(ApplyHighlight)

	-- Se o personagem já existir (ex: ele entrou antes do script rodar)
	if player.Character then
		ApplyHighlight(player.Character)
	end
end

-- Aplicar para quem já está no servidor
for _, player in ipairs(Players:GetPlayers()) do
	SetupPlayer(player)
end

-- Aplicar para novos jogadores
Players.PlayerAdded:Connect(SetupPlayer)

-- === Seu código de Transparência Local (Mantido) ===
local RunService = game:GetService("RunService")
RunService.RenderStepped:Connect(function()
	local char = LocalPlayer.Character
	if char then
		for _, part in ipairs(char:GetChildren()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
			end
		end
	end
end)