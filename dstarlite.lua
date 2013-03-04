--SHIM

require( 'debugger' )
require( 'profiler' )
_inspect = require( 'inspect' )
inspect = function( ... )
    print( _inspect( unpack( arg ) ) )
end

if not math.huge then
    math.huge = 1 / 0
end

function DumpQueue(q)
    local i = 1
    for key, s in q.nodes() do
        print( i..': '..'['..key[1]..','..key[2]..']', s.v[1], s.v[2], s.v[3], s.v[4] )
        i = i + 1
    end
end

function DumpNode(s)
     print(  s.v[1], s.v[2], s.v[3], s.v[4] )
end

function dlog( ... )
    if not verbose then return end
    inspect( unpack( arg ) )
end

function PrintMap(m, goal, start)
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge

    for i, n in m.each() do
        if n.v[1] < minx then
            minx = n.v[1]
        end
        if n.v[1] > maxx then
            maxx = n.v[1]
        end
        if n.v[2] < miny then
            miny = n.v[2]
        end
        if n.v[2] > maxy then
            maxy = n.v[2]
        end
    end

    local robotNode = goal
    local path = {}
    while goal do
        path[ goal ] = true
        goal = goal.tree
    end
    path[ start ] = true -- temporary hack - seems like start should already be there

    local z = 0
    local dirs = {[0] = '^', '>', 'v', '<'}
    for y = maxy, miny, -1 do
        if y == maxy then
            io.write( '  ' )
            for x = minx, maxx do
                local c = math.mod( math.abs( x ), 10 )
                io.write( c )
            end
            io.write( '\n\n' )
        end

        for x = minx, maxx do
            local n, pn = nil, nil
            for d=0, 3 do
                pn = m.get( {x, y, z, d} )
                if pn then
                    n = pn
                    if path[ pn ] then
                        break
                    end
                end
            end

            if x == minx then
                local c = math.mod( math.abs( y ), 10 )
                io.write( c..' ' )
            end

            if n then
                local c = '0'
                if n.cost == math.huge then
                    c = '#'
                elseif n.g == math.huge then
                    c = '!'
                else
                    --c = math.mod( math.floor(n.g), 10 )
                    c = '.'
                end

                if path[ n ] then
                    if n.cost == math.huge then
                        c = '%'
                    elseif n == robotNode then
                        c = 'T'
                    else
                        c = dirs[ n.v[4] ]
                    end
                end

                if n == start then
                    c = 'X'
                elseif n == goal then
                    c = 'S'
                end

                io.write( c )
            else
                io.write( ' ' )
            end
        end
        io.write( '\n' )
    end
end

--/SHIM


-- cmp is how we compare the keys
-- TODO: a nicety of this would be if all functions returning a value
--      returned their key also
function DSLPQueue( cmp )
    local self = {}
    local nodemap = {}
    local heap = {}
    local next = 1

    function swap( i1, i2 )
        heap[ i1 ].idx, heap[ i2 ].idx = i2, i1
        heap[ i1 ], heap[ i2 ] = heap[ i2 ], heap[ i1 ]
        --if next > i1 and next > i2 then
        --end
    end

    function percolateDown( i )
        local li, ri = 2 * i, 2 * i + 1
        local left, right = heap[ li ], heap[ ri ]
        local cur = heap[ i ]
        local smallest = i

        if li < next and cmp( left.key, heap[ smallest ].key ) < 0 then
            smallest = li
        end

        if ri < next and cmp( right.key, heap[ smallest ].key ) < 0 then
            smallest = ri
        end

        if smallest ~= i then
            swap( i, smallest )
            percolateDown( smallest )
        end
    end

    function percolateUp( i )
        if i >= next then return end

        local pi = math.floor( i / 2 )
        local key = heap[ i ].key
        while pi > 0 do
            if cmp( key, heap[ pi ].key ) < 0 then
                swap( pi, i )
                i, pi = pi, math.floor( pi / 2 )
            else
                return
            end
        end
    end

    self = {

        nodes = function()
            local i = 1
            return function()
                local v = heap[ i ]
                if v == nil then return nil end
                i = i + 1
                return v.key, v.value
            end
        end,

        insert = function( val, key )
            self.stats.maxl = math.max( self.stats.maxl, next )

            local now = socket.gettime()
            self.stats.insert = self.stats.insert + 1

            local node = {key = key, value = val, idx = next}
            nodemap[ val ] = node

            heap[ next ] = node
            next = next + 1
            percolateUp( next - 1 )

            updateTime = updateTime + ( socket.gettime() - now )
        end,

        -- TODO: replace this with percolation
        update = function( node, key )
            self.stats.update = self.stats.update + 1
            if self.remove( node ) then
                self.insert( node, key )
            end
        end,

        remove = function ( val )
            self.stats.remove = self.stats.remove + 1

            if next == 1 then return nil end
            if nodemap[ val ] == nil then return nil end
            local node = nodemap[ val ]
            nodemap[ val ] = nil

            next = next - 1
            if next == 1 then
                heap[ next ] = nil
                return val
            end
            local now = socket.gettime()

            local i = node.idx -- gets changed by swap
            swap( node.idx, next )
            heap[ next ] = nil

            percolateUp( i )
            percolateDown( i )

            removeTime = removeTime + ( socket.gettime() - now )
            return val
        end,

        top = function()
            return heap[1] and heap[1].value
        end,

        topKey = function()
            return heap[1] and heap[1].key
        end,

        pop = function()
            if heap[1] then
                return self.remove( heap[1].value )
            end
            return nil
        end,

        stats = {  update = 0, insert = 0, remove = 0, maxl = 0},

        contains = function( node )
            return nodemap[ node ] ~= nil
        end,

        length = function()
            return next - 1
        end,
    }

    return self
