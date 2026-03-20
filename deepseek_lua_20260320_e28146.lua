local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local Library = loadstring(game:HttpGet(repo.."Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo.."addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo.."addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
Title = "Vodka Hub",
Footer = "example",
Icon = 137581094938104,
NotifySide = "Right",
ShowCustomCursor = true
})

local Tabs = {
Main = Window:AddTab("Main","user"),
Visuals = Window:AddTab("Visuals","eye"),
Info = Window:AddTab("Info","info"),
["UI Settings"] = Window:AddTab("UI Settings","settings")
}

local replicated_storage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera

local utility = require(replicated_storage.Modules.Utility)

----------------------------------------------------------------
-- HELPER FUNCTIONS
----------------------------------------------------------------

local local_player = players.LocalPlayer
local current_target = nil

local function get_player_team(player)
    -- Check player's team
    if player.Team then
        return player.Team
    end
    
    -- Check character for team
    local char = player.Character
    if char then
        local team_value = char:FindFirstChild("Team") or char:FindFirstChild("TeamColor")
        if team_value then
            return team_value.Value
        end
    end
    
    return nil
end

local function is_teammate(player)
    if not Toggles.TeamCheck.Value then
        return false
    end
    
    local local_team = get_player_team(local_player)
    local target_team = get_player_team(player)
    
    if local_team and target_team then
        return local_team == target_team
    end
    
    return false
end

local function get_valid_targets()
    local targets = {}
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local fov_radius = Options.FOVRadius.Value
    local max_distance = Options.MaxDistance.Value
    
    for _, player in pairs(players:GetPlayers()) do
        if player ~= local_player and not is_teammate(player) then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if hrp and hum and hum.Health > 0 then
                -- Check distance
                local distance = (camera.CFrame.Position - hrp.Position).Magnitude
                if distance > max_distance then
                    continue
                end
                
                -- Check FOV
                local pos, on_screen = camera:WorldToViewportPoint(hrp.Position)
                if on_screen then
                    local screen_distance = (center - Vector2.new(pos.X, pos.Y)).Magnitude
                    if screen_distance <= fov_radius or not Toggles.FOVCircle.Value then
                        table.insert(targets, {
                            player = player,
                            hrp = hrp,
                            distance = distance,
                            screen_distance = screen_distance,
                            pos = pos
                        })
                    end
                end
            end
        end
    end
    
    return targets
end

local function get_closest_target_to_crosshair()
    local targets = get_valid_targets()
    
    if #targets == 0 then
        return nil
    end
    
    -- Sort by screen distance (closest to crosshair)
    table.sort(targets, function(a, b)
        return a.screen_distance < b.screen_distance
    end)
    
    return targets[1]
end

local function get_closest_target_by_distance()
    local targets = get_valid_targets()
    
    if #targets == 0 then
        return nil
    end
    
    -- Sort by world distance
    table.sort(targets, function(a, b)
        return a.distance < b.distance
    end)
    
    return targets[1]
end

----------------------------------------------------------------
-- SILENT AIM
----------------------------------------------------------------

local function get_players_in_fov()
    local entities = {}
    local fov_radius = Options.FOVRadius.Value
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local max_distance = Options.MaxDistance.Value
    
    for _, child in workspace:GetChildren() do
        local target = nil
        
        if child:FindFirstChildOfClass("Humanoid") then
            target = child
        elseif child.Name == "HurtEffect" then
            for _, hurt_player in child:GetChildren() do
                if hurt_player.ClassName ~= "Highlight" then
                    target = hurt_player
                    break
                end
            end
        end
        
        if target and target:FindFirstChild("HumanoidRootPart") then
            -- Check if it's a player and team check
            local player = players:GetPlayerFromCharacter(target)
            if player and player ~= local_player and not is_teammate(player) then
                -- Check distance
                local distance = (camera.CFrame.Position - target.HumanoidRootPart.Position).Magnitude
                if distance <= max_distance then
                    local pos, on_screen = camera:WorldToViewportPoint(target.HumanoidRootPart.Position)
                    
                    if on_screen then
                        local screen_distance = (center - Vector2.new(pos.X, pos.Y)).Magnitude
                        
                        if screen_distance <= fov_radius or not Toggles.FOVCircle.Value then
                            table.insert(entities, target)
                        end
                    end
                end
            end
        end
    end
    
    return entities
