local pitch = peripheral.find("servo")
local imu = peripheral.find("spinalyzer")
local transmitter = peripheral.find("transmitter")
local modem = peripheral.find("modem")

local yaw = {}
local pi = math.pi
local time_piece = 0.05

local msg = {
    yaw_ang ="",
    pitch_ang = "",
    mode = "",
    fire_permit = "",
    chassis_yaw_spd = "",
}

function yaw.getAngle()
    return transmitter.callRemote("yaw", "getAngle")
end

function yaw.setPID(p, i, d)
    transmitter.callRemote("yaw", "setPID", p, i, d)
end

function yaw.setOutputTorque(scale)
    transmitter.callRemote("yaw", "setOutputTorque", scale)
end

function yaw.setTargetValue(value)
    transmitter.callRemote("yaw", "setTargetValue", value)
end

function yaw.getAngularVelocity()
    return transmitter.callRemote("yaw", "getAngularVelocity")
end

function yaw.setIsAdjustingAngle(value)
    return transmitter.callRemote("yaw", "setIsAdjustingAngle",value)
end

function yaw.lock()
    transmitter.callRemote("yaw", "lock")
end

function yaw.unlock()
    transmitter.callRemote("yaw", "unlock")
end

function yaw.isLocked()
    return transmitter.callRemote("yaw", "isLocked")
end

function math.matrix_multiply(A, B)
    local result = {}
    for i = 1, #A do
        result[i] = {}
        for j = 1, #B[1] do
            local sum = 0
            for k = 1, #A[1] do
                sum = sum + A[i][k] * B[k][j]
            end
            result[i][j] = sum
        end
    end
    return result
end

function math.mat3_mul_vec3(m, v)
    return {
        m[1][1]*v[1] + m[1][2]*v[2] + m[1][3]*v[3],
        m[2][1]*v[1] + m[2][2]*v[2] + m[2][3]*v[3],
        m[3][1]*v[1] + m[3][2]*v[2] + m[3][3]*v[3],
    }
end

function rad_to_deg(rad)
    return rad * 180 / math.pi
end

function deg_to_rad(deg)
    return deg * math.pi / 180
end

function math.clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end

local attitude= {
    cannon_ang_world = {
        yaw = 0,
        pitch = 0,
        roll = 0,
    },
    cannon_ang_imu = {
        yaw = 0,     --south 0, west pi/2, north pi, east -pi/2
        pitch = 0,
        roll = 0,
    },
    rotate_matrix_cannon = {
        {0, 0, 0},
        {0, 0, 0},
        {0, 0, 0},
    },
    rotate_matrix_turrent = {
        {0, 0, 0},
        {0, 0, 0},
        {0, 0, 0},
    },
    forward_vector = {
        x = 0,
        y = 0,
        z = 0,
    },
    imu_pos = {
        x = 0,
        y = 0,
        z = 0,
    },
    imu_last_pos = {
        x = 0,
        y = 0,
        z = 0,
    },
    imu_spd = {
        x = 0,
        y = 0,
        z = 0,
    },
    imu_last_spd = {
        x = 0,
        y = 0,
        z = 0,
    },
    imu_accel = {
        x = 0,
        y = 0,
        z = 0,
    },
    imu_last_accel = {
        x = 0,
        y = 0,
        z = 0,
    },
    imu_acc_vec = {0,0,0},
    turrent_imu_pitch_ang = 0,
    chassis_imu_yaw_spd = 0,
    last_turrent_imu_pitch = 0,
    turent_imu_pitch_spd = 0,
}
local gimbal = {
    yaw_motor = {
        tar_ang = 0,
        cur_ang = 0,
        cur_spd = 0,
        tar_spd = 0,
        output_tor = 0,
        pos_pid = {
            kp = 6.0,
            ki = 0.0,
            kd = 0.0,
            integral = 0,
            last_error = 0,
            errall_max = 10000,
        },
        spd_pid = {
            kp = 600000.0,
            ki = 1000.0,
            kd = 0.0,
            integral = 0,
            last_error = 0,
            errall_max = 100000000,
        },
    },
    pitch_motor = {
        tar_ang = 0,
        cur_ang = 0,
        cur_spd = 0,
        tar_spd = 0,
        output_tor = 0,
        ang_max = math.rad(40),
        ang_min = math.rad(-10),
        pos_pid = {
            kp = 2.5,
            ki = 0.0,
            kd = 0.0,
            integral = 0,
            last_error = 0,
            errall_max = 10000,
        },
        spd_pid = {
            kp = 1800.0,
            ki = 0.0,
            kd = 0.0,
            integral = 0,
            last_error = 0,
            errall_max = 10000,
        },
    },
    m = 1,
    mode = 0,    --0:normal   1:stabilize
    fire_permit = 0
}
local target = {
    pos = {
        x = 0,
        y = 0,
        z = 0,
    },
    ang = {
        yaw = 0,
        pitch = 0,
        roll = 0,
    },
}


