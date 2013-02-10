function faketurtle()
	local turtle = {
		forward = function() return true end,
		dig = function() return true end
	}
	return turtle
end

t=faketurtle()
print( t.forward(), t.dig() )
print( "Hello World" )