end

local function get_closest_player_in_fov()
    local closest, closest_distance = nil, math.huge
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    
    for _, player in get_players_in_fov() do
        if not player:FindFirstChild("HumanoidRootPart") then continue end
        
        local pos, on_screen = camera:WorldToViewportPoint(player.HumanoidRootPart.Position)
        
        if not on_screen then continue end
        
        local distance = (center - Vector2.new(pos.X, pos.Y)).Magnitude
        
        if distance < closest_distance then
            closest = player
            closest_distance = distance
        end
    end
    
    return closest
end

local function get_closest_player()
    local entities = {}
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    
    for _, child in workspace:GetChildren() do
        if child:FindFirstChildOfClass("Humanoid") then
            table.insert(entities, child)
        elseif child.Name == "HurtEffect" then
            for _, hurt_player in child:GetChildren() do
                if hurt_player.ClassName ~= "Highlight" then
                    table.insert(entities, hurt_player)
                end
            end
        end
    end
    
    local closest, closest_distance = nil, math.huge
    
    for _, player in entities do
        if not player:FindFirstChild("HumanoidRootPart") then continue end
        
        local pos, on_screen = camera:WorldToViewportPoint(player.HumanoidRootPart.Position)
        
        if not on_screen then continue end
        
        local distance = (center - Vector2.new(pos.X, pos.Y)).Magnitude
        
        if distance < closest_distance then
            closest = player
            closest_distance = distance
        end
    end
    
    return closest
end

local old = utility.Raycast

utility.Raycast = function(...)
    local args = {...}
    
    if Toggles.SilentAim.Value then
        if #args > 0 and args[4] == 999 then
            local target
            if Toggles.FOVCircle.Value then
                target = get_closest_player_in_fov()
            else
                target = get_closest_player()
            end
            
            if target and target:FindFirstChild("Head") then
                args[3] = target.Head.Position
            end
        end
    end
    
    return old(table.unpack(args))
end

----------------------------------------------------------------
-- AIMLOCK (AIMBOT)
----------------------------------------------------------------

local aimlock_active = false
local aimlock_target = nil

local function aim_at_target(target_hrp)
    if not target_hrp or not Toggles.Aimlock.Value then
        return
    end
    
    -- Get the head or humanoidrootpart position to aim at
    local target_pos = target_hrp.Position
    local head = target_hrp.Parent:FindFirstChild("Head")
    if head then
        target_pos = head.Position
    end
    
    -- Calculate new camera direction
    local camera_pos = camera.CFrame.Position
    local direction = (target_pos - camera_pos).Unit
    
    -- Set camera CFrame to look at target
    camera.CFrame = CFrame.lookAt(camera_pos, target_pos)
end

-- Update aimlock target
run_service.RenderStepped:Connect(function()
    if not Toggles.Aimlock.Value then
        aimlock_target = nil
        return
    end
    
    -- Get the best target based on settings
    if Toggles.AimlockPriority.Value == "Crosshair" then
        local target_data = get_closest_target_to_crosshair()
        aimlock_target = target_data and target_data.hrp or nil
    else
        local target_data = get_closest_target_by_distance()
        aimlock_target = target_data and target_data.hrp or nil
    end
end)

-- Mouse movement for aimlock (only when holding key)
local aimlock_key = Enum.UserInputType.MouseButton2 -- Right mouse button by default

user_input_service.InputBegan:Connect(function(input, game_processed)
    if game_processed then return end
    
    if Toggles.Aimlock.Value and input.UserInputType == aimlock_key then
        aimlock_active = true
    end
end)

