--!strict
-- One transformation sequence; species choose their palette, size and motion/aura overrides here.
-- Fire carried by Inferno's authored model belongs to that model, not the shared transformation.
local Styles = {}

export type Motion = {
	spinTurns: number,
	baseShrink: number,
	revealScale: number,
	revealRoll: number,
	revealTime: number,
	foldTime: number,
	tilt: number,
	tiltRate: number,
}
export type Aura = {
	startSize: number,
	peakSize: number,
	fadeTime: number,
	strength: number,
	coreStrength: number,
	lightRange: number,
	lightBrightness: number,
}
export type Style = {
	formScale: number,
	glow: Color3,
	core: Color3,
	motion: Motion,
	aura: Aura,
}

-- Clone a default table for a species that needs a different twirl, reveal or falloff. Shared defaults are immutable.
Styles.DefaultMotion = table.freeze({
	spinTurns = 1.75,
	baseShrink = 0.68,
	revealScale = 0.72,
	revealRoll = 0.45,
	revealTime = 0.1,
	foldTime = 0.13,
	tilt = 0.08,
	tiltRate = 7,
}) :: Motion
Styles.DefaultAura = table.freeze({
	startSize = 3,
	peakSize = 12,
	fadeTime = 0.12,
	strength = 0.8,
	coreStrength = 0.75,
	lightRange = 14,
	lightBrightness = 4,
}) :: Aura

local PLAIN: Style = {
	formScale = 1,
	glow = Color3.fromRGB(190, 225, 255),
	core = Color3.fromRGB(255, 255, 255),
	motion = Styles.DefaultMotion,
	aura = Styles.DefaultAura,
}

local styles: { [string]: Style } = {
	Inferno = {
		formScale = 2.6,
		glow = Color3.fromRGB(255, 122, 28),
		core = Color3.fromRGB(255, 240, 190),
		motion = Styles.DefaultMotion,
		aura = Styles.DefaultAura,
	},
	-- Rammstone: the same twirl and diffuse glow as Inferno's, in rock red, into his flying brute (owner: "make sure the
	-- transformation is similar to Burpee's"); his red trail and pebbles are RammstoneMotion's.
	Rammstone = {
		formScale = 2.6,
		glow = Color3.fromRGB(235, 52, 32),
		core = Color3.fromRGB(255, 205, 170),
		motion = Styles.DefaultMotion,
		aura = Styles.DefaultAura,
	},
	-- Aquabeek: the same twirl and diffuse glow, in her bioluminescent aqua, into her bladed flying form; her water
	-- trail and droplets are AquabeekMotion's.
	Aquabeek = {
		formScale = 2.6,
		glow = Color3.fromRGB(56, 204, 242),
		core = Color3.fromRGB(205, 245, 255),
		motion = Styles.DefaultMotion,
		aura = Styles.DefaultAura,
	},
	-- Tormato: the same twirl and glow in his vermilion, into his little red dragon; his wind trails are TormatoMotion's.
	Tormato = {
		formScale = 2.6,
		glow = Color3.fromRGB(232, 78, 46),
		core = Color3.fromRGB(240, 246, 255),
		motion = Styles.DefaultMotion,
		aura = Styles.DefaultAura,
	},
	-- Boon Doc: the same twirl and glow in his healing mint with a gold core, into his flying toad; his glowing motes are
	-- BoonDocMotion's.
	BoonDoc = {
		formScale = 2.6,
		glow = Color3.fromRGB(110, 230, 190),
		core = Color3.fromRGB(255, 236, 170),
		motion = Styles.DefaultMotion,
		aura = Styles.DefaultAura,
	},
}

function Styles.of(slugId: string): Style
	return styles[slugId] or PLAIN
end

return Styles
