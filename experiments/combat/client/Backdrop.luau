--!strict
-- The cavern passage behind the menus (owner's pick, 2026-11-03), at full resolution: Roblox shrinks any image to
-- 1024 px, which looked blurry on a big screen, so each picture is cut into tiles that overlap a little past their
-- share, so no seam can open between them. Pictures and tiles: tools/ui/backgrounds.
--
-- local back = Backdrop.new(parent, aspect, radius) -- covers parent like a cropped image; radius rounds its corners
-- back.set("backGameplay")
local Theme = require(script.Parent.PvpTheme)
local Fx = require(script.Parent.PvpFx)

local Backdrop = {}

-- SHARED with tools/ui/backgrounds/tile.py.
local COLS, ROWS = 3, 2
local WIDTH, HEIGHT, PAD = 3000, 1687, 12

export type Backdrop = {
	group: GuiObject, -- the clipping frame; a CanvasGroup when rounded, so it can fade as one
	set: (name: string) -> (),
	fit: (aspect: number) -> (),
	names: (name: string) -> { string },
}

function Backdrop.new(parent: Instance, aspect: number, radius: number?): Backdrop
	-- Rounded corners need a CanvasGroup: a plain frame clips square.
	local group: GuiObject = Theme.new(if radius then "CanvasGroup" else "Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 0,
		Parent = parent,
	})
	if radius then
		Theme.corner(group, radius)
	end
	local cover = Theme.new("Frame", {
		Name = "Cover",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = group,
	})
	local tiles: { ImageLabel } = {}
	for row = 0, ROWS - 1 do
		for col = 0, COLS - 1 do
			-- Whole pixels of the picture, as the tiles were cut.
			local left = math.max(0, math.round(col * WIDTH / COLS - PAD))
			local right = math.min(WIDTH, math.round((col + 1) * WIDTH / COLS + PAD))
			local top = math.max(0, math.round(row * HEIGHT / ROWS - PAD))
			local bottom = math.min(HEIGHT, math.round((row + 1) * HEIGHT / ROWS + PAD))
			table.insert(
				tiles,
				Theme.new("ImageLabel", {
					Name = `Tile{#tiles + 1}`,
					Position = UDim2.fromScale(left / WIDTH, top / HEIGHT),
					Size = UDim2.fromScale((right - left) / WIDTH, (bottom - top) / HEIGHT),
					BackgroundTransparency = 1,
					Parent = cover,
				})
			)
		end
	end
	local self: Backdrop
	self = {
		group = group,
		-- Crop to cover a frame of this width over height, as ScaleType Crop does.
		fit = function(frameAspect: number)
			local picture = WIDTH / HEIGHT
			cover.Size = if frameAspect > picture
				then UDim2.fromScale(1, frameAspect / picture)
				else UDim2.fromScale(picture / frameAspect, 1)
		end,
		names = function(name: string): { string }
			local list = {}
			for index = 1, #tiles do
				table.insert(list, `{name}{index}`)
			end
			return list
		end,
		set = function(name: string)
			for index, tile in tiles do
				tile.Image = Fx.asset(`{name}{index}`)
			end
		end,
	}
	self.fit(aspect)
	return self
end

return Backdrop
