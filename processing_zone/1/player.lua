---@class CTFPlayer
---@field private __index CTFPlayer
---@field private __handle Entity
local CTFPlayer = {}
CTFPlayer.__index = CTFPlayer

---@param entity Entity?
---@return CTFPlayer?
function CTFPlayer.Get(entity)
	if entity == nil then
		return nil
	end

	local this = {__handle = entity}
	setmetatable(this, CTFPlayer)
	return this
end

function CTFPlayer:m_flNextAttack()
	return self.__handle:GetPropFloat("bcc_localdata", "m_flNextAttack")
end

function CTFPlayer:m_nTickBase()
	return self.__handle:GetPropInt("m_nTickBase")
end

function CTFPlayer:GetAmmoCount(iAmmoIndex)
	if iAmmoIndex == -1 then
		return 0
	end

	return self.__handle:GetPropDataTableInt("m_iAmmo")[iAmmoIndex]
end

function CTFPlayer:GetWorldSpaceCenter()
	local mins = self.__handle:GetMins()
	local maxs = self.__handle:GetMaxs()
	local origin = self.__handle:GetAbsOrigin()
	return origin + (mins + maxs) * 0.5
end

function CTFPlayer:GetEyePos()
	return self.__handle:GetAbsOrigin() + self.__handle:GetPropVector("localdata", "m_vecViewOffset[0]")
end

function CTFPlayer:GetHandle()
	return self.__handle
end

function CTFPlayer:m_bIsABot()
	return self.__handle:GetPropBool("m_bIsABot")
end

function CTFPlayer:m_bIsMiniBoss()
	return self.__handle:GetPropBool("m_bIsMiniBoss")
end

function CTFPlayer:m_nWaterLevel()
	return self.__handle:GetPropInt("m_nWaterLevel")
end

function CTFPlayer:m_nBotSkill()
	return self.__handle:GetPropInt("m_nBotSkill")
end

function CTFPlayer:m_hRagdoll()
	return self.__handle:GetPropEntity("m_hRagdoll")
end

function CTFPlayer:m_iClass()
	return self.__handle:GetPropInt("m_PlayerClass", "m_iClass")
end

function CTFPlayer:m_iszClassIcon()
	return self.__handle:GetPropString("m_PlayerClass", "m_iszClassIcon")
end

function CTFPlayer:m_iszCustomModel()
	return self.__handle:GetPropString("m_PlayerClass", "m_iszCustomModel")
end

function CTFPlayer:m_vecCustomModelOffset()
	return self.__handle:GetPropVector("m_PlayerClass", "m_vecCustomModelOffset")
end

function CTFPlayer:m_angCustomModelRotation()
	return self.__handle:GetPropVector("m_PlayerClass", "m_angCustomModelRotation")
end

function CTFPlayer:m_bCustomModelRotates()
	return self.__handle:GetPropBool("m_PlayerClass", "m_bCustomModelRotates")
end

function CTFPlayer:m_bCustomModelRotationSet()
	return self.__handle:GetPropBool("m_PlayerClass", "m_bCustomModelRotationSet")
end

function CTFPlayer:m_bCustomModelVisibleToSelf()
	return self.__handle:GetPropBool("m_PlayerClass", "m_bCustomModelVisibleToSelf")
end

function CTFPlayer:m_bUseClassAnimations()
	return self.__handle:GetPropBool("m_PlayerClass", "m_bUseClassAnimations")
end

function CTFPlayer:m_iClassModelParity()
	return self.__handle:GetPropInt("m_PlayerClass", "m_iClassModelParity")
end

function CTFPlayer:m_nNumHealers()
	return self.__handle:GetPropInt("m_Shared", "m_nNumHealers")
end

function CTFPlayer:m_iCritMult()
	return self.__handle:GetPropInt("m_Shared", "m_iCritMult")
end

function CTFPlayer:m_iAirDash()
	return self.__handle:GetPropInt("m_Shared", "m_iAirDash")
end

function CTFPlayer:m_nAirDucked()
	return self.__handle:GetPropInt("m_Shared", "m_nAirDucked")
end

function CTFPlayer:m_flDuckTimer()
	return self.__handle:GetPropFloat("m_Shared", "m_flDuckTimer")
end

function CTFPlayer:m_nPlayerState()
	return self.__handle:GetPropInt("m_Shared", "m_nPlayerState")
end

