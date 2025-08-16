-- Image and 3D Rendering Extension for Obsidian Library
-- Add this to your main Library.lua file or load it separately

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Wait for Library to be available
local Library = getgenv().Library
if not Library then
    error("Library not found! Make sure to load the main Library.lua first.")
end

-- Image Display Functions
local ImageDisplays = {}

function Library:CreateImageDisplay(Info)
    Info = Info or {}
    local ImageUrl = Info.ImageUrl or ""
    local Size = Info.Size or UDim2.fromOffset(200, 200)
    local Position = Info.Position or UDim2.fromOffset(10, 10)
    local Parent = Info.Parent or self.ScreenGui
    local Transparency = Info.Transparency or 0
    local ScaleType = Info.ScaleType or Enum.ScaleType.Fit
    local Visible = Info.Visible ~= false
    
    local ImageFrame = Instance.new("Frame")
    ImageFrame.Size = Size
    ImageFrame.Position = Position
    ImageFrame.BackgroundTransparency = 1
    ImageFrame.Visible = Visible
    ImageFrame.Parent = Parent
    
    local ImageLabel = Instance.new("ImageLabel")
    ImageLabel.Size = UDim2.fromScale(1, 1)
    ImageLabel.Position = UDim2.fromScale(0, 0)
    ImageLabel.BackgroundTransparency = 1
    ImageLabel.Image = ImageUrl
    ImageLabel.ImageTransparency = Transparency
    ImageLabel.ScaleType = ScaleType
    ImageLabel.Parent = ImageFrame
    
    -- Add corner radius if specified
    if Info.CornerRadius then
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, Info.CornerRadius)
        Corner.Parent = ImageLabel
    end
    
    -- Add stroke if specified
    if Info.StrokeColor then
        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Info.StrokeColor
        Stroke.Thickness = Info.StrokeThickness or 1
        Stroke.Parent = ImageLabel
    end
    
    local ImageDisplay = {
        Frame = ImageFrame,
        ImageLabel = ImageLabel,
        Visible = Visible,
        Type = "ImageDisplay"
    }
    
    function ImageDisplay:SetImage(Url)
        ImageLabel.Image = Url
    end
    
    function ImageDisplay:SetSize(NewSize)
        ImageFrame.Size = NewSize
    end
    
    function ImageDisplay:SetPosition(NewPosition)
        ImageFrame.Position = NewPosition
    end
    
    function ImageDisplay:SetTransparency(NewTransparency)
        ImageLabel.ImageTransparency = NewTransparency
    end
    
    function ImageDisplay:SetVisible(IsVisible)
        self.Visible = IsVisible
        ImageFrame.Visible = IsVisible
    end
    
    function ImageDisplay:FadeIn(Duration)
        Duration = Duration or 0.5
        TweenService:Create(ImageLabel, TweenInfo.new(Duration), {
            ImageTransparency = 0
        }):Play()
    end
    
    function ImageDisplay:FadeOut(Duration)
        Duration = Duration or 0.5
        TweenService:Create(ImageLabel, TweenInfo.new(Duration), {
            ImageTransparency = 1
        }):Play()
    end
    
    function ImageDisplay:Destroy()
        ImageFrame:Destroy()
        ImageDisplays[self] = nil
    end
    
    ImageDisplays[ImageDisplay] = true
    return ImageDisplay
end

-- 3D Model Rendering Functions
local ModelDisplays = {}

