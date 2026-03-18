-- Bot helper by __null

-- Settings:
-- Trigger symbol. All commands should start with this symbol.
local triggerSymbol = "!";

-- Process messages only from lobby owner.
local lobbyOwnerOnly = true;

-- Constants
local k_eTFPartyChatType_MemberChat = 1;
local steamid64Ident = 76561197960265728;
local partyChatEventName = "party_chat";
local availableClasses = { "scout", "soldier", "pyro", "demoman", "heavy", "engineer", "medic", "sniper", "spy" };
local availableAttackActions = { "start", "stop" };
local medigunTypedefs = {
    default = { 29, 211, 663, 796, 805, 885, 894, 903, 912, 961, 970 },
    quickfix = { 411 },
    kritz = { 35 }
};

-- Command container
local commands = {};

-- Found mediguns in inventory.
local foundMediguns = {
    default = -1,
    quickfix = -1,
    kritz = -1
};

-- Helper method that converts SteamID64 to SteamID3
local function SteamID64ToSteamID3(steamId64)
    return "[U:1:" .. steamId64 - steamid64Ident .. "]";
end

-- Thanks, LUA!
local function SplitString(input, separator)
    if separator == nil then
        separator = "%s";
    end

    local t = {};
    
    for str in string.gmatch(input, "([^" .. separator .. "]+)") do
            table.insert(t, str);
    end
    
    return t;
end

-- Helper that sends a message to party chat
local function Respond(input)
    client.Command("say_party " .. input, true);
end

-- Helper that checks if table contains a value
function Contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true;
        end
    end

    return false;
end

