-- === BLINDAGEM VR (SEGURANÇA OBRIGATÓRIA) ===
local VRService = game:GetService("VRService")

if VRService.VREnabled then
	script:Destroy()
	return
end
-- ============================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()
local fireEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestFireMissile")

-- === CONFIGURAÇÕES ===
local CLICK_HOLD_THRESHOLD = 0.25
local NORMAL_FOV = 70
local AIM_FOV = 50
local NORMAL_SPEED = 16
local AIM_SPEED = 8
local MAX_DISTANCE = 1000 -- Distância máxima do tiro

local isHolding = false
local isAiming = false
local holdStartTime = 0

-- === FUNÇÃO PARA PEGAR O ALVO REAL (SOLUÇÃO DO BUG DO CHÃO) ===
local function getTrueTarget()
	local mouseRay = mouse.UnitRay -- Pega a direção exata para onde a câmera/mouse aponta

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {player.Character} -- Ignora o próprio player

	local result = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * MAX_DISTANCE, params)

	if result then
		-- Verificação crucial: Se o que atingimos está a menos de 6 studs da câmera,
		-- provavelmente é o chão "atravessado" pela câmera ou o próprio pé.
		local distFromCamera = (result.Position - camera.CFrame.Position).Magnitude
		if distFromCamera < 6 then
			return mouseRay.Origin + (mouseRay.Direction * MAX_DISTANCE)
		end

		return result.Position
	else
		-- Se estiver apontando para o céu, retorna um ponto distante no horizonte
		return mouseRay.Origin + (mouseRay.Direction * MAX_DISTANCE)
	end
end

local zoomInTween = TweenService:Create(camera, TweenInfo.new(0.2), {FieldOfView = AIM_FOV})
local zoomOutTween = TweenService:Create(camera, TweenInfo.new(0.2), {FieldOfView = NORMAL_FOV})

local function setAimState(state)
	isAiming = state
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")

	if isAiming then
		zoomInTween:Play()
		if humanoid then humanoid.WalkSpeed = AIM_SPEED end
	else
		zoomOutTween:Play()
		if humanoid then humanoid.WalkSpeed = NORMAL_SPEED end
	end
end

-- Input Began
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if player:GetAttribute("Missiles") > 0 then
			isHolding = true
			holdStartTime = tick()
		end
	end
end)

-- Input Ended
UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not isHolding then return end
		isHolding = false

		local targetPos = getTrueTarget() -- <--- USANDO A NOVA FUNÇÃO AQUI

		if isAiming then
			fireEvent:FireServer(targetPos, "AimedFire")
			setAimState(false)
		else
			if (tick() - holdStartTime) < CLICK_HOLD_THRESHOLD then
				fireEvent:FireServer(targetPos, "QuickFire")
			end
		end
	end
end)

-- Heartbeat
RunService.Heartbeat:Connect(function()
	if isHolding and not isAiming then
		if player:GetAttribute("Missiles") <= 0 then
			isHolding = false
			return
		end

		if (tick() - holdStartTime) >= CLICK_HOLD_THRESHOLD then
			setAimState(true)
		end
	end
end)

player.CharacterRemoving:Connect(function()
	if isAiming then setAimState(false) end
	camera.FieldOfView = NORMAL_FOV
end)