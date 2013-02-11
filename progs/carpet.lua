function cc_include( f )
	if require then
		require( f )
	else
		dofile( '/john/'..f )
	end
end

cc_include( '../util.lua' )

len = 1
slot = 1
if arg[2] then len = arg[2] end

function docarpet()
	if turtle.getItemCount( slot ) < 1 then
		slot = slot + 1
		turtle.select( slot )
		docarpet()
	end

	turtle.digDown()
	turtle.placeDown()
	turtle.dig()
end

turtle.select( slot )
docarpet()
spiralDo( turtle, len, function( t )
	docarpet()
end);