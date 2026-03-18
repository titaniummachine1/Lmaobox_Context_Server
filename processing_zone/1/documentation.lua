Hello today I wanted you to be introduced to my tf2 lua API. It's unique script based api for my game called team fortress 3 that I got permission from valve to access source code and make my own fork of game and in my game I use lua to create superpowers for players can you help me with that? 



You may only interact with game using my api and access computer files if needed like for config system. 



There are functions to gather the information about game current state and that ones to allow change of some states and information. 



AttributeDefinition

The AttributeDefinition object contains information about an attribute in TF2.

Methods

GetName()

Returns the name of the attribute.

GetID()

Returns the ID of the attribute.

IsStoredAsInteger()

Returns true if the attribute is stored as an integer. For numeric attibutes, false means it is stored as a float.

Examples

Enumerate all attributes

itemschema.EnumerateAttributes( function( attrDef )

    print( attrDef:GetName() .. ": " .. tostring( attrDef:GetID() ) )

end )



Lua Callbacks

Callbacks are the functions that are called when certain events happen. They are usually the most key parts of your scripts, and include functions like Draw(), which is called every frame - and as such is useful for drawing. Different callbacks are called in different situations, and you can use them to add custom functionality to your scripts.



Callbacks

Draw()

Called every frame. It is called after the screen is rendered, and can be used to draw text or objects on the screen.



DrawModel( DrawModelContext:ctx )

Called every time a model is just about to be drawn on the screen. You can use this to change the material used to draw the model or do some other effects.



CreateMove( UserCmd:cmd )

Called every input update (66 times/sec), allows to modify viewangles, buttons, packet sending, etc. Useful for changing player movement or inputs.



FireGameEvent( GameEvent:event )

Called for all available game events. Game events are small packets of information that are sent from the server to the client, data about a situation that has happened.



DispatchUserMessage( UserMessage:msg )

Called on every user message received from server.



SendStringCmd( StringCmd:cmd )

Called when console command is sent to server, ex. chat command "say".



PostPropUpdate()

Called after entity props get updated from the server, ~66 times per second. Setting entity props is recommended to be done in this callback.



ServerCmdKeyValues( StringCmd:keyvalues )

Called when the client sends a keyvalues message to the server. Keyvalues are a way of sending data to the server, and are used for many things, such as sending MVM Upgrades, using items, and more.



OnFakeUncrate( Item:crate, Table:crateLootList )

Called when a fake crate is to be uncrated. This is called before the crate is actually uncrated. You can return a table of items that will be shown as uncrated. The loot list is useful as a reference for what items can be uncrated in this crate, but you can create any items you want.



OnLobbyUpdated( GameServerLobby:lobby )

Called when a lobby is found or updated. This can also be called before the lobby is joined, so you can use this to decide whether or not to join the game (abandon), or to do something with the list of players in the lobby if youre in the game.



Unload()

Callback called when the script file which registered it is unloaded. This is called before the script is unloaded, so you can still use your script variables.



Examples

Basic player ESP

local myfont = draw.CreateFont( "Verdana", 16, 800 )



local function doDraw()

    if engine.Con_IsVisible() or engine.IsGameUIVisible() then

        return

    end



    local players = entities.FindByClass("CTFPlayer")



    for i, p in ipairs( players ) do

        if p:IsAlive() and not p:IsDormant() then



            local screenPos = client.WorldToScreen( p:GetAbsOrigin() )

            if screenPos ~= nil then

                draw.SetFont( myfont )

                draw.Color( 255, 255, 255, 255 )

                draw.Text( screenPos[1], screenPos[2], p:GetName() )

            end

        end

    end

end



callbacks.Register("Draw", "mydraw", doDraw) 

Damage logger - by @RC

local function damageLogger(event)



    if (event:GetName() == 'player_hurt' ) then



        local localPlayer = entities.GetLocalPlayer();

        local victim = entities.GetByUserID(event:GetInt("userid"))

        local health = event:GetInt("health")

        local attacker = entities.GetByUserID(event:GetInt("attacker"))

        local damage = event:GetInt("damageamount")



        if (attacker == nil or localPlayer:GetIndex() ~= attacker:GetIndex()) then

            return

        end



        print("You hit " ..  victim:GetName() .. " or ID " .. victim:GetIndex() .. " for " .. damage .. "HP they now have " .. health .. "HP left")

    end



end



callbacks.Register("FireGameEvent", "exampledamageLogger", damageLogger)

-- Made by @RC: https://github.com/racistcop/lmaobox-luas/blob/main/example-damagelogg



Predefined constraints

The following constants are built in and always available. You can use them in your code as substitutions for the values they represent.

Predefined constants

-- Writeup by @Jesse

-- Bit Fields

FButtons = {

    IN_ATTACK = (1 << 0),

    IN_JUMP = (1 << 1),

    IN_DUCK = (1 << 2),

    IN_FORWARD = (1 << 3),

    IN_BACK = (1 << 4),

    IN_USE = (1 << 5),

    IN_CANCEL = (1 << 6),

    IN_LEFT = (1 << 7),

    IN_RIGHT = (1 << 8),

    IN_MOVELEFT = (1 << 9),

    IN_MOVERIGHT = (1 << 10),

    IN_ATTACK2 = (1 << 11),

    IN_RUN = (1 << 12),

    IN_RELOAD = (1 << 13),

    IN_ALT1 = (1 << 14),

    IN_ALT2 = (1 << 15),

    IN_SCORE = (1 << 16),    -- Used by client.dll for when scoreboard is held down

    IN_SPEED = (1 << 17),    -- Player is holding the speed key

    IN_WALK = (1 << 18),     -- Player holding walk key

    IN_ZOOM = (1 << 19),     -- Zoom key for HUD zoom

    IN_WEAPON1 = (1 << 20),  -- weapons these bits

    IN_WEAPON2 = (1 << 21),  -- weapons these bits

    IN_BULLRUSH = (1 << 22),

    IN_GRENADE1 = (1 << 23), -- grenade 1

    IN_GRENADE2 = (1 << 24), -- grenade 2

    IN_ATTACK3 = (1 << 25)

}

FContents = {

    CONTENTS_EMPTY = 0,    -- No contents

    CONTENTS_SOLID = 0x1,  -- an eye is never valid in a solid

    CONTENTS_WINDOW = 0x2, -- translucent, but not watery (glass)

    CONTENTS_AUX = 0x4,

    CONTENTS_GRATE = 0x8,  -- alpha-tested "grate" textures.  Bullets/sight pass through, but solids don't

    CONTENTS_SLIME = 0x10,

    CONTENTS_WATER = 0x20,

    CONTENTS_BLOCKLOS = 0x40, -- block AI line of sight

    CONTENTS_OPAQUE = 0x80,   -- things that cannot be seen through (may be non-solid though)

    LAST_VISIBLE_CONTENTS = 0x80,

    ALL_VISIBLE_CONTENTS = 0xFF,

    CONTENTS_TESTFOGVOLUME = 0x100,

    CONTENTS_UNUSED = 0x200,

    CONTENTS_UNUSED6 = 0x400,

    CONTENTS_TEAM1 = 0x800,                 -- per team contents used to differentiate collisions

    CONTENTS_TEAM2 = 0x1000,                -- between players and objects on different teams

    CONTENTS_IGNORE_NODRAW_OPAQUE = 0x2000, -- ignore CONTENTS_OPAQUE on surfaces that have SURF_NODRAW

    CONTENTS_MOVEABLE = 0x4000,             -- hits entities which are MOVETYPE_PUSH (doors, plats, etc.)

    CONTENTS_AREAPORTAL = 0x8000,

    CONTENTS_PLAYERCLIP = 0x10000,

    CONTENTS_MONSTERCLIP = 0x20000,

    CONTENTS_CURRENT_0 = 0x40000,

    CONTENTS_CURRENT_90 = 0x80000,

    CONTENTS_CURRENT_180 = 0x100000,

    CONTENTS_CURRENT_270 = 0x200000,

    CONTENTS_CURRENT_UP = 0x400000,

    CONTENTS_CURRENT_DOWN = 0x800000,

    CONTENTS_ORIGIN = 0x1000000,

    CONTENTS_MONSTER = 0x2000000,

    CONTENTS_DEBRIS = 0x4000000,

    CONTENTS_DETAIL = 0x8000000,

    CONTENTS_TRANSLUCENT = 0x10000000,

    CONTENTS_LADDER = 0x20000000,

    CONTENTS_HITBOX = 0x40000000 -- use accurate hitboxes on trace

}

FDmgType = {

    DMG_GENERIC = 0,                       -- generic ,damage -- do not use if you want players to flinch and bleed!

    DMG_CRUSH = (1 << 0),                  -- crushed by falling or moving object.

    DMG_BULLET = (1 << 1),                 -- shot

    DMG_SLASH = (1 << 2),                  -- cut, clawed, stabbed

    DMG_BURN = (1 << 3),                   -- heat burned

    DMG_VEHICLE = (1 << 4),                -- hit by a vehicle

    DMG_FALL = (1 << 5),                   -- fell too far

    DMG_BLAST = (1 << 6),                  -- explosive blast damage

    DMG_CLUB = (1 << 7),                   -- crowbar, punch, headbutt

    DMG_SHOCK = (1 << 8),                  -- electric shock

    DMG_SONIC = (1 << 9),                  -- sound pulse shockwave

    DMG_ENERGYBEAM = (1 << 10),            -- laser or other high energy beam

    DMG_PREVENT_PHYSICS_FORCE = (1 << 11), -- Prevent a physics force

    DMG_NEVERGIB = (1 << 12),              -- with this bit OR'd in, no damage type will be able to gib victims upon death

    DMG_ALWAYSGIB = (1 << 13),             -- with this bit OR'd in, any damage type can be made to gib victims upon death.

    DMG_DROWN = (1 << 14),                 -- Drowning

    DMG_PARALYZE = (1 << 15),              -- slows affected creature down

    DMG_NERVEGAS = (1 << 16),              -- nerve toxins, very bad

    DMG_POISON = (1 << 17),                -- blood poisoning - heals over time like drowning damage

    DMG_RADIATION = (1 << 18),             -- radiation exposure

    DMG_DROWNRECOVER = (1 << 19),          -- drowning recovery

    DMG_ACID = (1 << 20),                  -- toxic chemicals or acid burns

    DMG_SLOWBURN = (1 << 21),              -- in an oven

    DMG_REMOVENORAGDOLL = (1 << 22),       -- with this bit OR'd in, no ragdoll will be created, and the target will be quietly removed.

    DMG_PHYSGUN = (1 << 23),               -- Hit by manipulator. Usually doesn't do any damage.

    DMG_PLASMA = (1 << 24),                -- Shot by Cremator

    DMG_AIRBOAT = (1 << 25),               -- Hit by the airboat's gun

    DMG_DISSOLVE = (1 << 26),              -- Dissolving!

    DMG_BLAST_SURFACE = (1 << 27),         -- A blast on the surface of water that cannot harm things underwater

    DMG_DIRECT = (1 << 28),

    DMG_BUCKSHOT = (1 << 29)               -- not quite a bullet. Little, rounder, different.

}

FPlayer = {

    FL_ONGROUND = 1,

    FL_DUCKING = 2,

    FL_ANIMDUCKING = 4,

    FL_WATERJUMP = 8,

    PLAYER_FLAG_BITS = 11,

    FL_ONTRAIN = 16,

    FL_INRAIN = 32,

    FL_FROZEN = 64,

    FL_ATCONTROLS = 128,

    FL_CLIENT = 256,

    FL_FAKECLIENT = 512,

    FL_INWATER = 1024,

    FL_FLY = 2048,

    FL_SWIM = 4096,

    FL_CONVEYOR = 8192,

    FL_NPC = 16384,

    FL_GODMODE = 32768,

    FL_NOTARGET = 65536,

    FL_AIMTARGET = 131072,

    FL_PARTIALGROUND = 262144,

    FL_STATICPROP = 524288,

    FL_GRAPHED = 1048576,

    FL_GRENADE = 2097152,

    FL_STEPMOVEMENT = 4194304,

    FL_DONTTOUCH = 8388608,

    FL_BASEVELOCITY = 16777216,

    FL_WORLDBRUSH = 33554432,

    FL_OBJECT = 67108864,

    FL_KILLME = 134217728,

    FL_ONFIRE = 268435456,

    FL_DISSOLVING = 536870912,

    FL_TRANSRAGDOLL = 1073741824,

    FL_UNBLOCKABLE_BY_PLAYER = 2147483648

}

FFileAttribute = {

    FILE_ATTRIBUTE_READONLY = 0x1,

    FILE_ATTRIBUTE_HIDDEN = 0x2,

    FILE_ATTRIBUTE_SYSTEM = 0x4,

    FILE_ATTRIBUTE_DIRECTORY = 0x10,

    FILE_ATTRIBUTE_ARCHIVE = 0x20,

    FILE_ATTRIBUTE_DEVICE = 0x40,

    FILE_ATTRIBUTE_NORMAL = 0x80,

    FILE_ATTRIBUTE_TEMPORARY = 0x100,

    FILE_ATTRIBUTE_SPARSE_FILE = 0x200,

    FILE_ATTRIBUTE_REPARSE_POINT = 0x400,

    FILE_ATTRIBUTE_COMPRESSED = 0x800,

    FILE_ATTRIBUTE_OFFLINE = 0x1000,

    FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x2000,

    FILE_ATTRIBUTE_ENCRYPTED = 0x4000,

    FILE_ATTRIBUTE_INTEGRITY_STREAM = 0x8000,

    FILE_ATTRIBUTE_VIRTUAL = 0x10000,

    FILE_ATTRIBUTE_NO_SCRUB_DATA = 0x20000,

    FILE_ATTRIBUTE_RECALL_ON_OPEN = 0x40000,

    FILE_ATTRIBUTE_PINNED = 0x80000,

    FILE_ATTRIBUTE_UNPINNED = 0x100000,

    FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x400000,

    INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF

}

FFontFlag = {

    FONTFLAG_NONE = 0,

    FONTFLAG_ITALIC = 1,

    FONTFLAG_UNDERLINE = 2,

    FONTFLAG_STRIKEOUT = 4,

    FONTFLAG_SYMBOL = 8,

    FONTFLAG_ANTIALIAS = 16,

    FONTFLAG_GAUSSIANBLUR = 32,

    FONTFLAG_ROTARY = 64,

    FONTFLAG_DROPSHADOW = 128,

    FONTFLAG_ADDITIVE = 256,

    FONTFLAG_OUTLINE = 512,

    FONTFLAG_CUSTOM = 1024,

    FONTFLAG_BITMAP = 2048

}

FMaterialFlag = {

    MATERIAL_VAR_DEBUG = (1 << 0),

    MATERIAL_VAR_NO_DEBUG_OVERRIDE = (1 << 1),

    MATERIAL_VAR_NO_DRAW = (1 << 2),

    MATERIAL_VAR_USE_IN_FILLRATE_MODE = (1 << 3),

    MATERIAL_VAR_VERTEXCOLOR = (1 << 4),

    MATERIAL_VAR_VERTEXALPHA = (1 << 5),

    MATERIAL_VAR_SELFILLUM = (1 << 6),

    MATERIAL_VAR_ADDITIVE = (1 << 7),

    MATERIAL_VAR_ALPHATEST = (1 << 8),

    MATERIAL_VAR_ZNEARER = (1 << 10),

    MATERIAL_VAR_MODEL = (1 << 11),

    MATERIAL_VAR_FLAT = (1 << 12),

    MATERIAL_VAR_NOCULL = (1 << 13),

    MATERIAL_VAR_NOFOG = (1 << 14),

    MATERIAL_VAR_IGNOREZ = (1 << 15),

    MATERIAL_VAR_DECAL = (1 << 16),

    MATERIAL_VAR_ENVMAPSPHERE = (1 << 17),

    MATERIAL_VAR_ENVMAPCAMERASPACE = (1 << 19),

    MATERIAL_VAR_BASEALPHAENVMAPMASK = (1 << 20),

    MATERIAL_VAR_TRANSLUCENT = (1 << 21),

    MATERIAL_VAR_NORMALMAPALPHAENVMAPMASK = (1 << 22),

    MATERIAL_VAR_NEEDS_SOFTWARE_SKINNING = (1 << 23),

    MATERIAL_VAR_OPAQUETEXTURE = (1 << 24),

    MATERIAL_VAR_ENVMAPMODE = (1 << 25),

    MATERIAL_VAR_SUPPRESS_DECALS = (1 << 26),

    MATERIAL_VAR_HALFLAMBERT = (1 << 27),

    MATERIAL_VAR_WIREFRAME = (1 << 28),

    MATERIAL_VAR_ALLOWALPHATOCOVERAGE = (1 << 29),

    MATERIAL_VAR_ALPHA_MODIFIED_BY_PROXY = (1 << 30),

    MATERIAL_VAR_VERTEXFOG = (1 << 31)

}

