local VRService = game:GetService("VRService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local player = Players.LocalPlayer
local events = ReplicatedStorage:WaitForChild("Events")
local handshake = events:WaitForChild("Handshake")
local grabEvent = events:WaitForChild("GrabEvent")

-- == CONFIGURAÇÕES (Mantendo seus ajustes) ==
local GIANT_SCALE = 50  -- ESCALA ATUALIZADA
local START_HEIGHT = 18 
local HAND_VERTICAL_OFFSET = Vector3.new(0, 0, 0) -- Mãos mais baixas

local WALK_SPEED = 20 * 2.5 -- Ajustei a velocidade para a escala 50 (pra não ficar lento)
local SNAP_TURN_ANGLE = 45
local THROW_FORCE = 3.5 -- Mais força para objetos pesados
local VELOCITY_BUFFER_SIZE = 10
local GRAB_RADIUS = 6.0 
local GRAB_OFFSET = CFrame.new(0, -1, 0)

-- COMBATE
local GLOBAL_COOLDOWN = 1.0       
local THROW_COOLDOWN = 1.0        
local SMASH_MIN_VELOCITY = 60     
local FLOOR_OFFSET = 1.5          
local INPUT_TOLERANCE_OPEN = 0.1
local INPUT_TOLERANCE_CLOSED = 0.8

local ANIM_ID_RIGHT = "rbxassetid://135270474163426"
local ANIM_ID_LEFT  = "rbxassetid://77929376238501"

local RIGHT_FIX = CFrame.Angles(0, math.rad(180), math.rad(90))
local LEFT_FIX = CFrame.Angles(math.rad(180), 0, math.rad(-90))
local PUNCH_DIRECTION_OFFSET = CFrame.Angles(0, math.rad(180), 0) 

local worldPosition = Vector3.new(0, START_HEIGHT, 0)
local worldRotation = 0
local canSnapTurn = true

local hands = {
	Right = {BodyPart = nil, AnimTrack = nil, GrabWeld = nil, HeldObject = nil, VelHistory = {}, TriggerState = false, LastPos = Vector3.new(), GlobalCD = 0, LastThrowTime = 0},
	Left  = {BodyPart = nil, AnimTrack = nil, GrabWeld = nil, HeldObject = nil, VelHistory = {}, TriggerState = false, LastPos = Vector3.new(), GlobalCD = 0, LastThrowTime = 0}
}

-- VISUAL (SHOCKWAVE GRANDE)
local function CreateShockwave(position)
	local wave = Instance.new("Part")
	wave.Name = "SmashEffect"
	wave.Shape = Enum.PartType.Cylinder
	wave.Orientation = Vector3.new(0, 0, 90)
	wave.Position = position
	wave.Size = Vector3.new(1, 1, 1)
	wave.Color = Color3.fromRGB(255, 255, 255)
	wave.Material = Enum.Material.Neon
	wave.Anchored = true
	wave.CanCollide = false
	wave.Parent = Workspace

	-- Tamanho aumentado para escala 50
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {Size = Vector3.new(1, 60, 60), Transparency = 1}
	local tween = TweenService:Create(wave, tweenInfo, goal)
	tween:Play()
	tween.Completed:Connect(function() wave:Destroy() end)
end

-- UTILITÁRIOS
local function GetSmoothedVelocity(history)
	if #history == 0 then return Vector3.new(0,0,0) end
	local sum = Vector3.new(0,0,0)
	for _, v in ipairs(history) do sum = sum + v end
	return sum / #history
end

local function UpdateVelocityHistory(history, newVel)
	table.insert(history, newVel)
	if #history > VELOCITY_BUFFER_SIZE then table.remove(history, 1) end
end

local function SetupAnimation(handModel, side, animId)
	local animController = handModel:FindFirstChild("AnimationController") or Instance.new("AnimationController", handModel)
	local animator = animController:FindFirstChild("Animator") or Instance.new("Animator", animController)
	local animation = Instance.new("Animation")
	animation.AnimationId = animId
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play()
	track.TimePosition = 0
	track:AdjustSpeed(0)
	hands[side].AnimTrack = track
end

-- GRAB (MODIFICADO PARA PEGAR ANCORADOS)
local function TryGrab(side)
	local handData = hands[side]
	if handData.HeldObject then return end 

	if (tick() - handData.GlobalCD) < GLOBAL_COOLDOWN then return end
	if (tick() - handData.LastThrowTime) < THROW_COOLDOWN then return end

	local palm = handData.BodyPart; if not palm then return end
	local overlapParams = OverlapParams.new(); overlapParams.FilterDescendantsInstances = {player.Character}; overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local parts = Workspace:GetPartBoundsInRadius(palm.Position, GRAB_RADIUS * (GIANT_SCALE/15), overlapParams)

	for _, part in pairs(parts) do
		local character = part.Parent
		if character:IsA("Accessory") then character = character.Parent end
		local isGrabbable = (part:GetAttribute("Grab") == true) or character:FindFirstChild("Humanoid")

		-- [[ MUDANÇA AQUI: Removi o "and not part.Anchored" ]]
		-- Agora ele aceita pegar coisas ancoradas (árvores), o servidor vai soltar elas.
		if isGrabbable then
			grabEvent:FireServer(part, "Grab")
			part.CFrame = palm.CFrame * GRAB_OFFSET
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = palm; weld.Part1 = part; weld.Parent = part; part.Massless = true 
			handData.HeldObject = part; handData.GrabWeld = weld; handData.VelHistory = {} 
			break 
		end
	end
end

local function Release(side)
	local handData = hands[side]
	if handData.HeldObject and handData.GrabWeld then
		local obj = handData.HeldObject
		handData.GrabWeld:Destroy()
		obj.Massless = false
		local smoothVel = GetSmoothedVelocity(handData.VelHistory)
		obj.AssemblyLinearVelocity = smoothVel * THROW_FORCE
		grabEvent:FireServer(obj, "Release")
		handData.LastThrowTime = tick()
		handData.HeldObject = nil
		handData.GrabWeld = nil
	end
end

RunService.RenderStepped:Connect(function(dt)
	if not VRService.VREnabled then return end
	Camera.HeadScale = GIANT_SCALE

	local state = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	local valR2, valL2, valR1, valL1 = 0, 0, 0, 0
	local rightStick, leftStick = Vector2.new(), Vector2.new()

	for _, input in pairs(state) do
		if input.KeyCode == Enum.KeyCode.ButtonR2 then valR2 = input.Position.Z end 
		if input.KeyCode == Enum.KeyCode.ButtonL2 then valL2 = input.Position.Z end
		if input.KeyCode == Enum.KeyCode.ButtonR1 then valR1 = (input.Position.Z > 0.5) and 1 or 0 end 
		if input.KeyCode == Enum.KeyCode.ButtonL1 then valL1 = (input.Position.Z > 0.5) and 1 or 0 end
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then rightStick = input.Position end
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then leftStick = input.Position end
	end

	if hands.Right.AnimTrack then hands.Right.AnimTrack.TimePosition = hands.Right.AnimTrack.Length * math.min(valR2, 0.999) end
	if hands.Left.AnimTrack then hands.Left.AnimTrack.TimePosition = hands.Left.AnimTrack.Length * math.min(valL2, 0.999) end

	local isRightFist = valR1 > 0.5 
	if valR2 > 0.5 and not isRightFist then
		if not hands.Right.TriggerState then hands.Right.TriggerState = true; if not hands.Right.HeldObject then TryGrab("Right") end end
	else
		if hands.Right.TriggerState then hands.Right.TriggerState = false; if hands.Right.HeldObject then Release("Right") end end
	end

	local isLeftFist = valL1 > 0.5
	if valL2 > 0.5 and not isLeftFist then
		if not hands.Left.TriggerState then hands.Left.TriggerState = true; if not hands.Left.HeldObject then TryGrab("Left") end end
	else
		if hands.Left.TriggerState then hands.Left.TriggerState = false; if hands.Left.HeldObject then Release("Left") end end
	end

	-- LOCOMOÇÃO
	if math.abs(rightStick.X) > 0.5 then
		if canSnapTurn then worldRotation = worldRotation + math.rad(SNAP_TURN_ANGLE * (rightStick.X > 0 and -1 or 1)); canSnapTurn = false end
	else canSnapTurn = true end

	if leftStick.Magnitude > 0.2 then
		local fwd = Camera.CFrame.LookVector; local flatFwd = Vector3.new(fwd.X, 0, fwd.Z).Unit; local flatRight = flatFwd:Cross(Vector3.new(0, 1, 0))
		local move = (flatFwd * leftStick.Y) + (flatRight * leftStick.X)
		worldPosition = worldPosition + (move * WALK_SPEED * dt)
	end

	local originCF = CFrame.new(worldPosition) * CFrame.Angles(0, worldRotation, 0)
	Camera.CFrame = originCF * VRService:GetUserCFrame(Enum.UserCFrame.Head)

	-- FÍSICA E COMBATE
	local function UpdateHandPhysics(side, enumHand, fixCF, tVal, gVal)
		local hData = hands[side]
		if not hData.BodyPart then return end
		local cfRaw = VRService:GetUserCFrame(enumHand)
		local offsetCF = cfRaw + HAND_VERTICAL_OFFSET
		local targetCF = (Camera.CFrame * CFrame.new(offsetCF.p * (GIANT_SCALE - 1))) * offsetCF * fixCF

		local ignoreList = {player.Character} 
		if hData.HeldObject then
			table.insert(ignoreList, hData.HeldObject)
			if hData.HeldObject.Parent then table.insert(ignoreList, hData.HeldObject.Parent) end
		end

		local rayOrigin = targetCF.Position + Vector3.new(0, 10, 0) 
		local rayParams = RaycastParams.new(); rayParams.FilterDescendantsInstances = ignoreList; rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local ray = workspace:Raycast(rayOrigin, Vector3.new(0, -30, 0), rayParams)

		local hitFloor = false
		local isRealFloor = false

		if ray then
			if ray.Instance:GetAttribute("IsFloor") == true or ray.Instance.Name == "Baseplate" then isRealFloor = true end
			local floorLimit = ray.Position.Y + FLOOR_OFFSET
			if targetCF.Position.Y < floorLimit then
				targetCF = CFrame.new(targetCF.Position.X, floorLimit, targetCF.Position.Z) * targetCF.Rotation
				hitFloor = true
			end
		end

		local curVel = Vector3.new(); if dt > 0 then curVel = (targetCF.Position - hData.LastPos)/dt; UpdateVelocityHistory(hData.VelHistory, curVel) end
		hData.LastPos = targetCF.Position

		local bp = hData.BodyPart:FindFirstChild("BodyPosition")
		local bg = hData.BodyPart:FindFirstChild("BodyGyro")
		if bp and bg then bp.Position = targetCF.Position; bg.CFrame = targetCF end

		local isOnCooldown = (tick() - hData.GlobalCD) < GLOBAL_COOLDOWN
		local isThrowCooldown = (tick() - hData.LastThrowTime) < THROW_COOLDOWN

		if hitFloor and isRealFloor and curVel.Y < -SMASH_MIN_VELOCITY and not isOnCooldown and not isThrowCooldown then
			if tVal < INPUT_TOLERANCE_OPEN then
				hData.GlobalCD = tick()
				CreateShockwave(ray and ray.Position or targetCF.Position)
				grabEvent:FireServer(hData.BodyPart, "Smash")
			elseif tVal > INPUT_TOLERANCE_CLOSED and gVal > 0.8 then
				hData.GlobalCD = tick()
				local rawLook = (targetCF * PUNCH_DIRECTION_OFFSET).LookVector
				local flatLook = Vector3.new(rawLook.X, 0, rawLook.Z).Unit 
				grabEvent:FireServer(hData.BodyPart, "Punch", flatLook) 
			end
		end
	end

	UpdateHandPhysics("Right", Enum.UserCFrame.RightHand, RIGHT_FIX, valR2, valR1)
	UpdateHandPhysics("Left", Enum.UserCFrame.LeftHand, LEFT_FIX, valL2, valL1)
end)

local function Start(char)
	task.wait(1) 
	char:WaitForChild("Head").Transparency = 1 
	local rHand = char:WaitForChild("RightHand"); local lHand = char:WaitForChild("LeftHand")
	local rRoot = rHand:IsA("Model") and (rHand:FindFirstChild("RootPart") or rHand.PrimaryPart) or rHand
	local lRoot = lHand:IsA("Model") and (lHand:FindFirstChild("RootPart") or lHand.PrimaryPart) or lHand
	if rHand:IsA("Model") then SetupAnimation(rHand, "Right", ANIM_ID_RIGHT) end
	if lHand:IsA("Model") then SetupAnimation(lHand, "Left", ANIM_ID_LEFT) end
	hands.Right.BodyPart = rRoot; hands.Left.BodyPart = lRoot

	local head = char:WaitForChild("Head") 
	print("CLIENT VR: Aguardando teleporte do servidor...")
	local attempts = 0
	while (head.Position - Vector3.new(0, 10, 0)).Magnitude < 10 and attempts < 50 do
		task.wait(0.1)
		attempts = attempts + 1
	end

	local spawnPos = head.Position
	worldPosition = Vector3.new(spawnPos.X, spawnPos.Y - (START_HEIGHT - 5), spawnPos.Z)
	local rotPart = char.PrimaryPart or head
	local _, yRot, _ = rotPart.CFrame:ToEulerAnglesYXZ()
	worldRotation = yRot

	print("CLIENT VR: Sincronizado! (Escala 50 + Skin do Player)")
end

player.CharacterAdded:Connect(Start)
if player.Character then Start(player.Character) else handshake:FireServer(VRService.VREnabled) end