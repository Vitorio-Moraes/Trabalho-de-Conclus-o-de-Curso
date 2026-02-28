local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local character = script.Parent
local player = Players:GetPlayerFromCharacter(character)
-- Pega o Torso corretamente (R6 ou R15)
local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")

-- --- CONFIGURAÇÕES ---
local MAX_MISSILES = 5
local ATTRIBUTE_NAME = "Missiles"
local BACKPACK_MODEL = ReplicatedStorage.Assets:WaitForChild("MissileBackpack")

-- AJUSTE DE POSIÇÃO (OFFSET)
-- CFrame.new(X, Y, Z)
-- X: Negativo = Esquerda / Positivo = Direita
-- Y: Altura
-- Z: Positivo = Para Trás
local POSITION_OFFSET = CFrame.new(-0.2, 0, 0.8) -- Ajustado: Mais p/ Esq (-0.2) e Trás (0.8)

local currentBackpack = nil

local function updateMissiles()
	if not currentBackpack then return end

	-- TENTATIVA 1: Busca no Personagem (Boneco 3D)
	local rawAmount = character:GetAttribute(ATTRIBUTE_NAME)

	-- TENTATIVA 2: Se não achar no boneco, busca no Player (Lista de Jogadores)
	if rawAmount == nil and player then
		rawAmount = player:GetAttribute(ATTRIBUTE_NAME)
	end

	-- SEGURANÇA: Se continuar nil (não achou em lugar nenhum), assume 5 (CHEIO) pra não sumir tudo
	-- Antes estava "or 0", por isso sumia. Agora vai ficar cheio se der erro.
	local amount = tonumber(rawAmount) or MAX_MISSILES 

	-- Trava entre 0 e 5
	if amount > MAX_MISSILES then amount = MAX_MISSILES end
	if amount < 0 then amount = 0 end

	print("--- STATUS ---")
	print("Atributo achado? " .. (rawAmount ~= nil and "SIM" or "NÃO (Usando padrão)"))
	print("Mísseis visíveis: " .. amount)

	for i = 1, MAX_MISSILES do
		local missileName = tostring(i) 
		local missile = currentBackpack:FindFirstChild(missileName)

		if missile then
			-- Lógica de visibilidade
			local shouldBeVisible = (i <= amount)
			local targetTransparency = shouldBeVisible and 0 or 1

			if missile:IsA("BasePart") then
				missile.Transparency = targetTransparency
			else
				for _, part in ipairs(missile:GetDescendants()) do
					if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
						part.Transparency = targetTransparency
					end
				end
			end
		end
	end
end

local function setupBackpack()
	-- Limpa mochila antiga se houver (caso de respawn ou reset)
	if currentBackpack then currentBackpack:Destroy() end

	-- 1. Clona
	currentBackpack = BACKPACK_MODEL:Clone()

	if not currentBackpack.PrimaryPart then
		warn("ERRO CRÍTICO: O modelo 'MissileBackpack' não tem PrimaryPart definida!")
		return
	end

	-- 2. Posiciona (Offset ajustado aqui)
	currentBackpack:PivotTo(torso.CFrame * POSITION_OFFSET)

	-- 3. Coloca no personagem
	currentBackpack.Parent = character

	-- 4. Solda (WeldConstraint)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = currentBackpack.PrimaryPart
	weld.Parent = currentBackpack.PrimaryPart

	-- 5. Configura física (Essencial)
	for _, part in pairs(currentBackpack:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end

	-- Chama a atualização visual logo após criar para garantir que comece certo
	updateMissiles()
end

-- --- INICIALIZAÇÃO ---

-- Espera um pouco para garantir que o personagem carregou tudo
task.wait(0.5) 
setupBackpack()

-- --- ESCUTAR MUDANÇAS ---

-- Escuta no Personagem (caso o atributo esteja lá)
character:GetAttributeChangedSignal(ATTRIBUTE_NAME):Connect(updateMissiles)

-- Escuta no Player também (caso o atributo esteja lá)
if player then
	player:GetAttributeChangedSignal(ATTRIBUTE_NAME):Connect(updateMissiles)
end