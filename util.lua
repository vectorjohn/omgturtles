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


if not math.mod then
    function math.mod( n, d )
        return n % d
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
	
	local moves = {}

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

function rect( t, width, height )

end
