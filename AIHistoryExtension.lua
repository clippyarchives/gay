local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local hs = game:GetService("HttpService")

local function ensure_mem()
	if type(getgenv().obs_mem) ~= "table" then
		getgenv().obs_mem = { enabled = true; max_turns = 10; chat = {}; }
	else
		if getgenv().obs_mem.enabled == nil then getgenv().obs_mem.enabled = true end
		getgenv().obs_mem.max_turns = tonumber(getgenv().obs_mem.max_turns) or 10
		getgenv().obs_mem.chat = getgenv().obs_mem.chat or {}
	end
	return getgenv().obs_mem
end

local dir = "obsidian/chat_histories"

local function fs_ok()
	return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(makefolder) == "function" and typeof(listfiles) == "function" and typeof(isfolder) == "function" and typeof(delfile) == "function"
end

local function ensure_dir()
	if not fs_ok() then return false end
	if not isfolder(dir) then pcall(makefolder, dir) end
	return isfolder(dir)
end

local function sanitize_name(s)
	s = tostring(s or "session")
	s = s:gsub("[^%w%-%._]+","_")
	if #s == 0 then s = "session" end
	return s
end

local function save_history(name)
	local mem = ensure_mem()
	if not ensure_dir() then lib:Notify("fs unsupported", 2); return end
	local ts = tostring(os.time())
	local fn = dir.."/"..ts.."_"..sanitize_name(name)..".json"
	local data = { chat = mem.chat; max_turns = mem.max_turns; enabled = mem.enabled }
	local ok, enc = pcall(hs.JSONEncode, hs, data)
	if not ok then lib:Notify("json err",2) return end
	writefile(fn, enc)
	lib:Notify("saved",2)
end

local function list_histories()
	if not ensure_dir() then return {} end
	local files = {}
	for _,p in ipairs(listfiles(dir) or {}) do
		if p:lower():sub(-5) == ".json" then table.insert(files, p) end
	end
	table.sort(files, function(a,b) return a > b end)
	return files
end

local function load_history_file(path)
	if not fs_ok() then return nil end
	local ok, raw = pcall(readfile, path)
	if not ok then return nil end
	local ok2, data = pcall(hs.JSONDecode, hs, raw)
	if not ok2 then return nil end
	if type(data) == "table" and type(data.chat) == "table" then return data end
	if type(data) == "table" then return { chat = data } end
	return nil
end

local function join_chat(tbl)
	local lines = {}
	for _,m in ipairs(tbl or {}) do
		table.insert(lines, (m.role or "user")..": "..tostring(m.content or ""))
	end
	return table.concat(lines, "\n")
end

local function to_labels(paths)
	local out = {}
	for _,p in ipairs(paths) do
		local name = p:match("([^/\\]+)$.json$") or p:match("([^/\\]+)$") or p
		table.insert(out, name)
	end
	return out
end

local function attach(win)
	ensure_mem()
	local tab = win:AddTab("AI History", "save")

	local left = tab:AddLeftGroupbox("manage")
	local right = tab:AddRightGroupbox("preview")

	local name_inp = left:AddInput("hist_name", { Text = "session name"; Default = "session"; Finished = true; ClearTextOnFocus = false; Callback = function() end })
	left:AddButton({ Text = "save current history"; Func = function()
		local n = name_inp and name_inp.Value or "session"
		save_history(n)
		if refresh then task.delay(0.1, refresh) end
	end })

	local files = {}
	local labels = {}
	local chosen

	local dropdown = left:AddDropdown("hist_list", { Text = "saved histories"; Values = {}; AllowNull = true; Callback = function(v)
		chosen = v
		if v and v ~= "" then
			for i,lab in ipairs(labels) do if lab == v then chosen = files[i] break end end
			if chosen then
				local data = load_history_file(chosen)
				local text = data and join_chat(data.chat) or "(failed to read)"
				if #text == 0 then text = "(empty)" end
				prev_box:SetText(text)
			end
		else
			prev_box:SetText("")
		end
	end })

	local prev_box = right:AddLabel({ Text = ""; DoesWrap = true })

	local function repop()
		files = list_histories()
		labels = {}
		for _,p in ipairs(files) do
			local name = p:match("([^/\\]+)$") or p
			table.insert(labels, name)
		end
		dropdown:SetValues(labels)
		if #labels > 0 then dropdown:SetValue(labels[1]) else dropdown:SetValue(nil) prev_box:SetText("no histories") end
	end

	left:AddButton({ Text = "refresh list"; Func = repop })

	left:AddButton({ Text = "use selected (add to memory)"; Func = function()
		if not chosen then return end
		local data = load_history_file(chosen)
		if not data then return end
		local mem = ensure_mem()
		for _,m in ipairs(data.chat) do table.insert(mem.chat, m) end
		while #mem.chat > (tonumber(mem.max_turns) or 10)*2 do table.remove(mem.chat,1) end
		if type(getgenv().obs_mem_refresh) == "function" then pcall(getgenv().obs_mem_refresh) end
		lib:Notify("added to memory",2)
	end })

	left:AddButton({ Text = "load selected (replace memory)"; Func = function()
		if not chosen then return end
		local data = load_history_file(chosen)
		if not data then return end
		local mem = ensure_mem()
		mem.chat = data.chat
		while #mem.chat > (tonumber(mem.max_turns) or 10)*2 do table.remove(mem.chat,1) end
		if type(getgenv().obs_mem_refresh) == "function" then pcall(getgenv().obs_mem_refresh) end
		lib:Notify("replaced memory",2)
	end })

	left:AddButton({ Text = "delete selected"; Func = function()
		if not chosen or not fs_ok() then return end
		pcall(delfile, chosen)
		repop()
	end })

	repop()

	return { tab = tab }
end

print("ai_history_ext v2")
return { attach = attach }