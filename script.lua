-- TradeHub Anti-AFK Script
-- Prevents being kicked for inactivity while maintaining a modern UI

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Variables to track our connections globally for proper cleanup
local GlobalConnections = {}

-- Check for existing GUIs
local function DestroyExistingGUI()
    print("TradeHub: Checking for existing GUI instances")
    
    -- Ensure we have access to CoreGui
    if not CoreGui then
        warn("TradeHub: CoreGui service not available")
        return
    end
    
    -- Find and destroy any existing TradeHub GUIs
    local destroyed = false
    
    -- Try in protected mode to prevent any errors from breaking execution
    local success, errorMsg = pcall(function()
        -- Look for direct children of CoreGui
        for _, child in pairs(CoreGui:GetChildren()) do
            if child and child:IsA("ScreenGui") and child.Name == "TradeHub" then
                -- Destroy the GUI
                child:Destroy()
                destroyed = true
                print("TradeHub: Destroyed existing GUI")
            end
        end
    end)
    
    if not success then
        warn("TradeHub: Error while destroying existing GUI - " .. tostring(errorMsg))
    end
    
    if destroyed then
        -- Give time for the destruction to complete
        task.wait(0.2)
        print("TradeHub: Cleanup completed")
    else
        print("TradeHub: No existing GUI found")
    end
end

-- Function to safely track a connection for later cleanup
local function TrackConnection(connection)
    if connection then
        table.insert(GlobalConnections, connection)
        return connection
    end
end

-- Destroy any existing TradeHub GUI before creating a new one
DestroyExistingGUI()

-- Variables
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local AntiAFK = false
local Dragging = false
local DragInput
local DragStart
local StartPosition
local IdleConnection = nil
local CurrentTab = "Changelog"
local Logs = {}
local KeybindSettings = {
    Minimize = Enum.KeyCode.RightShift,
    KillGUI = Enum.KeyCode.Backspace,
    ToggleAntiAFK = Enum.KeyCode.F
}
local IsMinimized = false
local IsChangingKeybind = nil
local KeybindConnection = nil
local Resizing = false
local ResizingDirection = nil
local ResizeStart = nil
local ResizeStartSize = nil
local MinSize = Vector2.new(500, 400)
local RolimonItems = {}
local RolimonLastFetch = 0 -- Track when we last fetched data
local ConfigFilename = "TradeHubConfig.json" -- For saving/loading configs

-- Colors (shadcn inspired)
local Colors = {
    Background = Color3.fromRGB(20, 20, 22),
    CardBackground = Color3.fromRGB(30, 30, 33),
    PrimaryText = Color3.fromRGB(242, 242, 242),
    SecondaryText = Color3.fromRGB(161, 161, 170),
    AccentColor = Color3.fromRGB(147, 51, 234),
    BorderColor = Color3.fromRGB(39, 39, 42),
    ToggleOff = Color3.fromRGB(113, 113, 122),
    ToggleOn = Color3.fromRGB(147, 51, 234),
    LoaderBackground = Color3.fromRGB(63, 63, 70),
    LoaderFill = Color3.fromRGB(147, 51, 234),
    SidebarBackground = Color3.fromRGB(16, 16, 18),
    TabActive = Color3.fromRGB(30, 30, 33),
    TabInactive = Color3.fromRGB(20, 20, 22),
    LogBackground = Color3.fromRGB(12, 12, 14),
    Black = Color3.fromRGB(0, 0, 0),
    White = Color3.fromRGB(255, 255, 255),
    Success = Color3.fromRGB(0, 200, 83),
    Warning = Color3.fromRGB(255, 190, 0),
    Error = Color3.fromRGB(255, 50, 50),
    Button = Color3.fromRGB(147, 51, 234),
    Profit = Color3.fromRGB(0, 200, 83),  -- Ensure these are defined
    Loss = Color3.fromRGB(255, 50, 50),   -- Ensure these are defined
    Equal = Color3.fromRGB(147, 51, 234), -- Ensure these are defined
}

-- Create UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TradeHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game.CoreGui

-- Main GUI (created early to ensure it exists)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Colors.CardBackground
MainFrame.BorderSizePixel = 0
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5) -- Set anchor point to center
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0) -- Position at exact center of screen
MainFrame.Size = UDim2.new(0, 500, 0, 400)
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

-- Loading Screen
local LoadingFrame = Instance.new("Frame")
LoadingFrame.Name = "LoadingScreen"
LoadingFrame.BackgroundTransparency = 1 -- Changed to transparent
LoadingFrame.BorderSizePixel = 0
LoadingFrame.Size = UDim2.new(1, 0, 1, 0)
LoadingFrame.ZIndex = 100
LoadingFrame.Parent = ScreenGui

local LoadingContainer = Instance.new("Frame")
LoadingContainer.Name = "LoadingContainer"
LoadingContainer.BackgroundColor3 = Colors.CardBackground
LoadingContainer.BorderSizePixel = 0
LoadingContainer.Size = UDim2.new(0, 300, 0, 200)
LoadingContainer.Position = UDim2.new(0.5, -150, 0.5, -100)
LoadingContainer.ZIndex = 101
LoadingContainer.Parent = LoadingFrame

local LogoLabel = Instance.new("TextLabel")
LogoLabel.Name = "Logo"
LogoLabel.BackgroundTransparency = 1
LogoLabel.Position = UDim2.new(0, 0, 0, 30)
LogoLabel.Size = UDim2.new(1, 0, 0, 40)
LogoLabel.Font = Enum.Font.GothamBold
LogoLabel.Text = "TradeHub"
LogoLabel.TextColor3 = Colors.PrimaryText
LogoLabel.TextSize = 28
LogoLabel.ZIndex = 102
LogoLabel.Parent = LoadingContainer

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "Status"
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 0, 0, 80)
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Loading..."
StatusLabel.TextColor3 = Colors.SecondaryText
StatusLabel.TextSize = 14
StatusLabel.ZIndex = 102
StatusLabel.Parent = LoadingContainer

local ProgressBackground = Instance.new("Frame")
ProgressBackground.Name = "ProgressBackground"
ProgressBackground.BackgroundColor3 = Colors.LoaderBackground
ProgressBackground.BorderSizePixel = 0
ProgressBackground.Position = UDim2.new(0.1, 0, 0, 120)
ProgressBackground.Size = UDim2.new(0.8, 0, 0, 10)
ProgressBackground.ZIndex = 102
ProgressBackground.Parent = LoadingContainer

local ProgressBar = Instance.new("Frame")
ProgressBar.Name = "ProgressBar"
ProgressBar.BackgroundColor3 = Colors.LoaderFill
ProgressBar.BorderSizePixel = 0
ProgressBar.Size = UDim2.new(0, 0, 1, 0)
ProgressBar.ZIndex = 103
ProgressBar.Parent = ProgressBackground

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Name = "ProgressLabel"
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Position = UDim2.new(0, 0, 0, 140)
ProgressLabel.Size = UDim2.new(1, 0, 0, 20)
ProgressLabel.Font = Enum.Font.Gotham
ProgressLabel.Text = "0%"
ProgressLabel.TextColor3 = Colors.SecondaryText
ProgressLabel.TextSize = 14
ProgressLabel.ZIndex = 102
ProgressLabel.Parent = LoadingContainer

-- Resize handles (8 handles: corners + edges)
local ResizeHandles = {}

local function CreateResizeHandle(name, position, size)
    local handle = Instance.new("Frame")
    handle.Name = name
    handle.BackgroundColor3 = Colors.AccentColor
    handle.BackgroundTransparency = 1 -- Invisible but clickable
    handle.Position = position
    handle.Size = size
    handle.Parent = MainFrame
    
    -- Add to handles table
    ResizeHandles[name] = handle
    
    return handle
end

-- Create the 8 resize handles
CreateResizeHandle("TopLeft", UDim2.new(0, 0, 0, 30), UDim2.new(0, 10, 0, 10))
CreateResizeHandle("TopRight", UDim2.new(1, -10, 0, 30), UDim2.new(0, 10, 0, 10))
CreateResizeHandle("BottomLeft", UDim2.new(0, 0, 1, -10), UDim2.new(0, 10, 0, 10))
CreateResizeHandle("BottomRight", UDim2.new(1, -10, 1, -10), UDim2.new(0, 10, 0, 10))
CreateResizeHandle("Left", UDim2.new(0, 0, 0, 40), UDim2.new(0, 5, 1, -50))
CreateResizeHandle("Right", UDim2.new(1, -5, 0, 40), UDim2.new(0, 5, 1, -50))
CreateResizeHandle("Top", UDim2.new(0, 10, 0, 30), UDim2.new(1, -20, 0, 5))
CreateResizeHandle("Bottom", UDim2.new(0, 10, 1, -5), UDim2.new(1, -20, 0, 5))

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.BackgroundColor3 = Colors.Background
TitleBar.BorderSizePixel = 0
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.BackgroundTransparency = 1
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.Size = UDim2.new(0, 200, 1, 0)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "TradeHub Anti-AFK"
TitleLabel.TextColor3 = Colors.PrimaryText
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -60, 0, 0)
MinimizeButton.Size = UDim2.new(0, 30, 1, 0)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Colors.SecondaryText
MinimizeButton.TextSize = 18
MinimizeButton.Parent = TitleBar

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.BackgroundTransparency = 1
CloseButton.Position = UDim2.new(1, -30, 0, 0)
CloseButton.Size = UDim2.new(0, 30, 1, 0)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Colors.SecondaryText
CloseButton.TextSize = 14
CloseButton.Parent = TitleBar

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.BackgroundColor3 = Colors.SidebarBackground
Sidebar.BorderSizePixel = 0
Sidebar.Position = UDim2.new(0, 0, 0, 30)
Sidebar.Size = UDim2.new(0, 80, 1, -30)
Sidebar.Parent = MainFrame