user_input_service.InputEnded:Connect(function(input, game_processed)
    if game_processed then return end
    
    if input.UserInputType == aimlock_key then
        aimlock_active = false
    end
end)

-- Apply aimlock
run_service.RenderStepped:Connect(function()
    if Toggles.Aimlock.Value and aimlock_active and aimlock_target then
        aim_at_target(aimlock_target)
    end
end)

----------------------------------------------------------------
-- COMBAT
----------------------------------------------------------------

local MainBox = Tabs.Main:AddLeftGroupbox("Combat")

MainBox:AddToggle("SilentAim",{
    Text = "Silent Aim",
    Default = false
})

MainBox:AddToggle("Aimlock",{
    Text = "Aimlock (Hold Right Click)",
    Default = false
})

MainBox:AddDropdown("AimlockPriority",{
    Text = "Aimlock Priority",
    Default = "Crosshair",
    Options = {"Crosshair", "Distance"},
    Callback = function(v)
        Options.AimlockPriority.Value = v
    end
})

MainBox:AddToggle("TeamCheck",{
    Text = "Team Check (Don't target teammates)",
    Default = true
})

MainBox:AddSlider("MaxDistance",{
    Text = "Max Distance (Studs)",
    Default = 500,
    Min = 100,
    Max = 2000,
    Rounding = 0
})

----------------------------------------------------------------
-- MOD GUN
----------------------------------------------------------------

local GunBox = Tabs.Main:AddLeftGroupbox("Gun Mods")

local function toggleTableAttribute(attribute,value)
    for _, gcVal in pairs(getgc(true)) do
        if type(gcVal) == "table" and rawget(gcVal, attribute) then
            gcVal[attribute] = value
        end
    end
end

GunBox:AddToggle("ModGun",{
    Text = "Mod Gun",
    Default = false,
    Callback = function(v)
        if v then
            toggleTableAttribute("ShootCooldown",0)
            toggleTableAttribute("ShootSpread",0)
            toggleTableAttribute("ShootRecoil",0)
        end
    end
})

----------------------------------------------------------------
-- SPEED
----------------------------------------------------------------

local MovementBox = Tabs.Main:AddRightGroupbox("Movement")

MovementBox:AddToggle("SpeedHack",{
    Text = "Speed Hack",
    Default = false
})

MovementBox:AddSlider("SpeedAmount",{
    Text = "Speed",
    Default = 50,
    Min = 16,
    Max = 150,
    Rounding = 0
})

run_service.Heartbeat:Connect(function()
    if not Toggles.SpeedHack.Value then return end
    
    local char = local_player.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not root then return end
    
    root.Velocity = hum.MoveDirection * Options.SpeedAmount.Value + Vector3.new(0, root.Velocity.Y, 0)
end)

----------------------------------------------------------------
-- ESP
----------------------------------------------------------------

local VisualBox = Tabs.Visuals:AddLeftGroupbox("ESP")

VisualBox:AddToggle("PlayerESP",{
    Text = "Player ESP",
    Default = false
})

local esp = {}

local function create_esp(player)
    if player == local_player then return end
    
    local name = Drawing.new("Text")
    name.Size = 13
    name.Center = true
    name.Outline = true
    
    local health = Drawing.new("Line")
    health.Thickness = 3
    
    esp[player] = {name = name, health = health}
end

for _, p in pairs(players:GetPlayers()) do
    create_esp(p)
end

players.PlayerAdded:Connect(create_esp)
players.PlayerRemoving:Connect(function(player)
    if esp[player] then
        esp[player].name:Remove()
        esp[player].health:Remove()
        esp[player] = nil
    end
end)

