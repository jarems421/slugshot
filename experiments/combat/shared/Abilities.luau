--!strict
-- Slug abilities shared by server and clients (docs/slugs/ability-specs.md, owner 2026-11-06). Q arms a slug's main
-- and E its passive for the next shot. Values are the confirmed specs' starting numbers for playtesting.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Abilities = {}

export type Kind = string -- "main" (armed with Q) or "passive" (armed with E)

export type Crashwave = {
	Name: string,
	Cooldown: number,
	Reach: number, -- studs the wave travels after the hit
	Width: number,
	Height: number,
	Speed: number, -- studs/s; faster than running
	Share: number, -- of the direct hit's damage, to each enemy it touches
	Soak: number, -- seconds soaked
	StepUp: number, -- tallest rise it climbs in one go, like a stair
	Drop: number, -- deepest drop it follows before stopping at a ledge
}

export type Mistbank = {
	Name: string,
	Cooldown: number,
	Cap: number,
	Diameter: number,
	Lifetime: number,
	Grow: number,
	Fade: number,
	SoakAfter: number, -- seconds still soaked after leaving it
	View: number, -- studs you can see inside
}

Abilities.Kits = {
	Aquabeek = {
		main = {
			Name = "Crashwave",
			Cooldown = 6,
			Reach = 25,
			Width = 6,
			Height = 4,
			Speed = 40,
			Share = 1 / 3,
			Soak = 4,
			StepUp = 2.6,
			Drop = 4,
		} :: Crashwave,
		passive = {
			Name = "Mistbank",
			Cooldown = 4,
			Cap = 2,
			Diameter = 14,
			Lifetime = 8,
			Grow = 0.5,
			Fade = 0.6,
			SoakAfter = 2,
			View = 4,
		} :: Mistbank,
	},
}

-- Shared combat rules (ability-specs.md, "Shared combat rules").
Abilities.ControlImmunity = 3 -- seconds after any control effect ends
Abilities.MinSpeedScale = 0.5 -- slows never add up, and never go below this
Abilities.TeamObjectBudget = 24 -- placed objects per team; tuned in playtests
Abilities.Healers = { BoonDoc = true } :: { [string]: boolean } -- the only slugs that hit teammates

-- Statuses live as attributes on the character or dummy: `Status<Name>` holds the server time it ends and
-- `Status<Name>Team` the team that caused it. Models with any status carry this tag for clients.
Abilities.StatusTag = "SlugshotStatus"
Abilities.MistTag = "SlugshotMist"
Abilities.CoverTag = "SlugshotCover"

function Abilities.kit(slugId: string?): { main: any?, passive: any? }?
	return if slugId then (Abilities.Kits :: any)[slugId] else nil
end

function Abilities.ability(slugId: string?, kind: Kind): any?
	local kit = Abilities.kit(slugId)
	return kit and (kit :: any)[kind]
end

-- Only the strongest slow counts, never below the floor; no slows is full speed.
function Abilities.speedScale(slows: { number }): number
	local scale = 1
	for _, slow in slows do
		scale = math.min(scale, slow)
	end
	return math.clamp(scale, Abilities.MinSpeedScale, 1)
end

-- Players are on a Team, or carry a SlugshotTeam attribute in test places; dummies carry the attribute.
function Abilities.teamOf(model: Instance?): string?
	if not model then
		return nil
	end
	local player = if model:IsA("Player") then model else Players:GetPlayerFromCharacter(model)
	if player then
		if player.Team then
			return player.Team.Name
		end
		local named = player:GetAttribute("SlugshotTeam")
		return if typeof(named) == "string" then named else nil
	end
	local named = model:GetAttribute("SlugshotTeam")
	return if typeof(named) == "string" then named else nil
end

-- Your own character counts as an ally. Two models without teams are enemies.
function Abilities.allies(a: Instance?, b: Instance?): boolean
	if a == nil or b == nil then
		return false
	end
	if a == b then
		return true
	end
	local teamA, teamB = Abilities.teamOf(a), Abilities.teamOf(b)
	return teamA ~= nil and teamA == teamB
end

-- What a slug fired by `player` passes through: their own character and their teammates' characters and dummies.
-- Only healing slugs hit teammates. Server and client both filter shots with this.
function Abilities.passThrough(player: Player, slugId: string): { Instance }
	local list: { Instance } = {}
	if player.Character then
		table.insert(list, player.Character)
	end
	if Abilities.Healers[slugId] or not Abilities.teamOf(player) then
		return list
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character and Abilities.allies(player, other) then
			table.insert(list, other.Character)
		end
	end
	for _, model in CollectionService:GetTagged("RangeDummy") do
		if Abilities.allies(player, model) then
			table.insert(list, model)
		end
	end
	return list
end

-- Whether a point is inside any Mistbank (clients use it for the murk and for hiding name tags).
function Abilities.insideMist(point: Vector3): boolean
	for _, mist in CollectionService:GetTagged(Abilities.MistTag) do
		if mist:IsA("BasePart") and (point - mist.Position).Magnitude < mist.Size.X / 2 then
			return true
		end
	end
	return false
end

function Abilities.statusEnds(model: Instance, name: string): number
	local value = model:GetAttribute(`Status{name}`)
	return if typeof(value) == "number" then value else 0
end

function Abilities.hasStatus(model: Instance, name: string, now: number): boolean
	return Abilities.statusEnds(model, name) > now
end

return table.freeze(Abilities)
