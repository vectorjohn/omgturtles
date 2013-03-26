
function _gotocoord( t, map, xf,yf,zf, x, y, z )

    if z == nil then
        x, y, z = xf, yf, zf
        local state = t( 'getState' )
        xf, yf, zf = state.x, state.y, state.z
    end
    DStarLite( {xf, yf, zf, 0}, {x, y, z, 0}, map, function( v, cost, i )
        return CoordMove( t, v, cost, i )
    end)

    return true
end

function driveToCoord( t, x, y )
    local state = t( 'getState' )

    DStarLite( {state.x, state.y, 0, 0}, {x, y, 0, 0}, nil, function( v, cost, i )
        return DriveTo( t, v, cost, i )
    end)

    return true
end

function gotocoord( t, xf, yf, zf, x, y, z )
    return _gotocoord( t, nil, xf, yf, zf, x, y, z )
end

function gostate( t, to )
    local from = t( 'getState' )
    if not gotocoord( t, from.x, from.y, from.z, to.x, to.y, to.z ) then
        return false
    end
    from = t( 'getState' )
    while from.dir ~= to.dir do
        t( 'turnLeft' )
        from = t( 'getState' )
    end

    return true
end

function driveToState( t, to )
    local from = t( 'getState' )
    if not driveToCoord( t, to.x, to.y ) then
        return false
    end
    from = t( 'getState' )
    while from.dir ~= to.dir do
        t( 'turnLeft' )
        from = t( 'getState' )
    end

    return true
end

--finds a block that matches the block in front, or is empty
function findMatchOrEmpty( t )
    for i=1, 16 do
        t( 'select', i )
        if t( 'compare' ) then
            return true
        end
    end

    for i = 1, 16 do
        if t( 'getItemCount', i ) == 0 then
            t( 'select', i )
            return true
        end
    end

    return false
end

function selectEmpty( t )
    for i=1, 16 do
        if t( 'getItemCount', i ) == 0 then
            t( 'select', i )
            return i
        end
    end
    return false
end

function countEmptySlots( t )
    local empty = 0
    for i = 1, 16 do
        if t( 'getItemCount', i ) == 0 then
            empty = empty + 1
        end
    end
    return empty
end

function findMatch( t, from, to )
    for i = from, to do
        t( 'select', i )
        if t( 'compare' ) then
            return true
        end
    end

    return false
end

function emptyInventory( t, inv, places )
    if not places.harvest or not gostate( t, places.harvest ) then
        print( 'Failed to empty inventory - could not get to harvest chest' )
        return false
    end

    local droppedAny = false
    for i = 1, 16 do
        t( 'select', i )
        if not t( 'drop', math.max( 0, t( 'getItemCount', i ) - inv[i] ) ) then
            return droppedAny
        end

        droppedAny = droppedAny or t( 'getItemCount', i ) == 0
    end

    return droppedAny
end

--assumes slot 15 is a full fuel can
function refuel( t, places )
    local cfg = t( 'getConfig' )
    if not cfg.safeFuelLevel then
        cfg.safeFuelLevel = 1000
        t( 'setConfig', 'safeFuelLevel', cfg.safeFuelLevel )
    end

    if cfg.safeFuelLevel < t( 'getFuelLevel' ) then
        print( 'No need to refuel' )
        return true
    end

    if not places.refuel or not gostate( t, places.refuel ) then
        -- do NOT refuel.  Didn't find my way to a chest.
        print( 'Failed to refuel - could not find refuel chest' )
        return false
    end

    local slot = selectEmpty( t )
    if not slot then
        print( 'Failed to refuel - could not find an empty slot' )
        return false
    end

    local trash = {}
    while t( 'getFuelLevel' ) < cfg.safeFuelLevel do
        slot = selectEmpty( t )
        if not slot then
            if not bottleReturn( t, places, trash ) then
                print( 'Failed to refuel - could not dispose of empties' )
                return false
            end
            trash = {}
            slot = selectEmpty( t )

            if not gostate( t, places.refuel ) then
                print( 'Failed to refuel - could not get back to fuel chest after bottle return' )
                return false
            end
        end

        if not t( 'suck' ) then
            print( 'Failed to refuel - No more fuel in the fuel chest' )
            return false
        end

        if not t( 'refuel' ) then
            table.insert( trash, slot )
            print( 'Refueling - who put this shit in the fuel chest?  It is not delicious.' )
        else
            if trash[1] then
                t( 'transferTo', trash[1], 1 )  -- try combining the empty fuel cans
            else
                table.insert( trash, slot )
            end
        end
    end

    if t( 'getItemCount', slot ) > 0 then
        bottleReturn( t, places, trash )
    end

    return true
