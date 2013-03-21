
-- local t = trackable( turtle )

local makeRepeat = function( fn )
	return function( t, n )
		if n == nil then n = 1 end

		for i = 1, n do
			if false == t( fn ) then return i - 1 end
		end
		return n
	end
end

function digMove( t, n )

    for i = 1, n do
        if not t( 'forward' ) then
            t( 'dig' )

            if not t( 'forward' ) then
                return false
            end
        end

        t( 'digUp' )
    end

    return true
end

local forward = makeRepeat( 'forward' )
local back = makeRepeat( 'back' )
local left = makeRepeat( 'turnLeft' )
local right = makeRepeat( 'turnRight' )
local up = makeRepeat( 'up' )
local down = makeRepeat( 'down' )

function goback( t, state )
	if state.z > 0 then
		down( t, state.z )
	else
		up( t, -state.z )
	end
	
	left( t, state.dir )
	if state.y > 0 then
		forward( t, state.y )
	else
		back( t, -state.y )
	end

	left( t )

	if state.x > 0 then
		forward( t, state.x )
	else
		back( t, -state.x )
	end

	right( t )
end

function _gotocoord( t, map, xf,yf,zf, x, y, z )

    if z == nil then
        x, y, z = xf, yf, zf
        xf, yf, zf = 0, 0, 0
    end
    DStarLite( {xf, yf, zf, 0}, {x, y, z, 0}, map, function( v, cost, i )
        return CoordMove( t, v, cost, i )
    end)
end

local gotocoord

function mine( t, shaftRad, maxDepth, maxShafts, underground, mapfile )
    local xoff = 0
    local yoff = 10
    local map = nil
    local startState = t( 'getState' )

    if mapfile then
        map = loadmap( t, mapfile )
    else
        map = NodeMap()
        savemap( t, map, mapfile )
    end

    gotocoord = function( t, xf, yf, zf, x, y, z )
        _gotocoord( t, nil, xf, yf, zf, x, y, z )
    end

    for shaftNum = 0, maxShafts do
        fuelTopOff( t )

        mineOne( t, xoff, yoff, shaftRad, maxDepth, underground )

        local state = t( 'getState' )
        while state.dir ~= startState.dir do
            t( 'turnLeft' )
            state = t( 'getState' )
        end
        fuelTopOff( t )
        emptyInventory( t )

        savemap( t, map, mapfile )

        if xoff < 0 then
            xoff = -xoff
        else
            xoff = -xoff - ( 2 * shaftRad + 1 )
        end
    end
end

function savemap( t, m, file )
    if file == nil then
        file = '/john/data/mine.map'
    end
    local fh = fs.open( file, 'w' )
    local ts = t( 'getState' )

    fh.write( ts.x..'\n'..ts.y..'\n'..ts.z..'\n'..ts.dir..'\n' )

    for i, n in m.each() do
        fh.write( n:serialize().. '\n' )
    end

    fh.close()
end

function loadmap( t, file )
    if file == nil then
        file = '/john/data/mine.map'
    end
    local fh = fs.open( file, 'r' )
    local map = NodeMap()
    if not fh then
        t( 'setState', 0, 0, 0, 0 )
        return map
    end

    local x, y, z, dir = fh.readLine(), fh.readLine, fh.readLine, fh.readLine
    t( 'setState', tonumber( x ), tonumber( y ), tonumber( z ), tonumber( dir ) )

    local line = fh.readLine()
    while line do
        map.add( Node( line ) )
        line = fh.readLine()
    end
    fh.close()
    
    return map
end

-- assumes slot 1 has fuel.  Never uses the last one.
function fuelTopOff( t )
    local minFuel = 1000
    local cur = t( 'getFuelLevel' )

    for i = 2, 16 do
        t( 'select', i )

        if cur >= minFuel then
            return
        end

        while cur < minFuel and t( 'refuel', 1 ) do
            cur = t( 'getFuelLevel' )
        end
    end

    if cur < minFuel then
        t( 'select', 1 )
        while t( 'getItemCount', 1 ) > 1 and cur < minFuel and t( 'refuel', 1 ) do
            cur = t( 'getFuelLevel' )
        end
    end

    if cur < minFuel then
        return false
    end

    return true
end

function emptyInventory( t )

    -- first slot is fuel I'm expecting to find.  leave one there.
    t( 'select', 1 )
    t( 'drop', t( 'getItemCount', 1 ) - 1 )

    for i = 2, 16 do
        t( 'select', i )
        t( 'drop' )
    end
end

function mineOne( t, xoff, yoff, shaftRad, maxDepth, underground )
	left( t, 2 )

    if underground then
        if not digMove( t, yoff ) then
            print( 'Could not move to dig site' )
            return false
        end
    else
        drive( t, yoff )
    end

    if xoff > 0 then
        t( 'turnRight' )
    else
        t( 'turnLeft' )
    end

    digMove( t, math.abs( xoff ) )

	--t( 'pushState' )
	shaft( t, shaftRad, math.floor( maxDepth / 2 ) )

	--local undo = t( 'popState' )
    local state = t( 'getState' )
    gotocoord( t, state.x, state.y, state.z, 0, 0, 0 )

    do return end

	left( t, 2 )

	-- move out of the shaft so drive() doesn't drop us back down
	forward( t, shaftRad )
	
	drive( t, 10 - shaftRad )
end

function shaft( t, rad, depth )

	if depth < 1 then
		return true
	end

	--t( 'pushState' )

	t( 'digDown' )
	t( 'down' )
    local hitbedrock = false
    local refuel = false
	
	local ret = spiralDo( t, rad, function()
        if t( 'detect' ) and not t( 'dig' ) or t( 'detectDown' ) and not t( 'digDown' ) then
            hitbedrock = true
            return false
        end

        if t( 'getFuelLevel' ) < 100 then
            -- running low on fuel.  try to go home and refuel.
            local state = t( 'getState' )
            gotocoord( t, state.x, state.y, state.z, 0, 0, 0 )
            if not fuelTopOff( t ) then
                return false
            end
            emptyInventory( t )
            gotocoord( t, 0, 0, 0, state.x, state.y, state.z )
            local newstate = t( 'getState' )
            while newstate.dir ~= state.dir do
                t( 'turnRight' )
                newstate = t( 'getState' )
            end
        end
        return true
	end)

	t( 'digDown' )

	if ret == false then
		t( 'up' )
		--local undo = t( 'popState' )
		-- undo should now have the coordinates the turtle moved
		-- to since starting the shaft.  Use that to move
		-- back to the center and up the correct distance
		--goback( t, undo )
		return false
	end

	t( 'turnLeft' )

	forward( t, rad )
	t( 'turnRight' )
	back( t, rad )
	t( 'down' )

	-- merge this layer with the total history of the turtle
	--t( 'popState' )
	return shaft( t, rad, depth - 2 )
end
