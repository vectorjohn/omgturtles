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

t = trackable( faketurtle() )

function faceDirection( t, d )
    local state = t( 'getState' )

    -- frame shift so that turtle is facing 0 (north).  Delta is the turn direction and count
    local delta = math.mod( d - state.dir, 4 )

    local cmd = nil

    if math.abs( delta ) == 3 then
        delta = delta / -3
    end

    if delta == 0 then return
    elseif delta > 0 then cmd = 'turnRight'
    else cmd = 'turnLeft'
    end

    for i = 1, delta, delta / delta do
        t( cmd )
    end
end

function DSMoveCallback( v, cost, i )
    local state = t( 'getState' )
    local dx, dy = v[1], v[2]
    local dir = dx + dy - 1 * math.abs( dy )
    dir = math.mod( dir + 4, 4 )

    faceDirection( t, dir )

    if not t( 'forward' ) then
        return 1 / 0
    end

    return cost
end

function gotocoord( x,y,z )
    DStarLite( {0,0,0,0}, {x, y, z, 0}, nil, DSMoveCallback )
end

gotocoord( 5,5,5 )
