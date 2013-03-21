if require then
    package.path = '../?.lua;'..package.path
end

function cc_include( f )
    if require then
		require( f )
	else
        dofile( '/'.. shell.dir().. '/'.. f.. '.lua' )
	end
end

cc_include( 'util' )
cc_include( 'dstarlite' )
cc_include( 'progs/libtest' )
cc_include( 'coord_move' )

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
        return CoordMove( t, v, cost, i )
    end)
end

local args = {...}

if table.getn( args ) < 3 or args[6] == nil and args[4] ~= nil then
    print( 'Usage: dsltester.lua [from X Y Z] X Y Z' )
    return
end

gotocoord( tonumber( args[1] ), tonumber( args[2] ), tonumber( args[3] ), tonumber( args[4] ), tonumber( args[5] ), tonumber( args[6] ) )
