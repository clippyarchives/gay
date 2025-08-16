local lib = getgenv().Library
if not lib then error("load Library.lua first") end

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

local function join_chat(mem)
	local lines = {}
	for _,m in ipairs(mem.chat) do
		table.insert(lines, ((m.role == "assistant" and "ai" or "user") .. ": " .. tostring(m.content or "")))
	end
	return table.concat(lines, "\n")
end

local function attach(win)
	local mem = ensure_mem()
	local tab = win:AddTab("AI Memory", "database")

	local left = tab:AddLeftGroupbox("Controls")
	local right = tab:AddRightGroupbox("Current Context")

	left:AddToggle("obs_mem_enabled", { Text = "enable chat memory"; Default = mem.enabled; Callback = function(v) mem.enabled = v end })
	left:AddSlider("obs_mem_len", { Text = "max turns"; Default = mem.max_turns; Min = 1; Max = 50; Rounding = 0; Compact = false; Callback = function(v) mem.max_turns = math.clamp(math.floor(v+0.5),1,50) end })
	left:AddButton({ Text = "clear memory"; Func = function() mem.chat = {} refresh() end })
	left:AddButton({ Text = "copy memory"; Func = function() if setclipboard then setclipboard(join_chat(mem)) end end })

	local memBox = right:AddLabel({ Text = ""; DoesWrap = true })
	right:AddDivider()
	local ctxBox = right:AddLabel({ Text = ""; DoesWrap = true })

	refresh = function()
		local memTxt = (#mem.chat==0 and "(empty)") or join_chat(mem)
		memBox:SetText("chat memory (most recent last):\n"..memTxt)
		local ctx = tostring(getgenv().obs_last_context_text or "(no request yet)")
		ctxBox:SetText("last built context sent to ai:\n"..ctx)
	end

	getgenv().obs_mem_refresh = refresh
	refresh()

	return { tab = tab, refresh = refresh }
end

print("ai_memory_ext v2")
return { attach = attach }
