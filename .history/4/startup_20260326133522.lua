--------generator_control_computer--------
local generator = peripheral.find("electric_motor")
local modem = peripheral.find("modem")

local status = false    --shutdown 
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
    if redstone.getInput("right") then
        status = false
        if bat_percent < 30 then    --手动关闭发电机后电量低于30%自动充电
            status = true
        end
    else
        status = true
        if bat_percent > 95 then    --手动打开发电机后电量大于95%自动断电
            status = false
        end
    end

end

function generator_control_task()
    if status then 
        generator_on()
    else
        generator_off()
    end
end

init()
while true do
    generator_control_task()
    message_receive_task()
    --print("generator is running:"..status)
end