-- Standard Enum

EUserMessage = {

    Geiger = 0,

    Train = 1,

    HudText = 2,

    SayText = 3,

    SayText2 = 4,

    TextMsg = 5,

    ResetHUD = 6,

    GameTitle = 7,

    ItemPickup = 8,

    ShowMenu = 9,

    Shake = 10,

    Fade = 11,

    VGUIMenu = 12,

    Rumble = 13,

    CloseCaption = 14,

    SendAudio = 15,

    VoiceMask = 16,

    RequestState = 17,

    Damage = 18,

    HintText = 19,

    KeyHintText = 20,

    HudMsg = 21,

    AmmoDenied = 22,

    AchievementEvent = 23,

    UpdateRadar = 24,

    VoiceSubtitle = 25,

    HudNotify = 26,

    HudNotifyCustom = 27,

    PlayerStatsUpdate = 28,

    MapStatsUpdate = 29,

    PlayerIgnited = 30,

    PlayerIgnitedInv = 31,

    HudArenaNotify = 32,

    UpdateAchievement = 33,

    TrainingMsg = 34,

    TrainingObjective = 35,

    DamageDodged = 36,

    PlayerJarated = 37,

    PlayerExtinguished = 38,

    PlayerJaratedFade = 39,

    PlayerShieldBlocked = 40,

    BreakModel = 41,

    CheapBreakModel = 42,

    BreakModel_Pumpkin = 43,

    BreakModelRocketDud = 44,

    CallVoteFailed = 45,

    VoteStart = 46,

    VotePass = 47,

    VoteFailed = 48,

    VoteSetup = 49,

    PlayerBonusPoints = 50,

    RDTeamPointsChanged = 51,

    SpawnFlyingBird = 52,

    PlayerGodRayEffect = 53,

    PlayerTeleportHomeEffect = 54,

    MVMStatsReset = 55,

    MVMPlayerEvent = 56,

    MVMResetPlayerStats = 57,

    MVMWaveFailed = 58,

    MVMAnnouncement = 59,

    MVMPlayerUpgradedEvent = 60,

    MVMVictory = 61,

    MVMWaveChange = 62,

    MVMLocalPlayerUpgradesClear = 63,

    MVMLocalPlayerUpgradesValue = 64,

    MVMResetPlayerWaveSpendingStats = 65,

    MVMLocalPlayerWaveSpendingValue = 66,

    MVMResetPlayerUpgradeSpending = 67,

    MVMServerKickTimeUpdate = 68,

    PlayerLoadoutUpdated = 69,

    PlayerTauntSoundLoopStart = 70,

    PlayerTauntSoundLoopEnd = 71,

    ForcePlayerViewAngles = 72,

    BonusDucks = 73,

    EOTLDuckEvent = 74,

    PlayerPickupWeapon = 75,

    QuestObjectiveCompleted = 76,

    SPHapWeapEvent = 77,

    HapDmg = 78,

    HapPunch = 79,

    HapSetDrag = 80,

    HapSetConst = 81,

    HapMeleeContact = 82

}

EButtonCode = {

    BUTTON_CODE_INVALID = BUTTON_CODE_INVALID,

    BUTTON_CODE_NONE = BUTTON_CODE_NONE,

    KEY_FIRST = KEY_FIRST,

    KEY_NONE = KEY_NONE,

    KEY_0 = KEY_0,

    KEY_1 = KEY_1,

    KEY_2 = KEY_2,

    KEY_3 = KEY_3,

    KEY_4 = KEY_4,

    KEY_5 = KEY_5,

    KEY_6 = KEY_6,

    KEY_7 = KEY_7,

    KEY_8 = KEY_8,

    KEY_9 = KEY_9,

    KEY_A = KEY_A,

    KEY_B = KEY_B,

    KEY_C = KEY_C,

    KEY_D = KEY_D,

    KEY_E = KEY_E,

    KEY_F = KEY_F,

    KEY_G = KEY_G,

    KEY_H = KEY_H,

    KEY_I = KEY_I,

    KEY_J = KEY_J,

    KEY_K = KEY_K,

    KEY_L = KEY_L,

    KEY_M = KEY_M,

    KEY_N = KEY_N,

    KEY_O = KEY_O,

    KEY_P = KEY_P,

    KEY_Q = KEY_Q,

    KEY_R = KEY_R,

    KEY_S = KEY_S,

    KEY_T = KEY_T,

    KEY_U = KEY_U,

    KEY_V = KEY_V,

    KEY_W = KEY_W,

    KEY_X = KEY_X,

    KEY_Y = KEY_Y,

    KEY_Z = KEY_Z,

    KEY_PAD_0 = KEY_PAD_0,

    KEY_PAD_1 = KEY_PAD_1,

    KEY_PAD_2 = KEY_PAD_2,

    KEY_PAD_3 = KEY_PAD_3,

    KEY_PAD_4 = KEY_PAD_4,

    KEY_PAD_5 = KEY_PAD_5,

    KEY_PAD_6 = KEY_PAD_6,

    KEY_PAD_7 = KEY_PAD_7,

    KEY_PAD_8 = KEY_PAD_8,

    KEY_PAD_9 = KEY_PAD_9,

    KEY_PAD_DIVIDE = KEY_PAD_DIVIDE,

    KEY_PAD_MULTIPLY = KEY_PAD_MULTIPLY,

    KEY_PAD_MINUS = KEY_PAD_MINUS,

    KEY_PAD_PLUS = KEY_PAD_PLUS,

    KEY_PAD_ENTER = KEY_PAD_ENTER,

    KEY_PAD_DECIMAL = KEY_PAD_DECIMAL,

    KEY_LBRACKET = KEY_LBRACKET,

    KEY_RBRACKET = KEY_RBRACKET,

    KEY_SEMICOLON = KEY_SEMICOLON,

    KEY_APOSTROPHE = KEY_APOSTROPHE,

    KEY_BACKQUOTE = KEY_BACKQUOTE,

    KEY_COMMA = KEY_COMMA,

    KEY_PERIOD = KEY_PERIOD,

    KEY_SLASH = KEY_SLASH,

    KEY_BACKSLASH = KEY_BACKSLASH,

    KEY_MINUS = KEY_MINUS,

    KEY_EQUAL = KEY_EQUAL,

    KEY_ENTER = KEY_ENTER,

    KEY_SPACE = KEY_SPACE,

    KEY_BACKSPACE = KEY_BACKSPACE,

    KEY_TAB = KEY_TAB,

    KEY_CAPSLOCK = KEY_CAPSLOCK,

    KEY_NUMLOCK = KEY_NUMLOCK,

    KEY_ESCAPE = KEY_ESCAPE,

    KEY_SCROLLLOCK = KEY_SCROLLLOCK,

    KEY_INSERT = KEY_INSERT,

    KEY_DELETE = KEY_DELETE,

    KEY_HOME = KEY_HOME,

    KEY_END = KEY_END,

    KEY_PAGEUP = KEY_PAGEUP,

    KEY_PAGEDOWN = KEY_PAGEDOWN,

    KEY_BREAK = KEY_BREAK,

    KEY_LSHIFT = KEY_LSHIFT,

    KEY_RSHIFT = KEY_RSHIFT,

    KEY_LALT = KEY_LALT,

    KEY_RALT = KEY_RALT,

    KEY_LCONTROL = KEY_LCONTROL,

    KEY_RCONTROL = KEY_RCONTROL,

    KEY_LWIN = KEY_LWIN,

    KEY_RWIN = KEY_RWIN,

    KEY_APP = KEY_APP,

    KEY_UP = KEY_UP,

    KEY_LEFT = KEY_LEFT,

    KEY_DOWN = KEY_DOWN,

    KEY_RIGHT = KEY_RIGHT,

    KEY_F1 = KEY_F1,

    KEY_F2 = KEY_F2,

    KEY_F3 = KEY_F3,

    KEY_F4 = KEY_F4,

    KEY_F5 = KEY_F5,

    KEY_F6 = KEY_F6,

    KEY_F7 = KEY_F7,

    KEY_F8 = KEY_F8,

    KEY_F9 = KEY_F9,

    KEY_F10 = KEY_F10,

    KEY_F11 = KEY_F11,

    KEY_F12 = KEY_F12,

    KEY_CAPSLOCKTOGGLE = KEY_CAPSLOCKTOGGLE,

    KEY_NUMLOCKTOGGLE = KEY_NUMLOCKTOGGLE,

    KEY_SCROLLLOCKTOGGLE = KEY_SCROLLLOCKTOGGLE,

    KEY_LAST = KEY_LAST,

    KEY_COUNT = KEY_COUNT,

    MOUSE_FIRST = MOUSE_FIRST,

    MOUSE_LEFT = MOUSE_LEFT,

    MOUSE_RIGHT = MOUSE_RIGHT,

    MOUSE_MIDDLE = MOUSE_MIDDLE,

    MOUSE_4 = MOUSE_4,

    MOUSE_5 = MOUSE_5,

    MOUSE_WHEEL_UP = MOUSE_WHEEL_UP,

    MOUSE_WHEEL_DOWN = MOUSE_WHEEL_DOWN

}

ETFCOND = {

    TF_COND_AIMING = 0,

    TF_COND_ZOOMED = 1,

    TF_COND_DISGUISING = 2,

    TF_COND_DISGUISED = 3,

    TF_COND_STEALTHED = 4,

    TF_COND_INVULNERABLE = 5,

    TF_COND_TELEPORTED = 6,

    TF_COND_TAUNTING = 7,

    TF_COND_INVULNERABLE_WEARINGOFF = 8,

    TF_COND_STEALTHED_BLINK = 9,

    TF_COND_SELECTED_TO_TELEPORT = 10,

    TF_COND_CRITBOOSTED = 11,

    TF_COND_TMPDAMAGEBONUS = 12,

    TF_COND_FEIGN_DEATH = 13,

    TF_COND_PHASE = 14,

    TF_COND_STUNNED = 15,

    TF_COND_OFFENSEBUFF = 16,

    TF_COND_SHIELD_CHARGE = 17,

    TF_COND_DEMO_BUFF = 18,

    TF_COND_ENERGY_BUFF = 19,

    TF_COND_RADIUSHEAL = 20,

    TF_COND_HEALTH_BUFF = 21,

    TF_COND_BURNING = 22,

    TF_COND_HEALTH_OVERHEALED = 23,

    TF_COND_URINE = 24,

    TF_COND_BLEEDING = 25,

    TF_COND_DEFENSEBUFF = 26,

    TF_COND_MAD_MILK = 27,

    TF_COND_MEGAHEAL = 28,

    TF_COND_REGENONDAMAGEBUFF = 29,

    TF_COND_MARKEDFORDEATH = 30,

    TF_COND_NOHEALINGDAMAGEBUFF = 31,

    TF_COND_SPEED_BOOST = 32,

    TF_COND_CRITBOOSTED_PUMPKIN = 33,

    TF_COND_CRITBOOSTED_USER_BUFF = 34,

    TF_COND_CRITBOOSTED_DEMO_CHARGE = 35,

    TF_COND_SODAPOPPER_HYPE = 36,

    TF_COND_CRITBOOSTED_FIRST_BLOOD = 37,

    TF_COND_CRITBOOSTED_BONUS_TIME = 38,

    TF_COND_CRITBOOSTED_CTF_CAPTURE = 39,

    TF_COND_CRITBOOSTED_ON_KILL = 40,

    TF_COND_CANNOT_SWITCH_FROM_MELEE = 41,

    TF_COND_DEFENSEBUFF_NO_CRIT_BLOCK = 42,

    TF_COND_REPROGRAMMED = 43,

    TF_COND_CRITBOOSTED_RAGE_BUFF = 44,

    TF_COND_DEFENSEBUFF_HIGH = 45,

    TF_COND_SNIPERCHARGE_RAGE_BUFF = 46,

    TF_COND_DISGUISE_WEARINGOFF = 47,

    TF_COND_MARKEDFORDEATH_SILENT = 48,

    TF_COND_DISGUISED_AS_DISPENSER = 49,

    TF_COND_SAPPED = 50,

    TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED = 51,

    TF_COND_INVULNERABLE_USER_BUFF = 52,

    TF_COND_HALLOWEEN_BOMB_HEAD = 53,

    TF_COND_HALLOWEEN_THRILLER = 54,

    TF_COND_RADIUSHEAL_ON_DAMAGE = 55,

    TF_COND_CRITBOOSTED_CARD_EFFECT = 56,

    TF_COND_INVULNERABLE_CARD_EFFECT = 57,

    TF_COND_MEDIGUN_UBER_BULLET_RESIST = 58,

    TF_COND_MEDIGUN_UBER_BLAST_RESIST = 59,

    TF_COND_MEDIGUN_UBER_FIRE_RESIST = 60,

    TF_COND_MEDIGUN_SMALL_BULLET_RESIST = 61,

    TF_COND_MEDIGUN_SMALL_BLAST_RESIST = 62,

    TF_COND_MEDIGUN_SMALL_FIRE_RESIST = 63,

    TF_COND_STEALTHED_USER_BUFF = 64,

    TF_COND_MEDIGUN_DEBUFF = 65,

    TF_COND_STEALTHED_USER_BUFF_FADING = 66,

    TF_COND_BULLET_IMMUNE = 67,

    TF_COND_BLAST_IMMUNE = 68,

    TF_COND_FIRE_IMMUNE = 69,

    TF_COND_PREVENT_DEATH = 70,

    TF_COND_MVM_BOT_STUN_RADIOWAVE = 71,

    TF_COND_HALLOWEEN_SPEED_BOOST = 72,

    TF_COND_HALLOWEEN_QUICK_HEAL = 73,

    TF_COND_HALLOWEEN_GIANT = 74,

    TF_COND_HALLOWEEN_TINY = 75,

    TF_COND_HALLOWEEN_IN_HELL = 76,

    TF_COND_HALLOWEEN_GHOST_MODE = 77,

    TF_COND_MINICRITBOOSTED_ON_KILL = 78,

    TF_COND_OBSCURED_SMOKE = 79,

    TF_COND_PARACHUTE_ACTIVE = 80,

    TF_COND_BLASTJUMPING = 81,

    TF_COND_HALLOWEEN_KART = 82,

    TF_COND_HALLOWEEN_KART_DASH = 83,

    TF_COND_BALLOON_HEAD = 84,

    TF_COND_MELEE_ONLY = 85,

    TF_COND_SWIMMING_CURSE = 86,

    TF_COND_FREEZE_INPUT = 87,

    TF_COND_HALLOWEEN_KART_CAGE = 88,

    TF_COND_DONOTUSE_0 = 89,

    TF_COND_RUNE_STRENGTH = 90,

    TF_COND_RUNE_HASTE = 91,

    TF_COND_RUNE_REGEN = 92,

    TF_COND_RUNE_RESIST = 93,

    TF_COND_RUNE_VAMPIRE = 94,

    TF_COND_RUNE_REFLECT = 95,

    TF_COND_RUNE_PRECISION = 96,

    TF_COND_RUNE_AGILITY = 97,

    TF_COND_GRAPPLINGHOOK = 98,

    TF_COND_GRAPPLINGHOOK_SAFEFALL = 99,

    TF_COND_GRAPPLINGHOOK_LATCHED = 100,

    TF_COND_GRAPPLINGHOOK_BLEEDING = 101,

    TF_COND_AFTERBURN_IMMUNE = 102,

    TF_COND_RUNE_KNOCKOUT = 103,

    TF_COND_RUNE_IMBALANCE = 104,

    TF_COND_CRITBOOSTED_RUNE_TEMP = 105,

    TF_COND_PASSTIME_INTERCEPTION = 106,

    TF_COND_SWIMMING_NO_EFFECTS = 107,

    TF_COND_PURGATORY = 108,

    TF_COND_RUNE_KING = 109,

    TF_COND_RUNE_PLAGUE = 110,

    TF_COND_RUNE_SUPERNOVA = 111,

    TF_COND_PLAGUE = 112,

    TF_COND_KING_BUFFED = 113,

    TF_COND_TEAM_GLOWS = 114,

    TF_COND_KNOCKED_INTO_AIR = 115,

    TF_COND_COMPETITIVE_WINNER = 116,

    TF_COND_COMPETITIVE_LOSER = 117,

    TF_COND_HEALING_DEBUFF = 118,

    TF_COND_PASSTIME_PENALTY_DEBUFF = 119,

    TF_COND_GRAPPLED_TO_PLAYER = 120,

    TF_COND_GRAPPLED_BY_PLAYER = 121,

    TF_COND_PARACHUTE_DEPLOYED = 122,

    TF_COND_GAS = 123,

    TF_COND_BURNING_PYRO = 124,

    TF_COND_ROCKETPACK = 125,

    TF_COND_LOST_FOOTING = 126,

    TF_COND_AIR_CURRENT = 127,

    TF_COND_HALLOWEEN_HELL_HEAL = 128,

    TF_COND_POWERUPMODE_DOMINANT = 129,

    TF_COND_INVALID = -1

}

