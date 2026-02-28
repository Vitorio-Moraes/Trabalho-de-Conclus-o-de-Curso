local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

-- === CONFIGURAÇÕES GERAIS ===
local MAX_MISSILES = 5 
local MISSILE_SPEED = 200       
local MISSILE_LIFETIME = 5      
local MISSILE_DAMAGE = 25       

-- === REFERÊNCIAS ===
local DamageManager = require(ReplicatedStorage.Modules.DamageManager)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fireEvent = remotes:WaitForChild("RequestFireMissile")
local jumpEvent = remotes:WaitForChild("RequestJumpBoost")
local flightEvent = remotes:WaitForChild("RequestFlightState")
local projectilePrefab = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ProjectileMissile")

-- === GERENCIADOR DE MUNIÇÃO ===
local function onPlayerAdded(player)
	player:SetAttribute("Missiles", MAX_MISSILES) -- Começa cheio pra testar
	player:SetAttribute("MaxMissiles", MAX_MISSILES)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- === FUNÇÃO DO MÍSSIL ===
local function fireMissile(player, targetPos, tipo)
	local character = player.Character
	if not character then return end
	
	-- 1. Valida Munição
	local currentMissiles = player:GetAttribute("Missiles")
	if not currentMissiles or currentMissiles <= 0 then return end
	if tipo ~= "FlyShot" then
	player:SetAttribute("Missiles", currentMissiles - 1)
	end
		
	-- 2. Define Origem (Mão Direita)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then return end
	
	local direction = (targetPos - hand.Position).Unit
	-- Ajuste para não spawnar dentro do corpo
	local spawnPos = hand.Position + (direction * 4) + Vector3.new(0, 2, 0)
	local direction = (targetPos - spawnPos).Unit

	-- 3. Criação do Míssil
	local missile = projectilePrefab:Clone()
	missile.Name = "Missile_" .. player.Name
	missile.Parent = workspace

	local rootPart = missile.PrimaryPart or missile:FindFirstChildWhichIsA("BasePart", true)
	if not rootPart then missile:Destroy() return end
	missile.PrimaryPart = rootPart

	-- Posicionamento
	local lookAtCFrame = CFrame.lookAt(spawnPos, targetPos)
	-- Se o modelo do míssil estiver deitado, use a correção. Se for uma esfera, tire isso.
	local rotationCorrection = CFrame.Angles(math.rad(-90), 0, 0) 
	missile:PivotTo(lookAtCFrame * rotationCorrection)

	-- 5. Configuração de Colisão e Propriedades
	for _, obj in ipairs(missile:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = false
			obj.CanCollide = true 
			obj.Massless = true
			pcall(function() obj.CollisionGroup = "Missile" end)
			-- Define grupo de colisão se existir (Para não bater no dono)
			 

			if obj ~= rootPart then
				local w = Instance.new("WeldConstraint")
				w.Part0 = rootPart; w.Part1 = obj; w.Parent = rootPart
			end
		end
	end
	
	local launchVelocity = direction * MISSILE_SPEED
	rootPart.AssemblyLinearVelocity = launchVelocity 

	-- 6. Manutenção do Voo (LinearVelocity para manter a velocidade constante)
	local attachment = Instance.new("Attachment", rootPart)
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.MaxForce = math.huge -- Força infinita para não cair
	lv.VectorVelocity = launchVelocity
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = rootPart

	-- Mantém o míssil apontado para frente (opcional se o PivotTo já resolveu)
	local av = Instance.new("AngularVelocity")
	av.Attachment0 = attachment
	av.AngularVelocity = Vector3.zero
	av.MaxTorque = math.huge
	av.Parent = rootPart
	
	local spawnTime = tick() -- Guarde isso quando criar o míssil
	-- 6. Detecção de Dano (.Touched)
	local hitConnection
	hitConnection = rootPart.Touched:Connect(function(hit)
		
		if tick() - spawnTime < 0.1 and not hit.Parent:FindFirstChild("Humanoid") then 
			return 
		end
		
		-- Ignora dono e próprio míssil
		if hit:IsDescendantOf(character) or hit:IsDescendantOf(missile) then return end

		-- Verifica se acertou ALGO VIVO (Incluindo Gigante)
		local hitModel = hit:FindFirstAncestorOfClass("Model")
		warn(hitModel.Name .. " hitModel")

		-- Lógica Especial: Se bater na Mão do Gigante
		if hit.Name == "RightHand" or hit.Name == "LeftHand" or hitModel:GetAttribute("IsGiant") then
			-- Dano no Gigante
			DamageManager.ApplyDamage(hitModel, MISSILE_DAMAGE, "Míssil")

			-- Efeito visual de explosão aqui
			if hitConnection then hitConnection:Disconnect() end
			task.wait(0.2)
			missile:Destroy()
			return
		end

		-- Lógica Padrão: Humanoid
		if hitModel then
			local hitHumanoid = hitModel:FindFirstChild("Humanoid")
			if hitHumanoid then
				DamageManager.ApplyDamage(hitModel, MISSILE_DAMAGE, "Míssil")
		if hitConnection then hitConnection:Disconnect() end
				task.wait(0.2)
				missile:Destroy()
				return
			end
		end

		-- Se bater em parede (não vivo), explode também
		if not hit.CanCollide then return end -- Ignora sensores/triggers
		if hitConnection then hitConnection:Disconnect() end
		task.wait(0.2)
		missile:Destroy()
	end)

	Debris:AddItem(missile, MISSILE_LIFETIME)
end

-- === EVENTOS ===

fireEvent.OnServerEvent:Connect(function(player, targetPos, tipo)
	warn(tipo)
	-- BLINDAGEM: Gigante não atira míssil desse jeito
	if player.Character and player.Character:GetAttribute("IsGiant") then return end

	fireMissile(player, targetPos, tipo)
end)

jumpEvent.OnServerEvent:Connect(function(player)
	-- Consome munição ao pular duplo
	local currentMissiles = player:GetAttribute("Missiles")
	if currentMissiles and currentMissiles > 0 then
		player:SetAttribute("Missiles", currentMissiles - 1)
	end
	
end)

flightEvent.OnServerEvent:Connect(function(player, state)
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if state == "Start" then
		local currentMissiles = player:GetAttribute("Missiles")
		if currentMissiles and currentMissiles > 0 then
			player:SetAttribute("Missiles", currentMissiles - 1)
			if rootPart then rootPart:SetNetworkOwner(player) end
		end
	elseif state == "Stop" then
		if rootPart then rootPart:SetNetworkOwner(player) end
	end
end)