function Library:Create3DModelDisplay(Info)
    Info = Info or {}
    local ModelId = Info.ModelId or ""
    local Size = Info.Size or UDim2.fromOffset(300, 300)
    local Position = Info.Position or UDim2.fromOffset(10, 10)
    local Parent = Info.Parent or self.ScreenGui
    local Visible = Info.Visible ~= false
    local CameraDistance = Info.CameraDistance or 10
    local RotationSpeed = Info.RotationSpeed or 1
    local AutoRotate = Info.AutoRotate ~= false
    
    -- Create ViewportFrame for 3D rendering
    local ViewportFrame = Instance.new("ViewportFrame")
    ViewportFrame.Size = Size
    ViewportFrame.Position = Position
    ViewportFrame.BackgroundColor3 = Info.BackgroundColor or Color3.fromRGB(25, 25, 25)
    ViewportFrame.BackgroundTransparency = Info.BackgroundTransparency or 0
    ViewportFrame.Visible = Visible
    ViewportFrame.Parent = Parent
    
    -- Add corner radius if specified
    if Info.CornerRadius then
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, Info.CornerRadius)
        Corner.Parent = ViewportFrame
    end
    
    -- Add stroke if specified
    if Info.StrokeColor then
        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Info.StrokeColor
        Stroke.Thickness = Info.StrokeThickness or 1
        Stroke.Parent = ViewportFrame
    end
    
    -- Create camera for viewport
    local Camera = Instance.new("Camera")
    ViewportFrame.CurrentCamera = Camera
    
    -- Model container
    local Model = nil
    local ModelConnection = nil
    
    local ModelDisplay = {
        ViewportFrame = ViewportFrame,
        Camera = Camera,
        Model = Model,
        Visible = Visible,
        AutoRotate = AutoRotate,
        RotationSpeed = RotationSpeed,
        CameraDistance = CameraDistance,
        Type = "3DModelDisplay"
    }
    
    function ModelDisplay:LoadModel(Id)
        if Model then
            Model:Destroy()
        end
        
        if ModelConnection then
            ModelConnection:Disconnect()
        end
        
        local success, result = pcall(function()
            if tonumber(Id) then
                return game:GetService("InsertService"):LoadAsset(Id)
            else
                -- Handle mesh/model from workspace or other sources
                return Id
            end
        end)
        
        if success and result then
            if typeof(result) == "Instance" and result:IsA("Model") then
                Model = result
            elseif typeof(result) == "Instance" and result.ClassName == "Accessory" then
                Model = result
            else
                -- Try to find the first model in the result
                local foundModel = result:FindFirstChildOfClass("Model")
                if foundModel then
                    Model = foundModel
                else
                    Model = result
                end
            end
            
            if Model then
                Model.Parent = ViewportFrame
                self:UpdateCamera()
                
                if AutoRotate then
                    self:StartAutoRotation()
                end
            end
        end
    end
    
    function ModelDisplay:UpdateCamera()
        if not Model then return end
        
        local cf, size = Model:GetBoundingBox()
        local maxExtent = math.max(size.X, size.Y, size.Z)
        local distance = maxExtent * CameraDistance / 10
        
        Camera.CFrame = CFrame.lookAt(
            cf.Position + Vector3.new(distance, distance/2, distance),
            cf.Position
        )
    end
    
    function ModelDisplay:StartAutoRotation()
        if ModelConnection then
            ModelConnection:Disconnect()
        end
        
        if not AutoRotate or not Model then return end
        
        local rotation = 0
        ModelConnection = RunService.Heartbeat:Connect(function(dt)
            if not Model or not Model.Parent then
                if ModelConnection then
                    ModelConnection:Disconnect()
                end
                return
            end
            
            rotation = rotation + (dt * RotationSpeed * 50)
            local cf, size = Model:GetBoundingBox()
            local maxExtent = math.max(size.X, size.Y, size.Z)
            local distance = maxExtent * CameraDistance / 10
            
            local angle = math.rad(rotation)
            local x = math.cos(angle) * distance
            local z = math.sin(angle) * distance
            
            Camera.CFrame = CFrame.lookAt(
                cf.Position + Vector3.new(x, distance/2, z),
                cf.Position
            )
        end)
    end
    
    function ModelDisplay:StopAutoRotation()
        AutoRotate = false
        if ModelConnection then
            ModelConnection:Disconnect()
            ModelConnection = nil
        end
    end
    
    function ModelDisplay:SetAutoRotate(Enabled)
        AutoRotate = Enabled
        if Enabled then
            self:StartAutoRotation()
        else
            self:StopAutoRotation()
        end
    end
    
    function ModelDisplay:SetRotationSpeed(Speed)
        RotationSpeed = Speed
    end
    
    function ModelDisplay:SetCameraDistance(Distance)
        CameraDistance = Distance
        self:UpdateCamera()
    end
    
    function ModelDisplay:SetSize(NewSize)
        ViewportFrame.Size = NewSize
    end
    
    function ModelDisplay:SetPosition(NewPosition)
        ViewportFrame.Position = NewPosition
    end
    
    function ModelDisplay:SetVisible(IsVisible)
        self.Visible = IsVisible
        ViewportFrame.Visible = IsVisible
    end
    
    function ModelDisplay:SetBackgroundColor(Color)
        ViewportFrame.BackgroundColor3 = Color
    end
    
    function ModelDisplay:SetBackgroundTransparency(Transparency)
        ViewportFrame.BackgroundTransparency = Transparency
    end
    
    function ModelDisplay:Destroy()
        if ModelConnection then
            ModelConnection:Disconnect()
        end
        if Model then
            Model:Destroy()
        end
        ViewportFrame:Destroy()
        ModelDisplays[self] = nil
    end
    
    -- Load initial model if provided
    if ModelId and ModelId ~= "" then
        ModelDisplay:LoadModel(ModelId)
    end
    
    ModelDisplays[ModelDisplay] = true
    return ModelDisplay
