-------Electricity control computer startup file--------

local modem = peripheral.find("modem")
local accumulator = peripheral.find("modular_accumulator")

local parameter = {
    max_capacity = 0,
    current_capacity = 0,
    percent = 0,
}

function init()
    if accumulator == nil then
        print("Accumulator not found")
        while true do end
        return
    end

    if modem == nil then
        print("Modem not found")
        while true do end
        return
    end

    modem.open(3)  --electrical control
    modem.transmit(3, 3, "energy control computer init complete")
    print("electricalcontrol computerinit success")
end

function energy_read()
    parameter.last_percent = parameter.percent
    parameter.max_capacity = accumulator.getCapacity()
    parameter.current_capacity = accumulator.getEnergy()
    parameter.percent = accumulator.getPercent()
end

function message_send_task()
    modem.transmit(3, 3, "percent:"..parameter.percent)
    modem.transmit(3, 3, "current_capacity:"..parameter.current_capacity)
    modem.transmit(3, 3, "max_capacity:"..parameter.max_capacity)
    print("percent:"..parameter.percent)
    os.sleep(1)
end

init()
while true do
    energy_read()
    message_send_task()
end