function CTFPlayer:m_iDesiredPlayerClass()
	return self.__handle:GetPropInt("m_Shared", "m_iDesiredPlayerClass")
end

function CTFPlayer:m_flMovementStunTime()
	return self.__handle:GetPropFloat("m_Shared", "m_flMovementStunTime")
end

function CTFPlayer:m_iMovementStunAmount()
	return self.__handle:GetPropInt("m_Shared", "m_iMovementStunAmount")
end

function CTFPlayer:m_iMovementStunParity()
	return self.__handle:GetPropInt("m_Shared", "m_iMovementStunParity")
end

function CTFPlayer:m_hStunner()
	return self.__handle:GetPropEntity("m_Shared", "m_hStunner")
end

function CTFPlayer:m_iStunFlags()
	return self.__handle:GetPropInt("m_Shared", "m_iStunFlags")
end

function CTFPlayer:m_nArenaNumChanges()
	return self.__handle:GetPropInt("m_Shared", "m_nArenaNumChanges")
end

function CTFPlayer:m_bArenaFirstBloodBoost()
	return self.__handle:GetPropBool("m_Shared", "m_bArenaFirstBloodBoost")
end

function CTFPlayer:m_iWeaponKnockbackID()
	return self.__handle:GetPropInt("m_Shared", "m_iWeaponKnockbackID")
end

function CTFPlayer:m_bLoadoutUnavailable()
	return self.__handle:GetPropBool("m_Shared", "m_bLoadoutUnavailable")
end

function CTFPlayer:m_iItemFindBonus()
	return self.__handle:GetPropInt("m_Shared", "m_iItemFindBonus")
end

function CTFPlayer:m_bShieldEquipped()
	return self.__handle:GetPropBool("m_Shared", "m_bShieldEquipped")
end

function CTFPlayer:m_bParachuteEquipped()
	return self.__handle:GetPropBool("m_Shared", "m_bParachuteEquipped")
end

function CTFPlayer:m_iNextMeleeCrit()
	return self.__handle:GetPropInt("m_Shared", "m_iNextMeleeCrit")
end

function CTFPlayer:m_iDecapitations()
	return self.__handle:GetPropInt("m_Shared", "m_iDecapitations")
end

function CTFPlayer:m_iRevengeCrits()
	return self.__handle:GetPropInt("m_Shared", "m_iRevengeCrits")
end

function CTFPlayer:m_iDisguiseBody()
	return self.__handle:GetPropInt("m_Shared", "m_iDisguiseBody")
end

function CTFPlayer:m_hCarriedObject()
	return self.__handle:GetPropEntity("m_Shared", "m_hCarriedObject")
end

function CTFPlayer:m_bCarryingObject()
	return self.__handle:GetPropBool("m_Shared", "m_bCarryingObject")
end

function CTFPlayer:m_flNextNoiseMakerTime()
	return self.__handle:GetPropFloat("m_Shared", "m_flNextNoiseMakerTime")
end

function CTFPlayer:m_iSpawnRoomTouchCount()
	return self.__handle:GetPropInt("m_Shared", "m_iSpawnRoomTouchCount")
end

function CTFPlayer:m_iKillCountSinceLastDeploy()
	return self.__handle:GetPropInt("m_Shared", "m_iKillCountSinceLastDeploy")
end

function CTFPlayer:m_flFirstPrimaryAttack()
	return self.__handle:GetPropFloat("m_Shared", "m_flFirstPrimaryAttack")
end

function CTFPlayer:m_flEnergyDrinkMeter()
	return self.__handle:GetPropFloat("m_Shared", "m_flEnergyDrinkMeter")
end

function CTFPlayer:m_flHypeMeter()
	return self.__handle:GetPropFloat("m_Shared", "m_flHypeMeter")
end

function CTFPlayer:m_flChargeMeter()
	return self.__handle:GetPropFloat("m_Shared", "m_flChargeMeter")
end

function CTFPlayer:m_flInvisChangeCompleteTime()
	return self.__handle:GetPropFloat("m_Shared", "m_flInvisChangeCompleteTime")
end

function CTFPlayer:m_nDisguiseTeam()
	return self.__handle:GetPropInt("m_Shared", "m_nDisguiseTeam")
end

function CTFPlayer:m_nDisguiseClass()
	return self.__handle:GetPropInt("m_Shared", "m_nDisguiseClass")
end

function CTFPlayer:m_nDisguiseSkinOverride()
	return self.__handle:GetPropInt("m_Shared", "m_nDisguiseSkinOverride")
