
function cc_include( f )
	if require then
        package.path = '../?.lua;'..package.path
		require( f )
	else
		dofile( '/john/'..f..'.lua' )
	end
end

-- cc_include( 'util' ) -- requires this... uggh

if shell.__places__ == nil then
    shell.__places__ = {}
end

local t = trackable( turtle )

-- Export
places = {
    places = shell.__places__,

    set = function( name )
        places.places[ name ] = stateToVert( t( 'getState' ) )
    end,

    get = function( name )
        return places.places[ name ]
    end
}


if not places.get( 'origin' ) then
    places.set( 'origin' )
end