end

-- Function to add methods to existing groupboxes
local function AddImageDisplayToGroupbox(Groupbox)
    function Groupbox:AddImageDisplay(Info)
        Info = Info or {}
        local Container = self.Container
        
        local ImageUrl = Info.ImageUrl or ""
        local Size = Info.Size or UDim2.new(1, 0, 0, 200)
        local ScaleType = Info.ScaleType or Enum.ScaleType.Fit
        local Visible = Info.Visible ~= false
        
        local Holder = Instance.new("Frame")
        Holder.BackgroundTransparency = 1
        Holder.Size = Size
        Holder.Visible = Visible
        Holder.Parent = Container
        
        local ImageLabel = Instance.new("ImageLabel")
        ImageLabel.Size = UDim2.fromScale(1, 1)
        ImageLabel.Position = UDim2.fromScale(0, 0)
        ImageLabel.BackgroundColor3 = Info.BackgroundColor or Color3.fromRGB(25, 25, 25)
        ImageLabel.BackgroundTransparency = Info.BackgroundTransparency or 0
        ImageLabel.Image = ImageUrl
        ImageLabel.ScaleType = ScaleType
        ImageLabel.Parent = Holder
        
        -- Add corner radius
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, Library.CornerRadius or 4)
        Corner.Parent = ImageLabel
        
        -- Add stroke
        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Library.Scheme.OutlineColor
        Stroke.Parent = ImageLabel
        
        local ImageDisplay = {
            Holder = Holder,
            ImageLabel = ImageLabel,
            Visible = Visible,
            Type = "ImageDisplay"
        }
        
        function ImageDisplay:SetImage(Url)
            ImageLabel.Image = Url
        end
        
        function ImageDisplay:SetSize(NewSize)
            Holder.Size = NewSize
            self:Resize()
        end
        
        function ImageDisplay:SetVisible(IsVisible)
            self.Visible = IsVisible
            Holder.Visible = IsVisible
            self:Resize()
        end
        
        function ImageDisplay:SetScaleType(NewScaleType)
            ImageLabel.ScaleType = NewScaleType
        end
        
        function ImageDisplay:Resize()
            if self.Resize then
                self:Resize()
            end
        end
        
        self:Resize()
        table.insert(self.Elements, ImageDisplay)
        
        return ImageDisplay
    end
end

