local lib = getgenv().Library
if not lib then error("load Library.lua first") end

local syn = {}
syn.kw = { ["and"]=true,["break"]=true,["do"]=true,["else"]=true,["elseif"]=true,["end"]=true,["false"]=true,["for"]=true,["function"]=true,["if"]=true,["in"]=true,["local"]=true,["nil"]=true,["not"]=true,["or"]=true,["repeat"]=true,["return"]=true,["then"]=true,["true"]=true,["until"]=true,["while"]=true };
syn.lib = { game=true,workspace=true,script=true,math=true,string=true,table=true,bit32=true,task=true,coroutine=true,debug=true,os=true,Enum=true,Instance=true,CFrame=true,Vector2=true,Vector3=true,UDim2=true,Color3=true };
syn.fn = { pairs=true,ipairs=true,next=true,type=true,tostring=true,tonumber=true,pcall=true,xpcall=true,setmetatable=true,getmetatable=true,rawget=true,rawset=true,rawequal=true,require=true,print=true,warn=true,tick=true,time=true };
syn.col = { kw="#569CD6", str="#CE9178", com="#6A9955", num="#B5CEA8", lib="#4EC9B0", fn="#DCDCAA" };

local sent = string.char(30)
local function esc(s)
    s = s:gsub("&","&amp;"); s = s:gsub("<","&lt;"); s = s:gsub(">","&gt;"); return s
end
local function map_out(s, f)
    local i = 1; local out = {}
    while true do
        local a = string.find(s, sent, i, true)
        if not a then out[#out+1] = f(s:sub(i)); break end
        local b = string.find(s, sent, a+1, true)
        if not b then out[#out+1] = f(s:sub(i)); break end
        out[#out+1] = f(s:sub(i, a-1))
        out[#out+1] = s:sub(a, b)
        i = b + 1
    end
    return table.concat(out)
end
function syn.hl(s)
    if typeof(s) ~= "string" then return "" end
    local segs = {}
    local function hold(v)
        local i = #segs+1; segs[i] = v; return sent..i..sent
    end
    s = esc(s)
    s = s:gsub("(%b\"\")", function(m) return hold("<font color=\""..syn.col.str.."\">"..m.."</font>") end)
    s = s:gsub("(%b'')", function(m) return hold("<font color=\""..syn.col.str.."\">"..m.."</font>") end)
    s = s:gsub("(%-%-[^\n]*)", function(m) return hold("<font color=\""..syn.col.com.."\">"..m.."</font>") end)
    s = map_out(s, function(seg)
        for k,_ in pairs(syn.lib) do
            seg = seg:gsub("%f[%a_]"..k.."%f[^%a_]", function() return hold("<font color=\""..syn.col.lib.."\">"..k.."</font>") end)
        end
        return seg
    end)
    s = map_out(s, function(seg)
        for k,_ in pairs(syn.fn) do
            seg = seg:gsub("%f[%a_]"..k.."%f[^%a_]", function() return hold("<font color=\""..syn.col.fn.."\">"..k.."</font>") end)
        end
        return seg
    end)
    s = map_out(s, function(seg)
        seg = seg:gsub("%f[%a_]([%a_][%w_]*)%f[^%a_]", function(w)
            if syn.kw[w] then return hold("<font color=\""..syn.col.kw.."\">"..w.."</font>") end; return w
        end)
        return seg
    end)
    s = map_out(s, function(seg)
        return (seg:gsub("%f[%d]([%d]+%.?[%d]*)%f[^%d]", function(n)
            return hold("<font color=\""..syn.col.num.."\">"..n.."</font>")
        end))
    end)
    s = s:gsub(sent.."(%d+)"..sent, function(i) return segs[tonumber(i)] or "" end)
    return s
end

local function attach(ed)
    if not ed or not ed.TextBox then return end
    local tb = ed.TextBox
    local p = tb.Parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.RichText = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextWrapped = false
    lbl.FontFace = lib.Scheme.Font or Font.fromEnum(Enum.Font.Code)
    lbl.TextSize = tb.TextSize
    lbl.TextColor3 = lib.Scheme.FontColor
    lbl.ZIndex = 2
    lbl.Size = UDim2.fromScale(1,1)
    lbl.Parent = p

    tb.ZIndex = 3
    tb.TextTransparency = 1

    local function upd()
        lbl.Text = syn.hl(tb.Text)
    end
    upd()

    local con1 = tb:GetPropertyChangedSignal("Text"):Connect(upd)

    local old = ed.Destroy
    ed.Destroy = function(self)
        if con1 then con1:Disconnect() end
        if lbl then lbl:Destroy() end
        old(self)
    end

    return { label = lbl, disconnect = function() if con1 then con1:Disconnect() end end }
end

return { syn = syn, attach = attach }
