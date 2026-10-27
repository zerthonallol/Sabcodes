-- ============================================================
-- Sources Hub Redeemer — SAFE REWRITE
-- Убрано: loadstring/HttpGet, debug.*, getconnections, firesignal,
--         setupvalue, getupvalues, блокировка LeaveGame.
-- Оставлено: UI + перехват уведомлений + заполнение TextBox.
-- ============================================================

local Players           = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local LP                 = Players.LocalPlayer
local PlayerGui          = LP:WaitForChild("PlayerGui")

-- ---------- Вспомогательные ----------
local function isOurGui(instance)
    local p = instance
    for _ = 1, 10 do
        if not p then break end
        if p.Name == "SourcesHubRedeemerGui" then return true end
        p = p.Parent
    end
    return false
end

local function isVisibleChain(inst)
    local current = inst
    while current do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") then
            return current.Enabled
        end
        current = current.Parent
    end
    return true
end

local function findAllTextBoxes(pg)
    local boxes = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "SourcesHubRedeemerGui" then
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextBox") and not isOurGui(d) then
                    boxes[#boxes + 1] = d
                end
            end
        end
    end
    return boxes
end

-- Клик только штатным сигналом (без firesignal/getconnections)
local function clickButton(btn)
    if not btn then return false end
    local ok = pcall(function() btn.MouseButton1Click:Fire() end)
    return ok
end

local function writeCodeToBox(box, code)
    if not box then return false end
    local ok = pcall(function() box.Text = code end)
    return ok and box.Text == code
end

-- ---------- Ввод кода в поле (без манипуляций с debug) ----------
local function typeAndSubmitCode(code)
    if not LP then return false, "no LP" end
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return false, "no PlayerGui" end

    -- 1) Пытаемся найти стандартный фрейм Codes
    local codesGui = pg:FindFirstChild("Codes")
    if codesGui then
        if codesGui:IsA("ScreenGui") then codesGui.Enabled = true end
        local codesFrame = codesGui:FindFirstChild("Codes") or codesGui
        if codesFrame and codesFrame:IsA("GuiObject") then
            codesFrame.Visible = true
        end

        local box
        for _, d in ipairs(codesFrame:GetDescendants()) do
            if d:IsA("TextBox") and not isOurGui(d) then box = d; break end
        end

        local submitBtn
        for _, d in ipairs(codesFrame:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOurGui(d) then
                local n = d.Name:lower()
                local t = ""
                pcall(function() t = d.Text:lower() end)
                if n:find("submit") or t:find("submit")
                    or n:find("redeem") or t:find("redeem")
                    or n:find("claim")  or t:find("claim")
                    or n:find("confirm") or t:find("confirm")
                    or n:find("enter")  or n:find("apply") then
                    submitBtn = d; break
                end
            end
        end

        if box then
            writeCodeToBox(box, code)
            task.wait(0.05)
            if submitBtn then clickButton(submitBtn) end
            return true, "submitted via PlayerGui.Codes"
        end
    end

    -- 2) Fallback: ищем видимое поле ввода кода и ближайшую кнопку
    local box
    local deadline = tick() + 3
    while tick() < deadline do
        for _, d in ipairs(findAllTextBoxes(pg)) do
            if isVisibleChain(d) then
                local n  = d.Name:lower()
                local pn = (d.Parent and d.Parent.Name or ""):lower()
                if n:find("code") or pn:find("code")
                    or n:find("redeem") or pn:find("redeem")
                    or n:find("input") or pn:find("input")
                    or n:find("enter") then
                    box = d; break
                end
            end
        end
        if not box then
            for _, d in ipairs(findAllTextBoxes(pg)) do
                if isVisibleChain(d) then box = d; break end
            end
        end
        if box then break end
        task.wait(0.1)
    end
    if not box then return false, "no codebox visible" end

    writeCodeToBox(box, code)
    task.wait(0.05)

    local redeemBtn
    local searchNames = {"submit","redeem","claim","confirm","enter","send","apply","use","check"}
    local p = box.Parent
    for _ = 1, 8 do
        if not p then break end
        for _, d in ipairs(p:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOurGui(d) and d ~= box then
                local n = d.Name:lower()
                local t = ""
                pcall(function() t = d.Text:lower() end)
                for _, sn in ipairs(searchNames) do
                    if n:find(sn) or t:find(sn) then
                        if isVisibleChain(d) then redeemBtn = d; break end
                    end
                end
                if redeemBtn then break end
            end
        end
        if redeemBtn then break end
        p = p.Parent
    end
    if redeemBtn then clickButton(redeemBtn) end
    return true, "fallback used"
end

-- ---------- Поиск remote для уведомлений (без debug) ----------
-- Используем стандартный путь, который есть в игре; ничего не сканируем через getconnections.
local function findNotifyRemote()
    local Packages = ReplicatedStorage:FindFirstChild("Packages")
    if not Packages then return nil end
    local Net = Packages:FindFirstChild("Net")
    if not Net then return nil end
    -- Эвристика: берём все RemoteEvent в Net и возвращаем первый с "notif" в имени
    for _, d in ipairs(Net:GetDescendants()) do
        if d:IsA("RemoteEvent") and (d.Name:lower():find("notif") or d.Name:lower():find("announce")) then
            return d
        end
    end
    -- Если по имени не нашли — вернём nil (без «грязного» сканирования соединений)
    return nil
end

local notifyRemote = findNotifyRemote()

-- ---------- UI ----------
if PlayerGui:FindFirstChild("SourcesHubRedeemerGui") then
    PlayerGui.SourcesHubRedeemerGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SourcesHubRedeemerGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local mainFrame = Instance.new("ImageLabel")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 205)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -102)