ELifeState = {

    LIFE_ALIVE = 0,

    LIFE_DYING = 1,

    LIFE_DEAD = 2,

    LIFE_RESPAWNABLE = 3,

    LIFE_DISCARDAIM_BODY = 4

}

EWeaponID = {

    TF_WEAPON_NONE = 0,

    TF_WEAPON_BAT = 1,

    TF_WEAPON_BAT_WOOD = 2,

    TF_WEAPON_BOTTLE = 3,

    TF_WEAPON_FIREAXE = 4,

    TF_WEAPON_CLUB = 5,

    TF_WEAPON_CROWBAR = 6,

    TF_WEAPON_KNIFE = 7,

    TF_WEAPON_FISTS = 8,

    TF_WEAPON_SHOVEL = 9,

    TF_WEAPON_WRENCH = 10,

    TF_WEAPON_BONESAW = 11,

    TF_WEAPON_SHOTGUN_PRIMARY = 12,

    TF_WEAPON_SHOTGUN_SOLDIER = 13,

    TF_WEAPON_SHOTGUN_HWG = 14,

    TF_WEAPON_SHOTGUN_PYRO = 15,

    TF_WEAPON_SCATTERGUN = 16,

    TF_WEAPON_SNIPERRIFLE = 17,

    TF_WEAPON_MINIGUN = 18,

    TF_WEAPON_SMG = 19,

    TF_WEAPON_SYRINGEGUN_MEDIC = 20,

    TF_WEAPON_TRANQ = 21,

    TF_WEAPON_ROCKETLAUNCHER = 22,

    TF_WEAPON_GRENADELAUNCHER = 23,

    TF_WEAPON_PIPEBOMBLAUNCHER = 24,

    TF_WEAPON_FLAMETHROWER = 25,

    TF_WEAPON_GRENADE_NORMAL = 26,

    TF_WEAPON_GRENADE_CONCUSSION = 27,

    TF_WEAPON_GRENADE_NAIL = 28,

    TF_WEAPON_GRENADE_MIRV = 29,

    TF_WEAPON_GRENADE_MIRV_DEMOMAN = 30,

    TF_WEAPON_GRENADE_NAPALM = 31,

    TF_WEAPON_GRENADE_GAS = 32,

    TF_WEAPON_GRENADE_EMP = 33,

    TF_WEAPON_GRENADE_CALTROP = 34,

    TF_WEAPON_GRENADE_PIPEBOMB = 35,

    TF_WEAPON_GRENADE_SMOKE_BOMB = 36,

    TF_WEAPON_GRENADE_HEAL = 37,

    TF_WEAPON_GRENADE_STUNBALL = 38,

    TF_WEAPON_GRENADE_JAR = 39,

    TF_WEAPON_GRENADE_JAR_MILK = 40,

    TF_WEAPON_PISTOL = 41,

    TF_WEAPON_PISTOL_SCOUT = 42,

    TF_WEAPON_REVOLVER = 43,

    TF_WEAPON_NAILGUN = 44,

    TF_WEAPON_PDA = 45,

    TF_WEAPON_PDA_ENGINEER_BUILD = 46,

    TF_WEAPON_PDA_ENGINEER_DESTROY = 47,

    TF_WEAPON_PDA_SPY = 48,

    TF_WEAPON_BUILDER = 49,

    TF_WEAPON_MEDIGUN = 50,

    TF_WEAPON_GRENADE_MIRVBOMB = 51,

    TF_WEAPON_FLAMETHROWER_ROCKET = 52,

    TF_WEAPON_GRENADE_DEMOMAN = 53,

    TF_WEAPON_SENTRY_BULLET = 54,

    TF_WEAPON_SENTRY_ROCKET = 55,

    TF_WEAPON_DISPENSER = 56,

    TF_WEAPON_INVIS = 57,

    TF_WEAPON_FLAREGUN = 58,

    TF_WEAPON_LUNCHBOX = 59,

    TF_WEAPON_JAR = 60,

    TF_WEAPON_COMPOUND_BOW = 61,

    TF_WEAPON_BUFF_ITEM = 62,

    TF_WEAPON_PUMPKIN_BOMB = 63,

    TF_WEAPON_SWORD = 64,

    TF_WEAPON_DIRECTHIT = 65,

    TF_WEAPON_LIFELINE = 66,

    TF_WEAPON_LASER_POINTER = 67,

    TF_WEAPON_DISPENSER_GUN = 68,

    TF_WEAPON_SENTRY_REVENGE = 69,

    TF_WEAPON_JAR_MILK = 70,

    TF_WEAPON_HANDGUN_SCOUT_PRIMARY = 71,

    TF_WEAPON_BAT_FISH = 72,

    TF_WEAPON_CROSSBOW = 73,

    TF_WEAPON_STICKBOMB = 74,

    TF_WEAPON_HANDGUN_SCOUT_SEC = 75,

    TF_WEAPON_SODA_POPPER = 76,

    TF_WEAPON_SNIPERRIFLE_DECAP = 77,

    TF_WEAPON_RAYGUN = 78,

    TF_WEAPON_PARTICLE_CANNON = 79,

    TF_WEAPON_MECHANICAL_ARM = 80,

    TF_WEAPON_DRG_POMSON = 81,

    TF_WEAPON_BAT_GIFTWRAP = 82,

    TF_WEAPON_GRENADE_ORNAMENT = 83,

    TF_WEAPON_RAYGUN_REVENGE = 84,

    TF_WEAPON_PEP_BRAWLER_BLASTER = 85,

    TF_WEAPON_CLEAVER = 86,

    TF_WEAPON_GRENADE_CLEAVER = 87,

    TF_WEAPON_STICKY_BALL_LAUNCHER = 88,

    TF_WEAPON_GRENADE_STICKY_BALL = 89,

    TF_WEAPON_SHOTGUN_BUILDING_RESCUE = 90,

    TF_WEAPON_CANNON = 91,

    TF_WEAPON_THROWABLE = 92,

    TF_WEAPON_GRENADE_THROWABLE = 93,

    TF_WEAPON_PDA_SPY_BUILD = 94,

    TF_WEAPON_GRENADE_WATERBALLOON = 95,

    TF_WEAPON_HARVESTER_SAW = 96,

    TF_WEAPON_SPELLBOOK = 97,

    TF_WEAPON_SPELLBOOK_PROJECTILE = 98,

    TF_WEAPON_SNIPERRIFLE_CLASSIC = 99,

    TF_WEAPON_PARACHUTE = 100,

    TF_WEAPON_GRAPPLINGHOOK = 101,

    TF_WEAPON_PASSTIME_GUN = 102,

    TF_WEAPON_CHARGED_SMG = 103,

    TF_WEAPON_BREAKABLE_SIGN = 104,

    TF_WEAPON_ROCKETPACK = 105,

    TF_WEAPON_SLAP = 106,

    TF_WEAPON_JAR_GAS = 107,

    TF_WEAPON_GRENADE_JAR_GAS = 108,

    TF_WEAPON_FLAME_BALL = 109

}

ESignonState = {

    SIGNONSTATE_NONE = 0,

    SIGNONSTATE_CHALLENGE = 1,

    SIGNONSTATE_CONNECTED = 2,

    SIGNONSTATE_NEW = 3,

    SIGNONSTATE_PRESPAWN = 4,

    SIGNONSTATE_SPAWN = 5,

    SIGNONSTATE_FULL = 6,

    SIGNONSTATE_CHANGELEVEL = 7

}

ELoadoutSlot = {

    LOADOUT_POSITION_PRIMARY = 0,

    LOADOUT_POSITION_SECONDARY = 1,

    LOADOUT_POSITION_MELEE = 2,

    LOADOUT_POSITION_UTILITY = 3,

    LOADOUT_POSITION_BUILDING = 4,

    LOADOUT_POSITION_PDA = 5,

    LOADOUT_POSITION_PDA2 = 6,

    LOADOUT_POSITION_HEAD = 7,

    LOADOUT_POSITION_MISC = 8,

    LOADOUT_POSITION_ACTION = 9,

    LOADOUT_POSITION_MISC2 = 10,

    LOADOUT_POSITION_TAUNT = 11,

    LOADOUT_POSITION_TAUNT2 = 12,

    LOADOUT_POSITION_TAUNT3 = 13,

    LOADOUT_POSITION_TAUNT4 = 14,

    LOADOUT_POSITION_TAUNT5 = 15,

    LOADOUT_POSITION_TAUNT6 = 16,

    LOADOUT_POSITION_TAUNT7 = 17,

    LOADOUT_POSITION_TAUNT8 = 18

}

ERoundState = {

    GR_STATE_INIT = 0,

    GR_STATE_PREGAME = 1,

    GR_STATE_STARTGAME = 2,

    GR_STATE_PREROUND = 3,

    GR_STATE_RND_RUNNING = 4,

    GR_STATE_TEAM_WIN = 5,

    GR_STATE_RESTART = 6,

    GR_STATE_STALEMATE = 7,

    GR_STATE_GAME_OVER = 8,

    GR_NUM_ROUND_STATES = 11

}

ESpectatorMode = {

    OBS_MODE_NONE = 0,

    OBS_MODE_DEATHCAM = 1,

    OBS_MODE_FREEZECAM = 2,

    OBS_MODE_FIXED = 3,

    OBS_MODE_IN_EYE = 4,

    OBS_MODE_CHASE = 5,

    OBS_MODE_POI = 6,

    OBS_MODE_ROAMING = 7,

    NUM_OBSERVER_MODES = 8

}

EMatchAbandonStatus = {

    MATCHABANDON_SAFE = 0,

    MATCHABANDON_NOPENALTY = 1,

    MATCHABANDON_PENTALTY = 2

}

ERuneType = {

    RUNETYPE_TEMP_NONE = 0,

    RUNETYPE_TEMP_CRIT = 1,

    RUNETYPE_TEMP_UBER = 2

}

EProjectileType = {

    TF_PROJECTILE_NONE = 0,

    TF_PROJECTILE_BULLET = 1,

    TF_PROJECTILE_ROCKET = 2,

    TF_PROJECTILE_PIPEBOMB = 3,

    TF_PROJECTILE_PIPEBOMB_REMOTE = 4,

    TF_PROJECTILE_SYRINGE = 5,

    TF_PROJECTILE_FLARE = 6,

    TF_PROJECTILE_JAR = 7,

    TF_PROJECTILE_ARROW = 8,

    TF_PROJECTILE_FLAME_ROCKET = 9,

    TF_PROJECTILE_JAR_MILK = 10,

    TF_PROJECTILE_HEALING_BOLT = 11,

    TF_PROJECTILE_ENERGY_BALL = 12,

    TF_PROJECTILE_ENERGY_RING = 13,

    TF_PROJECTILE_PIPEBOMB_PRACTICE = 14,

    TF_PROJECTILE_CLEAVER = 15,

    TF_PROJECTILE_STICKY_BALL = 16,

    TF_PROJECTILE_CANNONBALL = 17,

    TF_PROJECTILE_BUILDING_REPAIR_BOLT = 18,

    TF_PROJECTILE_FESTIVE_ARROW = 19,

    TF_PROJECTILE_THROWABLE = 20,

    TF_PROJECTILE_SPELL = 21,

    TF_PROJECTILE_FESTIVE_JAR = 22,

    TF_PROJECTILE_FESTIVE_HEALING_BOLT = 23,

    TF_PROJECTILE_BREADMONSTER_JARATE = 24,

    TF_PROJECTILE_BREADMONSTER_MADMILK = 25,

    TF_PROJECTILE_GRAPPLINGHOOK = 26,

    TF_PROJECTILE_SENTRY_ROCKET = 27,

    TF_PROJECTILE_BREAD_MONSTER = 28

}

EMoveType = {

    MOVETYPE_NONE = 0,

    MOVETYPE_ISOMETRIC = 1,

    MOVETYPE_WALK = 2,

    MOVETYPE_STEP = 3,

    MOVETYPE_FLY = 4,

    MOVETYPE_FLYGRAVITY = 5,

    MOVETYPE_VPHYSICS = 6,

    MOVETYPE_PUSH = 7,

    MOVETYPE_NOCLIP = 8,

    MOVETYPE_LADDER = 9,

    MOVETYPE_OBSERVER = 10,

    MOVETYPE_CUSTOM = 11

}

EHitbox = {

    HITBOX_HEAD = 0,

    HITBOX_PELVIS = 1,

    HITBOX_SPINE_0 = 2,

    HITBOX_SPINE_1 = 3,

    HITBOX_SPINE_2 = 4,

    HITBOX_SPINE_3 = 5,

    HITBOX_UPPERARM_L = 6,

    HITBOX_LOWERARM_L = 7,

    HITBOX_HAND_L = 8,

    HITBOX_UPPERARM_R = 9,

    HITBOX_LOWERARM_R = 10,

    HITBOX_HAND_R = 11,

    HITBOX_HIP_L = 12,

    HITBOX_KNEE_L = 13,

    HITBOX_FOOT_L = 14,

    HITBOX_HIP_R = 15,

    HITBOX_KNEE_R = 16,

    HITBOX_FOOT_R = 17

}

