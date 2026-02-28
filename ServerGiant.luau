local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

Players.CharacterAutoLoads = false

local events = ReplicatedStorage:WaitForChild("Events")
local handshake = events:WaitForChild("Handshake")
local grabEvent = events:WaitForChild("GrabEvent")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local DamageManager = require(Modules:WaitForChild("DamageManager"))

-- CONFIGURAÇÕES
local PLAYER_THROW_DAMAGE = 30
local THROW_STATE_DURATION = 3
local SMASH_DAMAGE = 50       
local SMASH_RANGE = 50 
local PUNCH_DAMAGE = 60       
local WAVE_STEPS = 8          
local WAVE_STEP_SIZE = 7      
local WAVE_DELAY = 0.08       
local DEBUG_MODE = false      

-- 1. FUNÇÃO DE PERSONALIZAÇÃO (CORRIGIDA: PINTOR DE MODELOS)
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

-- 2. MONITORAMENTO
local function MonitorThrownPlayer(playerChar, throwerChar)
	local humanoid = playerChar:FindFirstChild("Humanoid")
	local rootPart = playerChar:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end
	playerChar:SetAttribute("ThrownByGiant", true)
	local connectionTouch, connectionJump
	local function CleanUp()
		if connectionTouch then connectionTouch:Disconnect() end
		if connectionJump then connectionJump:Disconnect() end
		playerChar:SetAttribute("ThrownByGiant", nil)
		humanoid.PlatformStand = false 
	end
	task.delay(0.2, function()
		if not playerChar:GetAttribute("ThrownByGiant") then return end
		connectionTouch = rootPart.Touched:Connect(function(hit)
			if hit:IsDescendantOf(playerChar) then return end
			if throwerChar and hit:IsDescendantOf(throwerChar) then return end
			if not hit.CanCollide then return end
			DamageManager.ApplyDamage(playerChar, PLAYER_THROW_DAMAGE, "Arremesso do Gigante")
			CleanUp()
		end)
	end)
	connectionJump = humanoid.Jumping:Connect(CleanUp)
	task.delay(THROW_STATE_DURATION, function() if playerChar:GetAttribute("ThrownByGiant") then CleanUp() end end)
end

local function SetHeldProperties(modelOrPart, isHeld)
	local targetGroup = isHeld and "HeldObject" or "Default"
	local function setProps(p)
		if p:IsA("BasePart") then
			p.CollisionGroup = targetGroup
			if isHeld then p.Massless = true else p.Massless = false end
		end
	end
	setProps(modelOrPart)
	for _, child in pairs(modelOrPart:GetDescendants()) do setProps(child) end
end