-- Tab Containers
local HomeContainer = Instance.new("Frame")
HomeContainer.Name = "HomeContainer"
HomeContainer.BackgroundTransparency = 1
HomeContainer.Position = UDim2.new(0, 80, 0, 30)
HomeContainer.Size = UDim2.new(1, -80, 1, -30)
HomeContainer.Visible = true
HomeContainer.Parent = MainFrame

local SettingsContainer = Instance.new("Frame")
SettingsContainer.Name = "SettingsContainer"
SettingsContainer.BackgroundTransparency = 1
SettingsContainer.Position = UDim2.new(0, 80, 0, 30)
SettingsContainer.Size = UDim2.new(1, -80, 1, -30)
SettingsContainer.Visible = false
SettingsContainer.Parent = MainFrame

local LogContainer = Instance.new("Frame")
LogContainer.Name = "LogContainer"
LogContainer.BackgroundTransparency = 1
LogContainer.Position = UDim2.new(0, 80, 0, 30)
LogContainer.Size = UDim2.new(1, -80, 1, -30)
LogContainer.Visible = false
LogContainer.Parent = MainFrame

-- Changelog Container
local ChangelogContainer = Instance.new("Frame")
ChangelogContainer.Name = "ChangelogContainer"
ChangelogContainer.BackgroundTransparency = 1
ChangelogContainer.Position = UDim2.new(0, 80, 0, 30)
ChangelogContainer.Size = UDim2.new(1, -80, 1, -30)
ChangelogContainer.Visible = true -- Make visible by default
ChangelogContainer.Parent = MainFrame

-- Changelog Title
local ChangelogTitle = Instance.new("TextLabel")
ChangelogTitle.Name = "ChangelogTitle"
ChangelogTitle.BackgroundTransparency = 1
ChangelogTitle.Position = UDim2.new(0, 10, 0, 10)
ChangelogTitle.Size = UDim2.new(1, -20, 0, 30)
ChangelogTitle.Font = Enum.Font.GothamBold
ChangelogTitle.Text = "TradeHub Changelog"
ChangelogTitle.TextColor3 = Colors.PrimaryText
ChangelogTitle.TextSize = 18
ChangelogTitle.TextXAlignment = Enum.TextXAlignment.Left
ChangelogTitle.Parent = ChangelogContainer

-- Config Container
local ConfigContainer = Instance.new("Frame")
ConfigContainer.Name = "ConfigContainer"
ConfigContainer.BackgroundTransparency = 1
ConfigContainer.Position = UDim2.new(0, 80, 0, 30)
ConfigContainer.Size = UDim2.new(1, -80, 1, -30)
ConfigContainer.Visible = false
ConfigContainer.Parent = MainFrame

-- Config Title
local ConfigTitle = Instance.new("TextLabel")
ConfigTitle.Name = "ConfigTitle"
ConfigTitle.BackgroundTransparency = 1
ConfigTitle.Position = UDim2.new(0, 10, 0, 10)
ConfigTitle.Size = UDim2.new(1, -20, 0, 30)
ConfigTitle.Font = Enum.Font.GothamBold
ConfigTitle.Text = "Configuration"
ConfigTitle.TextColor3 = Colors.PrimaryText
ConfigTitle.TextSize = 18
ConfigTitle.TextXAlignment = Enum.TextXAlignment.Left
ConfigTitle.Parent = ConfigContainer

-- Config Container Box
local ConfigBox = Instance.new("Frame")
ConfigBox.Name = "ConfigBox"
ConfigBox.BackgroundColor3 = Colors.CardBackground
ConfigBox.BorderSizePixel = 0
ConfigBox.Position = UDim2.new(0, 10, 0, 50)
ConfigBox.Size = UDim2.new(1, -20, 0, 200)
ConfigBox.Parent = ConfigContainer

-- Config Description
local ConfigDescription = Instance.new("TextLabel")
ConfigDescription.Name = "ConfigDescription"
ConfigDescription.BackgroundTransparency = 1
ConfigDescription.Position = UDim2.new(0, 10, 0, 10)
ConfigDescription.Size = UDim2.new(1, -20, 0, 60)
ConfigDescription.Font = Enum.Font.Gotham
ConfigDescription.Text = "Save and load your TradeHub configurations, including keybinds and UI settings. This allows you to keep your preferences between sessions."
ConfigDescription.TextColor3 = Colors.SecondaryText
ConfigDescription.TextSize = 14
ConfigDescription.TextWrapped = true
ConfigDescription.TextXAlignment = Enum.TextXAlignment.Left
ConfigDescription.Parent = ConfigBox

-- Save Config Button
local SaveConfigButton = Instance.new("TextButton")
SaveConfigButton.Name = "SaveConfigButton"
SaveConfigButton.BackgroundColor3 = Colors.AccentColor
SaveConfigButton.BorderSizePixel = 0
SaveConfigButton.Position = UDim2.new(0, 10, 0, 80)
SaveConfigButton.Size = UDim2.new(0.5, -15, 0, 40)
SaveConfigButton.Font = Enum.Font.GothamSemibold
SaveConfigButton.Text = "Save Configuration"
SaveConfigButton.TextColor3 = Colors.PrimaryText
SaveConfigButton.TextSize = 14
SaveConfigButton.Parent = ConfigBox

-- Load Config Button
local LoadConfigButton = Instance.new("TextButton")
LoadConfigButton.Name = "LoadConfigButton"
LoadConfigButton.BackgroundColor3 = Colors.AccentColor
LoadConfigButton.BorderSizePixel = 0
LoadConfigButton.Position = UDim2.new(0.5, 5, 0, 80)
LoadConfigButton.Size = UDim2.new(0.5, -15, 0, 40)
LoadConfigButton.Font = Enum.Font.GothamSemibold
LoadConfigButton.Text = "Load Configuration"
LoadConfigButton.TextColor3 = Colors.PrimaryText
LoadConfigButton.TextSize = 14
LoadConfigButton.Parent = ConfigBox

-- Config Status
local ConfigStatus = Instance.new("TextLabel")
ConfigStatus.Name = "ConfigStatus"
ConfigStatus.BackgroundTransparency = 1
ConfigStatus.Position = UDim2.new(0, 10, 0, 130)
ConfigStatus.Size = UDim2.new(1, -20, 0, 60)
ConfigStatus.Font = Enum.Font.Gotham
ConfigStatus.Text = "Status: Ready"
ConfigStatus.TextColor3 = Colors.SecondaryText
ConfigStatus.TextSize = 14
ConfigStatus.TextWrapped = true
ConfigStatus.TextXAlignment = Enum.TextXAlignment.Left
ConfigStatus.Parent = ConfigBox

-- Reset Config Button
local ResetConfigButton
pcall(function()
    ResetConfigButton = Instance.new("TextButton")
    ResetConfigButton.Name = "ResetConfigButton"
    ResetConfigButton.BackgroundColor3 = Colors.Error
    ResetConfigButton.BorderSizePixel = 0
    ResetConfigButton.Position = UDim2.new(0.25, 0, 0, 160)
    ResetConfigButton.Size = UDim2.new(0.5, 0, 0, 30)
    ResetConfigButton.Font = Enum.Font.GothamSemibold
    ResetConfigButton.Text = "Reset to Default"
    ResetConfigButton.TextColor3 = Colors.PrimaryText
    ResetConfigButton.TextSize = 14
    ResetConfigButton.Parent = ConfigBox
end)

-- Home Tab Button
local HomeTab = Instance.new("TextButton")
HomeTab.Name = "HomeTab"
HomeTab.BackgroundColor3 = Colors.TabActive
HomeTab.BorderSizePixel = 0
HomeTab.Position = UDim2.new(0, 0, 0, 10)
HomeTab.Size = UDim2.new(1, 0, 0, 40)
HomeTab.Font = Enum.Font.GothamSemibold
HomeTab.Text = "Home"
HomeTab.TextColor3 = Colors.PrimaryText
HomeTab.TextSize = 14
HomeTab.Parent = Sidebar

