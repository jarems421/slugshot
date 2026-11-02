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
	-- Arms and grip below were set by the owner on this panel (2026-11-01).
	-- First-person arms at rest: by the sides, hands and gun in the lower view.
	idleDepth = -0.7,
	idleLift = -0.15,
	idlePitch = 36,
	idleOut = 0.17,
	idleGunDown = -5,
	idleLean = 0.4,
	idleDrop = 0.1,
	-- First-person arms while running.
	runDepth = -1,
	runOut = 0.15,
	armLength = 1,
	armWidth = 0.66,
	-- Blaster in the hand.
	gripDown = 22,
	gripUp = 0.15,
	gripOut = 0.3,
	gripRelease = 0.3,
	-- Third-person arm reaching across the body.
	aimTwist = 45,
	aimInward = 40,
	-- Shot and movement reactions.
	kickBase = 22,
	kickCharge = 10,
	spiralSpeed = 6,
	chargeShake = 1,
	spiralLight = 1,
	-- Aiming down sights: zoom, the gun in first-person view, and the third-person camera.
	adsZoom = 1.25,
	adsGunDown = 1.1,
	adsGunForward = 1.75,
	adsPaneBack = -0.15,
	adsPaneSize = 1,
	adsOpenTime = 0.42,
	adsCloseTime = 0.3,
	-- The three-stage wind-up: smooth steps that hold on the gun and the view.
	chargeTime = 0.665, -- three kicks, about 0.22 s apart
	chargeClunk = 1,
	chargeViewTighten = 2,
	chargeMoveShake = 2.7,
	chargeStepRoll = 1.5, -- view roll per step (deg)
	chargeStepShove = 0.15, -- eye shoved back per step (studs)
	chargeMoveStep = 1.6, -- extra step kick on the gun at full movement
	chargeStepPulse = 0.7, -- view hit per step, every state (deg)
	adsShake = 0.25, -- share of the charge vibration kept through the sight
	-- How much of the droop each shot level corrects. 1: lands on the crosshair. 0: flies
	-- straight from the gun and droops.
	shotArcOne = 0.3,
	shotArcTwo = 0.6,
	aimArc = 1,
	-- Floppy's face at rest: tired, sick and lazy.
	faceLid = 0.04,
	faceTilt = 11,
	faceBlinkTime = 0.55,
	faceBlinkClose = 0.13,
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
	entry("idleLift", "Arms up", "Idle arms (first person)", -1, 1, 0.01),
	entry("idlePitch", "Hands forward (deg)", "Idle arms (first person)", 0, 75, 1),
	entry("idleOut", "Shoulder width", "Idle arms (first person)", -0.4, 0.5, 0.01),
	entry("idleGunDown", "Gun tips down (deg)", "Idle arms (first person)", -20, 40, 1),
	entry("idleLean", "Lean forward", "Idle arms (first person)", 0, 1, 0.01),
	entry("idleDrop", "Lean down", "Idle arms (first person)", 0, 0.5, 0.01),
	entry("runDepth", "Shoulders forward (-)", "Running arms (first person)", -1.2, 0, 0.01),
	entry("runOut", "Shoulder width", "Running arms (first person)", -0.2, 0.6, 0.01),
	entry("armLength", "Arm length", "Arms (first person)", 0.7, 1.4, 0.01),
	entry("armWidth", "Arm thickness", "Arms (first person)", 0.4, 1, 0.01),
	entry("gripDown", "Muzzle down (deg)", "Grip (third person)", -10, 50, 1),
	entry("gripUp", "Gun up in hand", "Grip (third person)", -0.2, 0.5, 0.01),
	entry("gripOut", "Gun out of palm", "Grip (third person)", -0.2, 0.6, 0.01),
	entry("gripRelease", "Gun toward fingers", "Grip (first person)", -0.1, 0.4, 0.01),
	entry("aimTwist", "Body turn (deg)", "Aiming left (third person)", 0, 70, 1),
	entry("aimInward", "Arm across body (deg)", "Aiming left (third person)", 10, 70, 1),
	entry("kickBase", "Kick, tap (deg)", "Recoil", 0, 50, 1),
	entry("kickCharge", "Extra at full charge (deg)", "Recoil", 0, 30, 1),
	entry("spiralSpeed", "Top speed (turns/s)", "Charge spiral", 0.5, 10, 0.1),
	entry("chargeShake", "Gun vibration", "Charge spiral", 0, 3, 0.05),
	entry("spiralLight", "Light strength", "Charge spiral", 0, 1, 0.05),
	entry("adsZoom", "Zoom", "ADS", 1, 2, 0.05),
	entry("adsShake", "Charge vibration", "ADS", 0, 1, 0.01),
	entry("adsGunDown", "Gun below crosshair", "ADS", 0.2, 1.6, 0.01),
	entry("adsGunForward", "Gun distance", "ADS", 1, 3, 0.01),
	entry("adsPaneSize", "Pane size", "ADS", 0.5, 2.5, 0.05),
	entry("adsOpenTime", "Scope open time (s)", "ADS", 0.1, 1.5, 0.01),
	entry("adsCloseTime", "Scope close time (s)", "ADS", 0.1, 1.5, 0.01),
	entry("chargeTime", "Charge time (s)", "Charge spiral", 0.3, 1.5, 0.01),
	entry("chargeClunk", "Step kick on gun", "Charge spiral", 0, 3, 0.05),
	entry("chargeViewTighten", "View tighten (deg)", "Charge spiral", 0, 10, 0.25),
	entry("shotArcOne", "One charge correction", "Accuracy", 0, 1, 0.05),
	entry("shotArcTwo", "Two charge correction", "Accuracy", 0, 1, 0.05),
	entry("aimArc", "Full charge correction", "Accuracy", 0, 1, 0.05),
	entry("chargeMoveShake", "Vibration while moving", "Charge spiral", 1, 6, 0.05),
	entry("chargeMoveStep", "Step kick while moving", "Charge spiral", 1, 6, 0.05),
	entry("chargeStepRoll", "View roll per step (deg)", "Charge spiral", 0, 5, 0.05),
	entry("chargeStepShove", "View shove per step (studs)", "Charge spiral", 0, 0.5, 0.01),
	entry("chargeStepPulse", "View hit per step (deg)", "Charge spiral", 0, 5, 0.05),
	entry("faceLid", "Lids lower at rest", "Floppy face", 0, 0.12, 0.005),
	entry("faceTilt", "Outer lid droop (deg)", "Floppy face", 0, 20, 1),
	entry("faceBlinkTime", "Blink time (s)", "Floppy face", 0.15, 8, 0.05),
	entry("faceBlinkClose", "Blink depth", "Floppy face", 0.05, 0.2, 0.005),
	entry("spotPitch", "Front/back tilt (deg)", "Flip camera (Spot)", 0, 30, 1),
	entry("spotRoll", "Side tilt (deg)", "Flip camera (Spot)", 0, 40, 1),
	entry("landDip", "Landing dip", "Landing (first person)", 0, 0.6, 0.01),
	entry("recoveryTime", "Total time (s)", "Floppy burrow", 1, 3, 0.05),
	entry("skidLength", "Belly skid", "Floppy burrow", 0, 2, 0.05),
	entry("wiggle", "Wiggle", "Floppy burrow", 0, 2, 0.05),
} :: { Entry }

return Tuning
