local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local hs = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local synx
pcall(function()
	synx = loadstring(game:HttpGet("https://raw.githubusercontent.com/clippyarchives/Obsidian/feature/ide-extension/IDESyntaxExtension.lua"))()
end)

local function color_to_hex(c)
	local r = math.clamp(math.floor((c.R or 0)*255+0.5),0,255)
	local g = math.clamp(math.floor((c.G or 0)*255+0.5),0,255)
	local b = math.clamp(math.floor((c.B or 0)*255+0.5),0,255)
	return string.format("#%02x%02x%02x", r, g, b)
end

local ACCENT_HEX = color_to_hex(lib.Scheme.AccentColor or Color3.fromRGB(157,125,255))

local function escape_rich_text(s)
	s = tostring(s or "")
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function chunk_text(s, lim)
	lim = lim or 20000
	if #s <= lim then return { s } end
	local out = {}
	local acc = ""
	for line in (s.."\n"):gmatch("([^\n]*)\n") do
		if #acc + #line + 1 > lim and acc ~= "" then
			table.insert(out, acc)
			acc = line
		else
			if acc == "" then acc = line else acc = acc .. "\n" .. line end
		end
	end
	if acc ~= "" then table.insert(out, acc) end
	return out
end

local function get_style()
	local s = getgenv().obs_chat_style or {}
	s.ai_color = s.ai_color or Color3.fromRGB(180,220,255)
	s.user_color = s.user_color or Color3.fromRGB(220,220,220)
	if s.use_model_prefix == nil then s.use_model_prefix = true end
	s.ai_label = s.ai_label or "AI"
	getgenv().obs_chat_style = s
	return s
end

local function add_lbl(parent, txt, color)
	local baseCol = color or lib.Scheme.FontColor
	local safe = escape_rich_text(txt)
	local chunks = chunk_text(safe, 20000)
	local first
	for i=1,#chunks do
		local l = Instance.new("TextLabel")
		l.BackgroundColor3 = lib.Scheme.BackgroundColor
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.TextWrapped = true
		l.FontFace = lib.Scheme.Font
		l.TextSize = 14
		l.TextColor3 = baseCol
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.new(1,-12,0,0)
		l.Text = chunks[i]
		l.RichText = true
		l.Parent = parent
		if not first then first = l end
	end
	return first
end

local function add_line_with_prefix(parent, prefix_kind, body, model)
	local s = get_style()
	local baseCol = lib.Scheme.FontColor
	local pfx, pfxCol
	if prefix_kind == "ai" then
		pfx = s.use_model_prefix and (tostring(model or "AI") .. " > ") or (tostring(s.ai_label) .. " > ")
		pfxCol = s.ai_color or baseCol
	else
		local dn = "user"
		local lp = Players.LocalPlayer
		if lp and lp.DisplayName and lp.DisplayName ~= "" then dn = lp.DisplayName end
		pfx = "["..dn.."] > "
		pfxCol = s.user_color or baseCol
	end
	local txt = string.format("<font color=\"%s\">%s</font>%s", color_to_hex(pfxCol), pfx, escape_rich_text(body))
	return add_lbl(parent, txt, baseCol)
end