ETFDmgCustom = {

    TF_DMG_CUSTOM_NONE = 0,

    TF_DMG_CUSTOM_HEADSHOT = 1,

    TF_DMG_CUSTOM_BACKSTAB = 2,

    TF_DMG_CUSTOM_BURNING = 3,

    TF_DMG_WRENCH_FIX = 4,

    TF_DMG_CUSTOM_MINIGUN = 5,

    TF_DMG_CUSTOM_SUICIDE = 6,

    TF_DMG_CUSTOM_TAUNTATK_HADOUKEN = 7,

    TF_DMG_CUSTOM_BURNING_FLARE = 8,

    TF_DMG_CUSTOM_TAUNTATK_HIGH_NOON = 9,

    TF_DMG_CUSTOM_TAUNTATK_GRAND_SLAM = 10,

    TF_DMG_CUSTOM_PENETRATE_MY_TEAM = 11,

    TF_DMG_CUSTOM_PENETRATE_ALL_PLAYERS = 12,

    TF_DMG_CUSTOM_TAUNTATK_FENCING = 13,

    TF_DMG_CUSTOM_PENETRATE_NONBURNING_TEAMMATE = 14,

    TF_DMG_CUSTOM_TAUNTATK_ARROW_STAB = 15,

    TF_DMG_CUSTOM_TELEFRAG = 16,

    TF_DMG_CUSTOM_BURNING_ARROW = 17,

    TF_DMG_CUSTOM_FLYINGBURN = 18,

    TF_DMG_CUSTOM_PUMPKIN_BOMB = 19,

    TF_DMG_CUSTOM_DECAPITATION = 20,

    TF_DMG_CUSTOM_TAUNTATK_GRENADE = 21,

    TF_DMG_CUSTOM_BASEBALL = 22,

    TF_DMG_CUSTOM_CHARGE_IMPACT = 23,

    TF_DMG_CUSTOM_TAUNTATK_BARBARIAN_SWING = 24,

    TF_DMG_CUSTOM_AIR_STICKY_BURST = 25,

    TF_DMG_CUSTOM_DEFENSIVE_STICKY = 26,

    TF_DMG_CUSTOM_PICKAXE = 27,

    TF_DMG_CUSTOM_ROCKET_DIRECTHIT = 28,

    TF_DMG_CUSTOM_TAUNTATK_UBERSLICE = 29,

    TF_DMG_CUSTOM_PLAYER_SENTRY = 30,

    TF_DMG_CUSTOM_STANDARD_STICKY = 31,

    TF_DMG_CUSTOM_SHOTGUN_REVENGE_CRIT = 32,

    TF_DMG_CUSTOM_TAUNTATK_ENGINEER_GUITAR_SMASH = 33,

    TF_DMG_CUSTOM_BLEEDING = 34,

    TF_DMG_CUSTOM_GOLD_WRENCH = 35,

    TF_DMG_CUSTOM_CARRIED_BUILDING = 36,

    TF_DMG_CUSTOM_COMBO_PUNCH = 37,

    TF_DMG_CUSTOM_TAUNTATK_ENGINEER_ARM_KILL = 38,

    TF_DMG_CUSTOM_FISH_KILL = 39,

    TF_DMG_CUSTOM_TRIGGER_HURT = 40,

    TF_DMG_CUSTOM_DECAPITATION_BOSS = 41,

    TF_DMG_CUSTOM_STICKBOMB_EXPLOSION = 42,

    TF_DMG_CUSTOM_AEGIS_ROUND = 43,

    TF_DMG_CUSTOM_FLARE_EXPLOSION = 44,

    TF_DMG_CUSTOM_BOOTS_STOMP = 45,

    TF_DMG_CUSTOM_PLASMA = 46,

    TF_DMG_CUSTOM_PLASMA_CHARGED = 47,

    TF_DMG_CUSTOM_PLASMA_GIB = 48,

    TF_DMG_CUSTOM_PRACTICE_STICKY = 49,

    TF_DMG_CUSTOM_EYEBALL_ROCKET = 50,

    TF_DMG_CUSTOM_HEADSHOT_DECAPITATION = 51,

    TF_DMG_CUSTOM_TAUNTATK_ARMAGEDDON = 52,

    TF_DMG_CUSTOM_FLARE_PELLET = 53,

    TF_DMG_CUSTOM_CLEAVER = 54,

    TF_DMG_CUSTOM_CLEAVER_CRIT = 55,

    TF_DMG_CUSTOM_SAPPER_RECORDER_DEATH = 56,

    TF_DMG_CUSTOM_MERASMUS_PLAYER_BOMB = 57,

    TF_DMG_CUSTOM_MERASMUS_GRENADE = 58,

    TF_DMG_CUSTOM_MERASMUS_ZAP = 59,

    TF_DMG_CUSTOM_MERASMUS_DECAPITATION = 60,

    TF_DMG_CUSTOM_CANNONBALL_PUSH = 61,

    TF_DMG_CUSTOM_TAUNTATK_ALLCLASS_GUITAR_RIFF = 62,

    TF_DMG_CUSTOM_THROWABLE = 63,

    TF_DMG_CUSTOM_THROWABLE_KILL = 64,

    TF_DMG_CUSTOM_SPELL_TELEPORT = 65,

    TF_DMG_CUSTOM_SPELL_SKELETON = 66,

    TF_DMG_CUSTOM_SPELL_MIRV = 67,

    TF_DMG_CUSTOM_SPELL_METEOR = 68,

    TF_DMG_CUSTOM_SPELL_LIGHTNING = 69,

    TF_DMG_CUSTOM_SPELL_FIREBALL = 70,

    TF_DMG_CUSTOM_SPELL_MONOCULUS = 71,

    TF_DMG_CUSTOM_SPELL_BLASTJUMP = 72,

    TF_DMG_CUSTOM_SPELL_BATS = 73,

    TF_DMG_CUSTOM_SPELL_TINY = 74,

    TF_DMG_CUSTOM_KART = 75,

    TF_DMG_CUSTOM_GIANT_HAMMER = 76,

    TF_DMG_CUSTOM_RUNE_REFLECT = 77,

    TF_DMG_CUSTOM_DRAGONS_FURY_IGNITE = 78,

    TF_DMG_CUSTOM_DRAGONS_FURY_BONUS_BURNING = 79,

    TF_DMG_CUSTOM_SLAP_KILL = 80,

    TF_DMG_CUSTOM_CROC = 81,

    TF_DMG_CUSTOM_TAUNTATK_GASBLAST = 82,

    TF_DMG_CUSTOM_AXTINGUISHER_BOOSTED = 83,

    TF_DMG_CUSTOM_END = 84

}

ETFClass = {

    TF_CLASS_UNDEFINED = 0,

    TF_CLASS_SCOUT = 1,

    TF_CLASS_SNIPER = 2,

    TF_CLASS_SOLDIER = 3,

    TF_CLASS_DEMOMAN = 4,

    TF_CLASS_MEDIC = 5,

    TF_CLASS_HEAVYWEAPONS = 6,

    TF_CLASS_PYRO = 7,

    TF_CLASS_SPY = 8,

    TF_CLASS_ENGINEER = 9,

    TF_CLASS_CIVILIAN = 10,

    TF_CLASS_COUNT_ALL = 11,

    TF_CLASS_RANDOM = 12

}

ETFTeam = {

    TEAM_UNASSIGNED = 0,

    TEAM_SPECTATOR = 1,

    TF_TEAM_PVE_DEFENDERS = 2,

    TF_TEAM_RED = 2,

    TF_TEAM_BLUE = 3,

    TF_TEAM_PVE_INVADERS = 3,

    TF_TEAM_COUNT = 4,

    TF_TEAM_PVE_INVADERS_GIANTS = 4,

    TEAM_ANY = -1,

    TEAM_INVALID = -1

}

Made with Material for MkDocs



Lua Globals

This page describes the Lua globals that are available.

Functions

print( msg:any, ... )

Prints message to console. Each argument is printed on a new line.

printc( r:integer, g:integer, b:integer, a:integer, msg:any, ... )

Prints a colored message to console. Each argument is printed on a new line.

LoadScript( scriptFile )

Loads a Lua script from given file.

UnloadScript( scriptFile )

Unloads a Lua script from given file.

GetScriptName()

Returns current script's file name.



Lua Globals

This page describes the Lua globals that are available.

Functions

print( msg:any, ... )

Prints message to console. Each argument is printed on a new line.

printc( r:integer, g:integer, b:integer, a:integer, msg:any, ... )

Prints a colored message to console. Each argument is printed on a new line.

LoadScript( scriptFile )

Loads a Lua script from given file.

UnloadScript( scriptFile )

Unloads a Lua script from given file.

GetScriptName()

Returns current script's file name.



DrawModelContext

Represents the context in which a model is being drawn in the DrawModel callback.



Methods

GetEntity()

Returns entity linked to the drawn model, can be nil.



GetModelName()

Returns the name of the model being drawn.



ForcedMaterialOverride( mat:Material )

Replace material used to draw the model. Material can be found or created via materials. API



DrawExtraPass()

Redraws the model. Can be used to achieve various effects with different materials.



StudioSetColorModulation( color:Color )

Sets the color modulation of the model via StudioRender.



StudioSetAlphaModulation( alpha:number )

Sets the alpha modulation of the model via StudioRender.



DepthRange( start:number, end:number )

Sets the depth range of the scene. Useful for drawing models in the background or other various effects. Should be reset to the default (0,1) when done.



SuppressEngineLighting( bool:boolean )

Suppresses the engine lighting when drawing the model.



Examples

Draw all player models using AmmoBox material

local ammoboxMaterial = materials.Find( "models/items/ammo_box2" )



local function onDrawModel( drawModelContext )

    local entity = drawModelContext:GetEntity()



    if entity:GetClass() == "CTFPlayer" then

        drawModelContext:ForcedMaterialOverride( ammoboxMaterial )

    end

end



callbacks.Register("DrawModel", "hook123", onDrawModel)


Table of contents

Methods

IsValid()

GetName()

GetClass()

GetIndex()

GetTeamNumber()

GetAbsOrigin()

SetAbsOrigin()

GetMins()

GetMaxs()

GetHealth()

GetMaxHealth()

IsPlayer()

IsWeapon()

IsAlive()

EstimateAbsVelocity()

GetMoveType()

HitboxSurroundingBox()

EntitySpaceHitboxSurroundingBox()

GetHitboxes( [currentTime:number] )

IsDormant()

ToInventoryItem()

Attributes

AttributeHookFloat( name:string, [defaultValue:number] )

AttributeHookInt( name:string, [defaultValue:integer] )

Entity netvars/props

GetPropFloat( propName, ... )

GetPropInt( propName, ... )

GetPropBool( propName, ... )

GetPropString( propName, ... )

GetPropVector( propName, ... )

GetPropEntity( propName, ... )

SetPropFloat( value:number, propName, ... )

SetPropInt( value:integer, propName, ... )

SetPropBool( value:bool, propName, ... )

SetPropEntity( value:Entity, propName, ... )

SetPropVector( value:Vector3, propName, ... )

Prop Data Tables

GetPropDataTableFloat( propName, ... )

GetPropDataTableBool( propName, ... )

GetPropDataTableInt( propName, ... )

GetPropDataTableEntity( propName, ... )

SetPropDataTableFloat( value:number, index:integer, propName, ... )

SetPropDataTableBool( value:integer, index:integer, propName, ... )

SetPropDataTableInt( value:integer, index:integer, propName, ... )

SetPropDataTableEntity( value:Entity, index:integer, propName, ... )

Player entity methods

InCond( condition:integer )

AddCond( condition:integer, [duration:number] )

RemoveCond( condition:integer )

IsCritBoosted()

GetCritMult()

GetCarryingRuneType()

GetMaxBuffedHealth()

GetEntityForLoadoutSlot( slot:integer )

IsInFreezecam()

Weapon entity methods

IsShootingWeapon()

IsMeleeWeapon()

IsMedigun()

CanRandomCrit()

GetLoadoutSlot()

GetWeaponProjectileType()

IsViewModelFlipped()

Melee Weapon Methods

GetSwingRange()

DoSwingTrace()

Medigun methods

GetMedigunHealRate()

GetMedigunHealingStickRange()

GetMedigunHealingRange()

IsMedigunAllowedToHealTarget( target:Entity )

Weapon Crit Methods

GetCritTokenBucket()

GetCritCheckCount()

GetCritSeedRequestCount()

GetCurrentCritSeed()

GetRapidFireCritTime()

GetLastRapidFireCritCheckTime()

GetWeaponBaseDamage()

GetCritChance()

GetCritCost( tokenBucket:number, critSeedRequestCount:number, critCheckCount:number )

CalcObservedCritChance()

IsAttackCritical( commandNumber:integer )

GetWeaponDamageStats()

Examples

Entity

Represents an entity in the game world. Make sure to not store entities long term, they can become invalid over time - their methods will return nil in that case.



Methods

IsValid()

Returns whether the entity is valid. This is done automatically and all other functions will return nil if the entity is invalid.



GetName()

Returns the name of the entity if its a player



GetClass()

Returns the class of the entity i.e. CTFPlayer



GetIndex()

Returns entity index



GetTeamNumber()

Returns the team number of the entity



GetAbsOrigin()

Returns the absolute position of the entity



SetAbsOrigin()

Sets the absolute position of the entity



GetMins()

Returns mins of the entity, must be combined with origin



GetMaxs()

Returns maxs of the entity, must be combined with origin



GetHealth()

Returns the health of the entity



GetMaxHealth()

Returns the max health of the entity



IsPlayer()

Returns true if the entity is a player



IsWeapon()

Returns true if the entity is a weapon



IsAlive()

Returns true if the entity is alive



EstimateAbsVelocity()

Returns the estimated absolute velocity of the entity as Vector3



GetMoveType()

Returns the move type of the entity (the netvar propr does not work)



HitboxSurroundingBox()

Returns the hitbox surrounding box of the entity as table of Vector3 mins and maxs



EntitySpaceHitboxSurroundingBox()

Returns the hitbox surrounding box of the entity in entity space as table of Vector3 mins and maxs



GetHitboxes( [currentTime:number] )

Returns world-transformed hitboxes of the entity as table of tables, each containing 2 entries of Vector3: mins and maxs positions of each hitbox. The currentTime argument is optional, by default 0, and can be changed if you want the transform to be based on a different time. Example returned table:



Hitbox Index	Mins&Maxs table

1	1: Vector3(1,2,3) 2: Vector3(4,5,6)

2	1: Vector3(7,8,9) 2: Vector3(0,1,2)

IsDormant()

Returns true if the entity is dormant (not being updated). Dormant entities are not drawn and shouldn't be interacted with.



ToInventoryItem()

If the entity is an item that can be in player's inventory, such as a wearable or a weapon, returns the inventory item as Item



Attributes

In order to get the attributes of an entity, you can use the following methods. The attribute hooking methods will multiply the default value by the attribute value, returning the result. For list of attributes see the Wiki



AttributeHookFloat( name:string, [defaultValue:number] )

Returns the number value of the attribute present on the entity, defaultValue is by default 1.0



AttributeHookInt( name:string, [defaultValue:integer] )

Returns the integer value of the attribute present on the entity,defaultValue is by default 1



Entity netvars/props

You can either input just the netvar name, or the table path to it



GetPropFloat( propName, ... )

Returns the float value of the given netvar



GetPropInt( propName, ... )

Returns the int value of the given netvar



GetPropBool( propName, ... )

Returns the bool value of the given netvar



GetPropString( propName, ... )

Returns the string value of the given netvar



GetPropVector( propName, ... )

Returns the vector value of the given netvar



GetPropEntity( propName, ... )

For entity handle props (m_hXXXXX)



SetPropFloat( value:number, propName, ... )

Sets the float value of the given netvar.



SetPropInt( value:integer, propName, ... )

Sets the int value of the given netvar.



SetPropBool( value:bool, propName, ... )

Sets the bool value of the given netvar.



SetPropEntity( value:Entity, propName, ... )

Set the entity value of the given netvar.



SetPropVector( value:Vector3, propName, ... )

Set the vector value of the given netvar.



Prop Data Tables

They return a Lua Table containing the entries, you can index them with integers



GetPropDataTableFloat( propName, ... )

Returns a table of floats, index them with integers based on context of the netvar



GetPropDataTableBool( propName, ... )

Returns a table of bools, index them with integers based on context of the netvar



GetPropDataTableInt( propName, ... )

Returns a table of ints, index them with integers based on context of the netvar



GetPropDataTableEntity( propName, ... )

Returns a table of entities, index them with integers based on context of the netvar



SetPropDataTableFloat( value:number, index:integer, propName, ... )

Sets the number value of the given netvar at the given index.



SetPropDataTableBool( value:integer, index:integer, propName, ... )

Sets the bool value of the given netvar at the given index.



SetPropDataTableInt( value:integer, index:integer, propName, ... )

Sets the integer value of the given netvar at the given index.



SetPropDataTableEntity( value:Entity, index:integer, propName, ... )

Sets the Entity value of the given netvar at the given index.



Player entity methods

These methods are only available if the entity is a player



InCond( condition:integer )

Returns whether the player is in the specified condition. List of conditions in TF2 can be found



AddCond( condition:integer, [duration:number] )

Adds the specified condition to the player, duration is optional (defaults to -1, which means infinite)



RemoveCond( condition:integer )

Removes the specified condition from the player



IsCritBoosted()

Whether the player is currently crit boosted by an external source



GetCritMult()

Returns the current crit multiplier of the player. See TF2 Crit Wiki for more info



GetCarryingRuneType()

For game mode where players can carry runes, returns the type of rune the player is carrying



GetMaxBuffedHealth()

Returns the max health of the player, including any buffs from items or medics



GetEntityForLoadoutSlot( slot:integer )

Returns the entity for the specified loadout slot. This can be used to get the hat entity for the slot, or the weapon entity for the slot



IsInFreezecam()

Whether the player is currently in a freezecam after death



Weapon entity methods

These methods are only available if the entity is a weapon, some methods have closer specifications on weapon type, and will return nil if the entity is not required weapon type.



IsShootingWeapon()

Returns whether the weapon is a weapon that can shoot projectiles or hitscan.



IsMeleeWeapon()

Returns whether the weapon is a melee weapon.



IsMedigun()

Returns whether the weapon is a medigun, supports all types of mediguns.



CanRandomCrit()

Returns whether the weapon can randomly crit in general, not in it's current state.



GetLoadoutSlot()

Returns the loadout slot ID of the weapon.



GetWeaponProjectileType()

Returns the projectile type of the weapon, returns nil if the weapon is not a projectile weapon.



IsViewModelFlipped()

Returns whether the weapon's view model is flipped.



Melee Weapon Methods

GetSwingRange()

Returns the swing range of the weapon, returns nil if the weapon is not a melee weapon.



DoSwingTrace()

Returns the Trace object result of the weapon's swing. In simple terms, it simulates what would weapon hit if it was swung.



Medigun methods

GetMedigunHealRate()

Returns the heal rate of the medigun, returns nil if the weapon is not a medigun.



GetMedigunHealingStickRange()

Returns the healing stick range of the medigun, returns nil if the weapon is not a medigun.



GetMedigunHealingRange()

Returns the healing range of the medigun, returns nil if the weapon is not a medigun.



IsMedigunAllowedToHealTarget( target:Entity )

Returns whether the medigun is allowed to heal the target, returns nil if the weapon is not a medigun.



Weapon Crit Methods

The following methods have close ties to random crits in TF2. You most likely do not need to use these methods. Feel free to use them though, I'm not here to stop you.



GetCritTokenBucket()

Returns the current crit token bucket value.



GetCritCheckCount()

Returns the current crit check count.



GetCritSeedRequestCount()

Returns the current crit seed request count.



GetCurrentCritSeed()