mainFrame.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
mainFrame.BackgroundTransparency = 0.1
mainFrame.Image = "rbxassetid://93857225029776"
mainFrame.ImageTransparency = 0.85
mainFrame.ScaleType = Enum.ScaleType.Crop
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Thickness = 1.5

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 44)
topBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
topBar.BackgroundTransparency = 0.4
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 16)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 200, 0, 14)
titleLabel.Position = UDim2.new(0, 12, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "SOURCES HUB REDEEMER"
titleLabel.TextColor3 = Color3.fromRGB(80, 10, 15)
titleLabel.TextSize = 11
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(0, 200, 0, 12)
subLabel.Position = UDim2.new(0, 12, 0, 25)
subLabel.BackgroundTransparency = 1
subLabel.Font = Enum.Font.Gotham
subLabel.Text = "safe rewrite"
subLabel.TextColor3 = Color3.fromRGB(120, 30, 35)
subLabel.TextSize = 10
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.Parent = topBar

local statusDot = Instance.new("TextButton")
statusDot.Size = UDim2.new(0, 10, 0, 10)
statusDot.Position = UDim2.new(1, -18, 0, 17)
statusDot.BackgroundColor3 = Color3.fromRGB(220, 40, 50)
statusDot.BorderSizePixel = 0
statusDot.Text = ""
statusDot.AutoButtonColor = false
statusDot.Parent = topBar
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local function makeButton(text, y, height)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -24, 0, height)
    b.Position = UDim2.new(0, 12, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    b.BackgroundTransparency = 0.35
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.Text = text
    b.TextColor3 = Color3.fromRGB(90, 12, 18)
    b.TextSize = 11
    b.AutoButtonColor = false
    b.Parent = mainFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    local s = Instance.new("UIStroke", b)
    s.Color = Color3.fromRGB(255, 255, 255); s.Thickness = 1
    return b
end

local scanButton = makeButton("START SCAN", 52, 30)
local modeButton = makeButton("MODE: 3 GLOBAL MESSAGES", 88, 30)
modeButton.TextSize = 9
modeButton.TextColor3 = Color3.fromRGB(80, 85, 95)

local previewBox = Instance.new("TextBox")
previewBox.Size = UDim2.new(1, -102, 0, 30)
previewBox.Position = UDim2.new(0, 12, 0, 126)
previewBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
previewBox.BackgroundTransparency = 0.35
previewBox.BorderSizePixel = 0
previewBox.PlaceholderText = "Captured code..."
previewBox.Text = ""
previewBox.TextColor3 = Color3.fromRGB(40, 45, 55)
previewBox.ClearTextOnFocus = false
previewBox.Font = Enum.Font.GothamBold
previewBox.TextSize = 11
previewBox.TextXAlignment = Enum.TextXAlignment.Left
previewBox.Parent = mainFrame
Instance.new("UICorner", previewBox).CornerRadius = UDim.new(0, 10)
local pstroke = Instance.new("UIStroke", previewBox)
pstroke.Color = Color3.fromRGB(255, 255, 255); pstroke.Thickness = 1

local pad = Instance.new("UIPadding", previewBox)
pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)

