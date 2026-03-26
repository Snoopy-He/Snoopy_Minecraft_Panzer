-----------main control computer startup file-----------

local modem = peripheral.find("modem")
local remote = peripheral.find("tweaked_controller")
--local SCR=peripheral.find("monitor")

local parameter = {
    chassis = {
        max_tar_spd = 200,
        max_tar_turn_spd = 50,
        tar_spd = 0,
        tar_turn_spd = 0,
        left_tar_spd = 0,
        right_tar_spd = 0,
        speed = "stop",
        turn = "straight",
    },

    remote = {
        button ={
            left_mouse = false,
            right_mouse = false,
            shift = false,
            space = false,
            up = false,
            down = false,
            left = false,
            right = false,
            w = false,
            a = false,
            s = false,
            d = false,
            u = false,
            i = false,
        },
        axis = {
            ws = 0,
            ad = 0,
        },
    }
}

--function print(text)
    --SCR.clear()
    --SCR.setCursorPos(1, 1)
    --SCR.write(text)
--end

function init()
    if remote == nil then
        print("Remote controller not found")
        while true do end
        return
    end

    if modem == nil then
        print("Modem not found")
        while true do end
        return
    end

    modem.open(1)
    modem.transmit(1, 1, "main control computer init complete")
    print("main control computer init success")
end

function remote_receive_task()
    parameter.remote.button.left_mouse = remote.getButton(10)
    parameter.remote.button.right_mouse = remote.getButton(11)
    parameter.remote.button.shift = remote.getButton(7)
    parameter.remote.button.space = remote.getButton(9)
    parameter.remote.button.up = remote.getButton(12)
    parameter.remote.button.down = remote.getButton(14)
    parameter.remote.button.left = remote.getButton(15)
    parameter.remote.button.right = remote.getButton(13)
    parameter.remote.button.u = remote.getButton(5)
    parameter.remote.button.i = remote.getButton(6)
    parameter.remote.axis.ws = remote.getAxis(2)
    parameter.remote.axis.ad = remote.getAxis(1)
    if parameter.remote.axis.ws < 0 then
        parameter.remote.button.w = true
        parameter.remote.button.s = false
    elseif parameter.remote.axis.ws > 0 then
        parameter.remote.button.w = false
        parameter.remote.button.s = true
    else
        parameter.remote.button.w = false
        parameter.remote.button.s = false
    end

    if parameter.remote.axis.ad < 0 then
        parameter.remote.button.a = true
        parameter.remote.button.d = false
    elseif parameter.remote.axis.ad > 0 then
        parameter.remote.button.a = false
        parameter.remote.button.d = true
    else
        parameter.remote.button.a = false
        parameter.remote.button.d = false
    end
end

function chassis_remote_set()

function chassis_control_task()
    if parameter.remote.button.w then
        parameter.chassis.speed = "forward"
    elseif parameter.remote.button.s then
        parameter.chassis.speed = "backward"
    else
        parameter.chassis.speed = "stop"
    end

    if parameter.remote.button.a then
        parameter.chassis.turn = "left"
    elseif parameter.remote.button.d then
        parameter.chassis.turn = "right"
    else        
        parameter.chassis.turn = "straight"
    end

    speed_set()
end

function speed_set()
    --parameter.chassis.speed = "forward"
    if parameter.chassis.speed == "stop" then
        parameter.chassis.tar_spd = 0
    elseif parameter.chassis.speed == "forward" then
        parameter.chassis.tar_spd = parameter.chassis.max_tar_spd
    elseif parameter.chassis.speed == "backward" then
        parameter.chassis.tar_spd = -parameter.chassis.max_tar_spd
    end
    --parameter.chassis.turn ="right"
    if parameter.chassis.turn == "straight" then
        parameter.chassis.tar_turn_spd = 0
    elseif parameter.chassis.turn == "left" then
        parameter.chassis.tar_turn_spd = parameter.chassis.max_tar_turn_spd
    elseif parameter.chassis.turn == "right" then
        parameter.chassis.tar_turn_spd = -parameter.chassis.max_tar_turn_spd
    end

    parameter.chassis.left_tar_spd = parameter.chassis.tar_spd - parameter.chassis.tar_turn_spd
    parameter.chassis.right_tar_spd = parameter.chassis.tar_spd + parameter.chassis.tar_turn_spd

    modem.transmit(1, 1, tostring(parameter.chassis.left_tar_spd.." "..parameter.chassis.right_tar_spd))
end

function message_send_task()

end

function gimbal_control_task()

function message_send_task()
    parallel.waitForAll(speed_send)
    os.sleep(0.05)
end

init()
while true do
    --remote_receive_task()
    --chassis_control_task()
    --message_send_task()
    parallel.waitForAll(remote_receive_task, chassis_control_task, message_send_task)
    --print("Speed: "..parameter.chassis.speed.." Turn: "..parameter.chassis.turn)
end