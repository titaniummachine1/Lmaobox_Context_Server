local me = entities.GetLocalPlayer()

if me then
    local ammoTable = me:GetPropDataTableInt("localdata", "m_iAmmo")
    if ammoTable then
        printc("255", "0", "0", "100", "**Ammo Table Info:**")
        for i, ammoCount in ipairs(ammoTable) do
            print("Ammo for index '" .. tostring(i) .. "': " .. tostring(ammoCount))
        end
    end

    -- Print all basic player info
    printc("255", "0", "0", "100", "**Player Info:**")
    local playerClass = pcall(function() return me:GetPropInt("m_iClass") end)
    print("Player Class ID: " .. tostring(playerClass and me:GetPropInt("m_iClass") or "Unknown"))

    -- Try to get player health info
    local health, maxHealth
    pcall(function() health = me:GetHealth() end)
    pcall(function() maxHealth = me:GetMaxHealth() end)
    print("Health: " .. tostring(health or "Unknown") .. "/" .. tostring(maxHealth or "Unknown"))

    -- Try more player properties
    local playerTeam
    pcall(function() playerTeam = me:GetTeamNumber() end)
    print("Team Number: " .. tostring(playerTeam or "Unknown"))

    local function safeGetItemDefByID(id)
        if not id then return nil end

        -- If itemschema is nil, try to reference it directly
        if not itemschema then
            printc("255", "255", "0", "100", "Warning: itemschema is nil, trying direct access")
        end

        local success, result = pcall(function()
            return itemschema.GetItemDefinitionByID(id)
        end)

        if not success or not result then
            -- Try forcing by index if possible
            printc("255", "255", "0", "100",
                "Failed to get item def by normal means, trying forced method for index: " .. tostring(id))

            -- This is aggressive - try to get ANY item definition to see if function works
            if itemschema and itemschema.Enumerate then
                local foundDef
                pcall(function()
                    itemschema.Enumerate(function(itemDef)
                        if itemDef and itemDef:GetID() == id then
                            foundDef = itemDef
                        end
                    end)
                end)
                if foundDef then
                    return foundDef
                end
            end
        end

        return success and result or nil
    end

    -- More aggressive item info getter
    local function getItemInfo(entity)
        if not entity then return nil end

        local info = {}

        -- Basic entity info
        info.class = pcall(function() return entity:GetClass() end) and entity:GetClass() or "Unknown"
        info.entity = entity

        -- Try more aggressively to get item definition index
        local itemDefIndex

        -- Method 1: Standard way
        local success = pcall(function()
            itemDefIndex = entity:GetPropInt("m_iItemDefinitionIndex")
        end)

        -- Method 2: If that failed, try brute-forcing property names
        if not success or not itemDefIndex then
            local possiblePropNames = {
                "m_iItemDefinitionIndex", "m_iItemDefIndex", "m_ItemDefinitionIndex",
                "m_ItemDefIndex", "m_DefIndex", "m_iDefIndex"
            }

            for _, propName in ipairs(possiblePropNames) do
                pcall(function()
                    local val = entity:GetPropInt(propName)
                    if val and val > 0 then
                        itemDefIndex = val
                    end
                end)
                if itemDefIndex then break end
            end
        end

        -- Method 3: Try to get it from ToInventoryItem if available
        if not itemDefIndex and entity.ToInventoryItem then
            pcall(function()
                local invItem = entity:ToInventoryItem()
                if invItem then
                    pcall(function() itemDefIndex = invItem:GetDefinitionIndex() end)
                end
            end)
        end

        info.itemDefIndex = itemDefIndex

        -- Get item definition if possible
        if info.itemDefIndex then
            info.itemDef = safeGetItemDefByID(info.itemDefIndex)

            if info.itemDef then
                -- Get basic item info
                pcall(function() info.name = info.itemDef:GetName() end)
                pcall(function() info.typeName = info.itemDef:GetTypeName() end)
                pcall(function() info.loadoutSlot = info.itemDef:GetLoadoutSlot() end)
                pcall(function() info.description = info.itemDef:GetDescription() end)
                pcall(function() info.isWearable = info.itemDef:IsWearable() end)

                -- Try to get attributes even if GetAttributes fails
                local attributes = {}
                pcall(function()
                    attributes = info.itemDef:GetAttributes() or {}
                end)
                info.attributes = attributes
            else
                -- If we can't get item definition, try to get some info directly from entity
                print("No item definition found for index " ..
                    tostring(info.itemDefIndex) .. ", trying direct entity properties")

                -- Try various property access methods
                pcall(function()
                    info.name = entity:GetPropString("m_iName")
                end)
                if not info.name or info.name == "" then
                    pcall(function()
                        info.name = entity:GetPropString("m_szPrintName")
                    end)
                end
            end
        end

        return info
    end

    local function printItemInfo(info, itemTypeLabel)
        if not info then
            print("No " .. itemTypeLabel .. " info available.")
            return
        end

        printc("0", "0", "255", "100", "**" .. itemTypeLabel .. " Info:**")

        -- Only print name if it's not unknown
        if info.name and info.name ~= "Unknown" then
            print("Name: " .. tostring(info.name))
        end

        -- Only print type if it's not unknown
        if info.typeName and info.typeName ~= "Unknown" then
            print("Type: " .. tostring(info.typeName))
        end

        -- Only print class if it's not unknown
        if info.class and info.class ~= "Unknown" then
            print("Class: " .. tostring(info.class))
        end

        -- Only print loadout slot if it's valid
        if info.loadoutSlot and info.loadoutSlot >= 0 then
            print("Loadout Slot: " .. tostring(info.loadoutSlot))
        end

        -- Only print item definition index if it exists
        if info.itemDefIndex then
            print("Item Definition Index: " .. tostring(info.itemDefIndex))
        end

        if info.description and info.description ~= "" then
            print("Description: " .. tostring(info.description))
        end

        if info.isWearable ~= nil then
            print("Is Wearable: " .. tostring(info.isWearable))
        end

        -- Print attributes if available and not empty
        if info.attributes and next(info.attributes) then
            local hasValidAttrs = false
            for attrDef, value in pairs(info.attributes) do
                if attrDef then
                    hasValidAttrs = true
                    break
                end
            end

            if hasValidAttrs then
                print("Attributes:")
                for attrDef, value in pairs(info.attributes) do
                    local attrName = pcall(function() return attrDef:GetName() end) and attrDef:GetName() or nil
                    if attrName and attrName ~= "Unknown" then
                        print("  " .. attrName .. ": " .. tostring(value))
                    end
                end
            end
        end
    end

    -- Try to get ALL entity props for debugging
    local function dumpEntityProps(entity, label)
        if not entity then return end

        printc("128", "128", "255", "100", "**" .. label .. " Properties Dump:**")

        -- Common TF2 networked properties to try
        local propsToTry = {
            "m_iItemDefinitionIndex", "m_iEntityLevel", "m_bInitialized",
            "m_iEntityQuality", "m_iAccountID", "m_bOnlyIterateItemViewAttributes",
            "m_iItemIDHigh", "m_iItemIDLow", "m_bValidatedAttachedEntity",
            "m_AttributeManager", "m_Item", "m_iTeamNum", "m_hOwnerEntity"
        }

        local foundAnyProps = false
        for _, propName in ipairs(propsToTry) do
            local foundProp = false
            -- Try as int
            pcall(function()
                local val = entity:GetPropInt(propName)
                if val and val ~= 0 then -- Skip zero values as they're often default/nil
                    print(propName .. " (int): " .. tostring(val))
                    foundProp = true
                    foundAnyProps = true
                end
            end)

            -- Only try other types if we haven't found a valid value yet
            if not foundProp then
                -- Try as float
                pcall(function()
                    local val = entity:GetPropFloat(propName)
                    if val and val ~= 0.0 then -- Skip zero values as they're often default/nil
                        print(propName .. " (float): " .. tostring(val))
                        foundProp = true
                        foundAnyProps = true
                    end
                end)
            end

            if not foundProp then
                -- Try as bool - only print true values since false is default
                pcall(function()
                    local val = entity:GetPropBool(propName)
                    if val == true then -- Only print "true" values
                        print(propName .. " (bool): " .. tostring(val))
                        foundProp = true
                        foundAnyProps = true
                    end
                end)
            end

            if not foundProp then
                -- Try as string - only print non-empty strings
                pcall(function()
                    local val = entity:GetPropString(propName)
                    if val and val ~= "" then
                        print(propName .. " (string): " .. tostring(val))
                        foundProp = true
                        foundAnyProps = true
                    end
                end)
            end

            if not foundProp then
                -- Try as entity - only print valid entities
                pcall(function()
                    local val = entity:GetPropEntity(propName)
                    if val and val:IsValid() then
                        print(propName .. " (entity): " .. tostring(val))
                        foundAnyProps = true
                    end
                end)
            end
        end

        if not foundAnyProps then
            print("No meaningful properties found for this entity.")
        end
    end

    local function printWeaponAmmoInfo(weaponEntity, weaponName)
        if not weaponEntity then
            print("Could not retrieve " .. weaponName .. " weapon entity.")
            return
        end

        -- Dump entity props for debugging
        dumpEntityProps(weaponEntity, weaponName .. " Weapon")

        local wData
        local success = pcall(function() wData = weaponEntity:GetWeaponData() end)
        if not success or not wData then
            print("Could not retrieve weapon data for " .. weaponName)
            return
        end

        local clip1, clip2
        pcall(function() clip1 = weaponEntity:GetPropInt("LocalWeaponData", "m_iClip1") end)
        pcall(function() clip2 = weaponEntity:GetPropInt("LocalWeaponData", "m_iClip2") end)
        clip1 = clip1 or 0
        clip2 = clip2 or 0

        local itemDefinitionIndex
        success = pcall(function() itemDefinitionIndex = weaponEntity:GetPropInt("m_iItemDefinitionIndex") end)
        if not success then
            itemDefinitionIndex = nil
            printc("255", "255", "0", "100", "Could not retrieve item definition index for " .. weaponName)
        end

        local itemDefinition = nil
        if itemschema and itemschema.GetItemDefinitionByID and itemDefinitionIndex then
            success, itemDefinition = pcall(function() return itemschema.GetItemDefinitionByID(itemDefinitionIndex) end)
            if not success then
                printc("255", "255", "0", "100", "Error getting item definition")
                itemDefinition = nil
            end
        end

        local weaponDefName = "Unknown"
        local weaponClass = "Unknown"
        local weaponLoadoutSlot = -1
        local weaponHidden = false
        local weaponIsTool = false
        local weaponIsBaseItem = false
        local weaponIsWearable = false
        local weaponTypeName = "Unknown"
        local weaponDescription = nil
        local weaponIconName = nil
        local weaponBaseNumber = "Unknown"
        local eCanCrit = false

        if itemDefinition then
            pcall(function() weaponDefName = itemDefinition:GetName() or "Unknown" end)
            pcall(function() weaponClass = itemDefinition:GetClass() or "Unknown" end)
            pcall(function() weaponLoadoutSlot = itemDefinition:GetLoadoutSlot() or -1 end)

            pcall(function() if itemDefinition.IsHidden then weaponHidden = itemDefinition:IsHidden() end end)
            pcall(function() if itemDefinition.IsTool then weaponIsTool = itemDefinition:IsTool() end end)
            pcall(function() if itemDefinition.IsBaseItem then weaponIsBaseItem = itemDefinition:IsBaseItem() end end)
            pcall(function() if itemDefinition.IsWearable then weaponIsWearable = itemDefinition:IsWearable() end end)
            pcall(function()
                if itemDefinition.GetTypeName then
                    weaponTypeName = itemDefinition:GetTypeName() or
                        "Unknown"
                end
            end)
            pcall(function() if itemDefinition.GetDescription then weaponDescription = itemDefinition:GetDescription() end end)
            pcall(function() if itemDefinition.GetIconName then weaponIconName = itemDefinition:GetIconName() end end)
            pcall(function()
                if itemDefinition.GetBaseItemName then
                    weaponBaseNumber = itemDefinition:GetBaseItemName() or
                        "Unknown"
                end
            end)
        end

        pcall(function() if weaponEntity.CanRandomCrit then eCanCrit = weaponEntity:CanRandomCrit() end end)

        -- Extract weapon data with nil checks
        local wDamage = wData.damage or 0
        local wBulletsPerShot = wData.bulletsPerShot or 0
        local wRange = wData.range or 0
        local wSpread = wData.spread or 0
        local wPunchAngle = wData.punchAngle or 0
        local wTimeFireDelay = wData.timeFireDelay or 0
        local wTimeIdle = wData.timeIdle or 0
        local wTimeIdleEmpty = wData.timeIdleEmpty or 0
        local wTimeReloadStart = wData.timeReloadStart or 0
        local wTimeReload = wData.timeReload or 0
        local wDrawCrosshair = wData.drawCrosshair or 0
        local wProjectile = wData.projectile or 0
        local wAmmoPerShot = wData.ammoPerShot or 0
        local wProjectileSpeed = wData.projectileSpeed or 0
        local wSmackDelay = wData.smackDelay or 0
        local wUseRapidFireCrits = wData.useRapidFireCrits or false

        printc("0", "255", "0", "100", "Definition Name: " .. weaponDefName)
        print("Class: " .. weaponClass)
        print("Loadout Slot: " .. weaponLoadoutSlot)
        print("Hidden: " .. tostring(weaponHidden))
        print("Is Tool: " .. tostring(weaponIsTool))
        print("Is Base Item: " .. tostring(weaponIsBaseItem))
        print("Is Wearable: " .. tostring(weaponIsWearable))
        print("Type Name: " .. weaponTypeName)

        if weaponDescription then
            print("Description: " .. weaponDescription)
        else
            printc("255", "255", "0", "100",
                "Failed to get description. 'itemDefinition:GetDescription()' may not work for this item.")
        end

        if weaponIconName then
            print("Icon Name: " .. weaponIconName)
        else
            printc("255", "255", "0", "100",
                "Failed to get icon name. 'itemDefinition:GetIconName()' may not work for this item.")
        end

        print("Base Item Name: " .. weaponBaseNumber)
        print("Can Random Crit: " .. tostring(eCanCrit))

        printc("255", "0", "0", "100", "**m_iClip(1/2) for " .. weaponDefName .. ":**")
        print("Current " .. weaponName .. " weapon entity: " .. tostring(weaponEntity))
        print("Current Ammo in m_iClip1: " .. tostring(clip1))
        print("Current Ammo in m_iClip2: " .. tostring(clip2))

        printc("255", "0", "0", "100", "**Weapon Data for " .. weaponDefName .. ":**")
        print("Weapon Damage: " .. tostring(wDamage))
        print("Bullets Per Shot: " .. tostring(wBulletsPerShot))
        print("Range: " .. tostring(wRange))
        print("Spread: " .. tostring(wSpread))
        print("Punch Angle: " .. tostring(wPunchAngle))
        print("Time Fire Delay: " .. tostring(wTimeFireDelay))
        print("Time Idle: " .. tostring(wTimeIdle))
        print("Time Idle Empty: " .. tostring(wTimeIdleEmpty))
        print("Time Reload Start: " .. tostring(wTimeReloadStart))
        print("Time Reload: " .. tostring(wTimeReload))
        print("Draw Crosshair: " .. tostring(wDrawCrosshair))
        print("Projectile: " .. tostring(wProjectile))
        print("Ammo Per Shot: " .. tostring(wAmmoPerShot))
        print("Projectile Speed: " .. tostring(wProjectileSpeed))
        print("Smack Delay: " .. tostring(wSmackDelay))
        print("Use Rapid Fire Crits: " .. tostring(wUseRapidFireCrits))

        -- Check if IsShootingWeapon function exists and weapon is a shooting weapon
        local isShootingWeapon = false
        pcall(function()
            if weaponEntity.IsShootingWeapon then
                isShootingWeapon = weaponEntity:IsShootingWeapon()
            end
        end)

        if isShootingWeapon then
            printc("255", "0", "0", "100", "Shooting weapon info for " .. weaponDefName .. ":")

            local eType, eSpread, eSpeed, eGravity, ePSpread, eLoadoutSlotID, eWeaponID, eFlippedViewmodel

            pcall(function()
                if weaponEntity.GetWeaponProjectileType then
                    eType = weaponEntity:GetWeaponProjectileType()
                end
            end)
            eType = eType or "Unknown"

            pcall(function()
                if weaponEntity.GetWeaponSpread then
                    eSpread = weaponEntity:GetWeaponSpread()
                end
            end)
            eSpread = eSpread or 0

            pcall(function()
                if weaponEntity.GetProjectileSpeed then
                    eSpeed = weaponEntity:GetProjectileSpeed()
                end
            end)
            eSpeed = eSpeed or 0

            pcall(function()
                if weaponEntity.GetProjectileGravity then
                    eGravity = weaponEntity:GetProjectileGravity()
                end
            end)
            eGravity = eGravity or 0

            pcall(function()
                if weaponEntity.GetProjectileSpread then
                    ePSpread = weaponEntity:GetProjectileSpread()
                end
            end)
            ePSpread = ePSpread or 0

            pcall(function()
                if weaponEntity.GetLoadoutSlot then
                    eLoadoutSlotID = weaponEntity:GetLoadoutSlot()
                end
            end)
            eLoadoutSlotID = eLoadoutSlotID or -1

            pcall(function()
                if weaponEntity.GetWeaponID then
                    eWeaponID = weaponEntity:GetWeaponID()
                end
            end)
            eWeaponID = eWeaponID or -1

            pcall(function()
                if weaponEntity.IsViewModelFlipped then
                    eFlippedViewmodel = weaponEntity:IsViewModelFlipped()
                end
            end)
            eFlippedViewmodel = eFlippedViewmodel or false

            print("Projectile Type: " .. tostring(eType))
            print("Spread: " .. tostring(eSpread))
            print("Speed: " .. tostring(eSpeed))
            print("Gravity: " .. tostring(eGravity))
            print("Project Spread: " .. tostring(ePSpread))
            print("Loadout Slot ID: " .. tostring(eLoadoutSlotID))
            print("Weapon ID: " .. tostring(eWeaponID))
            print("Flipped Viewmodel: " .. tostring(eFlippedViewmodel))
        else
            printc("0", "255", "0", "100", weaponDefName .. " is not a shooting weapon.*********")
        end

        -- Check if IsMeleeWeapon function exists and weapon is a melee weapon
        local isMeleeWeapon = false
        pcall(function()
            if weaponEntity.IsMeleeWeapon then
                isMeleeWeapon = weaponEntity:IsMeleeWeapon()
            end
        end)

        if isMeleeWeapon then
            printc("255", "0", "0", "100", "Melee weapon info for " .. weaponDefName .. ":")

            local eSwingRange = 0
            pcall(function()
                if weaponEntity.GetSwingRange then
                    eSwingRange = weaponEntity:GetSwingRange()
                end
            end)

            local eSwingTrace
            pcall(function()
                if weaponEntity.DoSwingTrace then
                    eSwingTrace = weaponEntity:DoSwingTrace()
                end
            end)

            if eSwingTrace then
                local tEntity = eSwingTrace.entity
                local tEntityStr = tostring(tEntity or "nil")
                local tEntityPlayer = "false"

                pcall(function()
                    if tEntity and tEntity.IsPlayer then
                        tEntityPlayer = tostring(tEntity:IsPlayer())
                    end
                end)

                local tContents = eSwingTrace.contents or 0
                local tHitbox = eSwingTrace.hitbox or -1
                local tHitgroup = eSwingTrace.hitgroup or -1
                local tEntityName = "Unknown"

                pcall(function()
                    if tEntityPlayer == "true" and tEntity and tEntity.GetName then
                        tEntityName = tEntity:GetName() or "Unknown"
                    end
                end)

                print("Swing Range: " .. tostring(eSwingRange))

                if not tEntity or tEntityStr == "InvalidEntity" then
                    print("If swung, your melee weapon would hit nothing.")
                elseif tEntityPlayer == "false" then
                    print("If swung, your melee would not hit a player! You would hit an entity of class type: " ..
                        tostring(tEntity))
                elseif tEntityPlayer == "true" then
                    print("If swung, your melee would hit the player: " .. tostring(tEntityName))
                end

                print("Melee swing contents: " .. tostring(tContents))
                print("Melee swing hitbox: " .. tostring(tHitbox))
                print("Melee swing hitgroup: " .. tostring(tHitgroup))
            else
                print("Could not perform melee swing trace.")
                print("Swing Range: " .. tostring(eSwingRange))
            end
        else
            printc("0", "255", "0", "100", weaponDefName .. " is not a melee weapon.*********")
        end

        local function HealCheck(target)
            if not target or not weaponEntity.IsMedigunAllowedToHealTarget then
                return false
            end

            local canHeal = false
            pcall(function() canHeal = weaponEntity:IsMedigunAllowedToHealTarget(target) end)
            return canHeal
        end

        -- Check if IsMedigun function exists and weapon is a medigun
        local isMedigun = false
        pcall(function()
            if weaponEntity.IsMedigun then
                isMedigun = weaponEntity:IsMedigun()
            end
        end)

        if isMedigun then
            -- Target Check
            local tMe = entities.GetLocalPlayer()
            if tMe then
                local tSource
                pcall(function()
                    tSource = tMe:GetAbsOrigin() + tMe:GetPropVector("localdata", "m_vecViewOffset[0]")
                end)

                local tDestination
                pcall(function()
                    if engine and engine.GetViewAngles and tSource then
                        tDestination = tSource + engine.GetViewAngles():Forward() * 1000
                    end
                end)

                local tTrace
                pcall(function()
                    if engine and engine.TraceLine and tSource and tDestination then
                        tTrace = engine.TraceLine(tSource, tDestination, MASK_SHOT_HULL)
                    end
                end)

                local tVisTarget = tTrace and tTrace.entity or nil

                if tVisTarget then
                    local classStr = "Unknown"
                    pcall(function()
                        if tVisTarget.GetClass then
                            classStr = tVisTarget:GetClass()
                        end
                    end)

                    if not HealCheck(tVisTarget) then
                        print(classStr .. " is not healable.******************************")
                    else
                        local canHealVisTarget = HealCheck(tVisTarget)
                        print("Can heal visible target: " .. tostring(canHealVisTarget))
                    end
                    --Distance calculation if I want to add heal target distance check later: tTrace.fraction * 1000
                end

                printc("255", "0", "0", "100", "Medigun info for " .. weaponDefName .. ":")

                local eHealRate = 0
                pcall(function()
                    if weaponEntity.GetMedigunHealRate then
                        eHealRate = weaponEntity:GetMedigunHealRate()
                    end
                end)

                local eHealStickRange = 0
                pcall(function()
                    if weaponEntity.GetMedigunHealingStickRange then
                        eHealStickRange = weaponEntity:GetMedigunHealingStickRange()
                    end
                end)

                local eHealRange = 0
                pcall(function()
                    if weaponEntity.GetMedigunHealingRange then
                        eHealRange = weaponEntity:GetMedigunHealingRange()
                    end
                end)

                local HealSelf = tMe and HealCheck(tMe) or false
                local HealTarget = tVisTarget and HealCheck(tVisTarget) or false

                print("Heal Rate: " .. tostring(eHealRate))
                print("Heal Stick Range: " .. tostring(eHealStickRange))
                print("Heal Range: " .. tostring(eHealRange))
                print("Can Heal Self: " .. tostring(HealSelf))
                print("Can Heal Target: " .. tostring(HealTarget))
            end
        end
    end

    -- Get weapons - more aggressive approach
    local primaryWeaponEntity, secondaryWeaponEntity, meleeEntity

    -- Try standard method first
    pcall(function()
        if me.GetEntityForLoadoutSlot then
            primaryWeaponEntity = me:GetEntityForLoadoutSlot(LOADOUT_POSITION_PRIMARY)
            secondaryWeaponEntity = me:GetEntityForLoadoutSlot(LOADOUT_POSITION_SECONDARY)
            meleeEntity = me:GetEntityForLoadoutSlot(LOADOUT_POSITION_MELEE)
        end
    end)

    -- If not found, try to find weapons in the player's children entities
    if not primaryWeaponEntity or not secondaryWeaponEntity then
        printc("255", "255", "0", "100", "Some weapons not found by standard method, trying aggressive search...")

        -- Try to find weapons directly in the world
        pcall(function()
            local allWeapons = entities.FindByClass("CBaseCombatWeapon")
            for i, entity in ipairs(allWeapons) do
                local owner
                pcall(function() owner = entity:GetPropEntity("m_hOwnerEntity") end)

                if owner and owner == me then
                    -- Try to determine which slot this weapon belongs to
                    local slot = -1
                    pcall(function()
                        if entity.GetLoadoutSlot then
                            slot = entity:GetLoadoutSlot()
                        else
                            -- Try to get slot from definition
                            local defIndex
                            pcall(function() defIndex = entity:GetPropInt("m_iItemDefinitionIndex") end)
                            if defIndex and itemschema and itemschema.GetItemDefinitionByID then
                                local itemDef = itemschema.GetItemDefinitionByID(defIndex)
                                if itemDef then
                                    slot = itemDef:GetLoadoutSlot()
                                end
                            end
                        end
                    end)

                    if slot == 0 and not primaryWeaponEntity then
                        primaryWeaponEntity = entity
                        printc("0", "255", "0", "100", "Found primary weapon by entity search")
                    elseif slot == 1 and not secondaryWeaponEntity then
                        secondaryWeaponEntity = entity
                        printc("0", "255", "0", "100", "Found secondary weapon by entity search")
                    elseif slot == 2 and not meleeEntity then
                        meleeEntity = entity
                        printc("0", "255", "0", "100", "Found melee weapon by entity search")
                    end
                end
            end
        end)
    end

    -- Find all wearables - aggressive approach
    local wearables = {}
    local wearableClasses = {
        "CTFWearable", "CTFWearableDemoShield", "CTFWearableRobotArm",
        "CTFWearableItem", "CTFWearableCampaignItem", "CTFWearableRazorback",
        "CTFPowerupBottle", "CTFWearableLevelableItem"
    }

    -- First try to use GetWearables() if it exists
    pcall(function()
        if me.GetWearables then
            wearables = me:GetWearables() or {}
            printc("0", "255", "0", "100", "Found " .. #wearables .. " wearables using GetWearables()")
        end
    end)

    -- Fallback: try to find wearables by iterating through entities
    -- Add check for more wearable classes
    for _, className in ipairs(wearableClasses) do
        pcall(function()
            local items = entities.FindByClass(className)

            for i, entity in ipairs(items) do
                local owner
                pcall(function() owner = entity:GetPropEntity("m_hOwnerEntity") end)

                if owner and owner == me then
                    local isNew = true

                    -- Check if already in wearables list
                    for _, existing in ipairs(wearables) do
                        if existing == entity then
                            isNew = false
                            break
                        end
                    end

                    if isNew then
                        table.insert(wearables, entity)
                        printc("0", "255", "0", "100", "Found additional wearable of class " .. className)
                    end
                end
            end
        end)
    end

    -- More aggressive search - try to find ALL entities owned by player
    pcall(function()
        -- Try all entity indices
        for i = 1, 2048 do
            pcall(function()
                local entity = entities.GetByIndex(i)
                if entity and entity ~= me then
                    local owner
                    pcall(function() owner = entity:GetPropEntity("m_hOwnerEntity") end)

                    if owner and owner == me then
                        local class = "Unknown"
                        pcall(function() class = entity:GetClass() end)

                        -- Check if it's something we want to track
                        local shouldTrack = false

                        if string.find(class, "Wearable") or
                            string.find(class, "Item") or
                            string.find(class, "Shield") or
                            string.find(class, "Boots") or
                            string.find(class, "Bottle") then
                            shouldTrack = true
                        end

                        if shouldTrack then
                            -- Check if already in wearables list
                            local isNew = true
                            for _, existing in ipairs(wearables) do
                                if existing == entity then
                                    isNew = false
                                    break
                                end
                            end

                            if isNew then
                                table.insert(wearables, entity)
                                printc("0", "255", "0", "100",
                                    "Found additional wearable of class " .. class .. " by brute force")
                            end
                        end
                    end
                end
            end)
        end
    end)

    -- Check inventory (look for equipped items)
    local inventoryItems = {}
    pcall(function()
        if inventory and inventory.Enumerate then
            inventory.Enumerate(function(item)
                -- Get inventory item info
                local itemID, itemDefID, classID, slot

                pcall(function() itemID = item:GetItemID() end)
                pcall(function() itemDefID = item:GetDefinitionIndex() end)
                pcall(function()
                    if item.GetItemDefinition then
                        local itemDef = item:GetItemDefinition()
                        if itemDef and itemDef.GetID then
                            itemDefID = itemDef:GetID()
                        end
                    end
                end)

                -- Try to check various classes for equipment
                local isEquipped = false
                local classesToCheck = {
                    4, -- Demoman
                    1, -- Scout
                    8, -- Spy
                    9, -- Engineer
                    3, -- Soldier
                    2, -- Sniper
                    7, -- Medic
                    5, -- Heavy
                    6, -- Pyro
                }

                for _, classToCheck in ipairs(classesToCheck) do
                    pcall(function()
                        if item.IsEquipped and item:IsEquipped(classToCheck) then
                            isEquipped = true
                            classID = classToCheck
                        end
                    end)
                    if isEquipped then break end
                end

                if isEquipped then
                    pcall(function()
                        if item.GetLoadoutSlot then
                            slot = item:GetLoadoutSlot(classID)
                        end
                    end)

                    -- Try to get a loadout position even if GetLoadoutSlot fails
                    if not slot then
                        pcall(function()
                            if itemDefID and itemschema and itemschema.GetItemDefinitionByID then
                                local itemDef = itemschema.GetItemDefinitionByID(itemDefID)
                                if itemDef then
                                    slot = itemDef:GetLoadoutSlot()
                                end
                            end
                        end)
                    end

                    table.insert(inventoryItems, {
                        id = itemID,
                        defID = itemDefID,
                        classID = classID,
                        slot = slot,
                        definition = safeGetItemDefByID(itemDefID)
                    })

                    printc("0", "255", "0", "100", "Found equipped inventory item with ID " .. tostring(itemDefID))
                end
            end)
        end
    end)

    -- Output weapon info
    printc("255", "0", "0", "100", "**Weapon Ammo Info:**")
    if primaryWeaponEntity then
        printWeaponAmmoInfo(primaryWeaponEntity, "primary")
    else
        print("No primary weapon entity found.")
    end

    if secondaryWeaponEntity then
        printWeaponAmmoInfo(secondaryWeaponEntity, "secondary")
    else
        print("No secondary weapon entity found.")
    end

    if meleeEntity then
        printWeaponAmmoInfo(meleeEntity, "melee")
    else
        print("No melee weapon entity found.")
    end

    -- Output wearables info
    printc("255", "0", "0", "100", "**Wearables Info:**")
    if #wearables > 0 then
        print("Found " .. #wearables .. " wearable items")
        for i, wearable in ipairs(wearables) do
            local info = getItemInfo(wearable)
            printItemInfo(info, "Wearable " .. i)
            dumpEntityProps(wearable, "Wearable " .. i) -- Dump all properties for debugging
        end
    else
        print("No wearables found.")
    end

    -- Output inventory items info
    printc("255", "0", "0", "100", "**Equipped Inventory Items:**")
    if #inventoryItems > 0 then
        print("Found " .. #inventoryItems .. " equipped inventory items")
        for i, item in ipairs(inventoryItems) do
            local hasValidInfo = false

            -- Check if item has any valid information
            if item.id or item.defID or (item.definition and item.definition:GetName() ~= "Unknown") then
                hasValidInfo = true
            end

            if hasValidInfo then
                print("Inventory Item " .. i .. ":")

                if item.id then
                    print("  ID: " .. tostring(item.id))
                end

                if item.defID then
                    print("  Definition ID: " .. tostring(item.defID))
                end

                if item.classID then
                    print("  Class ID: " .. tostring(item.classID))
                end

                if item.slot and item.slot >= 0 then
                    print("  Slot: " .. tostring(item.slot))
                end

                if item.definition then
                    pcall(function()
                        local name = item.definition:GetName()
                        if name and name ~= "Unknown" then
                            print("  Name: " .. tostring(name))
                        end

                        local typeName = item.definition:GetTypeName()
                        if typeName and typeName ~= "Unknown" then
                            print("  Type: " .. tostring(typeName))
                        end

                        if item.definition.GetDescription then
                            local desc = item.definition:GetDescription()
                            if desc and desc ~= "" then
                                print("  Description: " .. tostring(desc))
                            end
                        end
                    end)
                end
                print("")
            end
        end
    else
        print("No equipped inventory items found.")
    end

    -- Try to get loadout specific info from the class
    printc("255", "0", "0", "100", "**Class Loadout Info:**")
    pcall(function()
        -- Try to get information directly from player loadout slots - more aggressive with more slots
        for i = 0, 20 do -- Try more slots than standard
            -- Try multiple methods of slot access
            local entity
            pcall(function()
                if me.GetEntityForLoadoutSlot then
                    entity = me:GetEntityForLoadoutSlot(i)
                end
            end)

            -- Try alternative access if normal fails
            if not entity then
                pcall(function()
                    -- Try brute force method - try to look up in entity tables
                    local allEntities = entities.FindByClass("CTFWearable*")
                    for _, wearableEntity in ipairs(allEntities) do
                        local defIndex
                        pcall(function() defIndex = wearableEntity:GetPropInt("m_iItemDefinitionIndex") end)

                        if defIndex then
                            local itemDef = safeGetItemDefByID(defIndex)
                            if itemDef then
                                local slot
                                pcall(function() slot = itemDef:GetLoadoutSlot() end)

                                if slot == i then
                                    entity = wearableEntity
                                    printc("0", "255", "0", "100",
                                        "Found item for slot " .. i .. " by brute force item def lookup")
                                end
                            end
                        end
                    end
                end)
            end

            if entity then
                local info = getItemInfo(entity)
                if info and info.name then
                    print("Loadout Slot " .. i .. ": " .. tostring(info.name))

                    -- Try to check if this might be a shield or boots (for demoman)
                    local class = pcall(function() return entity:GetClass() end) and entity:GetClass() or "Unknown"
                    if string.find(class, "Shield") or (info.typeName and string.find(tostring(info.typeName), "Shield")) then
                        printc("255", "128", "0", "100", "Found shield item: " .. tostring(info.name))
                        -- Dump more details on shields
                        dumpEntityProps(entity, "Shield Item Details")
                    elseif string.find(class, "Boots") or (info.typeName and string.find(tostring(info.typeName), "Boots")) then
                        printc("255", "128", "0", "100", "Found boots item: " .. tostring(info.name))
                        -- Dump more details on boots
                        dumpEntityProps(entity, "Boots Item Details")
                    end
                end
            end
        end
    end)

    -- Extra aggressive item search as a last resort - only print meaningful results
    printc("255", "0", "0", "100", "**Last Resort Item Search:**")
    pcall(function()
        -- Try brute force by ID ranges for common demo items
        local knownDemoItemIds = {
            -- Primary weapons
            308,  -- Loch-n-Load
            996,  -- Loose Cannon
            1151, -- Iron Bomber
            405,  -- Ali Baba's Wee Booties
            608,  -- Bootlegger

            -- Secondary weapons
            130,  -- Scottish Resistance
            131,  -- Chargin' Targe
            265,  -- Sticky Jumper
            406,  -- Splendid Screen
            1099, -- Tide Turner
            1150, -- Quickiebomb Launcher

            -- Melee weapons
            132, -- Eyelander
            172, -- Scotsman's Skullcutter
            266, -- Claidheamh Mòr
            307, -- Ullapool Caber
            327, -- Half-Zatoichi
            404, -- Persian Persuader
            482  -- Nessie's Nine Iron
        }

        local foundAnyItems = false
        for _, itemId in ipairs(knownDemoItemIds) do
            local itemDef = safeGetItemDefByID(itemId)
            if itemDef then
                local itemName = "Unknown"
                pcall(function() itemName = itemDef:GetName() end)

                -- Only proceed if we got a valid name
                if itemName and itemName ~= "Unknown" then
                    local itemSlot = -1
                    pcall(function() itemSlot = itemDef:GetLoadoutSlot() end)
                    local itemType = "Unknown"
                    pcall(function() itemType = itemDef:GetTypeName() end)

                    local infoString = "Known Demo Item ID " .. itemId .. ": " .. itemName

                    -- Only add slot if valid
                    if itemSlot and itemSlot >= 0 then
                        infoString = infoString .. " (Slot: " .. itemSlot

                        -- Only add type if valid and slot was valid
                        if itemType and itemType ~= "Unknown" then
                            infoString = infoString .. ", Type: " .. itemType
                        end

                        infoString = infoString .. ")"
                    end

                    print(infoString)
                    foundAnyItems = true

                    -- See if this item is equipped
                    if inventory and inventory.GetItemInLoadout then
                        local classId = 4 -- Demoman class ID
                        pcall(function()
                            local equippedItem = inventory.GetItemInLoadout(classId, itemSlot)
                            if equippedItem then
                                local equippedId = -1
                                pcall(function() equippedId = equippedItem:GetDefinitionIndex() end)

                                if equippedId == itemId then
                                    printc("255", "255", "0", "100", "FOUND EQUIPPED: " .. itemName)
                                end
                            end
                        end)
                    end
                end
            end
        end

        if not foundAnyItems then
            print("No known demo items found in database")
        end
    end)
else
    print("Local player entity not found.")
end