end

function CTFPlayer:m_nMaskClass()
	return self.__handle:GetPropInt("m_Shared", "m_nMaskClass")
end

function CTFPlayer:m_hDisguiseTarget()
	return self.__handle:GetPropEntity("m_Shared", "m_hDisguiseTarget")
end

function CTFPlayer:m_iDisguiseHealth()
	return self.__handle:GetPropInt("m_Shared", "m_iDisguiseHealth")
end

function CTFPlayer:m_bFeignDeathReady()
	return self.__handle:GetPropBool("m_Shared", "m_bFeignDeathReady")
end

function CTFPlayer:m_hDisguiseWeapon()
	return self.__handle:GetPropEntity("m_Shared", "m_hDisguiseWeapon")
end

function CTFPlayer:m_nTeamTeleporterUsed()
	return self.__handle:GetPropInt("m_Shared", "m_nTeamTeleporterUsed")
end

function CTFPlayer:m_flCloakMeter()
	return self.__handle:GetPropFloat("m_Shared", "m_flCloakMeter")
end

function CTFPlayer:m_flSpyTranqBuffDuration()
	return self.__handle:GetPropFloat("m_Shared", "m_flSpyTranqBuffDuration")
end

--- m_Shared, tfsharedlocaldata
function CTFPlayer:m_nDesiredDisguiseTeam()
	return self.__handle:GetPropInt("m_Shared", "tfsharedlocaldata", "m_nDesiredDisguiseTeam")
end

function CTFPlayer:m_nDesiredDisguiseClass()
	return self.__handle:GetPropInt("m_Shared", "tfsharedlocaldata", "m_nDesiredDisguiseClass")
end

function CTFPlayer:m_flStealthNoAttackExpire()
	return self.__handle:GetPropFloat("m_Shared", "tfsharedlocaldata", "m_flStealthNoAttackExpire")
end

function CTFPlayer:m_flStealthNextChangeTime()
	return self.__handle:GetPropFloat("m_Shared", "tfsharedlocaldata", "m_flStealthNextChangeTime")
end

function CTFPlayer:m_bLastDisguisedAsOwnTeam()
	return self.__handle:GetPropBool("m_Shared", "tfsharedlocaldata", "m_bLastDisguisedAsOwnTeam")
end

function CTFPlayer:m_flRageMeter()
	return self.__handle:GetPropFloat("m_Shared", "tfsharedlocaldata", "m_flRageMeter")
end

function CTFPlayer:m_bRageDraining()
	return self.__handle:GetPropBool("m_Shared", "tfsharedlocaldata", "m_bRageDraining")
end

function CTFPlayer:m_flNextRageEarnTime()
	return self.__handle:GetPropFloat("m_Shared", "tfsharedlocaldata", "m_flNextRageEarnTime")
end

function CTFPlayer:m_bInUpgradeZone()
	return self.__handle:GetPropBool("m_Shared", "tfsharedlocaldata", "m_bInUpgradeZone")
end

function CTFPlayer:m_flItemChargeMeter()
	return self.__handle:GetPropDataTableFloat("m_Shared", "tfsharedlocaldata", "m_flItemChargeMeter")
end

function CTFPlayer:m_bPlayerDominated()
	return self.__handle:GetPropDataTableBool("m_Shared", "tfsharedlocaldata", "m_bPlayerDominated")
end

function CTFPlayer:m_bPlayerDominatingMe()
	return self.__handle:GetPropDataTableBool("m_Shared", "tfsharedlocaldata", "m_bPlayerDominatingMe")
end

function CTFPlayer:_condition_bits()
	return self.__handle:GetPropInt("m_ConditionList", "_condition_bits")
end

function CTFPlayer:m_iTauntIndex()
	return self.__handle:GetPropInt("m_Shared", "m_iTauntIndex")
end

function CTFPlayer:m_iTauntConcept()
	return self.__handle:GetPropInt("m_Shared", "m_iTauntConcept")
end

function CTFPlayer:m_nPlayerCondEx()
	return self.__handle:GetPropInt("m_Shared", "m_nPlayerCondEx")
end

function CTFPlayer:m_iStunIndex()
	return self.__handle:GetPropInt("m_Shared", "m_iStunIndex")
end

function CTFPlayer:m_nHalloweenBombHeadStage()
	return self.__handle:GetPropInt("m_Shared", "m_nHalloweenBombHeadStage")
