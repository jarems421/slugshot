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
}

function Styles.of(slugId: string): Style
	return styles[slugId] or PLAIN
end

return Styles
