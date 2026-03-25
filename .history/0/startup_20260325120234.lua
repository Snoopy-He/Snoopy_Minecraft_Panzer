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
    angle = {
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
    last_yaw = 0
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

function rad_to_deg(rad)
    return rad * 180 / math.pi
end

function deg_to_rad(deg)
    return deg * math.pi / 180
    
end

function quat_to_euler(q)
    local x, y, z, w = q.x, q.y, q.z, q.w
    
    -- 归一化
    local n = math.sqrt(x*x + y*y + z*z + w*w)
    x, y, z, w = x/n, y/n, z/n, w/n
    
    local m01 = 2*x*y + 2*w*z
    local m11 = 1 - 2*x*x - 2*z*z
    local m21 = 2*y*z - 2*w*x
    local m20 = 2*x*z + 2*w*y
    local m22 = 1 - 2*x*x - 2*y*y
    local m02 = 2*x*z - 2*w*y
    local m00 = 1 - 2*y*y - 2*z*z
    
    -- 万向锁处理
    if math.abs(m21) > 0.999999 then
        local roll = math.pi/2 * (m21 > 0 and 1 or -1)
        local yaw = 0
        local pitch = math.atan2(-m02, m00)
        return roll, pitch, yaw
    end
    
    local roll = math.asin(-m21)
    local yaw  = math.atan2(m20, m22)
    local pitch = math.atan2(m01, m11)
    
    return {yaw = yaw,pitch = pitch,roll = roll}
end

local function mat_to_euler_yxz(R)
    local r11, r12, r13 = R[1][1], R[1][2], R[1][3]
    local r21, r22, r23 = R[2][1], R[2][2], R[2][3]
    local r31, r32, r33 = R[3][1], R[3][2], R[3][3]

    -- 中间角：这里选绕 X 的 pitch
    -- 对 YXZ 顺序的一种常用形式可以取：sin(pitch) = -r32
    local pitch = math.asin(-r32)  -- X
    local cp    = math.cos(pitch)

    local yaw, roll              -- Y, Z

    if math.abs(cp) > 1e-6 then
        -- 绕 Y 的 yaw：用 r31, r33
        yaw  = math.atan2(r31 / cp, r33 / cp)
        -- 绕 Z 的 roll：用 r12, r22
        roll = math.atan2(r12 / cp, r22 / cp)
    else
        -- 万向节锁：|cos(pitch)| ≈ 0，即 pitch ≈ ±pi/2
        pitch = (r32 < 0) and ( math.pi/2) or (-math.pi/2)

        -- 此时 Y、Z 轴旋转耦合，约定 roll 自由、yaw=0 或反之皆可
        -- 这里选 yaw = 0，把自由度并入 roll
        yaw  = 0
        roll = math.atan2(-r21, r11)
    end

    return {yaw = yaw, pitch = pitch, roll = roll}  -- 弧度
end


function attitude_calc_task()
    attitude.last_yaw = attitude.angle.yaw
    attitude.position = ship.getWorldspacePosition()
    attitude.speed = ship.getVelocity()
    attitude.rotate_matrix = ship.getTransformationMatrix()
    attitude.quaternion = ship.getQuaternion()
    attitude.angle = mat_to_euler_yxz(attitude.rotate_matrix)
    attitude.
    print(rad_to_deg(attitude.angle.pitch))

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
        --print("left speed: "..parameter.left_tar_spd.." right speed: "..parameter.right_tar_spd)
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
    parallel.waitForAll(chassis_control_task, message_receive_task,attitude_calc_task)
end