local function add_code_block(gui, code)
	local t = code:gsub("\r","")
	local first = t:match("^%s*([%w%-_]*)\n")
	if first and (#first<=5) and (first:lower()=="lua" or first:lower()=="luau") then
		t = t:gsub("^%s*[%w%-_]*\n", "", 1)
	end
	if synx and synx.syn and synx.syn.hl then
		local ok, res = pcall(function()
			return synx.syn.hl(t)
		end)
		if ok and type(res) == "string" then
			gui.Text = res
			gui.RichText = true
		else
			gui.Text = t
			gui.RichText = false
		end
	else
		gui.Text = t
		gui.RichText = false
	end
	return t
end

local function instance_path(inst)
	local segs = {}
	local cur = inst
	while cur and cur ~= game do
		table.insert(segs, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(segs, ".")
end

local function snapshot_instance(inst, depth, lines, depthLimit, maxLines, classList, nameList, path)
	if #lines >= maxLines then return end

	local classOk = true
	if classList and #classList > 0 then
		classOk = false
		for _,cls in ipairs(classList) do
			if inst:IsA(cls) or inst.ClassName == cls then classOk = true break end
		end
	end

	local nameOk = true
	if nameList and #nameList > 0 then
		nameOk = false
		local lower = tostring(inst.Name):lower()
		for _,frag in ipairs(nameList) do
			if lower:find(frag, 1, true) then nameOk = true break end
		end
	end

	if classOk and nameOk then
		local line = (path or inst.Name).." ("..inst.ClassName..")"
		if inst:IsA("BasePart") then
			local p = inst.Position
			local s = inst.Size
			line = line..string.format(" pos=(%.1f,%.1f,%.1f) size=(%.1f,%.1f,%.1f)", p.X,p.Y,p.Z, s.X,s.Y,s.Z)
		elseif inst:IsA("ValueBase") then
			local ok,val = pcall(function() return inst.Value end)
			if ok and val ~= nil then line = line.." value="..tostring(val) end
		end
		table.insert(lines, line)
	end

	if depth >= depthLimit then return end
	for _,c in ipairs(inst:GetChildren()) do
		if #lines >= maxLines then break end
		local childPath = (path and (path.."."..c.Name)) or c.Name
		snapshot_instance(c, depth+1, lines, depthLimit, maxLines, classList, nameList, childPath)
	end
end

local function parse_list(s)
	local out = {}
	if not s then return out end
	for token in string.gmatch(s, "[^,]+") do
		token = token:gsub("^%s+", ""):gsub("%s+$", "")
		if token ~= "" then table.insert(out, token) end
	end
	return out
end

local function build_service_context(selected, filter)
	local blockLines = {}
	for svcName, enabled in pairs(selected) do
		if enabled then
			local ok, svc = pcall(function() return game:GetService(svcName) end)
			if ok and svc then
				snapshot_instance(svc, 0, blockLines, 4, 800, filter.classes, filter.names, string.lower(svc.Name))
			end
		end
	end
	return table.concat(blockLines, "\n")
end

local function find_scripts()
	local foundScripts = {}
	local plrs = game:GetService("Players")
	
	local function safe_scan(container, name)
		local ok, result = pcall(function()
			if not container then return {} end
			local scripts = {}
			for _, child in ipairs(container:GetDescendants()) do
				if child:IsA("LocalScript") or child:IsA("ModuleScript") then
					table.insert(scripts, child)
				end
				if #scripts > 50 then break end
			end
			return scripts
		end)
		return ok and result or {}
	end
	
	local containers = {
		{game:GetService("ReplicatedStorage"), "ReplicatedStorage"},
		{game:GetService("StarterGui"), "StarterGui"},
		{game:GetService("StarterPlayerScripts"), "StarterPlayerScripts"}
	}
	
	if plrs.LocalPlayer then
		local ok, playerGui = pcall(function() return plrs.LocalPlayer:FindFirstChild("PlayerGui") end)
		if ok and playerGui then
			table.insert(containers, {playerGui, "PlayerGui"})
		end
		
		local ok2, playerScripts = pcall(function() return plrs.LocalPlayer:FindFirstChild("PlayerScripts") end)
		if ok2 and playerScripts then
			table.insert(containers, {playerScripts, "PlayerScripts"})
		end
	end
	
	for _, container in ipairs(containers) do
		local scripts = safe_scan(container[1], container[2])
		for _, script in ipairs(scripts) do
			table.insert(foundScripts, script)
		end
	end
	
	return foundScripts
end

local function extract_answer(data)
	if type(data) ~= "table" then return nil end
	if type(data.output_text) == "string" and #data.output_text > 0 then return data.output_text end
	if type(data.output) == "table" then
		local buf = {}
		for _, item in ipairs(data.output) do
			if item and item.type == "message" and type(item.content) == "table" then
				for _, c in ipairs(item.content) do
					if type(c) == "table" then
						if c.type == "output_text" and type(c.text) == "string" and #c.text > 0 then
							table.insert(buf, c.text)
						elseif c.type == "text" then
							local t = (type(c.text)=="table" and (c.text.value or c.text)) or (type(c.text)=="string" and c.text)
							if type(t) == "string" and #t > 0 then table.insert(buf, t) end
						end
					end
				end
			end
			if item and (item.type == "tool_result" or item.type == "response.output_text.delta") and item.output_text then
				if type(item.output_text) == "string" and #item.output_text > 0 then table.insert(buf, item.output_text) end
			end
		end
		if #buf > 0 then return table.concat(buf, "\n") end
	end
	if type(data.choices) == "table" and data.choices[1] and data.choices[1].message and type(data.choices[1].message.content) == "string" then
		return data.choices[1].message.content
	end
	if type(data.message) == "table" and type(data.message.content) == "string" and #data.message.content > 0 then
		return data.message.content
	end
	return nil
end

local function extract_anthropic_text(obj)
	local buf = {}
	if type(obj) == "table" and type(obj.content) == "table" then
		for _,c in ipairs(obj.content) do
			if type(c) == "table" then
				if c.type == "text" and type(c.text) == "string" and #c.text > 0 then
					table.insert(buf, c.text)
				elseif c.type == "tool_use" then
					-- ignore
				elseif c.type == "web_search_tool_result" then
					-- ignore
				end
			end
		end
	end
	return table.concat(buf, "\n")
end

local function sanitize_label(s)
	s = tostring(s or "srv")
	s = s:gsub("^[^A-Za-z]+", "x")
	s = s:gsub("[^%w_%-]", "-")
	s = s:gsub("%-+", "-")
	return s
end

local function normalize_mcp_url(u)
	if type(u) ~= "string" then return u end
	local slug = u:match("^https?://smithery%.ai/server/(.+)$")
	if slug then
		return "https://server.smithery.ai/"..slug.."/mcp"
	end
	if u:match("^https?://server%.smithery%.ai/.+") and (not u:find("/mcp$")) then
		return u.."/mcp"
	end
	return u
end

local function is_array(t)
	if type(t) ~= "table" then return false end
	local n = 0
	for k,_ in pairs(t) do
		if type(k) ~= "number" then return false end
		n = n + 1
	end
	return n == #t and n > 0
end

local function normalize_headers(h)
	if type(h) ~= "table" then return nil end
	if not is_array(h) then
		local has_kv = false
		for k,_ in pairs(h) do if type(k) ~= "number" then has_kv = true break end end
		return has_kv and h or nil
	end
	local obj = {}
	for _,v in ipairs(h) do
		if type(v) == "table" then
			for kk,vv in pairs(v) do obj[tostring(kk)] = tostring(vv) end
		elseif type(v) == "string" then
			local k, val = string.match(v, "^%s*([^:=%s]+)%s*[:=]%s*(.+)$")
			if k and val then obj[k] = val end
		end
	end
	if next(obj) == nil then return nil end
	return obj
end

local function flatten_messages_to_prompt(msgs)
	local buf = {}
	for _,m in ipairs(msgs or {}) do
		local role = tostring(m.role or "system")
		local content = tostring(m.content or "")
		if content ~= "" then
			table.insert(buf, role..": "..content)
		end
	end
	return table.concat(buf, "\n\n")
end

local function get_rules_save_path()
	local base = "Obsidian"
	local sm = rawget(lib, "SaveManager")
	if sm and type(sm.Folder) == "string" and sm.Folder ~= "" then
		base = sm.Folder
	elseif type(lib.Folder) == "string" and lib.Folder ~= "" then
		base = lib.Folder
	end
	pcall(function()
		if not isfolder(base) then makefolder(base) end
	end)
	return base.."/ai_rules.json"
end

local function save_rules_to_disk(tbl)
	local ok, data = pcall(function() return hs:JSONEncode(tbl) end)
	if not ok then return end
	local path = get_rules_save_path()
	pcall(function() writefile(path, data) end)
end

local function load_rules_from_disk()
	local path = get_rules_save_path()
	local ok, data = pcall(function() return readfile(path) end)
	if not ok or type(data) ~= "string" or #data == 0 then return nil end
	local ok2, obj = pcall(function() return hs:JSONDecode(data) end)
	if not ok2 or type(obj) ~= "table" then return nil end
	return obj
end

local function attach(win, opt)
	opt = opt or {}
	local key = opt.key or ""
	local model = opt.model or "gpt-4o"
	local provider = opt.provider or "openai"
	local sys = opt.system or "you are a helpful assistant"
	local ide = opt.ide

	local base_rules = {
		sys,
		"when output includes code, wrap the code in fenced code blocks (```lua ... ```); do not add unrelated notes unless asked"
	}
	local user_rules = {}

	local persisted = load_rules_from_disk()
	if persisted and type(persisted.user_rules) == "table" then
		user_rules = persisted.user_rules
	end

	local scripts_store = {}
	local services_selected = {}
	local filter = { classes = {}, names = {} }

	local include_game_scripts = {}

	local function get_openai_key()
		local v = ""
		local opts = lib.Options
		if opts and opts.OpenAIKey and typeof(opts.OpenAIKey.Value) == "string" and opts.OpenAIKey.Value ~= "" then
			v = opts.OpenAIKey.Value
		elseif typeof(getgenv().ai_openai_key) == "string" and getgenv().ai_openai_key ~= "" then
			v = getgenv().ai_openai_key
		elseif typeof(getgenv().ai_key) == "string" and getgenv().ai_key ~= "" then
			v = getgenv().ai_key
		elseif typeof(key) == "string" then
			v = key
		end
		if type(v) == "string" then
			return (v:gsub("^%s+","")):gsub("%s+$","")
		end
		return ""
	end

	local function get_anthropic_key()
		local opts = lib.Options
		if opts and opts.AnthropicKey and typeof(opts.AnthropicKey.Value) == "string" and opts.AnthropicKey.Value ~= "" then
			return opts.AnthropicKey.Value
		end
		if typeof(getgenv().ai_anthropic_key) == "string" and getgenv().ai_anthropic_key ~= "" then return getgenv().ai_anthropic_key end
		return ""
	end

	local function get_gemini_key()
		local opts = lib.Options
		if opts and opts.GeminiKey and typeof(opts.GeminiKey.Value) == "string" and opts.GeminiKey.Value ~= "" then
			return opts.GeminiKey.Value
		end
		if typeof(getgenv().ai_gemini_key) == "string" and getgenv().ai_gemini_key ~= "" then return getgenv().ai_gemini_key end
		return ""
	end

	local function get_current_provider()
		local p = provider
		local opts = lib.Options
		if opts and opts.AIProvider and opts.AIProvider.Value then
			p = tostring(opts.AIProvider.Value)
		end
		if typeof(getgenv().ai_provider) == "string" and getgenv().ai_provider ~= "" then p = getgenv().ai_provider end
		if p == "" then p = "openai" end
		return p
	end

	local function default_model_for_provider(p)
		if p == "anthropic" then return "claude-3-5-sonnet-20240620" end
		if p == "google" then return "gemini-1.5-pro" end
		return "gpt-4o"
	end

	local function get_current_model(p)
		local m = model
		local opts = lib.Options
		if p == "openai" and opts and opts.OpenAIModel and opts.OpenAIModel.Value and tostring(opts.OpenAIModel.Value) ~= "" then
			m = tostring(opts.OpenAIModel.Value)
		elseif opts and opts.AIModel and opts.AIModel.Value and tostring(opts.AIModel.Value) ~= "" then
			m = tostring(opts.AIModel.Value)
		elseif m == "" or m == nil then
			m = default_model_for_provider(p)
		end
		return m
	end

	local function get_provider_key(p)
		if p == "anthropic" then return get_anthropic_key() end
		if p == "google" then return get_gemini_key() end
		return get_openai_key()
	end

	local function build_messages()
		local m = {}
		for _,r in ipairs(base_rules) do table.insert(m,{role="system",content=r}) end
		for _,r in ipairs(user_rules) do table.insert(m,{role="system",content=r}) end
		local ctx = build_service_context(services_selected, filter)
		if ctx ~= "" then table.insert(m, { role = "system", content = "services context:\n"..ctx }) end
		for inst, state in pairs(include_game_scripts) do
			if state and scripts_store[inst] then
				local path = instance_path(inst)
				table.insert(m, { role = "system", content = "game script: "..path.."\n```lua\n"..scripts_store[inst].."\n```" })
			end
		end
		local mem = getgenv().obs_mem
		if mem and mem.enabled and type(mem.chat) == "table" and #mem.chat > 0 then
			local memtxt = {}
			for _,mm in ipairs(mem.chat) do table.insert(memtxt, string.format("%s: %s", mm.role, tostring(mm.content or ""))) end
			table.insert(m, { role = "system", content = "chat memory:\n"..table.concat(memtxt, "\n") })
		end
		return m
	end

	local function insert_code(src)
		if ide and type(ide) == "table" and ide.GetText and ide.SetText then
			local cur = ide:GetText() or ""
			ide:SetText((#cur>0 and (cur.."\n") or "") .. src)
			lib:Notify("added to ide",2)
		elseif typeof(getgenv().obs_ide_insert)=="function" then
			getgenv().obs_ide_insert(src)
			lib:Notify("sent to ide",2)
		elseif setclipboard then
			setclipboard(src)
			lib:Notify("copied",2)
		end
	end

	local tab = win:AddKeyTab("AI Chat")

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1,0,1,0)
	holder.Parent = tab.Container

	local box = Instance.new("ScrollingFrame")
	box.BackgroundColor3 = lib.Scheme.MainColor
	box.BorderColor3 = lib.Scheme.OutlineColor
	box.AutomaticCanvasSize = Enum.AutomaticSize.Y
	box.CanvasSize = UDim2.fromOffset(0,0)
	box.ScrollBarThickness = 2
	box.Size = UDim2.new(1,-12,1,-66)
	box.Position = UDim2.fromOffset(6,6)
	box.Parent = holder

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0,6)
	list.Parent = box

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1,-12,0,44)
	row.Position = UDim2.new(0,6,1,-50)
	row.Parent = holder

	local inp = Instance.new("TextBox")
	inp.BackgroundColor3 = lib.Scheme.MainColor
	inp.BorderColor3 = lib.Scheme.OutlineColor
	inp.ClearTextOnFocus = false
	inp.TextXAlignment = Enum.TextXAlignment.Left
	inp.TextYAlignment = Enum.TextYAlignment.Center
	inp.FontFace = lib.Scheme.Font
	inp.TextColor3 = lib.Scheme.FontColor
	inp.TextSize = 14
	inp.PlaceholderText = "type..."
	inp.Size = UDim2.new(1,-206,1,0)
	inp.Parent = row

	local ip = Instance.new("UIPadding")
	ip.PaddingLeft = UDim.new(0,8)
	ip.Parent = inp

	local use_web = (typeof(getgenv().ai_enable_web) == "boolean") and getgenv().ai_enable_web or false

	local web = Instance.new("TextButton")
	web.BackgroundColor3 = lib.Scheme.MainColor
	web.BorderColor3 = lib.Scheme.OutlineColor
	web.Text = use_web and "web: on" or "web: off"
	web.FontFace = lib.Scheme.Font
	web.TextSize = 14
	web.TextColor3 = lib.Scheme.FontColor
	web.Size = UDim2.new(0,96,1,0)
	web.Position = UDim2.new(1,-200,0,0)
	web.Parent = row

	web.MouseButton1Click:Connect(function()
		use_web = not use_web
		getgenv().ai_enable_web = use_web
		web.Text = use_web and "web: on" or "web: off"
	end)

	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = lib.Scheme.MainColor
	btn.BorderColor3 = lib.Scheme.OutlineColor
	btn.Text = "send"
	btn.FontFace = lib.Scheme.Font
	btn.TextSize = 14
	btn.TextColor3 = lib.Scheme.FontColor
	btn.Size = UDim2.new(0,96,1,0)
	btn.Position = UDim2.new(1,-96,0,0)
	btn.Parent = row

	local rtab = win:AddKeyTab("AI Rules")
	local rh = Instance.new("Frame")
	rh.BackgroundTransparency = 1
	rh.Size = UDim2.new(1,0,1,0)
	rh.Parent = rtab.Container

	local rbox = Instance.new("ScrollingFrame")
	rbox.BackgroundColor3 = lib.Scheme.MainColor
	rbox.BorderColor3 = lib.Scheme.OutlineColor
	rbox.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rbox.CanvasSize = UDim2.fromOffset(0,0)
	rbox.ScrollBarThickness = 2
	rbox.Size = UDim2.new(1,-12,1,-66)
	rbox.Position = UDim2.fromOffset(6,6)
	rbox.Parent = rh

	local rlist = Instance.new("UIListLayout")
	rlist.Padding = UDim.new(0,6)
	rlist.Parent = rbox

	local rrow = Instance.new("Frame")
	rrow.BackgroundTransparency = 1
	rrow.Size = UDim2.new(1,-12,0,44)
	rrow.Position = UDim2.new(0,6,1,-50)
	rrow.Parent = rh

	local rinp = Instance.new("TextBox")
	rinp.BackgroundColor3 = lib.Scheme.MainColor
	rinp.BorderColor3 = lib.Scheme.OutlineColor
	rinp.ClearTextOnFocus = false
	rinp.TextXAlignment = Enum.TextXAlignment.Left
	rinp.TextYAlignment = Enum.TextYAlignment.Center
	rinp.FontFace = lib.Scheme.Font
	rinp.TextColor3 = lib.Scheme.FontColor
	rinp.TextSize = 14
	rinp.PlaceholderText = "add rule..."
	rinp.Size = UDim2.new(1,-210,1,0)
	rinp.Parent = rrow

	local radd = Instance.new("TextButton")
	radd.BackgroundColor3 = lib.Scheme.MainColor
	radd.BorderColor3 = lib.Scheme.OutlineColor
	radd.Text = "add"
	radd.FontFace = lib.Scheme.Font
	radd.TextSize = 14
	radd.TextColor3 = lib.Scheme.FontColor
	radd.Size = UDim2.new(0,96,1,0)
	radd.Position = UDim2.new(1,-200,0,0)
	radd.Parent = rrow

	local rclear = Instance.new("TextButton")
	rclear.BackgroundColor3 = lib.Scheme.MainColor
	rclear.BorderColor3 = lib.Scheme.OutlineColor
	rclear.Text = "clear"
	rclear.FontFace = lib.Scheme.Font
	rclear.TextSize = 14
	rclear.TextColor3 = lib.Scheme.FontColor
	rclear.Size = UDim2.new(0,96,1,0)
	rclear.Position = UDim2.new(1,-96,0,0)
	rclear.Parent = rrow

	local function refresh_rules()
		for _,c in ipairs(rbox:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
		local idx = 0
		for _,r in ipairs(base_rules) do idx = idx + 1; add_lbl(rbox, tostring(idx)..". "..r) end
		for _,r in ipairs(user_rules) do idx = idx + 1; add_lbl(rbox, tostring(idx)..". "..r) end
	end

	local function persist_rules()
		save_rules_to_disk({ user_rules = user_rules })
	end

	radd.MouseButton1Click:Connect(function()
		local t = rinp.Text
		if t=="" then return end
		rinp.Text = ""
		table.insert(user_rules, t)
		refresh_rules()
		persist_rules()
	end)

	rclear.MouseButton1Click:Connect(function()
		user_rules = {}
		refresh_rules()
		persist_rules()
	end)

	refresh_rules()

	local svctab = win:AddTab("Services", "server")
	local svcBoxLeft = svctab:AddLeftGroupbox("Services")
	local svcBoxRight = svctab:AddRightGroupbox("Selected Context")

	local preview = svcBoxRight:AddLabel({ Text = "", DoesWrap = true })

	local function update_preview()
		if not preview or not preview.SetText then return end
		local ctx = build_service_context(services_selected, filter)
		preview:SetText(ctx == "" and "no services selected" or ctx)
	end

	local classInput = svcBoxRight:AddInput("svc_classes", { Text = "Class Filter(s) e.g. Model, Part"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) end })
	local nameInput = svcBoxRight:AddInput("svc_names", { Text = "Name Contains (comma list)"; Default = ""; Finished = true; ClearTextOnFocus = false; Callback = function(v) end })
	classInput:OnChanged(function(v) filter.classes = parse_list(v); update_preview() end)
	nameInput:OnChanged(function(v) local lst=parse_list(v); for i=1,#lst do lst[i]=lst[i]:lower() end filter.names=lst; update_preview() end)

	for _, svc in ipairs(game:GetChildren()) do
		local name = svc.ClassName
		svcBoxLeft:AddToggle("AI_SVC_"..name, {
			Text = name,
			Default = false,
			Callback = function(v)
				services_selected[name] = v or nil
				update_preview()
			end
		})
	end

	svctab:AddRightGroupbox("Actions"):AddButton({ Text = "Refresh Context", Func = update_preview })

	local stab = win:AddKeyTab("AI Scripts")
	local sh = Instance.new("Frame")
	sh.BackgroundTransparency = 1
	sh.Size = UDim2.new(1,0,1,0)
	sh.Parent = stab.Container

	local sbox = Instance.new("ScrollingFrame")
	sbox.BackgroundColor3 = lib.Scheme.MainColor
	sbox.BorderColor3 = lib.Scheme.OutlineColor
	sbox.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sbox.CanvasSize = UDim2.fromOffset(0,0)
	sbox.ScrollBarThickness = 2
	sbox.Size = UDim2.new(1,-12,1,-12)
	sbox.Position = UDim2.fromOffset(6,6)
	sbox.Parent = sh

	local slist = Instance.new("UIListLayout")
	slist.Padding = UDim.new(0,8)
	slist.Parent = sbox

	local function add_script(code)
		table.insert(scripts_store, code)
		local codebtn = Instance.new("TextButton")
		codebtn.AutoButtonColor = true
		codebtn.BackgroundColor3 = lib.Scheme.MainColor
		codebtn.BorderColor3 = lib.Scheme.OutlineColor
		codebtn.TextXAlignment = Enum.TextXAlignment.Left
		codebtn.TextYAlignment = Enum.TextYAlignment.Top
		codebtn.TextWrapped = true
		codebtn.FontFace = lib.Scheme.Font
		codebtn.TextSize = 14
		codebtn.TextColor3 = lib.Scheme.FontColor
		codebtn.AutomaticSize = Enum.AutomaticSize.Y
		codebtn.Size = UDim2.new(1,-12,0,0)
		codebtn.Parent = sbox
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0,8)
		pad.PaddingRight = UDim.new(0,8)
		pad.PaddingTop = UDim.new(0,6)
		pad.PaddingBottom = UDim.new(0,6)
		pad.Parent = codebtn
		local norm = code
		codebtn.Text = norm
		codebtn.RichText = false
		codebtn.MouseButton1Click:Connect(function()
			insert_code(norm)
		end)
	end

	local gtab = win:AddTab("Game Scripts", "file-text")
	local gLeft = gtab:AddLeftGroupbox("Scripts")
	local gRight = gtab:AddRightGroupbox("Preview")

	local currentInst
	local aiToggle

	local pvHolder = Instance.new("Frame")
	pvHolder.BackgroundTransparency = 1
	pvHolder.Size = UDim2.new(1,0,0,300)
	pvHolder.Parent = gRight.Container

	local pvFrame = Instance.new("Frame")
	pvFrame.BackgroundColor3 = lib.Scheme.MainColor
	pvFrame.BorderColor3 = lib.Scheme.OutlineColor
	pvFrame.BorderSizePixel = 1
	pvFrame.Size = UDim2.new(1,0,1,0)
	pvFrame.Parent = pvHolder

	local pv = Instance.new("ScrollingFrame")
	pv.BackgroundTransparency = 1
	pv.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pv.CanvasSize = UDim2.fromOffset(0,0)
	pv.ScrollBarThickness = 2
	pv.Size = UDim2.new(1,-4,1,-4)
	pv.Position = UDim2.fromOffset(2,2)
	pv.Parent = pvFrame

	local pvText = Instance.new("TextLabel")
	pvText.BackgroundTransparency = 1
	pvText.TextXAlignment = Enum.TextXAlignment.Left
	pvText.TextYAlignment = Enum.TextYAlignment.Top
	pvText.TextWrapped = true
	pvText.FontFace = lib.Scheme.Font
	pvText.TextSize = 14
	pvText.TextColor3 = lib.Scheme.FontColor
	pvText.AutomaticSize = Enum.AutomaticSize.Y
	pvText.Size = UDim2.new(1,-12,0,0)
	pvText.Position = UDim2.fromOffset(6,6)
	pvText.Parent = pv

	pv.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			for _, side in ipairs(win.ActiveTab and win.ActiveTab.Sides or {}) do
				side.ScrollingEnabled = false
			end
			task.delay(0.05, function()
				for _, side in ipairs(win.ActiveTab and win.ActiveTab.Sides or {}) do
					side.ScrollingEnabled = true
				end
			end)
		end
	end)

	local function apply_preview_text(src)
		local t = add_code_block(pvText, src or "")
		return t
	end

	apply_preview_text("select a script to preview")

	aiToggle = gRight:AddToggle("AI_CONTEXT", { 
		Text = "Give Context To AI"; 
		Default = false; 
		Callback = function(v) 
			if currentInst then 
				include_game_scripts[currentInst] = v;
				lib:Notify(v and "added to ai context" or "removed from ai context", 2);
			end 
		end 
	});

	local function add_script_button(inst)
		local path = instance_path(inst)
		gLeft:AddButton({ 
			Text = inst.Name .. " (" .. inst.ClassName .. ")"; 
			Func = function()
				currentInst = inst;
				apply_preview_text("decompiling " .. inst.Name .. "...")
				aiToggle:SetValue(include_game_scripts[inst] or false);
				
				task.spawn(function()
					local ok, src = pcall(function() 
						return decompile(inst) 
					end);
					local code = ok and src or "decompile failed";
					scripts_store[inst] = code;
					apply_preview_text(code)
					
					if setclipboard then
						setclipboard(code);
						lib:Notify("copied to clipboard", 2);
					end;
				end);
			end 
		});
	end

	local function rebuild_game_scripts()
		if gLeft.Elements then
			for _,el in ipairs(gLeft.Elements) do 
				if el.Holder then 
					el.Holder:Destroy() 
				end 
			end
			gLeft.Elements = {}
		end
		
		local scripts = find_scripts();
		lib:Notify("found " .. #scripts .. " scripts", 2);
		
		for _, inst in ipairs(scripts) do
			add_script_button(inst);
		end
		
		if #scripts == 0 then
			gLeft:AddLabel("no localscript/modulescript found");
		end
	end

	gLeft:AddButton({ Text = "Refresh Scripts"; Func = rebuild_game_scripts });
	rebuild_game_scripts();

	local function render_reply(text, model_name)
		local prefixed = false
		local i = 1
		while true do
			local a,b,seg = text:find("```(.-)```", i)
			if not a then
				local tail = text:sub(i)
				if tail ~= "" then
					if not prefixed then add_line_with_prefix(box, "ai", tail, model_name); prefixed = true else add_lbl(box, tail) end
				elseif not prefixed then
					add_line_with_prefix(box, "ai", "", model_name)
					prefixed = true
				end
				break
			end
			local pre = text:sub(i, a-1)
			if pre ~= "" then
				if not prefixed then add_line_with_prefix(box, "ai", pre, model_name); prefixed = true else add_lbl(box, pre) end
			elseif not prefixed then
				add_line_with_prefix(box, "ai", "", model_name)
				prefixed = true
			end
			local norm = seg:gsub("^%s*[%w%-_]*\n", "", 1)
			add_script(norm)
			i = b + 1
		end
	end

	local function maybe_prepend_docs(q, msgs)
		local f = getgenv().obs_knowledge_context_for_query
		if typeof(f) == "function" and (getgenv().ai_use_docs == true) then
			local ctx = f(q)
			if type(ctx) == "string" and #ctx > 0 then
				table.insert(msgs, 1, { role = "system", content = "docs context:\n"..ctx })
			end
		end
	end

	local busy = false
	local function send()
		if busy then return end
		local q = inp.Text
		if q == "" then return end
		inp.Text = ""
		add_line_with_prefix(box, "user", q)
		local waitlbl = add_lbl(box, "...")
		local base = build_messages()
		table.insert(base, { role = "user", content = q })
		maybe_prepend_docs(q, base)
		busy = true
		
		local out = "request failed"
		local prov = get_current_provider()
		local model_name = get_current_model(prov)
		local k = get_provider_key(prov)

		local want_mcp = false
		if typeof(getgenv().mcp_use_in_chat) == "boolean" and getgenv().mcp_enabled == true then want_mcp = getgenv().mcp_use_in_chat end

		if prov == "openai" then
			if use_web or want_mcp then
				local tools = {}
				if use_web then table.insert(tools, { type = "web_search_preview" }) end
				local function mcp_tools()
					if getgenv().mcp_enabled and getgenv().mcp_use_in_chat and type(getgenv().mcp_servers) == "table" then
						for idx, e in ipairs(getgenv().mcp_servers) do
							if e and (e.enabled ~= false) and type(e.url) == "string" and e.url ~= "" then
								local label = (tostring(e.label or ("srv"..tostring(idx))))
								local url = normalize_mcp_url(e.url)
								local hdr = normalize_headers(e.headers)
								table.insert(tools, { type = "mcp", server_label = label, server_url = url, require_approval = e.require_approval or e.req or "never", headers = hdr })
							end
						end
					end
				mcp_tools()
				local prompt = flatten_messages_to_prompt(base)
				local body = { model = model_name, tools = tools, input = prompt }
				local success, result = pcall(function()
					return request({
						Url = "https://api.openai.com/v1/responses";
						Method = "POST";
						Headers = { ["Content-Type"] = "application/json"; ["Authorization"] = "Bearer "..k; };
						Body = hs:JSONEncode(body);
					})
				end)
				if not success then
					out = "request error: "..tostring(result)
				elseif not result or not result.Body then
					out = "empty response body"
				else
					local okj, data = pcall(hs.JSONDecode, hs, result.Body)
					if okj then
						local txt = extract_answer(data)
						if not txt or txt == "" then
							if data.error and data.error.message then
								out = "api error: "..tostring(data.error.message)
							else
								out = "no answer text\nraw: "..string.sub(result.Body,1,1200)
							end
						else
							out = txt
						end
					else
						out = "json parse error"
					end
				end
			else
				local success, result = pcall(function()
					return request({ 
						Url = "https://api.openai.com/v1/chat/completions"; 
						Method = "POST"; 
						Headers = { 
							["Content-Type"] = "application/json"; 
							["Authorization"] = "Bearer "..k; 
						}; 
						Body = hs:JSONEncode({ 
							model = model_name; 
							messages = base; 
						}); 
					})
				end)
				if not success then
					out = "request error: " .. tostring(result)
				elseif not result then
					out = "no response received"
				elseif not result.Body then
					out = "empty response body"
				else
					local parseOk, data = pcall(hs.JSONDecode, hs, result.Body)
					if not parseOk then
						out = "json parse error: " .. tostring(data) .. "\nraw response: " .. result.Body
					elseif data.error then
						out = "api error: " .. (data.error.message or tostring(data.error))
					elseif not data.choices or #data.choices == 0 then
						out = "no choices in response\nraw: " .. result.Body
					elseif not data.choices[1].message then
						out = "no message in choice\nraw: " .. result.Body  
					elseif not data.choices[1].message.content then
						out = "no content in message\nraw: " .. result.Body
					else
						out = data.choices[1].message.content
					end
				end
			end
		elseif prov == "anthropic" then
			local sysParts = {}
			local amsg = {}
			for _,m in ipairs(base) do
				if m.role == "system" then
					table.insert(sysParts, m.content or "")
				else
					local r = m.role == "assistant" and "assistant" or "user"
					table.insert(amsg, { role = r, content = tostring(m.content or "") })
				end
			end
			local body = { model = model_name, system = table.concat(sysParts, "\n\n"), messages = amsg, max_tokens = 1024 }
			if getgenv().ai_enable_web then
				local t = { { type = "web_search_20250305", name = "web_search", max_uses = tonumber(getgenv().ai_web_max_uses) }, }
				if typeof(getgenv().ai_web_allowed_domains) == "table" then t[1].allowed_domains = getgenv().ai_web_allowed_domains end
				if typeof(getgenv().ai_web_blocked_domains) == "table" then t[1].blocked_domains = getgenv().ai_web_blocked_domains end
				if typeof(getgenv().ai_web_user_location) == "table" then t[1].user_location = getgenv().ai_web_user_location end
				body.tools = t
			end
			local success, result = pcall(function()
				return request({
					Url = "https://api.anthropic.com/v1/messages";
					Method = "POST";
					Headers = { ["Content-Type"] = "application/json"; ["x-api-key"] = k; ["anthropic-version"] = "2023-06-01"; };
					Body = hs:JSONEncode(body);
				})
			end)
			if not success then
				out = "request error: "..tostring(result)
			elseif not result or not result.Body then
				out = "empty response body"
			else
				local okj, data = pcall(hs.JSONDecode, hs, result.Body)
				if okj and type(data) == "table" then
					local txt = extract_anthropic_text(data)
					if txt == "" then
						out = "no answer text\nraw: "..string.sub(result.Body,1,1200)
					else
						out = txt
					end
				else
					out = "json parse error"
				end
			end
		elseif prov == "google" then
			local prompt = flatten_messages_to_prompt(base)
			local body = { contents = { { role = "user", parts = { { text = prompt } } } } }
			local url = "https://generativelanguage.googleapis.com/v1beta/models/"..model_name..":generateContent?key="..hs:UrlEncode(k)
			local success, result = pcall(function()
				return request({
					Url = url;
					Method = "POST";
					Headers = { ["Content-Type"] = "application/json" };
					Body = hs:JSONEncode(body);
				})
			end)
			if not success then
				out = "request error: "..tostring(result)
			elseif not result or not result.Body then
				out = "empty response body"
			else
				local okj, data = pcall(hs.JSONDecode, hs, result.Body)
				if okj and type(data) == "table" then
					local txt = ""
					local cand = data.candidates and data.candidates[1]
					if cand and cand.content and cand.content.parts then
						local buf = {}
						for _,p in ipairs(cand.content.parts) do if p and type(p.text)=="string" then table.insert(buf, p.text) end end
						txt = table.concat(buf, "\n")
					end
					out = (txt ~= "" and txt) or "no answer text"
				else
					out = "json parse error"
				end
			end
		else
			out = "unknown provider"
		end
		
		waitlbl:Destroy()
		render_reply(out, prov..":"..model_name)
		busy = false

		local mem = getgenv().obs_mem
		if mem and mem.enabled then
			local function push(role, content)
				table.insert(mem.chat, { role = role, content = content })
				while #mem.chat > (tonumber(mem.max_turns) or 10) * 2 do table.remove(mem.chat, 1) end
			end
			push("user", q)
			push("assistant", out)
		end

		local msgs = {}
		for _,m in ipairs(base) do table.insert(msgs, m.content or "") end
		getgenv().obs_last_context_text = table.concat(msgs, "\n\n")
		if type(getgenv().obs_mem_refresh) == "function" then pcall(getgenv().obs_mem_refresh) end
	end

	btn.MouseButton1Click:Connect(send)
	inp.FocusLost:Connect(function(enter) if enter then send() end end)

	return { tab = tab }
end

print("ai_chat_ext v15.5")
return { attach = attach }