local position = {
    x = 0,
    y = 0,
    z = 0,
}

local quaternion = {
    w = 0,
    x = 0,
    y = 0,
    z = 0,
}

local euler_angle = {
    yaw = 0,     --正东pi,正南pi/2,正西0，正北-pi/2
    pitch = 0,   --抬头<0，低头>0
    roll = 0,    --右滚<0，左滚>0
}

function init()
    if pitch == nil then
        print("pitch not found")
        while true do end
        return
    end

    if imu == nil then
        print("IMU not found")
        while true do end
        return
    end

    if transmitter == nil then
        print("yaw not found")
        while true do end
        return
    end

    if modem == nil then
        print("Modem not found")
        while true do end
        return
    end

    transmitter.setProtocol(0)
    modem.open(4)     --chassis_gimbal_attitude topic
    modem.open(5)     --main control topic
    pitch.setIsAdjustingAngle(false)
    pitch.setPID(0,0,0)
    yaw.setIsAdjustingAngle(false)
    yaw.setPID(0,0,0)
    gimbal.pitch_motor.tar_ang = pitch.getAngle()
    gimbal.yaw_motor.tar_ang = yaw.getAngle()
    os.sleep(1)
    print("gimbal control computer init success")
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
    
    return roll, pitch,yaw
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


function norm(v)
    local l = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
    return { x = v.x/l, y = v.y/l, z = v.z/l }
end

function getForward(R)
    return { x = R[1][2], y = R[3][2], z = R[2][2] }
end

-- R_world: 由“相对于世界 xyz 的欧拉角”算出的旋转矩阵
function world_to_imu_pitch(R_world)
    local f = getForward(R_world)  -- 世界坐标下的前向
    f = norm(f)

    local horiz = math.sqrt(f.x * f.x + f.z * f.z)
    local pitch = math.atan2(f.y, horiz)   -- 弧度
    return pitch
end

function pitch_correction(pitch)
    return pi/2-pitch
end

function derivative_calc(val,last_val)
    return {
        x=(val.x-last_val.x)/time_piece,
        y=(val.y-last_val.y)/time_piece,
        z=(val.z-last_val.z)/time_piece
    }
end

function accel_calc()
    attitude.imu_last_spd = attitude.imu_spd
    attitude.imu_pos = imu.getPosition()
    attitude.imu_spd = imu.getSpinalyzerVelocity()
    attitude.imu_accel = derivative_calc(attitude.imu_spd,attitude.imu_last_spd)
    attitude.imu_acc_vec[1] = attitude.imu_accel.x    --left>0 and right<0
    attitude.imu_acc_vec[2] = attitude.imu_accel.y    --left>0 and right<0
    attitude.imu_acc_vec[3] = attitude.imu_accel.z    --forward>0  and backward<0
end

function attitude_calc_task()
    attitude.last_turrent_imu_pitch = attitude.turrent_imu_pitch_ang
    attitude.rotate_matrix_cannon = math.matrix_multiply(imu.getRotationMatrix(), pitch.getRelative())
    attitude.rotate_matrix_turrent = imu.getRotationMatrix()
    attitude.imu_pos = imu.getPosition()
    attitude.cannon_ang_world = mat_to_euler_yxz(attitude.rotate_matrix_cannon)
    attitude.cannon_ang_imu.yaw = attitude.cannon_ang_world.yaw
    attitude.cannon_ang_imu.pitch = world_to_imu_pitch(attitude.rotate_matrix_cannon)
    attitude.turrent_imu_pitch_ang = world_to_imu_pitch(attitude.rotate_matrix_turrent)
    attitude.turrent_imu_pitch_spd = (attitude.turrent_imu_pitch_ang - attitude.last_turrent_imu_pitch) / time_piece
    accel_calc()
    attitude.imu_acc_vec = math.mat3_mul_vec3(imu.getRotationMatrix(),attitude.imu_acc_vec)
    attitude.imu_accel.x = attitude.imu_acc_vec[1]    --left>0 and right<0
    attitude.imu_accel.y = attitude.imu_acc_vec[2]    --up>0 and down<0
    attitude.imu_accel.z = attitude.imu_acc_vec[3]   --forward>0  and backward<0
end

function pid_calc(target,current,pid_param)
    local error = target - current
    pid_param.integral = pid_param.integral + error
    local derivative = error - pid_param.last_error
    pid_param.last_error = error
    return pid_param.kp * error + pid_param.ki * pid_param.integral + pid_param.kd * derivative
end