-- Settings Tab Button
local SettingsTab = Instance.new("TextButton")
SettingsTab.Name = "SettingsTab"
SettingsTab.BackgroundColor3 = Colors.TabInactive
SettingsTab.BorderSizePixel = 0
SettingsTab.Position = UDim2.new(0, 0, 0, 50)
SettingsTab.Size = UDim2.new(1, 0, 0, 40)
SettingsTab.Font = Enum.Font.GothamSemibold
SettingsTab.Text = "Settings"
SettingsTab.TextColor3 = Colors.SecondaryText
SettingsTab.TextSize = 14
SettingsTab.Parent = Sidebar

-- Log Tab Button
local LogTab = Instance.new("TextButton")
LogTab.Name = "LogTab"
LogTab.BackgroundColor3 = Colors.TabInactive
LogTab.BorderSizePixel = 0
LogTab.Position = UDim2.new(0, 0, 0, 90)
LogTab.Size = UDim2.new(1, 0, 0, 40)
LogTab.Font = Enum.Font.GothamSemibold
LogTab.Text = "Log"
LogTab.TextColor3 = Colors.SecondaryText
LogTab.TextSize = 14
LogTab.Parent = Sidebar

-- Changelog Tab Button (first position)
local ChangelogTab = Instance.new("TextButton")
ChangelogTab.Name = "ChangelogTab"
ChangelogTab.BackgroundColor3 = Colors.TabActive -- Active by default
ChangelogTab.BorderSizePixel = 0
ChangelogTab.Position = UDim2.new(0, 0, 0, 10)
ChangelogTab.Size = UDim2.new(1, 0, 0, 40)
ChangelogTab.Font = Enum.Font.GothamSemibold
ChangelogTab.Text = "Changelog"
ChangelogTab.TextColor3 = Colors.PrimaryText
ChangelogTab.TextSize = 14
ChangelogTab.Parent = Sidebar

-- Home Tab Button (adjusted position)
local HomeTab = Instance.new("TextButton")
HomeTab.Name = "HomeTab"
HomeTab.BackgroundColor3 = Colors.TabInactive -- Not active by default
HomeTab.BorderSizePixel = 0
HomeTab.Position = UDim2.new(0, 0, 0, 50) -- Position moved down
HomeTab.Size = UDim2.new(1, 0, 0, 40)
HomeTab.Font = Enum.Font.GothamSemibold
HomeTab.Text = "Home"
HomeTab.TextColor3 = Colors.SecondaryText
HomeTab.TextSize = 14
HomeTab.Parent = Sidebar

-- Settings Tab Button (adjusted position)
local SettingsTab = Instance.new("TextButton")
SettingsTab.Name = "SettingsTab"
SettingsTab.BackgroundColor3 = Colors.TabInactive
SettingsTab.BorderSizePixel = 0
SettingsTab.Position = UDim2.new(0, 0, 0, 90) -- Position moved down
SettingsTab.Size = UDim2.new(1, 0, 0, 40)
SettingsTab.Font = Enum.Font.GothamSemibold
SettingsTab.Text = "Settings"
SettingsTab.TextColor3 = Colors.SecondaryText
SettingsTab.TextSize = 14
SettingsTab.Parent = Sidebar

-- Log Tab Button (adjusted position)
local LogTab = Instance.new("TextButton")
LogTab.Name = "LogTab"
LogTab.BackgroundColor3 = Colors.TabInactive
LogTab.BorderSizePixel = 0
LogTab.Position = UDim2.new(0, 0, 0, 130) -- Position moved down
LogTab.Size = UDim2.new(1, 0, 0, 40)
LogTab.Font = Enum.Font.GothamSemibold
LogTab.Text = "Log"
LogTab.TextColor3 = Colors.SecondaryText
LogTab.TextSize = 14
LogTab.Parent = Sidebar

-- Config Tab Button
local ConfigTab
local success, err = pcall(function()
    ConfigTab = Instance.new("TextButton")
    ConfigTab.Name = "ConfigTab"
    ConfigTab.BackgroundColor3 = Colors.TabInactive
    ConfigTab.BorderSizePixel = 0
    ConfigTab.Position = UDim2.new(0, 0, 0, 170) -- Position moved down
    ConfigTab.Size = UDim2.new(1, 0, 0, 40)
    ConfigTab.Font = Enum.Font.GothamSemibold
    ConfigTab.Text = "Config"
    ConfigTab.TextColor3 = Colors.SecondaryText
    ConfigTab.TextSize = 14
    ConfigTab.Parent = Sidebar
end)

if not success then
    print("TradeHub Error creating ConfigTab: " .. tostring(err))
    -- Create a fallback version with default properties
    ConfigTab = Instance.new("TextButton")
    ConfigTab.Name = "ConfigTab"
    ConfigTab.Text = "Config"
    ConfigTab.Parent = Sidebar
end

-- Info Container (Home Tab)
local InfoContainer = Instance.new("Frame")
InfoContainer.Name = "InfoContainer"
InfoContainer.BackgroundColor3 = Colors.CardBackground
InfoContainer.BorderSizePixel = 0
InfoContainer.Position = UDim2.new(0, 10, 0, 80)
InfoContainer.Size = UDim2.new(1, -20, 0, 180)
InfoContainer.Parent = HomeContainer

-- Status Container (Home Tab)
local StatusContainer = Instance.new("Frame")
StatusContainer.Name = "StatusContainer"
StatusContainer.BackgroundColor3 = Colors.CardBackground
StatusContainer.BorderSizePixel = 0
StatusContainer.Position = UDim2.new(0, 10, 0, 10)
StatusContainer.Size = UDim2.new(1, -20, 0, 60)
StatusContainer.Parent = HomeContainer

local StatusTitle = Instance.new("TextLabel")
StatusTitle.Name = "StatusTitle"
StatusTitle.BackgroundTransparency = 1
StatusTitle.Position = UDim2.new(0, 10, 0, 10)
StatusTitle.Size = UDim2.new(0.5, 0, 0, 20)
StatusTitle.Font = Enum.Font.GothamBold
StatusTitle.Text = "Anti-AFK Status"
StatusTitle.TextColor3 = Colors.PrimaryText
StatusTitle.TextSize = 14
StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
StatusTitle.Parent = StatusContainer

local StatusValue = Instance.new("TextLabel")
StatusValue.Name = "StatusValue"
StatusValue.BackgroundTransparency = 1
StatusValue.Position = UDim2.new(0, 10, 0, 30)
StatusValue.Size = UDim2.new(0.5, 0, 0, 20)
StatusValue.Font = Enum.Font.Gotham
StatusValue.Text = "Inactive"
StatusValue.TextColor3 = Colors.SecondaryText
StatusValue.TextSize = 12
StatusValue.TextXAlignment = Enum.TextXAlignment.Left
StatusValue.Parent = StatusContainer

local ToggleContainer = Instance.new("Frame")
ToggleContainer.Name = "ToggleContainer"
ToggleContainer.BackgroundTransparency = 1
ToggleContainer.Position = UDim2.new(0.7, 0, 0, 15)
ToggleContainer.Size = UDim2.new(0.3, -10, 0, 30)
ToggleContainer.Parent = StatusContainer

local ToggleBackground = Instance.new("Frame")
ToggleBackground.Name = "ToggleBackground"
ToggleBackground.BackgroundColor3 = Colors.ToggleOff
ToggleBackground.BorderSizePixel = 0
ToggleBackground.Position = UDim2.new(0, 0, 0.5, -10)
ToggleBackground.Size = UDim2.new(0, 44, 0, 20)
ToggleBackground.Parent = ToggleContainer

local ToggleButton = Instance.new("Frame")
ToggleButton.Name = "ToggleButton"
ToggleButton.BackgroundColor3 = Colors.White
ToggleButton.BorderSizePixel = 0
ToggleButton.Position = UDim2.new(0, 2, 0, 2)
ToggleButton.Size = UDim2.new(0, 16, 0, 16)
ToggleButton.Parent = ToggleBackground

local InfoTitle = Instance.new("TextLabel")
InfoTitle.Name = "InfoTitle"
InfoTitle.BackgroundTransparency = 1
InfoTitle.Position = UDim2.new(0, 10, 0, 10)
InfoTitle.Size = UDim2.new(1, -20, 0, 20)
InfoTitle.Font = Enum.Font.GothamBold
InfoTitle.Text = "Information"
InfoTitle.TextColor3 = Colors.PrimaryText
InfoTitle.TextSize = 14
InfoTitle.TextXAlignment = Enum.TextXAlignment.Left
InfoTitle.Parent = InfoContainer

