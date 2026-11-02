--!strict
-- Shared action IDs and defaults for input and saved preferences.
type Row = { id: string, label: string, main: string?, second: string? }
return {
	{
		name = "Moving",
		rows = {
			{ id = "forward", label = "Forward", main = "W" },
			{ id = "left", label = "Left", main = "A" },
			{ id = "back", label = "Back", main = "S" },
			{ id = "right", label = "Right", main = "D" },
			{ id = "jump", label = "Jump", main = "Space" },
			{ id = "sprint", label = "Sprint", main = "C" },
			{ id = "slide", label = "Slide", main = "LeftShift" },
			{
				id = "shiftLock",
				label = "Shift lock",
				main = "LeftControl",
				second = "RightControl",
			},
		},
	},
	{
		name = "Shooting",
		rows = {
			{ id = "fire", label = "Fire", main = "MouseButton1" },
			{ id = "aim", label = "Aim", main = "MouseButton2" },
			{ id = "nextSlug", label = "Next slug" },
			{ id = "previousSlug", label = "Previous slug" },
			{ id = "slug1", label = "Slug 1", main = "One" },
			{ id = "slug2", label = "Slug 2", main = "Two" },
			{ id = "slug3", label = "Slug 3", main = "Three" },
			{ id = "slug4", label = "Slug 4", main = "Four" },
			{ id = "slug5", label = "Slug 5", main = "Five" },
		},
	},
	{
		name = "Other",
		rows = {
			{ id = "inventory", label = "Inventory", main = "E" },
			{ id = "settings", label = "Settings", main = "M" },
			{ id = "firstPerson", label = "First person" },
		},
	},
} :: { { name: string, rows: { Row } } }
