--------generator_control_computer--------
local generator = peripheral.find("electric_motor")

function init()
    if generator == nil then
        print("generator not found")
        while true do
        end
    end
end

function generator_on()
    generator.setSpeed(1)
end

function generator_off()
    generator.setSpeed(0)
end

init()
while true do
    generator_off()
    os.sleep(0.05)
end