local InfoText = Instance.new("TextLabel")
InfoText.Name = "InfoText"
InfoText.BackgroundTransparency = 1
InfoText.Position = UDim2.new(0, 10, 0, 30)
InfoText.Size = UDim2.new(1, -20, 0, 40)
InfoText.Font = Enum.Font.Gotham
InfoText.Text = "Anti-AFK will prevent you from being disconnected due to inactivity. Toggle the switch to activate."
InfoText.TextColor3 = Colors.SecondaryText
InfoText.TextSize = 12
InfoText.TextWrapped = true
InfoText.TextXAlignment = Enum.TextXAlignment.Left
InfoText.TextYAlignment = Enum.TextYAlignment.Top
InfoText.Parent = InfoContainer

local KeybindsInfo = Instance.new("TextLabel")
KeybindsInfo.Name = "KeybindsInfo"
KeybindsInfo.BackgroundTransparency = 1
KeybindsInfo.Position = UDim2.new(0, 10, 0, 80)
KeybindsInfo.Size = UDim2.new(1, -20, 0, 100)
KeybindsInfo.Font = Enum.Font.Gotham
KeybindsInfo.Text = "Navigate using the sidebar tabs. You can configure keybinds in the Settings tab."
KeybindsInfo.TextColor3 = Colors.SecondaryText
KeybindsInfo.TextSize = 12
KeybindsInfo.TextWrapped = true
KeybindsInfo.TextXAlignment = Enum.TextXAlignment.Left
KeybindsInfo.TextYAlignment = Enum.TextYAlignment.Top
KeybindsInfo.Parent = InfoContainer

-- Settings Container
local SettingsTitle = Instance.new("TextLabel")
SettingsTitle.Name = "SettingsTitle"
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.Position = UDim2.new(0, 10, 0, 10)
SettingsTitle.Size = UDim2.new(1, -20, 0, 30)
SettingsTitle.Font = Enum.Font.GothamBold
SettingsTitle.Text = "Keybind Settings"
SettingsTitle.TextColor3 = Colors.PrimaryText
SettingsTitle.TextSize = 18
SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
SettingsTitle.Parent = SettingsContainer    

-- Add keybind info text
local KeybindInfo = Instance.new("TextLabel")
KeybindInfo.Name = "KeybindInfo"
KeybindInfo.BackgroundTransparency = 1
KeybindInfo.Position = UDim2.new(0, 10, 0, 200)
KeybindInfo.Size = UDim2.new(1, -20, 0, 40)
KeybindInfo.Font = Enum.Font.Gotham
KeybindInfo.Text = "Note: Keybinds will not activate when typing in text boxes or when the window is out of focus."
KeybindInfo.TextColor3 = Colors.SecondaryText
KeybindInfo.TextSize = 12
KeybindInfo.TextWrapped = true
KeybindInfo.TextXAlignment = Enum.TextXAlignment.Left
KeybindInfo.Parent = SettingsContainer

-- Create keybind settings
local function CreateKeybindSetting(title, keybindType, yPos)
    local Container = Instance.new("Frame")
    Container.Name = title .. "Container"
    Container.BackgroundColor3 = Colors.CardBackground
    Container.BorderSizePixel = 0
    Container.Position = UDim2.new(0, 10, 0, yPos)
    Container.Size = UDim2.new(1, -20, 0, 40)
    Container.Parent = SettingsContainer
    
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.Size = UDim2.new(0.6, 0, 1, 0)
    Title.Font = Enum.Font.GothamSemibold
    Title.Text = title
    Title.TextColor3 = Colors.PrimaryText
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Container
    
    local KeybindButton = Instance.new("TextButton")
    KeybindButton.Name = "KeybindButton"
    KeybindButton.BackgroundColor3 = Colors.Background
    KeybindButton.BorderSizePixel = 0
    KeybindButton.Position = UDim2.new(0.7, 0, 0.5, -15)
    KeybindButton.Size = UDim2.new(0.3, -10, 0, 30)
    KeybindButton.Font = Enum.Font.Code
    KeybindButton.Text = KeybindSettings[keybindType].Name
    KeybindButton.TextColor3 = Colors.PrimaryText
    KeybindButton.TextSize = 12
    KeybindButton.Parent = Container
    
    -- Configure keybind button click
    KeybindButton.MouseButton1Click:Connect(function()
        IsChangingKeybind = keybindType
        KeybindButton.Text = "Press key..."
        KeybindButton.TextColor3 = Colors.AccentColor
    end)
    
    return KeybindButton
end

local MinimizeKeybindButton = CreateKeybindSetting("Minimize GUI", "Minimize", 50)
local KillGUIKeybindButton = CreateKeybindSetting("Kill GUI", "KillGUI", 100) 
local ToggleAFKKeybindButton = CreateKeybindSetting("Toggle Anti-AFK", "ToggleAntiAFK", 150)

-- Log container
local LogTitle = Instance.new("TextLabel")
LogTitle.Name = "LogTitle"
LogTitle.BackgroundTransparency = 1
LogTitle.Position = UDim2.new(0, 10, 0, 10)
LogTitle.Size = UDim2.new(1, -20, 0, 30)
LogTitle.Font = Enum.Font.GothamBold
LogTitle.Text = "Activity Log"
LogTitle.TextColor3 = Colors.PrimaryText
LogTitle.TextSize = 18
LogTitle.TextXAlignment = Enum.TextXAlignment.Left
LogTitle.Parent = LogContainer

local LogBox = Instance.new("Frame")
LogBox.Name = "LogBox"
LogBox.BackgroundColor3 = Colors.LogBackground
LogBox.BorderSizePixel = 0
LogBox.Position = UDim2.new(0, 10, 0, 50)
LogBox.Size = UDim2.new(1, -20, 1, -60)
LogBox.Parent = LogContainer

local LogScrollFrame = Instance.new("ScrollingFrame")
LogScrollFrame.Name = "LogScrollFrame"
LogScrollFrame.BackgroundTransparency = 1
LogScrollFrame.Position = UDim2.new(0, 10, 0, 10)
LogScrollFrame.Size = UDim2.new(1, -20, 1, -20)
LogScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScrollFrame.ScrollBarThickness = 4
LogScrollFrame.ScrollBarImageColor3 = Colors.ToggleOff
LogScrollFrame.BorderSizePixel = 0
LogScrollFrame.Parent = LogBox

-- Minimized GUI
local MinimizedFrame = Instance.new("Frame")
MinimizedFrame.Name = "MinimizedFrame"
MinimizedFrame.BackgroundColor3 = Colors.CardBackground
MinimizedFrame.BorderSizePixel = 0
MinimizedFrame.Position = UDim2.new(0.95, 0, 0.05, 0) -- Position in top-right corner
MinimizedFrame.AnchorPoint = Vector2.new(1, 0) -- Anchor to top-right
MinimizedFrame.Size = UDim2.new(0, 110, 0, 30)
MinimizedFrame.Visible = false
MinimizedFrame.Parent = ScreenGui

local MinimizedLabel = Instance.new("TextLabel")
MinimizedLabel.Name = "MinimizedLabel"
MinimizedLabel.BackgroundTransparency = 1
MinimizedLabel.Position = UDim2.new(0, 10, 0, 0)
MinimizedLabel.Size = UDim2.new(0.6, 0, 1, 0)
MinimizedLabel.Font = Enum.Font.GothamSemibold
MinimizedLabel.Text = "TradeHub"
MinimizedLabel.TextColor3 = Colors.PrimaryText
MinimizedLabel.TextSize = 12
MinimizedLabel.TextXAlignment = Enum.TextXAlignment.Left
MinimizedLabel.Parent = MinimizedFrame

local RestoreButton = Instance.new("TextButton")
RestoreButton.Name = "RestoreButton"
RestoreButton.BackgroundTransparency = 1
RestoreButton.Position = UDim2.new(0.6, 0, 0, 0)
RestoreButton.Size = UDim2.new(0.4, 0, 1, 0)
RestoreButton.Font = Enum.Font.GothamBold
RestoreButton.Text = "+"
RestoreButton.TextColor3 = Colors.SecondaryText
RestoreButton.TextSize = 14
RestoreButton.Parent = MinimizedFrame

-- Function declarations (need to be before they're used)
local AddLog
local UpdateLogDisplay
local UpdateToggle
local SimulateActivity
local ConnectAntiAFK
local StartAntiAFK
local StopAntiAFK
local ToggleAntiAFK
local SwitchTab
local ToggleMinimize
local UpdateKeybindButton
local SetupKeybindListener
local ShowLoader
local Update
local CleanupAndDestroy
local FetchRolimons
local FindItemByName
local SearchItems
local OpenItemSearch
local CloseItemSearch
local PopulateSearchResults
local SelectItemFromSearch
local UpdateTradeItem
local ClearTradeItem
local UpdateTradeUI
local HandleResize
local SaveConfig
local LoadConfig
local ResetConfig

-- UpdateLogDisplay function definition
function UpdateLogDisplay()
    -- Clear existing logs
    for _, child in pairs(LogScrollFrame:GetChildren()) do
        child:Destroy()
    end
    
    -- Add logs to scroll frame
    local yPos = 0
    for i, log in ipairs(Logs) do
        local LogEntry = Instance.new("TextLabel")
        LogEntry.Name = "LogEntry_" .. i
        LogEntry.BackgroundTransparency = 1
        LogEntry.Position = UDim2.new(0, 0, 0, yPos)
        LogEntry.Size = UDim2.new(1, 0, 0, 20)
        LogEntry.Font = Enum.Font.Code
        LogEntry.Text = "[" .. log.timestamp .. "] " .. log.message
        LogEntry.TextColor3 = log.color
        LogEntry.TextSize = 12
        LogEntry.TextXAlignment = Enum.TextXAlignment.Left
        LogEntry.Parent = LogScrollFrame
        
        yPos = yPos + 20
    end
    
    -- Update canvas size
    LogScrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos)
    
    -- Auto scroll to bottom
    LogScrollFrame.CanvasPosition = Vector2.new(0, yPos)
