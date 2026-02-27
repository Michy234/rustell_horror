--!strict
local Settings = {}

export type CookingStatus = "Empty" | "ReadyToCook" | "Cooking" | "Cooked"

Settings.STATUS = {
	EMPTY = "Empty" :: CookingStatus,
	READY_TO_COOK = "ReadyToCook" :: CookingStatus,
	COOKING = "Cooking" :: CookingStatus,
	COOKED = "Cooked" :: CookingStatus,
}

-- List of authorized usernames for Admin Commands
Settings.ADMINS = {
	"Francesco0990o"
}

Settings.COOKING_TIME = 10 -- Seconds
Settings.INTERACTION_DISTANCE = 8
Settings.RAW_COLOR = Color3.fromRGB(255, 170, 170) -- Brighter Pink/Rosaceo

Settings.NPC_HOLD_TIME = 1 -- Seconds they hold the rustella before eating
Settings.NPC_WALK_RADIUS = 50 -- Large spread for NPCs
Settings.NPC_MIN_DISTANCE = 20 -- Stay far from brace
Settings.NPC_IDLE_TIME = 3 -- Seconds between moves (less hyperactive)

Settings.DEATH_SOUND_ID = "rbxassetid://1973317014"
Settings.DEATH_VOLUME = 0.8

-- New Settings
Settings.AUDIO_VOLUME = 0.5
Settings.MUSIC_VOLUME = 0.3
Settings.DIFFICULTY = 1.0 -- Scale for hunger decay

Settings.NOTIFY_DURATION_BASE = 1.5
Settings.NOTIFY_CHAR_MULTIPLIER = 0.05 -- Seconds per character extra

Settings.BURNT_FEED_SOUND = "rbxassetid://8819900535"
Settings.BURNT_PENALTY = 12 -- Hunger points lost

Settings.BURNING_TIME = 12 -- Seconds after cooked until it burns
Settings.BURNT_COLOR = Color3.fromRGB(30, 30, 30) -- Black/Burnt

Settings.HUNGER_DECAY_RATE = 1 -- Percentage points per second (BASE)
Settings.FEED_RESTORE_AMOUNT = 30 -- Amount of hunger restored per feed

Settings.SOUNDS = {
	INSERT = "rbxassetid://147722227", -- Kick sound
	COOKED = "rbxassetid://138222365", -- Correct Ding sound as requested
	COAL = "rbxassetid://1548837501", -- Sizzling
	NOTIFY = "rbxassetid://452267918", -- Pop/Notify
	WOAH = "rbxassetid://292117557", -- Surprise/Woah sound
	CHOMP = "rbxassetid://6748255118", -- Eating sound
}

Settings.BG_MUSIC = {
	ID = "rbxassetid://1842306658",
	VOLUME = 0.3
}

-- Win & Malus Settings
Settings.WIN_TIME = 300 -- 5 minutes
Settings.WIN_SOUND_ID = "rbxassetid://356817586"
Settings.DOG_SOUND_ID = "rbxassetid://9097860409"
Settings.DOG_WALK_SOUND_ID = "rbxassetid://7676505509"
Settings.DOG_CLICKS_MIN = 10
Settings.DOG_CLICKS_MAX = 30
Settings.DOG_SPAWN_INTERVAL = 45 -- Seconds (increased to follow user request)

Settings.ADMINS = {
	"Michy234", -- User's potential name
	"Moltarobba",
	"marco"
}

-- Rain Malus Settings
Settings.RAIN_INTERVAL = 100   -- Seconds between rain checks
Settings.RAIN_CHANCE = 0.4      -- 40% chance per interval
Settings.RAIN_DURATION = 10     -- Seconds rain lasts
Settings.RAIN_SOUND_ID = "rbxassetid://237985445"

-- Brace Coal Settings
Settings.COAL_DURATION = 40     -- Seconds coal burns before brace goes out

-- Salt Settings
Settings.SALT_SOUND_ID = "rbxassetid://6042053626"  -- shaker SFX (swap if needed)

-- NPC Obstacle Avoidance
Settings.NPC_OBSTACLE_RAYCAST_DISTANCE = 8    -- Studs di previsione ostacoli (raycast forward)
Settings.NPC_BRACE_AVOID_RADIUS = 15          -- Raggio minimo dalla brace durante il cammino
Settings.NPC_SEPARATION_RADIUS = 6            -- Raggio separazione tra NPC (steering)
Settings.NPC_STUCK_TIMEOUT = 3                -- Secondi prima di considerare l'NPC bloccato

-- Grandpa Settings
Settings.GRANDPA_SNORE_ID      = "rbxassetid://9089200372"   -- Man Snoring
Settings.GRANDPA_MUMBLE_ID     = "rbxassetid://18465332573"  -- Grumbling
Settings.GRANDPA_STANDUP_ID    = "rbxassetid://135527140272616"  -- AR'VATTEN A LA CAS AVAST A FATIJA          -- TODO: SFX nonno si alza (grido)
Settings.GRANDPA_WAKEUP_NPCS   = 2                           -- NPC rimanenti per svegliare il nonno
-- Facce del Nonno — usa le texture ID REALI (non gli ID wrapper del catalogo)
Settings.GRANDPA_FACE_SLEEPING = "rbxassetid://15637705"   -- occhi chiusi (wrapper era 15637848)
Settings.GRANDPA_FACE_AWAKE    = "rbxassetid://66329524"   -- occhi aperti (wrapper era 66330106)
Settings.GRANDPA_FACE_ANGRY    = "rbxassetid://10749405"   -- arrabbiato  (wrapper era 10860384)

return Settings
