local abilityController = {}

local HTTPService = game:GetService("HttpService")
local ReplicatedStorage = game.ReplicatedStorage

local Modules = require(ReplicatedStorage.modules)
local network = Modules.load("network")
local Utilities = Modules.load("utilities")
local AbilityUtilities = Modules.load("ability_utilities")

local AbilityLookup = require(ReplicatedStorage.abilityLookup)

function abilityController.abilityUseRequest(abilityId)
	local player = game.Players.LocalPlayer
	local character = player.Character
	local root = character.PrimaryPart
	if not player or not character or not root or not abilityId then return false, "nil player/abilityId" end

	--Check if Ability of abilityId exists in abilityLookup
	local abilityModule = AbilityLookup[abilityId]
	if not abilityModule then return false, "invalid_abilityId" end

	--Check if player can Cast locally using AbilityUtilities
	local playerData = network:invoke("getLocalPlayerDataCache")

	local canCast, err = AbilityUtilities.canPlayerCast(player, playerData, abilityId)
	if canCast then
		--Generate abilityCastGuid and encode it
		local abilityGuid = HTTPService:GenerateGUID()
		local abilityGuidJSON = Utilities.safeJSONEncode({abilityGuid})

		--Get Mouse Position and Starting Cast Tick
		local mousePosition = player:GetMouse().Hit.Position
		local castTick = tick()

		--Get player states HERE
		local casterStates = {}

		local abilityDataCopy = Utilities.copyTable(abilityModule)
		local increasingStat, newStatData = AbilityUtilities.calculateStats(playerData, abilityId)

		abilityDataCopy.statistics[increasingStat] = newStatData

		--Set executionData
		local executionData = {
			caster = player,
			casterCharacter = character,
			casterRoot = root,
			casterStates = casterStates,
			castTick = castTick,
			abilityId = abilityId,
			abilityGuid = abilityGuid,
			abilityGuidJSON = abilityGuidJSON,
			targetPosition = mousePosition,
			abilityData = abilityDataCopy
		}

		--Call Remote for changing Ability State ("begin")
		network:fireServer("requestAbilityStateUpdate", "begin", executionData)

		--Execute Ability Locally
		abilityModule:execute(executionData, true)

		network:fireServer("requestAbilityStateUpdate", "end", executionData)
	else
		warn(err)
	end
end

function abilityController.replicateAbilityLocally(executionData, isSource)
	if not executionData then return "invalid_executionData" end

	local abilityModule = AbilityLookup[executionData.abilityId]
	if abilityModule then
		abilityModule:execute(executionData, isSource)
	end
end

function abilityController.replicateAbilityUpdateLocally(executionData, isSource)
	if not executionData then return "invalid_executionData" end

	local abilityModule = AbilityLookup[executionData.abilityId]
	if abilityModule then
		abilityModule:execute_update(executionData, isSource)
	end
end


function abilityController.init()
	--N/A
	network:create("abilityUseRequest", "BindableFunction", "OnInvoke", abilityController.abilityUseRequest)
	network:create("replicateAbilityLocally", "RemoteEvent", "OnClientEvent", abilityController.replicateAbilityLocally)
	network:create("replicateAbilityUpdateLocally", "RemoteEvent", "OnClientEvent", abilityController.replicateAbilityUpdateLocally)
end

return abilityController