end

-- AddLog function definition
function AddLog(message, color)
    table.insert(Logs, {message = message, color = color or Colors.PrimaryText, timestamp = os.date("%H:%M:%S")})
    UpdateLogDisplay()
end

-- UpdateToggle function definition
function UpdateToggle()
    local togglePos = AntiAFK and UDim2.new(0, 26, 0, 2) or UDim2.new(0, 2, 0, 2)
    local toggleColor = AntiAFK and Colors.ToggleOn or Colors.ToggleOff
    local statusText = AntiAFK and "Active" or "Inactive"
    local statusColor = AntiAFK and Colors.Success or Colors.SecondaryText
    
    TweenService:Create(ToggleButton, TweenInfo.new(0.2), {Position = togglePos}):Play()
    TweenService:Create(ToggleBackground, TweenInfo.new(0.2), {BackgroundColor3 = toggleColor}):Play()
    
    StatusValue.Text = statusText
    StatusValue.TextColor3 = statusColor
end

-- SimulateActivity function definition
function SimulateActivity()
    local VirtualUser = game:GetService("VirtualUser")
    VirtualUser:CaptureController()
    VirtualUser:ClickButton1(Vector2.new(0, 0))
    AddLog("Prevented AFK kick", Colors.Success)
end

-- ConnectAntiAFK function definition
function ConnectAntiAFK()
    -- Disconnect previous connection if it exists
    if IdleConnection then
        IdleConnection:Disconnect()
        IdleConnection = nil
    end
    
    -- Only create a new connection if anti-AFK is enabled
    if AntiAFK then
        IdleConnection = Players.LocalPlayer.Idled:Connect(function()
            SimulateActivity()
        end)
        AddLog("Anti-AFK activated", Colors.Success)
    else
        AddLog("Anti-AFK deactivated", Colors.Warning)
    end
end

-- StartAntiAFK function definition
function StartAntiAFK()
    AntiAFK = true
    UpdateToggle()
    ConnectAntiAFK()
end

-- StopAntiAFK function definition
function StopAntiAFK()
    AntiAFK = false
    UpdateToggle()
    ConnectAntiAFK()
end

-- ToggleAntiAFK function definition
function ToggleAntiAFK()
    AntiAFK = not AntiAFK
    UpdateToggle()
    ConnectAntiAFK()
end

-- SwitchTab function definition
function SwitchTab(tabName)
    pcall(function()
        -- Reset all tab buttons
        ChangelogTab.BackgroundColor3 = Colors.TabInactive
        ChangelogTab.TextColor3 = Colors.SecondaryText
        HomeTab.BackgroundColor3 = Colors.TabInactive
        HomeTab.TextColor3 = Colors.SecondaryText
        SettingsTab.BackgroundColor3 = Colors.TabInactive
        SettingsTab.TextColor3 = Colors.SecondaryText
        LogTab.BackgroundColor3 = Colors.TabInactive
        LogTab.TextColor3 = Colors.SecondaryText
        
        -- Only try to update ConfigTab if it exists and is properly configured
        if ConfigTab then
            pcall(function()
                ConfigTab.BackgroundColor3 = Colors.TabInactive
                ConfigTab.TextColor3 = Colors.SecondaryText
            end)
        end
        
        -- Hide all containers
        ChangelogContainer.Visible = false
        HomeContainer.Visible = false
        SettingsContainer.Visible = false
        LogContainer.Visible = false
        
        -- Only try to hide ConfigContainer if it exists
        if ConfigContainer then
            pcall(function()
                ConfigContainer.Visible = false
            end)
        end
        
        -- Set active tab
        if tabName == "Changelog" then
            ChangelogTab.BackgroundColor3 = Colors.TabActive
            ChangelogTab.TextColor3 = Colors.PrimaryText
            ChangelogContainer.Visible = true
            -- Load changelog content if needed
            if not ChangelogContainer:FindFirstChild("MarkdownContent") then
                LoadChangelog()
            end
        elseif tabName == "Home" then
            HomeTab.BackgroundColor3 = Colors.TabActive
            HomeTab.TextColor3 = Colors.PrimaryText
            HomeContainer.Visible = true
        elseif tabName == "Settings" then
            SettingsTab.BackgroundColor3 = Colors.TabActive
            SettingsTab.TextColor3 = Colors.PrimaryText
            SettingsContainer.Visible = true
        elseif tabName == "Log" then
            LogTab.BackgroundColor3 = Colors.TabActive
            LogTab.TextColor3 = Colors.PrimaryText
            LogContainer.Visible = true
            UpdateLogDisplay() -- Refresh logs when switching to log tab
        elseif tabName == "Config" and ConfigTab and ConfigContainer then
            pcall(function()
                ConfigTab.BackgroundColor3 = Colors.TabActive
                ConfigTab.TextColor3 = Colors.PrimaryText
                ConfigContainer.Visible = true
            end)
        end
    end)
    
    CurrentTab = tabName
end

-- ToggleMinimize function definition
function ToggleMinimize()
    IsMinimized = not IsMinimized
    MainFrame.Visible = not IsMinimized
    MinimizedFrame.Visible = IsMinimized
end

-- UpdateKeybindButton function definition
function UpdateKeybindButton(button, keyCode)
    button.Text = keyCode.Name
    button.TextColor3 = Colors.PrimaryText
end

-- SetupKeybindListener function definition
function SetupKeybindListener()
    -- Disconnect any previous connection
    if KeybindConnection then
        KeybindConnection:Disconnect()
        KeybindConnection = nil
    end
    
    -- Create a new keybind listener and track it
    KeybindConnection = TrackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        -- Check if we're setting a keybind
        if IsChangingKeybind then
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                KeybindSettings[IsChangingKeybind] = input.KeyCode
                
                -- Update button text
                if IsChangingKeybind == "Minimize" then
                    UpdateKeybindButton(MinimizeKeybindButton, input.KeyCode)
                elseif IsChangingKeybind == "KillGUI" then
                    UpdateKeybindButton(KillGUIKeybindButton, input.KeyCode)
                elseif IsChangingKeybind == "ToggleAntiAFK" then
                    UpdateKeybindButton(ToggleAFKKeybindButton, input.KeyCode)
                end
                
                AddLog("Keybind updated: " .. IsChangingKeybind .. " -> " .. input.KeyCode.Name, Colors.AccentColor)
                IsChangingKeybind = nil
            end
        
        -- Handle keybinds
        elseif input.UserInputType == Enum.UserInputType.Keyboard then
            -- Skip keybind handling if:
            -- 1. The game processed the input (user is typing in a text box)
            -- 2. The input was received while a text box is focused
            -- 3. The window is out of focus
            
            -- Get the active text box if any
            local isTextBoxFocused = UserInputService:GetFocusedTextBox() ~= nil
            
            -- Check if window is focused (no perfect way to check this, but this helps)
            local isWindowFocused = true -- Assume focused by default
            pcall(function()
                isWindowFocused = game:GetService("GuiService"):IsTenFootInterface() or 
                                  UserInputService.MouseIconEnabled or
                                  UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or
                                  UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            end)
            
            -- Only process keybinds if the user is not typing and the window is focused
            if not gameProcessed and not isTextBoxFocused and isWindowFocused then
                if input.KeyCode == KeybindSettings.Minimize then
                    ToggleMinimize()
                    AddLog("Used keybind: Minimize", Colors.SecondaryText)
                elseif input.KeyCode == KeybindSettings.KillGUI then
                    AddLog("Used keybind: Kill GUI", Colors.Error)
                    task.wait(0.1) -- Short delay so the log can be seen
                    CleanupAndDestroy()
                elseif input.KeyCode == KeybindSettings.ToggleAntiAFK then
                    ToggleAntiAFK()
                    AddLog("Used keybind: Toggle Anti-AFK", Colors.SecondaryText)
                end
            end
        end
    end))
end

