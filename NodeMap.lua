NodeMap = {}

NodeMap._mt = Class( NodeMap )

function NodeMap:new()
    return setmetatable( {
        nodes = {}
    }, NodeMap._mt )
end

function NodeMap:add( n, val, noexpand )
    local nodes = self.nodes

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
end

function NodeMap:hasKey( n )
    return self:get( n ) ~= nil
end

function NodeMap:remove( n )
    self.nodes[ n[1] ][ n[2] ][ n[3] ][ n[4] ] = nil
    --yep, nodes grows with containers forever
end

function NodeMap:get( n )
    local nodes = self.nodes
    return nodes[ n[1] ]
        and nodes[ n[1] ][ n[2] ]
        and nodes[ n[1] ][ n[2] ][ n[3] ]
        and nodes[ n[1] ][ n[2] ][ n[3] ][ n[4] ]
end

function NodeMap:each()
    local nodes = self.nodes
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
end
