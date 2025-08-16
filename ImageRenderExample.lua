-- Example usage of Image and 3D Rendering Extension for Obsidian Library
-- Load this after loading the main Library.lua and ImageRenderExtension.lua

-- First load the main library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/testing2122/Obsidian/main/Library.lua"))()

-- Create a window first
local Window = Library:CreateWindow({
    Title = "Image & 3D Render Demo",
    Footer = "Obsidian Library with Image/3D Support",
    Size = UDim2.fromOffset(800, 600),
    AutoShow = true
})

-- Create tabs
local ImageTab = Window:AddTab("Image Display")
local ModelTab = Window:AddTab("3D Models")

-- Then load the image/3D extension (after window and tabs are created)
loadstring(game:HttpGet("https://raw.githubusercontent.com/testing2122/Obsidian/main/ImageRenderExtension.lua"))()

-- Now we can use the image and 3D features
-- Image Display Examples
local ImageGroup = ImageTab:AddLeftGroupbox("Image Examples")

-- Add a simple image display
local ImageDisplay1 = ImageGroup:AddImageDisplay({
    ImageUrl = "rbxassetid://6031075938", -- Example image ID
    Size = UDim2.new(1, 0, 0, 150),
    ScaleType = Enum.ScaleType.Fit,
    BackgroundColor = Color3.fromRGB(40, 40, 40),
    BackgroundTransparency = 0
})

-- Add controls for the image
ImageGroup:AddInput("ImageURL1", {
    Text = "Image URL/ID",
    Default = "6031075938",
    Placeholder = "Enter image ID or URL",
    Callback = function(Value)
        local imageId = tonumber(Value) and "rbxassetid://" .. Value or Value
        ImageDisplay1:SetImage(imageId)
    end
})

ImageGroup:AddSlider("ImageSize1", {
    Text = "Image Height",
    Default = 150,
    Min = 50,
    Max = 400,
    Rounding = 0,
    Callback = function(Value)
        ImageDisplay1:SetSize(UDim2.new(1, 0, 0, Value))
    end
})

ImageGroup:AddToggle("ImageVisible1", {
    Text = "Show Image",
    Default = true,
    Callback = function(Value)
        ImageDisplay1:SetVisible(Value)
    end
})

-- Second image with different settings
local ImageDisplay2 = ImageGroup:AddImageDisplay({
    ImageUrl = "rbxassetid://6031097225", -- Another example
    Size = UDim2.new(1, 0, 0, 100),
    ScaleType = Enum.ScaleType.Crop,
    BackgroundColor = Color3.fromRGB(60, 60, 60),
    BackgroundTransparency = 0.2
})

-- 3D Model Display Examples
local ModelGroup = ModelTab:AddLeftGroupbox("3D Model Examples")

-- Add a 3D model display
local ModelDisplay1 = ModelGroup:Add3DModelDisplay({
    ModelId = "16190426", -- Example model ID (Roblox character)
    Size = UDim2.new(1, 0, 0, 250),
    AutoRotate = true,
    RotationSpeed = 1,
    CameraDistance = 8,
    BackgroundColor = Color3.fromRGB(30, 30, 30),
    BackgroundTransparency = 0
})

-- Add controls for the 3D model
ModelGroup:AddInput("ModelID1", {
    Text = "Model ID",
    Default = "16190426",
    Placeholder = "Enter model ID",
    Callback = function(Value)
        if tonumber(Value) then
            ModelDisplay1:LoadModel(tonumber(Value))
        end
    end
})

ModelGroup:AddToggle("AutoRotate1", {
    Text = "Auto Rotate",
    Default = true,
    Callback = function(Value)
        ModelDisplay1:SetAutoRotate(Value)
    end
})

ModelGroup:AddSlider("RotationSpeed1", {
    Text = "Rotation Speed",
    Default = 1,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Callback = function(Value)
        ModelDisplay1:SetRotationSpeed(Value)
    end
})

ModelGroup:AddSlider("CameraDistance1", {
    Text = "Camera Distance",
    Default = 8,
    Min = 2,
    Max = 20,
    Rounding = 0,
    Callback = function(Value)
        ModelDisplay1:SetCameraDistance(Value)
    end
})

