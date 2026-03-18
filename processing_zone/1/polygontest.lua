
-- Create a simple 2x2 texture for coloring the polygon
local texture = draw.CreateTextureRGBA(string.char(
 0xff, 0xff, 0xff, 255, --255 is alpha rest is magic XD
 0xff, 0xff, 0xff, 255,
 0xff, 0xff, 0xff, 255,
 0xff, 0xff, 0xff, 255
), 2, 2)

 -- Ensure the texture is deleted after use
 --draw.DeleteTexture(texture)

-- Function to draw a polygon given a list of vertices (offsets) and origin
function DrawPolygon(originX, originY, vertices, r, g, b, a)
 -- Adjust vertices based on the origin position
 local adjustedVertices = {}
 for i, vertex in ipairs(vertices) do
 local adjustedX = originX + vertex[1] -- X offset from the origin
 local adjustedY = originY + vertex[2] -- Y offset from the origin
 table.insert(adjustedVertices, {adjustedX, adjustedY, 0, 0}) -- Add adjusted vertex
 end

 --remember to alwasy set color before drawing its like takign the pain on brush
 draw.Color(r, g, b, a)

 -- Draw the polygon using the provided vertices and texture
 draw.TexturedPolygon(texture, adjustedVertices, false)
end

-- Example usage of vertices (these are offsets from the origin)
local vertices = {
 {0, 0}, -- First vertex (offset from origin)
 {50, 10},
 {100, 50}, -- Second vertex (offset from origin)
 {75, 100}, -- Third vertex (offset from origin)
 {25, 100}, -- Fourth vertex (offset from origin)
}

-- Function to render the polygon
function RenderPolygon()
 local screenW, screenH = draw.GetScreenSize()

 -- Define the origin (where you want the polygon to be drawn)
 --remember to do math floor so we always have intiger value used for drawing
 local originX = math.floor(screenW / 2)
 local originY = math.floor(screenH / 2)

 -- Draw the polygon at the specified origin with an orange color
 DrawPolygon(originX, originY, vertices, 255, 165, 0, 255) -- Orange color
end

-- Register the named function to the 'Draw' callback for rendering
callbacks.Register("Draw", "RenderPolygonCallback", RenderPolygon)

