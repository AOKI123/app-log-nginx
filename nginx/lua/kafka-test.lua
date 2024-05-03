-- curl 'http://localhost/test?data=tb7rZx%2bGdMFVWeorhox1Eg%3d%3d'
local cjson = require "cjson"
local kafka_producer = require "resty.kafka.producer"
local KAFKA_BROKERS = ${KAFKA_BROKERS}
local KAFKA_TOPIC = "${KAFKA_TOPIC}"
local KAFKA_PRODUCER_CONF = ${KAFKA_PRODUCER_CONF}

local p = kafka_producer:new(KAFKA_BROKERS, KAFKA_PRODUCER_CONF)

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
            pk = string.sub(pk, 1, 2)
        end
        rt[pk]=pv;
    end
    rt['ip'] = header_data["X-REAL-IP"] or header_data["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"
    rt['start_time'] = ngx.req.start_time() * 1000
    rt['server_time'] = ngx.now() * 1000
    return rt
end

local headers_data = parse_headers(ngx.req.get_headers())
local parsed_lines = {"test"}
for _i = 1, #parsed_lines do
    local ll = {c = parsed_lines[_i], f = 1, t = headers_data['server_time'], l = headers_data['server_time'], n = 'main', i = 1, m = true, h = headers_data}
    local ok, err = p:send(KAFKA_TOPIC, nil, cjson.encode(ll))
    if not ok then
        ngx.log(ngx.ERR,"send kafka err:", err .. ", data:" .. ll)
        return
    end
end