-- ShowLoader function definition
function ShowLoader()
    print("TradeHub: Starting loader animation")
    
    for i = 0, 100, 5 do
        if not ScreenGui or not ScreenGui.Parent then break end
        
        local success, err = pcall(function()
            ProgressBar.Size = UDim2.new(i/100, 0, 1, 0)
            ProgressLabel.Text = i.."%"
        end)
        
        if not success then
            print("TradeHub Error in loader: " .. tostring(err))
        end
        
        print("TradeHub: Loading progress " .. i .. "%")
        
        local status = "Loading"
        if i < 30 then
            status = "Initializing..."
        elseif i < 60 then
            status = "Configuring anti-AFK..."
        elseif i < 90 then
            status = "Preparing interface..."
        else
            status = "Almost ready..."
        end
        
        pcall(function()
            StatusLabel.Text = status
        end)
        
        task.wait(0.05) -- Use task.wait instead of wait
    end
    
    task.wait(0.5) -- Use task.wait instead of wait
    
    pcall(function()
        LoadingFrame.Visible = false
        MainFrame.Visible = true
    end)
    
    -- Add initial log entry
    pcall(function()
        AddLog("TradeHub initialized", Colors.AccentColor)
        AddLog("Anti-AFK is ready", Colors.SecondaryText)
    end)
    
    print("TradeHub: Loading complete")
end

-- Update function definition
function Update(input)
    local delta = input.Position - DragStart
    MainFrame.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + delta.Y)
end

-- Connect events with tracking
-- Tab switching
ChangelogTab.MouseButton1Click:Connect(function()
    SwitchTab("Changelog")
end)

HomeTab.MouseButton1Click:Connect(function()
    SwitchTab("Home")
end)

SettingsTab.MouseButton1Click:Connect(function()
    SwitchTab("Settings")
end)

LogTab.MouseButton1Click:Connect(function()
    SwitchTab("Log")
end)

-- Toggle events
ToggleContainer.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        ToggleAntiAFK()
    end
end)

ToggleBackground.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        ToggleAntiAFK()
    end
end)

-- Make Toggle Button clickable too
ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        ToggleAntiAFK()
    end
end)

-- Minimize/restore buttons
MinimizeButton.MouseButton1Click:Connect(function()
    ToggleMinimize()
end)

RestoreButton.MouseButton1Click:Connect(function()
    ToggleMinimize()
end)

-- Dragging
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = true
        DragStart = input.Position
        StartPosition = MainFrame.Position
    end
end)

TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = false
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        DragInput = input
    end
end)

-- Anti-AFK functionality
RunService.Heartbeat:Connect(function()
    -- This is now empty since we handle the Idled connection separately
end)

-- Initialize keybind buttons
UpdateKeybindButton(MinimizeKeybindButton, KeybindSettings.Minimize)
UpdateKeybindButton(KillGUIKeybindButton, KeybindSettings.KillGUI)
UpdateKeybindButton(ToggleAFKKeybindButton, KeybindSettings.ToggleAntiAFK)

-- Setup keybind listener
SetupKeybindListener()

-- Add version info to logs
AddLog("TradeHub v1.2 - Fixed loading", Colors.AccentColor)

-- Start the script - Changed how we execute the ShowLoader function
print("TradeHub: Script started")

-- Instead of using coroutine.wrap, use a direct task.spawn approach
task.spawn(function()
    local success, error = pcall(ShowLoader)
    if not success then
        print("TradeHub Error: " .. tostring(error))
        
        -- Fallback in case the loader fails
        if LoadingFrame and MainFrame then
            LoadingFrame.Visible = false
            MainFrame.Visible = true
        end
    end
end)

-- Function to clean up all connections and destroy the GUI
function CleanupAndDestroy()
    print("TradeHub: Starting cleanup")
    
    -- Disconnect idle connection
    if IdleConnection then
        IdleConnection:Disconnect()
        IdleConnection = nil
    end
    
    -- Disconnect keybind connection
    if KeybindConnection then
        KeybindConnection:Disconnect()
        KeybindConnection = nil
    end
    
    -- Disconnect any other tracked connections
    for _, connection in ipairs(GlobalConnections) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    
    -- Clear the connections table
    GlobalConnections = {}
    
    -- Finally destroy the GUI
    if ScreenGui and ScreenGui.Parent then
        ScreenGui:Destroy()
    end
    
    print("TradeHub: Cleanup complete")
end

-- Update the CloseButton to use our cleanup function
CloseButton.MouseButton1Click:Connect(function()
    CleanupAndDestroy()
end)

-- Restore InputChanged connection for dragging
UserInputService.InputChanged:Connect(function(input)
    if input == DragInput and Dragging then
        Update(input)
    end
end)

-- Handle resize functionality
function HandleResize(input)
    local delta = input.Position - ResizeStart
    local newSize = UDim2.new(0, 0, 0, 0)
    
    -- Calculate new size based on resize direction
    if ResizingDirection == "BottomRight" then
        newSize = UDim2.new(0, ResizeStartSize.X + delta.X, 0, ResizeStartSize.Y + delta.Y)
    elseif ResizingDirection == "TopLeft" then
        newSize = UDim2.new(0, ResizeStartSize.X - delta.X, 0, ResizeStartSize.Y - delta.Y)
        MainFrame.Position = UDim2.new(0, StartPosition.X.Offset + delta.X, 0, StartPosition.Y.Offset + delta.Y)
    elseif ResizingDirection == "TopRight" then
        newSize = UDim2.new(0, ResizeStartSize.X + delta.X, 0, ResizeStartSize.Y - delta.Y)
        MainFrame.Position = UDim2.new(0, StartPosition.X.Offset, 0, StartPosition.Y.Offset + delta.Y)
    elseif ResizingDirection == "BottomLeft" then
        newSize = UDim2.new(0, ResizeStartSize.X - delta.X, 0, ResizeStartSize.Y + delta.Y)
        MainFrame.Position = UDim2.new(0, StartPosition.X.Offset + delta.X, 0, StartPosition.Y.Offset)
    elseif ResizingDirection == "Right" then
        newSize = UDim2.new(0, ResizeStartSize.X + delta.X, 0, ResizeStartSize.Y)
    elseif ResizingDirection == "Left" then
        newSize = UDim2.new(0, ResizeStartSize.X - delta.X, 0, ResizeStartSize.Y)
        MainFrame.Position = UDim2.new(0, StartPosition.X.Offset + delta.X, 0, StartPosition.Y.Offset)
    elseif ResizingDirection == "Bottom" then
        newSize = UDim2.new(0, ResizeStartSize.X, 0, ResizeStartSize.Y + delta.Y)
    elseif ResizingDirection == "Top" then
        newSize = UDim2.new(0, ResizeStartSize.X, 0, ResizeStartSize.Y - delta.Y)
        MainFrame.Position = UDim2.new(0, StartPosition.X.Offset, 0, StartPosition.Y.Offset + delta.Y)
    end
    
    -- Enforce minimum size
    newSize = UDim2.new(0, math.max(newSize.X.Offset, MinSize.X), 0, math.max(newSize.Y.Offset, MinSize.Y))
    
    -- Apply the new size
    MainFrame.Size = newSize
end

-- Connect resize handlers
for name, handle in pairs(ResizeHandles) do
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Resizing = true
            ResizingDirection = name
            ResizeStart = input.Position
            StartPosition = MainFrame.Position
            ResizeStartSize = Vector2.new(MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset)
        end
    end)
    
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Resizing = false
            ResizingDirection = nil
        end
    end)
end

-- Add resize handling to InputChanged
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if Dragging and DragInput then
            Update(input)
        elseif Resizing and ResizingDirection then
            HandleResize(input)
        end
    end
end)

-- Config Functions
function SaveConfig()
    local success, result = pcall(function()
        -- Create configuration table
        local config = {
            KeybindSettings = KeybindSettings,
            Position = {
                Centered = true, -- Flag to indicate we're using centered positioning
                X = MainFrame.Position.X.Offset,
                Y = MainFrame.Position.Y.Offset
            },
            Size = {
                X = MainFrame.Size.X.Offset,
                Y = MainFrame.Size.Y.Offset
            },
            AntiAFK = AntiAFK
        }
        
        -- Convert to JSON
        local jsonData = HttpService:JSONEncode(config)
        
        -- Try to save using writefile (this works in certain environments)
        writefile(ConfigFilename, jsonData)
        
        AddLog("Configuration saved successfully", Colors.Success)
        ConfigStatus.Text = "Status: Configuration saved successfully!"
        ConfigStatus.TextColor3 = Colors.Success
        
        return true
    end)
    
    if not success then
        AddLog("Failed to save configuration: " .. tostring(result), Colors.Error)
        ConfigStatus.Text = "Status: Failed to save configuration. This feature may not be supported in this environment."
        ConfigStatus.TextColor3 = Colors.Error
        return false
    end
    
    return success
end

