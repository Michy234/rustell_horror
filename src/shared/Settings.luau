--!strict
local Settings = {}

export type CookingStatus = "Empty" | "ReadyToCook" | "Cooking" | "Cooked"

Settings.STATUS = {
	EMPTY = "Empty" :: CookingStatus,
	READY_TO_COOK = "ReadyToCook" :: CookingStatus,
	COOKING = "Cooking" :: CookingStatus,
	COOKED = "Cooked" :: CookingStatus,
}

Settings.COOKING_TIME = 10 -- Seconds
Settings.INTERACTION_DISTANCE = 8
Settings.RAW_COLOR = Color3.fromRGB(255, 170, 170) -- Brighter Pink/Rosaceo

Settings.NPC_HOLD_TIME = 5 -- Seconds they hold the rustella before eating
Settings.NPC_WALK_RADIUS = 50 -- Large spread for NPCs
Settings.NPC_MIN_DISTANCE = 20 -- Stay far from brace
Settings.NPC_IDLE_TIME = 5 -- Seconds between moves (less hyperactive)

Settings.DEATH_SOUND_ID = "rbxassetid://5113630674"
Settings.DEATH_VOLUME = 0.8

Settings.NOTIFY_DURATION_BASE = 1.5
Settings.NOTIFY_CHAR_MULTIPLIER = 0.05 -- Seconds per character extra

Settings.BURNT_FEED_SOUND = "rbxassetid://6732739921"
Settings.BURNT_PENALTY = 20 -- Hunger points lost

Settings.BURNING_TIME = 15 -- Seconds after cooked until it burns
Settings.BURNT_COLOR = Color3.fromRGB(30, 30, 30) -- Black/Burnt

Settings.HUNGER_DECAY_RATE = 1 -- Percentage points per second (0 to 100)
Settings.FEED_RESTORE_AMOUNT = 35 -- Amount of hunger restored per feed

Settings.SOUNDS = {
	INSERT = "rbxassetid://147722227", -- Kick sound
	COOKED = "rbxassetid://138222365", -- Correct Ding sound as requested
	COAL = "rbxassetid://1548837501", -- Sizzling
	NOTIFY = "rbxassetid://6894523305", -- Pop/Notify
	WOAH = "rbxassetid://292117557", -- Surprise/Woah sound
	CHOMP = "rbxassetid://6748255118", -- Eating sound
}

Settings.BG_MUSIC = {
	ID = "rbxassetid://1842306658",
	VOLUME = 0.3
}

return Settings