end

function CTFPlayer:m_nPlayerCondEx2()
	return self.__handle:GetPropInt("m_Shared", "m_nPlayerCondEx2")
end

function CTFPlayer:m_nPlayerCondEx3()
	return self.__handle:GetPropInt("m_Shared", "m_nPlayerCondEx3")
end

function CTFPlayer:m_nStreaks()
	return self.__handle:GetPropInt("m_Shared", "m_nStreaks")
end

function CTFPlayer:m_unTauntSourceItemID_Low()
	return self.__handle:GetPropInt("m_Shared", "m_unTauntSourceItemID_Low")
end

function CTFPlayer:m_unTauntSourceItemID_High()
	return self.__handle:GetPropInt("m_Shared", "m_unTauntSourceItemID_High")
end

function CTFPlayer:m_flRuneCharge()
	return self.__handle:GetPropFloat("m_Shared", "m_flRuneCharge")
end

function CTFPlayer:m_bHasPasstimeBall()
	return self.__handle:GetPropInt("m_Shared", "m_bHasPasstimeBall")
end

function CTFPlayer:m_bIsTargetedForPasstimePass()
	return self.__handle:GetPropInt("m_Shared", "m_bIsTargetedForPasstimePass")
end

function CTFPlayer:m_hPasstimePassTarget()
	return self.__handle:GetPropEntity("m_Shared", "m_hPasstimePassTarget")
end

function CTFPlayer:m_askForBallTime()
	return self.__handle:GetPropInt("m_Shared", "m_askForBallTime")
end

function CTFPlayer:m_bKingRuneBuffActive()
	return self.__handle:GetPropInt("m_Shared", "m_bKingRuneBuffActive")
end

function CTFPlayer:lengthprop131()
	return self.__handle:GetPropInt("m_Shared", "m_ConditionData", "lengthproxy", "lengthprop131")
end

function CTFPlayer:m_nPlayerCondEx4()
	return self.__handle:GetPropInt("m_Shared", "m_nPlayerCondEx4")
end

function CTFPlayer:m_flHolsterAnimTime()
	return self.__handle:GetPropFloat("m_Shared", "m_flHolsterAnimTime")
end

function CTFPlayer:m_hSwitchTo()
	return self.__handle:GetPropEntity("m_Shared", "m_hSwitchTo")
end

function CTFPlayer:m_hItem()
	return self.__handle:GetPropEntity("m_hItem")
end


function CTFPlayer:m_vecOrigin()
	return self.__handle:GetPropVector("tflocaldata", "m_vecOrigin")
end

function CTFPlayer:m_angEyeAngles()
	return self.__handle:GetPropVector("tflocaldata", "m_angEyeAngles[0]")
end

function CTFPlayer:m_bIsCoaching()
	return self.__handle:GetPropBool("tflocaldata", "m_bIsCoaching")
end

function CTFPlayer:m_hCoach()
	return self.__handle:GetPropEntity("tflocaldata", "m_hCoach")
end

function CTFPlayer:m_hStudent()
	return self.__handle:GetPropEntity("tflocaldata", "m_hStudent")
end

function CTFPlayer:m_nCurrency()
	return self.__handle:GetPropInt("tflocaldata", "m_nCurrency")
end

function CTFPlayer:m_nExperienceLevel()
	return self.__handle:GetPropInt("tflocaldata", "m_nExperienceLevel")
end

function CTFPlayer:m_nExperienceLevelProgress()
	return self.__handle:GetPropInt("tflocaldata", "m_nExperienceLevelProgress")
end

function CTFPlayer:m_bMatchSafeToLeave()
	return self.__handle:GetPropBool("tflocaldata", "m_bMatchSafeToLeave")
end

function CTFPlayer:m_bAllowMoveDuringTaunt()
	return self.__handle:GetPropBool("m_bAllowMoveDuringTaunt")
end

function CTFPlayer:m_bIsReadyToHighFive()
	return self.__handle:GetPropBool("m_bIsReadyToHighFive")
end

function CTFPlayer:m_hHighFivePartner()
	return self.__handle:GetPropEntity("m_hHighFivePartner")
end

function CTFPlayer:m_nForceTauntCam()
	return self.__handle:GetPropInt("m_nForceTauntCam")
end

function CTFPlayer:m_flTauntYaw()
	return self.__handle:GetPropFloat("m_flTauntYaw")
end