function LoadConfig()
    local success, result = pcall(function()
        -- Check if config file exists
        if not isfile(ConfigFilename) then
            AddLog("No saved configuration found", Colors.Warning)
            ConfigStatus.Text = "Status: No saved configuration found."
            ConfigStatus.TextColor3 = Colors.Warning
            return false
        end
        
        -- Read and parse the config file
        local jsonData = readfile(ConfigFilename)
        local config = HttpService:JSONDecode(jsonData)
        
        -- Apply the configuration
        -- Keybinds
        if config.KeybindSettings then
            for key, value in pairs(config.KeybindSettings) do
                KeybindSettings[key] = Enum.KeyCode[value.Name]
            end
            
            -- Update keybind buttons
            UpdateKeybindButton(MinimizeKeybindButton, KeybindSettings.Minimize)
            UpdateKeybindButton(KillGUIKeybindButton, KeybindSettings.KillGUI)
            UpdateKeybindButton(ToggleAFKKeybindButton, KeybindSettings.ToggleAntiAFK)
        end
        
        -- Position and Size
        if config.Position then
            -- For backward compatibility with old configs that used absolute positioning
            -- Convert to new centered positioning
            MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
            
            -- If we want to restore the exact position, uncomment below:
            -- MainFrame.AnchorPoint = Vector2.new(0, 0)
            -- MainFrame.Position = UDim2.new(0, config.Position.X, 0, config.Position.Y)
        end
        
        if config.Size then
            MainFrame.Size = UDim2.new(0, math.max(config.Size.X, MinSize.X), 0, math.max(config.Size.Y, MinSize.Y))
        end
        
        -- Anti-AFK state
        if config.AntiAFK ~= nil then
            AntiAFK = config.AntiAFK
            UpdateToggle()
            ConnectAntiAFK()
        end
        
        AddLog("Configuration loaded successfully", Colors.Success)
        ConfigStatus.Text = "Status: Configuration loaded successfully!"
        ConfigStatus.TextColor3 = Colors.Success
        
        return true
    end)
    
    if not success then
        AddLog("Failed to load configuration: " .. tostring(result), Colors.Error)
        ConfigStatus.Text = "Status: Failed to load configuration. " .. tostring(result)
        ConfigStatus.TextColor3 = Colors.Error
        return false
    end
    
    return success
end

function ResetConfig()
    local success, result = pcall(function()
        -- Reset keybinds to default
        KeybindSettings = {
            Minimize = Enum.KeyCode.RightShift,
            KillGUI = Enum.KeyCode.Backspace,
            ToggleAntiAFK = Enum.KeyCode.F
        }
        
        -- Update keybind buttons
        UpdateKeybindButton(MinimizeKeybindButton, KeybindSettings.Minimize)
        UpdateKeybindButton(KillGUIKeybindButton, KeybindSettings.KillGUI)
        UpdateKeybindButton(ToggleAFKKeybindButton, KeybindSettings.ToggleAntiAFK)
        
        -- Reset Anti-AFK state
        AntiAFK = false
        UpdateToggle()
        ConnectAntiAFK()
        
        -- If saved config exists, delete it
        if isfile(ConfigFilename) then
            delfile(ConfigFilename)
        end
        
        AddLog("Configuration reset to default", Colors.Warning)
        ConfigStatus.Text = "Status: Configuration reset to default settings"
        ConfigStatus.TextColor3 = Colors.Warning
        
        return true
    end)
    
    if not success then
        AddLog("Failed to reset configuration: " .. tostring(result), Colors.Error)
        ConfigStatus.Text = "Status: Failed to reset configuration. " .. tostring(result)
        ConfigStatus.TextColor3 = Colors.Error
        return false
    end
    
    return success
end

-- Connect config button events
SaveConfigButton.MouseButton1Click:Connect(function()
    SaveConfig()
end)

LoadConfigButton.MouseButton1Click:Connect(function()
    LoadConfig()
end)

ResetConfigButton.MouseButton1Click:Connect(function()
    ResetConfig()
end)

-- Try to load config on startup
task.spawn(function()
    task.wait(1) -- Wait for UI to initialize
    if isfile and readfile and isfile(ConfigFilename) then
        LoadConfig()
    end
end)

-- Connect the Config tab click event safely
local success, err = pcall(function()
    ConfigTab.MouseButton1Click:Connect(function()
        SwitchTab("Config")
    end)
end)
if not success then
    print("TradeHub Error connecting ConfigTab click: " .. tostring(err))
end