local function Add3DModelDisplayToGroupbox(Groupbox)
    function Groupbox:Add3DModelDisplay(Info)
        Info = Info or {}
        local Container = self.Container
        
        local ModelId = Info.ModelId or ""
        local Size = Info.Size or UDim2.new(1, 0, 0, 300)
        local Visible = Info.Visible ~= false
        local AutoRotate = Info.AutoRotate ~= false
        local RotationSpeed = Info.RotationSpeed or 1
        local CameraDistance = Info.CameraDistance or 10
        
        local Holder = Instance.new("Frame")
        Holder.BackgroundTransparency = 1
        Holder.Size = Size
        Holder.Visible = Visible
        Holder.Parent = Container
        
        -- Create ViewportFrame for 3D rendering
        local ViewportFrame = Instance.new("ViewportFrame")
        ViewportFrame.Size = UDim2.fromScale(1, 1)
        ViewportFrame.Position = UDim2.fromScale(0, 0)
        ViewportFrame.BackgroundColor3 = Info.BackgroundColor or Color3.fromRGB(25, 25, 25)
        ViewportFrame.BackgroundTransparency = Info.BackgroundTransparency or 0
        ViewportFrame.Parent = Holder
        
        -- Add corner radius
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, Library.CornerRadius or 4)
        Corner.Parent = ViewportFrame
        
        -- Add stroke
        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Library.Scheme.OutlineColor
        Stroke.Parent = ViewportFrame
        
        -- Create camera for viewport
        local Camera = Instance.new("Camera")
        ViewportFrame.CurrentCamera = Camera
        
        -- Model container
        local Model = nil
        local ModelConnection = nil
        
        local ModelDisplay = {
            Holder = Holder,
            ViewportFrame = ViewportFrame,
            Camera = Camera,
            Model = Model,
            Visible = Visible,
            AutoRotate = AutoRotate,
            RotationSpeed = RotationSpeed,
            CameraDistance = CameraDistance,
            Type = "3DModelDisplay"
        }
        
        function ModelDisplay:LoadModel(Id)
            if Model then
                Model:Destroy()
            end
            
            if ModelConnection then
                ModelConnection:Disconnect()
            end
            
            local success, result = pcall(function()
                if tonumber(Id) then
                    return game:GetService("InsertService"):LoadAsset(Id)
                else
                    return Id
                end
            end)
            
            if success and result then
                if typeof(result) == "Instance" and result:IsA("Model") then
                    Model = result
                elseif typeof(result) == "Instance" and result.ClassName == "Accessory" then
                    Model = result
                else
                    local foundModel = result:FindFirstChildOfClass("Model")
                    if foundModel then
                        Model = foundModel
                    else
                        Model = result
                    end
                end
                
                if Model then
                    Model.Parent = ViewportFrame
                    self:UpdateCamera()
                    
                    if AutoRotate then
                        self:StartAutoRotation()
                    end
                end
            end
        end
        
        function ModelDisplay:UpdateCamera()
            if not Model then return end
            
            local cf, size = Model:GetBoundingBox()
            local maxExtent = math.max(size.X, size.Y, size.Z)
            local distance = maxExtent * CameraDistance / 10
            
            Camera.CFrame = CFrame.lookAt(
                cf.Position + Vector3.new(distance, distance/2, distance),
                cf.Position
            )
        end
        
        function ModelDisplay:StartAutoRotation()
            if ModelConnection then
                ModelConnection:Disconnect()
            end
            
            if not AutoRotate or not Model then return end
            
            local rotation = 0
            ModelConnection = RunService.Heartbeat:Connect(function(dt)
                if not Model or not Model.Parent then
                    if ModelConnection then
                        ModelConnection:Disconnect()
                    end
                    return
                end
                
                rotation = rotation + (dt * RotationSpeed * 50)
                local cf, size = Model:GetBoundingBox()
                local maxExtent = math.max(size.X, size.Y, size.Z)
                local distance = maxExtent * CameraDistance / 10
                
                local angle = math.rad(rotation)
                local x = math.cos(angle) * distance
                local z = math.sin(angle) * distance
                
                Camera.CFrame = CFrame.lookAt(
                    cf.Position + Vector3.new(x, distance/2, z),
                    cf.Position
                )
            end)
        end
        
        function ModelDisplay:StopAutoRotation()
            AutoRotate = false
            if ModelConnection then
                ModelConnection:Disconnect()
                ModelConnection = nil
            end
        end
        
        function ModelDisplay:SetAutoRotate(Enabled)
            AutoRotate = Enabled
            if Enabled then
                self:StartAutoRotation()
            else
                self:StopAutoRotation()
            end
        end
        
        function ModelDisplay:SetRotationSpeed(Speed)
            RotationSpeed = Speed
        end
        
        function ModelDisplay:SetCameraDistance(Distance)
            CameraDistance = Distance
            self:UpdateCamera()
        end
        
        function ModelDisplay:SetSize(NewSize)
            Holder.Size = NewSize
            self:Resize()
        end
        
        function ModelDisplay:SetVisible(IsVisible)
            self.Visible = IsVisible
            Holder.Visible = IsVisible
            self:Resize()
        end
        
        function ModelDisplay:SetBackgroundColor(Color)
            ViewportFrame.BackgroundColor3 = Color
        end
        
        function ModelDisplay:SetBackgroundTransparency(Transparency)
            ViewportFrame.BackgroundTransparency = Transparency
        end
        
        function ModelDisplay:Resize()
            if self.Resize then
                self:Resize()
            end
        end
        
        -- Load initial model if provided
        if ModelId and ModelId ~= "" then
            ModelDisplay:LoadModel(ModelId)
        end
        
        self:Resize()
        table.insert(self.Elements, ModelDisplay)
        
        return ModelDisplay
    end