-- Game event processor
local function FireGameEvent(event)
    -- Validation.
    -- Checking if we've received a party_chat event.
    if event:GetName() ~= partyChatEventName then
        return;
    end

    -- Checking a message type. Should be k_eTFPartyChatType_MemberChat.
    if event:GetInt("type") ~= k_eTFPartyChatType_MemberChat then
        return;
    end

    local partyMessageText = event:GetString("text");

    -- Checking if message starts with a trigger symbol.
    if string.sub(partyMessageText, 1, 1) ~= triggerSymbol then
        return;
    end

    if lobbyOwnerOnly then
        -- Validating that message sender actually owns this lobby
        local senderId = SteamID64ToSteamID3(event:GetString("steamid"));

        if party.GetLeader() ~= senderId then
            return;
        end
    end

    -- Parsing the command
    local fullCommand = string.sub(partyMessageText, 2, #partyMessageText);
    local commandArgs = SplitString(fullCommand);

    -- Validating if we know this command
    local commandName = commandArgs[1];
    local commandCallback = commands[commandName];

    if commandCallback == nil then
        Respond("Unknown command [" .. commandName .. "]");
        return;
    end

    -- Removing command name
    table.remove(commandArgs, 1);

    -- Calling callback
    commandCallback(commandArgs);
end

-- ============= Commands' section ============= --
local function KillCommand(args)
    client.Command("kill", true);
    Respond("Killed myself.");
end

local function ExplodeCommand(args)
    client.Command("explode", true);
    Respond("Boom!");
end

local function SwitchWeapon(args)
    local slotStr = args[1];

    if slotStr == nil then
        Respond("Usage: " .. triggerSymbol .. "slot <slot number>");
        return;
    end

    local slot = tonumber(slotStr);

    if slot == nil then
        Respond("Unknown slot [" .. slotStr .. "]. Available are 0-10.");
        return;
    end

    if slot < 0 or slot > 10 then
        Respond("Unknown slot [" .. slotStr .. "]. Available are 0-10.");
        return;
    end

    Respond("Switched weapon to slot [" .. slot .. "]");
    client.Command("slot" .. slot, true);
end

local function SwitchClass(args)
    local class = args[1];

    if class == nil then
        Respond("Usage: " .. triggerSymbol .. "class <" .. table.concat(availableClasses, ", ") .. ">");
        return;
    end

    if not Contains(availableClasses, class) then
        Respond("Unknown class [" .. class .. "]");
        return;
    end

    if class == "heavy" then
        -- Wtf Valve
        class = "heavyweapons";
    end

    Respond("Switched to [" .. class .. "]");
    client.Command("join_class " .. class, true);
end

local function Say(args)
    local msg = args[1];

    if msg == nil then
        Respond("Usage: " .. triggerSymbol .. "say <text>");
        return;
    end

    client.Command("say " .. msg, true);
end

local function SayTeam(args)
    local msg = args[1];

    if msg == nil then
        Respond("Usage: " .. triggerSymbol .. "say_team <text>");
        return;
    end
    
    client.Command("say_team " .. msg, true);
end

local function SayParty(args)
    local msg = args[1];

    if msg == nil then
        Respond("Usage: " .. triggerSymbol .. "say_party <text>");
        return;
    end

    client.Command("say_party " .. msg, true);
end

local function Taunt(args)
    client.Command("taunt", true);
end

local function TauntByName(args)
    local firstArg = args[1];

    if firstArg == nil then
        Respond("Usage: " .. triggerSymbol .. "tauntn <Full taunt name>.");
        Respond("For example: " .. triggerSymbol .. "tauntn Taunt: The Schadenfreude");
        return;
    end

    local fullTauntName = table.concat(args, " ");
    client.Command("taunt_by_name " .. fullTauntName, true);
end

local function Attack(args)
    local action = args[1];
    local buttonStr = args[2];

    if action == nil or buttonStr == nil then
        Respond("Usage: " .. triggerSymbol .. "attack <" .. table.concat(availableAttackActions, ", ") .. "> <button (1-3)>");
        return;
    end

    if not Contains(availableAttackActions, action) then
        Respond("Unknown attack option. Available options are: <" .. table.concat(availableAttackActions, ", ") .. ">");
        return;
    end

    local button = tonumber(buttonStr);

    if button == nil then
        Respond("Button is not valid. Available options are: 1-3");
        return;
    end

    if button < 0 or button > 3 then
        Respond("Button is not valid. Available options are: 1-3");
        return;
    end

    local modifier = "+";

    if action == "stop" then
        modifier = "-";
    end

    if button == 1 then
        client.Command(modifier .. "attack", true);
    else
        client.Command(modifier .. "attack" .. button, true);
    end
end
-- ============= End of commands' section ============= --

-- This method is an inventory enumerator. Used to search for mediguns in the inventory.
local function EnumerateInventory(item)
    -- Broken for now. Will fix later.

    local itemName = item:GetName();
    local itemDefIndex = item:GetDefIndex();

    if Contains(medigunTypedefs.default, itemDefIndex) then
        -- We found a default medigun.
        --foundMediguns.default = item:GetItemId();
        local id = item:GetItemId();
    end

    if Contains(medigunTypedefs.quickfix, itemDefIndex) then
        -- We found a quickfix.
        -- foundMediguns.quickfix = item:GetItemId();
        local id = item:GetItemId();
    end

    if Contains(medigunTypedefs.kritz, itemDefIndex) then
        -- We found a kritzkrieg.
        --foundMediguns.kritz = item:GetItemId();
        local id = item:GetItemId();
    end
end

-- Registers new command.
-- 'commandName' is a command name
-- 'callback' is a function that's called when command is executed.
local function RegisterCommand(commandName, callback)
    if commands[commandName] ~= nil then
        error("Command with name " .. commandName .. " was already registered!");
        return; -- just in case, idk if error() acts as an exception
    end

    commands[commandName] = callback;
end

-- Sets up command list and registers an event hook
local function Initialize()
    -- Registering commands

    -- Suicide commands
    RegisterCommand("kill", KillCommand);
    RegisterCommand("explode", ExplodeCommand);

    -- Switching things
    RegisterCommand("slot", SwitchWeapon);
    RegisterCommand("class", SwitchClass);

    -- Saying things
    RegisterCommand("say", Say);
    RegisterCommand("say_team", SayTeam);
    RegisterCommand("say_party", SayParty);

    -- Taunting
    RegisterCommand("taunt", Taunt);
    RegisterCommand("tauntn", TauntByName);

    -- Attacking
    RegisterCommand("attack", Attack);

    -- Registering event callback
    callbacks.Register("FireGameEvent", FireGameEvent);

    -- Broken for now! Will fix later.
    --inventory.Enumerate(EnumerateInventory);
end

Initialize();