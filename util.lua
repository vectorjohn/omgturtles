
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
	local dir = 0
	
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
				dir = dir,
			}
		end,

		printState = function()
			print( 'Turtle <'..x..','..y..'> facing '.. dir )
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
			moves[ cmd ]()
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

function reversibleDo( t, fn )
	t( fn )
end

