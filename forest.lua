
logging = false

if ( os.getComputerLabel() or '' ) == '' then
    os.setComputerLabel( os.getComputerID().. '' )
end

log = '/john/forest_'.. os.getComputerLabel().. '.log'

function mcstamp()
    return os.day().. 'T'.. os.time()
end

function templog( s )
    if logging then
        local fh = fs.open( log, 'a' )
        fh.write( mcstamp().. ': '.. s.. '\n' )
        fh.close()
    end
    print( s )
end

function xxiowrite( s )
    local fh = fs.open( log, 'a' )
    fs.write( mcstamp().. ': '.. s.. '\n' )
    fs.close()
    owrite( s )
end

function _gotocoord( t, map, xf,yf,zf, x, y, z )

    if z == nil then
        x, y, z = xf, yf, zf
        local state = t( 'getState' )
        xf, yf, zf = state.x, state.y, state.z
    end

    return generic_goto( t, map, CoordMove, xf, yf, zf, x, y, z )
end

function driveToCoord( t, x, y )
    local state = t( 'getState' )
    return generic_goto( t, nil, DriveTo, state.x, state.y, 0, x, y, 0 )
end

function gotocoord( t, xf, yf, zf, x, y, z )
    return _gotocoord( t, nil, xf, yf, zf, x, y, z )
end

function hackMoveWrap( move_fn, inv )
    return function( t, v, cost, i)

        local newcost = move_fn( t, v, cost, i )

        if newcost > cost then
            -- I'm assuming move_fn was trying to move forward, up, or down.
            local dig, compare = 'dig', 'compare'
            if v[3] == 1 then dig, compare = 'digUp', 'compareUp' end
            if v[3] == -1 then dig, compare = 'digDown', 'compareDown' end
            
            for i=1,16 do
                if selectIfHackable( t, i, inv[i] ) and t( compare ) and t( dig ) then
                    -- was able to break it instead
                    return move_fn( t, v, cost, i )
                end
            end
        end

        return newcost
    end
end

function hackto( t, inv, x, y, z )
    local state = t( 'getState' )
    local xf, yf, zf = state.x, state.y, state.z
    return generic_goto( t, nil, hackMoveWrap( CoordMove, inv ), xf, yf, zf, x, y, z )
end

function hackDriveTo( t, inv, x, y )
    local state = t( 'getState' )
    return generic_goto( t, nil, hackMoveWrap( DriveTo, inv ), state.x, state.y, 0, x, y, 0 )
end

function hackToState( t, inv, to )

    if not hackto( t, inv, to.x, to.y, to.z ) then
        return false
    end

    faceDirection( t, to.dir )

    return true
end

function hackDriveToState( t, inv, to )
    if not hackDriveTo( t, inv, to.x, to.y ) then
        return false
    end

    faceDirection( t, to.dir )

    return true
end

local driveToState = hackDriveToState

--[[
function hackToState( t, to )
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
    if not driveToCoord( t, to.x, to.y ) then
        return false
    end

    local from = t( 'getState' )
    while from.dir ~= to.dir do
        t( 'turnLeft' )
        from = t( 'getState' )
    end

    return true
end
--]]

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

function emptyInventory( t, inv, places )
    if not places.harvest or not hackToState( t, inv, places.harvest ) then
        templog( 'Failed to empty inventory - could not get to harvest chest' )
        return false
    end

    local droppedAny = false
    for i = 1, 16 do
        t( 'select', i )
        local item = inv[i]
        if type(item) ~= 'table' then
            item = {'any', item or 0}
        end
        if not t( 'drop', math.max( 0, t( 'getItemCount', i ) - item[2] ) ) then
            return droppedAny
        end

        droppedAny = droppedAny or t( 'getItemCount', i ) == 0
    end

    return droppedAny
end