run_service.RenderStepped:Connect(function()
    for player, draw in pairs(esp) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if hrp and hum and Toggles.PlayerESP.Value and hum.Health > 0 then
            local pos, vis = camera:WorldToViewportPoint(hrp.Position)
            
            if vis then
                draw.name.Text = player.Name
                draw.name.Position = Vector2.new(pos.X, pos.Y - 20)
                draw.name.Visible = true
                
                local hp = hum.Health / hum.MaxHealth
                draw.health.From = Vector2.new(pos.X - 20, pos.Y)
                draw.health.To = Vector2.new(pos.X - 20, pos.Y + (40 * hp))
                draw.health.Visible = true
            else
                draw.name.Visible = false
                draw.health.Visible = false
            end
        else
            draw.name.Visible = false
            draw.health.Visible = false
        end
    end
end)

----------------------------------------------------------------
-- FOV + GUN TRACKER
----------------------------------------------------------------

local FovBox = Tabs.Visuals:AddRightGroupbox("FOV")

FovBox:AddToggle("FOVCircle",{
    Text = "Show FOV",
    Default = false
})

FovBox:AddSlider("FOVRadius",{
    Text = "FOV Radius",
    Default = 150,
    Min = 50,
    Max = 500,
    Rounding = 0
})

FovBox:AddToggle("GunTrackerEnabled",{
    Text = "Gun Tracker",
    Default = false
})

local fov = Drawing.new("Circle")
fov.Thickness = 2
fov.Filled = false
fov.NumSides = 100
fov.Color = Color3.fromRGB(255, 255, 255)

local GunTracker = Drawing.new("Line")
GunTracker.Thickness = 2
GunTracker.Color = Color3.fromRGB(0,255,0)
GunTracker.Visible = false

local CurrentTarget = nil

run_service.RenderStepped:Connect(function()
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    
    fov.Position = center
    fov.Radius = Options.FOVRadius.Value
    fov.Visible = Toggles.FOVCircle.Value
    
    local closest = nil
    local closestDist = math.huge
    
    for _, player in pairs(players:GetPlayers()) do
        if player ~= local_player and not is_teammate(player) then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if root and hum and hum.Health > 0 then
                local pos, visible = camera:WorldToViewportPoint(root.Position)
                
                if visible then
                    local dist = (center - Vector2.new(pos.X, pos.Y)).Magnitude
                    
                    if dist < Options.FOVRadius.Value and dist < closestDist then
                        closestDist = dist
                        closest = root
                    end
                end
            end
        end
    end
    
    CurrentTarget = closest
    
    if not Toggles.GunTrackerEnabled.Value or not CurrentTarget then
        GunTracker.Visible = false
        return
    end
    
    local pos, onScreen = camera:WorldToViewportPoint(CurrentTarget.Position)
    
    if onScreen then
        GunTracker.From = center
        GunTracker.To = Vector2.new(pos.X, pos.Y)
        GunTracker.Visible = true
    else
        GunTracker.Visible = false
    end
end)

----------------------------------------------------------------
-- INFO TAB
----------------------------------------------------------------

local InfoBox = Tabs.Info:AddLeftGroupbox("Discord")

InfoBox:AddLabel("Join the Vodka Hub Discord")

InfoBox:AddButton("Copy Discord Link", function()
    setclipboard("https://discord.gg/dJJ3psbAxw")
    Library:Notify("Discord copied to clipboard!")
end)

InfoBox:AddLabel("If you want more features added to the hub please join the discord.")

----------------------------------------------------------------
-- UI SETTINGS
----------------------------------------------------------------

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")

MenuGroup:AddToggle("KeybindMenuOpen",{
    Default = Library.KeybindFrame.Visible,
    Text = "Open Keybind Menu",
    Callback = function(v)
        Library.KeybindFrame.Visible = v
    end
})

MenuGroup:AddLabel("Menu bind")
    :AddKeyPicker("MenuKeybind", {Default = "RightShift", NoUI = true, Text = "Menu keybind"})

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})

ThemeManager:SetFolder("VodkaHub")
SaveManager:SetFolder("VodkaHub/configs")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

SaveManager:LoadAutoloadConfig()