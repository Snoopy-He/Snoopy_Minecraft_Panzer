-----------main control computer startup file-----------

local modem = peripheral.find("modem")
local remote = peripheral.find("tweaked_controller")
--local SCR=peripheral.find("monitor")

local ang_step = 3.0 --每个周期遥控器控制云台的角度增量
local pi = 3.1415926

function rad_to_deg(rad)
    return rad * 180 / math.pi
end

function deg_to_rad(deg)
    return deg * math.pi / 180
end

local button_state = {}

function button_state:new()
    local obj = {state = "false",last_state = "false",flag = false,last_flag = false}
    setmetatable(obj, button_state)
    return obj
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
    yaw_ang = 0.0,
    pitch_ang = 0.0,
    mode = 1,    --0: normal mode  1:stabilize mode
    fire_permit = 0,
    chassis_yaw_spd = 0
}

local keyboard = {
    button ={
        left_mouse = button_state:new(),
        right_mouse = button_state:new(),
        shift = button_state:new(),
        space = button_state:new(),
        up = button_state:new(),
        down = button_state:new(),
        left = button_state:new(),
        right = button_state:new(),
        w = button_state:new(),
        a = button_state:new(),
        s = button_state:new(),
        d = button_state:new(),
        u = button_state:new(),
        i = button_state:new(),
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

    gimbal.yaw_ang = deg_to_rad(-90)
    gimbal.pitch_ang = deg_to_rad(0)
    os.sleep(1)
    print("main control computer init success")
end

function button_update(state)
    if state.flag then
        state.state = "hold"
    elseif state.last_state == "true" and state.last_flag == true then
        state.state = "false"
        state.last_state = "false"
    elseif state.last_state == "false" and state.last_flag == true then
        state.state = "true"
        state.last_state = "true"
    end
    state.last_flag = state.flag
end

function remote_state_update()
    button_update(keyboard.button.left_mouse)
    button_update(keyboard.button.right_mouse)
    button_update(keyboard.button.shift)
    button_update(keyboard.button.space)
    button_update(keyboard.button.up)
    button_update(keyboard.button.down)
    button_update(keyboard.button.left)
    button_update(keyboard.button.right)
    button_update(keyboard.button.w)
    button_update(keyboard.button.a)
    button_update(keyboard.button.s)
    button_update(keyboard.button.d)
    button_update(keyboard.button.u)
    button_update(keyboard.button.i)
end

function remote_receive_task()
    keyboard.button.left_mouse.flag = remote.getButton(10)
    keyboard.button.right_mouse.flag = remote.getButton(11)
    keyboard.button.shift.flag = remote.getButton(7)
    keyboard.button.space.flag = remote.getButton(9)
    keyboard.button.up.flag = remote.getButton(12)
    keyboard.button.down.flag = remote.getButton(14)
    keyboard.button.left.flag = remote.getButton(15)
    keyboard.button.right.flag = remote.getButton(13)
    keyboard.button.u.flag = remote.getButton(5)
    keyboard.button.i.flag = remote.getButton(6)
    keyboard.axis.ws = remote.getAxis(2)
    keyboard.axis.ad = remote.getAxis(1)
    if keyboard.axis.ws < 0 then
        keyboard.button.w.flag = true
        keyboard.button.s.flag = false
    elseif keyboard.axis.ws > 0 then
        keyboard.button.w.flag = false
        keyboard.button.s.flag = true
    else
        keyboard.button.w.flag = false
        keyboard.button.s.flag = false
    end

    if keyboard.axis.ad < 0 then
        keyboard.button.a.flag = true
        keyboard.button.d.flag = false
    elseif keyboard.axis.ad > 0 then
        keyboard.button.a.flag = false
        keyboard.button.d.flag = true
    else
        keyboard.button.a.flag = false
        keyboard.button.d.flag = false
    end

    remote_state_update()
end

function chassis_remote_get()
    if keyboard.button.w.state == "hold" then
        chassis.speed = "forward"
    elseif keyboard.button.s.state == "hold" then
        chassis.speed = "backward"
    else
        chassis.speed = "stop"
    end

    if keyboard.button.a.state == "hold" then
        chassis.turn = "left"
    elseif keyboard.button.d.state == "hold" then
        chassis.turn = "right"
    else        
        chassis.turn = "straight"
    end
end

function chassis_speed_set()
    --chassis.speed = "forward"
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
    if keyboard.button.u.state == "true" then
        gimbal.mode = 1
    elseif keyboard.button.u.state == "false" then
        gimbal.mode = 0
    end

    if keyboard.button.left.state == "hold" then
        gimbal.yaw_ang = gimbal.yaw_ang + deg_to_rad(ang_step)
        if gimbal.yaw_ang > pi then
            gimbal.yaw_ang = -pi
        end
    end

    if keyboard.button.right.state == "hold" then
        gimbal.yaw_ang = gimbal.yaw_ang - deg_to_rad(ang_step)
        if gimbal.yaw_ang < -pi then
            gimbal.yaw_ang = pi
        end
    end

    if keyboard.button.up.state == "hold" then
        gimbal.pitch_ang = gimbal.pitch_ang + deg_to_rad(ang_step)
    end

    if keyboard.button.down.state == "hold" then
        gimbal.pitch_ang = gimbal.pitch_ang - deg_to_rad(ang_step)
    end

    if keyboard.button.space.state == "hold" then
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
    print(gimbal.mode)
    modem.transmit(1, 1, tostring(chassis.left_tar_spd.." "..chassis.right_tar_spd))
    modem.transmit(4, 4, tostring(string.format("%d", gimbal.mode).." "..string.format("%.3f", gimbal.yaw_ang).." "..string.format("%.3f", gimbal.pitch_ang).." "..string.format("%d", gimbal.fire_permit).." "..string.format("%.3f", gimbal.chassis_yaw_spd)))
    os.sleep(0.05)
end

function message_receive_task()
    local event, modemSide, senderChannel, 
    replyChannel, message, senderDistance = os.pullEvent("modem_message")
    if senderChannel == 1 and message ~= nil then
        gimbal.chassis_yaw_spd = tonumber(message)
        --print("chassis yaw spd:"..string.format("%.3f", gimbal.chassis_yaw_spd))
    end
end

init()
while true do
    parallel.waitForAll(remote_receive_task,chassis_control_task, gimbal_control_task,message_send_task,message_receive_task)
end