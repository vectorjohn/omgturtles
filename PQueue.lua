-- cmp is how we compare the keys
-- TODO: a nicety of this would be if all functions returning a value
--      returned their key also
function PQueue( cmp )
    local self = {}
    local nodemap = {}
    local heap = {}
    local next = 1

    local function swap( i1, i2 )
        heap[ i1 ].idx, heap[ i2 ].idx = i2, i1
        heap[ i1 ], heap[ i2 ] = heap[ i2 ], heap[ i1 ]
    end

    local function percolateDown( i )
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

    local function percolateUp( i )
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
                if i == next then return nil end
                local v = heap[ i ]
                i = i + 1
                return v.key, v.value
            end
        end,

        insert = function( val, key )
            if nodemap[ val ] then
                self.update( val, key )
                return
            end
            local node = {key = key, value = val, idx = next}
            nodemap[ val ] = node

            heap[ next ] = node
            next = next + 1
            percolateUp( next - 1 )

        end,

        -- TODO: replace this with percolation
        update = function( val, key )
            if self.remove( val ) then
                self.insert( val, key )
            end
        end,

        remove = function ( val )

            if next == 1 then return nil end
            if nodemap[ val ] == nil then return nil end
            local node = nodemap[ val ]
            nodemap[ val ] = nil

            next = next - 1
            if next == 1 then
                heap[ next ] = nil
                return val
            end

            local i = node.idx -- gets changed by swap
            swap( node.idx, next )
            heap[ next ] = nil

            percolateUp( i )
            percolateDown( i )

            return val
        end,

        top = function()
            return heap[1] and heap[1].value
        end,

        getKey = function( val )
            local node = nodemap[ val ]
            if node then
                return node.key
            end
            return nil
        end,

        topKey = function()
            if heap[1] == nil then return nil end
            return heap[1].key
        end,

        pop = function()
            if heap[1] then
                return self.remove( heap[1].value )
            end
            return nil
        end,

        contains = function( node )
            return nodemap[ node ] ~= nil
        end,

        length = function()
            return next - 1
        end,
    }

    return self
end