Returns the current crit seed.



GetRapidFireCritTime()

Returns the time until the current rapid fire crit is over.



GetLastRapidFireCritCheckTime()

Returns the time of the last rapid fire crit check.



GetWeaponBaseDamage()

Returns the base damage of the weapon.



GetCritChance()

Returns the weapon's current crit chance as a number from 0 to 1. This crit chance changes during gameplay based on player's recently dealt damage.



GetCritCost( tokenBucket:number, critSeedRequestCount:number, critCheckCount:number )

Calculates the cost of a crit based on the given crit parameters. You can either use the GetCritTokenBucket(), GetCritCheckCount(), and GetCritSeedRequestCount() methods to get the current crit parameters, or you can pass your own if you are simulating crits.



CalcObservedCritChance()

This function estimates the observed crit chance. The observed crit chance is calculated on the server from the damage you deal across a game round. It is only rarely sent to the client, but is important for crit calculations.



IsAttackCritical( commandNumber:integer )

Returns whether the given command number would result in a crit.



GetWeaponDamageStats()

Returns the current damage stats as a following table:



Type	Damage

total	1234

critical	250

melee	90

Examples

Calculate needed crit hack damage

local myfont = draw.CreateFont( "Verdana", 16, 800 )



callbacks.Register( "Draw", function ()

    draw.Color(255, 255, 255, 255)

    draw.SetFont( myfont )



    local player = entities.GetLocalPlayer()

    local wpn = player:GetPropEntity("m_hActiveWeapon")



    if wpn ~= nil then

        local critChance = wpn:GetCritChance()

        local dmgStats = wpn:GetWeaponDamageStats()

        local totalDmg = dmgStats["total"]

        local criticalDmg = dmgStats["critical"]



        -- (the + 0.1 is always added to the comparsion)

        local cmpCritChance = critChance + 0.1



        -- If we are allowed to crit

        if cmpCritChance > wpn:CalcObservedCritChance() then

            draw.Text( 200, 510, "We can crit just fine!")

        else --Figure out how much damage we need

            local requiredTotalDamage = (criticalDmg * (2.0 * cmpCritChance + 1.0)) / cmpCritChance / 3.0

            local requiredDamage = requiredTotalDamage - totalDmg



            draw.Text( 200, 510, "Damage needed to crit: " .. math.floor(requiredDamage))

        end

    end

end )

Basic player ESP

local myfont = draw.CreateFont( "Verdana", 16, 800 )



local function doDraw()

    if engine.Con_IsVisible() or engine.IsGameUIVisible() then

        return

    end



    local players = entities.FindByClass("CTFPlayer")



    for i, p in ipairs( players ) do

        if p:IsAlive() and not p:IsDormant() then



            local screenPos = client.WorldToScreen( p:GetAbsOrigin() )

            if screenPos ~= nil then

                draw.SetFont( myfont )

                draw.Color( 255, 255, 255, 255 )

                draw.Text( screenPos[1], screenPos[2], p:GetName() )

            end

        end

    end

end



callbacks.Register("Draw", "mydraw", doDraw) 

Draw local player hitboxes

callbacks.Register( "Draw", function ()

    local player = entities.GetLocalPlayer()

    local hitboxes = player:GetHitboxes()



    for i = 1, #hitboxes do

        local hitbox = hitboxes[i]

        local min = hitbox[1]

        local max = hitbox[2]



        -- to screen space

        min = client.WorldToScreen( min )

        max = client.WorldToScreen( max )



        if (min ~= nil and max ~= nil) then

            -- draw hitbox

            draw.Color(255, 255, 255, 255)

            draw.Line( min[1], min[2], max[1], min[2] )

            draw.Line( max[1], min[2], max[1], max[2] )

            draw.Line( max[1], max[2], min[1], max[2] )

            draw.Line( min[1], max[2], min[1], min[2] )

        end

    end

end )

Clip size attribute on player

local me = entities.GetLocalPlayer()



local myClipSizeMultiplier = me:AttributeHookFloat( "mult_clipsize" )

Clip size attribute on weapon

local me = entities.GetLocalPlayer()



local primaryWeapon = me:GetEntityForLoadoutSlot( LOADOUT_POSITION_PRIMARY )

local weaponClipSizeMultiplier = primaryWeapon:AttributeHookFloat( "mult_clipsize" )

Is player taunting

local me = entities.GetLocalPlayer()



local isTaunting = me:InCond( TFCond_Taunting )

Get rage meter value

local me = entities.GetLocalPlayer()



local rageMeter = me:GetPropFloat( "m_flRageMeter" )

Made with Material for MkDocs

Table of contents

Constructor

EulerAngles( pitch, yaw, roll)

Fields

x / pitch

y / yaw

z / roll

Methods

Unpack()

Clear()

Normalize()

Forward()

Right()

Up()

Examples

EulerAngles

A class that represents a set of Euler angles.

Constructor

EulerAngles( pitch, yaw, roll)

Creates a new instace of EulerAngles.

Fields

Fields are modifiable directly.

x / pitch

number

y / yaw

number

z / roll

number

Methods

Unpack()

Returns the X, Y, and Z coordinates as a separate variables.

Clear()

Clears the angles to 0, 0, 0

Normalize()

Clamps the angles to standard ranges.

Forward()

Returns the forward vector of the angles.

Right()

Returns the right vector of the angles.

Up()

Returns the up vector of the angles.

Examples

Getting view angles

local me = entities.GetLocalPlayer()

local viewAngles = me:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]")

Unpack example

local myAngles = EulerAngles( 30, 60, 0 )

local pitch, yaw, roll = myAngles:Unpack()

Made with Material for MkDocs

Table of contents

Methods

GetName()

GetString( fieldName:string )

GetInt( fieldName:string )

GetFloat( fieldName:string )

SetString( fieldName:string, value:string )

SetInt( fieldName:string, value:int )

SetFloat( fieldName:string, value:float )

SetBool( fieldName:string, value:bool )

Examples

GameEvent

Represents a game event that was sent from the server. For a list of game events for Source games and TF2 see the GameEvent List.



Methods

GetName()

Returns the name of the event.



GetString( fieldName:string )

Returns the string value of the given field.



GetInt( fieldName:string )

Returns the int value of the given field.



GetFloat( fieldName:string )

Returns the float value of the given field.



SetString( fieldName:string, value:string )

Sets the string value of the given field.



SetInt( fieldName:string, value:int )

Sets the int value of the given field.



SetFloat( fieldName:string, value:float )

Sets the float value of the given field.



SetBool( fieldName:string, value:bool )

Sets the bool value of the given field.



Examples

Damage logger - by @RC

local function damageLogger(event)



    if (event:GetName() == 'player_hurt' ) then



        local localPlayer = entities.GetLocalPlayer();

        local victim = entities.GetByUserID(event:GetInt("userid"))

        local health = event:GetInt("health")

        local attacker = entities.GetByUserID(event:GetInt("attacker"))

        local damage = event:GetInt("damageamount")



        if (attacker == nil or localPlayer:GetIndex() ~= attacker:GetIndex()) then

            return

        end



        print("You hit " ..  victim:GetName() .. " or ID " .. victim:GetIndex() .. " for " .. damage .. "HP they now have " .. health .. "HP left")

    end



end



callbacks.Register("FireGameEvent", "exampledamageLogger", damageLogger)

-- Made by @RC: https://github.com/racistcop/lmaobox-luas/blob/main/example-damagelogger.lua

Made with Material for MkDocs

Methods

GetGroupID()

GetMembers()

Examples

GameServerLobby

The GameServerLobby library provides information about the current match made game.



Methods

GetGroupID()

Returns the group ID of the current lobby.



GetMembers()

Returns a table of LobbyPlayer objects representing the players in the lobby.



Examples

Print the steam IDs of all players in the lobby

local lobby = gamecoordinator.GetGameServerLobby()



if lobby then

    for _, player in pairs( lobby:GetMembers() ) do

        print( player:GetSteamID() )

    end

end

Made with Material for MkDocs

Methods

IsValid()

GetName()

GetDefIndex()

GetItemDefinition()

GetLevel()

GetItemID()

GetInventoryPosition()

IsEquippedForClass( classid:integer )

GetImageTextureID()

GetAttributes()

SetAttribute( attrDef:AttributeDefinition, value:any )

SetAttribute( attrName:string, value:any )

RemoveAttribute( attrDef:AttributeDefinition )

RemoveAttribute( attrName:string )

Examples

Item

Represents an item in player's inventory.



Methods

IsValid()

Returns true if the item is valid. There are instances where an item in the inventory is not valid and you should account for them. Otherwise, methods will return nil.



GetName()

Returns the name of the item. This is the name that is displayed in the inventory and can be custom.



GetDefIndex()

Returns the item's definition index. Can be used to get the item's definition.



GetItemDefinition()

Returns the item's definition as the ItemDefinition object.



GetLevel()

Returns the item's level.



GetItemID()

Returns the item's ID. This is a unique 64bit ID for the item that identifies it across the economy.



GetInventoryPosition()

Returns the item's position in the inventory.



IsEquippedForClass( classid:integer )

Returns true if the item is equipped for the given class.



GetImageTextureID()

Returns the item's backpack image texture ID. Some items may not have it, in which case, result is -1.



GetAttributes()

Returns the item's attributes as a table where keys are AttributeDefinition objects and values are the values of the attributes.



SetAttribute( attrDef:AttributeDefinition, value:any )

Sets the value of the given attribute by it's definition. The value must be the correct type for the given attribute definition.



SetAttribute( attrName:string, value:any )

Sets the value of the given attribute by it's name. The value must be the correct type for the given attribute definition.



RemoveAttribute( attrDef:AttributeDefinition )

Removes the given attribute by it's definition.



RemoveAttribute( attrName:string )

Removes the given attribute by it's name.



Examples

Set unusual effect and name of item

local nameAttr = itemschema.GetAttributeDefinitionByName( "custom name attr" )



local firstItem = inventory.GetItemByPosition( 1 )



firstItem:SetAttribute( "attach particle effect", 33 ) -- Set the unusual effect to rotating flames

firstItem:SetAttribute( nameAttr, "Dumb dumb item" ) -- Set the custom name to "Dumb dumb item"

Print all attributes of an item

local item = inventory.GetItemByPosition( 1 )



for def, v in pairs( item:GetAttributes() ) do

    print( def:GetName() .. " : " .. tostring( v ) )

end

Made with Material for MkDocs





---ItemDefinition




Methods

GetName()

GetID()

GetClass()

GetLoadoutSlot()

IsHidden()

IsTool()

IsBaseItem()

IsWearable()

GetNameTranslated()

GetTypeName()

GetDescription()

GetIconName()

GetBaseItemName()

GetAttributes()

Examples

ItemDefinition

The ItemDefinition object contains static information about an item. Static information refers to information that is not changed during the course of the game.



Methods

GetName()

Returns the name of the item.



GetID()

Returns the definition ID of the item.



GetClass()

Returns the class of the item.



GetLoadoutSlot()

Returns the loadout slot that the item should be placed in.



IsHidden()

Returns true if the item is hidden.



IsTool()

Returns true if the item is a tool, such as a key.



IsBaseItem()

Returns true if the item is a base item, such as a stock weapon.



IsWearable()

Returns true if the item is a wearable.



GetNameTranslated()

Returns the name of the item in the language of the current player.



GetTypeName()

Returns the type name of the item.



GetDescription()

Returns the description of the item.



GetIconName()

Returns the icon name of the item.



GetBaseItemName()

Returns the base item name of the item.



GetAttributes()

Returns the static item attributes as a table where keys are AttributeDefinition objects and values are the values of the attributes.



Examples

Get the name of active weapon

local me = entities.GetLocalPlayer()

local activeWeapon = me:GetPropEntity( "m_hActiveWeapon" )



if activeWeapon ~= nil then

    local itemDefinitionIndex = activeWeapon:GetPropInt( "m_iItemDefinitionIndex" )

    local itemDefinition = itemschema.GetItemDefinitionByID( itemDefinitionIndex )

    local weaponName = itemDefinition:GetName()

    print( weaponName )

end

Print all static active weapon attributes

local me = entities.GetLocalPlayer()

local activeWeapon = me:GetPropEntity( "m_hActiveWeapon" )

local itemDef = itemschema.GetItemDefinitionByID( activeWeapon:GetPropInt( "m_iItemDefinitionIndex" ) )

local attributes = itemDef:GetAttributes()



for attrDef, value in pairs( attributes ) do

    print( attrDef:GetName() .. ": " .. tostring( value ) )

end

Made with Material for MkDocs


Methods

GetSteamID()

GetTeam()

GetPlayerType()

GetName()

GetLastConnectTime()

Examples

LobbyPlayer

The LobbyPlayer class is used to provide information about a player in a Game Server lobby.



Methods

GetSteamID()

Returns the SteamID of the player as a string.



GetTeam()

Returns the GC assigned team of the player.



GetPlayerType()

Returns the GC assigned player type of this player.



GetName()

Returns the steam name of the player.



GetLastConnectTime()

Returns the last time the player connected to the server as a unix timestamp.



Examples

Print the steam IDs and teams of all players in a found lobby

callbacks.Register( "OnLobbyUpdated", "mylobby", function( lobby )

    for _, player in pairs( lobby:GetMembers() ) do

        print( player:GetSteamID(), player:GetTeam() )

    end

end )

Made with Material for MkDocs

Methods

GetID()

GetName()

IsCompetitiveMode()

MatchGroup

The MatchGroup object describes a single type of queue in TF2 matchmaking.



Methods

GetID()

Returns the ID of the match group.



GetName()

Returns the name of the match group.



IsCompetitiveMode()

Returns whether the match group is a competitive mode. Can return false if you are using a competitive bypass feature.



Made with Material for MkDocs




--MatchMapDefinition



Methods

GetName()

GetID()

GetNameLocKey()

MatchMapDefinition

Represents a map that is playable in a matchmaking match.



Methods

GetName()

Returns the name of the map.



GetID()

Returns the ID of the map.



GetNameLocKey()

Returns the map name localization key.



Made with Material for MkDocs


Material


Methods

GetName()

GetTextureGroupName

AlphaModulate( alpha:number )

ColorModulate( red:number, green:number, blue:number )

SetMaterialVarFlag( flag:integer, set:bool )

SetShaderParam( param:string, value:any )

Examples

Material

Represents a material in source engine. For more information about materials see the Material page.



Methods

GetName()

Returns the material name



GetTextureGroupName

Returns group the material is part of



AlphaModulate( alpha:number )

Modulate transparency of material by given alpha value



ColorModulate( red:number, green:number, blue:number )

Modulate color of material by given RGB values



SetMaterialVarFlag( flag:integer, set:bool )

Change a material variable flag, see MaterialVarFlags for a list of flags. The flag is the integer value of the flag enum, not the string name.



SetShaderParam( param:string, value:any )

Set a shader parameter, see ShaderParameters for a list of parameters. Supported values are integer, number, Vector3, string.



Examples

Create a material, and change ignorez to false

kv = [["VertexLitGeneric"

{

    "$basetexture"  "vgui/white_additive"

    "$ignorez" "1"

}

]]



myMaterial = materials.Create( "myMaterial", kv )

myMaterial:SetMaterialVarFlag( MATERIAL_VAR_IGNOREZ, false )

Made with Material for MkDocs


PartyMemberActivity


Methods

GetLobbyID()

IsOnline()

IsMultiqueueBlocked()

GetClientVersion()

PartyMemberActivity

The PartyMemberActivity class is used to provide information about a party member.



Methods

GetLobbyID()

Returns the lobby ID of the party member. This can be used to find out whether the party member is currently in a matchmade game.



IsOnline()

Returns whether the party member is currently online.



IsMultiqueueBlocked()

Returns whether the party member is currently blocked from joining a matchmade game.



GetClientVersion()

Returns the client version of the party member.



Made with Material for MkDocs


StringCmd


Methods

Get()

Set( string:command )

Examples

StringCmd

Represents a string command.



Methods

Get()

Used to get the command string itself.



Set( string:command )

Set the command string.



Examples

Prevent user from using 'status'

local function onStringCmd( stringCmd )



    if stringCmd:Get() == "status" then

        stringCmd:Set( "echo No status for you!" )

    end

end



callbacks.Register( "SendStringCmd", "hook", onStringCmd )

Made with Material for MkDocs




----Trace

Fields

fraction

entity

plane

contents

hitbox

hitgroup

allsolid

startsolid

startpos

endpos

Extra

Examples

Trace

Return value of engine.TraceLine and engine.TraceHull funcs



Fields

Fields are non-modifiable.



fraction

number



Fraction of the trace that was completed.



entity

Entity



The entity that was hit.



plane

Vector3