function pitch_feed_forward()
    local y_accel_feed
    local z_accel_feed 
    if math.abs(attitude.imu_accel.y) > 0.5 then
        y_accel_feed = attitude.imu_accel.y * gimbal.m * math.cos(attitude.cannon_ang_imu.pitch)
    else 
        y_accel_feed = 0
    end

    if math.abs(attitude.imu_accel.z) > 0.5 then
        z_accel_feed = attitude.imu_accel.z * gimbal.m * math.sin(attitude.cannon_ang_imu.pitch)
    else
        z_accel_feed = 0
    end

    return y_accel_feed + z_accel_feed
end

function yaw_feed_forward()
end

--位置环pid+炮塔（底盘）pitch角速度pid+加速度前馈
function pitch_control()
    if gimbal.mode == 0 then   --normal mode
        gimbal.pitch_motor.cur_ang = pitch.getAngle()
        gimbal.pitch_motor.tar_ang = target.ang.pitch
        gimbal.pitch_motor.cur_spd = pitch.getAngularVelocity()
    elseif gimbal.mode == 1 then
        gimbal.pitch_motor.cur_ang = attitude.cannon_ang_imu.pitch
        gimbal.pitch_motor.tar_ang = target.ang.pitch
        gimbal.pitch_motor.cur_spd = pitch.getAngularVelocity()+attitude.turrent_imu_pitch_spd
    end

    gimbal.pitch_motor.tar_spd = pid_calc(gimbal.pitch_motor.tar_ang, gimbal.pitch_motor.cur_ang, gimbal.pitch_motor.pos_pid)
    local pid_output = pid_calc(gimbal.pitch_motor.tar_spd,gimbal.pitch_motor.cur_spd, gimbal.pitch_motor.spd_pid)
    local feed_forward = pitch_feed_forward()
    --pitch.setOutputTorque(-pid_output-feed_forward)
    pitch.setOutputTorque(0)
end

--位置环pid+底盘yaw角速度前馈
function yaw_control()
    if gimbal.mode == 0 then   --normal mode
        gimbal.yaw_motor.cur_ang = -yaw.getAngle()
        gimbal.yaw_motor.tar_ang = -target.ang.yaw
        gimbal.yaw_motor.cur_spd = -yaw.getAngularVelocity()
    elseif gimbal.mode == 1 then
        gimbal.yaw_motor.cur_ang = attitude.cannon_ang_imu.yaw
        gimbal.yaw_motor.tar_ang = target.ang.yaw
        gimbal.yaw_motor.cur_spd = -yaw.getAngularVelocity()-attitude.chassis_imu_yaw_spd*0.5
    end

    if gimbal.yaw_motor.tar_ang-gimbal.yaw_motor.cur_ang > pi then   -- 选择劣弧（最短）路径
        gimbal.yaw_motor.cur_ang = gimbal.yaw_motor.cur_ang + 2*pi
    elseif gimbal.yaw_motor.tar_ang-gimbal.yaw_motor.cur_ang < -pi then
        gimbal.yaw_motor.cur_ang = gimbal.yaw_motor.cur_ang - 2*pi
    end

    gimbal.yaw_motor.tar_spd = pid_calc(gimbal.yaw_motor.tar_ang, gimbal.yaw_motor.cur_ang, gimbal.yaw_motor.pos_pid)
    gimbal.yaw_motor.tar_spd = math.clamp(gimbal.yaw_motor.tar_spd,-pi,pi)
    local pid_output = pid_calc(gimbal.yaw_motor.tar_spd,gimbal.yaw_motor.cur_spd,gimbal.yaw_motor.spd_pid)
    --yaw.setOutputTorque(pid_output)
    yaw.setOutputTorque(0)
end

function gimbal_control_task()
    target.ang.yaw = math.rad(90)
    target.ang.pitch = math.rad(0)
    pitch_control()
    yaw_control()
end

function message_receive_task()
    local event, modemSide, senderChannel, 
    replyChannel, message, senderDistance = os.pullEvent("modem_message")
    if senderChannel == 4 and message ~= nil then
        msg.mode,msg.yaw_ang,msg.pitch_ang,msg.fire_permit,msg.chassis_yaw_spd = message:match("(-?%d+%.?%d*) (-?%d+%.?%d*) (-?%d+%.?%d*) (-?%d+%.?%d*) (-?%d+%.?%d*)")
        attitude.chassis_imu_yaw_spd = tonumber(msg.chassis_yaw_spd)
        gimbal.yaw_motor.tar_ang = tonumber(msg.yaw_ang)
        gimbal.pitch_motor.tar_ang = tonumber(msg.pitch_ang)
        gimbal.fire_permit = tonumber(msg.pitch_ang)
        print(msg.yaw_ang)
    else 
        attitude.chassis_imu_yaw_spd  = 0;
    end
end

init()
while true do
    parallel.waitForAll(attitude_calc_task,gimbal_control_task,message_receive_task)
    os.sleep(time_piece)
end
