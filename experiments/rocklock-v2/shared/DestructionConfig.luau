--!strict
-- Rocklock v2 destruction rules (owner, 2026-10-30). Every attack damages every ordinary
-- destructible object: structures have structural health and attacks differ only in how much
-- they deal (archetype x tier x material). No standard attack deals zero (MinMultiplier).
-- All numbers are experimental and tunable; they are not final balance.
return table.freeze({
	-- What each category allows. Essential terrain only shows hit effects.
	Categories = table.freeze({
		Full = table.freeze({ Breakable = true, Label = "Fully destructible" }),
		Partial = table.freeze({ Breakable = true, Label = "Partially destructible" }),
		Landmark = table.freeze({ Breakable = true, Label = "Protected landmark (outer layer)" }),
		Essential = table.freeze({ Breakable = false, Label = "Essential (damage effects only)" }),
	}),
	-- Structural damage of the test tool's power tiers before multipliers. A future slug
	-- supplies its own amount and archetype through Destruction.attack.
	Tiers = table.freeze({ Weak = 25, Medium = 55, Heavy = 110 }),
	TierOrder = table.freeze({ "Weak", "Medium", "Heavy" }),
	-- Impact archetypes (gameplay roles, not species): smashing, piercing, digging,
	-- blasting, elemental (fire, water...) and constructive (raises temporary rock).
	ArchetypeOrder = table.freeze({
		"Blunt",
		"Penetrating",
		"Tunnelling",
		"Explosive",
		"Elemental",
	}),
	-- Material effectiveness per archetype; anything missing counts as 1.
	Materials = table.freeze({
		Stone = table.freeze({
			Blunt = 1.2,
			Penetrating = 0.9,
			Tunnelling = 0.8,
			Explosive = 1.0,
			Elemental = 0.6,
		}),
		Loose = table.freeze({
			Blunt = 1.5,
			Penetrating = 1.2,
			Tunnelling = 1.2,
			Explosive = 1.4,
			Elemental = 0.8,
		}),
		Slab = table.freeze({
			Blunt = 1.1,
			Penetrating = 1.6,
			Tunnelling = 1.0,
			Explosive = 1.0,
			Elemental = 0.6,
		}),
		Hardrock = table.freeze({
			Blunt = 1.0,
			Penetrating = 0.6,
			Tunnelling = 0.5,
			Explosive = 0.9,
			Elemental = 0.4,
		}),
	}),
	MinMultiplier = 0.25,
	-- Explosive splash: full damage at the hit point, Falloff fraction at Radius.
	Explosive = table.freeze({ Radius = 7, Falloff = 0.4 }),
	-- Terrain zones (loose earth over protected bedrock): crater radius per tier and
	-- archetype; a global cap keeps rapid-fire digging from flooding the server.
	Excavation = table.freeze({
		Radius = table.freeze({ Weak = 2.2, Medium = 3.4, Heavy = 4.8 }),
		Archetype = table.freeze({
			Blunt = 1,
			Penetrating = 0.75,
			Tunnelling = 1.6,
			Explosive = 1.3,
			Elemental = 0.8,
		}),
		MaxPerSecond = 12,
		MaxRadius = 7,
	}),
	-- Small chunks vanish (clients show their debris); large ones fall and settle as anchored
	-- collision that stays until the round resets.
	Rubble = table.freeze({
		SmallLifetime = 4,
		LargeLimit = 80,
		Gravity = 196.2,
		MaxFallTime = 1.2,
		ClearCheck = 0.25,
	}),
	-- Suspended formations: warning (cracks, shake, dust, ground ring), then the fall.
	Hazard = table.freeze({ DefaultWarning = 1.3, Shake = 0.22, StructuralDamage = 90 }),
	-- Requests from clients: range, rate and per-tier cooldowns (seconds).
	Requests = table.freeze({
		Range = 400,
		PerSecond = 8,
		Cooldown = table.freeze({ Weak = 0.2, Medium = 0.45, Heavy = 0.9 }),
	}),
	-- Constructive earth (a raised temporary slab wall, like a defensive rock rise).
	Constructive = table.freeze({ Lifetime = 12, Health = 80, MaxActive = 2, Distance = 9 }),
})