--assumes slot 15 is a full fuel can
function refuel( t, inv, places )
    local cfg = t( 'getConfig' )
    if not cfg.safeFuelLevel then
        cfg.safeFuelLevel = 1000
        t( 'setConfig', 'safeFuelLevel', cfg.safeFuelLevel )
    end

    if cfg.safeFuelLevel < t( 'getFuelLevel' ) then
        templog( 'No need to refuel' )
        return true
    end

    if not places.refuel or not hackToState( t, inv, places.refuel ) then
        -- do NOT refuel.  Didn't find my way to a chest.
        templog( 'Failed to refuel - could not find refuel chest' )
        return false
    end

    local slot = selectEmpty( t )
    if not slot then
        templog( 'Failed to refuel - could not find an empty slot' )
        return false
    end

    local trash = {}
    while t( 'getFuelLevel' ) < cfg.safeFuelLevel do
        slot = selectEmpty( t )
        if not slot then
            if not bottleReturn( t, inv, places, trash ) then
                templog( 'Failed to refuel - could not dispose of empties' )
                return false
            end
            trash = {}
            slot = selectEmpty( t )

            if not hackToState( t, inv, places.refuel ) then
                templog( 'Failed to refuel - could not get back to fuel chest after bottle return' )
                return false
            end
        end

        if not t( 'suck' ) then
            templog( 'Failed to refuel - No more fuel in the fuel chest' )
            return false
        end

        if not t( 'refuel' ) then
            table.insert( trash, slot )
            templog( 'Refueling - who put this shit in the fuel chest?  It is not delicious.' )
        else
            if trash[1] then
                t( 'transferTo', trash[1], 1 )  -- try combining the empty fuel cans
            elseif t( 'getItemCount', slot ) == 1 then
                table.insert( trash, slot )
            end
        end
    end

    if t( 'getItemCount', slot ) > 0 then
        bottleReturn( t, inv, places, trash )
    end

    return true
end

function bottleReturn( t, inv, places, trash )
    if not places.bottlereturn or not hackToState( t, inv, places.bottlereturn ) then
        return false
    end

    if table.getn( trash ) == 0 then
        return false
    end

    for i=1, table.getn( trash ) do
        t( 'select', trash[i] )
        if not t( 'drop' ) then
            return false
        end
    end
    return true
end

function chopTree( t, inv )
    if not findMatch( t, 16, 16 ) then
        -- not sure this is a tree
        return false
    end

    local state = t( 'getState' )
    t( 'dig' ) -- now the selected block is the tree's logs
    t( 'forward' )

    followChop( t, inv )

    hackToState( t, inv, state )

    return true
end

