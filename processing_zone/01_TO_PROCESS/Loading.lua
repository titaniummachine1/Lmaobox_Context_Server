local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")

local Fonts = Lib.UI.Fonts

-- Tworzenie tekstury 2x2 (białej) dla kolorowania pierścienia
local textureData = string.char(
    0xFF, 0xFF, 0xFF, 255,
    0xFF, 0xFF, 0xFF, 255,
    0xFF, 0xFF, 0xFF, 255,
    0xFF, 0xFF, 0xFF, 255
)
local texture = draw.CreateTextureRGBA(textureData, 2, 2)

-- Funkcja do rysowania otwartego pierścienia
local function DrawOpenRingSegmented(originX, originY, radiusOuter, radiusInner, percentage, numSegments, gapAngle, r, g, b, a)
    -- Ograniczenie procenta między 0 a 100
    percentage = math.max(0, math.min(percentage, 100))

    -- Przekształcenie procentu na radiany (0 do 2π - gap)
    local startAngle = -math.pi / 2  -- Start od góry (12:00)
    local totalAngle = (percentage / 100) * ((2 * math.pi) - gapAngle)
    local endAngle = startAngle + totalAngle

    -- Ustaw kolor przed rysowaniem
    draw.Color(r, g, b, a)

    -- Ustalanie kąta dla każdego segmentu
    local angleStep = (endAngle - startAngle) / numSegments

    -- Rysowanie segmentów
    for i = 0, numSegments - 1 do
        local angle1 = startAngle + i * angleStep
        local angle2 = startAngle + (i + 1) * angleStep
        if angle2 > endAngle then angle2 = endAngle end

        -- Obliczanie wierzchołków na zewnętrznej krawędzi
        local xOuter1 = math.floor(originX + radiusOuter * math.cos(angle1) + 0.5)
        local yOuter1 = math.floor(originY + radiusOuter * math.sin(angle1) + 0.5)
        local xOuter2 = math.floor(originX + radiusOuter * math.cos(angle2) + 0.5)
        local yOuter2 = math.floor(originY + radiusOuter * math.sin(angle2) + 0.5)

        -- Obliczanie wierzchołków na wewnętrznej krawędzi
        local xInner1 = math.floor(originX + radiusInner * math.cos(angle1) + 0.5)
        local yInner1 = math.floor(originY + radiusInner * math.sin(angle1) + 0.5)
        local xInner2 = math.floor(originX + radiusInner * math.cos(angle2) + 0.5)
        local yInner2 = math.floor(originY + radiusInner * math.sin(angle2) + 0.5)

        -- Rysowanie segmentu jako czterokąt (quad)
        local quad = {
            { xOuter1, yOuter1, 0, 0 },
            { xOuter2, yOuter2, 1, 0 },
            { xInner2, yInner2, 1, 1 },
            { xInner1, yInner1, 0, 1 },
        }
        draw.TexturedPolygon(texture, quad, true)
    end
end

-- Funkcja do renderowania pierścienia ładowania
local percentage = 0  -- Początkowy procent wypełnienia
local increasing = true  -- Kierunek zmiany procentu

function RenderLoadingCircle()
    local screenW, screenH = draw.GetScreenSize()

    -- Definiowanie środka (centrum ekranu)
    local originX = math.floor(screenW / 2)
    local originY = math.floor(screenH / 2)

    -- Definiowanie promieni zewnętrznego i wewnętrznego
    local radiusOuter = 100  -- Zewnętrzny promień pierścienia
    local radiusInner = 80   -- Wewnętrzny promień pierścienia (kontroluje grubość)

    -- Liczba segmentów (ustawienie dla płynności i wydajności)
    local numSegments = 50  -- Więcej segmentów = gładszy pierścień

    -- Definiowanie przerwy, aby pierścień był otwarty
    local gapAngle = 0.15  -- Regulacja dla kontroli wielkości przerwy (w radianach)

    -- Rysowanie pierścienia z przerwą, w oparciu o procent
    DrawOpenRingSegmented(originX, originY, radiusOuter, radiusInner, percentage, numSegments, gapAngle, 255, 165, 0, 255)  -- Kolor pomarańczowy

    -- Aktualizacja procentu dla animacji
    if increasing then
        percentage = percentage + 0.5  -- Zmienna prędkość wypełniania
        if percentage >= 100 then
            percentage = 100
            increasing = false
        end
    else
        percentage = percentage - 0.5
        if percentage <= 0 then
            percentage = 0
            increasing = true
        end
    end

    -- Opcjonalnie: Wyświetlanie procentu jako tekst
    draw.SetFont(Fonts.Verdana)
    draw.Color(255, 255, 255, 255)
    local text = string.format("%d%%", math.floor(percentage))
    local textWidth, textHeight = draw.GetTextSize(text)
    draw.Text(math.floor(originX - textWidth / 2), math.floor(originY - textHeight / 2), text)
end

-- Rejestracja funkcji RenderLoadingCircle w callbacku 'Draw'
callbacks.Register("Draw", "RenderLoadingCircleCallback", RenderLoadingCircle)
