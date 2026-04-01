-----------left monitor computer----------
local monitor = peripheral.find("monitor")
local modem = peripheral.find("modem")

function init()
    if monitor == nil then
        print("monitor not found")
        while true do end
        return
    end
    if modem == nil then
        print("modem not found")
        while true do end
        return
    end
    modem.open(6)   --online check topic
    modem.transmit(6, 6, "left_monitor_ok")
    print("left monitor computer init success")
end

function message_receive_task()
end

init()
while true do

end