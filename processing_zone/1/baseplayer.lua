---@class CBasePlayer
---@field private __index CBasePlayer
---@field private __handle Entity
local CBasePlayer = {}
CBasePlayer.__index = CBasePlayer

---@param entity Entity?
---@return CBasePlayer?
function CBasePlayer.Get(entity)
	if entity == nil then
		return nil
	end

	local this = {__handle = entity}
	setmetatable(this, CBasePlayer)
	return this
end

function CBasePlayer:m_iFOV()
	return self.__handle:GetPropInt("m_iFOV")
end

function CBasePlayer:m_iFOVStart()
	return self.__handle:GetPropInt("m_iFOVStart")
end

function CBasePlayer:m_flFOVTime()
	return self.__handle:GetPropFloat("m_flFOVTime")
end

function CBasePlayer:m_iDefaultFOV()
	return self.__handle:GetPropInt("m_iDefaultFOV")
end

function CBasePlayer:m_hZoomOwner()
	return self.__handle:GetPropEntity("m_hZoomOwner")
end

function CBasePlayer:m_hVehicle()
	return self.__handle:GetPropEntity("m_hVehicle")
end

function CBasePlayer:m_hUseEntity()
	return self.__handle:GetPropEntity("m_hUseEntity")
end

function CBasePlayer:m_iHealth()
	return self.__handle:GetPropInt("m_iHealth")
end

function CBasePlayer:m_lifeState()
	return self.__handle:GetPropInt("m_lifeState")
end

function CBasePlayer:m_iBonusProgress()
	return self.__handle:GetPropInt("m_iBonusProgress")
end

function CBasePlayer:m_iBonusChallenge()
	return self.__handle:GetPropInt("m_iBonusChallenge")
end

function CBasePlayer:m_flMaxspeed()
	return self.__handle:GetPropFloat("m_flMaxspeed")
end

function CBasePlayer:m_fFlags()
	return self.__handle:GetPropInt("m_fFlags")
end

function CBasePlayer:m_iObserverMode()
	return self.__handle:GetPropInt("m_iObserverMode")
end

function CBasePlayer:m_hObserverTarget()
	return self.__handle:GetPropEntity("m_hObserverTarget")
end

function CBasePlayer:m_hViewModel()
	return self.__handle:GetPropEntity("m_hViewModel[0]")
end

function CBasePlayer:m_szLastPlaceName()
	return self.__handle:GetPropInt("m_szLastPlaceName")
end

function CBasePlayer:m_vecViewOffset()
	return self.__handle:GetPropVector("localdata", "m_vecViewOffset[0]")
end

function CBasePlayer:m_flFriction()
	return self.__handle:GetPropFloat("localdata", "m_flFriction")
end

function CBasePlayer:m_iAmmo()
	return self.__handle:GetPropDataTableInt("localdata", "m_iAmmo")
end

function CBasePlayer:m_fOnTarget()
	return self.__handle:GetPropInt("localdata", "m_fOnTarget")
end

function CBasePlayer:m_nTickBase()
	return self.__handle:GetPropInt("localdata", "m_nTickBase")
end

function CBasePlayer:m_nNextThinkTick()
	return self.__handle:GetPropInt("localdata", "m_nNextThinkTick")
end

function CBasePlayer:m_hLastWeapon()
	return self.__handle:GetPropEntity("localdata", "m_hLastWeapon")
end

function CBasePlayer:m_hGroundEntity()
	return self.__handle:GetPropEntity("localdata", "m_hGroundEntity")
end

function CBasePlayer:m_vecVelocity()
	return self.__handle:GetPropVector("localdata", "m_vecVelocity[0]")
end

function CBasePlayer:m_vecBaseVelocity()
	return self.__handle:GetPropVector("localdata", "m_vecBaseVelocity")
end

function CBasePlayer:m_hConstraintEntity()
	return self.__handle:GetPropEntity("localdata", "m_hConstraintEntity")
end

function CBasePlayer:m_vecConstraintCenter()
	return self.__handle:GetPropVector("localdata", "m_vecConstraintCenter")
end

function CBasePlayer:m_flConstraintRadius()
	return self.__handle:GetPropFloat("localdata", "m_flConstraintRadius")
end

function CBasePlayer:m_flConstraintWidth()
	return self.__handle:GetPropFloat("localdata", "m_flConstraintWidth")
end

function CBasePlayer:m_flConstraintSpeedFactor()
	return self.__handle:GetPropFloat("localdata", "m_flConstraintSpeedFactor")
end

function CBasePlayer:m_flDeathTime()
	return self.__handle:GetPropFloat("localdata", "m_flDeathTime")
end

function CBasePlayer:m_nWaterLevel()
	return self.__handle:GetPropInt("localdata", "m_nWaterLevel")
