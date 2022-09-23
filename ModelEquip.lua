--[[

	$$\      $$\$$\   $$\$$$$$$\$$\   $$\ $$$$$$\ $$$$$$\$$$$$$$$\$$\     $$\ 
	$$ | $\  $$ $$ |  $$ \_$$  _$$$\  $$ $$  __$$\\_$$  _$$  _____\$$\   $$  |
	$$ |$$$\ $$ $$ |  $$ | $$ | $$$$\ $$ $$ /  \__| $$ | $$ |      \$$\ $$  / 
	$$ $$ $$\$$ $$$$$$$$ | $$ | $$ $$\$$ $$ |       $$ | $$$$$\     \$$$$  /  
	$$$$  _$$$$ $$  __$$ | $$ | $$ \$$$$ $$ |       $$ | $$  __|     \$$  /   
	$$$  / \$$$ $$ |  $$ | $$ | $$ |\$$$ $$ |  $$\  $$ | $$ |         $$ |    
	$$  /   \$$ $$ |  $$ $$$$$$\$$ | \$$ \$$$$$$  $$$$$$\$$ |         $$ |    
	\__/     \__\__|  \__\______\__|  \__|\______/\______\__|         \__|                                                                       
       
    || INTRODUCTION ||
    
    ModelEquip v2.0.0 by @Whincify
    
    ModelEquip allows you to weld models to a players character. This is useful for fake guns, tools, armor, etc.
    
    || DOCUMENTATION ||
    
    SETTINGS (CHANGE SETTINGS VIA MODULE ATTRIBUTES):
    
    AutomaticallyWeld (true, false) - If true, models will be automatically welded before being added to the character.
    PersistDeath (true, false) - If true, characters will respawn with models until they are removed.
    DetectUpdates (true, false) - If true, the module will check & notify you if an update available.
    
    USAGE:
    
    ModelEquip.Init() - Initializes the module.
    ModelEquip:Add(humanoid:Humanoid, model:string, overridePersistant:boolean) - Adds the specified model to the character. 
    ModelEquip:Remove(humanoid:Humanoid, model:string) -- Removes the specified model from a character.
       
]]-- 

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local settings = {
	AutomaticallyWeld = script:GetAttribute("AutomaticallyWeld"),
	PersistDeath = script:GetAttribute("AutomaticallyWeld"),
	DetectUpdates = script:GetAttribute("DetectUpdates")
}

local ModelEquip = {
	Version = "2.0.0",
	Initialized = false,
	ActivePlayers = {},
}

local function GetRigType(humanoid:Humanoid)
	local rigType = humanoid.RigType

	if (rigType == Enum.HumanoidRigType.R6) then
		return "R6"
	elseif (rigType == Enum.HumanoidRigType.R15) then
		return "R15"
	else
		return warn("[MODEL EQUIP] Invalid humanoid!")
	end
end

local function UpdateWelds(model:Model)
	if settings["AutomaticallyWeld"] then
		for i, v in model:GetDescendants() do
			if (v:IsA("WeldConstraint") or v:IsA("Weld")) then
				v:Destroy()
			end
		end

		for i, v in model:GetDescendants() do
			if v:IsA("BasePart") then
				if (model.PrimaryPart == v) then continue end

				local weld = Instance.new("WeldConstraint",model.PrimaryPart)
				weld.Part0 = v
				weld.Part1 = model.PrimaryPart
			end
		end
	end
end

function ModelEquip:Add(humanoid:Humanoid, model:string, overridePersistant:boolean)
	local character = humanoid.Parent

	if (not character.PrimaryPart or humanoid.Health <= 0) then
		return
	end

	local modelDir = script:FindFirstChild(model)

	if (not modelDir) then
		return warn("[MODEL EQUIP] Invalid model!")
	end

	local rigType = GetRigType(humanoid)
	local bodyPart = modelDir.Body:FindFirstChild(rigType).Value

	if (not bodyPart or not modelDir) then
		return
	end

	local associatedPart = character:FindFirstChild(bodyPart.Name)

	if (not associatedPart) then
		return warn("[MODEL EQUIP] "..bodyPart.Name.." is not a valid BodyPart!")
	end

	model = modelDir:FindFirstChildOfClass("Model"):Clone()

	UpdateWelds(model)

	model.Name = modelDir.Name

	local relativeCFrame = bodyPart.CFrame:Inverse() * model.PrimaryPart.CFrame

	model.Parent = character
	model:SetPrimaryPartCFrame(associatedPart.CFrame * relativeCFrame)

	local modelToBody = Instance.new("WeldConstraint",model)
	modelToBody.Part0 = model.PrimaryPart
	modelToBody.Part1 = associatedPart
	model.PrimaryPart.Anchored = false

	if (settings["PersistDeath"] and (not overridePersistant)) then
		local player = Players:GetPlayerFromCharacter(character)

		local alreadyActive = false

		for i, v in self.ActivePlayers[player.UserId] do
			if (v[1] == model) then
				alreadyActive = true
				break
			end
		end

		if (not alreadyActive) then
			table.insert(self.ActivePlayers[player.UserId],{modelDir.Name,true})
		end
	end
end

function ModelEquip:Remove(humanoid:Humanoid, model:string)
	local character = humanoid.Parent

	if (not character.PrimaryPart or humanoid.Health <= 0) then
		return
	end

	local modelDir = script:FindFirstChild(model)

	if (not modelDir) then
		return warn("[MODEL EQUIP] Invalid model!")
	end

	if character:FindFirstChild(model) then
		character:FindFirstChild(model):Destroy()

		if settings["PersistDeath"] then
			local player = Players:GetPlayerFromCharacter(character)

			for i, v in self.ActivePlayers[player.UserId] do
				if (v[1] == model) then
					table.remove(self.ActivePlayers[player.UserId],i)
					break
				end
			end
		end
	end
end

function ModelEquip:Init()
	if (not self.Initialized) then
		self.Initialized = true

		if settings["DetectUpdates"] then
			local success, err = pcall(function()
				local ModuleInfo = MarketplaceService:GetProductInfo(10980601269,Enum.InfoType.Asset)
				
				local LatestVersion = string.gsub(ModuleInfo.Description,"Current Version: ","")
				
				if (LatestVersion ~= self.Version) then
					warn("[MODEL EQUIP] A new version of the module is available! https://www.roblox.com/library/10980601269/ModelEquip")
				end
			end)
			
			if err then
				warn("[MODEL EQUIP] Unable to check for updates due to the following error: "..err)
			end
		end

		if settings["PersistDeath"] then
			workspace.ChildAdded:Connect(function(child)
				if (not child:IsA("Model")) then
					return
				end

				local player = Players:GetPlayerFromCharacter(child)

				if (player and self.ActivePlayers[player.UserId]) then
					repeat task.wait() until (child.PrimaryPart and child:FindFirstChildOfClass("Humanoid"))

					for i, v in self.ActivePlayers[player.UserId] do
						if v[2] then
							self:Add(child:FindFirstChildOfClass("Humanoid"),v[1],true)
						end
					end
				end
			end)
			
			for i, v in Players:GetPlayers() do
				if (not self.ActivePlayers[v.UserId]) then
					self.ActivePlayers[v.UserId] = {}
				end
			end

			Players.PlayerAdded:Connect(function(player)
				self.ActivePlayers[player.UserId] = {}
			end)

			Players.PlayerRemoving:Connect(function(player)
				if self.ActivePlayers[player.UserId] then
					self.ActivePlayers[player.UserId] = nil
				end
			end)
		end
	else
		return warn("[MODEL EQUIP] Module has already been initialized!")
	end
end

return ModelEquip
