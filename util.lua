if require then
    package.path = '../?.lua;'..package.path
end

function cc_include( f )
    if require then
		require( f )
	else
        --dofile( '/'.. shell.dir().. '/'.. f.. '.lua' )
        dofile( '/john/'.. f.. '.lua' )
	end
end

cc_include( 'Event' )

if not math.mod then
    function math.mod( n, d )
        return n % d
    end
end

function table.map( t, fn )
    if type(t) ~= 'function' then
        t = pairs(t)
    end
    local nt = {}
    for k, v in t do
        nt[ k ] = fn( v )
    end
    return nt
end

function table.each( t, fn )
    if type(t) ~= 'function' then
        t = pairs(t)
    end

    for k, v in t do
        if fn( v, k ) == false then
            return
        end
    end
end

function table.reduce( t, fn, init )
    local result = init
    table.each( t, function(v, k)
        result = fn( result, v, k )
    end)
    return result
end

function table.filter( t, fn )
    local nt = {}
    table.each( t, function( v, k )
        if fn( v, k ) then
            nt[ k ] = v
        end
    end)
    return nt
end

function table.first( t, fn )
    local val, key = nil, nil
    table.each( t, function( v, k )
        if fn( v, k ) then
            val, key = v, k
            return false
        end
    end)

    return val, key
end

function table.copy( t, deep )
    local cp = {}
    for k, v in pairs( t ) do
        if deep and type( v ) == 'table' then
            cp[ k ] = table.copy( v )
        else
            cp[ k ] = v
        end
    end
    return cp
end

--sort without side effects.  deep copies the table
function table.fsort( t, cmp )
    t = table.copy( t, true )
    table.sort( t, cmp )
    return t
end

function dist( v1, v2 )
    local dx, dy, dz = math.abs( v1[1] - v2[1] ), math.abs( v1[2] - v2[2] ), math.abs( v1[3] - v2[3] )
    return math.sqrt( dx * dx + dy * dy + dz * dz )
end

function mandist( v1, v2 )
    local dx, dy, dz = math.abs( v1[1] - v2[1] ), math.abs( v1[2] - v2[2] ), math.abs( v1[3] - v2[3] )
    return dx + dy + dz
end

-- solve the travelling salesperson problem in
-- O(n^2) time like a boss.
-- JK, this uses nearest neighbor.  Fast and easy.
function tsp( start, verts )
    verts = table.copy( verts )

    return function()
        if not verts then
            return verts
        end

        verts = table.map( verts, function(v)
            return {mandist( start, v ), v}
        end)

        local best = table.remove( verts )
        best = {dist = best[1], v = best[2]}

        table.reduce( verts, function( best, node )
            if node[1] < best.dist then
                if not best.rest then best.rest = {} end

                table.insert( best.rest, best.v )
                best.dist = node[1]
                best.v = node[2]
            end
            return best
        end, best)

        verts = best.rest
        return best.v
    end
end

function spiralDo( t, r, each )

	function step( curRad, dir, sidePos )
		if each and each( t, curRad, dir, sidePos ) == false then return false end
		if not t( 'forward' ) then return false end
		return true
	end

	for rr = 1, r do
		for dir = 0, 3 do
			for side=1, 2 * rr do
				if dir > 0 and side == 1 then t('turnLeft') end
				if not step( rr, dir, side ) then return false end
				if dir == 0 and side == 1 then t('turnLeft') end
			end
		end
	end

	return true
end

function hillClimb( t, range, cmp )
	local success = false
	local allAir = true
	local status = spiralDo( t, range, function( t, r)
		allAir = allAir and not t( 'detectDown' )

		if r > 1 and allAir then
			return false
		end

		if t( 'detect' ) then
			success = true
			return false
		end
	end)

	if allAir then
		-- surrounded by air.  found a local max!
		return true
	end

	-- blocked or went to end of range with no up hills.
	if status or not success then
		return false
	end

	t( 'up' )
	return hillClimb( t, range, cmp )
end

function trackable( t )
    local x = 0
    local y = 0
    local z = 0
    local dir = 0
    local states = {}
    local config = {}
	
	local moves = {}

    Event.mixin( moves )

	moves = {
		move = function(scale)
			if dir == 0 then y = y + scale
				elseif dir == 1 then x = x + scale
				elseif dir == 2 then y = y - scale
				elseif dir == 3 then x = x - scale
			end
			return true
		end,

		forward = function()
			moves.move(1)
		end,

		back = function()
			moves.move(-1)
		end,

		down = function()
			z = z - 1
		end,

		up = function()
			z = z + 1
		end,

		turnLeft = function()
			dir = dir - 1
			if dir < 0 then dir = 3 end
		end,

		turnRight = function()
			dir = dir + 1
			if dir > 3 then dir = 0 end
		end,

		getState = function()
			return {
				x = x,
				y = y,
				z = z,
				dir = dir,
			}
		end,

        getConfig = function( k )
            if k == nil then
                return config
            end
            return config[ k ]
        end,

        setConfig = function( k, v )
            if type( k ) == 'table' then
                config = k
            end
            config[ k ] = v
        end,

        setState = function( nx, ny, nz, ndir )
            x, y, z, dir = nx, ny, nz, ndir
        end,

		pushState = function()
			local tend = table.getn( states )
			states[ tend + 1 ] = moves.getState()
			x = 0
			y = 0
			z = 0
			dir = 0
		end,

		popState = function()
			local tend = table.getn( states )
			local old = moves.getState()
			if tend > 0 then
				local prev = states[ tend ]
				states[ tend ] = nil
				x = prev.x
				y = prev.y
				z = prev.z
				dir = prev.dir
				return old
			end

			return nil
		end,

		mergeState = function()
			local old = moves.popState()
			x = x + old.x
			y = y + old.y
			z = z + old.z
			dir = dir + old.dir
			if dir > 3 then dir = dir - 4 end

			return moves.getState()
		end,

		noop = function() return end,

		printState = function()
			print( 'Turtle <'..x..','..y..','..z..'> facing '.. dir )
		end,



	}

	return function( cmd, ... )
		if t[ cmd ] ~= nil then
			local ret = t[ cmd ]( unpack( arg ) )
			if ret ~= false then
				if moves[ cmd ] ~= nil then
					moves[ cmd ]()
				end
			end

			return ret
		end

		-- not a turtle command, just an internal one
		if moves[ cmd ] ~= nil then
			return moves[ cmd ]( unpack( arg ) )
		end
	end
