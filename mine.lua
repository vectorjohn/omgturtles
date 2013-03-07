local state = {
	
}

local shaftRad = 3
local maxDepth = 60
local fuelSlot = 1

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

function gotocoord( t, xf,yf,zf, x, y, z )

    if z == nil then
        x, y, z = xf, yf, zf
        xf, yf, zf = 0, 0, 0
    end
    DStarLite( {xf, yf, zf, 0}, {x, y, z, 0}, nil, function( v, cost, i )
        return CoordMove( t, v, cost, i )
    end)
end

function mine( t, shaftRad, maxDepth, maxShafts, underground )
    local xoff = 0
    local yoff = 10

    for shaftNum = 0, maxShafts do
        mineOne( t, xoff, yoff, shaftRad, maxDepth, underground )

        emptyInventory( t )

        if xoff < 0 then
            xoff = -xoff + ( 2 * shaftRad + 1 )
        else
            xoff = -xoff - ( 2 * shaftRad + 1 )
        end
        --yoff = yoff + 2 * shaftRad + 1
    end
end

function emptyInventory( t )
    for i = 1, 16 do
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
	shaft( t, shaftRad, maxDepth )

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
	
	local ret = spiralDo( t, rad, function()
		t( 'digDown' )
		t( 'dig' )
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
