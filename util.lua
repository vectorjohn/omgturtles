
function spiralDo( t, r, each )

	function step( curRad, dir, sidePos )
		if each and each( t, curRad, dir, sidePos ) == false then return false end
		if not t.forward() then return false end
		return true
	end

	for rr = 1, r do
		for dir = 0, 3 do
			for side=1, 2 * rr do
				if dir > 0 and side == 1 then t.turnLeft() end
				if not step( rr, dir, side ) then return false end
				if dir == 0 and side == 1 then t.turnLeft() end
			end
		end
	end

	return true
end

function hillClimb( t, range, cmp )
	local success = false
	local allAir = true
	local status = spiralDo( t, range, function( t, r)
		allAir = allAir and not t.detectDown()

		if r > 1 and allAir then
			return false
		end

		if t.detect() then
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

	t.up()
	return hillClimb( t, range, cmp )
end


function faketurtle()
	local T = {
		x = 0,
		y = 0,
		dir = 0,
	}

	function T.forward()
		if T.dir == 0 then T.y = T.y + 1
			elseif T.dir == 1 then T.x = T.x + 1
			elseif T.dir == 2 then T.y = T.y - 1
			elseif T.dir == 3 then T.x = T.x - 1
		end
		--print( "Move to <", T.x, ",", T.y, ">" )
		return true
	end

	function T.turnLeft()
		T.dir = T.dir - 1
		if T.dir < 0 then T.dir = 3 end
		--print (T.dir)
		return true
	end

	function T.dig() return true end

	return T
end

function runTest()
	t = faketurtle()
	spiralDo( t, 3, nil, justdoit )
end

if turtle == nil then
	runTest()
end