end

function bottleReturn( t, places, trash )
    if not places.bottlereturn or not gostate( t, places.bottlereturn ) then
        return false
    end

    for i=1, table.getn( trash ) do
        if not t( 'drop' ) then
            return false
        end
    end
    return true
end

function chopTree( t )
    if not findMatch( t, 16, 16 ) then
        -- not sure this is a tree
        return false
    end

    t( 'dig' ) -- now the selected block is the tree's logs
    t( 'forward' )

    followChop( t )

    t( 'back' )

    return true
end

--follow blocks matching the currently selected one
function followChop( t )

    if t( 'compareUp' ) then
        t( 'digUp' )
        t( 'up' )
        followChop( t )
        t( 'down' )
    end

    if t( 'compareDown' ) then
        t( 'digDown' )
        t( 'down' )
        followChop( t )
        t( 'up' )
    end

    --[[ at least for rubber, this isn't necessary.  and it wouldn't really work anyway
    --it's supposed to find branches, but it would not find diagonal ones.
    for i=1, 4 do
        if t( 'compare' ) then
            local state = t( 'getState' )
            t( 'dig' )
            t( 'forward' )
            followChop( t )
            gostate( t, state )
        end

        t( 'turnLeft' )
    end
    --]]
end

function findSaplings( t )
    local state = t( 'getState' )
    t( 'select', 1 )
    drive( t, 1 )
    t( 'suckDown' )
    spiralDo( t, 3, function()
        while t( 'suckDown' ) do end
    end)
    t( 'down' )
    --gostate( t, state )   --experimentally leaving this out to save fuel.
end

function cctimestamp()
    return os.day() * 24 + os.time()
end

function treefarm( t, width, height )
    gotocoord = function( t, xf, yf, zf, x, y, z )
        _gotocoord( t, nil, xf, yf, zf, x, y, z )
    end

    while true do
        local startTime = cctimestamp()

        makeRounds( t, width, height )

        if startTime + 1 > cctimestamp() then
            os.setAlarm( startTime + 1 - cctimestamp() )
            os.pullEvent( 'alarm' )
        end
    end
end

function selectSapling( t )
    for i = 1, 1 do
        if t( 'getItemCount', i ) > 0 then
            t( 'select', i )
            return true
        end
    end
    return false
end

function selectSaplingToUse( t )
    if t( 'getItemCount', 1 ) > 1 then
        selectSapling( t )
        return true
    end
    return false
end

function selectTree( t )
    if t( 'getItemCount', 16 ) > 0 then
        t( 'select', 16 )
        return true
    end
    return false
end

function plantTree( t )
    if selectSaplingToUse( t ) then
        return t( 'place' )
    end
    print( 'Out of saplings' )
    return false
end

function facingTree( t )
    if selectTree( t ) then
        return t( 'compare' )
    end

    return nil  --unknown
end

function facingSapling( t )
    if selectSapling( t ) then
        return t( 'compare' )
    end

    return nil  --unknown
end

function facingEmpty( t )
    if t( 'forward' ) then
        t( 'back' )
        return true
    end
    return false
end

local TreeState = {
    unknown = 'unknown',
    empty = 'empty',
    sapling = 'sapling',
    chopped = 'chopped',
    tree = 'tree',
}

local TimeSensitiveStates = {
    [TreeState.chopped] = TreeState.chopped,
}

local IdleTreeStates = {
    [TreeState.empty] = TreeState.empty,
    [TreeState.tree] = TreeState.tree,
    [TreeState.unknown] = TreeState.unknown,
    [TreeState.sapling] = TreeState.sapling,
}

function Tree( v, state, birth, updated )
    return {
        v = v,
        state = state or TreeState.unknown,
        birth = birth or os.clock(),
        updated = updated or birth or os.clock()
    }
end

function TreeValue( tree )
    local key = 0

    if tree.state == TreeState.tree then
        key = 1
    elseif tree.state == TreeState.empty then
        key = 2
    elseif tree.state == TreeState.unknown then
        key = 3
    elseif tree.state == TreeState.sapling then
        -- time since planting - 5 minutes in minutes
        -- maxing out at 1.  after 5 minutes, same priority as a tree
        key = math.min( 1, ((os.clock() - tree.updated) - 10 * 60) / 60 )
        --key = math.min( 1, ((os.clock() - tree.updated) - 60))  -- debugging - fast
    elseif tree.state == TreeState.chopped then
        key = ((os.clock() - tree.updated) - 1 * 60) / 5 -- time since chopping - 2 minutes in quarter minutes
    end

    return key
end

function TimeToAction( tree )
    if tree.state == TreeState.chopped then
        return tree.updated + 1.4 * 60
    end

    return 1/0