end

function NodeMap()
	local nodes = {}
	local self

    function tcopy(t)
        tt = {}
        for k,v in pairs(t) do
            tt[ k ] = v
        end

        --TODO: i need a deep copy function.
        tt.v = {tt.v[1], tt.v[2], tt.v[3], tt.v[4]}
        return tt
    end

	self = {
		add = function( n, val, noexpand )
            if false and val.cost and val.cost == math.huge and not noexpand then
                n = tcopy( n )
                for d = 0, 3 do
                    n[4] = d
                    self.add( n, val, true )
                end
                return
            end
			if nodes[ n[1] ] == nil then
				nodes[ n[1] ] = {}
			end
			if nodes[ n[1] ][ n[2] ] == nil then
				nodes[ n[1] ][ n[2] ] = {}
			end
			if nodes[ n[1] ][ n[2] ][ n[3] ] == nil then
				nodes[ n[1] ][ n[2] ][ n[3] ] = {}
			end

			nodes[ n[1] ][ n[2] ][ n[3] ][ n[4] ] = val
		end,
		hasKey = function( n )
			return self.get( n ) ~= nil
		end,
		remove = function( n )
			nodes[ n[1] ][ n[2] ][ n[3] ][ n[4] ] = nil
			--yep, nodes grows with containers forever
		end,

		get = function( n )
			return nodes[ n[1] ]
				and nodes[ n[1] ][ n[2] ]
				and nodes[ n[1] ][ n[2] ][ n[3] ]
				and nodes[ n[1] ][ n[2] ][ n[3] ][ n[4] ]
		end,

        each = function()
            local fnodes = {}
            for xi, x in pairs( nodes ) do
                for yi, y in pairs( x ) do
                    for zi, z in pairs( y ) do
                        for di, d in pairs( z ) do
                            table.insert( fnodes, d )
                        end
                    end
                end
            end

            return ipairs( fnodes )
        end,
	}

    return self
end


function Node( v )
    return {
        rhs = math.huge,
        g = math.huge,
        tree = nil,
        findseq = 0,
        cost = 1,
        oldcost = 1,
        v = {v[1], v[2], v[3], v[4]}
    }
end

function Obstacle( v )
    local n = Node( v )
    n.cost = math.huge
    return n
end

--helper function, because to make a node blocked I have
--to show it blocked in all "direction" dimensions...
--I don't like that, I need a better map structure.
-- Needs to remove existing nodes, and replace *all*
-- directions with the new obstacle.  If there was a
-- node already, its RHS etc. values need to be maintained.
function makeObstacle( v, map, seq )
    for dir = 0, 3 do
        local ov = {v[1], v[2], v[3], dir}
        local existing = map.get( ov )
        if existing then
            existing.oldcost = existing.cost
            existing.cost = math.huge
            --for s in Succ( existing ) do
            --    if s.tree == existing then
            --    end
            --end
        else
            local node = Obstacle( ov )
            map.add( node.v, node )
        end
    end
end

