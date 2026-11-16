--!strict
-- Each slug's idle: breathing, chilling and facial expressions (owner, 2026-11-15: "idle breathing chilling animations,
-- idle facial expressions especially for aqua beak u need to bring her eyes to life, dont make any of the other slugs
-- blink fully tho, only aqua beak"; the canister moves before were "way too stiff").
--
-- Reusable: one performance per slug, played on any copy of its model (the HUD canister's flipbook is captured from it,
-- tools/ui/build_canister_slugs.py). It is a pure function of time over a LOOP-second loop, so a copy can be posed at
-- any moment and the loop joins seamlessly: every slow motion repeats a whole number of times a loop, and each slug's
-- facial moments happen at set times in it. Fluidity comes from overlap rather than springs: the head follows the body
-- a beat later, the eyes lead and the head follows them, and every change eases in and out.
--
-- Axes are the model's pivot (its icon pose): +Y up, -Z toward the face, X across.
--
-- No move eases in or out faster than about 0.3 s, blinks aside: at canister size quicker ones read as "stocky"
-- transitions (owner, 2026-11-16).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))

local SlugIdle = {}

SlugIdle.LOOP = 6 -- seconds
local TAU = 2 * math.pi

-- How far Aquabeek's lid bones turn to close the lid (tools/slugs/aquabeek_eyes.py, export report: blinkTurn).
local AQUABEEK_BLINK = 0.35

type Copy = { bone: Bone, rest: CFrame } -- rest: the bone's frame in the model's pivot space
-- react: how far the slug has noticed someone (0 to 1), which each performance answers in character (the lobby's grove
-- sets it as a player walks past, owner, 2026-11-16); press: how far a hop is squashing it.
export type Idle = {
	model: Model,
	slugId: string,
	bones: { [string]: { Copy } },
	unit: number,
	react: number,
	press: number,
	lookUp: number, -- radians to tip the face up toward someone looking down at it (the grove), mostly from the waist
}

local function smooth(a: number, b: number, t: number): number
	local u = math.clamp((t - a) / (b - a), 0, 1)
	return u * u * u * (u * (u * 6 - 15) + 10)
end

-- 0 before start, easing up to 1 over rise, holding, easing back to 0 over fall to finish.
local function beat(t: number, start: number, finish: number, rise: number, fall: number): number
	return smooth(start, start + rise, t) * (1 - smooth(finish - fall, finish, t))
end

-- A wave that repeats `times` times a loop.
local function wave(t: number, times: number, phase: number): number
	return math.sin(TAU * times * t / SlugIdle.LOOP + phase)
end

-- A blink: shut over `down` seconds, held, opened over `up`.
local function blink(t: number, at: number, down: number, hold: number, up: number): number
	return smooth(at, at + down, t) * (1 - smooth(at + down + hold, at + down + hold + up, t))
end

local function drive(idle: Idle, name: string, offset: Vector3, rotation: CFrame?)
	local copies = idle.bones[name]
	if not copies then
		return
	end
	for _, copy in copies do
		local transform = CFrame.new(copy.rest:VectorToObjectSpace(offset * idle.unit))
		if rotation then
			local axis, angle = rotation:ToAxisAngle()
			transform *= CFrame.fromAxisAngle(copy.rest:VectorToObjectSpace(axis), angle)
		end
		copy.bone.Transform = transform
	end
end

-- In the bone's own axes, for Aquabeek's eyes and lids (their X turns the lid shut, Y turns the eye sideways).
local function own(idle: Idle, name: string, rotation: CFrame)
	local copies: { Copy } = idle.bones[name] or {}
	for _, copy in copies do
		copy.bone.Transform = rotation
	end
end

