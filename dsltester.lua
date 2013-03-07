function cc_include( f )
	if require then
		require( f )
	else
		dofile( '/john/'..f..'.lua' )
	end
end

cc_include( 'util' )
cc_include( 'dstarlite' )
cc_include( 'progs/libtest' )

function faceDirection( t, d, curDir )
    -- frame shift so that turtle is facing 0 (north).  Delta is the turn direction and count
    -- Also, math.mod() is different than mod operator - math.mod handles negatives
    local delta = d - curDir
    print( 'face ', d, 'from', curDir )

    if delta == 0 then
        return
    end

    local cmd = nil

    if math.abs( delta ) == 3 then
        delta = delta / -3
    end

    if delta == 0 then return
    elseif delta > 0 then cmd = 'turnRight'
    else cmd = 'turnLeft'
    end

    print( 'turning: '..cmd )
    local ccw = 1
    if delta < 0 then ccw = -1 end
    for i = ccw, delta, ccw do
        t( cmd )
    end
end

function DSMoveCallback( t, v, cost, i )
    local state = t( 'getState' )
    local dx, dy, dz = v[1], v[2], v[3]
    local dir = dx + dy - 1 * math.abs( dy )
    local cmd = 'forward'
    dir = math.mod( dir + 4, 4 )

    if dx == 0 and dy == 0 and dz == 0 then
        -- DStarLite sometimes says to move to the current location.  I may or may not change that.
        return cost
    end

    if dx ~= 0 or dy ~= 0 then
        faceDirection( t, dir, state.dir )
    end

    if dz ~= 0 then
        if dz > 0 then cmd = 'up'
        else cmd = 'down'
        end
    end

    if not t( cmd ) then
        return 1 / 0
    end

    return cost
end

function gotocoord( xf,yf,zf, x, y, z )
    local t = verboseTurtle( trackable( faketurtle() ) )
    t = trackable( turtle )
    local count = 0

    if x == nil then
        x, y, z = xf, yf, zf
        xf, yf, zf = 0, 0, 0
    end
    DStarLite( {xf, yf, zf, 0}, {x, y, z, 0}, nil, function( v, cost, i )
        count = count + 1
        --if count == 3 then return 1 / 0 end
        return DSMoveCallback( t, v, cost, i )
    end)
end

local args = {...}

if table.getn( args ) < 3 then
    print( 'Usage: dsltester.lua [from X Y Z] X Y Z' )
    return
end

gotocoord( tonumber( args[1] ), tonumber( args[2] ), tonumber( args[3] ), tonumber( args[4] ), tonumber( args[5] ), tonumber( args[6] ) )
