-----------remote weapon station control computer-------

local pitch = peripheral.find("servo")
local imu = peripheral.find("spinalyzer")
local transmitter = peripheral.find("transmitter")
local modem = peripheral.find("modem")

local yaw = {}
local pi = math.pi
local time_piece = 0.05

local receive_msg = {
    yaw_ang ="",
    pitch_ang = "",
    gimbal_mode = "",
    control_mode = "",
    fire_permit = "",
    chassis_yaw_spd = "",
}

local xyz={}
local angle = {}

function xyz:new(x,y,z)
    local obj = {x = x, y = y, z = z}
    setmetatable(obj, xyz)
    return obj
end

function angle:new(yaw, pitch, roll)
    local obj = {yaw = yaw, pitch = pitch, roll = roll}
    setmetatable(obj, angle)
    return obj
end

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

function math.sec(x)
    return 1/math.cos(x)
end

function math.distance_2d_calc(x1, z1, x2, z2)
    return math.sqrt((x2 - x1)^2 + (z2 - z1)^2)
end

function math.distance_3d_calc(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
end

function math.atan_in_circle(x,z)
    if z>0 then
        return math.atan(x/z)
    elseif x<0 and z<0 then
        return -math.pi/2+math.atan(-z/x)
    elseif x>0 and z<0 then
        return math.pi/2+math.atan(-z/x)
    elseif z==0 and x>0 then
        return math.pi/2
    elseif z==0 and x<0 then
        return -math.pi/2
    else
        return 0
    end
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

function math.nil_to_zero(value)
    if value == nil then
        return 0
    end
    return value
end

function math.nil_to_last(value,last_value)
    if value == nil then
        return last_value
        end
        return value
end

function math.nan_check(value, default)
    if value ~= value then  -- NaN is the only value that is not equal to itself
        return default
    end
    return value
end

function math.xyz_to_array(xyz)
    local arr = {}
    arr[1] = xyz.x
    arr[2] = xyz.y
    arr[3] = xyz.z
    return arr
end

function arr_to_xyz(arr)
    return xyz:new(arr[1],arr[2],arr[3])
end

local attitude= {
    cannon_ang_world = angle:new(0,0,0),
    cannon_ang_imu = angle:new(0,0,0),
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
    forward_vector = xyz:new(0,0,0),
    imu_pos = xyz:new(0,0,0),
    imu_spd = xyz:new(0,0,0),
    imu_last_spd = xyz:new(0,0,0),
    imu_accel = xyz:new(0,0,0),
    imu_last_accel = xyz:new(0,0,0),
    imu_acc_vec = {0,0,0},
    turrent_imu_pitch_ang = 0,
    chassis_imu_yaw_spd = 0,
    chassis_imu_last_yaw_spd = 0,
    last_turrent_imu_pitch = 0,
    turent_imu_pitch_spd = 0,
}

local gimbal = {
    yaw_motor = {
        tar_ang = 0,
        cur_ang = 0,
        tar_last_ang = 0,
        cur_spd = 0,
        tar_spd = 0,
        output_tor = 0,
        pos_pid = {
            kp = 5.0,
            ki = 0.0,
            kd = 0.0,
            integral = 0,
            last_error = 0,
            errall_max = 10000,
        },
        spd_pid = {
            kp = 8000.0,
            ki = 0.0,
            kd = 0.0,
            integral = 0,
            last_error = 0,
            errall_max = 100000000,
        },
    },
    pitch_motor = {
        tar_ang = 0,
        tar_last_ang = 0,
        cur_ang = 0,
        cur_spd = 0,
        tar_spd = 0,
        output_tor = 0,
        ang_max = math.rad(70),
        ang_min = math.rad(-15),
        pos_pid = {
            kp = 5.0,
            ki = 0.0,
            kd = 0.0,
            integral = 0,
            last_error = 0,
            errall_max = 10000,
        },
        spd_pid = {
            kp = 500.0,
            ki = 0.0,
            kd = 0.0,
            integral = 0,
            last_error = 0,
            errall_max = 10000,
        },
    },
    m = 1,
    gimbal_mode = 0,    --0:normal   1:stabilize
    control_mode = 0,    --0:manual   1:sentry
    last_mode = 0,
    fire_permit = 0
}

local cannon = {
    length = 16,
    d = 0.01,   --阻力
    g = 0.05,  --重力
    velocity = 160,
    pos = xyz:new(0,0,0),
    gimbal_offset = xyz:new(4,1,2),
}

local target = {
    pos = xyz:new(530,0,50),
    distance_3d = 0,
    distance_2d = 0,
    flying_time = 0,
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

    transmitter.setProtocol(1)
    modem.open(5)     --rws main control topic
    modem.open(6)   --online check topic
    pitch.setIsAdjustingAngle(false)
    pitch.setPID(0,0,0)
    yaw.setIsAdjustingAngle(false)
    yaw.setPID(0,0,0)
    gimbal.pitch_motor.tar_ang = pitch.getAngle()
    gimbal.yaw_motor.tar_ang = yaw.getAngle()
    os.sleep(1)
    print("rws control computer init success")
    modem.transmit(6, 6, "rws_ok")
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
    attitude.imu_pos = imu.getSpinalyzerPosition()
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

function cannon_pos_calc()
    local rel_pos =  arr_to_xyz(math.mat3_mul_vec3(attitude.rotate_matrix_cannon,math.xyz_to_array(cannon.gimbal_offset)))
    cannon.pos.x = attitude.imu_pos.x + rel_pos.z
    cannon.pos.y = attitude.imu_pos.y + rel_pos.x
    cannon.pos.z = attitude.imu_pos.z - rel_pos.y
    --print(string.format("%.2f,%.2f,%.2f", cannon.pos.x, cannon.pos.y, cannon.pos.z))

end

function fx(p1,p2,p3,p4,p5,a,x) 
    return p1*math.sec(x)+p2*math.tan(x)+a*math.log(p3-p4*math.sec(x))+p5
end

function Fx(p1,p2,p3,p4,p5,p6,x) 
    return p1*math.sec(x)+p2*math.tan(x)+p3*math.log(p4-p5*math.sec(x))-p6 
end

function fx_derivative(p1,p2,p3,p4,a,x)
    return math.sec(x)*(math.tan(x)*(p1-a*p4/(p3-p4*math.sec(x)))+p2*math.sec(x))
end

function Fx_derivative(p1,p2,p3,p4,p5,x)
    return math.sec(x)*(math.tan(x)*p1+math.sec(x)*p2-p3*p5*math.tan(x)/(p4-p5*math.sec(x)))
end

function Newton_Raphson(p1,p2,p3,p4,p5,p6,x0,n)
    local x = x0
    for i=1,n do
        local f = Fx(p1,p2,p3,p4,p5,p6,x)
        local f_derivative = Fx_derivative(p1,p2,p3,p4,p5,x)
        if f_derivative == 0 then
            break
        end
        local x_new = x - f / f_derivative
        x = math.nan_check(x,100)
        if math.abs(x_new - x) < 1e-6 then
            return x_new
        end
        x = x_new
    end
    x = math.nan_check(x,100)
    return x
end

function track_calc(parameter,can_pos,tar_pos)   --弹道计算
    local v = parameter.velocity/20
    local d = parameter.d
    local g = parameter.g
    local l = 0

    local w = math.distance_2d_calc(can_pos.x, can_pos.z, tar_pos.x, tar_pos.z)
    local h = tar_pos.y - can_pos.y
    local a1 = g*w/d/v
    local a2 = w
    local a3 = g/d/d
    local a4 = 1+d*l/v
    local a5 = d*w/v
    local a6 = g*l/d/v+h

    local pitch1=Newton_Raphson(a1,a2,a3,a4,a5,a6,0,10)
    local pitch2=Newton_Raphson(a1,a2,a3,a4,a5,a6,1.5,10)

    gimbal.yaw_motor.tar_ang = math.atan_in_circle(tar_pos.x - can_pos.x, tar_pos.z - can_pos.z)
    gimbal.pitch_motor.tar_ang = math.min(pitch1, pitch2)
    cannon.distance_3d = math.distance_3d_calc(can_pos.x, can_pos.y, can_pos.z, tar_pos.x, tar_pos.y, tar_pos.z)
    cannon.distance_2d = w
    cannon.flying_time = flying_time_calc(math.min(pitch1, pitch2), w,parameter)
    --print(string.format("yaw: %.2f, pitch1: %.2f, distance_3d: %.2f, distance_2d: %.2f, flying_time: %.2f", gimbal.yaw_motor.tar_ang, rad_to_deg(pitch1), cannon.distance_3d, cannon.distance_2d, cannon.flying_time))
end

function flying_time_calc(pitch,distance,parameter)
    local d,l = 0.01,13
    local v = parameter.velocity/20
    local d = parameter.d
    locall = parameter.l

    local result = -math.log(1-(distance-l*math.cos(pitch))*d/v/math.cos(pitch))/d
    return result
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
    gimbal.pitch_motor.tar_ang = math.rad(0)
    if gimbal.gimbal_mode == 0 then   --normal mode
        gimbal.pitch_motor.cur_ang = pitch.getAngle()
        gimbal.pitch_motor.cur_spd = pitch.getAngularVelocity()
    elseif gimbal.gimbal_mode == 1 then
        gimbal.pitch_motor.cur_ang = attitude.cannon_ang_imu.pitch
        gimbal.pitch_motor.cur_spd = pitch.getAngularVelocity()+attitude.turrent_imu_pitch_spd
    end

    --print(string.format("cur_ang: %.2f, cur_spd: %.2f", rad_to_deg(gimbal.pitch_motor.cur_ang), rad_to_deg(gimbal.pitch_motor.cur_spd)))

    gimbal.pitch_motor.tar_ang = math.clamp(gimbal.pitch_motor.tar_ang, gimbal.pitch_motor.ang_min, gimbal.pitch_motor.ang_max)

    -- 选择劣弧（最短）路径

    gimbal.pitch_motor.tar_spd = pid_calc(gimbal.pitch_motor.tar_ang, -gimbal.pitch_motor.cur_ang, gimbal.pitch_motor.pos_pid)
    gimbal.pitch_motor.tar_spd = math.clamp(gimbal.pitch_motor.tar_spd,-pi,pi)
    local pid_output = pid_calc(-gimbal.pitch_motor.tar_spd,gimbal.pitch_motor.cur_spd, gimbal.pitch_motor.spd_pid)
    local feed_forward = pitch_feed_forward()
    --pid_output = 0
    --feed_forward = 0
    --print(string.format("tar_ang:%.2f,cur_ang:%.2f", rad_to_deg(gimbal.pitch_motor.tar_ang), rad_to_deg(gimbal.pitch_motor.cur_ang)))
    pitch.setOutputTorque(-pid_output-feed_forward)
end

--位置环pid+底盘yaw角速度前馈
function yaw_control()
    gimbal.yaw_motor.tar_ang = 0
    if gimbal.gimbal_mode == 0 then   --normal mode
        gimbal.yaw_motor.cur_ang = -yaw.getAngle()
        --gimbal.yaw_motor.tar_ang = -target.ang.yaw
        gimbal.yaw_motor.cur_spd = -yaw.getAngularVelocity()
    elseif gimbal.gimbal_mode == 1 then
        gimbal.yaw_motor.cur_ang = attitude.cannon_ang_imu.yaw
        --gimbal.yaw_motor.tar_ang = target.ang.yaw
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
    --print(string.format("tar_ang:%.2f,cur_ang:%.2f,tar_spd:%.2f,cur_spd:%.2f,pid_output:%.2f", rad_to_deg(gimbal.yaw_motor.tar_ang), rad_to_deg(gimbal.yaw_motor.cur_ang), rad_to_deg(gimbal.yaw_motor.tar_spd), rad_to_deg(gimbal.yaw_motor.cur_spd), pid_output))
    --pid_output = 0
    yaw.setOutputTorque(pid_output)
end

function fire()
    redstone.setOutput("back", true)
end

function sease_fire()
    redstone.setOutput("back", false)
end

function cannon_control_task()
    if gimbal.fire_permit == 1 then
        fire()
        gimbal.fire_permit = 0
    else
        sease_fire()
    end
end

function gimbal_control_task()
    if gimbal.mode == 1 then
        track_calc(cannon, cannon.pos, target.pos)
    end
    pitch_control()
    yaw_control()
    cannon_pos_calc()
end

function message_receive_task()
    local event, modemSide, senderChannel, 
    replyChannel, message, senderDistance = os.pullEvent("modem_message")
    if senderChannel == 4 and message ~= nil then
        gimbal.yaw_motor.tar_last_ang = gimbal.yaw_motor.tar_ang
        gimbal.pitch_motor.tar_last_ang = gimbal.pitch_motor.tar_ang
        attitude.chassis_imu_last_yaw_spd = attitude.chassis_imu_yaw_spd

        receive_msg.gimbal_mode, receive_msg.control_mode, receive_msg.fire_permit, receive_msg.chassis_yaw_spd, receive_msg.yaw_ang, receive_msg.pitch_ang = string.match(message, "(%d),(%d),(%d),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
        attitude.chassis_imu_yaw_spd = math.nil_to_zero(tonumber(receive_msg.chassis_yaw_spd))
        if math.abs(attitude.chassis_imu_last_yaw_spd-attitude.chassis_imu_yaw_spd) > 1 then
            attitude.chassis_imu_yaw_spd = attitude.chassis_imu_last_yaw_spd    
        end
        gimbal.yaw_motor.tar_ang = math.nil_to_last(tonumber(receive_msg.yaw_ang), gimbal.yaw_motor.tar_last_ang)
        gimbal.pitch_motor.tar_ang = math.nil_to_last(tonumber(receive_msg.pitch_ang), gimbal.pitch_motor.tar_last_ang)
        gimbal.fire_permit = math.nil_to_zero(tonumber(receive_msg.fire_permit))
        gimbal.gimbal_mode = math.nil_to_zero(tonumber(receive_msg.gimbal_mode))
        gimbal.control_mode = math.nil_to_zero(tonumber(receive_msg.control_mode))
    
        --print(message)
    else 
        attitude.chassis_imu_yaw_spd  = 0;
    end
end

function print_debug_task()
    print(string.format("%.2f,%.2f,%.2f", cannon.pos.x, cannon.pos.y, cannon.pos.z))
    --print(string.format("%.2f,%.2f,%.2f", attitude.imu_pos.x, attitude.imu_pos.y, attitude.imu_pos.z))
    --print(string.format(" %.2f,%.2f,%.2f,%.2f", gimbal.yaw_motor.tar_ang, gimbal.pitch_motor.tar_ang,pitch.getAngle(), yaw.getAngle()))
end

init()
while true do
    parallel.waitForAll(attitude_calc_task,gimbal_control_task,cannon_control_task,message_receive_task,print_debug_task)
    os.sleep(time_piece)
end
