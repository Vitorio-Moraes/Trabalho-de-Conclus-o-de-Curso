local PhysicsService = game:GetService("PhysicsService")

local function SetupGroups()
	-- Cria grupos (pcall para evitar erro se já existirem)
	pcall(function() PhysicsService:RegisterCollisionGroup("GiantBody") end)
	pcall(function() PhysicsService:RegisterCollisionGroup("GiantHand") end)
	pcall(function() PhysicsService:RegisterCollisionGroup("HeldObject") end) -- NOVO
	pcall(function() PhysicsService:RegisterCollisionGroup("Map") end)

	-- REGRAS DE COLISÃO:
	-- 1. Mão não bate no corpo do gigante
	PhysicsService:CollisionGroupSetCollidable("GiantHand", "GiantBody", false)
	-- 2. Mão não bate em Mão
	PhysicsService:CollisionGroupSetCollidable("GiantHand", "GiantHand", false)

	-- 3. Mão NÃO bate no Objeto Segurado (A SOLUÇÃO DO TREMOR)
	PhysicsService:CollisionGroupSetCollidable("GiantHand", "HeldObject", false)

	-- 4. Objeto Segurado NÃO bate no corpo do Gigante (Pra não te empurrar)
	PhysicsService:CollisionGroupSetCollidable("GiantBody", "HeldObject", false)

	-- 5. Mão bate no Mapa/Default? Sim, para interagir.
	PhysicsService:CollisionGroupSetCollidable("GiantHand", "Default", true)
end

SetupGroups()

-- Função global auxiliar
function _G.ApplyGiantGroups(character)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "RightHand" or part.Name == "LeftHand" or part:IsDescendantOf(character:FindFirstChild("RightHand")) or part:IsDescendantOf(character:FindFirstChild("LeftHand")) then
				part.CollisionGroup = "GiantHand"
				part.Massless = true 
			else
				part.CollisionGroup = "GiantBody"
			end
		end
	end
end