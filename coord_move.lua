function generic_goto( t, map, move_fn, xf, yf, zf, x, y, z )
    DStarLite( {xf, yf, zf, 0}, {x, y, z, 0}, map, function( v, cost, i )
        return move_fn( t, v, cost, i )
    end)

    return true
end

function gocoord( t, v, opts )
    opts = opts or {}
    local state = t( 'getState' )
    local xf, yf, zf = state.x, state.y, state.z
    local move_fn = opts.move_fn or CoordMove

    return generic_goto( t, nil, move_fn, xf, yf, zf, v[1], v[2], v[3] )
end

function gostate( t, to, opts )
    local ret = gocoord( t, stateToVert( to ), opts )

    faceDirection( t, to.dir )

    return ret
end

function _faceDirection( t, d, curDir )
    -- frame shift so that turtle is facing 0 (north).  Delta is the turn direction and count
    -- Also, math.mod() is different than mod operator - math.mod handles negatives
    local delta = d - curDir
    --print( 'face ', d, 'from', curDir )

    if delta == 0 then
        return
    end

    local cmd = nil

    if math.abs( delta ) == 3 then
        delta = delta / -3
    end

    if delta == 0 then return
    elseif delta > 0 then cmd = 'turnRight'
    else cmd = 'turnLeft'
    end

    --print( 'turning: '..cmd )
    local ccw = 1
    if delta < 0 then ccw = -1 end
    for i = ccw, delta, ccw do
        t( cmd )
    end
end

function faceCoord( t, v )
    local state = t( 'getState' )
    local dx, dy = v[1], v[2]
    local dir = dx + dy - 1 * math.abs( dy )
    dir = math.mod( dir + 4, 4 )

    if dx == 0 and dy == 0 then
        return
    end

    _faceDirection( t, dir, state.dir )
end

function CoordMove( t, v, cost, i )
    local state = t( 'getState' )
    local dx, dy, dz = v[1], v[2], v[3]
    local cmd = 'forward'

    if dx == 0 and dy == 0 and dz == 0 then
        -- DStarLite sometimes says to move to the current location.  I may or may not change that.
        return cost
    end

    if dx ~= 0 or dy ~= 0 then
        faceCoord( t, v )
    end

    if dz ~= 0 then
        if dz > 0 then cmd = 'up'
        else cmd = 'down'
        end
    end

    if not t( cmd ) then
        return 1 / 0
    end

    return cost
end

function DriveTo( t, v, cost, i )
    local state = t( 'getState' )
    local dx, dy = v[1], v[2]
    local dir = dx + dy - 1 * math.abs( dy )
    dir = math.mod( dir + 4, 4 )

    if dx == 0 and dy == 0 then
        -- DStarLite sometimes says to move to the current location.  I may or may not change that.
        return cost
    end

    _faceDirection( t, dir, state.dir )

    if not drive( t, 1 ) then
        return 1 / 0
    end

    return cost
end
