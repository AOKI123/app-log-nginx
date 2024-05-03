-- curl 'http://localhost/test?data=tb7rZx%2bGdMFVWeorhox1Eg%3d%3d'
local cjson = require "cjson"
local AES_KEY = "${AES_KEY}"
local AES_IV = "${AES_IV}"

local headers = ngx.req.get_headers()

for k,v in pairs(headers) do
    local pv = v;
    local pk = string.gsub(k, "-", "_")
    if type(v) == "table" then
        pv = cjson.encode(v)
    end
    local prefix = string.gsub(pk, 1, 2)
    if prefix == 'x_' then
        pk = string.gsub(pk, 1, 2)
    end
    ngx.say(pk, " : ", pv, "\r\n")
end

ngx.say("start_time : " .. ngx.req.start_time() .. "\r\n")
ngx.say("server_time : " .. ngx.now() .. "\r\n")

local args = ngx.req.get_uri_args()
if args == nil then
    ngx.req.read_body()
    args = ngx.req.get_post_args()
end
if args and args.data then
    ngx.say("rec:" .. args.data)
    local res = ngx.decode_base64(args.data)
    if res ~= nil then
        local aes = require "resty.aes_pad"
        local aes_func = aes:new(AES_KEY, nil, aes.cipher(128, "cbc"), { iv = AES_IV })
        aes_func:set_padding(0)
        ngx.say(aes_func:decrypt(res))
    end
else
    ngx.say("no data")
end