end

-- end up one square south of the tree facing north
function getToTree( t, tree )
    if tree.v[3] == nil then
        driveToState( t, {x=tree.v[1], y=tree.v[2] - 1, z=nil, dir=0} )
        tree.v[3] = t( 'getState' ).z
    else
        gostate( t, {x=tree.v[1], y=tree.v[2] - 1, z=tree.v[3], dir=0} )
    end

    return true
end

function DT(tree)
    print( 'Tree '.. tree.state.. ': <'.. tree.v[1].. ','.. tree.v[2].. '>' )
end

-- assumes turtle is facing north at the trunk of the bottom left corner of the tree farm
-- TODO: solve problem where tree grows bushy and surrounds the turtle.
function TendTreeFarm( t, width, height )
    local startState = t( 'getState' )

    --sorted with smallest tree value at the top
    local Q = PQueue( function( ta, tb )
        return TreeValue( ta ) - TreeValue( tb )
    end)

    -- sorted with small numbers at the top.  probably time.
    local ActionQueue = PQueue( function( ta, tb )
        return ta - tb
        --return TimeToAction( tb ) - TimeToActon( ta )
    end)

    local spacing = 6   -- = space between trees + 1
    local map = {}

    t( 'turnLeft' )
    t( 'turnLeft' )
    drive( t, 3 )
    t( 'setState', 0, 0, 0, 0 )

    --I don't like turtle config.  I want something seperate.  a "context" that is independent of the turtle
    t( 'setConfig', 'safeFuelLevel', width * height * spacing * 5 )
    t( 'setConfig', 'emergencyFuelLevel', (width + height) * spacing + 10 )
    t( 'setConfig', 'safeEmptySlots', 2 )

    local places = {
        harvest = {x=0, y=-3, z=0, dir=2},
        refuel = {x=2, y=-3, z=0, dir=2},
        bottlereturn = {x=4, y=-3, z=0, dir=2},
    }

    local inv = {
        width * height, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 1,
    }

    local chestState = {x=0, y=-3, z = 0, 2 }

    for x = 0, (width - 1) * spacing, spacing do
        map[ x ] = {}
        for y = 1, (height - 1) * spacing + 1, spacing do
            local tree = Tree( {x, y, nil}, TreeState.unknown )
            --Q.insert( tree, tree )
            ActionQueue.insert( tree, TimeToAction( tree ) )
            map[ x ][ y ] = tree
        end
    end


    local function neighbors( tree )
        local x, y = tree.v[1], tree.v[2]
        local nbrs = {}
        local coords = {
            {x + spacing, y},
            {x - spacing, y},
            {x, y + spacing},
            {x, y - spacing},
        }

        for i=1,4 do
            local v = coords[i]
            if map[ v[1] ] and map[ v[1] ][ v[2] ] then
                table.insert( nbrs, map[ v[1] ][ v[2] ] )
            end
        end

        return nbrs
    end

    local function closestTree( tree )
        io.write( 'closest tree to: ' )
        DT( tree )

        local Next = PQueue( function( a, b ) return a - b end )
        local seen = {}
        local haveSaps = selectSaplingToUse( t )

        Next.insert( tree, 0 )
        while Next.top() do
            local topKey = Next.topKey()
            local best = nil

            while Next.topKey() == topKey do
                if IdleTreeStates[ Next.top().state ] ~= nil then
                    local canplant = Next.top().state ~= TreeState.empty or haveSaps
                    if not best and TreeValue( Next.top() ) > 0 and canplant or best and TreeValue( Next.top() ) > TreeValue( best ) and canplant then

                        best = Next.top()
                    end
                end

                for i, nbr in ipairs( neighbors( Next.top() ) ) do
                    if not seen[ nbr ] then
                        seen[ nbr ] = true
                        Next.insert( nbr, Next.topKey() + 1 )
                    end
                end

                Next.pop()
            end

            if best then return best end
        end

        return nil
    end

    local cfg = t( 'getConfig' )
    while true do

        if t( 'getFuelLevel' ) < cfg.emergencyFuelLevel or countEmptySlots( t ) < cfg.safeEmptySlots then
            if not emptyInventory( t, inv, places ) then
                print( 'No need to waste fuel.  Stopping.' )
                gostate( t, startState )
                return
            end
            if not refuel( t, places ) then
                print( 'Ow ow ow ow ow!' )
                gostate( t, startState )
                return
            end
        end

        local tree = ActionQueue.top()
        
        if ActionQueue.topKey() == math.huge then
            --tree = Q.top()
        end

        if ActionQueue.topKey() < os.clock() then
            -- the tree in the action queue is ready to take action on.
            print( 'tree in action queue is ready to do a thing' )
            getToTree( t, tree )
            processTree( t, tree )
            print( 'actionqueue update'.. tree.v[1].. 'x'.. tree.v[2].. ':'..TimeToAction( tree) )
            ActionQueue.update( tree, TimeToAction( tree ) )
            --Q.update( tree, tree )
        else
            -- there is nothing with a time limit.  Look for trees near that
            -- find tree closest to 'tree'.  Process it.
            -- Maybe.  Or maybe just modify the old algorithm to circle back
            -- when a time has elapsed.
            tree = closestTree( tree )
            if tree then
                io.write( 'processing closest tree: ' )
                DT( tree )
                getToTree( t, tree )
                processTree( t, tree )
                ActionQueue.update( tree, TimeToAction( tree ) )
                --Q.update( tree, tree )
            else
                -- wait for something to happen
                -- this could be event triggered
                -- maybe take this time to refuel or empty inventory
                if t( 'getFuelLevel' ) < cfg.safeFuelLevel then
                    emptyInventory( t, inv, places )
                    refuel( t, places )
                end
                os.sleep( 15 )
            end
        end
    end

    --gostate( t, startState )