Plane normal of the surface hit.



contents

integer



Contents of the surface hit.



hitbox

integer



Hitbox that was hit.



hitgroup

integer



Hitgroup that was hit.



allsolid

boolean



Whether the trace completed in all solid.



startsolid

boolean



Whether the trace started in a solid.



startpos

Vector3



The start position of the trace.



endpos

Vector3



The end position of the trace.



Extra

More information can be found at Valve Wiki



Examples

What am I looking at?

local me = entities.GetLocalPlayer();

local source = me:GetAbsOrigin() + me:GetPropVector( "localdata", "m_vecViewOffset[0]" );

local destination = source + engine.GetViewAngles():Forward() * 1000;



local trace = engine.TraceLine( source, destination, MASK_SHOT_HULL );



if (trace.entity ~= nil) then

    print( "I am looking at " .. trace.entity:GetClass() );

    print( "Distance to entity: " .. trace.fraction * 1000 );

end

Made with Material for MkDocs




----UserCmd


Fields

command_number

tick_count

viewangles

forwardmove

sidemove

upmove

buttons

impulse

weaponselect

weaponsubtype

random_seed

mousedx

mousedy

hasbeenpredicted

sendpacket

Methods

SetViewAngles( pitch, yaw, roll )

GetViewAngles()

SetSendPacket( sendpacket )

GetSendPacket()

SetButtons( buttons )

GetButtons()

SetForwardMove( float factor )

GetForwardMove()

SetSideMove( float factor )

GetSideMove()

SetUpMove( float factor )

GetUpMove()

Examples

UserCmd

Represents a user (movement) command about to be sent to the server. For more in depth insight see the UserCmd page.



Fields

Fields are modifiable directly.



command_number

integer



The number of the command.



tick_count

integer



The current tick count.



viewangles

EulerAngles



The view angles of the player.



forwardmove

number



The forward movement of the player.



sidemove

number



The sideways movement of the player.



upmove

number



The upward movement of the player.



buttons

integer (bits)



The buttons that are pressed. Masked with bits from IN_* enum



impulse

integer



The impulse command that was issued.



weaponselect

integer



The weapon id that is selected.



weaponsubtype

integer



The subtype of the weapon.



random_seed

integer



The random seed of the command.



mousedx

integer



The mouse delta in the x direction.



mousedy

integer



The mouse delta in the y direction.



hasbeenpredicted

boolean



Whether the command has been predicted.



sendpacket

boolean



Whether the command should be sent to the server or choked.



Methods

SetViewAngles( pitch, yaw, roll )

Sets the view angles of the player.



GetViewAngles()

returns: pitch, yaw, roll



SetSendPacket( sendpacket )

Sets whether the command should be sent to the server or choked.



GetSendPacket()

returns: sendpacket



SetButtons( buttons )

Sets the buttons that are pressed.



GetButtons()

returns: buttons



SetForwardMove( float factor )

Sets the forward movement of the player.



GetForwardMove()

returns: forwardmove



SetSideMove( float factor )

Sets the sideways movement of the player.



GetSideMove()

returns: sidemove



SetUpMove( float factor )

Sets the upward movement of the player.



GetUpMove()

returns: upmove



Examples

Simple Bunny hop

local function doBunnyHop( cmd )

    local player = entities.GetLocalPlayer( );



    if (player ~= nil or not player:IsAlive()) then

    end



    if input.IsButtonDown( KEY_SPACE ) then



        local flags = player:GetPropInt( "m_fFlags" );



        if flags & FL_ONGROUND == 1 then

            cmd:SetButtons(cmd.buttons | IN_JUMP)

        else 

            cmd:SetButtons(cmd.buttons & (~IN_JUMP))

        end

    end

end



callbacks.Register("CreateMove", "myBhop", doBunnyHop)

Made with Material for MkDocs





----UserMessage

Reading

GetID()

GetDataBits()

GetDataBytes()

Reset()

ReadByte()

ReadBit()

ReadFloat( [bitLength:integer] )

ReadInt( [bitLength:integer] )

ReadString( maxlen:integer )

GetCurBit()

Writing

SetCurBit( bit:integer )

WriteBit( bit:integer )

WriteByte( byte:integer )

WriteString( str:string )

WriteInt( int:integer, [bitLength:integer] )

WriteFloat( value:number, [bitLength:integer] )

Example

UserMessage

Received as the only argument in DispatchUserMessage callback.



Reading

Reading starts at the beginning of the message (curBit = 0). Each call to Read*() advances the read cursor by the number of bits read. Reading past the end of the message will cause an error.



GetID()

Returns the ID of the message. You can get the list here: TF2 User Messages.



GetDataBits()

Returns the length of the message in bits



GetDataBytes()

Returns the length of the message in bytes



Reset()

Resets the read position to the beginning of the message. This is useful if you want to read the message multiple times, but it is not necessary. Each callback receives an already reset user message.



ReadByte()

Reads one byte from the message. Returns the byte read as first return value, and current bit position as second return value.



ReadBit()

Reads a single bit from the message. Returns the bit read as first return value, and current bit position as second return value.



ReadFloat( [bitLength:integer] )

Reads 4 bytes from the message and returns it as a float. Default bitLength is 32 (4 bytes). For short, use 16, for long, use 64. Returns the float read as first return value, and current bit position as second return value.



ReadInt( [bitLength:integer] )

Reads 4 bytes from the message and returns it as an integer. Default bitLength is 32 (4 bytes). For short, use 16, for long, use 64. Returns the integer read as first return value, and current bit position as second return value.



ReadString( maxlen:integer )

Reads a string from the message. You must specify valid maxlen. The string will be truncated if it is longer than maxlen. Returns the string read as first return value, and current bit position as second return value.



GetCurBit()

Returns the current bit position in the message.



Writing

When writing, make sure that your curBit is correct and that you do not overflow the message.



SetCurBit( bit:integer )

Sets the current bit position in the message.



WriteBit( bit:integer )

Writes a single bit to the message.



WriteByte( byte:integer )

Writes a single byte to the message.



WriteString( str:string )

Writes given string to the message.



WriteInt( int:integer, [bitLength:integer] )

Writes an integer to the message. Default bitLength is 32 (4 bytes). For short, use 16, for long, use 64.



WriteFloat( value:number, [bitLength:integer] )

Writes a float to the message. Default bitLength is 32 (4 bytes). For short, use 16, for long, use 64.



Example

Print chat messages from players

local function myCoolMessageHook(msg)



    if msg:GetID() == SayText2 then 

        msg:SetCurBit(8)-- skip 2 bytes of padding



        local chatType = msg:ReadString(256)

        local playerName = msg:ReadString(256)

        local message = msg:ReadString(256)



        print("Player " .. playerName .. " said " .. message)

    end



end



callbacks.Register("DispatchUserMessage", myCoolMessageHook)

Made with Material for MkDocs




---WeaponData


Fields

damage

bulletsPerShot

range

spread

punchAngle

timeFireDelay

timeIdle

timeIdleEmpty

timeReloadStart

timeReload

drawCrosshair

projectile

ammoPerShot

projectileSpeed

smackDelay

useRapidFireCrits

Examples

WeaponData

Contains variables related to specifications of a weapon, such as firing speed, number of projectiles, etc. Some of them may not be used, or may be wrong.



Fields

Fields are read only



damage

integer



bulletsPerShot

integer



range

number



spread

number



punchAngle

number



timeFireDelay

number



timeIdle

number



timeIdleEmpty

number



timeReloadStart

number



timeReload

number



drawCrosshair

number



projectile

integer



Represents projectile id



ammoPerShot

integer



projectileSpeed

number



smackDelay

number



useRapidFireCrits

boolean



Examples

Example usage

local function onCreateMove( cmd )

    local me = entities.GetLocalPlayer()

    if (me ~= nil) then

        local wpn = me:GetPropEntity( "m_hActiveWeapon" )

        if (wpn  ~= nil) then

            local wdt = wpn:GetWeaponData()

            print( "timeReload: " .. tostring(wdt.timeReload) )

        end

    end

end



callbacks.Register("CreateMove", onCreateMove)

Made with Material for MkDocs


---Vector3

Constructor

Vector3( x, y, z )

Fields

x

y

z

Methods

Unpack()

Length()

LengthSqr()

Length2D()

Length2DSqr()

Dot( Vector3 )

Cross( Vector3 )

Clear()

Normalize()

Right()

Up()

Angles()

Examples

Vector3

Represents a point in 3D space. X and Y are the horizontal coordinates, Z is the vertical coordinate.



Constructor

Vector3( x, y, z )

Fields

Fields are modifiable directly.



x

number



The X coordinate.



y

number



The Y coordinate.



z

number



The Z coordinate.



Methods

Unpack()

Returns the X, Y, and Z coordinates as a separate variables.



Unpack example

local myVector = Vector3( 1, 2, 3 )

local x, y, z = myVector:Unpack()

Length()

The length of the vector.



LengthSqr()

The squared length of the vector.



Length2D()

The length of the vector in 2D.



Length2DSqr()

The squared length of the vector in 2D.



Dot( Vector3 )

The dot product of the vector and the given vector.



Cross( Vector3 )

The cross product of the vector and the given vector.



Clear()

Clears the vector to 0,0,0



Normalize()

Normalizes the vector.



Right()

Returns the right vector of the vector.



Up()

Returns the up vector of the vector.



Angles()

Returns the angles of the vector.



Examples

Unpack example

local myVector = Vector3( 1, 2, 3 )

local x, y, z = myVector:Unpack()

Length example

local myVector = Vector3( 1, 2, 3 )

local length = myVector:Length()

