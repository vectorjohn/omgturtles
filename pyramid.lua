
local settings = {
    channel = 129,
    base = 511
}

local function getModem()
    local sides = {'left', 'right', 'top', 'bottom', 'front', 'back' }
    for i=1, table.getn( sides ) do
        if peripheral.isPresent( sides[i] ) and peripheral.getType( sides[i] ) == 'modem' then
            return peripheral.wrap( sides[i] )
        end
    end

    return nil
end

local function waitForMessage( modem )
    local event, modemSide, senderChannel, replyChannel, message = os.pullEvent( 'modem_message' )

    message = textutils.unserialize( message )
    return {
        cmd = message.cmd,

        send = function( resp )
            modem.transmit( replyChannel, senderChannel, textutils.serialize( resp ) )
        end
    }
end

local function beController()
    local modem = getModem()
    modem.open( settings.channel )

    local jobs = generateJobs()

    while true do
        message = waitForMessage( modem )

        if message.cmd == 'getjob' then
            -- TODO: work on this    
        end
    end
end

local function miningJob( x, z )
    return {
        x = x,
        y = 0,
        z = z,
        length = settings.base
    }
end

local function generateJobs()
    local jobs = PQueue( function( j1, j2 )
        local diff = j1.z - j2.z
        if diff ~= 0 then
            return -diff -- z starts at 0, but we go down
        end

        return j1.x - j2.x
    end)

    --just go down to 100.  If we run out of jobs, more can be generated, but I assume we're closer than 100
    for z = 0, -100, -3 do
        for x = 0, settings.base - 1 do
            jobs.insert( miningJob( x, z ) ) 
        end
    end

    return jobs
end
