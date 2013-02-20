--SHIM

require( 'debugger' )
require( 'profiler' )
if not math.huge then
    math.huge = 1 / 0
end

function DumpQueue(q)
    for key, s in q.nodes() do
        print( '['..key[1]..','..key[2]..']', s.v[1], s.v[2], s.v[3] )
    end
end

function DumpNode(s)
     print(  s.v[1], s.v[2], s.v[3] )
end

function PrintMap(m, goal)
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

    local z = 0
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
            local n = m.get( {x, y, z} )

            if x == minx then
                local c = math.mod( math.abs( y ), 10 )
                io.write( c..' ' )
            end

            if n then
                local c = '0'
                if n.g == math.huge then
                    c = '!'
                else
                    c = math.mod( n.g, 10 )
                end

                if path[ n ] then
                    c = '*'
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

	self = {
		add = function( n, val )
			if nodes[ n[1] ] == nil then
				nodes[ n[1] ] = {}
			end
			if nodes[ n[1] ][ n[2] ] == nil then
				nodes[ n[1] ][ n[2] ] = {}
			end

			nodes[ n[1] ][ n[2] ][ n[3] ] = val
		end,
		hasKey = function( n )
			return self.get( n ) ~= nil
		end,
		remove = function( n )
			nodes[ n[1] ][ n[2] ][ n[3] ] = nil
			--yep, nodes grows with containers forever
		end,

		get = function( n )
			return nodes[ n[1] ]
				and nodes[ n[1] ][ n[2] ]
				and nodes[ n[1] ][ n[2] ][ n[3] ]
		end,

        each = function()
            local fnodes = {}
            for xi, x in pairs( nodes ) do
                for yi, y in pairs( x ) do
                    for zi, z in pairs( y ) do
                        table.insert( fnodes, z )
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
        v = v
    }
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

function DStarLite( start, goal, followpath )
    local U, km, CalculateKey, CompareKey
    local map = NodeMap()

    function DN(s) DumpNode(s) end
    function DQ() DumpQueue( U ) end

    -- Koenig reverses start and goal which seems
    -- totally stupid to do in code, but to help me
    -- understand, I'm doing it too.
    goal, start = Node( start ), Node( goal )
    -- start, goal = Node( start ), Node( goal )

    last = nil

    map.add( start.v, start )
    function Succ( s )
        -- TODO: Randomize this.  I think it helps.
        s = s.v
        local vertices = {
			{s[1],     s[2] + 1, s[3]    },
			{s[1] - 1, s[2],     s[3]    },
			{s[1] + 1, s[2],     s[3]    },
			--{s[1],     s[2],     s[3] + 1},
			--{s[1],     s[2],     s[3] - 1},
			{s[1],     s[2] - 1, s[3]    },
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

    function Heuristic( s1, s2 )
        return TrueDistance( s1.v, s2.v )
        -- I think for this to be feasible, I need to randomize vertices
        --return Distance( s1.v, s2.v )
    end

    function Cost( s, sn )
        return Distance( s.v, sn.v )
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
        end)

        U.insert( goal, CalculateKey( goal ) )
        map.add( goal.v, goal )
    end

    -- in thie middle of this one!
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
        PrintMap( map, start )
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

s = {0,0,0}

--g = {math.random(-size, size), math.random(-size,size), math.random(-size,size) }
g = {50, 50, 0}

DStarLite( s, g, nil )

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
