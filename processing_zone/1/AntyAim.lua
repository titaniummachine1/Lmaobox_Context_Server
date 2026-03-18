
local menuLoaded, MenuLib = pcall(require, "Menu")                               
assert(menuLoaded, "MenuLib not found, please install it!")                       
assert(MenuLib.Version >= 1.44, "MenuLib version is too old, please update it!") 

--[[ Menu ]]--
local menu = MenuLib.Create("Anti Aim lua for Lmaobox", MenuFlags.AutoSize)
menu.Style.TitleBg = { 125, 155, 255, 255 } 
menu.Style.Outline = true                

local RandomToggle  = menu:AddComponent(MenuLib.Checkbox("Random Yaw", true))
local Antioverlap   = menu:AddComponent(MenuLib.Checkbox("anti overlap", true))

local FakeLagToggle = menu:AddComponent(MenuLib.Checkbox("Random Fake Lag", false))
local MinFakeLag    = menu:AddComponent(MenuLib.Slider("Fake Lag Min Value", 1 ,22 , 14 ))
local MaxFakeLag    = menu:AddComponent(MenuLib.Slider("Fake Lag Max Value", 1 ,22 , 22 ))

local JitterToggle  = menu:AddComponent(MenuLib.Checkbox("(Yaw) Jitter", false))
local JitterReal    = menu:AddComponent(MenuLib.Slider("Real Angle Jitter", -180 ,180 , 140 ))
local JitterFake    = menu:AddComponent(MenuLib.Slider("Fake Angle Jitter", -180 ,180 , 170 ))

local OffsetSpinToggle  = menu:AddComponent(MenuLib.Checkbox("(Yaw) Offset Spin", false))
local RealOffset    = menu:AddComponent(MenuLib.Slider("Real Angle Offset", 0 ,180 , 65 ))

local SemiSpinToggle  = menu:AddComponent(MenuLib.Checkbox("(Yaw) Semi Spin (broken)", false))
local SemiSpinOffset    = menu:AddComponent(MenuLib.Slider("Spin Angle", -179 ,180 , 50 ))
local SemiSpinRealOffset    = menu:AddComponent(MenuLib.Slider("Real Angle Offset", -180 ,180 , 50 ))



local function script()
  if RandomToggle:GetValue() == true then

    gui.SetValue("Anti Aim - Custom Yaw (Real)", math.random(-180, 180 ))
    gui.SetValue("Anti Aim - Custom Yaw (Fake)", math.random(-180, 180 ))

    gui.SetValue("Anti Aim - Pitch", "Custom")

    if FakeAngle == RealAngle then 
      RealAngle = somethingElse
      end

    local number = math.random(1,3)
    if number == 1 then 
      gui.SetValue("Anti Aim - Pitch", 2)
    elseif number == 2 then
      gui.SetValue("Anti Aim - Pitch", 4)
    else
        local pitch = math.random(40, 80)
      pitch = -pitch
      gui.SetValue("Anti Aim - Custom Pitch (Real)", pitch)
    end
    --gui.SetValue("Anti Aim - Custom Pitch (Real)", math.random(-90, 90 ))

  end

    if FakeLagToggle:GetValue() == true then
          ticks = math.random(MinFakeLag.Value, MaxFakeLag.Value) * 15
    end

    if JitterToggle:GetValue() == true then
            if gui.GetValue( "Anti Aim - Custom Yaw (Real)" ) == JitterReal.Value then
                gui.SetValue( "Anti Aim - Custom Yaw (Real)", JitterFake.Value)
                gui.SetValue( "Anti Aim - Custom Yaw (Fake)", JitterReal.Value)
            else 
                gui.SetValue( "Anti Aim - Custom Yaw (Real)", JitterReal.Value)
                gui.SetValue( "Anti Aim - Custom Yaw (Fake)", JitterFake.Value)
            end
        
            gui.SetValue( "Anti Aim - Custom Yaw (Real)", -JitterReal.Value)
            gui.SetValue( "Anti Aim - Custom Yaw (Fake)", -JitterFake.Value)
    end

    if OffsetSpinToggle:GetValue() == true then
        
        gui.SetValue( "Anti Aim - Custom Yaw (fake)", gui.GetValue( "Anti Aim - Custom Yaw (fake)" ) + 1)

        if (gui.GetValue( "Anti Aim - Custom Yaw (fake)") == 180) then 
          gui.SetValue( "Anti Aim - Custom Yaw (fake)", -180)
        end
      
        gui.SetValue( "Anti Aim - Custom Yaw (real)", gui.GetValue( "Anti Aim - Custom Yaw (fake)") - RealOffset.Value)

    end

    if SemiSpinToggle:GetValue() == true then

        gui.SetValue( "Anti Aim - Custom Yaw (fake)", gui.GetValue( "Anti Aim - Custom Yaw (fake)" ) + 1)

        if (gui.GetValue("Anti Aim - Custom Yaw (fake)") == SemiSpinOffset.Value) then
          gui.SetValue( "Anti Aim - Custom Yaw (fake)", (SemiSpinOffset.Value - 100))
        end
      
        gui.SetValue( "Anti Aim - Custom Yaw (real)", gui.GetValue( "Anti Aim - Custom Yaw (fake)") - SemiSpinRealOffset.Value)
    end
end

local function OnUnload()
    MenuLib.RemoveMenu(menu)
    client.Command('play "ui/buttonclickrelease"', true)
end

callbacks.Unregister("Unload", "MCT_Unload")                   
callbacks.Unregister("CreateMove", "MCT_CreateMove")            

callbacks.Register("Unload", "MCT_Unload", OnUnload)                        
callbacks.Register( "Draw", "MCT_Script", script )