end


function chainMove( t, ... )
	for i in ipairs( arg ) do
		t( arg[i] )
	end
end

function tcurry( t, fn, ... )
	local preargs = arg
	local arglen = table.getn( arg )
	return function( ... )
		for i in ipairs( arg ) do
			preargs[ arglen + i ] = arg[i]
		end
		return t( fn, unpack( preargs ) )
	end
end

function verboseTurtle( t )
	return function( ... )
		term.write( '* '.. arg[1].. ': ' )

		local ret = t( unpack( arg ) )
		if arg[1] ~= 'printState' then
			t( 'printState' )
		end
		return ret
	end
end

reverse = {
	forward = 'back',
	back = 'forward',
	turnLeft = 'turnRight',
	turnRight = 'turnLeft',
}

function reversibleDo( t, fn )
	if reverse[ fn ] == nil then return false end

	t( fn )
	t( reverse[ fn ] )
end

function reversible( t, fn )
	return function()
		reversibleDo( t, fn )
	end
end

function revChain( t, ... )
	local fns = {}
	for i in ipairs( arg ) do
		fns[i] = arg[i]
	end

	local len = table.getn( arg )
	for i in ipairs( arg ) do
		if reverse[ arg[i] ] == nil then
			fns[ 2 * len - i + 1 ] = 'noop'
		else
			--print( 'reverse of ', arg[i], ' is ', reverse[ arg[i] ], ' in ', i, 2 * len - i + 1 )

			fns[ 2 * len - i + 1 ] = reverse[ arg[i] ]
		end
	end
	--print( unpack( fns ) )
	return chainMove( t, unpack( fns ) )
end

function drive( t, dist )
	for i = 1, dist do
		if not t( 'forward' ) then
			if not t( 'up' ) then return false end
			return drive( t, dist - i + 1 )
		end
		while t( 'down' ) do end
	end

	return true
end


--TODO - this could automatically put all of the items in slot next to each other.
--or other neat stuff.
--TODO: looks like there is compareTo and getItemSpace, which could make this better
--transfers all possible items to slot
--if slot is not full, and a partial stack is transferred into it, 
--it will start combining into that slot.
function combineAll( t, slot )
    local combineCount = 0
    local skipslot = {
        [slot] = true
    }

    for i = 1, 16 do

        local trycount = t( 'getItemCount', i )
        
        if not skipslot[ i ] and trycount > 0 then
            t( 'select', i )
            if t( 'compareTo', slot ) and t( 'transferTo', slot, trycount ) then
                local newcount = t( 'getItemCount', i )
                combineCount = combineCount + ( trycount - newcount )
                if newcount > 0 then
                    slot = i
                    skipslot[ slot ] = true
                end
            end
        end
    end

    return combineCount
end


function faceDirection( t, dir )
    local cd = t( 'getState' ).dir

    local max, min = math.max( dir, cd ), math.min( dir, cd )

    -- There has to be a clever way to do this, but I'm not coming up with it.
    if min == max then return end

    if max - min == 2 then
        t( 'turnLeft' )
        t( 'turnLeft' )
        return
    end

    if dir == 3 and cd == 0 then t( 'turnLeft' ) return end
    if dir == 0 and cd == 3 then t( 'turnRight' ) return end

    if dir < cd then t( 'turnLeft' ) return end
    t( 'turnRight' )
end

function stateToVert( state )
    return {state.x, state.y, state.z, state.dir}
end

function vertToState( v )
    return {
        x = v[1],
        y = v[2],
        z = v[3],
        dir = v[4],
    }
end

function aboveState( st )
    st = table.copy( st )
    st.z = st.z + 1
    return st
end

function selectEmpty( t )
    for i=1, 16 do
        if t( 'getItemCount', i ) == 0 then
            t( 'select', i )
            return i
        end
    end
    return false
end

function countEmptySlots( t )
    local empty = 0
    for i = 1, 16 do
        if t( 'getItemCount', i ) == 0 then
            empty = empty + 1
        end
    end
    return empty
end

function findMatch( t, from, to )
    for i = from, to do
        t( 'select', i )
        if t( 'compare' ) then
            return true
        end
    end

    return false
end

function selectFirst( t, item, inv )
    local found = false

    for i = 1, 16 do
        if type( inv[i] ) == 'table' and inv[i][1] == item then
            t( 'select', i )
            return i
        end
    end

    return found
end

function cctimestamp()
    return os.day() * 24 + os.time()
end

function returner( t, mover )
    local state = t( 'getState' )
    return function()
        mover( t, state )
    end
end

function Logger( name )
end

function Inventory()
    return {

    }
end
