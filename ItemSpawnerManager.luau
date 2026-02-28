local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players") 

local collectiblePrefab = ReplicatedStorage:WaitForChild("Assets").Models:WaitForChild("Default")
local spawnFolder = Workspace:WaitForChild("ItemSpawns")

local RESPAWN_TIME = 5 -- Aumentei para 5s (2s é muito rápido pra recarregar tudo)

local function setupSpawn(spawnPart)
	local currentItem = nil
	local isActive = false
	local connection = nil 

	local function spawnItem()
		if isActive then return end
		isActive = true

		currentItem = collectiblePrefab:Clone()
		currentItem.Parent = Workspace

		-- Posicionamento
		local targetCFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
		if currentItem:IsA("Model") then
			currentItem:PivotTo(targetCFrame)
		elseif currentItem:IsA("BasePart") then
			currentItem.CFrame = targetCFrame
			currentItem.Anchored = true
			currentItem.CanCollide = false
		end

		-- Garante que não tenha peso para não travar ninguém
		for _, p in pairs(currentItem:GetDescendants()) do
			if p:IsA("BasePart") then p.Massless = true; p.CanCollide = false end
		end

		-- Encontra sensor de toque
		local touchPart = nil
		if currentItem:IsA("BasePart") then
			touchPart = currentItem
		elseif currentItem:IsA("Model") then
			touchPart = currentItem.PrimaryPart or currentItem:FindFirstChildWhichIsA("BasePart", true)
		end

		if touchPart then
			touchPart.CanTouch = true 

			connection = touchPart.Touched:Connect(function(hit)
				local character = hit.Parent
				local player = Players:GetPlayerFromCharacter(character)
				local humanoid = character:FindFirstChild("Humanoid")

				-- === BLINDAGEM VR ===
				-- Se for o Gigante, ignora completamente.
				if player and player:GetAttribute("IsGiant") then return end
				-- ====================

				if player and humanoid and humanoid.Health > 0 then
					if not isActive then return end

					local currentMissiles = player:GetAttribute("Missiles") or 0 
					local maxMissiles = player:GetAttribute("MaxMissiles") or 3 

					if currentMissiles < maxMissiles then
						-- Coleta Sucesso
						isActive = false 
						if connection then connection:Disconnect() connection = nil end

						player:SetAttribute("Missiles", currentMissiles + 1)
						-- print(player.Name .. " recarregou! (" .. (currentMissiles + 1) .. "/" .. maxMissiles .. ")")

						-- Efeito sonoro ou visual aqui seria legal no futuro

						currentItem:Destroy()

						task.wait(RESPAWN_TIME)
						spawnItem()
					end
				end
			end)
		else
			warn("CollectibleMissile sem BasePart para toque!")
			isActive = false 
		end
	end

	spawnItem()
end

-- Inicializa todos os spawns
for _, spawnPart in ipairs(spawnFolder:GetChildren()) do
	-- Você pode criar vários tipos de spawn mudando o nome da peça no mapa
	if spawnPart.Name == "MissileSpawn" then
		task.spawn(function() setupSpawn(spawnPart) end)
	end
end