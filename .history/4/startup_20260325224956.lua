--------generator_control_computer--------
local generator = peripheral.find("electric_motor")
local modem = peripheral.find("modem")

local status = false
local bat_percent = 0

function init()
    if generator == nil then
        print("generator not found")
        while true do
        end
    end

    if modem == nil then
        print("modem not found")
        while true do
        end
    end
    modem.open(3)  --electrical message topic
end

function generator_on()
    generator.setSpeed(1)
end

function generator_off()
    generator.stop()
end

function message_receive_task()
    local event, modemSide, senderChannel, 
    replyChannel, message, senderDistance = os.pullEvent("modem_message")
    if senderChannel == 3 and message ~= nil then
        bat_percent = message
        print(message)
    else 
        bat_percent  = 0;
    end
    if redstone.getInput

init()
while true do
    generator_off()
    print("generator shutdown")
    --os.sleep(0.05)
end