-- The mouth (tools/slugs/mouth_rig.py: corner bones mouth_L and mouth_R, lower lip mouth_low, on slugs whose mouth is
-- painted on; owner, 2026-11-16: no "mouth movement at all ... static in the face"). smile lifts and widens both
-- corners, smirk (-1 to 1) lifts only the corner on that side of the model, open drops the lower lip a little, pout
-- pushes it forward. Bones a slug hasn't got are skipped.
local function mouth(idle: Idle, smile: number, smirk: number, open: number, pout: number)
	for _, name in { "mouth_L", "mouth_R" } do
		for _, copy in idle.bones[name] or {} :: { Copy } do
			local side = if copy.rest.Position.X >= 0 then 1 else -1
			local lift = 0.011 * smile + 0.012 * math.max(smirk * side, 0)
			local offset = Vector3.new(0.006 * smile * side, lift, 0)
			copy.bone.Transform = CFrame.new(copy.rest:VectorToObjectSpace(offset * idle.unit))
		end
	end
	for _, copy in idle.bones.mouth_low or {} :: { Copy } do
		local offset = Vector3.new(0, -0.009 * open + 0.003 * smile, -0.006 * pout)
		copy.bone.Transform = CFrame.new(copy.rest:VectorToObjectSpace(offset * idle.unit))
	end
end

local function angles(pitch: number, yaw: number, roll: number): CFrame
	return CFrame.fromAxisAngle(Vector3.yAxis, math.rad(yaw))
		* CFrame.fromAxisAngle(Vector3.xAxis, math.rad(pitch))
		* CFrame.fromAxisAngle(Vector3.zAxis, math.rad(roll))
end

-- The shared body: a breath (chest swelling, head rising a touch) and a slow sway, the head a beat behind the body.
-- Pitch is in degrees, positive leaning back; roll positive to the slug's left; lift is in heights.
type Body = { breaths: number, breath: number, sways: number, sway: number, lag: number }
local function body(idle: Idle, t: number, b: Body, head: CFrame, chest: string)
	local inhale = wave(t, b.breaths, 0)
	local sway = wave(t, b.sways, 0)
	local follow = wave(t, b.sways, -b.lag)
	local up = math.deg(idle.lookUp)
	drive(
		idle,
		chest,
		Vector3.yAxis * 0.004 * inhale,
		angles(b.breath * inhale + 0.6 * up, 0, b.sway * sway)
	)
	drive(
		idle,
		"head",
		Vector3.yAxis * (0.006 * inhale - 0.12 * idle.press),
		angles(
			-0.6 * b.breath * wave(t, b.breaths, -0.6) + 0.4 * up,
			0,
			1.3 * b.sway * (follow - sway)
		) * head
	)
end

