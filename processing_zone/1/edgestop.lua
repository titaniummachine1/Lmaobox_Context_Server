

  local function preventFalling()
    local player = getPlayer() -- get the player object
    local position = player:getAbsOrigin() -- get the player's current position
    local mapSize = getMapSize() -- get the size of the map
    local move = getMove() -- get the player's current movement inputs
    
    local function isOnObstacle(x, y)
        local worldPos = Vector(x, y, 0) -- create a Vector object with the x and y coordinates and a z value of 0
        local mapPos = worldToMap(worldPos) -- convert the world position to a map position
        local navPos = mapToWorld(mapPos) -- convert the map position back to a world position
        return navPos.z ~= 0 -- return true if the z position of the nav position is not 0, indicating that it is on an obstacle
      end
    
    if position.x < 0 or isOnObstacle(position.x, position.y) then -- if the player is too far to the left or on an obstacle
      move.x = 0 -- set the player's x movement to 0
    elseif position.x > mapSize.x or isOnObstacle(position.x, position.y) then -- if the player is too far to the right or on an obstacle
      move.x = 0 -- set the player's x movement to 0
    end
    
    if position.y < 0 or isOnObstacle(position.x, position.y) then -- if the player is too far down or on an obstacle
      move.y = 0 -- set the player's y movement to 0
    elseif position.y > mapSize.y or isOnObstacle(position.x, position.y) then -- if the player is too far up or on an obstacle
      move.y = 0 -- set the player's y movement to 0
    end
    
    setMove(move) -- set the player's movement inputs to the modified values
  end
  
  callbacks.Register("CreateMove", preventFalling) -- register the callback to be executed every frame