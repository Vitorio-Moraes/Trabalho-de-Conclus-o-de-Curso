-- === BLINDAGEM VR (SEGURANÇA OBRIGATÓRIA) ===
local VRService = game:GetService("VRService")

-- Se for o Gigante (VR), esse script morre aqui.
if VRService.VREnabled then
	script:Destroy()
	return
end
-- ============================================

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- === CONFIGURAÇÕES ===
local MAX_DISTANCE = 150           -- Alcance máximo
local GRAPPLE_SPEED = 150          -- Velocidade máxima de puxão
local MIN_SPEED = 50               -- Velocidade mínima ao chegar perto
local SLOW_DOWN_DIST = 40          -- Distância para começar a desacelerar
local STOP_DISTANCE = 6            -- Distância para soltar o gancho automaticamente
local VERTICAL_OFFSET = Vector3.new(0, 5, 0) -- Offset para puxar acima do ponto mirado
local WALL_DETECTION_DIST = 4      -- Distância para detectar paredes a frente
local MAX_DOWN_ANGLE = -0.3        -- Ângulo limite para mirar para baixo

-- Variáveis de Estado
local isGrappling = false
local grappleTarget = nil

-- Referências
local character, rootPart, handAttachment, linearVelocity, beam

-- Parâmetros de Raycast reusáveis
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- === FUNÇÕES AUXILIARES ===

local function stopGrapple()
	if not isGrappling then return end
	isGrappling = false

	if linearVelocity then 
		linearVelocity.Enabled = false 
	end
	if beam then
		beam.Enabled = false
		if beam.Attachment1 then beam.Attachment1:Destroy() end
	end
end

local function startGrapple()
	if not rootPart or isGrappling then return end

	-- 1. Identificar onde o jogador está mirando com a CÂMERA
	local aimPoint = mouse.Hit.Position

	-- 2. Calcular a origem do gancho saindo do PERSONAGEM
	local grappleOrigin = character:FindFirstChild("Head") and character.Head.Position or rootPart.Position + Vector3.new(0, 2, 0)

	-- 3. Direção real: Do personagem até onde a câmera mirou
	local realDirection = (aimPoint - grappleOrigin).Unit * MAX_DISTANCE

	raycastParams.FilterDescendantsInstances = {character}

	-- O Raycast sai fisicamente do personagem
	local raycastResult = workspace:Raycast(grappleOrigin, realDirection, raycastParams)

	if raycastResult then
		isGrappling = true
		grappleTarget = raycastResult.Position + VERTICAL_OFFSET

		local targetAttachment = Instance.new("Attachment")
		targetAttachment.WorldPosition = raycastResult.Position
		targetAttachment.Parent = workspace.Terrain

		beam.Attachment1 = targetAttachment
		beam.Enabled = true
	end
end

-- === EVENTOS DO PERSONAGEM ===

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	rootPart = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Jumping:Connect(stopGrapple)

	local attachment0 = Instance.new("Attachment", rootPart)
	linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = attachment0
	linearVelocity.MaxForce = 600000
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Enabled = false
	linearVelocity.Parent = rootPart

	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand then
		handAttachment = Instance.new("Attachment", hand)
		beam = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("FX"):WaitForChild("Beam")
		beam.Attachment0 = handAttachment
		beam.Parent = character
	end
end)

-- === LOOP PRINCIPAL (FÍSICA) ===

RunService.Heartbeat:Connect(function(deltaTime)
	if isGrappling and rootPart and grappleTarget and linearVelocity then
		local currentPos = rootPart.Position
		local directionVector = (grappleTarget - currentPos)
		local distance = directionVector.Magnitude
		local moveDir = directionVector.Unit

		if distance < 25 and moveDir.Y < MAX_DOWN_ANGLE then
			stopGrapple()
			return
		end

		if distance < STOP_DISTANCE then
			stopGrapple()
			local momentumMult = (rootPart.AssemblyLinearVelocity.Y > 0) and 1 or 0.3
			rootPart:ApplyImpulse(rootPart.AssemblyLinearVelocity * rootPart.AssemblyMass * momentumMult * 0.6)
		else
			local targetSpeed = math.clamp((distance / SLOW_DOWN_DIST) * GRAPPLE_SPEED, MIN_SPEED, GRAPPLE_SPEED)

			raycastParams.FilterDescendantsInstances = {character}
			local wallHit = workspace:Raycast(currentPos, moveDir * WALL_DETECTION_DIST, raycastParams)

			local finalVelocityDir = moveDir

			if wallHit and wallHit.Instance.CanCollide then
				local normal = wallHit.Normal
				local slideDir = moveDir - (moveDir:Dot(normal) * normal)
				if slideDir.Magnitude < 0.1 then
					slideDir = Vector3.new(0, 1, 0)
				end
				finalVelocityDir = slideDir.Unit
			end

			linearVelocity.VectorVelocity = finalVelocityDir * targetSpeed
			linearVelocity.Enabled = true
		end
	end
end)

-- === INPUTS ===

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if isGrappling then
			stopGrapple()
		else
			startGrapple()
		end
	end
end)