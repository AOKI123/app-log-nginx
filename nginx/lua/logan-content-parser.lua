local aes = require "resty.aes_pad"
local zlib = require "zlib"
local cjson = require "cjson"
local kafka_producer = require "resty.kafka.producer"

local AES_KEY = "${AES_KEY}"
local AES_IV = "${AES_IV}"
local KAFKA_BROKERS = ${KAFKA_BROKERS}
local KAFKA_TOPIC = "${KAFKA_TOPIC}"
local KAFKA_PRODUCER_CONF = ${KAFKA_PRODUCER_CONF}

local function leftShift(num, shift)
    return math.floor(num * (2 ^ shift))
end

local function byte2int(num1, num2, num3, num4)
    local num = 0
    num = num + leftShift(num1, 24)
    num = num + leftShift(num2, 16)
    num = num + leftShift(num3, 8)
    num = num + num4
    return num
end

local function decrypt(data)
    local aes_func = aes:new(AES_KEY, nil, aes.cipher(128, "cbc"), { iv = AES_IV })
    aes_func:set_padding(0)
    return aes_func:decrypt(data)
end

local function gunzip(data)
    local stream = zlib.inflate()
    local callStatus, body = pcall(stream, data)
    if callStatus then
        return body
    else
        return nil
    end
end

local function parse_headers(header_data)
    local rt = {}
    for k, v in pairs(header_data) do
        local pv = v;
        local pk = string.gsub(k, "-", "_")
        if type(v) == "table" then
            pv = cjson.encode(v)
        end
        local prefix = string.sub(pk, 1, 2)
        if prefix == 'x_' then
            pk = string.sub(pk, 3)
        end
        rt[pk]=pv;
    end
    rt['ip'] = header_data["X-REAL-IP"] or header_data["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"
    rt['start_time'] = ngx.req.start_time() * 1000
    rt['server_time'] = ngx.now() * 1000
    return rt
end

local function parse_lines(logan_data)
    local rt = {}
    if logan_data == nil then
        return rt
    end
    -- 日志总长度
    local t_len = #logan_data
    for i = 1, t_len do
        local start = string.byte(logan_data, i)
        while true do
            if start == 1 then
                -- 单条加密压缩的总长度
                local s_len = byte2int(string.byte(logan_data, i + 1), string.byte(logan_data, i + 2), string.byte(logan_data, i + 3), string.byte(logan_data, i + 4))
                i = i + 4
                if s_len <= 0 then
                    break
                end
                local l_type = 0
                local s_end_index = i + s_len + 1;
                if t_len - i - 1 == s_len then
                    -- 异常
                    l_type = 0
                elseif t_len - i - 1 > s_len and 0 == string.byte(logan_data, s_end_index) then
                    -- 正常
                    l_type = 1
                elseif t_len - i - 1 > s_len and 1 == string.byte(logan_data, s_end_index) then
                    -- 异常
                    l_type = 2
                else
                    i = i - 4
                    break
                end
                local sub_data = string.sub(logan_data, i, i + s_len)
                sub_data = decrypt(sub_data)
                sub_data = gunzip(sub_data)
                i = i + s_len
                if l_type == 1 then
                    i = i + 1
                end
                if sub_data ~= nil then
                    table.insert(rt, sub_data)
                end
                break
            end
        end
    end
    return rt
end

local headers_data = parse_headers(ngx.req.get_headers())
local parsed_lines = parse_lines(ngx.req.get_body_data())

if nil == parsed_lines or 0 == #parsed_lines then
    return
end

local headers_str = cjson.encode(headers_data)
local p = kafka_producer:new(KAFKA_BROKERS, KAFKA_PRODUCER_CONF)
for _i = 1, #parsed_lines do
    local message = '{"h":' ..  headers_str .. ',"t":' .. headers_data['server_time'] .. ',' .. string.sub(parsed_lines[_i], 1)
    local ok, err = p:send(KAFKA_TOPIC, nil, message)
    if not ok then
        ngx.log(ngx.ERR, "send kafka err:", err .. ", data:" .. message)
    end
end