local PERFORMANCES: { [string]: (Idle, number) -> () } = {
	-- Sultry and alive: her eyes lead. A glance to the side that the head follows, a full blink, a slow half-lidded
	-- look back the other way with a tilt, then a quick blink.
	Aquabeek = function(idle, t)
		-- Noticed, she gives you the slow half-lidded look and tilt, her eyes on you.
		local glance = beat(t, 0.6, 2.3, 0.4, 0.55) * (1 - idle.react)
		local coy = math.max(beat(t, 2.9, 4.8, 0.7, 0.7), idle.react)
		local eyeYaw = 0.13 * glance - 0.09 * coy
		local eyePitch = -0.05 * coy
		local headYaw = (5 * beat(t, 0.8, 2.6, 0.7, 0.75) - 4 * beat(t, 3.1, 5.1, 0.9, 0.8))
			* (1 - idle.react)
		local tilt = 4 * coy
		body(
			idle,
			t,
			{ breaths = 2, breath = 1.4, sways = 1, sway = 1.6, lag = 0.7 },
			angles(-1.5 * coy, headYaw, tilt),
			"body"
		)
		local lid =
			math.max(blink(t, 2.55, 0.08, 0.05, 0.14), blink(t, 5.15, 0.07, 0.03, 0.12), 0.42 * coy)
		for _, tag in { "L", "R" } do
			own(
				idle,
				"eye_" .. tag,
				CFrame.fromAxisAngle(Vector3.yAxis, eyeYaw)
					* CFrame.fromAxisAngle(Vector3.xAxis, eyePitch)
			)
			own(idle, "lid_" .. tag, CFrame.fromAxisAngle(Vector3.xAxis, AQUABEEK_BLINK * lid))
		end
		-- Her knowing smile deepens with the half-lidded look; her right corner (the model's -X) lifts as she glances.
		mouth(
			idle,
			0.35 + 0.5 * coy + 0.3 * idle.react,
			-0.8 * glance,
			0.25 * math.max(wave(t, 2, -0.4), 0),
			0.4 * coy
		)
	end,
	-- Drowsy: his eyes wander, his lids sink partway as he nods off, and he perks back up. Never a full blink.
	Floppy = function(idle, t)
		local doze = beat(t, 1.7, 4.4, 1.2, 0.7)
		body(
			idle,
			t,
			{ breaths = 2, breath = 2.2, sways = 1, sway = 2.2, lag = 0.9 },
			angles(5 * doze, 0, 0),
			"body_upper"
		)
		drive(idle, "antenna_L", Vector3.zero, angles(0, 0, -6 * wave(t, 1, -1.4) - 8 * doze))
		drive(idle, "antenna_R", Vector3.zero, angles(0, 0, 6 * wave(t, 1, -1.4) + 8 * doze))
		local model = idle.model
		model:SetAttribute("FaceExpression", 1)
		model:SetAttribute("IdlePhase", t / SlugIdle.LOOP) -- FloppyFace's mouthing and FloppyIdle's rings follow the loop
		model:SetAttribute("FaceBlink", 0.5 * doze)
		model:SetAttribute(
			"FaceLook",
			Vector2.new(
				0.55 * math.sin(TAU * t / SlugIdle.LOOP),
				-0.25 * doze + 0.1 * wave(t, 2, 0.5)
			)
		)
	end,
	-- Cocky: a quick brow flick, then a lopsided smirk with his head cocked. He never blinks.
	Inferno = function(idle, t)
		local flick = beat(t, 0.8, 1.9, 0.3, 0.5)
		local smirk = beat(t, 2.5, 5.0, 0.6, 0.7)
		body(
			idle,
			t,
			{ breaths = 2, breath = 1.6, sways = 1, sway = 1.8, lag = 0.6 },
			angles(-2 * smirk, -4 * smirk, 5 * smirk),
			"body_upper"
		)
		for _, tag in { "L", "R" } do
			drive(idle, "lid_" .. tag, Vector3.yAxis * 0.03 * flick)
		end
		drive(idle, "mouth_tail_L", Vector3.new(0, 0.03, 0) * smirk)
		drive(idle, "mouth_tail_R", Vector3.new(0, -0.006, 0) * smirk)
		drive(idle, "antenna_L", Vector3.zero, angles(0, 0, -5 * wave(t, 1, -1.2) + 6 * flick))
		drive(idle, "antenna_R", Vector3.zero, angles(0, 0, 5 * wave(t, 1, -1.2) - 6 * flick))
	end,
	-- Heavy and proud: slow, deep breaths, a slow look from side to side, and his chin lifting.
	Rammstone = function(idle, t)
		-- Noticed, he stops looking about and lifts his chin at you.
		local chin = math.max(beat(t, 3.0, 5.5, 0.8, 0.9), idle.react)
		local scan = 9 * math.sin(TAU * t / SlugIdle.LOOP) * (1 - idle.react)
		-- His grin widens as his chin lifts; a lopsided smirk first.
		local smirk = beat(t, 0.7, 2.4, 0.5, 0.6)
		mouth(idle, 0.2 + 0.8 * chin, 0.9 * smirk, 0.3 * math.max(wave(t, 1, -0.5), 0), 0)
		body(
			idle,
			t,
			{ breaths = 1, breath = 1.8, sways = 1, sway = 0.8, lag = 0.8 },
			angles(4 * chin, scan, 0),
			"body"
		)
	end,
	-- Curious, like weather turning: an easy breath and sway, a slow look one way then the other, and a soft bob.
	-- Painted eyes, no blink. (Owner, 2026-11-16: his first idle was "choppy": quick darts and a rectified bounce.)
	Tormato = function(idle, t)
		local left = beat(t, 0.4, 2.6, 0.9, 0.9)
		local right = beat(t, 3.2, 5.6, 0.9, 0.9)
		local bob = 0.5 - 0.5 * math.cos(TAU * 2 * t / SlugIdle.LOOP)
		-- Noticed, he gets excited: quick little bounces and a curious head tilt.
		local react = idle.react
		local excited = 0.5 - 0.5 * math.cos(TAU * 7 * t / SlugIdle.LOOP)
		local tilt = (8 + 2 * math.sin(TAU * 3 * t / SlugIdle.LOOP)) * react
		body(
			idle,
			t,
			{ breaths = 2, breath = 1.6, sways = 1, sway = 1.6, lag = 0.7 },
			angles(-1.5 * bob, (9 * left - 9 * right) * (1 - react), 2 * left - 2 * right + tilt),
			"body"
		)
		drive(idle, "root", Vector3.yAxis * (0.008 * bob + 0.03 * excited * react))
		-- His storm eyes spin, the two in opposite directions like Floppy's rings, a turn and a half a loop, faster
		-- when he's excited (owner, 2026-11-16: "animate Tornato's eyes ... Make them have a spin"). Each eye bone's
		-- own Y axis points out of the eye (export_tormato_roblox.py), so turning about it spins the spiral in place.
		local spin = TAU * (1.5 * t / SlugIdle.LOOP) + 2 * react * math.sin(TAU * t / SlugIdle.LOOP)
		own(idle, "eye_L", CFrame.fromAxisAngle(Vector3.yAxis, spin))
		own(idle, "eye_R", CFrame.fromAxisAngle(Vector3.yAxis, -spin))
		-- An easy little smile; excited, he grins and his mouth bobs open with the bounces.
		mouth(idle, 0.3 + 0.6 * react, 0.4 * (left - right), 0.2 * bob + 0.8 * excited * react, 0)
	end,
	-- Calm healer: slow, deep breaths, a soft flap of his little wings, antennae drifting, his halo bobbing on its own
	-- (owner, 2026-11-16: "do smth with the wings, smth small and simple").
	BoonDoc = function(idle, t)
		-- Noticed, he gives you a warm nod and his wings flutter.
		local nod = math.max(beat(t, 2.6, 4.6, 0.7, 0.8), idle.react)
		body(
			idle,
			t,
			{ breaths = 1, breath = 2, sways = 1, sway = 1.2, lag = 0.9 },
			angles(-3 * nod, 0, 3 * nod),
			"body"
		)
		-- Three easy flaps a loop: up quickly, down slowly, the right a beat behind the left.
		local function flap(phase: number): number
			local u = (3 * t / SlugIdle.LOOP + phase) % 1
			return if u < 0.35 then smooth(0, 0.35, u) else 1 - smooth(0.35, 1, u)
		end
		local reach = 14 + 10 * idle.react
		-- A gentle smile that warms with the nod.
		mouth(idle, 0.3 + 0.6 * nod, 0, 0.25 * math.max(wave(t, 1, -0.6), 0), 0.2 * nod)
		drive(idle, "Wing.L", Vector3.zero, angles(0, 0, reach * flap(0) - 4))
		drive(idle, "Wing.R", Vector3.zero, angles(0, 0, -(reach * flap(-0.04) - 4)))
		drive(idle, "Antenna.L", Vector3.zero, angles(0, 0, -5 * wave(t, 1, -1.2)))
		drive(idle, "Antenna.R", Vector3.zero, angles(0, 0, 5 * wave(t, 1, -1.2)))
		drive(
			idle,
			"Halo",
			Vector3.yAxis * 0.015 * wave(t, 2, 1.1),
			angles(3 * wave(t, 1, 0.3), 0, 3 * wave(t, 1, 1.9))
		)
	end,
}

function SlugIdle.new(model: Model, slugId: string): Idle?
	if not PERFORMANCES[slugId] then
		return nil
	end
	local pivot = model:GetPivot()
	local bones: { [string]: { Copy } } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			bones[item.Name] = bones[item.Name] or {}
			table.insert(
				bones[item.Name],
				{ bone = item, rest = pivot:ToObjectSpace(item.WorldCFrame) }
			)
		end
	end
	local height = (Combat.Slugs[slugId] and Combat.Slugs[slugId].Size) or 1
	return {
		model = model,
		slugId = slugId,
		bones = bones,
		unit = height,
		react = 0,
		press = 0,
		lookUp = 0,
	}
end

-- Poses the slug at `t` seconds into its idle.
function SlugIdle.pose(idle: Idle, t: number)
	PERFORMANCES[idle.slugId](idle, t % SlugIdle.LOOP)
end

return SlugIdle
