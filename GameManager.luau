print(">>> GAME MANAGER: Script Iniciado com Sucesso! <<<") -- Prova de vida

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- === CONFIGURAÇÕES ===
local INTERMISSION_TIME = 15
local MATCH_TIME = 600 
local MIN_KNIGHTS = 1

-- === FUNÇÕES DE UTILIDADE ===

-- Agora busca o atributo no PLAYER, que não some ao morrer
local function getGiant()
	for _, p in pairs(Players:GetPlayers()) do
		-- AGORA CHECA NO PLAYER (Persistente) ou no Character (Atual)
		if p:GetAttribute("IsGiant") == true or (p.Character and p.Character:GetAttribute("IsGiant") == true) then 
			return p 
		end
	end
	return nil
end

local function ApplySkin(player, rig)
	-- O sufixo "Async" indica que o Roblox vai buscar os dados na nuvem
	local success, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
	end)

	if success and desc then
		local rightHand = rig:FindFirstChild("RightHand") or rig:FindFirstChild("Right Arm")
		local leftHand = rig:FindFirstChild("LeftHand") or rig:FindFirstChild("Left Arm")
		local head = rig:FindFirstChild("Head")

		-- Função auxiliar otimizada (usando GetDescendants é mais rápido que recursão manual)
		local function PaintParts(model, color)
			if not model then return end
			-- Se for uma peça única (BasePart)
			if model:IsA("BasePart") then
				model.Color = color
			end
			-- Pega todos os filhos, netos, etc., de uma vez
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Color = color
				end
			end
		end

		-- Aplica a cor na Mão Direita
		if rightHand then 
			PaintParts(rightHand, desc.RightArmColor) 
		end

		-- Aplica a cor na Mão Esquerda
		if leftHand then 
			PaintParts(leftHand, desc.LeftArmColor) 
		end

		-- Aplica a cor na Cabeça e Rosto
		if head then 
			PaintParts(head, desc.HeadColor)

			-- Aplica Rosto (Face)
			local face = head:FindFirstChild("face") or head:FindFirstChildWhichIsA("Decal")
			if not face then 
				face = Instance.new("Decal", head)
				face.Name = "face"
			end
			face.Texture = "rbxassetid://" .. desc.Face
		end

		print("SERVER GIANT: Skin aplicada com sucesso em " .. player.Name)
	else
		warn("SERVER GIANT: Falha ao carregar skin de " .. player.Name .. " Erro: " .. tostring(desc))
	end
end


local function getAliveKnights()
	local alive = {}
	local giant = getGiant()
	for _, p in pairs(Players:GetPlayers()) do
		-- Um cavaleiro é qualquer um que NÃO seja o gigante e tenha personagem vivo
		if p ~= giant and p.Character and p.Character:FindFirstChild("Humanoid") then
			if p.Character.Humanoid.Health > 0 then 
				table.insert(alive, p) 
			end
		end
	end
	return alive
end

local function SpawnGiant(player)
	print("SERVER GIANT: Tentando spawnar " .. player.Name)
	if player.Character then player.Character:Destroy() end
	local rig = ReplicatedStorage:WaitForChild("GiantRig"):Clone()
	rig.Name = player.Name

	local spawnCF = CFrame.new(0, 10, 0)
	local locationsFolder = Workspace:FindFirstChild("GiantLocations")
	if locationsFolder then
		local spawnPart = locationsFolder:FindFirstChild("SpawnPoint")
		if spawnPart then spawnCF = spawnPart.CFrame + Vector3.new(0, 5, 0) end
	end
	rig:PivotTo(spawnCF)

	rig:SetAttribute("IsGiant", true)
	if _G.ApplyGiantGroups then _G.ApplyGiantGroups(rig) else for _, p in pairs(rig:GetDescendants()) do if p:IsA("BasePart") then p.Massless = true end end end
	rig.Parent = workspace

	-- [[ APLICA A SKIN COM A FUNÇÃO RECURSIVA ]]
	ApplySkin(player, rig)
	-- ==================

	player.Character = rig
	local partsToFloat = {}; if rig:FindFirstChild("Head") then table.insert(partsToFloat, rig.Head) end
	local function PrepareHand(handModel)
		if not handModel then return end
		local root = handModel:FindFirstChild("RootPart") or handModel.PrimaryPart or (handModel:IsA("BasePart") and handModel)
		if root then root.Anchored = false; table.insert(partsToFloat, root) end
	end
	PrepareHand(rig:FindFirstChild("RightHand")); PrepareHand(rig:FindFirstChild("LeftHand"))
	for _, part in pairs(partsToFloat) do
		local bp = Instance.new("BodyPosition"); bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bp.D = 800; bp.P = 40000; bp.Position = part.Position; bp.Parent = part
		local bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); bg.D = 500; bg.P = 20000; bg.CFrame = part.CFrame; bg.Parent = part
		part:SetNetworkOwner(player)
	end
end

