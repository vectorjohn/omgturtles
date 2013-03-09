--SHIM
verbose = {}    --this is a map of features to be verbose about
mode = 'production' -- production or development

if mode == 'development' then
    require( 'debugger' )
    require( 'profiler' )
    require "socket"
    _inspect = require( 'inspect' )
    inspect = function( ... )
        print( _inspect( unpack( arg ) ) )
    end

    local iowrite = io.write
    io = {write = function( ... )
        if not verbose then return end
        iowrite( unpack( arg ) )
    end}
    
else
    function pause() end
    profiler = {start = function() end, stop = function() end}
    socket = {gettime = function() return 0 end}
    inspect = function() end
    if not term then
        local iowrite = io.write
        term = {
            write = function( ... )
                if not verbose then return end
                iowrite( unpack( arg ) )
            end
        }
    end
    io = term
end

-- CC doesn't seem to have math.huge. Or maybe it is sometimes math.inf?
if not math.huge then
    math.huge = 1 / 0
end

function DumpQueue(q)
    if not verbose then return end

    local i = 1
    for key, s in q.nodes() do
        dprint( i..': '..'['..key[1]..','..key[2]..']', s.v[1], s.v[2], s.v[3], s.v[4] )
        i = i + 1
    end
end

function DumpNode(s)
    if not verbose then return end
     print(  '<'..s.v[1]..','..s.v[2]..','.. s.v[3]..','.. s.v[4]..'>' )
end

function dlog( ... )
    if not verbose then return end
    inspect( unpack( arg ) )
end

function dprint( ... )
    if not verbose then return end
    print( unpack( arg ) )
end

function panic()
    dprint( "Stuff broke and I don't know what to do about it" )
    if verbose then
        pause()
    end
end

function LogPrintMap( m, goal, start )
    if not ( verbose and verbose.map ) then
        return
    end
    PrintMap( m, goal, start )
end

--Not likely very useful in 3D
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

local NodeMetatable = {}
NodeMetatable.__index = NodeMetatable
NodeMetatable.__metatable = NodeMetatable

function NodeMetatable:serialize()
    return self.v[1]..','
        ..self.v[2]..','
        ..self.v[3]..','
        ..self.v[4]..','
        ..self.g..','
        ..self.rhs..','
        ..self.cost
end

function NodeMetatable:unserialize( s )
    local v = {}
    s:gsub( '([^,]*)', function(m) table.insert( v,tonumber(m) ) end )

    local n = Node( v )
    n.g = v[5]
    n.rhs = v[6]
    n.cost = v[7]
    return n
end

function Node( v )
    if type(v) == 'string' then
        return NodeMetatable:unserialize( v )
    end

    if v == nil then v = {0,0,0,0} end

    local n = {
        rhs = math.huge,
        g = math.huge,
        tree = nil,
        cost = 1,
        oldcost = 1,
        v = {v[1], v[2], v[3], v[4]},
    }

    setmetatable( n, NodeMetatable )
    return n
end

function Unit( n )
    return n
end

function VectorAdd( v1, v2 )
    local vs = {
        v1[1] + v2[1],
        v1[2] + v2[2],
        v1[3] + v2[3],
        v1[4] + v2[4],
    }
    if vs[4] > 3 then vs[4] = vs[4] - 4 end

    return vs
end

function VectorSub( v1, v2 )
    local vs = {
        v1[1] - v2[1],
        v1[2] - v2[2],
        v1[3] - v2[3],
        v1[4] - v2[4],
    }
    if vs[4] < 0 then vs[4] = vs[4] + 4 end

    return vs
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
function makeObstacle( v, map, cost )
    for dir = 0, 3 do
        local ov = {v[1], v[2], v[3], dir}
        local existing = map.get( ov )
        if existing then
            existing.oldcost = existing.cost
            existing.cost = cost
            --for s in Succ( existing ) do
            --    if s.tree == existing then
            --    end
            --end
        else
            local node = Node( ov )
            node.cost = cost
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

function DStarLite( start, goal, map, onmove )
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
			{s[1], s[2], s[3]+1,s[4]},
			{s[1], s[2], s[3]-1,s[4]},
		}

        local nodes = {}
        local i, diff = 1, 1
        while vertices[i] do
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
        return Distance( s1.v, s2.v ) --+ cross * .0000000001
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

            if math.abs(kd1) < 0.00001 then
                kd1 = k1[2] - k2[2]
                if math.abs(kd1) < 0.00001 then return 0 end
                return kd1
            end
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

        while U.topKey() and ( CompareKey( U.topKey(), CalculateKey( goal ) ) < 0 or goal.rhs ~= goal.g ) do
            iters = iters + 1
            local u = U.top()
            local kold = U.topKey()
            local knew = CalculateKey( u )

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
                            pause()
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

        local seendis = {}
        local seendat = {}
        local path = {}
        local cur = goal
        while cur do
            local k = cur.v[1]..','..cur.v[2]..','..cur.v[3]

            if seendat[ cur ] or seendis[k] then
                dprint( "Holy shit what's going on?" )
                dprint( 'km: ', km )
                LogPrintMap( map, nil, start )
                panic()
            end

            seendis[k] = true
            seendat[ cur ] = true
            table.insert( path, cur )
            cur = cur.tree
        end

        return path
    end

    -- try to move to v, which is move i and expected cost cost
    function TestMove( v, cost, i )
        local firstmove = i == 1
        local isstart = Distance( start.v, VectorAdd( goal.v, v ) ) == 0
        if not isstart and not firstmove and math.random() < 0.2 then
            return math.huge
        end

        return cost
    end
    
    function TraversePath( path )
        local len = table.getn( path )
        local lasti = nil
        local costOld
        local move = onmove or TestMove
        for i=1, len do
            local n = path[ i ]
            lasti = i
            DN( n )
            
            if i > 1 then
                costOld = Cost( path[ i - 1 ], path[ i ] )
            else
                costOld = path[ i ].cost
            end

            local cost = move( VectorSub( n.v, goal.v ), n.cost, i )

            if cost ~= n.cost then
                dprint( 'obstacle' )
                makeObstacle( n.v, map, cost )
                break
            end
            goal = path[ i ]
        end

        return lasti
    end

    function Main()

        local origGoal = goal
        local last = goal
        Initialize()

        math.randomseed( 27 )

        while start and Distance( start.v, goal.v ) > 0 do

            iter = iter + 1
            dprint( 'Attempt ', iter )

            local now = socket.gettime()
            local path = ComputeShortestPath()
            dprint( 'Time to compute: ', socket.gettime() - now )

            -- if start.rhs == infinity there is no known path=

            local lasti = TraversePath( path )
            
            LogPrintMap( map, last, start )

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
    end

    Main()
end

updateTime = 0
removeTime = 0

if mode == 'development' then
    s = {0,0,0,0}
    g = {16, 15, 0, 0}



    DStarLite( s, g, nil )

    dprint( 'Total time in DSLPQueue.insert: ', updateTime )
    dprint( 'Total time in DSLPQueue.remove: ', removeTime )
end
