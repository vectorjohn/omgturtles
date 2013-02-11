function cc_include( f )
	if require then
		require( f )
	else
		dofile( '/john/'..f )
	end
end

cc_include( '../util.lua' )
cc_include( '../mine.lua' )


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

	mine( t, 1, 2 )

	do return end

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

	print( "Test tcurry" )
	local move = tcurry( t, 'forward' )
	move()
	move()

	print( 'Test reverse' )

	local rmove = reversible( t, 'forward' )
	rmove()
	rmove()

	revChain( t, 
		'forward',
		'turnLeft',
		'forward',
		'forward',
		'turnRight',
		'back',
		'forward',
		'forward'
	)
end

runTest()