local function spawnEveryone()
	print("GAME MANAGER: Iniciando Spawn Controlado (VR vs PC)...")

	-- 1. Identificamos o gigante ANTES de qualquer reset
	local giantPlayer = getGiant()

	if not giantPlayer then
		print("GAME MANAGER: Erro - Nenhum gigante detectado para iniciar!")
		-- Opcional: Cancelar partida ou escolher um aleatório
	end

	for _, p in pairs(Players:GetPlayers()) do
		if p == giantPlayer then
			-- AQUI ESTÁ A CHAVE: Não usamos LoadCharacter para o Gigante!
			-- Chamamos a sua função de Rig VR diretamente
			print("GAME MANAGER: Spawnando " .. p.Name .. " como GIGANTE VR.")
			SpawnGiant(p) -- Usa a sua função que clona o GiantRig e seta NetworkOwner
		else
			-- Para os cavaleiros, o LoadCharacter padrão resolve
			print("GAME MANAGER: Spawnando " .. p.Name .. " como Cavaleiro PC.")
			p:LoadCharacter() 

			-- Garante que o atributo seja aplicado ao novo personagem do cavaleiro
			local char = p.Character or p.CharacterAdded:Wait()
			char:SetAttribute("IsGiant", false)
		end
	end
end

local GameState = {
	WAITING = "Aguardando Jogadores...",
	INTERMISSION = "Preparando Partida: ",
	PLAYING = "Partida em Andamento: ",
	GAMEOVER = "Fim de Jogo! Vencedor: "
}

-- Valores para UI
local statusValue = ReplicatedStorage:FindFirstChild("GameStatus") or Instance.new("StringValue", ReplicatedStorage)
statusValue.Name = "GameStatus"
local timerValue = ReplicatedStorage:FindFirstChild("GameTimer") or Instance.new("IntValue", ReplicatedStorage)
timerValue.Name = "GameTimer"


-- === LOOP PRINCIPAL ===
task.spawn(function()
	while true do
		-- FASE 1: AGUARDANDO
		statusValue.Value = GameState.WAITING
		timerValue.Value = 0

		print("GAME MANAGER: Estado = Waiting") 
				
		local ready = false
		repeat
			local giant = getGiant()
			local knightsCount = #Players:GetPlayers() - (giant and 1 or 0)

			if giant and knightsCount >= MIN_KNIGHTS then
				ready = true
				print("GAME MANAGER: Jogadores suficientes! Iniciando...")
			else
				ready = false

				-- Mensagem de Debug (Só a cada 3 segundos pra não floodar)
				if os.time() % 3 == 0 then
					local msg = "Faltam: "
					if not giant then msg = msg .. "[Gigante VR] " end
					if knightsCount < MIN_KNIGHTS then msg = msg .. "[Cavaleiros PC]" end
					print("GAME MANAGER: " .. msg)
				end

				if not giant then
					statusValue.Value = "Aguardando Gigante (VR)..."
				elseif knightsCount < MIN_KNIGHTS then
					statusValue.Value = "Aguardando Cavaleiros (PC)..."
				end
			end
			task.wait(1)
		until ready

		-- FASE 2: INTERMISSÃO
		print("GAME MANAGER: Intermissão iniciada.")
		for i = INTERMISSION_TIME, 1, -1 do
			statusValue.Value = GameState.INTERMISSION
			timerValue.Value = i

			local giant = getGiant()
			local knightsCount = #Players:GetPlayers() - (giant and 1 or 0)
			if not giant or knightsCount < MIN_KNIGHTS then
				statusValue.Value = "Cancelado! Jogador saiu."
				print("GAME MANAGER: Cancelado na intermissão.")
				task.wait(2)
				break 
			end
			task.wait(1)
		end

		-- FASE 3: PARTIDA
		local giantStart = getGiant()
		if giantStart then
			print("GAME MANAGER: PARTIDA COMEÇOU!")
			spawnEveryone()
			task.wait(2) 

			local winner = "Ninguém"
			local matchRunning = true
			local timeLeft = MATCH_TIME

			while matchRunning and timeLeft > 0 do
				statusValue.Value = GameState.PLAYING
				timerValue.Value = timeLeft

				local currentGiant = getGiant()
				if not currentGiant then
					winner = "Cavaleiros (Gigante Saiu)"
					matchRunning = false
				elseif currentGiant.Character and currentGiant.Character:FindFirstChild("Humanoid") then
					if currentGiant.Character.Humanoid.Health <= 0 then
						winner = "Cavaleiros"
						matchRunning = false
					end
				end

				local knights = getAliveKnights()
				if timeLeft < (MATCH_TIME - 5) and #knights == 0 then
					winner = "O Gigante"
					matchRunning = false
				end

				timeLeft = timeLeft - 1
				task.wait(1)
			end

			if timeLeft <= 0 then winner = "Cavaleiros (Tempo Esgotado)" end

			statusValue.Value = GameState.GAMEOVER .. winner
			print("GAME MANAGER: Fim de Jogo! Vencedor: " .. winner)
			task.wait(5) 
		end
		task.wait(1)
	end
end)
