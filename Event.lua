
Event = {}

function Event.mixin( obj )
    local callbacks = {}

    function obj.bind( ev, fn )
        if not callbacks[ ev ] then
            callbacks[ ev ] = {}
        end

        table.insert( callbacks[ ev ], fn )
    end

    function obj.unbind( ev, fn )
    end

    function obj.trigger( ev, ... )
        if not callbacks[ ev ] then return end

        for i=1, getn(callbacks[ev]) do
            callbacks[ev][i]( ... )
        end
    end
end
