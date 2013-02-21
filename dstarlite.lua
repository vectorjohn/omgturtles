--SHIM

require( 'debugger' )
require( 'profiler' )
if not math.huge then
    math.huge = 1 / 0
end

function DumpQueue(q)
    for key, s in q.nodes() do
        print( '['..key[1]..','..key[2]..']', s.v[1], s.v[2], s.v[3], s.v[4] )
    end
end

function DumpNode(s)
     print(  s.v[1], s.v[2], s.v[3], s.v[4] )
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
                    c = math.mod( math.floor(n.g), 10 )
                end

                if path[ n ] then
                    c = dirs[ n.v[4] ]
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
-- equal is used to compare the value
function DSLPQueue( cmp, equal )
    local self = {}
    local list = nil
    local nodemap = {}

    self = {

        nodes = function()
            local l = list
            return function()
                local cur = l
                if not cur then
                    return nil, nil
                end

                l = l.next
                return cur.key, cur.value
            end
        end,

        insert = function( node, key )
            local now = socket.gettime()
            self.stats.find = self.stats.find + 1
            self.stats.insert = self.stats.insert + 1

            local l = list
            local prev = nil
            local link = {next = nil, prev = nil, value = node, key = key}

            nodemap[ node ] = link

            local len = self.length()
            if len > self.stats.maxl then
                self.stats.maxl = len
            end

            while l do
                if cmp( key, l.key ) <= 0 then
                    if l.prev then
                        link.prev = l.prev
                        l.prev.next = link
                    end
                    l.prev = link
                    link.next = l

                    if l == list then list = link end

                    updateTime = updateTime + ( socket.gettime() - now )

                    return
                end
                prev = l
                l = l.next
            end

            if prev then
                prev.next = link
                link.prev = prev
            else
                list = link
            end
            updateTime = updateTime + ( socket.gettime() - now )
        end,

        update = function( node, key )
            if self.remove( node ) then
                self.insert( node, key )
            end

            --[[
            local l = list
            while l do
                if equal( node, l.value ) then
                    l.key = key
                    self.remove(
                    return
                end

                l = l.next
            end
            ]]--
        end,

        remove = function( node )
            self.stats.find = self.stats.find + 1
            self.stats.remove = self.stats.remove + 1

            if nodemap[ node ] then
                local l = nodemap[ node ]
                nodemap[ node ] = nil

                if l.prev then
                    l.prev.next = l.next
                end
                if l.next then
                    l.next.prev = l.prev
                end

                if l == list then
                    --removed head, have to change it
                    list = list.next
                end
                return true
            end

            return false
        end,

        top = function()
            return list and list.value
        end,

        topKey = function()
            return list and list.key
        end,

        pop = function()
            local value = list.value
            if value then
                self.remove( value )
            end
            return value
        end,

        stats = { find = 0, insert = 0, remove = 0, maxl = 0},

        contains = function( node )
            self.stats.find = self.stats.find + 1
            return nodemap[ node ] ~= nil

            --[[
            local l = list
            while l do
                if equal( node, l.value ) then return true end
                l = l.next
            end
            return false
            ]]--
        end,

        length = function()
            local i, l = 0, list
            while l do
                l = l.next
                i = i + 1
            end
            return i
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
        return tt
    end

	self = {
		add = function( n, val, noexpand )
            if val.cost and val.cost == math.huge and not noexpand then
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
        real = false,
        cost = 1,
        v = v
    }
end

function Obstacle( v )
    local n = Node( v )
    n.cost = math.huge
    return n
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
			-- {s[1],      s[2],      s[3] + 1,  s[4]     }, -- move up
			-- {s[1],      s[2],      s[3] - 1,  s[4]     }, -- move down
			{s[1],      s[2],      s[3],      l[ s[4] ]},  -- turn left
			{s[1],      s[2],      s[3],      r[ s[4] ]},  -- turn right
		}

        local nodes = {}
        local i, diff = 1, 1
        if math.random() > .5 then
            i = table.getn( vertices )
            diff = -1
        end
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
        return TrueDistance( s1.v, s2.v ) + cross * .05
        -- I think for this to be feasible, I need to randomize vertices
        --return Distance( s1.v, s2.v )
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

        return Distance( s.v, sn.v ) + reverse + sn.cost
    end

    function MakeKeyCalculator( start, h )
        return function( s )
            --for k in s do print( k ) end
            --print( 'DOING', s, s.g, s.rhs )
            local k2 = math.min( s.g, s.rhs )
            return { k2 + h( start, s ) + km, k2 }
        end
    end
    
    function Initialize()

        km = 0
        goal.rhs = 0

        CalculateKey = MakeKeyCalculator( start, Heuristic )

        CompareKey = function( k1, k2 )
            local kd1 = k1[1] - k2[1]

            if kd1 == 0 then return k1[2] - k2[2] end
            return kd1
        end

        U = DSLPQueue( CompareKey, function( s1, s2 )
            return s1.v[1] == s2.v[1]
                and s1.v[2] == s2.v[2]
                and s1.v[3] == s2.v[3]
                and s1.v[4] == s2.v[4]
        end)

        U.insert( goal, CalculateKey( goal ) )
        map.add( goal.v, goal )
        map.add( start.v, start )
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
        io.write( 'START: ' )
        DN( start )
        while U.topKey() and ( CompareKey( U.topKey(), CalculateKey( start ) ) < 0 or start.rhs > start.g ) do
            iters = iters + 1
            local u = U.top()
            local kold = U.topKey()
            local knew = CalculateKey( u )
            -- pause()
            --DN(u)

            if CompareKey( kold, knew ) < 0 then
                U.update( u, knew )
            elseif u.g > u.rhs then
                u.g = u.rhs
                U.remove( u )
                for s in Pred( u ) do
                    -- using distance as my state comparision.
                    -- it COULD actually be different than distance...
                    local c = Cost( s, u )
                    if Distance( s.v, goal.v ) ~= 0 and s.rhs > c + u.g then
                        s.rhs = c + u.g
                        UpdateVertex( s )
                        s.tree = u
                        --[[
                        newrhs = math.min( s.rhs, Cost(s, u) + u.g )
                        if newrhs ~= s.rhs then
                            mins = s
                        end
                        ]]--
                    end
                end
            else
                local gold = u.g
                u.g = math.huge
                UpdateVertex( u )

                for s in Pred( u ) do

                    if Distance( s.v, goal.v ) ~= 0 and s.tree == u then

                        -- this kind of book keeping might be why
                        -- they did an updaterhs() func.
                        s.tree = nil
                        s.rhs = math.huge

                        --NOT SURE - the s.tree == u thing is in
                        --dstarlite.c:338. I think it has something to do
                        --with only looking at predecessors along the
                        --robots path or something.

                        -- this if seems to be in the pseudocode but
                        -- nothing like it in the c...
                        -- if s.rhs == Cost( s, u ) + gold then

                            for s2 in Succ( s ) do
                                local mayberhs = Cost( s, s2 ) + s2.g
                                if s.rhs > mayberhs then
                                    s.rhs = mayberhs
                                    s.tree = s2
                                end
                            end

                            UpdateVertex( s )
                        --end
                    end
                end
            end
        end
        print( 'Shortest Path Iters: ', iters )
        local st = U.stats
        print( 'find', st.find, 'insert', st.insert, 'remove', st.remove, 'maxl', st.maxl )
        DQ()
        --local cur = start
        --while cur do
        --    DN(cur)
        --    cur = cur.tree
        --end

        print( 'Known nodes' )
        PrintMap( map, start, goal )
    end
    

    function Main()

        last = start
        Initialize()
        ComputeShortestPath()

        print( start )
        do return end

        while Distance( start.v, goal.v ) > 0 do
            -- if start.rhs == infinity there is no known path=

            --TODO make a function for this
            local min = nil
            local mins = nil
            local curMin = nil
            for s in Succ( start ) do
                curMin = Cost( start, s ) + s.g
                if not mins or curMin < min then
                    mins = s
                    min = curMin
                end
            end
            start = mins

            -- move to start
            -- t( moveTo, s ) ish
            -- look for changes (i.e. was I able to move to start

            if not 'able to move to s' then
                km = km + Heuristic( last, start )
                last = start

                -- for all edges (u,v) with new edge cost
                -- update edge cost c(u,v) - I'm not sure what that means

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

--g = {math.random(-size, size), math.random(-size,size), math.random(-size,size) }
g = {18, 18, 0, 0}

updateTime = 0
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

DStarLite( s, g, nil )

print( 'Total time in DSLPQueue.insert: ', updateTime )

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