end

function makeRounds( t, width, height )
    local startState = t( 'getState' )
    local spacing = 5

    t( 'select', 1 )

    t( 'turnLeft' )
    t( 'turnLeft' )
    drive( t, 3 )


    local turn = 'turnRight'
    local waitTime = 3 * 60
    local nextCleanup = os.clock() + waitTime
    local cleanupStart = startState

    for x = 1, width - 1 do
        for y = 1, height - 1 do
            if not chopTree( t ) then
                --last pass probably chopped a tree.  look for saplings
                findSaplings( t )
            end

            --fails if a sapling exists
            plantTree( t )

            --[[
            if not plantTree( t ) then
                gostate( t, startState )
                return false
            end
            --]]

            if os.clock() > nextCleanup then
                doCleanup( t )
                nextCleanup = os.clock() + waitTime
                --cleanupStart = 
            end

            drive( t, spacing + 1 )
        end
        
        chopTree( t )

        plantTree( t )
        --[[
        if not plantTree( t ) then
            gostate( t, startState )
            return false
        end
        --]]

        plantTree( t )
        drive( t, 2 )
        t( turn )

        drive( t, spacing + 1 )
        t( turn )

        if turn == 'turnRight' then
            turn = 'turnLeft'
        else
            turn = 'turnRight'
        end
    end

    gostate( t, startState )
end

function updateTreeState( tree, state )
    tree.state = state
    tree.updated = os.clock()
end

function processTree( t, tree )
    if tree.state == TreeState.chopped then
        print( 'Process chopped' )
        local age = os.clock() - tree.updated
        if facingTree( t ) then
            updateTreeState( tree, TreeState.tree )
            processTree( t, tree )
        elseif facingSapling( t ) then
            --wish there was a nicer way to do this...
            --I want everything to act as if it was set to 
            --sapling at the time it was actually set to chopped
            --(because that's when I plant them)
            updateTreeState( tree, TreeState.sapling )
            tree.updated = tree.updated - age
        else
            -- how?
            updateTreeState( tree, TreeState.unknown )
            processTree( t, tree )
        end
        --don't bother looking if its been a while.
        if age < 30 * 60 then
            findSaplings( t )
        end
    elseif tree.state == TreeState.tree then
        print( 'Process tree' )
        chopTree( t )
        plantTree( t )
        updateTreeState( tree, TreeState.chopped )
    elseif tree.state == TreeState.empty then
        print( 'Process empty' )
        if plantTree( t ) then
            updateTreeState( tree, TreeState.sapling )
        else
            return false -- couldn't plant.  who knows what to do.
        end
    elseif tree.state == TreeState.sapling then
        print( 'Process sapling' )
        if facingSapling( t ) then
            -- give it more time
            updateTreeState( tree, TreeState.sapling )
        else
            updateTreeState( tree, TreeState.tree )
            processTree( t, tree )
        end
    elseif tree.state == TreeState.unknown then
        print( 'Process Unknown.  Checking...' )
        if facingSapling( t ) then
            print( 'itsa sapling!' )
            updateTreeState( tree, TreeState.sapling )
        elseif facingTree( t ) then
            print( 'hey a tree' )
            updateTreeState( tree, TreeState.tree )
        elseif facingEmpty( t ) then
            print( 'Nothing :(' )
            updateTreeState( tree, TreeState.empty )
        else
            return false    --I don't know what to do
        end

        print( 'Now try processing again' )
        return processTree( t, tree )
    end

    return true
end

function doCleanup( t, width, height, prevState )
end


