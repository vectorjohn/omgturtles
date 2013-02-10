function cc_include( f )
	if require then
		require( f )
	else
		dofile( '/john/'..f )
	end
end

cc_include( '../util.lua' )


term = {
	write = function(s)
		io.write( s )
	end
}

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
	t = trackable( faketurtle() )
	spiralDo( t, 3, nil, justdoit )

	t = verboseTurtle( t )

	chainMove( t, 
		'printState',
		'forward',
		'forward',
		'turnLeft',
		'forward',
		'back'
	)
end

runTest()