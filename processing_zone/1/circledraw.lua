-- +---------------------+
-- |  Settings - circle  |
-- +=====================+
circle = {
    color       = Color(1,1,1), -- RGB color of the circle
    opacity     = 1.0,  -- Opacity of the circle
    radius      = 1,    -- Radius of the circle around the object
    show        = true, -- Should the circle be shown by default?
    steps       = 32,   -- Number of segments that make up the circle
    thickness   = 0.2,  -- Thickness of the circle line
    vert_offset = 0.05, -- Vertical height of the circle relative to the object
}
-- +---------------------------+
-- |  Function - toggleCircle  |
-- +===========================+
function toggleCircle()
  -- Toggle circle state
 circle.show = not circle.show
  -- Draw/Clear the circle depending on state
  if circle.show then drawCircle() else clearCircle() end
end
-- +-------------------------+
-- |  Function - drawCircle  |
-- +=========================+
function drawCircle()
  -- Update circle state
  circle.show = true
  -- Draw circle vector-lines
  self.setVectorLines({
    {
      points    = getCircleVectorPoints(circle.radius, circle.steps, circle.vert_offset),
      color     = circle.color,
      thickness = circle.thickness,
      rotation  = {0,-90,0},
    }
  })
end
-- +--------------------------+
-- |  Function - clearCircle  |
-- +==========================+
function clearCircle()
  -- Update circle state
  circle.show = false
  -- Clear vector-lines
  self.setVectorLines({})
end
-- +------------------------------------+
-- |  Function - getCircleVectorPoints  |
-- +====================================+
function getCircleVectorPoints(radius, steps, y)
    -- Initialise
    local t = {}
    local d,s,c,r = 360/steps, math.sin, math.cos, math.rad
    -- Create points
    for i = 0,steps do
        table.insert(t, {
            c(r(d*i))*radius,
            y,
            s(r(d*i))*radius
        })
    end
    -- Return
    return t
end