-- Load the markdown parser module directly via loadstring
local MarkdownParser
pcall(function()
    local markdownScript = [==[
--[[
    Markdown Parser for Roblox
    
    This module parses markdown text and converts it to Roblox UI elements.
    
    Features:
    - Headers (# Header 1, ## Header 2, etc.)
    - Bold text (**bold**)
    - Italic text (*italic*)
    - Lists (- item, * item, 1. item)
    - Code blocks (```code```)
    - Links [text](url)
]]

local MarkdownParser = {}

-- Default styles
MarkdownParser.Style = {
    Font = {
        Regular = Enum.Font.Gotham,
        Bold = Enum.Font.GothamBold,
        Italic = Enum.Font.GothamMedium,
        Code = Enum.Font.Code,
        Header = Enum.Font.GothamBold
    },
    TextSize = {
        Default = 14,
        H1 = 24,
        H2 = 20,
        H3 = 18,
        H4 = 16,
        H5 = 15,
        H6 = 14,
        Code = 13
    },
    Color = {
        Default = Color3.fromRGB(220, 220, 220),
        Header = Color3.fromRGB(255, 255, 255),
        Link = Color3.fromRGB(70, 150, 255),
        Code = Color3.fromRGB(200, 200, 200),
        CodeBackground = Color3.fromRGB(40, 40, 40)
    },
    LineSpacing = 5,
    IndentSize = 20
}

-- Fetch markdown from URL
function MarkdownParser.FetchFromURL(url)
    local success, result
    
    -- Get HttpService
    local HttpService
    
    success, HttpService = pcall(function()
        return game:GetService("HttpService")
    end)
    
    if not success or not HttpService then
        return "# Error\nCould not access HttpService. This may be disabled in your executor."
    end
    
    -- Make request
    success, result = pcall(function()
        return HttpService:GetAsync(url)
    end)
    
    if not success then
        return "# Error\nFailed to fetch markdown from URL: " .. url .. "\n\nError: " .. tostring(result)
    end
    
    return result
end

-- Parse markdown text and create UI elements in the specified container
function MarkdownParser.ParseToContainer(markdownText, container, customStyle)
    -- Merge custom style with default style
    local style = {}
    for k, v in pairs(MarkdownParser.Style) do
        if type(v) == "table" then
            style[k] = {}
            for k2, v2 in pairs(v) do
                style[k][k2] = v2
            end
        else
            style[k] = v
        end
    end
    
    if customStyle then
        for k, v in pairs(customStyle) do
            if type(v) == "table" and type(style[k]) == "table" then
                for k2, v2 in pairs(v) do
                    style[k][k2] = v2
                end
            else
                style[k] = v
            end
        end
    end
    
    -- Clear existing content
    for _, child in pairs(container:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "ChangelogTitle" then
            child:Destroy()
        end
    end
    
    -- Create a scrolling frame for the content
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "MarkdownContent"
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.Position = UDim2.new(0, 10, 0, 50) -- Position below title
    scrollFrame.Size = UDim2.new(1, -20, 1, -60)
    scrollFrame.CanvasSize = UDim2.new(1, -20, 0, 0) -- Will be updated as content is added
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.BorderSizePixel = 0
    scrollFrame.Parent = container
    
    -- Split the text into lines
    local lines = {}
    for line in string.gmatch(markdownText .. "\n", "([^\n]*)\n") do
        table.insert(lines, line)
    end
    
    local currentY = 0
    local lineIndex = 1
    
    while lineIndex <= #lines do
        local line = lines[lineIndex]
        
        -- Check for headers
        local headerLevel, headerText = string.match(line, "^(#+)%s+(.+)")
        if headerLevel then
            local level = math.min(#headerLevel, 6)
            
            local header = Instance.new("TextLabel")
            header.BackgroundTransparency = 1
            header.Position = UDim2.new(0, 0, 0, currentY)
            header.Size = UDim2.new(1, 0, 0, style.TextSize["H" .. level] + 10)
            header.Font = style.Font.Header
            header.Text = headerText
            header.TextColor3 = style.Color.Header
            header.TextSize = style.TextSize["H" .. level]
            header.TextXAlignment = Enum.TextXAlignment.Left
            header.TextWrapped = true
            header.Parent = scrollFrame
            
            currentY = currentY + header.Size.Y.Offset + style.LineSpacing
            lineIndex = lineIndex + 1
            
            -- Add horizontal line after H1 and H2
            if level <= 2 then
                local divider = Instance.new("Frame")
                divider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                divider.BorderSizePixel = 0
                divider.Position = UDim2.new(0, 0, 0, currentY)
                divider.Size = UDim2.new(1, 0, 0, 1)
                divider.Parent = scrollFrame
                
                currentY = currentY + 3 + style.LineSpacing
            end
        -- Check for code blocks
        elseif line:match("^```") then
            local codeBlockContent = {}
            local language = line:match("^```(%w*)")
            
            lineIndex = lineIndex + 1
            while lineIndex <= #lines and not lines[lineIndex]:match("^```") do
                table.insert(codeBlockContent, lines[lineIndex])
                lineIndex = lineIndex + 1
            end
            
            -- Skip the closing ```
            lineIndex = lineIndex + 1
            
            local codeText = table.concat(codeBlockContent, "\n")
            
            -- Create a frame for the code block
            local codeFrame = Instance.new("Frame")
            codeFrame.BackgroundColor3 = style.Color.CodeBackground
            codeFrame.BorderSizePixel = 0
            codeFrame.Position = UDim2.new(0, 0, 0, currentY)
            
            -- Create code text
            local codeLabel = Instance.new("TextLabel")
            codeLabel.BackgroundTransparency = 1
            codeLabel.Position = UDim2.new(0, 10, 0, 10)
            codeLabel.Size = UDim2.new(1, -20, 1, -20)
            codeLabel.Font = style.Font.Code
            codeLabel.Text = codeText
            codeLabel.TextColor3 = style.Color.Code
            codeLabel.TextSize = style.TextSize.Code
            codeLabel.TextXAlignment = Enum.TextXAlignment.Left
            codeLabel.TextYAlignment = Enum.TextYAlignment.Top
            codeLabel.TextWrapped = true
            codeLabel.Parent = codeFrame
            
            -- Calculate the height based on content
            local textHeight = 0
            local textService = game:GetService("TextService")
            local textSize = textService:GetTextSize(
                codeText,
                style.TextSize.Code,
                style.Font.Code,
                Vector2.new(scrollFrame.Size.X.Offset - 40, 10000)
            )
            textHeight = textSize.Y
            
            codeLabel.Size = UDim2.new(1, -20, 0, textHeight)
            codeFrame.Size = UDim2.new(1, 0, 0, textHeight + 20)
            codeFrame.Parent = scrollFrame
            
            currentY = currentY + codeFrame.Size.Y.Offset + style.LineSpacing
        -- Check for lists
        elseif line:match("^%s*[%-%*]%s+") or line:match("^%s*%d+%.%s+") then
            local indentLevel = 0
            local listItems = {}
            
            while lineIndex <= #lines do
                local currentLine = lines[lineIndex]
                local spaces = currentLine:match("^(%s*)")
                local currentIndent = spaces and #spaces/2 or 0
                local listMarker, listText = currentLine:match("^%s*([%-%*]%s+)(.+)") or currentLine:match("^%s*(%d+%.%s+)(.+)")
                
                if not listMarker then
                    break
                end
                
                table.insert(listItems, {
                    text = listText,
                    marker = listMarker:sub(1,1) == "-" or listMarker:sub(1,1) == "*" and "•" or listMarker,
                    indent = currentIndent
                })
                
                lineIndex = lineIndex + 1
            end
            
            -- Create list items
            for i, item in ipairs(listItems) do
                local listItem = Instance.new("TextLabel")
                listItem.BackgroundTransparency = 1
                listItem.Position = UDim2.new(0, item.indent * style.IndentSize, 0, currentY)
                listItem.Size = UDim2.new(1, -item.indent * style.IndentSize, 0, style.TextSize.Default + 5)
                listItem.Font = style.Font.Regular
                
                -- Format the list marker
                local displayMarker = item.marker
                if displayMarker == "•" then
                    displayMarker = "• "
                end
                
                listItem.Text = displayMarker .. " " .. item.text
                listItem.TextColor3 = style.Color.Default
                listItem.TextSize = style.TextSize.Default
                listItem.TextXAlignment = Enum.TextXAlignment.Left
                listItem.TextWrapped = true
                listItem.Parent = scrollFrame
                
                -- Calculate height based on content
                local textService = game:GetService("TextService")
                local textSize = textService:GetTextSize(
                    listItem.Text,
                    style.TextSize.Default,
                    style.Font.Regular,
                    Vector2.new(scrollFrame.Size.X.Offset - (item.indent * style.IndentSize), 10000)
                )
                listItem.Size = UDim2.new(1, -item.indent * style.IndentSize, 0, textSize.Y)
                
                currentY = currentY + listItem.Size.Y.Offset + 2
            end
            
            currentY = currentY + style.LineSpacing
        -- Regular paragraph
        else
            -- Process consecutive lines until we find a blank line or special format
            local paragraphLines = {}
            
            while lineIndex <= #lines do
                local currentLine = lines[lineIndex]
                -- Stop at blank line or special format
                if currentLine == "" or 
                   currentLine:match("^#+%s+") or 
                   currentLine:match("^```") or
                   currentLine:match("^%s*[%-%*]%s+") or 
                   currentLine:match("^%s*%d+%.%s+") then
                    break
                end
                
                table.insert(paragraphLines, currentLine)
                lineIndex = lineIndex + 1
            end
            
            -- If no paragraph content, just skip the blank line
            if #paragraphLines == 0 then
                lineIndex = lineIndex + 1
                currentY = currentY + style.LineSpacing
            else
                local paragraphText = table.concat(paragraphLines, " ")
                
                -- Basic formatting for bold/italic/links
                local formattedText = paragraphText
                
                -- Create paragraph label
                local paragraph = Instance.new("TextLabel")
                paragraph.BackgroundTransparency = 1
                paragraph.Position = UDim2.new(0, 0, 0, currentY)
                paragraph.Size = UDim2.new(1, 0, 0, style.TextSize.Default + 5)
                paragraph.Font = style.Font.Regular
                paragraph.Text = formattedText
                paragraph.TextColor3 = style.Color.Default
                paragraph.TextSize = style.TextSize.Default
                paragraph.TextXAlignment = Enum.TextXAlignment.Left
                paragraph.TextWrapped = true
                paragraph.Parent = scrollFrame
                
                -- Calculate height based on content
                local textService = game:GetService("TextService")
                local textSize = textService:GetTextSize(
                    formattedText,
                    style.TextSize.Default,
                    style.Font.Regular,
                    Vector2.new(scrollFrame.Size.X.Offset, 10000)
                )
                paragraph.Size = UDim2.new(1, 0, 0, textSize.Y)
                
                currentY = currentY + paragraph.Size.Y.Offset + style.LineSpacing
            end
        end
    end
    
    -- Update the canvas size
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, currentY)
end

-- Load and display a local markdown file
function MarkdownParser.LoadFile(filePath, container, customStyle)
    local success, content = pcall(function()
        return readfile(filePath)
    end)
    
    if not success then
        local errorMessage = "# Error Loading File\n\nCould not load file: " .. filePath
        MarkdownParser.ParseToContainer(errorMessage, container, customStyle)
        return false
    end
    
    MarkdownParser.ParseToContainer(content, container, customStyle)
    return true
end

return MarkdownParser
    ]==]
    
    MarkdownParser = loadstring(markdownScript)()
end)

-- Function to load changelog content
function LoadChangelog()
    -- First try to load from local file
    local changelogContent = ""
    local success = pcall(function()
        changelogContent = readfile("changelog.md")
    end)
    
    if not success then
        -- If local file fails, try to fetch from GitHub
        pcall(function()
            changelogContent = MarkdownParser.FetchFromURL("https://raw.githubusercontent.com/ripgrim/Trade-Hangout-Anti-AFK/main/markdown.lua")
        end)
    end
    
    -- If we don't have markdown content, use a basic message
    if not changelogContent or changelogContent == "" then
        changelogContent = "# TradeHub Changelog\n\n## Unable to load changelog\nPlease check your internet connection or try again later."
    end
    
    -- If parser is available, use it to display the changelog
    if MarkdownParser then
        MarkdownParser.ParseToContainer(changelogContent, ChangelogContainer, {
            Color = {
                Default = Colors.SecondaryText,
                Header = Colors.PrimaryText,
                Link = Colors.AccentColor,
                Code = Colors.SecondaryText,
                CodeBackground = Colors.Background
            }
        })
    else
        -- Fallback if parser is not available
        local fallbackText = Instance.new("TextLabel")
        fallbackText.Name = "FallbackText"
        fallbackText.BackgroundTransparency = 1
        fallbackText.Position = UDim2.new(0, 10, 0, 50)
        fallbackText.Size = UDim2.new(1, -20, 1, -60)
        fallbackText.Font = Enum.Font.Gotham
        fallbackText.Text = "Changelog content could not be displayed. The markdown parser module is missing."
        fallbackText.TextColor3 = Colors.SecondaryText
        fallbackText.TextSize = 14
        fallbackText.TextWrapped = true
        fallbackText.TextXAlignment = Enum.TextXAlignment.Left
        fallbackText.Parent = ChangelogContainer
    end
end

-- Load changelog on startup
task.spawn(function()
    task.wait(1) -- Wait for UI to initialize
    LoadChangelog()
end)