function CTFPlayer:m_nActiveTauntSlot()
	return self.__handle:GetPropInt("m_nActiveTauntSlot")
end

function CTFPlayer:m_iTauntItemDefIndex()
	return self.__handle:GetPropInt("m_iTauntItemDefIndex")
end

function CTFPlayer:m_flCurrentTauntMoveSpeed()
	return self.__handle:GetPropFloat("m_flCurrentTauntMoveSpeed")
end

function CTFPlayer:m_flVehicleReverseTime()
	return self.__handle:GetPropFloat("m_flVehicleReverseTime")
end

function CTFPlayer:m_flMvMLastDamageTime()
	return self.__handle:GetPropFloat("m_flMvMLastDamageTime")
end

function CTFPlayer:m_flLastDamageTime()
	return self.__handle:GetPropFloat("m_flLastDamageTime")
end

function CTFPlayer:m_bInPowerPlay()
	return self.__handle:GetPropBool("m_bInPowerPlay")
end

function CTFPlayer:m_iSpawnCounter()
	return self.__handle:GetPropInt("m_iSpawnCounter")
end

function CTFPlayer:m_bArenaSpectator()
	return self.__handle:GetPropBool("m_bArenaSpectator")
end

function CTFPlayer:m_hOuter()
	return self.__handle:GetPropEntity("m_AttributeManager", "m_hOuter")
end

function CTFPlayer:m_ProviderType()
	return self.__handle:GetPropInt("m_AttributeManager", "m_ProviderType")
end

function CTFPlayer:m_iReapplyProvisionParity()
	return self.__handle:GetPropInt("m_AttributeManager", "m_iReapplyProvisionParity")
end

function CTFPlayer:m_flHeadScale()
	return self.__handle:GetPropFloat("m_flHeadScale")
end

function CTFPlayer:m_flTorsoScale()
	return self.__handle:GetPropFloat("m_flTorsoScale")
end

function CTFPlayer:m_flHandScale()
	return self.__handle:GetPropFloat("m_flHandScale")
end

function CTFPlayer:m_bUseBossHealthBar()
	return self.__handle:GetPropBool("m_bUseBossHealthBar")
end

function CTFPlayer:m_bUsingVRHeadset()
	return self.__handle:GetPropBool("m_bUsingVRHeadset")
end

function CTFPlayer:m_bForcedSkin()
	return self.__handle:GetPropBool("m_bForcedSkin")
end

function CTFPlayer:m_nForcedSkin()
	return self.__handle:GetPropInt("m_nForcedSkin")
end

function CTFPlayer:m_bGlowEnabled()
	return self.__handle:GetPropBool("m_bGlowEnabled")
end

function CTFPlayer:m_nActiveWpnClip()
	return self.__handle:GetPropInt("TFSendHealersDataTable", "m_nActiveWpnClip")
end

function CTFPlayer:m_flKartNextAvailableBoost()
	return self.__handle:GetPropFloat("m_flKartNextAvailableBoost")
end

function CTFPlayer:m_iKartHealth()
	return self.__handle:GetPropInt("m_iKartHealth")
end

function CTFPlayer:m_iKartState()
	return self.__handle:GetPropInt("m_iKartState")
end

function CTFPlayer:m_hGrapplingHookTarget()
	return self.__handle:GetPropEntity("m_hGrapplingHookTarget")
end

function CTFPlayer:m_hSecondaryLastWeapon()
	return self.__handle:GetPropEntity("m_hSecondaryLastWeapon")
end

function CTFPlayer:m_bUsingActionSlot()
	return self.__handle:GetPropInt("m_bUsingActionSlot")
end

function CTFPlayer:m_flInspectTime()
	return self.__handle:GetPropFloat("m_flInspectTime")
end

function CTFPlayer:m_flHelpmeButtonPressTime()
	return self.__handle:GetPropFloat("m_flHelpmeButtonPressTime")
end

function CTFPlayer:m_iCampaignMedals()
	return self.__handle:GetPropInt("m_iCampaignMedals")
end

function CTFPlayer:m_iPlayerSkinOverride()
	return self.__handle:GetPropInt("m_iPlayerSkinOverride")
end

function CTFPlayer:m_bViewingCYOAPDA()
	return self.__handle:GetPropInt("m_bViewingCYOAPDA")
end

function CTFPlayer:m_bRegenerating()
	return self.__handle:GetPropInt("m_bRegenerating")
end

return CTFPlayer