local redeemButton = Instance.new("TextButton")
redeemButton.Size = UDim2.new(0, 70, 0, 30)
redeemButton.Position = UDim2.new(1, -82, 0, 126)
redeemButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
redeemButton.BorderSizePixel = 0
redeemButton.Text = "REDEEM"
redeemButton.TextColor3 = Color3.fromRGB(90, 12, 18)
redeemButton.Font = Enum.Font.GothamBold
redeemButton.TextSize = 10
redeemButton.Parent = mainFrame
Instance.new("UICorner", redeemButton).CornerRadius = UDim.new(0, 10)
local rstroke = Instance.new("UIStroke", redeemButton)
rstroke.Color = Color3.fromRGB(255, 255, 255); rstroke.Thickness = 1

local bottomRow = Instance.new("Frame")
bottomRow.Size = UDim2.new(1, -24, 0, 30)
bottomRow.Position = UDim2.new(0, 12, 0, 162)
bottomRow.BackgroundTransparency = 1
bottomRow.Parent = mainFrame

local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.new(0, 48, 1, 0)
delayLabel.Position = UDim2.new(0, 10, 0, 0)
delayLabel.BackgroundTransparency = 1
delayLabel.Font = Enum.Font.GothamBold
delayLabel.Text = "Delay:"
delayLabel.TextColor3 = Color3.fromRGB(90, 95, 105)
delayLabel.TextSize = 11
delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.Parent = bottomRow

local delayBox = Instance.new("TextBox")
delayBox.Size = UDim2.new(0, 48, 1, 0)
delayBox.Position = UDim2.new(0, 62, 0, 0)
delayBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
delayBox.BackgroundTransparency = 0.35
delayBox.BorderSizePixel = 0
delayBox.Text = "0.5"
delayBox.TextColor3 = Color3.fromRGB(40, 45, 55)
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 12
delayBox.TextXAlignment = Enum.TextXAlignment.Center
delayBox.ClearTextOnFocus = false
delayBox.Parent = bottomRow
Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 10)
local dstroke = Instance.new("UIStroke", delayBox)
dstroke.Color = Color3.fromRGB(255, 255, 255); dstroke.Thickness = 1

local setButton = Instance.new("TextButton")
setButton.Size = UDim2.new(0, 70, 1, 0)
setButton.Position = UDim2.new(1, -70, 0, 0)
setButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
setButton.BorderSizePixel = 0
setButton.Text = "SET"
setButton.TextColor3 = Color3.fromRGB(90, 12, 18)
setButton.Font = Enum.Font.GothamBold
setButton.TextSize = 10
setButton.Parent = bottomRow
Instance.new("UICorner", setButton).CornerRadius = UDim.new(0, 10)
local sstroke = Instance.new("UIStroke", setButton)
sstroke.Color = Color3.fromRGB(255, 255, 255); sstroke.Thickness = 1