end

function CBasePlayer:m_flLaggedMovementValue()
	return self.__handle:GetPropFloat("localdata", "m_flLaggedMovementValue")
end

--- Im not sure if this is as integer
function CBasePlayer:m_chAreaBits()
	return self.__handle:GetPropDataTableInt("localdata", "m_Local", "m_chAreaBits")
end

--- Im not sure if this is as integer
function CBasePlayer:m_chAreaPortalBits()
	return self.__handle:GetPropDataTableInt("localdata", "m_Local", "m_chAreaPortalBits")
end

function CBasePlayer:m_iHideHUD()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_iHideHUD")
end

function CBasePlayer:m_flFOVRate()
	return self.__handle:GetPropFloat("localdata", "m_Local", "m_flFOVRate")
end

function CBasePlayer:m_bDucked()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_bDucked")
end

function CBasePlayer:m_bDucking()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_bDucking")
end

function CBasePlayer:m_bInDuckJump()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_bInDuckJump")
end

function CBasePlayer:m_flDucktime()
	return self.__handle:GetPropFloat("localdata", "m_Local", "m_flDucktime")
end

function CBasePlayer:m_flDuckJumpTime()
	return self.__handle:GetPropFloat("localdata", "m_Local", "m_flDuckJumpTime")
end

function CBasePlayer:m_flJumpTime()
	return self.__handle:GetPropFloat("localdata", "m_Local", "m_flJumpTime")
end

function CBasePlayer:m_flFallVelocity()
	return self.__handle:GetPropFloat("localdata", "m_Local", "m_flFallVelocity")
end

function CBasePlayer:m_vecPunchAngle()
	return self.__handle:GetPropVector("localdata", "m_Local", "m_vecPunchAngle")
end

function CBasePlayer:m_vecPunchAngleVel()
	return self.__handle:GetPropVector("localdata", "m_Local", "m_vecPunchAngleVel")
end

function CBasePlayer:m_bDrawViewmodel()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_bDrawViewmodel")
end

function CBasePlayer:m_bWearingSuit()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_bWearingSuit")
end

function CBasePlayer:m_bPoisoned()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_bPoisoned")
end

function CBasePlayer:m_bForceLocalPlayerDraw()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_bForceLocalPlayerDraw")
end

function CBasePlayer:m_flStepSize()
	return self.__handle:GetPropFloat("localdata", "m_Local", "m_flStepSize")
end

function CBasePlayer:m_bAllowAutoMovement()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_bAllowAutoMovement")
end

function CBasePlayer:m_skybox3d_scale()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_skybox3d.scale")
end

function CBasePlayer:m_skybox3d_origin()
	return self.__handle:GetPropVector("localdata", "m_Local", "m_skybox3d.origin")
end

function CBasePlayer:m_skybox3d_area()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_skybox3d.area")
end

function CBasePlayer:m_skybox3d_fog_enable()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_skybox3d.fog.enable")
end

function CBasePlayer:m_skybox3d_fog_blend()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_skybox3d.fog.blend")
end

function CBasePlayer:m_skybox3d_fog_dirPrimary()
	return self.__handle:GetPropVector("localdata", "m_Local", "m_skybox3d.fog.dirPrimary")
end

function CBasePlayer:m_skybox3d_fog_colorPrimary()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_skybox3d.fog.colorPrimary")
end

function CBasePlayer:m_skybox3d_fog_colorSecondary()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_skybox3d.fog.colorSecondary")
end

function CBasePlayer:m_skybox3d_fog_start()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_skybox3d.fog.start")
end

function CBasePlayer:m_skybox3d_fog_end()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_skybox3d.fog.end")
end

function CBasePlayer:m_skybox3d_fog_maxdensity()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_skybox3d.fog.maxdensity")
end

function CBasePlayer:m_PlayerFog_m_hCtrl()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_PlayerFog.m_hCtrl")
end

function CBasePlayer:m_audio_soundscapeIndex()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_audio.soundscapeIndex")
end

function CBasePlayer:m_audio_localBits()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_audio.localBits")
end

function CBasePlayer:m_audio_entIndex()
	return self.__handle:GetPropInt("localdata", "m_Local", "m_audio.entIndex")
end

function CBasePlayer:m_szScriptOverlayMaterial()
	return self.__handle:GetPropString("localdata", "m_Local", "m_szScriptOverlayMaterial")
end

function CBasePlayer:lengthprop20()
	return self.__handle:GetPropInt("m_AttributeList", "m_Attributes", "lengthproxy", "lengthprop20")
end

function CBasePlayer:deadflag()
	return self.__handle:GetPropInt("pl", "deadflag")
end

return CBasePlayer