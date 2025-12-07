---@meta

-- Constants: E_TraceLine
-- Auto-generated from: https://lmaobox.net/lua/Lua_Constants/
-- Last updated: 2025-12-07T21:34:00.146Z

---@type integer
CONTENTS_EMPTY = 0

---@type integer
CONTENTS_SOLID = 0x1

---@type integer
CONTENTS_WINDOW = 0x2

---@type integer
CONTENTS_AUX = 0x4

---@type integer
CONTENTS_GRATE = 0x8

---@type integer
CONTENTS_SLIME = 0x10

---@type integer
CONTENTS_WATER = 0x20

---@type integer
CONTENTS_BLOCKLOS = 0x40

---@type integer
CONTENTS_OPAQUE = 0x80

---@type integer
CONTENTS_TESTFOGVOLUME = 0x100

---@type integer
CONTENTS_UNUSED = 0x200

---@type integer
CONTENTS_BLOCKLIGHT = 0x400

---@type integer
CONTENTS_TEAM1 = 0x800

---@type integer
CONTENTS_TEAM2 = 0x1000

---@type integer
CONTENTS_IGNORE_NODRAW_OPAQUE = 0x2000

---@type integer
CONTENTS_MOVEABLE = 0x4000

---@type integer
CONTENTS_AREAPORTAL = 0x8000

---@type integer
CONTENTS_PLAYERCLIP = 0x10000

---@type integer
CONTENTS_MONSTERCLIP = 0x20000

---@type integer
CONTENTS_CURRENT_0 = 0x40000

---@type integer
CONTENTS_CURRENT_90 = 0x80000

---@type integer
CONTENTS_CURRENT_180 = 0x100000

---@type integer
CONTENTS_CURRENT_270 = 0x200000

---@type integer
CONTENTS_CURRENT_UP = 0x400000

---@type integer
CONTENTS_CURRENT_DOWN = 0x800000

---@type integer
CONTENTS_ORIGIN = 0x1000000

---@type integer
CONTENTS_MONSTER = 0x2000000

---@type integer
CONTENTS_DEBRIS = 0x4000000

---@type integer
CONTENTS_DETAIL = 0x8000000

---@type integer
CONTENTS_TRANSLUCENT = 0x10000000

---@type integer
CONTENTS_LADDER = 0x20000000

---@type integer
CONTENTS_HITBOX = 0x40000000

---@type integer
SURF_LIGHT = 0x0001

---@type integer
SURF_SKY2D = 0x0002

---@type integer
SURF_SKY = 0x0004

---@type integer
SURF_WARP = 0x0008

---@type integer
SURF_TRANS = 0x0010

---@type integer
SURF_NOPORTAL = 0x0020

---@type integer
SURF_TRIGGER = 0x0040

---@type integer
SURF_NODRAW = 0x0080

---@type integer
SURF_HINT = 0x0100

---@type integer
SURF_SKIP = 0x0200

---@type integer
SURF_NOLIGHT = 0x0400

---@type integer
SURF_BUMPLIGHT = 0x0800

---@type integer
SURF_NOSHADOWS = 0x1000

---@type integer
SURF_NODECALS = 0x2000

---@type any
SURF_NOPAINT = SURF_NODECALS

---@type integer
SURF_NOCHOP = 0x4000

---@type integer
SURF_HITBOX = 0x8000

---@type integer
MASK_ALL = 0xFFFFFFFF

---@type any
MASK_SOLID = CONTENTS_SOLID

---@type any
MASK_PLAYERSOLID = CONTENTS_SOLID

---@type any
MASK_NPCSOLID = CONTENTS_SOLID

---@type any
MASK_NPCFLUID = CONTENTS_SOLID

---@type any
MASK_WATER = CONTENTS_WATER

---@type any
MASK_OPAQUE = CONTENTS_SOLID

---@type any
MASK_OPAQUE_AND_NPCS = MASK_OPAQUE

---@type any
MASK_BLOCKLOS = CONTENTS_SOLID

---@type any
MASK_BLOCKLOS_AND_NPCS = MASK_BLOCKLOS

---@type any
MASK_VISIBLE = MASK_OPAQUE

---@type any
MASK_VISIBLE_AND_NPCS = MASK_OPAQUE_AND_NPCS

---@type any
MASK_SHOT = CONTENTS_SOLID

---@type any
MASK_SHOT_BRUSHONLY = CONTENTS_SOLID

---@type any
MASK_SHOT_HULL = CONTENTS_SOLID

---@type any
MASK_SHOT_PORTAL = CONTENTS_SOLID

---@type any
MASK_SOLID_BRUSHONLY = CONTENTS_SOLID

---@type any
MASK_PLAYERSOLID_BRUSHONLY = CONTENTS_SOLID

---@type any
MASK_NPCSOLID_BRUSHONLY = CONTENTS_SOLID

---@type any
MASK_NPCWORLDSTATIC = CONTENTS_SOLID

---@type any
MASK_NPCWORLDSTATIC_FLUID = CONTENTS_SOLID

---@type any
MASK_SPLITAREAPORTAL = CONTENTS_WATER

---@type any
MASK_CURRENT = CONTENTS_CURRENT_0

---@type any
MASK_DEADSOLID = CONTENTS_SOLID

---@type integer
MAX_COORD_INTEGER = 16384

---@type any
COORD_EXTENT = 2*MAX_COORD_INTEGER

---@type any
MAX_TRACE_LENGTH = 1.732050807569*COORD_EXTENT

