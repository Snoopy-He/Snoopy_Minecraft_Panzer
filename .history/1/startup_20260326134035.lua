-----------main control computer startup file-----------

local modem = peripheral.find("modem")
local remote = peripheral.find("tweaked_controller")
--local SCR=peripheral.find("monitor")

local ang_step = 1 --每个周期遥控器控制云台的角度增量
local pi = 3.1415926

function rad_to_deg(rad)
    return rad * 180 / math.pi
end

function deg_to_rad(deg)
    return deg * math.pi / 180
end

local chassis = {
    max_tar_spd = 200,
    max_tar_turn_spd = 50,
    tar_spd = 0,
    tar_turn_spd = 0,
    left_tar_spd = 0,
    right_tar_spd = 0,
    speed = "stop",
    turn = "straight",
}

local gimbal = {
    yaw_ang = 0,
    pitch_ang = 0,
    mode = 0,    --0: normal mode  1:stabilize mode
    fire_permit = 0,
    chassis_yaw_spd = 0
}

local keyboard = {
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
    modem.open(4)   --gimbal control topic

    gimbal.yaw_ang = deg_to_rad(90)
    gimbal.pitch_ang = deg_to_rad(0)
    os.sleep(1)
    print("main control computer init success")
end

function remote_receive_task()
    keyboard.button.left_mouse = remote.getButton(10)
    keyboard.button.right_mouse = remote.getButton(11)
    keyboard.button.shift = remote.getButton(7)
    keyboard.button.space = remote.getButton(9)
    keyboard.button.up = remote.getButton(12)
    keyboard.button.down = remote.getButton(14)
    keyboard.button.left = remote.getButton(15)
    keyboard.button.right = remote.getButton(13)
    keyboard.button.u = remote.getButton(5)
    keyboard.button.i = remote.getButton(6)
    keyboard.axis.ws = remote.getAxis(2)
    keyboard.axis.ad = remote.getAxis(1)
    if keyboard.axis.ws < 0 then
        keyboard.button.w = true
        keyboard.button.s = false
    elseif keyboard.axis.ws > 0 then
        keyboard.button.w = false
        keyboard.button.s = true
    else
        keyboard.button.w = false
        keyboard.button.s = false
    end

    if keyboard.axis.ad < 0 then
        keyboard.button.a = true
        keyboard.button.d = false
    elseif keyboard.axis.ad > 0 then
        keyboard.button.a = false
        keyboard.button.d = true
    else
        keyboard.button.a = false
        keyboard.button.d = false
    end
end

function chassis_remote_get()
    if keyboard.button.w then
        chassis.speed = "forward"
    elseif keyboard.button.s then
        chassis.speed = "backward"
    else
        chassis.speed = "stop"
    end

    if keyboard.button.a then
        chassis.turn = "left"
    elseif keyboard.button.d then
        chassis.turn = "right"
    else        
        chassis.turn = "straight"
    end
end

function chassis_speed_set()
    chassis.speed = "forward"
    if chassis.speed == "stop" then
        chassis.tar_spd = 0
    elseif chassis.speed == "forward" then
        chassis.tar_spd = chassis.max_tar_spd
    elseif chassis.speed == "backward" then
        chassis.tar_spd = -chassis.max_tar_spd
    end
    --chassis.turn ="right"
    if chassis.turn == "straight" then
        chassis.tar_turn_spd = 0
    elseif chassis.turn == "left" then
        chassis.tar_turn_spd = chassis.max_tar_turn_spd
    elseif chassis.turn == "right" then
        chassis.tar_turn_spd = -chassis.max_tar_turn_spd
    end

    chassis.left_tar_spd = chassis.tar_spd - chassis.tar_turn_spd
    chassis.right_tar_spd = chassis.tar_spd + chassis.tar_turn_spd

end

function gimbal_remote_get()
    if keyboard.button.u then
        if gimbal.mode == 0 then
            gimbal.mode = 1
        else
            gimbal.mode = 0
        end
    end

    if keyboard.button.left then
        gimbal.yaw_ang = gimbal.yaw_ang - deg_to_rad(ang_step)
    end

    if keyboard.button.right then
        gimbal.yaw_ang = gimbal.yaw_ang + deg_to_rad(ang_step)
    end

    if keyboard.button.up then
        gimbal.pitch_ang = gimbal.pitch_ang + deg_to_rad(ang_step)/2
    end

    if keyboard.button.down then
        gimbal.pitch_ang = gimbal.pitch_ang - deg_to_rad(ang_step)/2
    end

    if keyboard.button.space then
        gimbal.fire_permit = 1
    else
        gimbal.fire_permit = 0
    end

end

function chassis_control_task()
    chassis_remote_get()
    chassis_speed_set()
end

function gimbal_control_task()
    gimbal_remote_get()
end

function message_send_task()
    print(gimbal.yaw_ang)
    modem.transmit(1, 1, tostring(chassis.left_tar_spd.." "..chassis.right_tar_spd))
    modem.transmit(4, 4, tostring(gimbal.mode.." "..gimbal.yaw_ang.." "..gimbal.pitch_ang.." "..gimbal.fire_permit.." "..gimbal.chassis_yaw_spd))
    os.sleep(0.05)
end

function message_receive_task()
    local event, modemSide, senderChannel, 
    replyChannel, message, senderDistance = os.pullEvent("modem_message")
    if senderChannel == 1 and message ~= nil then
        gimbal.chassis_yaw_spd = message
    end
end

init()
while true do
    parallel.waitForAll(remote_receive_task,chassis_control_task, gimbal_control_task,message_send_task,message_receive_task)
end