```



Made with Material for MkDocs


---callbacks



Functions

Register( id, function )

Register( id, unique, function )

Unregister( id, unique )

Examples

callbacks

Functions

Callbacks are functions that are called when a certain event occurs. Yiu can use them to add custom functionality to your scripts. To see the list of available callbacks, see the callbacks page.



Register( id, function )

Registers a callback function to be called when the event with the given id occurs.



Register( id, unique, function )

Registers a callback function to be called when the event with the given id occurs. If the callback function is already registered, it will not be registered again.



Unregister( id, unique )

Unregisters a callback function from the event with the given id.



Examples

Made with Material for MkDocs


---client


Functions

GetExtraInventorySlots()

IsFreeTrialAccount()

HasCompetitiveAccess()

IsInCoachesList()

WorldToScreen( worldPos:Vector3 )

Command( command:string, unrestrict:bool )

ChatSay( msg:string )

ChatTeamSay( msg:string )

AllowListener( eventName:string )

GetPlayerNameByIndex( index:integer )

GetPlayerNameByUserID( userID:integer )

GetPlayerInfo( index:integer )

GetLocalPlayerIndex()

GetConVar( name:string )

SetConVar( name:string, value:any )

RemoveConVarProtection( name:string )

ChatPrintf( msg:string )

Localize ( key:string )

Examples

client

The client library is used to get information about the client.



Functions

GetExtraInventorySlots()

Returns the number of extra inventory slots the user has.



IsFreeTrialAccount()

Returns whether the user is a free trial account.



HasCompetitiveAccess()

Returns whether the user has competitive access.



IsInCoachesList()

Returns whether the user is in the coaches list.



WorldToScreen( worldPos:Vector3 )

Translate world position into screen position (x,y)



Command( command:string, unrestrict:bool )

Run command in game console



ChatSay( msg:string )

Say text on chat



ChatTeamSay( msg:string )

Say text on team chat



AllowListener( eventName:string )

DOES NOTHING. All events are allowed by default. This function is deprecated and it's only there to not cause errors in existing scripts.



GetPlayerNameByIndex( index:integer )

Return player name by index



GetPlayerNameByUserID( userID:integer )

Return player name by user id



GetPlayerInfo( index:integer )

Returns the following table:



Variable	Value

Name	playername

UserID	number

SteamID	STEAM_0:?:?

IsBot	true/false

IsHLTV	true/false

GetLocalPlayerIndex()

Return local player index



GetConVar( name:string )

Get game convar value. Returns integer, number and string if found. Returns nil if not found.



SetConVar( name:string, value:any )

Set game convar value. Value can be integer, number, string.



RemoveConVarProtection( name:string )

Remove convar protection. This is needed for convars that are not allowed to be changed by the server.



ChatPrintf( msg:string )

Print text on chat, this text can be colored. Color codes are:



\x01 - White color

\x02 - Old color

\x03 - Player name color

\x04 - Location color

\x05 - Achievement color

\x06 - Black color

\x07 - Custom color, read from next 6 characters as HEX

\x08 - Custom color with alpha, read from next 8 characters as HEX

Localize ( key:string )

Returns a localized string. The localizable strings usually start with a # character, but there are exceptions. Will return nil on failure.



Examples

Print colored chat message

if client.ChatPrintf( "\x06[\x07FF1122LmaoBox\x06] \x04You died!" ) then

    print( "Chat message sent" )

end

Get player name

local me = entities.GetLocalPlayer()

local name = entities.GetPlayerNameByIndex(me:GetIndex())

print( name )

Get player steam id

local me = entities.GetLocalPlayer()

local playerInfo = entities.GetPlayerInfo(me:GetIndex())

local steamID = playerInfo.SteamID

print( steamID )

Made with Material for MkDocs


---clientstate


Functions

ForceFullUpdate()

GetClientSignonState()

GetDeltaTick()

GetLastOutgoingCommand()

GetChokedCommands()

GetLastCommandAck()

GetConnectTime()

GetTimeSinceLastReceived()

GetLatencyIn()

GetLatencyOut()

clientstate

The clientstate library is used to get information about the internal client state.



Functions

ForceFullUpdate()

Requests a full update from the server. This can lag the game a bit and should be used sparingly. It can even cause the game to crash if used incorrectly.



GetClientSignonState()

Returns the current client signon state. This is useful for determining if the client is fully connected to the server.



GetDeltaTick()

Returns the tick number of the last received tick.



GetLastOutgoingCommand()

Returns the last outgoing command number.



GetChokedCommands()

Returns the number of commands the client is currently choking.



GetLastCommandAck()

Returns the last command acknowledged by the server.



GetConnectTime()

Returns the time the client connected to the server.



GetTimeSinceLastReceived()

Returns the time since the last tick was received.



GetLatencyIn()

Returns the incoming latency.



GetLatencyOut()

Returns the outgoing latency.



Made with Material for MkDocs


---draw

Functions

Color( r, g, b, a )

Line( x1, y1, x2, y2 )

FilledRect( x1, y1, x2, y2 )

OutlinedRect( x1, y1, x2, y2 )

GetTextSize( string )

Text( x:integer, y:integer, text:string )

TextShadow( x:integer, y:integer, text:string )

GetScreenSize()

CreateFont( name:string, height:integer, weight:integer, [fontFlags:integer] )

AddFontResource( pathTTF:string )

SetFont( font:integer )

Textures

CreateTexture( imagePath:string )

CreateTextureRGBA( rgbaBinaryData:string, width:integer, height:integer )

GetTextureSize( textureId:integer )

TexturedRect( textureId:integer, x1:integer, y1:integer, x2:integer, y2:integer)

DeleteTexture( textureId:integer )

Examples

draw

Functions

Color( r, g, b, a )

Set color for drawing shapes and texts



Line( x1, y1, x2, y2 )

Draw line from x1, y1 to x2, y2



FilledRect( x1, y1, x2, y2 )

Draw filled rectangle with top left point at x1, y1 and bottom right point at x2, y2



OutlinedRect( x1, y1, x2, y2 )

Draw outlined rectangle with top left point at x1, y1 and bottom right point at x2, y2



GetTextSize( string )

returns: width, height Get text size with current font



Text( x:integer, y:integer, text:string )

Draw text at x, y



TextShadow( x:integer, y:integer, text:string )

Draw text with shadow at x, y



GetScreenSize()

returns: width, height Get game resolution settings



CreateFont( name:string, height:integer, weight:integer, [fontFlags:integer] )

Create font by name. Font flags are optional and can be combined with bitwise OR. Default font flags are FONTFLAG_CUSTOM | FONTFLAG_ANTIALIAS



AddFontResource( pathTTF:string )

Add font resource by path to ttf file, relative to Team Fortress 2 folder



SetFont( font:integer )

Set current font for drawing. To be used with DrawText



Textures

When creating textures, you should make sure each size is a valid power of 2. Otherwise, the texture will be scaled to the nearest larger power of 2 and look weird.



CreateTexture( imagePath:string )

Create texture from image on the given path. Path is relative to %localappdata%.. But you can also specify an absolute path if you wish. Returns texture id for the newly created texture. Supported image extensions: PNG, JPG, BMP, TGA, VTF



CreateTextureRGBA( rgbaBinaryData:string, width:integer, height:integer )

Create texture from raw rgba data in the format RGBA8888 (one byte per color). In this format you must specify the valid width and height of the texture. Returns texture id for the newly created texture.



GetTextureSize( textureId:integer )

Returns: width, height of the texture as integers



TexturedRect( textureId:integer, x1:integer, y1:integer, x2:integer, y2:integer)

Draw the texture by textureId as a rectangle with top left point at x1, y1 and bottom right point at x2, y2.



DeleteTexture( textureId:integer )

Delete texture by textureId from memory. You should do this when unloading your script.



Examples

Draw an image

local lmaoboxTexture = draw.CreateTexture( "lmaobox.png" ) -- in %localappdata% folder



callbacks.Register("Draw", function()

    local w, h = draw.GetScreenSize()

    local tw, th = draw.GetTextureSize( lmaoboxTexture )



    draw.TexturedRect( lmaoboxTexture, w/2 - tw/2, h/2 - th/2, w/2 + tw/2, h/2 + th/2 )

end)

Add font resource

draw.AddFontResource("Choktoff.ttf") -- In Team Fortress 2 folder

local myfont = draw.CreateFont("Choktoff", 15, 800, FONTFLAG_CUSTOM | FONTFLAG_ANTIALIAS)

Drawing a white square with lines

local function doDraw()

    if engine.Con_IsVisible() or engine.IsGameUIVisible() then

        return

    end



    draw.Color(255, 255, 255, 255)

    draw.Line(100, 100, 100, 200)

    draw.Line(100, 200, 200, 200)

    draw.Line(200, 200, 200, 100)

    draw.Line(200, 100, 100, 100)

end



callbacks.Register("Draw", "mydraw", doDraw)

Made with Material for MkDocs

---engine

Functions

Con_IsVisible()

IsGameUIVisible()

IsTakingScreenshot()

TraceLine( src:Vector3, dst:Vector3, mask:integer, [shouldHitEntity(ent:Entity, contentsMask:integer):Function] )

TraceHull( src:Vector3, dst:Vector3, mins:Vector3, maxs:Vector3, mask:integer, [shouldHitEntity(ent:Entity, contentsMask:integer):Function] )

GetPointContents( x:number, y:number, z:number )

GetMapName()

GetServerIP()

GetViewAngles()

SetViewAngles( angles:EulerAngles )

PlaySound( soundPath:string )

GetGameDir()

SendKeyValues( keyValues:string )

Notification( title:string, [longText:string] )

RandomSeed( seed:integer )

RandomFloat( min:number, [max:number = 1] )

RandomInt( min:integer, [max:integer = 0x7FFF] )

RandomFloatExp( min:number, max:number, [exponent:number = 1] )

Examples

engine

The engine library provides access to the game's core functionality.



Functions

Con_IsVisible()

Whether the game console is visible.



IsGameUIVisible()

Whether the game UI is visible.



IsTakingScreenshot()

Whether the game is taking a screenshot.



TraceLine( src:Vector3, dst:Vector3, mask:integer, [shouldHitEntity(ent:Entity, contentsMask:integer):Function] )

Traces line from src to dst, returns Trace class. The shouldHitEntity function is optional, and can be used to filter out entities that should not be hit. It should return true if the entity should be hit, and false otherwise.



TraceHull( src:Vector3, dst:Vector3, mins:Vector3, maxs:Vector3, mask:integer, [shouldHitEntity(ent:Entity, contentsMask:integer):Function] )

Traces hull from src to dst, returns Trace class. The shouldHitEntity function is optional, and can be used to filter out entities that should not be hit. It should return true if the entity should be hit, and false otherwise.



GetPointContents( x:number, y:number, z:number )

Checks if given point is inside wall, returns contents



GetMapName()

Returns map name



GetServerIP()

Returns server ip



GetViewAngles()

Returns player view angles



SetViewAngles( angles:EulerAngles )

Sets player view angles



PlaySound( soundPath:string )

Plays a sound at the given path, relative to the game's root folder



GetGameDir()

Returns game install directory



SendKeyValues( keyValues:string )

Sends key values to server, returns true if successful, this can be used to send very specific commands to the server. For example, buy MvM upgrades, trigger noise makers...



Notification( title:string, [longText:string] )

Creates a notification in the TF2 client. If longText is not specified, the notification will be a simple popup with title text. If longText is specified, the notification will be a popup with title text, which will open a large window with longText as text.



RandomSeed( seed:integer )

Sets the seed for the game's uniform random number generator.



RandomFloat( min:number, [max:number = 1] )

Returns a random number between min and max (inclusive), using the game's uniform random number generator.



RandomInt( min:integer, [max:integer = 0x7FFF] )

Returns a random integer between min and max (inclusive), using the game's uniform random number generator.



RandomFloatExp( min:number, max:number, [exponent:number = 1] )

Returns a random number between min and max using the exponent, using the game's uniform random number generator.



Examples

Trigger noise maker without using a charge

local kv = [[

    "use_action_slot_item_server"

    {

    }

]]



engine.SendKeyValues( kv )

What am I looking at?

local me = entities.GetLocalPlayer();

local source = me:GetAbsOrigin() + me:GetPropVector( "localdata", "m_vecViewOffset[0]" );

local destination = source + engine.GetViewAngles():Forward() * 1000;



local trace = engine.TraceLine( source, destination, MASK_SHOT_HULL );



if (trace.entity ~= nil) then

    print( "I am looking at " .. trace.entity:GetClass() );

    print( "Distance to entity: " .. trace.fraction * 1000 );

end

TraceLine with custom trace filter

local trace = engine.TraceLine( source, destination, MASK_SHOT_HULL, function ( entity, contentsMask )

        if ( entity:GetClass() == "CTFPlayer" ) then

            return true;

        end



        print("Entity: " .. entity:GetClass() .. " is not a player")

        return false;

    end );

Made with Material for MkDocs



Skip to content

entities

Search


Functions

FindByClass( className:string )

GetLocalPlayer()

GetByIndex( index:integer )

GetByUserID( userID:integer )

GetPlayerResources()

Examples

entities

The entities library provides a way to find entities by their name, or by their class.



Functions

FindByClass( className:string )

Find and put into table all entities with given class name



GetLocalPlayer()

Return local player entity



GetByIndex( index:integer )

Return entity by index



GetByUserID( userID:integer )

Return entity by user id



GetPlayerResources()

Return player resources entity



Examples

What is my name?

local me = entities.GetLocalPlayer()

local name = me:GetName()

print( name )

Find all players

local players = entities.FindByClass("CTFPlayer")



for i, player in ipairs(players) do

    print( player:GetName() )

end

Find all entities in the game

for i = 1, 8192 do -- index 1 is world entity

    local entity = entities.GetByIndex( i )

    if entity then

        print( i, entity:GetClass() )

    end

end

Made with Material for MkDocs



Skip to content

filesystem

Search


Functions

CreateDirectory( string:path )

EnumerateDirectory( string:path, function( filename:string, attributes:integer ) )

GetFileTime( string:path )

GetFileAttributes( string:path )

SetFileAttributes( string:path, integer:attributes )

Examples

filesystem

This library provides a simple interface to the filesystem.



Functions

CreateDirectory( string:path )

Creates a directory at the specified relative or absolute path. Returns true if the directory was created, false if unsuccessful.



EnumerateDirectory( string:path, function( filename:string, attributes:integer ) )

Enumerates the files and directories in the specified directory. The callback function receives the filename and attributes of each file or directory. The path is relative to the game directory or absolute. You are not allowed to enumerate outside of the game directory.



GetFileTime( string:path )

Returns 3 return values: the creation time, the last access time, and the last write time of the file at the specified path.



GetFileAttributes( string:path )

Returns the attributes of the file at the specified path.



SetFileAttributes( string:path, integer:attributes )

Sets the attributes of the file at the specified path.



Examples

Create a directory inside the 'Team Fortress 2' directory

filesystem.CreateDirectory( [[myContent]] )

Enumerate every file in the tf/ directory

filesystem.EnumerateDirectory( [[tf/*]] , function( filename, attributes )

 print( filename, attributes )

end )

Made with Material for MkDocs



Skip to content

gamecoordinator

Search


Functions

ConnectedToGC()

InEndOfMatch()

HasLiveMatch()

IsConnectedToMatchServer()

AbandonMatch()

GetMatchAbandonStatus()

GetDataCenterPingData()

GetNumMatchInvites()

AcceptMatchInvites()

JoinMatchmakingMatch()

EnumerateQueueMapsHealth( function( MatchMapDefinition, number ) ) )

GetGameServerLobby()

Examples

gamecoordinator

The gamecoordinator library provides information about the state of the matchmaking system and current match made game.



Functions

ConnectedToGC()

Returns true if the player is connected to the game coordinator.



InEndOfMatch()

Returns true if the player is in the end of match phase.



HasLiveMatch()

Returns true if the player is assigned to a live match.



IsConnectedToMatchServer()

Returns true if the player is connected to the assigned match server.



AbandonMatch()

Abandons the current match and forcefully disconnects the player from the match server.



GetMatchAbandonStatus()

Returns the status of the match relative to the player connection.



GetDataCenterPingData()

Returns the ping data for all available data centers in a table. Table example:



DataCenter	Ping

syd	35

GetNumMatchInvites()

Returns the number of match invites the player has.



AcceptMatchInvites()

Accepts all match invites the player has. Usually it's just one, and they are automatically accepted after some time anyway so you can selectively accept them. Accepting an invite does not immediately join you into the match.



JoinMatchmakingMatch()

Joins the match the player is currently assigned to from the previously acccepted match invite. This is usually called after accepting a match invite if the player wants to join the match. If not, call AbandonMatch() to leave the match.



EnumerateQueueMapsHealth( function( MatchMapDefinition, number ) ) )

Enumerates the maps in the queue and calls the callback function for each map. The callback function receives the MatchMapDefinition and the health of the map represented as a number from 0 to 1. You must receive the GameCoordinator's map health update at least once to use this function (i.e. by queueing up).



GetGameServerLobby()

Returns the GameServerLobby object for the current match or nil if the player is not in a match.



Examples

Select cp_dustbowl map and print all selected maps

gamecoordinator.EnumerateQueueMapsHealth( function( map, health )



    if map:GetName() == "cp_dustbowl" then

        party.SetCasualMapSelected( map, true )

    end



    if party.IsCasualMapSelected( map ) then

        print( "Selected: " .. map:GetName() .. ": " .. tostring(health) )

    end



end )

Made with Material for MkDocs



Skip to content

gamerules

Search


Functions

IsMatchTypeCasual()

IsMatchTypeCompetitive()

IsManagedMatchEnded()

GetTimeLeftInMatch()

IsTruceActive()

IsMvM()

GetCurrentMatchGroup()

IsUsingGrapplingHook()

IsUsingSpells()

GetCurrentNextMapVotingState()

GetPlayerVoteState ( playerIndex:integer )

GetRoundState()

Examples

gamerules

The gamerules library contains functions for detecting the game rules of a TF2 match.



Functions

IsMatchTypeCasual()

Returns true if the match is a casual match.



IsMatchTypeCompetitive()

Returns true if the match is a competitive match.



IsManagedMatchEnded()

Returns true if the matchmaking match has ended.



GetTimeLeftInMatch()

Returns the time left in the match.



IsTruceActive()

When truce is active, players cannot attack each other.



IsMvM()

Returns true if the current match is a MvM game.



GetCurrentMatchGroup()

Returns the current match group.



IsUsingGrapplingHook()

Returns true if current gamemode allows players to use the grappling hook.



IsUsingSpells()

Returns true if current gamemode allows players to use spells.



GetCurrentNextMapVotingState()

Returns the current next map voting state.



GetPlayerVoteState ( playerIndex:integer )

Returns the vote state of the player with the given index.



GetRoundState()

Returns the current state of the round as integer.



State	Meaning

0	ROUND_INIT

1	ROUND_PREGAME

2	ROUND_STARTGAME

3	ROUND_PREROUND

4	ROUND_RUNNING

5	ROUND_TEAMWIN

6	ROUND_RESTART

7	ROUND_STALEMATE

8	ROUND_GAMEOVER

9	ROUND_BONUS

10	ROUND_BETWEEN_ROUNDS

Examples

Prevent player from attacking during Truce

local function onCreateMove( cmd )

    if gamerules.IsTruceActive() then

        cmd.buttons = cmd.buttons & ~IN_ATTACK

    end

end



callbacks.Register("CreateMove", onCreateMove)

Made with Material for MkDocs



Skip to content

globals

Search


Functions

TickInterval()

TickCount()

RealTime()

CurTime()

FrameCount()

FrameTime()

AbsoluteFrameTime()

MaxClients()

Examples

globals

This library contains global source engine variables.



Functions

TickInterval()

Returns server tick interval



TickCount()

Returns client tick count



RealTime()

Returns the time since start of the game



CurTime()

Returns the current time



FrameCount()

Returns the frame count



FrameTime()

Return delta time between frames



AbsoluteFrameTime()

Return delta time between frames



MaxClients()

Max player count of the current server



Examples

FPS Counter - by x6h

local consolas = draw.CreateFont("Consolas", 17, 500)

local current_fps = 0



local function watermark()

  draw.SetFont(consolas)

  draw.Color(255, 255, 255, 255)



  -- update fps every 100 frames

  if globals.FrameCount() % 100 == 0 then

    current_fps = math.floor(1 / globals.FrameTime())

  end



  draw.Text(5, 5, "[lmaobox | fps: " .. current_fps .. "]")

end



callbacks.Register("Draw", "draw", watermark)

-- https://github.com/x6h

Made with Material for MkDocs



Skip to content

gui

Search


Functions

GetValue( msg:string )

SetValue( msg:string, index:integer )

SetValue( msg:string, msg:string )

Examples

gui

Functions

GetValue( msg:string )

Get current value of a setting



SetValue( msg:string, index:integer )

Set current Integer value of a setting



SetValue( msg:string, msg:string )

Set current Text value of a setting



Examples

Set aimbot settings

gui.SetValue("aim bot", 1);

gui.SetValue("aim method", "silent");



local aim_method = gui.GetValue("aim method");

print( aim_method ) -- prints 'silent'

Get current aimbot fov

local aim_fov = gui.GetValue("aim fov");

print( aim_fov )

Change ESP color for blue team

gui.SetValue("blue team color", 0xcaffffff)

Made with Material for MkDocs



Skip to content

input

Search


Functions

GetMousePos()

IsButtonDown( button:integer )

IsButtonPressed( button:integer )

IsButtonReleased( button:integer )

IsMouseInputEnabled()

SetMouseInputEnabled( enabled:bool )

GetPollTick()

Examples

input

The input library provides an interface to the user's keyboard and mouse.



Functions

GetMousePos()

Returns the current mouse position as a table where index 1 is x and index 2 is y.



IsButtonDown( button:integer )

Returns true if the specified mouse button is down. Otherwise, it returns false.



IsButtonPressed( button:integer )

Returns true if the specified mouse button was pressed. Otherwise, it returns false. Second return value is the tick when button was pressed.



IsButtonReleased( button:integer )

Returns true if the specified mouse button was released. Otherwise, it returns false. Second return value is the tick when button was released.



IsMouseInputEnabled()

Returns whether the mouse input is currently enabled.



SetMouseInputEnabled( enabled:bool )

Sets whether the mouse is visible on screen and has priority on the topmost panel.



GetPollTick()

Returns the tick when buttons have last been polled.



Examples

Attack when user presses E

local function onCreateMove( cmd )

    if input.IsButtonDown( KEY_E ) then

        cmd.buttons = cmd.buttons | IN_ATTACK

    end

end



callbacks.Register( "CreateMove", onCreateMove )

Made with Material for MkDocs



Skip to content

inventory

Search


Functions

Enumerate( callback:function( item ) )

GetItemByPosition( position:integer )

GetMaxItemCount()

GetItemByItemID( itemID:integer )

GetItemInLoadout( classid:integer, slot:integer )

EquipItemInLoadout( item:Item, classid:integer, slot:integer )

CreateFakeItem( itemdef:ItemDefinition, pickupOrPosition:integer, itemID64:integer, quality:integer, origin:integer, level:integer, isNewItem:bool )

inventory

The inventory library is used to access the player's inventory and the items in it. Every item is of type Item.



Functions

Enumerate( callback:function( item ) )

Callback is called for each item in the inventory. The item is passed as the first argument and is of type Item.



GetItemByPosition( position:integer )

Returns the item at the given position in the inventory.



GetMaxItemCount()

Returns the maximum number of items that can be in the inventory.



GetItemByItemID( itemID:integer )

Returns the item with the given 64bit item ID.



GetItemInLoadout( classid:integer, slot:integer )

Returns the item that is in the given slot in the given class' loadout slot.



EquipItemInLoadout( item:Item, classid:integer, slot:integer )

Equips the item that is in the given slot in the given class' loadout slot. The item is of type Item



CreateFakeItem( itemdef:ItemDefinition, pickupOrPosition:integer, itemID64:integer, quality:integer, origin:integer, level:integer, isNewItem:bool )

Creates a fake item with the given parameters. The item definition is of type ItemDefinition. The pickupOrPosition parameter is the pickup method, if isNewItem parameter is true, and the inventory position of the item if isNewItem parameter is false. The itemID64 is the unique 64bit item ID of the item, you can use -1 to generate a random ID. For quality and origin you can use constants. The level is the item's level.



Made with Material for MkDocs



Skip to content

itemschema

Search


Functions

GetItemDefinitionByID( id:integer )

GetItemDefinitionByName( name:string )

Enumerate( callback:function(itemDefinition) )

GetAttributeDefinitionByName( name:string )

EnumerateAttributes( callback:function(attributeDefinition) )

Examples

itemschema

The itemschema library contains functions for retrieving information about items. Items referred to in this library are of the ItemDefinition type.



Functions

GetItemDefinitionByID( id:integer )

Returns the item definition for the item with the given ID.



GetItemDefinitionByName( name:string )

Returns the item definition for the item with the given name.



Enumerate( callback:function(itemDefinition) )

Enumerates all item definitions, calling the callback for each one.



GetAttributeDefinitionByName( name:string )

Returns the attribute definition for the item with the given name.



EnumerateAttributes( callback:function(attributeDefinition) )

Enumerates all attribute definitions, calling the callback for each one.



Examples

Get player's weapon name

local activeWeapon = entities.GetLocalPlayer():GetPropEntity("m_hActiveWeapon")

local wpnId = activeWeapon:GetPropInt("m_iItemDefinitionIndex")

if wpnId ~= nil then

    local wpnName = itemschema.GetItemDefinitionByID(wpnId):GetName()

    draw.TextShadow(screenPos[1], screenPos[2], wpnName)

end

Find all hats and cosmetics

local function forEveryItem( itemDefinition )

    if itemDefinition:IsWearable() then

        print( "Found: " .. itemDefinition:GetName() )

    end

end



itemschema.Enumerate( forEveryItem )

Made with Material for MkDocs



Skip to content

materials

Search


Functions

Find( name:string )

Enumerate( callback( mat ) )

Create( name:string, vmt:string )

Examples

materials

The materials library provides a way to create and alter materials for rendering.



Functions

Find( name:string )

Find a material by name



Enumerate( callback( mat ) )

Enumerate all loaded materials and call the callback function for each one. The only argument in the callback is the Material object.



Create( name:string, vmt:string )

Create custom material following the Valve Material Type syntax. VMT should be a string containing the full material definition. Name should be an unique name of the material.



Examples

Create white material

kv = [["UnlitGeneric"

{

    "$basetexture"  "vgui/white_additive"

    "$ignorez" "1"

    "$model" "1"

}

]]



myMaterial = materials.Create( "myMaterial", kv )

Find materials that have 'wood' in name

local function forEveryMaterial( material )

    if string.find( material:GetName(), "wood" ) then

        print( "Found material: " .. material:GetName() )

    end

end



materials.Enumerate( forEveryMaterial )

Made with Material for MkDocs



Skip to content

party

Search


Functions

GetLeader()

GetMembers()

GetPendingMembers()

GetGroupID()

GetQueuedMatchGroups()

GetAllMatchGroups()

Leave()

CanQueueForMatchGroup( matchGroup:MatchGroup )

QueueUp( matchGroup:MatchGroup )

CancelQueue( matchGroup:MatchGroup )

IsInStandbyQueue()

CanQueueForStandby()

QueueUpStandby()

CancelQueueStandby()

GetMemberActivity( index:integer )

PromoteMemberToLeader( steamid:string )

KickMember( steamid:string )

IsCasualMapSelected( map:MatchMapDefinition )

SetCasualMapSelected( map:MatchMapDefinition, selected:bool )

Examples

party

The party library provides functions for managing the player's matchmaking party. All functions return nil if the player is not in a party or the party client is not initialized.



Functions

GetLeader()

Returns the player's party leader's SteamID as string.



GetMembers()

Returns a table containing the player's party members' SteamIDs as strings.



Key Index	Value

1	STEAM_0:?:?

GetPendingMembers()

Returns a table containing the player's pending party members' SteamIDs as strings. These members are invited to party, but have not joined yet.



GetGroupID()

Returns the player's party's group ID.



GetQueuedMatchGroups()

Returns a table where values are the player's queued match groups as MatchGroup objects.



Key	Value

Casual	MatchGroup object

GetAllMatchGroups()

Returns a table where values are all possible match groups as MatchGroup objects.



Key	Value

Casual	MatchGroup object

Leave()

Leaves the current party.



CanQueueForMatchGroup( matchGroup:MatchGroup )

Returns true if the player can queue for the given match group. If the player can not queue for the match groups, returns a table of reasons why the player can not queue.



Key	Value

1	Select at least one Mission in order to queue.

QueueUp( matchGroup:MatchGroup )

Requests to queue up for a match group.



CancelQueue( matchGroup:MatchGroup )

Cancles the request to queue up for a match group.



IsInStandbyQueue()

Whether the player is in the standby queue. That refers to queueing up for an ongoing match in your party.



CanQueueForStandby()

Returns whether the player can queue up for a standby match. That refers to an ongoing match in your party.



QueueUpStandby()

Requests to queue up for a standby match in your party. That refers to an ongoing match in your party.



CancelQueueStandby()

Cancles the request to queue up for a standby match in your party. That refers to an ongoing match in your party.



GetMemberActivity( index:integer )

Returns a PartyMemberActivity object for the party member at the given index. See GetMembers() for the index.



PromoteMemberToLeader( steamid:string )

Promotes the given player to the party leader. Works only if you are the party leader.



KickMember( steamid:string )

Kicks the given player from the party. Works only if you are the party leader.



IsCasualMapSelected( map:MatchMapDefinition )

Returns true if the given map is selected for casual play.



SetCasualMapSelected( map:MatchMapDefinition, selected:bool )

Sets the given map as selected for casual play.



Examples

Queue up for casual

local casual = party.GetAllMatchGroups()["Casual"]



local reasons = party.CanQueueForMatchGroup( casual )



if reasons == true then

    party.QueueUp( casual )

else

    for k,v in pairs( reasons ) do

        print( v )

    end

end

Print all party members, but not the leader

local members = party.GetMembers()



for k, v in pairs( members ) do

    if v ~= party.GetLeader() then

        print( v )

    end

end

Am I in queue?

if #party.GetQueuedMatchGroups() > 0 then

    print( "I'm in queue!" )

end

Made with Material for MkDocs



Skip to content

playerlist

Search


Functions

GetPriority( player:Entity )

GetPriority( userID:number )

GetPriority( steamID:string )

SetPriority( player:Entity, priority:number )'

SetPriority( userID:number, priority:number )

SetPriority( steamID:string, priority:number )

GetColor( player:Entity )

GetColor( userID:number )

GetColor( steamID:string )

SetColor( player:Entity, color:number )

SetColor( userID:number, color:number )

SetColor( steamID:string, color:number )

Examples

playerlist

The playerlist library provides a way to retrieve values from, and customize the playerlist.



Functions

GetPriority( player:Entity )

Returns the priority of the player.



GetPriority( userID:number )

Returns the priority of the player by user ID.



GetPriority( steamID:string )

Returns the priority of the player by Steam ID.



SetPriority( player:Entity, priority:number )'

Sets the priority of the player.



SetPriority( userID:number, priority:number )

Sets the priority of the player by user ID.



SetPriority( steamID:string, priority:number )

Sets the priority of the player by Steam ID.



GetColor( player:Entity )

Returns the color of the player.



GetColor( userID:number )

Returns the color of the player by user ID.



GetColor( steamID:string )

Returns the color of the player by Steam ID.



SetColor( player:Entity, color:number )

Sets the color of the player.



SetColor( userID:number, color:number )

Sets the color of the player by user ID.



SetColor( steamID:string, color:number )

Sets the color of the player by Steam ID.



Examples

Get playerlist color by SteamID

local color = playerlist.GetColor("STEAM_0:0:123456789");

Set playerlist priority by SteamID

local priority = 1;



playerlist.SetPriority("STEAM_0:0:123456789", priority);

Made with Material for MkDocs



Skip to content

steam

Search


Functions

GetSteamID()

GetPlayerName( steamid:string )

IsFriend( steamid:string )

GetFriends()

ToSteamID64( steamid:string )

steam

The steam library provides access to basic Steam API functionality and data.



Functions

GetSteamID()

Returns SteamID of the user as string.



GetPlayerName( steamid:string )

Returns the player name of the player having the given SteamID.



IsFriend( steamid:string )

Returns true if the player is a friend of the user.



GetFriends()

Returns a table of all friends of the user.



ToSteamID64( steamid:string )

Returns the 64bit SteamID of the player as a long integer.



Made with Material for MkDocs



Skip to content

vector

Search


Functions

Add( {x,y,z}, {x,y,z} )

Subtract( {x,y,z}, {x,y,z} )

Multiply( {x,y,z}, m )

Divide( {x,y,z}, d )

Length( {x,y,z} )

LengthSqr( {x,y,z} )

Distance( {x,y,z}, {x,y,z} )

Normalize( {x,y,z} )

Angles( {pitch,yaw,roll} )

AngleForward( {pitch,yaw,roll} )

AngleRight( {pitch,yaw,roll} )

AngleUp( {pitch,yaw,roll} )

AngleNormalize( {pitch,yaw,roll} )

Examples

vector

The vector library provides a simple way to manipulate 3D vectors. You can use both Lua tables and Vector3 instances as arguments. The functions below showcase only the table-based option.



Functions

Add( {x,y,z}, {x,y,z} )

Add two vectors



Subtract( {x,y,z}, {x,y,z} )

Subtract two vectors



Multiply( {x,y,z}, m )

Multiply vector by scalar



Divide( {x,y,z}, d )

Divide vector by scalar



Length( {x,y,z} )

Get vector length



LengthSqr( {x,y,z} )

Get vector squared length



Distance( {x,y,z}, {x,y,z} )

Get distance between two vectors



Normalize( {x,y,z} )

Normalize vector



Angles( {pitch,yaw,roll} )

Get vector angles



AngleForward( {pitch,yaw,roll} )

Get forward vector angle



AngleRight( {pitch,yaw,roll} )

Get right vector angle



AngleUp( {pitch,yaw,roll} )

Get up vector angle



AngleNormalize( {pitch,yaw,roll} )

Normalize vector angles



Examples

Arithmetic example

local vec = vector.Add( Vector3( 1, 2, 3 ), {4, 5, 6} )

local vec = vector.Subtract( {10, 20, 30}}, {4, 5, 6} )

Made with Material for MkDocs



Skip to content

warp

Search


Functions

GetChargedTicks()

IsWarping()

CanWarp()

CanDoubleTap( weapon:Entity )

TriggerWarp()

TriggerDoubleTap()

TriggerCharge()

Examples

warp

This library can be used for interacting with the warp exploit feature of TF2. How it works:



You can charge up ticks to later on send to server in a batch, which will execute them all at once, it behaves like a small speedhack, a warp.



Warping results in a small dash in the direction you are running in.



Warping while shooting results in weapons speeding up their reload times -> some weapons can shoot twice - a double tap.



Functions

GetChargedTicks()

Returns the amount of charged warp ticks.



IsWarping()

Returns true if the user is currently warping. Since the period of warping is super short, this is only really useful in CreateMove callbacks where you can use it to do your logic.



CanWarp()

Whether we can warp or not. Does not guarantee a full charge or a double tap.



CanDoubleTap( weapon:Entity )

Extension of CanWarp with additional checks. When this is true, you can guarentee a weapon will double tap.



TriggerWarp()

Triggers a warp.



TriggerDoubleTap()

Triggers a warp with double tap.



TriggerCharge()

Triggers a charge of warp ticks.



Examples

local function onCreateMove(cmd)

    local me = entities.GetLocalPlayer()

    if me ~= nil then

        local wpn = me:GetPropEntity( "m_hActiveWeapon" )

        if wpn  ~= nil then

            local canDt = warp.CanDoubleTap(wpn)

            if oldCanDt ~= canDt and canDt == true then

                engine.PlaySound( "player/recharged.wav" )

            end

            oldCanDt = canDt

        end

    end

end

callbacks.Register("CreateMove", onCreateMove)

Made with Material for MkDocs


Examples

Play a sound when weapon can double tap

local function onCreateMove( cmd )

    local me = entities.GetLocalPlayer()

    if e ~= nil then

        local wpn = me:GetPropEntity( "m_hActiveWeapon" )

        if wpn  ~= nil then



            local canDt = warp.CanDoubleTap(wpn)



            if oldCanDt ~= canDt and canDt == true then

                engine.PlaySound( "player/recharged.wav" )

            end



            oldCanDt = canDt

        end

    end

end



callbacks.Register("CreateMove", onCreateMove)

Made with Material for MkDocs



// This code prints the number of frames per second on the screen.

// It does this by getting the current frame count and dividing it by the time it took to render the last frame.

// The result is then rounded down to the nearest integer and printed to the screen.

// The code is executed every time the Draw event is triggered.

local consolas = draw.CreateFont("Consolas", 17, 500)

local current_fps = 0

local function watermark()

  draw.SetFont(consolas)

  draw.Color(255, 255, 255, 255)

  // update fps every 100 frames

  if globals.FrameCount() % 100 == 0 then

    current_fps = math.floor(1 / globals.FrameTime())

  end

  draw.Text(5, 5, "[lmaobox | fps: " .. current_fps .. "]")

end

callbacks.Register("Draw", "draw", watermark)


About

The Lua API for TF2 is still in development, but it is ready to be used.

If you find bugs, have suggestion, have a problem or want to contribute then feel free to discuss it in our dedicated Telegram group

If you develop your scripts in Visual Studio Code, then you can use a helpful snippet addon lmaobox LUA API snippets made by @RC.

Learning Lua

You can start learning Lua by following the friendly tutorial made by Garry's Mod developers:

Garry's Mod Lua Tutorial.

Or any of the following guides for example:

Lua.org Tutorial

Tutorialspoint Tutorial

How to start

Make sure you're using the beta version of Lmaobox (run your loader with -beta parameter)

Read the documentation to learn how to use the API to create scripts

Execute your scripts:

a) Put your Lua scripts in your %localappdata% folder and execute them using:

lua_load myScript.lua

b) Execute Lua directly in console using:

lua print( "Hello World" )

Top Examples

FPS Counter - by x6h

local consolas = draw.CreateFont("Consolas", 17, 500)

local current_fps = 0

local function watermark()

  draw.SetFont(consolas)

  draw.Color(255, 255, 255, 255)

  -- update fps every 100 frames

  if globals.FrameCount() % 100 == 0 then

    current_fps = math.floor(1 / globals.FrameTime())

  end

  draw.Text(5, 5, "[lmaobox | fps: " .. current_fps .. "]")

end

callbacks.Register("Draw", "draw", watermark)

-- https://github.com/x6h

Damage logger - by @RC

local function damageLogger(event)

    if (event:GetName() == 'player_hurt' ) then

        local localPlayer = entities.GetLocalPlayer();

        local victim = entities.GetByUserID(event:GetInt("userid"))

        local health = event:GetInt("health")

        local attacker = entities.GetByUserID(event:GetInt("attacker"))

        local damage = event:GetInt("damageamount")

        if (attacker == nil or localPlayer:GetIndex() ~= attacker:GetIndex()) then

            return

        end

        print("You hit " ..  victim:GetName() .. " or ID " .. victim:GetIndex() .. " for " .. damage .. "HP they now have " .. health .. "HP left")

    end

end

callbacks.Register("FireGameEvent", "exampledamageLogger", damageLogger)

-- Made by @RC

Basic player ESP

local myfont = draw.CreateFont( "Verdana", 16, 800 )

local function doDraw()

    if engine.Con_IsVisible() or engine.IsGameUIVisible() then

        return

    end

    local players = entities.FindByClass("CTFPlayer")

    for i, p in ipairs( players ) do

        if p:IsAlive() and not p:IsDormant() then

            local screenPos = client.WorldToScreen( p:GetAbsOrigin() )

            if screenPos ~= nil then

                draw.SetFont( myfont )

                draw.Color( 255, 255, 255, 255 )

                draw.Text( screenPos[1], screenPos[2], p:GetName() )

            end

        end

    end

end

callbacks.Register("Draw", "mydraw", doDraw)



Based on that can you make simple script that gets info about enemy look 