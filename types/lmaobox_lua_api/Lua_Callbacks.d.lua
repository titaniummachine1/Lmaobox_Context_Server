---@meta

-- Lmaobox Lua API: Lua Callbacks - Lmaobox Lua
-- Auto-generated from: https://lmaobox.net/lua/Lua_Callbacks
-- Path: Lua_Callbacks
-- Last updated: 2025-12-08T06:34:50.363Z

---@return any
function Draw() end

---@param ctx DrawModelContext
---@return any
function DrawModel(ctx) end

---@param info any
---@return any
function DrawStaticProps(info) end

---@param cmd UserCmd
---@return any
function CreateMove(cmd) end

---@param event GameEvent
---@return any
function FireGameEvent(event) end

---@param msg any
---@return any
function DispatchUserMessage(msg) end

---@param cmd string
---@return string
function SendStringCmd(cmd) end

---@param stage number
---@return any
function FrameStageNotify(stage) end

---@param view ViewSetup
---@return any
function RenderView(view) end

---@param view ViewSetup
---@return any
function PostRenderView(view) end

---@param view ViewSetup
---@return any
function RenderViewModel(view) end

---@param keyvalues string
---@return any
function ServerCmdKeyValues(keyvalues) end

---@param crate Item|nil
---@param crateLootList table
---@return any
function OnFakeUncrate(crate, crateLootList) end

---@param lobby any
---@return any
function OnLobbyUpdated(lobby) end

---@param key string
---@param value string
function SetRichPresence(key, value) end

---@param typeID number
---@param data string
---@return any
function GCSendMessage(typeID, data) end

---@param typeID number
---@param data string
---@return any
function GCRetrieveMessage(typeID, data) end

---@param msg NetMessage
---@param reliable boolean
---@param voice boolean
---@return any
function SendNetMsg(msg, reliable, voice) end

---@return any
function DoPostScreenSpaceEffects() end

---@param TempEntity any
---@param entEvtTable any
---@return any
function ProcessTempEntities(TempEntity, entEvtTable) end

---@return any
function Unload() end

