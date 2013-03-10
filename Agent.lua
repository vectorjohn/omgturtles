-- so far this is a bunch of ideas thrown out to see
-- what feels good.  Mostly I want an event loop that has
-- a priority queue of different 'things to do', which I'm
-- calling behaviors.  Every time it does on of those things,
-- or even while doing those things, priorities can change.
-- It might be interrupted in the middle of mining to do the
-- 'find fuel' behavior.  It should then be able to resume 
-- a previous behavior.
Agent = {}
Agent._mt = Class( Agent )


Behavior = {
    _behaviors = {}
}

function Behavior.register( name, fn )
    Behavior._behaviors[ name ] = {
        main = fn,
        conf = {}
    }
end

function Behavior.get( name )
    return Behavior._behaviors[ name ]
end

Behavior.register( 'idle', function( this, t, state )
    os.startTimer( 0.5 )
    os.pullEvent()
    state.wants.update( this, 1 )
end)

function Agent.msg()
end

function Bot( t, map )

    local mapper = coroutine.wrap(function( start, goal, iter )

        while true do
            local newstart, newgoal, newiter = coroutine.yield()
            start = newstart or start
            goal = newgoal or goal
            iter = = newiter or iter

            DStarLite( start, goal, map, iter )
        end
    end)

    local wants = PQueue( function( k1, k2 )
        return k2 - k1  --pq is a min p queue so do it backwards
    end)

    local idle = Behavior.get( 'idle' )
    wants.insert( Behavior.get( 'mine' ), 10 )
    wants.insert( idle, 1 )

    t = trackable( t )
    local state = {
        wants = wants,
        map = map,
        mapper = mapper
    }

    while true do
        local goal = wants.top()
        goal.main( goal, t, state )
        local idleKey = wants.getKey( idle )
        wants.update( idle, idleKey * 2 )
    end
end
