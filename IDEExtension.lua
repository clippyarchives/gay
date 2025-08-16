-- IDE Extension for Obsidian Library

local lib = getgenv().Library
if not lib then error("Library not found! Load Library.lua first.") end

local TextService = game:GetService("TextService")

local editors = {}

local function maketext(parent, text)
    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = lib.Scheme.MainColor
    holder.BackgroundTransparency = 0
    holder.Size = UDim2.new(1, 0, 1, -54)
    holder.Position = UDim2.fromOffset(0, 24)
    holder.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, lib.CornerRadius or 4)
    corner.Parent = holder

    local stroke = Instance.new("UIStroke")
    stroke.Color = lib.Scheme.OutlineColor
    stroke.Parent = holder

    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.CanvasSize = UDim2.fromOffset(0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
    scroll.ScrollBarThickness = 2
    scroll.Parent = holder

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = scroll

    local tb = Instance.new("TextBox")
    tb.RichText = false
    tb.MultiLine = true
    tb.ClearTextOnFocus = false
    tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.TextYAlignment = Enum.TextYAlignment.Top
    tb.BackgroundTransparency = 1
    tb.TextEditable = true
    tb.TextWrapped = true
    tb.Text = text or ""
    tb.FontFace = lib.Scheme.Font or Font.fromEnum(Enum.Font.Code)
    tb.TextSize = 14
    tb.TextColor3 = lib.Scheme.FontColor
    tb.Size = UDim2.new(1, 0, 0, 0)
    tb.Parent = scroll

    local function updateCanvas()
        local width = math.max(1, scroll.AbsoluteSize.X - (pad.PaddingLeft.Offset + pad.PaddingRight.Offset))
        local params = Instance.new("GetTextBoundsParams")
        params.Text = (tb.Text == "" and " " or tb.Text)
        params.RichText = false
        params.Font = tb.FontFace
        params.Size = tb.TextSize
        params.Width = width
        local bounds = TextService:GetTextBoundsAsync(params)
        tb.Size = UDim2.new(1, 0, 0, bounds.Y)
        scroll.CanvasSize = UDim2.fromOffset(0, bounds.Y + pad.PaddingTop.Offset + pad.PaddingBottom.Offset)
    end

    updateCanvas()
    tb:GetPropertyChangedSignal("Text"):Connect(updateCanvas)
    scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)

    return holder, scroll, tb, updateCanvas
end

function lib:CreateCodeEditor(info)
    info = info or {}

    local size = info.Size or UDim2.fromOffset(460, 260)
    local pos = info.Position or UDim2.fromOffset(12, 12)
    local parent = info.Parent or self.ScreenGui
    local visible = info.Visible ~= false
    local value = info.Default or ""
    local readonly = info.ReadOnly or false

    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = size
    holder.Position = pos
    holder.Visible = visible
    holder.Parent = parent

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = info.Title or "code"
    title.FontFace = lib.Scheme.Font or Font.fromEnum(Enum.Font.Gotham)
    title.TextColor3 = lib.Scheme.FontColor
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Parent = holder

    local editor_frame, scroll, textbox, updateCanvas = maketext(holder, value)
    textbox.TextEditable = not readonly

    local btnbar = Instance.new("Frame")
    btnbar.BackgroundTransparency = 1
    btnbar.Size = UDim2.new(1, 0, 0, 30)
    btnbar.Position = UDim2.new(0, 0, 1, -30)
    btnbar.ZIndex = 2
    btnbar.Parent = holder

    local pad = Instance.new("UIPadding")
    pad.PaddingRight = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.Parent = btnbar

    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Padding = UDim.new(0, 6)
    list.Parent = btnbar

    local function mkbtn(txt, cb)
        local b = Instance.new("TextButton")
        b.AutoButtonColor = true
        b.Text = txt
        b.FontFace = lib.Scheme.Font or Font.fromEnum(Enum.Font.Gotham)
        b.TextSize = 14
        b.TextColor3 = lib.Scheme.FontColor
        b.BackgroundColor3 = lib.Scheme.MainColor
        b.Size = UDim2.fromOffset(88, 26)
        b.ZIndex = 3
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, lib.CornerRadius or 4)
        c.Parent = b
        local s = Instance.new("UIStroke")
        s.Color = lib.Scheme.OutlineColor
        s.Parent = b
        b.Parent = btnbar
        b.MouseButton1Click:Connect(cb)
        return b
    end

    local ed = { Holder = holder, TextBox = textbox, Title = title, Type = "CodeEditor", Visible = visible }

    function ed:SetText(t) textbox.Text = t or ""; updateCanvas() end
    function ed:GetText() return textbox.Text end
    function ed:SetVisible(v) self.Visible = v; holder.Visible = v end
    function ed:SetSize(s) holder.Size = s; updateCanvas() end
    function ed:SetPosition(p) holder.Position = p end
    function ed:SetReadOnly(v) textbox.TextEditable = not v end
    function ed:Destroy() editors[self] = nil; holder:Destroy() end

    local path = info.Path or "obsidian_editor.lua"

    mkbtn("run", function()
        local src = textbox.Text
        local f = (getgenv().loadstring or loadstring)(src)
        if typeof(f) == "function" then
            local ok, err = pcall(f)
            if not ok and lib.NotifyOnError then lib:Notify({Title = "error", Description = tostring(err), Time = 4}) end
        end
    end)

    mkbtn("save", function()
        if writefile then writefile(path, textbox.Text); lib:Notify("saved: " .. path, 3) else lib:Notify("writefile unsupported", 3) end
    end)

    mkbtn("load", function()
        if readfile and isfile and isfile(path) then local c = readfile(path); textbox.Text = c or ""; updateCanvas(); lib:Notify("loaded: " .. path, 3) else lib:Notify("no file: " .. path, 3) end
    end)

    editors[ed] = true
    return ed
end

local function add_to_groupbox(gb)
    function gb:AddCodeEditor(info)
        info = info or {}
        local cont = self.Container
        local holder = Instance.new("Frame")
        holder.BackgroundTransparency = 1
        holder.Size = info.Size or UDim2.new(1, 0, 0, 300)
        holder.Parent = cont

        local ed = lib:CreateCodeEditor({ Parent = holder, Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 0), Default = info.Default or "", Title = info.Title or "code", Path = info.Path, ReadOnly = info.ReadOnly, Visible = info.Visible ~= false })

        self:Resize()
        table.insert(self.Elements, ed)

        if self.Resize then
            local old = self.Resize
            self.Resize = function(s, ...) old(s, ...); if ed and ed.Holder and ed.Holder.Parent then ed.Holder.Size = UDim2.new(1, 0, 0, s.Container.AbsoluteSize.Y) end end
        end

        return ed
    end
end

for _, t in pairs(lib.Tabs) do
    if t.Groupboxes then for _, g in pairs(t.Groupboxes) do add_to_groupbox(g) end end
    if t.Tabboxes then for _, tb in pairs(t.Tabboxes) do if tb.Tabs then for _, st in pairs(tb.Tabs) do add_to_groupbox(st) end end end end
end

local orig_unload = lib.Unload
function lib:Unload() for ed,_ in pairs(editors) do ed:Destroy() end orig_unload(self) end

return { Editors = editors }
