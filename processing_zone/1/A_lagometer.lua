local verdana = draw.CreateFont("Verdana", 17, 500)
local fps, frameCount, frameTime, frameInterval, minFps, maxFps, fpsMax = 0, 0, 0, 10, math.huge, 0, 300 
local lagometerData = {}
local lagometerIndex = 1
local screenWidth, screenHeight = draw.GetScreenSize()
local lagometerX, lagometerY = 5, screenHeight / 1.6
local lagometerWidth, lagometerHeight, maxLatency = 200, 200, 1000

local function addLagometerData(lagometer_data, latency_in, latency_out, current_fps, frame_time)
    -- Normalize the latencies
    latency_in = latency_in / maxLatency
    latency_out = latency_out / maxLatency

    table.insert(lagometer_data, 1, { latency_in = latency_in, latency_out = latency_out, current_fps = current_fps, frame_time = frame_time })

    -- Trim the lagometer data if it exceeds the lagometer width
    if #lagometer_data > lagometerWidth then
        table.remove(lagometer_data)
    end
end

local function drawLagometer(lagometer_data)
    local lagometerHalfHeight = lagometerHeight / 2
    local red_color = { 255, 0, 0, 255 }
    local yellow_color = { 255, 255, 0, 255 }
    local blue_color = { 0, 0, 255, 255 }
    local green_color = { 0, 255, 0, 255 }

    local x_offset = lagometerWidth - #lagometer_data + 1
    for i, data in ipairs(lagometer_data) do
        local x = lagometerX + x_offset + i - 1
        local y_latency_in = math.floor(lagometerY + lagometerHeight - (data.latency_in * lagometerHeight))
        local y_latency_out = math.floor(lagometerY + lagometerHeight - (data.latency_out * lagometerHeight))

        -- Determine the higher and lower latency values
        -- This shit so stupid but I cba
        local higher_latency, lower_latency, higher_color, lower_color
        if y_latency_in > y_latency_out then
            higher_latency, lower_latency, higher_color, lower_color = y_latency_in, y_latency_out, yellow_color, red_color
        else
            higher_latency, lower_latency, higher_color, lower_color = y_latency_out, y_latency_in, red_color, yellow_color
        end

        -- Draw the lower latency line first
        draw.Color(table.unpack(lower_color))
        draw.Line(x, lagometerY + lagometerHeight, x, lower_latency)

        -- Draw the higher latency line on top
        draw.Color(table.unpack(higher_color))
        draw.Line(x, lagometerY + lagometerHeight, x, higher_latency)

        local y_frame_time = math.floor(lagometerY + lagometerHalfHeight - (data.frame_time / fpsMax * lagometerHalfHeight))
        local y_fps = math.floor(lagometerY + lagometerHalfHeight - (data.current_fps / fpsMax * lagometerHalfHeight))

        -- Draw fps line (bottom graph)
        draw.Color(table.unpack(blue_color))
        draw.Line(x, lagometerY + lagometerHalfHeight, x, y_fps)

        -- Draw frame_time line (top graph)
        draw.Color(table.unpack(green_color))
        draw.Line(x, lagometerY + lagometerHalfHeight, x, y_frame_time)
    end

    -- Draw lagometer background
    draw.Color(0, 0, 0, 190)
    draw.FilledRect(lagometerX, lagometerY, lagometerX + lagometerWidth, lagometerY + lagometerHeight)
end

local function OnDraw()
    frameCount = globals.FrameCount()
    local latencyIn, latencyOut = clientstate.GetLatencyIn() * 1000, clientstate.GetLatencyOut() * 1000 -- Convert to ms
    local latency = latencyIn + latencyOut

    -- Every 10 frames. NGL atm if frameInterval is lower than like 100 you'll get hitches. I think it has to do with the way I'm handling the lagometerData table.
    if frameCount % frameInterval == 0 then
        frameTime = globals.FrameTime() * 1000
        fps = math.floor(1000 / frameTime)
        minFps = math.min(minFps, fps)
        maxFps = math.max(maxFps, fps)
        addLagometerData(lagometerData, latencyIn, latencyOut, fps, frameTime)
        frameCount = 0 --I think this fixes the outofmemory crash but idk yet
    end

    draw.SetFont(verdana)
    draw.Color(255, 255, 255, 255)
    draw.Text(5, 5, "[fps: " .. fps .. " | min fps: " .. minFps .. " | max fps: " .. maxFps .. "]")
    draw.Text(5, 25, "[ping: " .. math.floor(latency) .. "ms | frame time: " .. math.floor(frameTime) .. "ms]")
    draw.Color(0, 0, 0, 190)
    draw.FilledRect(lagometerX, lagometerY, lagometerX + lagometerWidth, lagometerY + lagometerHeight)
    drawLagometer(lagometerData)
end
callbacks.Unregister("Draw", "LAG_Draw")
callbacks.Register("Draw", "LAG_Draw", OnDraw)