function Distance( a, b )
    return math.abs( a[1] - b[1] )
        + math.abs( a[2] - b[2] )
        + math.abs( a[3] - b[3] )
end

function TrueDistance( a, b )
    local d1, d2, d3 = math.abs( a[1] - b[1] ), math.abs( a[2] - b[2] ), math.abs( a[3] - b[3] )
    local hyp = math.sqrt( d1 * d1 + d2 * d2 )
    return math.sqrt( hyp * hyp + d3 * d3 )
end

function DStarLite( start, goal, map )
    local U, km, CalculateKey, CompareKey
    local iter = 0

    if map == nil then
        map = NodeMap()
    end

    function DN(s) DumpNode(s) end
    function DQ() DumpQueue( U ) end

    -- Koenig reverses start and goal which seems
    -- totally stupid to do in code, but to help me
    -- understand, I'm doing it too.
    goal, start = Node( start ), Node( goal )
    -- start, goal = Node( start ), Node( goal )

    last = nil

    function Succ( s )
        -- TODO: Randomize this.  I think it helps.
        s = s.v
        local r = { [0]=1, 2, 3, 0}
        local l = { [0]=3, 0, 1, 2}
        local dx, dy = 0, 0
        if s[4] == 0 or s[4] == 2 then
            dy = 1
        else
            dx = 1
        end

        if verbose then
            pause()
        end

        local vertices = {
			{s[1] + dx, s[2] + dy, s[3],      s[4]     }, -- move north or east
			{s[1] - dx, s[2] - dy, s[3],      s[4]     }, -- move south or west
			--{s[1],      s[2],      s[3] + 1,  s[4]     }, -- move up
			--{s[1],      s[2],      s[3] - 1,  s[4]     }, -- move down
			{s[1],      s[2],      s[3],      l[ s[4] ]},  -- turn left
			{s[1],      s[2],      s[3],      r[ s[4] ]},  -- turn right
		}

        local vertices = {
			{s[1]+1, s[2], s[3],s[4]},
			{s[1]-1, s[2], s[3],s[4]},
			{s[1], s[2]+1, s[3],s[4]},
			{s[1], s[2]-1, s[3],s[4]},
		}

        local nodes = {}
        local i, diff = 1, 1
        if math.random() > .5 then
            i = table.getn( vertices )
            diff = -1
        end
        while vertices[i] do
            if verbose then
                dlog( vertices )
            end
            local n = map.get( vertices[i] )
            if not n then

                n = Node( vertices[i] )
            end

            table.insert( nodes, n )
            i = i + diff
        end

        local ni = 0
        return function()
            ni = ni + 1
            return nodes[ ni ]
        end
    end

    function Pred( s )
        return Succ( s )
    end

    function updaterhs( n )
        n.rhs = math.huge
        n.tree = nil
        for s in Succ( n ) do
            local cost = Cost( n, s )
            if n.rhs > s.g + cost then
                n.rhs = s.g + cost
                n.tree = s
            end
        end

        if n.tree and n.tree.tree == n then
            -- oopsies, infinite loop.
            -- Well, it looks like that may not be the case
            -- Because a later call to updaterhs may fix it
            -- It's hard to comprehend a proof that will happen...
            -- So.  Keep an eye out.
            -- srslyPause()
        end

        UpdateVertex( n )
    end

    --s2 is current... at least now
    function Heuristic( s1, s2 )
        local dx1 = s2.v[1] - goal.v[1]
        local dy1 = s2.v[2] - goal.v[2]
        local dz1 = s2.v[3] - goal.v[3]
        local dx2 = start.v[1] - goal.v[1]
        local dy2 = start.v[2] - goal.v[2]
        local dz2 = start.v[3] - goal.v[3]

        local cross = math.abs( dx1 * dy2 - dx2 * dy1 )
        cross = cross + math.abs( dx1 * dz2 - dx2 * dz1 )

        -- the cross product nudging needs to be small enough to not
        -- encourage the turtle to turn a lot, but big enough
        -- to reduce expanded nodes.
        --return TrueDistance( s1.v, s2.v ) + cross * .05
        -- I think for this to be feasible, I need to randomize vertices
        return Distance( s1.v, s2.v ) + cross * .000001
    end

    function Cost( s, sn )
        local reverse = 0

        if s.v[4] ~= sn.v[4] then
            -- turning is cheap but not free (takes time, not fuel)
            return .5
        end

        --include a penalty for driving in reverse (for looks)
        local dv = {s.v[1] - sn.v[1], s.v[2] - sn.v[2]}
        if dv[1] < 0  and s.v[4] == 1 then
            reverse = .1
        elseif dv[2] < 0 and s.v[4] == 0 then
            reverse = .1
        elseif dv[2] > 0 and s.v[4] == 2 then
            reverse = .1
        elseif dv[1] > 0 and s.v[4] == 3 then
            reverse = .1
        end

        reverse=0
        --return Distance( s.v, sn.v ) + reverse + sn.cost
        return ( sn.cost + s.cost ) / 2
    end

    function MakeKeyCalculator( h )
        return function( s )
            --for k in s do print( k ) end
            --print( 'DOING', s, s.g, s.rhs )
            local k2 = math.min( s.g, s.rhs )
            return { k2 + h( goal, s ) + km, k2 }
        end
    end
    
    function Initialize()

        km = 0

        start.g = math.huge
        start.rhs = 0

        CalculateKey = MakeKeyCalculator( Heuristic )

        CompareKey = function( k1, k2 )
            local kd1 = k1[1] - k2[1]

            if kd1 == 0 then return k1[2] - k2[2] end
            return kd1
        end

        U = DSLPQueue( CompareKey )

        U.insert( start, CalculateKey( start ) )
        map.add( goal.v, goal )
        map.add( start.v, start )
    end

    function MinSucc( u )
        local mincost = math.huge
        local minsucc = nil

        for s in Succ( u ) do
            local cost = Cost( u, s )
            
            if ( cost + s.g ) < mincost then
                mincost = cost + s.g
                minsucc = s
            end
        end

        return minsucc, mincost
    end

    function UpdateCost( u, newcost )
        local tmpold, tmpnew, minsucc, mincost
        local oldcost = u.cost
        u.cost = newcost

        for s in Succ( u ) do
            u.cost = oldcost
            tmpold = Cost( u, s )
            u.cost = newcost
            tmpnew = Cost( u, s )

            if Distance( u.v, start.v ) > 0 then
                if tmpold > tmpnew then
                    u.rhs = math.min( u.rhs, tmpnew + u.g )
                elseif u.rhs == (tmpold + s.g) then
                    minsucc, mincost = MinSucc( u )
                    u.rhs = mincost
                    u.tree = minsucc 
                end
            end
        end

        UpdateVertex( u )

        for s in Succ( u ) do
            u.cost = oldcost
            tmpold = Cost( u, s )
            u.cost = newcost
            tmpnew = Cost( u, s )

            if Distance( s.v, start.v ) > 0 then
                if tmpold > tmpnew then
                    s.rhs = math.min( s.rhs, tmpnew + u.g )
                elseif s.rhs == ( tmpold + u.g ) then
                    minsucc, mincost = MinSucc( s )
                    s.rhs = mincost
                    s.tree = minsucc
                end
            end

            UpdateVertex( s )
        end
    end

    function UpdateVertex( u )
        local cont = U.contains( u )

        if u.g ~= u.rhs and cont then
            U.update( u, CalculateKey( u ) )
        elseif u.g ~= u.rhs and not cont then
            map.add( u.v, u )
            U.insert( u, CalculateKey( u ) )
        elseif u.g == u.rhs and cont then
            U.remove( u )
        end
    end

    function ComputeShortestPath()
        local iters = 0
        io.write( 'Driving to: ' )
        DN( start )
        if iter == 4 then
            pause()
        end
        while U.topKey() and ( CompareKey( U.topKey(), CalculateKey( goal ) ) < 0 or goal.rhs > goal.g ) do
            iters = iters + 1
            local u = U.top()
            local kold = U.topKey()
            local knew = CalculateKey( u )

            --DN(u)

            if CompareKey( kold, knew ) < 0 then
                U.update( u, knew )
            elseif u.g > u.rhs then
                u.g = u.rhs
                U.remove( u )
                for s in Pred( u ) do
                    -- using distance as my state comparision.
                    -- it COULD actually be different than distance...
                    local c = Cost( u, s )
                    if Distance( s.v, start.v ) ~= 0 and s.rhs > c + u.g then
                        s.rhs = c + u.g
                        UpdateVertex( s )
                        s.tree = u
                        if u.tree == s then
                            srslyPause()
                        end
                    end
                end
            else
                local gold = u.g
                u.g = math.huge

                --I don't know.  The pseudocode shows
                --this part going over Pred() + u.  But
                --I didn't see that in the c implementation.
                local preds = { u }
                for s in Pred( u ) do
                    table.insert( preds, s )
                end

                for i, s in pairs( preds ) do

                    if Distance( s.v, start.v ) > 0 and s.tree == u then
                        updaterhs( s )
                    end
                end
            end
        end

        --if goal.g < goal.rhs then
        --  else
        --[[
        print( 'Shortest Path Iters: ', iters )
        local st = U.stats
        print( 'update', st.update, 'insert', st.insert, 'remove', st.remove, 'maxl', st.maxl )
        DQ()
        --local cur = start
        --while cur do
        --    DN(cur)
        --    cur = cur.tree
        --end

        print( 'Known nodes' )
        PrintMap( map, start, goal )
        --]]

        local seendis = {}
        local seendat = {}
        local path = {}
        local cur = goal
        while cur do
            local k = cur.v[1]..','..cur.v[2]..','..cur.v[3]

            if seendat[ cur ] or seendis[k] then
                srslyPause()
            end

            seendis[k] = true
            seendat[ cur ] = true
            table.insert( path, cur )
            cur = cur.tree
        end

        --[[  for some reason it isn't backwards anymore...
        local len = table.getn( path )
        for i=1, math.floor( len / 2 ) do
            path[ i ], path[ len - i + 1 ] = path[ len - i + 1 ], path[ i ]
        end
        --]]

        return path
    end
    

    function Main()

        local origGoal = goal
        local last = goal
        Initialize()

        math.randomseed( 14 )

        while start and Distance( start.v, goal.v ) > 0 do

            iter = iter + 1
            print( 'Attempt ', iter )

            local path = ComputeShortestPath()
            --goal.tree = nil

            -- if start.rhs == infinity there is no known path=

            local len = table.getn( path )
            local lasti = nil
            local costOld
            for i=1, len do
                local n = path[ i ]
                lasti = i
                DN( n )
                
                if i > 1 then
                    costOld = Cost( path[ i - 1 ], path[ i ] )
                else
                    costOld = path[ i ].cost
                end

                if i > 1 and Distance( start.v, n.v ) > 0 and math.random() < 0.4 then
                    print( 'obstacle' )
                    makeObstacle( n.v, map, seq )
                    break
                end
                goal = path[ i ]
            end


            PrintMap( map, last, start )

            if iter == 3 then
                pause()
            end
            if Distance( start.v, goal.v ) > 0 then

                km = km + Heuristic( last, goal )
                last = goal

                --for all the cells we went through...?
                for i = lasti, 1, -1 do
                    local newcost = path[ i ].cost
                    path[ i ].cost = path[ i ].oldcost

                    UpdateCost( path[ i ], newcost )
                    path[ i ].oldcost = path[ i ].cost
                end
            end
        end
        -- drive until you hit something
        -- for all edges (u, v) with changed cost
        --update the cost c(u,v)
        --update vertext v
    end

    Main()  --not necessary probably