end

-- Add methods to all existing groupboxes
for _, Tab in pairs(Library.Tabs) do
    if Tab.Groupboxes then
        for _, Groupbox in pairs(Tab.Groupboxes) do
            AddImageDisplayToGroupbox(Groupbox)
            Add3DModelDisplayToGroupbox(Groupbox)
        end
    end
    
    if Tab.Tabboxes then
        for _, Tabbox in pairs(Tab.Tabboxes) do
            if Tabbox.Tabs then
                for _, SubTab in pairs(Tabbox.Tabs) do
                    AddImageDisplayToGroupbox(SubTab)
                    Add3DModelDisplayToGroupbox(SubTab)
                end
            end
        end
    end
end

-- Hook into future groupbox creation
local originalAddGroupbox = nil
for _, Tab in pairs(Library.Tabs) do
    if Tab.AddGroupbox then
        originalAddGroupbox = Tab.AddGroupbox
        break
    end
end

if originalAddGroupbox then
    -- Override AddGroupbox for all tabs
    for _, Tab in pairs(Library.Tabs) do
        if Tab.AddGroupbox then
            local original = Tab.AddGroupbox
            Tab.AddGroupbox = function(self, Info)
                local groupbox = original(self, Info)
                AddImageDisplayToGroupbox(groupbox)
                Add3DModelDisplayToGroupbox(groupbox)
                return groupbox
            end
        end
        
        if Tab.AddLeftGroupbox then
            local original = Tab.AddLeftGroupbox
            Tab.AddLeftGroupbox = function(self, Name, IconName)
                local groupbox = original(self, Name, IconName)
                AddImageDisplayToGroupbox(groupbox)
                Add3DModelDisplayToGroupbox(groupbox)
                return groupbox
            end
        end
        
        if Tab.AddRightGroupbox then
            local original = Tab.AddRightGroupbox
            Tab.AddRightGroupbox = function(self, Name, IconName)
                local groupbox = original(self, Name, IconName)
                AddImageDisplayToGroupbox(groupbox)
                Add3DModelDisplayToGroupbox(groupbox)
                return groupbox
            end
        end
    end
end

-- Cleanup function
function Library:CleanupImageAndModelDisplays()
    for display, _ in pairs(ImageDisplays) do
        display:Destroy()
    end
    
    for display, _ in pairs(ModelDisplays) do
        display:Destroy()
    end
end

-- Add cleanup to existing unload function
local originalUnload = Library.Unload
function Library:Unload()
    self:CleanupImageAndModelDisplays()
    originalUnload(self)
end

print("Image and 3D Rendering Extension loaded successfully!")

return {
    ImageDisplays = ImageDisplays,
    ModelDisplays = ModelDisplays
}