--!strict
-- Feel values the owner judges by eye. Code reads these live every frame, and the
-- Studio-only panel (combat client, P) moves them while playing, so a value can be
-- settled in one sitting. Bake a chosen value here; nothing is saved between sessions.
local Tuning = {}

export type Entry = {
	key: string,
	label: string,
	group: string,
	min: number,
	max: number,
	step: number,
}

Tuning.values = {
	-- First-person arms at rest: by the sides, hands and gun in the lower view.
	idleDepth = -0.75,
	idleLift = -0.25,
	idlePitch = 55,
	idleOut = 0.25,
	idleGunDown = 30,
	idleLean = 0.3,
	idleDrop = 0.1,
	-- First-person arms while running (owner-settled 2026-11-01).
	runDepth = -0.62,
	runOut = 0.19,
	armLength = 1.0738 * 1.12 * 0.9,
	armWidth = 0.64,
	-- Blaster in the hand.
	gripDown = 9,
	gripUp = 0.18,
	gripOut = 0.06,
	gripRelease = 0.1,
	-- Third-person arm reaching across the body.
	aimTwist = 45,
	aimInward = 40,
	-- Shot and movement reactions.
	kickBase = 22,
	kickCharge = 10,
	spotPitch = 13,
	spotRoll = 19,
	landDip = 0.24,
	-- Floppy's recovery, impact to gone.
	recoveryTime = 1.5,
	skidLength = 1,
	wiggle = 1,
}

Tuning.defaults = table.clone(Tuning.values)

local function entry(
	key: string,
	label: string,
	group: string,
	min: number,
	max: number,
	step: number
): Entry
	return { key = key, label = label, group = group, min = min, max = max, step = step }
end

Tuning.Entries = {
	entry("idleDepth", "Shoulders forward (-)", "Idle arms (first person)", -1.2, 0.3, 0.01),
	entry("idleLift", "Arms up", "Idle arms (first person)", -0.4, 1, 0.01),
	entry("idlePitch", "Hands forward (deg)", "Idle arms (first person)", 0, 75, 1),
	entry("idleOut", "Shoulder width", "Idle arms (first person)", -0.4, 0.5, 0.01),
	entry("idleGunDown", "Gun tips down (deg)", "Idle arms (first person)", -20, 40, 1),
	entry("idleLean", "Lean forward", "Idle arms (first person)", 0, 1, 0.01),
	entry("idleDrop", "Lean down", "Idle arms (first person)", 0, 0.5, 0.01),
	entry("runDepth", "Shoulders forward (-)", "Running arms (first person)", -1.2, 0, 0.01),
	entry("runOut", "Shoulder width", "Running arms (first person)", -0.2, 0.6, 0.01),
	entry("armLength", "Arm length", "Arms (first person)", 0.7, 1.4, 0.01),
	entry("armWidth", "Arm thickness", "Arms (first person)", 0.4, 1, 0.01),
	entry("gripDown", "Muzzle down (deg)", "Grip (third person)", -10, 30, 1),
	entry("gripUp", "Gun up in hand", "Grip (third person)", -0.2, 0.5, 0.01),
	entry("gripOut", "Gun out of palm", "Grip (third person)", -0.2, 0.3, 0.01),
	entry("gripRelease", "Gun toward fingers", "Grip (first person)", -0.1, 0.4, 0.01),
	entry("aimTwist", "Body turn (deg)", "Aiming left (third person)", 0, 70, 1),
	entry("aimInward", "Arm across body (deg)", "Aiming left (third person)", 10, 70, 1),
	entry("kickBase", "Kick, tap (deg)", "Recoil", 0, 50, 1),
	entry("kickCharge", "Extra at full charge (deg)", "Recoil", 0, 30, 1),
	entry("spotPitch", "Front/back tilt (deg)", "Flip camera (Spot)", 0, 30, 1),
	entry("spotRoll", "Side tilt (deg)", "Flip camera (Spot)", 0, 40, 1),
	entry("landDip", "Landing dip", "Landing (first person)", 0, 0.6, 0.01),
	entry("recoveryTime", "Total time (s)", "Floppy burrow", 1, 3, 0.05),
	entry("skidLength", "Belly skid", "Floppy burrow", 0, 2, 0.05),
	entry("wiggle", "Wiggle", "Floppy burrow", 0, 2, 0.05),
} :: { Entry }

return Tuning