-- hover
local function hover(btn)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.35}):Play()
    end)
end
hover(scanButton); hover(modeButton)
hover(setButton); hover(redeemButton)

statusDot.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- dragging
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
mainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then update(input) end
end)

-- ---------- Состояние ----------
local scanning = false
local buffer = {}
local mode = 3
local delay = 0.5

local function updateDelay()
    local val = tonumber(delayBox.Text)
    if val and val >= 0.05 then
        delay = val
        print("[Safe Redeemer] Delay set to:", delay)
    else
        delayBox.Text = tostring(delay)
    end
end
delayBox.FocusLost:Connect(function(enter) if enter then updateDelay() end end)
delayBox:GetPropertyChangedSignal("Text"):Connect(function()
    local val = tonumber(delayBox.Text)
    if val and val >= 0.05 then delay = val end
end)
setButton.MouseButton1Click:Connect(updateDelay)

local function isValidCode(msg)
    return msg:match("^[A-Za-z0-9]+$") ~= nil
end

local function updatePreview()
    if #buffer == 0 then previewBox.Text = ""; return end
    local count = math.min(#buffer, mode)
    previewBox.Text = table.concat(buffer, "", 1, count)
end

local function processBuffer()
    if not scanning then return end
    while #buffer >= mode do
        local combined = table.concat(buffer, "", 1, mode)
        buffer = {}
        updatePreview()
        typeAndSubmitCode(combined)
        print("[Safe Redeemer] Auto-redeemed: " .. combined)
        task.wait(delay)
    end
    updatePreview()
end

local function onAnnouncement(txt)
    if not scanning or not txt or txt == "" then return end
    local msg = txt:match("^%s*(.-)%s*$")
    if msg and #msg > 0 and isValidCode(msg) then
        table.insert(buffer, msg)
        updatePreview()
        if #buffer >= mode then task.spawn(processBuffer) end
        print("[Safe Redeemer] Captured: " .. msg .. " (buffer: " .. #buffer .. ")")
    end
end

local function toggleScan()
    scanning = not scanning
    if scanning then
        scanButton.Text = "SCANNING..."
        scanButton.BackgroundColor3 = Color3.fromRGB(120, 220, 140)
        scanButton.BackgroundTransparency = 0.2
        statusDot.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
        buffer = {}; updatePreview()
        print("[Safe Redeemer] Scanning started.")
    else
        scanButton.Text = "START SCAN"
        scanButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        scanButton.BackgroundTransparency = 0.35
        statusDot.BackgroundColor3 = Color3.fromRGB(220, 40, 50)
        buffer = {}; updatePreview()
        print("[Safe Redeemer] Scanning stopped.")
    end
end
scanButton.MouseButton1Click:Connect(toggleScan)

modeButton.MouseButton1Click:Connect(function()
    mode = (mode % 4) + 1
    modeButton.Text = "MODE: " .. mode .. " GLOBAL MESSAGE" .. (mode > 1 and "S" or "")
    updatePreview()
    if scanning and #buffer >= mode then task.spawn(processBuffer) end
end)

local function manualRedeem()
    local code = previewBox.Text
    if code and code ~= "" then
        typeAndSubmitCode(code)
        print("[Safe Redeemer] Manually redeemed: " .. code)
        buffer = {}; updatePreview()
    end
end
redeemButton.MouseButton1Click:Connect(manualRedeem)
previewBox.FocusLost:Connect(function(enter) if enter then manualRedeem() end end)

-- ---------- Подписка на уведомления ----------
if notifyRemote then
    notifyRemote.OnClientEvent:Connect(function(txt, ...)
        onAnnouncement(txt)
    end)
    print("[Safe Redeemer] Subscribed to notifyRemote:", notifyRemote:GetFullName())
else
    warn("[Safe Redeemer] Notify remote not found by name. Capture won't work in this game.")
end

print("[Safe Redeemer] Ready. Click 'START SCAN' to begin.")