-- EVENTO PRINCIPAL
grabEvent.OnServerEvent:Connect(function(player, part, action, extraData)
	
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")

	-- Se o humanoide estiver morto ou o gigante estiver marcado como morto, ignora o comando
	if humanoid and humanoid.Health <= 0 then return end
	if character:GetAttribute("IsDead") then return end
	
	-- SMASH
	if action == "Smash" then
		if not part then return end
		local centerPos = part.Position
		local boxSize = Vector3.new(SMASH_RANGE, 15, SMASH_RANGE)
		local overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = {player.Character}
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		local victims = Workspace:GetPartBoundsInBox(CFrame.new(centerPos), boxSize, overlapParams)
		local hitHumanoids = {} 

		for _, v in pairs(victims) do
			local char = v.Parent; if char:IsA("Accessory") then char = char.Parent end
			local hum = char:FindFirstChild("Humanoid")
			if hum and not hitHumanoids[hum] then
				hitHumanoids[hum] = true
				DamageManager.ApplyDamage(char, SMASH_DAMAGE, "Esmagamento")
				local root = char:FindFirstChild("HumanoidRootPart"); if root then root.AssemblyLinearVelocity = Vector3.new(0, 80, 0) end
			end
		end
		return
	end

	-- PUNCH
	if action == "Punch" then
		if not part then return end
		local direction = extraData or part.CFrame.LookVector 
		local startPos = part.Position
		task.spawn(function()
			local currentPos = startPos
			local hitAlready = {}
			for i = 1, WAVE_STEPS do
				currentPos = currentPos + (direction * WAVE_STEP_SIZE)
				local rayOrigin = currentPos + Vector3.new(0, 20, 0)
				local rayParams = RaycastParams.new()
				rayParams.FilterDescendantsInstances = {player.Character}
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				local ray = Workspace:Raycast(rayOrigin, Vector3.new(0, -50, 0), rayParams)
				local isValidFloor = ray and (ray.Instance:GetAttribute("IsFloor") == true or ray.Instance.Name == "Baseplate")
				if isValidFloor then
					local floorY = ray.Position.Y
					local targetPos = Vector3.new(currentPos.X, floorY - 3, currentPos.Z)
					local rock = Instance.new("Part")
					rock.Size = Vector3.new(15, 1, 15); rock.Position = targetPos; rock.Anchored = true; rock.CanCollide = false; rock.Material = Enum.Material.Slate; rock.Color = Color3.fromRGB(80, 80, 80); rock.Parent = Workspace
					local tween = TweenService:Create(rock, TweenInfo.new(0.15), {Size = Vector3.new(12, math.random(5, 8), 12), Position = targetPos + Vector3.new(0, 5, 0)})
					tween:Play(); Debris:AddItem(rock, 2.5) 
					local boxSize = Vector3.new(18, 15, 18)
					local victims = Workspace:GetPartBoundsInBox(CFrame.new(Vector3.new(targetPos.X, floorY + 3, targetPos.Z)), boxSize, overlapParams)
					for _, v in pairs(victims) do
						local char = v.Parent; if char:IsA("Accessory") then char = char.Parent end
						local hum = char:FindFirstChild("Humanoid")
						if hum and not hitAlready[hum] then
							hitAlready[hum] = true
							DamageManager.ApplyDamage(char, PUNCH_DAMAGE, "Terremoto")
							local root = char:FindFirstChild("HumanoidRootPart")
							if root then root.AssemblyLinearVelocity = (direction * 30) + Vector3.new(0, 45, 0) end
						end
					end
				end
				task.wait(WAVE_DELAY)
			end
		end)
		return
	end

	-- GRAB
	if not part or not part:IsA("BasePart") then return end
	local character = part.Parent
	if character:IsA("Accessory") then character = character.Parent end
	local humanoid = character:FindFirstChild("Humanoid")

	if action == "Grab" then
		if part.Anchored then part.Anchored = false end
		part.CanCollide = true; part.AssemblyLinearVelocity = Vector3.new(0, 0.1, 0); part:SetNetworkOwner(player); character:SetAttribute("ThrownByGiant", nil)
		if humanoid then humanoid.PlatformStand = true; SetHeldProperties(character, true) else SetHeldProperties(part, true) end

	elseif action == "Release" then
		if humanoid then SetHeldProperties(character, false) else SetHeldProperties(part, false) end
		if humanoid then
			humanoid.PlatformStand = false
			task.delay(0.1, function() if part and part.Parent then local vp = Players:GetPlayerFromCharacter(character); if vp then part:SetNetworkOwner(vp) else part:SetNetworkOwner(nil) end MonitorThrownPlayer(character, player.Character) end end)
		else
			local c; c = part.Touched:Connect(function(hit) if hit:IsDescendantOf(player.Character) then return end local d = DamageManager.CalculateDamageFromSpeed(part.AssemblyLinearVelocity.Magnitude); if d > 0 then local v = hit.Parent; if v:FindFirstChild("Humanoid") then if DamageManager.ApplyDamage(v, d, "Bloco") then c:Disconnect() end end end end)
			task.delay(5, function() if c then c:Disconnect() end end)
		end
	end
end)

-- SPAWN GIANT
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
	local humanoid = rig:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			print("SERVER GIANT: " .. player.Name .. " morreu!")
			rig:SetAttribute("IsDead", true) -- Marca para os remotes ignorarem comandos

			-- Remove as forças físicas para o corpo cair
			for _, part in pairs(rig:GetDescendants()) do
				if part:IsA("BodyPosition") or part:IsA("BodyGyro") or part:IsA("AlignPosition") or part:IsA("AlignOrientation") then
					part:Destroy()
				end
			end

			-- Opcional: Garantir que as mãos voltem a ter massa para caírem de forma pesada
			for _, part in pairs(rig:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Massless = false
				end
			end

			-- Opcional: Se quiser que o Gigante não colida mais com os humanos após morrer
			-- pcall(function() PhysicsService:CollisionGroupSetCollidable("GiantBody", "Default", false) end)
		end)
	end
end

local function SpawnHuman(player) if player.Character then player.Character:Destroy() end player:LoadCharacter() end
handshake.OnServerEvent:Connect(function(player, isVR) if isVR then SpawnGiant(player) else SpawnHuman(player) end end)