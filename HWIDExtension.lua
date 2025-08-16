local hs = game:GetService("HttpService")

local function http()
	return (syn and syn.request) or request or http_request
end

local function get()
	local req = http()
	if not req then return "" end
	local ok, res = pcall(function()
		return req({ Url = "https://httpbin.org/get"; Method = "GET"; })
	end)
	if not ok or not res or not res.Body then return "" end
	local ok2, dec = pcall(hs.JSONDecode, hs, res.Body)
	if not ok2 or type(dec) ~= "table" or type(dec.headers) ~= "table" then return "" end
	local hw = ""
	for k,v in pairs(dec.headers) do
		local n = tostring(k):lower()
		if n:find("fingerprint") or n:find("hwid") then hw = tostring(v or ""); break end
	end
	return hw
end

local function parse_list(s)
	if type(s) ~= "string" or #s == 0 then return {} end
	if s:sub(1,1) == "[" then
		local ok, arr = pcall(hs.JSONDecode, hs, s)
		if ok and type(arr) == "table" then
			local m = {}
			for _,x in ipairs(arr) do if type(x) == "string" and x ~= "" then m[x] = true end end
			return m
		end
	end
	local m = {}
	for line in s:gmatch("([^\r\n]+)") do
		local t = line:gsub("^%s+",""):gsub("%s+$","")
		if t ~= "" and not t:match("^#") then m[t] = true end
	end
	return m
end

local function fetch(url)
	local ok, body = pcall(game.HttpGet, game, url)
	if ok and type(body) == "string" and #body > 0 then return body end
	local r = http()
	if not r then return "" end
	local ok2, res = pcall(function()
		return r({ Url = url; Method = "GET"; })
	end)
	return (ok2 and res and res.Body) and res.Body or ""
end

local function enforce(opt)
	opt = opt or {}
	local url = opt.url or "https://raw.githubusercontent.com/clippyarchives/Obsidian/feature/ide-extension/hwids.txt"
	local dm = opt.dm or "xenon9012"
	local hw = get()
	local raw = fetch(url)
	local wl = parse_list(raw)
	local cnt = 0; for _ in pairs(wl) do cnt = cnt + 1 end
	local ok = (cnt == 0) or (wl[hw] == true)
	if not ok then
		local nl = loadstring(game:HttpGet('https://raw.githubusercontent.com/IceMinisterq/Notification-Library/Main/Library.lua'))()
		nl:SendNotification('Info', 'HWID Not registered, please dm '..dm, 6)
	end
	return ok, hw
end

return { get = get, enforce = enforce }