end

s = {0,0,0,0}

g = {6, 5, 0, 0}

updateTime = 0
removeTime = 0
require "socket"

local map = NodeMap()

for i=-5, 20 do
    n = Obstacle( {i, 5, 0, 0} )
    map.add( n.v, n )
end
for i=0, 500 do
    n = {
        math.floor( 2*g[1] * math.random() - g[1] ),
        math.floor( 2*g[2] * math.random() - g[2] ),
        math.floor( 2*g[3] * math.random() - g[3] ),
        0
    }
    n = Obstacle( n )
    map.add( n.v, n )
end

verbose=false

srslyPause = pause
-- function pause() end

--profiler.start( 'dstarlite.prof' )
DStarLite( s, g, nil )
--profiler.stop()

print( 'Total time in DSLPQueue.insert: ', updateTime )
print( 'Total time in DSLPQueue.remove: ', removeTime )

os.exit()
math.randomseed( os.time() )
size = 20
for x=-5, 5 do
    for y = -5, 5 do
        for z = -5, 5 do
            g = {x, y, z}
            if x and y and z then
                DStarLite( s, g, nil )
            end
        end
    end
end
--g = {math.random(-size, size), math.random(-size,size), math.random(-size,size) }
--g = {3, 3, 0}
--DStarLite( s, g, nil )
