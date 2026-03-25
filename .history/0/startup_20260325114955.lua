--------chassis control computer startup file--------

local Motor={peripheral.find("Create_RotationSpeedController")}
local modem = peripheral.find("modem")

local left_wheel=Motor[2]
local right_wheel=Motor[1]

local parameter = {
    max_speed = 256,
    left_tar_spd = 0,
    right_tar_spd = 0,
    left_current_spd = 0,
    right_current_spd = 0,
    right_last_tar_spd = 0,
    left_last_tar_spd = 0,
    accel_rate = 8,
    state = "stop",  -- accel, keep, stop
}

local attitude = {
    quaternion = {
        w = 0,
        x = 0,
        y = 0,
        z = 0,
    },
    omega = {
        x = 0,
        y = 0,
        z = 0,
    },
    rotate_matrix = {
        {0, 0, 0},
        {0, 0, 0},
        {0, 0, 0},
    },
    euler = {
        yaw = 0,
        pitch = 0,
        roll = 0
    },
    position = {
        x = 0,
        y = 0,
        z = 0,
    },
    speed = {
        x = 0,
        y = 0,
        z = 0,
    }
}

function math.clamp(value,min,max)
    if value<min then
        return min
    end
    if value>max then
        return max
    end
    return value
end

function math.nil_to_zero(value)
    if value == nil then
        return 0
    end
    return value
end

function send_left_wheel_speed()
    left_wheel.setTargetSpeed(-math.floor(parameter.left_current_spd))
end

function send_right_wheel_speed()
    right_wheel.setTargetSpeed(math.floor(parameter.right_current_spd))
end

function send_both_wheels_speed()
    parallel.waitForAll(send_left_wheel_speed, send_right_wheel_speed)
end

function init()
    if left_wheel == nil then
        print("Left wheel not found")
        modem.transmit(1, 1, "chassis control computer init failed: left wheel not found")
        while true do end
        return
    end
    if right_wheel == nil then
        print("Right wheel not found")
        modem.transmit(1, 1, "chassis control computer init failed: right wheel not found")
        while true do end
        return
    end
    if modem == nil then
        print("Modem not found")
        while true do end
        return
    end

    left_wheel.setTargetSpeed(0)
    right_wheel.setTargetSpeed(0)

    modem.open(1)   --speed control
    modem.transmit(1, 1, "chassis control computer init complete")
    print("chassis control computer init success")
end

function attitude_calc_task()
    attitude.position = ship.getWorldspacePosition()
    attitude.speed = ship.getVelocity()
    attitude.rotate_matrix = ship.getTransformationMatrix()
    attitude.


end

function message_receive_task()
    local event, modemSide, senderChannel, 
    replyChannel, message, senderDistance = os.pullEvent("modem_message")

    if senderChannel == 1 and message ~= nil then
        --print(message)
        parameter.left_last_tar_spd = parameter.left_tar_spd
        parameter.right_last_tar_spd = parameter.right_tar_spd
        parameter.left_tar_spd, parameter.right_tar_spd = message:match("(-?%d+) (-?%d+)")
        parameter.left_tar_spd = math.nil_to_zero(tonumber(parameter.left_tar_spd))
        parameter.right_tar_spd = math.nil_to_zero(tonumber(parameter.right_tar_spd))
        print("left speed: "..parameter.left_tar_spd.." right speed: "..parameter.right_tar_spd)
    end

end

function chassis_control_task()
    if parameter.left_tar_spd > parameter.left_current_spd then
        parameter.left_current_spd = parameter.left_current_spd + parameter.accel_rate
    elseif parameter.left_tar_spd < parameter.left_current_spd then
        parameter.left_current_spd = parameter.left_current_spd - parameter.accel_rate
    else 
        parameter.left_current_spd = parameter.left_tar_spd
    end

    left_current_spd = math.clamp(parameter.left_current_spd, -parameter.left_tar_spd, parameter.left_tar_spd)

    if parameter.right_tar_spd > parameter.right_current_spd then
        parameter.right_current_spd = parameter.right_current_spd + parameter.accel_rate
    elseif parameter.right_tar_spd < parameter.right_current_spd then
        parameter.right_current_spd = parameter.right_current_spd - parameter.accel_rate
    else
        parameter.right_current_spd = parameter.right_tar_spd
    end

    right_current_spd = math.clamp(parameter.right_current_spd, -parameter.right_tar_spd, parameter.right_tar_spd)

    parameter.left_current_spd = math.clamp(parameter.left_current_spd, -parameter.max_speed, parameter.max_speed)
    parameter.right_current_spd = math.clamp(parameter.right_current_spd, -parameter.max_speed, parameter.max_speed)
    send_both_wheels_speed()
end

init()
while true do
    parallel.waitForAll( chassis_control_task, message_receive_task)
end