ModelGroup:AddSlider("ModelHeight1", {
    Text = "Display Height",
    Default = 250,
    Min = 100,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        ModelDisplay1:SetSize(UDim2.new(1, 0, 0, Value))
    end
})

-- Advanced controls
local AdvancedGroup = ModelTab:AddRightGroupbox("Advanced Controls")

-- Color picker for background
AdvancedGroup:AddColorPicker("ModelBG1", {
    Default = Color3.fromRGB(30, 30, 30),
    Title = "Background Color",
    Callback = function(Value)
        ModelDisplay1:SetBackgroundColor(Value)
    end
})

-- Transparency slider
AdvancedGroup:AddSlider("ModelTransparency1", {
    Text = "Background Transparency",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        ModelDisplay1:SetBackgroundTransparency(Value)
    end
})

-- Standalone image display (not in groupbox)
local StandaloneImage = Library:CreateImageDisplay({
    ImageUrl = "rbxassetid://6031075938",
    Size = UDim2.fromOffset(200, 200),
    Position = UDim2.fromOffset(50, 50),
    CornerRadius = 10,
    StrokeColor = Color3.fromRGB(255, 255, 255),
    StrokeThickness = 2,
    Visible = false -- Start hidden
})

-- Standalone 3D model display
local Standalone3D = Library:Create3DModelDisplay({
    ModelId = "16190426",
    Size = UDim2.fromOffset(300, 300),
    Position = UDim2.fromOffset(300, 50),
    CornerRadius = 15,
    StrokeColor = Color3.fromRGB(125, 85, 255),
    StrokeThickness = 3,
    AutoRotate = true,
    RotationSpeed = 0.5,
    CameraDistance = 10,
    Visible = false -- Start hidden
})

-- Controls for standalone displays
local StandaloneGroup = ImageTab:AddRightGroupbox("Standalone Displays")

StandaloneGroup:AddToggle("ShowStandaloneImage", {
    Text = "Show Standalone Image",
    Default = false,
    Callback = function(Value)
        StandaloneImage:SetVisible(Value)
    end
})

StandaloneGroup:AddToggle("ShowStandalone3D", {
    Text = "Show Standalone 3D Model",
    Default = false,
    Callback = function(Value)
        Standalone3D:SetVisible(Value)
    end
})

StandaloneGroup:AddButton("Fade In Image", function()
    StandaloneImage:SetVisible(true)
    StandaloneImage:FadeIn(1)
end)

StandaloneGroup:AddButton("Fade Out Image", function()
    StandaloneImage:FadeOut(1)
end)

-- Example of loading different model types
local ModelExamples = {
    ["Roblox Character"] = "16190426",
    ["Sword"] = "47433",
    ["Car"] = "1374148",
    ["Building"] = "1374149"
}

local ExampleGroup = ModelTab:AddRightGroupbox("Model Examples")

for name, id in pairs(ModelExamples) do
    ExampleGroup:AddButton(name, function()
        ModelDisplay1:LoadModel(tonumber(id))
    end)
end

-- Test different image scale types
local ScaleGroup = ImageTab:AddRightGroupbox("Scale Types")

local ScaleTypes = {
    "Fit",
    "Crop", 
    "Tile",
    "Stretch"
}

for _, scaleType in pairs(ScaleTypes) do
    ScaleGroup:AddButton("Set " .. scaleType, function()
        ImageDisplay1:SetScaleType(Enum.ScaleType[scaleType])
    end)
end

-- Cleanup when library unloads
Library:OnUnload(function()
    if StandaloneImage then
        StandaloneImage:Destroy()
    end
    if Standalone3D then
        Standalone3D:Destroy()
    end
end)

print("Image and 3D Rendering Demo loaded!")
print("Features:")
print("- Image displays with various scale types")
print("- 3D model rendering with auto-rotation")
print("- Customizable backgrounds and styling")
print("- Standalone and groupbox-integrated displays")
print("- Fade in/out animations for images")
print("- Real-time controls for all parameters")
print("")
print("Usage:")
print("1. Use the input boxes to change image URLs or model IDs")
print("2. Toggle auto-rotation and adjust speeds for 3D models")
print("3. Try the standalone displays with the toggle buttons")
print("4. Experiment with different scale types for images")