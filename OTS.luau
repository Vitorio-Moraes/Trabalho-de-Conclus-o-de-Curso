local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Configurações iniciais
local mouseLocked = true
local cameraAngleX = 0
local cameraAngleY = 0
local cameraOffset = Vector3.new(3, 3, 16) 

-- 1. SUBSTITUI O ÍCONE DO MOUSE PELA CROSSHAIR
mouse.Icon = "rbxassetid://117431027"


local function updateMouseState()
	if mouseLocked then
		-- Prende o mouse no centro e garante que o ícone apareça lá
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		camera.CameraType = Enum.CameraType.Scriptable
	else
		-- Solta o mouse para interagir com a tela
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- 2. TOGGLE PARA SOLTAR/PRENDER O MOUSE (SHIFT)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- Ignora se estiver digitando no chat

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		mouseLocked = not mouseLocked
		updateMouseState()
	end
end)

player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")

	humanoid.AutoRotate = false
	updateMouseState()

	-- Captura o movimento do mouse para girar a câmera
	local function playerInput(actionName, inputState, inputObject)
		if mouseLocked and inputState == Enum.UserInputState.Change then
			cameraAngleX = cameraAngleX - inputObject.Delta.X
			cameraAngleY = math.clamp(cameraAngleY - inputObject.Delta.Y * 0.4, -75, 75)
		end
	end

	ContextActionService:BindAction("CameraMovement", playerInput, false, Enum.UserInputType.MouseMovement, Enum.UserInputType.Touch)

	-- Atualização por Frame
	RunService:BindToRenderStep("CameraUpdate", Enum.RenderPriority.Camera.Value, function()
		if not mouseLocked then return end

		-- Cálculo da posição da câmera baseado nos ângulos
		local startCFrame = CFrame.new(rootPart.CFrame.Position) * 
			CFrame.Angles(0, math.rad(cameraAngleX), 0) * 
			CFrame.Angles(math.rad(cameraAngleY), 0, 0)

		local cameraCFrame = startCFrame:PointToWorldSpace(cameraOffset)
		local cameraFocus = startCFrame:PointToWorldSpace(Vector3.new(cameraOffset.X, cameraOffset.Y, -100000))

		camera.CFrame = CFrame.lookAt(cameraCFrame, cameraFocus)

		-- Faz o personagem virar para onde a mira aponta
		local lookingCFrame = CFrame.lookAt(rootPart.Position, camera.CFrame:PointToWorldSpace(Vector3.new(0, 0, -100000)))
		rootPart.CFrame = CFrame.fromMatrix(rootPart.Position, lookingCFrame.XVector, rootPart.CFrame.YVector)
	end)
end)