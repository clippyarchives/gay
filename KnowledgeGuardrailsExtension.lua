local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local hs = game:GetService("HttpService")

local function jenc(t) return hs:JSONEncode(t) end
local function jdec(s) local ok,d=pcall(hs.JSONDecode,hs,s); return ok and d or nil end

local function get_key()
	local o = (lib.Options and lib.Options.OpenAIKey and lib.Options.OpenAIKey.Value) or getgenv().ai_key or ""
	return o
end

local EMB_MODEL = "text-embedding-3-small"
local store = { model = EMB_MODEL, docs = {} }
local store_path = "obs_knowledge_store.json"

local function load_store()
	if isfile and isfile(store_path) then
		local d = jdec(readfile(store_path) or "")
		if type(d)=="table" and d.docs then store = d end
	end
end
local function save_store()
	if writefile then writefile(store_path, jenc(store)) end
end

local function dot(a,b)
	local s=0; for i=1,math.min(#a,#b) do s=s+a[i]*b[i] end; return s
end
local function norm(a)
	local s=0; for i=1,#a do s=s+a[i]*i end; return math.sqrt(s)
end
local function cos(a,b)
	local na,nb = norm(a), norm(b)
	if na==0 or nb==0 then return 0 end
	return dot(a,b)/(na*nb)
end

local function embed(text)
	local key = get_key()
	local body = { model = EMB_MODEL, input = text }
	local ok,res = pcall(function()
		return (request or http_request or (syn and syn.request))({
			Url = "https://api.openai.com/v1/embeddings",
			Method = "POST",
			Headers = { ["Content-Type"]="application/json", ["Authorization"]="Bearer "..key },
			Body = jenc(body)
		})
	end)
	if not ok or not res or not res.Body then return nil end
	local d = jdec(res.Body)
	if not d or not d.data or not d.data[1] or not d.data[1].embedding then return nil end
	return d.data[1].embedding
end

local function add_doc(title, text)
	local vec = embed(text)
	if not vec then return false, "embed failed" end
	table.insert(store.docs, { id = #store.docs+1, title = title or ("doc_"..tostring(#store.docs+1)), text = text, vec = vec })
	save_store()
	return true
end

local function search_docs(query, topk)
	topk = topk or 3
	local qv = embed(query)
	if not qv then return {} end
	local scored = {}
	for _,d in ipairs(store.docs) do
		local s = cos(qv, d.vec)
		scored[#scored+1] = { score=s, doc=d }
	end
	table.sort(scored, function(a,b) return a.score>b.score end)
	local out = {}
	for i=1, math.min(topk, #scored) do out[i]=scored[i].doc end
	return out
end

local function build_context_for_query(q, topk)
	local hits = search_docs(q, topk)
	local buf = {}
	for _,d in ipairs(hits) do
		buf[#buf+1] = ("["..d.title.."]\n"..d.text)
	end
	return table.concat(buf, "\n\n---\n\n")
end

-- expose query hook used by chat extension
getgenv().obs_knowledge_context_for_query = function(q)
	local k = (lib.Options and lib.Options.KG_TopK and tonumber(lib.Options.KG_TopK.Value)) or 3
	return build_context_for_query(q, k)
end

-- moderation hooks
local function moderate(txt)
	local key = get_key()
	if not txt or txt=="" then return true,nil end
	local body = { model = "omni-moderation-latest", input = txt }
	local ok,res = pcall(function()
		return (request or http_request or (syn and syn.request))({
			Url = "https://api.openai.com/v1/moderations",
			Method = "POST",
			Headers = { ["Content-Type"]="application/json", ["Authorization"]="Bearer "..key },
			Body = jenc(body)
		})
	end)
	if not ok or not res or not res.Body then return true,nil end
	local d = jdec(res.Body)
	local r = d and d.results and d.results[1]
	if r and r.flagged then
		return false, "flagged by moderation"
	end
	return true,nil
end

getgenv().obs_moderate_input = function(text)
	if not (getgenv().kg_mod_in or false) then return true,nil end
	return moderate(text)
end
getgenv().obs_moderate_output = function(text)
	if not (getgenv().kg_mod_out or false) then return true,nil end
	return moderate(text)
end

local function attach(win)
	load_store()
	local tab = win:AddTab("Add Docs","book") -- renamed
	local left = tab:AddLeftGroupbox("Store")
	local right = tab:AddRightGroupbox("Search & Settings")

	left:AddInput("KG_Title", { Text = "title"; Default = "doc"; Finished = true })
	left:AddInput("KG_Text", { Text = "content"; Default = ""; Finished = true })
	left:AddButton({ Text = "Add Doc", Func = function()
		local title = (lib.Options.KG_Title and lib.Options.KG_Title.Value) or "doc"
		local text  = (lib.Options.KG_Text and lib.Options.KG_Text.Value) or ""
		if text=="" then lib:Notify("no content",2) return end
		local ok,err = add_doc(title,text)
		lib:Notify(ok and "added" or ("fail: "..tostring(err)),2)
	end })

	right:AddSlider("KG_TopK", { Text = "top-k"; Default = 3; Min = 1; Max = 5; Rounding = 0 })
	local prev = right:AddLabel({ Text = ""; DoesWrap = true })
	right:AddInput("KG_Query", { Text = "query (preview only)"; Default = ""; Finished = true })
	right:AddButton({ Text = "Preview", Func = function()
		local q = (lib.Options.KG_Query and lib.Options.KG_Query.Value) or ""
		if q=="" then prev:SetText("") return end
		prev:SetText(build_context_for_query(q, (lib.Options.KG_TopK and lib.Options.KG_TopK.Value) or 3))
	end })

	right:AddDivider()
	right:AddToggle("KG_ModIn", { Text = "moderate input"; Default = false; Callback=function(v) getgenv().kg_mod_in = v end })
	right:AddToggle("KG_ModOut", { Text = "moderate output"; Default = false; Callback=function(v) getgenv().kg_mod_out = v end })
	right:AddToggle("KG_UseDocs", { Text = "use docs in ai chat \n[must have web on]"; Default = (getgenv().ai_use_docs==true); Callback=function(v) getgenv().ai_use_docs = v end })

	return { tab = tab }
end

return { attach = attach }
