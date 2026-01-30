local t = {}
t.time = 0
function dotimer(dt,interval,start) --delay
	if start == true then
		t.time = t.time + dt
		if t.time >= interval then
			t.time = t.time - interval    --reset timer
			return true
		else
			return false
		end
	else
		t.time = 0
	end

end

callbacks.Register( 'CreateMove', function()
	local localplayer = entities.GetLocalPlayer()
	local charge = false
	if warp.GetChargedTicks() ~= 23 then --if cannot dt/warp
		charge = true
		if dotimer(0.16,10,charge) then --default delay time is 10(ms), u can change to whatever u prefer (less than 10 may broke DT)
			warp.TriggerCharge()
		end
	else
		charge = false
	end

end)
