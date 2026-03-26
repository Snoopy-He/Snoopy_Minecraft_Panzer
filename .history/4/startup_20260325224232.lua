--------generator_control_computer--------
local generator = peripheral.find("electric_motor")

function init()
    if generator == nil then
        print("generator not found")
        while true do
        end
    end
end