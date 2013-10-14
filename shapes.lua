if not table.merge then
    function table.merge( target, ... )
        for i=1, table.getn( arg ) do
            for k, v in pairs( arg[i] ) do
                target[k] = v
            end
        end

        return target
    end
end

function bresenham( v1, v2 )
    local ov = v1
    v1 = {0, 0, 0}
    v2 = {v2[1] - ov[1], v2[2] - ov[2], v2[3] - ov[3]}

    local x0, y0, z0, x1, y1, z1 = v1[1], v1[2], v1[3], v2[1], v2[2], v2[3]

    local dx, dy = math.abs( v2[1] )

--[[
function line(x0, y0, x1, y1)
   dx := abs(x1-x0)
   dy := abs(y1-y0) 
   if x0 < x1 then sx := 1 else sx := -1
   if y0 < y1 then sy := 1 else sy := -1
   err := dx-dy
 
   loop
     setPixel(x0,y0)
     if x0 = x1 and y0 = y1 exit loop
     e2 := 2*err
     if e2 > -dy then 
       err := err - dy
       x0 := x0 + sx
     end if
     if e2 <  dx then 
       err := err + dx
       y0 := y0 + sy 
     end if
   end loop
--]]

end

shape = {}

function shape.line( t, opts )
    opts = table.merge( {
        v1 = false,
        v2 = {0, 0, 0},
    }, opts )

    local state = t( 'getState' )

    if not opts.v1 then
        return true
    end
    if not opts.v2 then
        opts.v2 = v1
        opts.v1 = stateToVert( state )
    end
end

-- a plain line, only changing in one direction.
-- e.g. 0,0,0 to 0,10,0
function shape.straightline( t, opts )
    opts = table.merge( {
        v1 = false,
        dir = false,
        dist = 0,
        retrymove = nil,
        before = function() end,
        after = function() end,
        move = function() return t( 'forward' ) end,
    }, opts )

    if opts.v1 == false then
        opts.v1 = stateToVert( t( 'getState' ) )
    end
    if opts.dir == false then
        opts.dir = opts.v1[4]
    end


    retrymove( t, opts.v1, { retry = opts.retrymove } )
    faceDirection( t, opts.dir )

    --starting at 1 so that if they say go 1, I get one call of the move callbacks
    for i=1, opts.dist do
        if opts.before() == false then return false end
        if opts.move( t ) == false then return false end
        if opts.after() == false then return false end
    end

    return true
end

function shape.rect( t, opts )
    opts = table.merge( {
        v1 = false,
        v2 = false,
        filled = false,
        onrect = function() end,
    }, opts )

    if opts.v2 == false then return true end
    if opts.v1 == false then opts.v1 = stateToVert( t( 'getState' ) ) end

    local samex = false
    local ret = true

    if opts.v1[1] >= opts.v2[1] then
        samex = true
        opts.v1 = table.merge( {}, opts.v1, {opts.v2[1]} )
    end

    if opts.v1[2] >= opts.v2[2] then
        --if samex then return true end
        if samex then
            --special case to handle center block
            ret = ret and shape.straightline( t, table.merge( {}, opts, {
                v1 = opts.v1,
                dir = 0,
                dist = 1,
            }))

            if ret and opts.onrect() == false then return false end
            return ret

        end
        opts.v2 = table.merge( {}, opts.v1, {[2] = opts.v2[2]} )
    end

    ret = ret and shape.straightline( t, table.merge( {}, opts, {
        v1 = opts.v1,
        dir = 0,
        dist = opts.v2[2] - opts.v1[2],
    }))
    ret = ret and shape.straightline( t, table.merge( {}, opts, {
        v1 = false,
        dir = 1,
        dist = opts.v2[1] - opts.v1[1],
    }))
    ret = ret and shape.straightline( t, table.merge( {}, opts, {
        v1 = false,
        dir = 2,
        dist = opts.v2[2] - opts.v1[2],
    }))
    ret = ret and shape.straightline( t, table.merge( {}, opts, {
        v1 = false,
        dir = 3,
        dist = opts.v2[1] - opts.v1[1],
    }))

    if ret and opts.filled then
        t( 'turnRight' )
        if opts.onrect() == false then return false end
        local curstate = t( 'getState' )

        opts.v1 = {opts.v1[1] + 1, opts.v1[2] + 1, curstate.z, opts.v1[4]}
        opts.v2 = {opts.v2[1] - 1, opts.v2[2] - 1, curstate.z, opts.v2[4]}
        return shape.rect( t, opts )
    end

    return ret
end

function shape.pyramid( t, opts )
    t( 'up' )
    return shape.rect( t, table.merge( {
        filled = true,
        after = function()
            t( 'placeDown' )
        end,
        onrect = function()
            t( 'up' )
        end
    }, opts))

end

-- point a to point b with the fewest turns manhattan path
-- E.g. to do 0,0,0 to 3,5,7, it would
-- drive to 3,0,0 -> 3,5,0 -> 3,5,7
function shape.manline( t, opts )
end

--ctx may contain turtle settings, location of chests, inventory, etc.
--step is a callback to call on each step
--v1 and v2 define the volume of the cuboid
function shape.cuboid( t, ctx, step, v1, v2 )
end
