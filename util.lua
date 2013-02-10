
function spiralDo( t, r, each )

	function step()
		if each and each( t ) ~= false then return false end
		if not t.forward() then return false end
		return true
	end

	for rr = 1, r do
		for dir = 0, 3 do
			for side=1, 2 * rr do
				if dir > 0 and side == 1 then t.turnLeft() end
				if not step() then return false end
				if dir == 0 and side == 1 then t.turnLeft() end
			end
		end
	end

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
