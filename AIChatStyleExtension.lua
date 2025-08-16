local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local function ensure_style()
	local s = getgenv().obs_chat_style
	if type(s) ~= "table" then
		s = {}
		getgenv().obs_chat_style = s
	end
	s.ai_color = s.ai_color or Color3.fromRGB(180,220,255)
	s.user_color = s.user_color or Color3.fromRGB(220,220,220)
	s.use_model_prefix = (s.use_model_prefix ~= false)
	s.ai_label = s.ai_label or "AI"
	return s
end

local function attach(win)
	local s = ensure_style()
	local tab = win:AddTab("AI Style", "palette")

	local left = tab:AddLeftGroupbox("appearance")
	local right = tab:AddRightGroupbox("labels")

	local ai_lbl = left:AddLabel("ai message color")
	ai_lbl:AddColorPicker("obs_ai_col", { Default = s.ai_color; Transparency = 0; Callback = function(v) s.ai_color = v end })
	local user_lbl = left:AddLabel("user message color")
	user_lbl:AddColorPicker("obs_user_col", { Default = s.user_color; Transparency = 0; Callback = function(v) s.user_color = v end })

	right:AddToggle("obs_use_model_prefix", { Text = "use model name in ai prefix"; Default = s.use_model_prefix; Callback = function(v) s.use_model_prefix = v end })
	right:AddInput("obs_ai_label", { Text = "custom ai label (when toggle off)"; Default = s.ai_label; Finished = true; ClearTextOnFocus = false; Callback = function(v) s.ai_label = v end })

	return { tab = tab }
end

print("ai_chat_style_ext v1")
return { attach = attach }
