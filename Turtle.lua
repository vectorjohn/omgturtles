
local TurtleMT = {
    __index = function( t, k )
    end
}

TurtleMT.__metatable = TurtleMT

function Turtle:new( t )
    t = {
        turtle = t
    }

    return setmetatable( t, TurtleMT )
end