--follow blocks matching the currently selected one
function followChop( t, inv )

    local h = 0
    local leaf = 5
    local sapling = 1

    while t( 'compareUp' ) do
        t( 'digUp' )
        t( 'up' )
        h = h + 1
    end

    for i = leaf, 16 do
        if t( 'getItemCount', i ) > 0 then
            sapling = i
            break
        end
    end

    local function digmaybe( d )
        if t( 'compare'.. d ) then t( 'dig'.. d ) return 1 end
        return 0
    end

    local function lower()
        if h > 0 then t( 'down' ) h = h - 1 end
        if h > 0 then t( 'down' ) h = h - 1 end
        if h > 0 then t( 'down' ) h = h - 1 return true end
        return false
    end

    if h > 0 then t( 'down' ) h = h - 1 end

    t( 'select', leaf )

    local abort = false
    while h > 0 do
        local dug, tries = 0, 0

        if not abort then
            local st = t( 'getState' )
            spiralDo( t, 2, function()
                dug = dug + digmaybe( '' )
                dug = dug + digmaybe( 'Up' )
                dug = dug + digmaybe( 'Down' )
                tries = tries + 3

                if dug / tries < .2 then
                    --don't waste time digging empty space
                    abort = true
                    return false
                end
            end)
            hackToState( t, inv, st )
        end

        lower()
    end

    -- this needs to be an option.  to incrase seedling production.
    -- often by the time i'm done tearing up the leaves, I see
    -- 1 or 2 saplings on the ground.  I need those saplings!
    t( 'up' )
    if h <= 1 then
        spiralDo( t, 2, function()
            while t( 'suckDown' ) do end
        end)
    end

    --make sure the saplings are in slot 1
    combineAll( t, 1 )

    --[[ at least for rubber, this isn't necessary.  and it wouldn't really work anyway
    --it's supposed to find branches, but it would not find diagonal ones.
    for i=1, 4 do
        if t( 'compare' ) then
            local state = t( 'getState' )
            t( 'dig' )
            t( 'forward' )
            followChop( t )
            hackToState( t, state )
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

    --the random is because I can't decide how big to do this, so sometimes do 3
    spiralDo( t, 2 +  math.floor(math.random() * 1.2), function()
        while t( 'suckDown' ) do end
    end)
    t( 'down' )
    --hackToState( t, state )   --experimentally leaving this out to save fuel.
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
    templog( 'Out of saplings' )
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
        -- time since planting - a few minutes in minutes
        -- maxing out at 1.  after some time, same priority as a tree
        key = math.min( 1, ((os.clock() - tree.updated) - 15 * 60) / 60 )
        --key = math.min( 1, ((os.clock() - tree.updated) - 60))  -- debugging - fast
    elseif tree.state == TreeState.chopped then
        key = ((os.clock() - tree.updated) - 1 * 60) / 5 -- time since chopping - 2 minutes in quarter minutes
    end

    return key
end

function TimeToAction( tree )
    if tree.state == TreeState.chopped then
        return tree.updated + 1.1 * 60
    end

    return 1/0
end

-- end up one square south of the tree facing north
function getToTree( t, inv, tree )
    if tree.v[3] == nil then
        driveToState( t, inv, {x=tree.v[1], y=tree.v[2] - 1, z=nil, dir=0} )
        tree.v[3] = t( 'getState' ).z
    else
        hackToState( t, inv, {x=tree.v[1], y=tree.v[2] - 1, z=tree.v[3], dir=0} )
    end

    return true
end

function DT(tree)
    templog( 'Tree '.. tree.state.. ': <'.. tree.v[1].. ','.. tree.v[2].. '>' )
end

local Hackable = {
    leaf = true,
    grass = true,
    yflower = true,
    rflower = true,
}

function selectIfHackable( t, slot, item )

    if type( item ) == 'table' and Hackable[ item[1] ] and t( 'getItemCount', slot ) > 0 then
        t( 'select', slot )
        return true
    end
    return false
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

    --I don't like turtle config.  I want something seperate.  a "context" that is independent of the turtle
    t( 'setConfig', 'safeFuelLevel', (width-1) * height * spacing * 10  )
    t( 'setConfig', 'emergencyFuelLevel', (width + height) * spacing * 4 + 10 )
    t( 'setConfig', 'safeEmptySlots', 2 )

    local places = {
        harvest = {x=0, y=-3, z=0, dir=2},
        refuel = {x=2, y=-3, z=0, dir=2},
        bottlereturn = {x=4, y=-3, z=0, dir=2},
    }

    local inv = {
        {'sapling',width * height}, 0, 0, 0,
        {'leaf',1}, {'grass',1}, 0, 0,              --{'yflower',1}, {'rflower',1},
        0, 0, 0, 0,
        0, 0, 0, {'tree',1},
    }

    t( 'turnLeft' )
    t( 'turnLeft' )
    drive( t, 3 )
    hackToState( t, inv, {x=0, y=-3, z=0, dir=2} )
    t( 'setState', 0, 0, 0, 0 )

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

    local lastTree = nil
    local cfg = t( 'getConfig' )
    while true do

        if t( 'getFuelLevel' ) < cfg.emergencyFuelLevel or countEmptySlots( t ) < cfg.safeEmptySlots then
            if not emptyInventory( t, inv, places ) then
                templog( 'No need to waste fuel.  Stopping.' )
                hackToState( t, inv, startState )
                return
            end
            if not refuel( t, inv, places ) then
                templog( 'Ow ow ow ow ow!' )
                hackToState( t, inv, startState )
                return
            end
        end

        local tree = ActionQueue.top()
        
        if ActionQueue.topKey() == math.huge then
            --tree = Q.top()
        end

        if ActionQueue.topKey() < os.clock() then
            -- the tree in the action queue is ready to take action on.
            --templog( 'tree in action queue is ready to do a thing' )
            getToTree( t, inv, tree )
            processTree( t, inv, tree )
            lastTree = tree
            --templog( 'actionqueue update'.. tree.v[1].. 'x'.. tree.v[2].. ':'..TimeToAction( tree) )
            ActionQueue.update( tree, TimeToAction( tree ) )
            --Q.update( tree, tree )
        else
            -- there is nothing with a time limit.  Look for trees near that
            -- find tree closest to 'tree'.  Process it.
            -- Maybe.  Or maybe just modify the old algorithm to circle back
            -- when a time has elapsed.
            tree = closestTree( lastTree or tree )
            if tree then
                io.write( 'processing closest tree: ' )
                DT( tree )
                getToTree( t, inv, tree )
                processTree( t, inv, tree )
                lastTree = tree
                ActionQueue.update( tree, TimeToAction( tree ) )
                --Q.update( tree, tree )
            else
                -- wait for something to happen
                -- this could be event triggered
                -- maybe take this time to refuel or empty inventory
                if t( 'getFuelLevel' ) < cfg.safeFuelLevel then
                    emptyInventory( t, inv, places )
                    refuel( t, inv, places )
                else
                    os.sleep( 15 )
                end
            end
        end
    end

    --hackToState( t, startState )
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
                hackToState( t, startState )
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
            hackToState( t, startState )
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

    hackToState( t, startState )
end

function updateTreeState( tree, state )
    tree.state = state
    tree.updated = os.clock()
end

function processTree( t, inv, tree )
    if tree.state == TreeState.chopped then
        templog( 'Process chopped' )
        local age = os.clock() - tree.updated
        if facingTree( t ) then
            updateTreeState( tree, TreeState.tree )
            processTree( t, inv, tree )
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
            processTree( t, inv, tree )
        end
        --don't bother looking if its been a while.
        if age < 30 * 60 then
            findSaplings( t )
        end
    elseif tree.state == TreeState.tree then
        templog( 'Process tree' )
        chopTree( t, inv )
        plantTree( t )
        updateTreeState( tree, TreeState.sapling )  --changed - chop grinds the tree manually.
    elseif tree.state == TreeState.empty then
        templog( 'Process empty' )
        if plantTree( t ) then
            updateTreeState( tree, TreeState.sapling )
        else
            return false -- couldn't plant.  who knows what to do.
        end
    elseif tree.state == TreeState.sapling then
        templog( 'Process sapling' )
        if facingSapling( t ) then
            -- give it more time
            updateTreeState( tree, TreeState.sapling )
        else
            updateTreeState( tree, TreeState.tree )
            processTree( t, inv, tree )
        end
    elseif tree.state == TreeState.unknown then
        templog( 'Process Unknown.  Checking...' )
        if facingSapling( t ) then
            templog( 'itsa sapling!' )
            updateTreeState( tree, TreeState.sapling )
        elseif facingTree( t ) then
            templog( 'hey a tree' )
            updateTreeState( tree, TreeState.tree )
        elseif facingEmpty( t ) then
            templog( 'Nothing :(' )
            updateTreeState( tree, TreeState.empty )
        else
            return false    --I don't know what to do
        end

        templog( 'Now try processing again' )
        return processTree( t, inv, tree )
    end

    return true
end

function doCleanup( t, width, height, prevState )
end


