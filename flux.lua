--[[
    FluxUI v1.0 - Modern Roblox ImGui Library
    Immediate-mode GUI with modern visuals
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

repeat task.wait() until Players.LocalPlayer

pcall(function()
    if game:GetService("CoreGui"):FindFirstChild("FluxUI") then
        game:GetService("CoreGui"):FindFirstChild("FluxUI"):Destroy()
    end
end)

-- ═══════════════════════════════════════════
-- CORE OBJECT
-- ═══════════════════════════════════════════
local Flux = {}
Flux._started = false
Flux._refreshRequested = false
Flux._widgetDefs = {}
Flux._rootInstance = nil
Flux._rootWidget = {ID = "R", type = "Root", Instance = nil, ZIndex = 0}
Flux._states = {}
Flux._callbacks = {}
Flux._IDStack = {"R"}
Flux._usedIDs = {}
Flux._stackIndex = 1
Flux._cycleTick = 0
Flux._widgetCount = 0
Flux._lastWidget = Flux._rootWidget
Flux._lastVDOM = {["R"] = Flux._rootWidget}
Flux._VDOM = {["R"] = Flux._rootWidget}
Flux._nextWidgetID = nil
Flux._windowZCounter = 10
Flux._dragData = nil
Flux._sliderData = nil
Flux._openDropdownID = nil
Flux._colorPickerData = nil

-- ═══════════════════════════════════════════
-- THEME
-- ═══════════════════════════════════════════
local T = {
    WindowBg        = Color3.fromRGB(13, 13, 20),
    WindowBorder    = Color3.fromRGB(40, 40, 58),
    TitleBg         = Color3.fromRGB(18, 18, 28),
    TitleBgActive   = Color3.fromRGB(24, 24, 36),
    ContentBg       = Color3.fromRGB(16, 16, 24),
    Accent          = Color3.fromRGB(124, 92, 252),
    AccentHover     = Color3.fromRGB(148, 120, 253),
    AccentActive    = Color3.fromRGB(100, 72, 228),
    AccentDim       = Color3.fromRGB(75, 55, 170),
    FrameBg         = Color3.fromRGB(26, 26, 38),
    FrameHover      = Color3.fromRGB(34, 34, 50),
    FrameActive     = Color3.fromRGB(42, 42, 60),
    ButtonBg        = Color3.fromRGB(30, 30, 46),
    ButtonHover     = Color3.fromRGB(40, 40, 60),
    ButtonActive    = Color3.fromRGB(124, 92, 252),
    Text            = Color3.fromRGB(228, 228, 240),
    TextDim         = Color3.fromRGB(130, 130, 158),
    TextDisabled    = Color3.fromRGB(70, 70, 90),
    SliderBg        = Color3.fromRGB(26, 26, 38),
    SliderFill      = Color3.fromRGB(124, 92, 252),
    SliderGrab      = Color3.fromRGB(190, 180, 255),
    CheckBg         = Color3.fromRGB(26, 26, 38),
    CheckMark       = Color3.fromRGB(124, 92, 252),
    InputBg         = Color3.fromRGB(20, 20, 30),
    InputBorder     = Color3.fromRGB(45, 45, 65),
    InputFocus      = Color3.fromRGB(124, 92, 252),
    DropdownBg      = Color3.fromRGB(20, 20, 30),
    DropdownHover   = Color3.fromRGB(34, 34, 50),
    TreeBg          = Color3.fromRGB(22, 22, 34),
    TreeHover       = Color3.fromRGB(30, 30, 44),
    Separator       = Color3.fromRGB(40, 40, 58),
    ScrollBg        = Color3.fromRGB(16, 16, 24),
    ScrollGrab      = Color3.fromRGB(50, 50, 72),
    Shadow          = Color3.fromRGB(0, 0, 4),
    GradientLeft    = Color3.fromRGB(124, 92, 252),
    GradientRight   = Color3.fromRGB(72, 160, 252),
    SuccessColor    = Color3.fromRGB(74, 222, 128),
    WarningColor    = Color3.fromRGB(251, 191, 36),
    ErrorColor      = Color3.fromRGB(239, 68, 68),
    WinCorner       = 8,
    Corner          = 6,
    SmallCorner     = 4,
    Padding         = 12,
    Spacing         = 5,
    TitleH          = 30,
    WidgetH         = 26,
    CheckSize       = 18,
    SliderH         = 22,
    InputH          = 26,
    BtnH            = 26,
    DropH           = 26,
    ProgressH       = 14,
    TreeH           = 24,
    SepH            = 1,
    Font            = Enum.Font.GothamMedium,
    FontBold        = Enum.Font.GothamBold,
    FontSize        = 13,
    TitleSize       = 14,
    SmallSize       = 11,
    TweenTime       = 0.12,
    TweenStyle      = Enum.EasingStyle.Quart,
    TweenDir        = Enum.EasingDirection.Out,
}
Flux.Theme = T

-- ═══════════════════════════════════════════
-- STATE CLASS
-- ═══════════════════════════════════════════
local StateClass = {}
StateClass.__index = StateClass

function StateClass:get()
    return self.value
end

function StateClass:set(newValue)
    if self.value == newValue then return newValue end
    self.value = newValue
    for _, w in pairs(self.ConnectedWidgets) do
        if Flux._widgetDefs[w.type] and Flux._widgetDefs[w.type].UpdateState then
            Flux._widgetDefs[w.type].UpdateState(w)
        end
    end
    for _, fn in pairs(self.ConnectedFunctions) do
        fn(newValue)
    end
    return newValue
end

function StateClass:onChange(fn)
    table.insert(self.ConnectedFunctions, fn)
    return self
end

function Flux.State(initialValue)
    local ID = Flux._getID(2)
    if Flux._states[ID] then
        return Flux._states[ID]
    end
    local s = setmetatable({
        value = initialValue,
        ConnectedWidgets = {},
        ConnectedFunctions = {},
    }, StateClass)
    Flux._states[ID] = s
    return s
end

-- ═══════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════
local function getMouse()
    local ok, pos = pcall(function()
        return UserInputService:GetMouseLocation()
    end)
    return ok and pos and Vector2.new(pos.X, pos.Y - 36) or Vector2.new(0, 0)
end

local function tw(inst, props, dur)
    local t = TweenService:Create(inst,
        TweenInfo.new(dur or T.TweenTime, T.TweenStyle, T.TweenDir),
        props)
    t:Play()
    return t
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or T.Corner)
    c.Parent = parent
    return c
end

local function stroke(parent, col, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = col or T.WindowBorder
    s.Thickness = thick or 1
    s.Transparency = trans or 0.3
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, top, bot, left, right)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, top or 0)
    p.PaddingBottom = UDim.new(0, bot or 0)
    p.PaddingLeft = UDim.new(0, left or 0)
    p.PaddingRight = UDim.new(0, right or 0)
    p.Parent = parent
    return p
end

local function list(parent, pad, dir)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, pad or T.Spacing)
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

local function lighten(c, a)
    a = a or 0.12
    return Color3.new(math.clamp(c.R+a,0,1), math.clamp(c.G+a,0,1), math.clamp(c.B+a,0,1))
end

local function darken(c, a)
    a = a or 0.12
    return Color3.new(math.clamp(c.R-a,0,1), math.clamp(c.G-a,0,1), math.clamp(c.B-a,0,1))
end

local function rgbToHsv(c)
    local r, g, b = c.R, c.G, c.B
    local mx, mn = math.max(r,g,b), math.min(r,g,b)
    local h, s, v = 0, 0, mx
    local d = mx - mn
    s = mx == 0 and 0 or d/mx
    if mx ~= mn then
        if mx == r then h = (g-b)/d + (g<b and 6 or 0)
        elseif mx == g then h = (b-r)/d + 2
        else h = (r-g)/d + 4 end
        h = h/6
    end
    return h, s, v
end

local function pointInRect(px, py, x, y, w, h)
    return px >= x and px <= x+w and py >= y and py <= y+h
end

-- ═══════════════════════════════════════════
-- GUI ROOT
-- ═══════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FluxUI"
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local popupLayer = Instance.new("Frame")
popupLayer.Name = "Popups"
popupLayer.Size = UDim2.fromScale(1, 1)
popupLayer.BackgroundTransparency = 1
popupLayer.ZIndex = 9000
popupLayer.Parent = screenGui

Flux._rootInstance = screenGui
Flux._rootWidget.Instance = screenGui

-- ═══════════════════════════════════════════
-- INPUT SYSTEM
-- ═══════════════════════════════════════════
local mouseDown = false
local mousePos = Vector2.new(0, 0)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        mouseDown = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        mouseDown = false
        Flux._dragData = nil
        Flux._sliderData = nil
        Flux._colorPickerData = nil
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or
       input.UserInputType == Enum.UserInputType.Touch then
        mousePos = Vector2.new(input.Position.X, input.Position.Y)
    end
end)

-- Drag + slider handling each frame
RunService.Heartbeat:Connect(function()
    local mp = getMouse()
    -- Window dragging
    if Flux._dragData and mouseDown then
        local d = Flux._dragData
        local nx = mp.X - d.offset.X
        local ny = mp.Y - d.offset.Y
        d.frame.Position = UDim2.fromOffset(nx, ny)
    end
    -- Slider dragging
    if Flux._sliderData and mouseDown then
        local sd = Flux._sliderData
        local rel = math.clamp((mp.X - sd.bar.AbsolutePosition.X) / sd.bar.AbsoluteSize.X, 0, 1)
        local val = sd.min + rel * (sd.max - sd.min)
        if sd.step then
            val = math.floor(val / sd.step + 0.5) * sd.step
        end
        val = math.clamp(val, math.min(sd.min, sd.max), math.max(sd.min, sd.max))
        if sd.state then sd.state:set(val) end
    end
    -- Color picker dragging
    if Flux._colorPickerData and mouseDown then
        local cp = Flux._colorPickerData
        if cp.mode == "palette" then
            local rx = math.clamp((mp.X - cp.palette.AbsolutePosition.X) / cp.palette.AbsoluteSize.X, 0, 1)
            local ry = math.clamp((mp.Y - cp.palette.AbsolutePosition.Y) / cp.palette.AbsoluteSize.Y, 0, 1)
            cp.h = rx
            cp.s = 1 - ry
            if cp.state then cp.state:set(Color3.fromHSV(cp.h, cp.s, cp.v)) end
        elseif cp.mode == "value" then
            local ry = math.clamp((mp.Y - cp.valueBar.AbsolutePosition.Y) / cp.valueBar.AbsoluteSize.Y, 0, 1)
            cp.v = 1 - ry
            if cp.state then cp.state:set(Color3.fromHSV(cp.h, cp.s, cp.v)) end
        end
    end
end)

-- ═══════════════════════════════════════════
-- CORE ENGINE
-- ═══════════════════════════════════════════
function Flux._getID(offset)
    if Flux._nextWidgetID then
        local id = Flux._nextWidgetID
        Flux._nextWidgetID = nil
        return id
    end
    local id = ""
    local i = 1 + (offset or 1)
    local ok, line = pcall(debug.info, i, "l")
    while ok and line and line ~= -1 and line ~= nil do
        id = id .. "+" .. tostring(line)
        i = i + 1
        ok, line = pcall(debug.info, i, "l")
    end
    if id == "" then
        id = "w" .. tostring(Flux._widgetCount)
    end
    local parentID = Flux._IDStack[Flux._stackIndex]
    local fullID = parentID .. "/" .. id
    Flux._usedIDs[fullID] = (Flux._usedIDs[fullID] or 0) + 1
    return fullID .. ":" .. Flux._usedIDs[fullID]
end

function Flux.SetNextWidgetID(id)
    Flux._nextWidgetID = id
end

function Flux._getParent()
    return Flux._VDOM[Flux._IDStack[Flux._stackIndex]]
end

function Flux._discardWidget(w)
    if w and w.type ~= "Root" then
        local def = Flux._widgetDefs[w.type]
        if def and def.Discard then def.Discard(w) end
        if w.Instance then w.Instance:Destroy() end
        -- Clean up state connections
        if w.states then
            for _, st in pairs(w.states) do
                if st.ConnectedWidgets then
                    st.ConnectedWidgets[w.ID] = nil
                end
            end
        end
    end
end

function Flux._insert(widgetType, args, stateObj)
    local id = Flux._getID(2)
    Flux._widgetCount = Flux._widgetCount + 1

    local existing = Flux._lastVDOM[id]
    local widget
    local isNew = false

    if existing and existing.type == widgetType then
        widget = existing
        Flux._lastVDOM[id] = nil
    else
        if existing then
            Flux._discardWidget(existing)
            Flux._lastVDOM[id] = nil
        end
        isNew = true
        widget = {
            ID = id,
            type = widgetType,
            arguments = args or {},
            events = {},
            states = {},
            ZIndex = Flux._widgetCount,
        }
        local def = Flux._widgetDefs[widgetType]
        widget.Instance = def.Generate(widget, args or {})
        -- Parent to current container
        local parent = Flux._getParent()
        if parent and parent.ContentFrame then
            widget.Instance.Parent = parent.ContentFrame
        else
            widget.Instance.Parent = screenGui
        end
    end

    widget.lastTick = Flux._cycleTick
    widget.arguments = args or {}

    -- Reset per-frame events
    for k in pairs(widget.events) do
        widget.events[k] = false
    end

    -- Handle state binding
    if stateObj and type(stateObj) == "table" and stateObj.ConnectedWidgets then
        widget.states.default = stateObj
        stateObj.ConnectedWidgets[id] = widget
    end

    -- Update widget
    local def = Flux._widgetDefs[widgetType]
    if isNew then
        if def.Init then def.Init(widget, args or {}, stateObj) end
    end
    if def.Update then def.Update(widget, args or {}, stateObj) end
    if stateObj and def.UpdateState then def.UpdateState(widget) end

    Flux._VDOM[id] = widget
    Flux._lastWidget = widget
    widget.Instance.LayoutOrder = Flux._widgetCount

    -- Container push
    if def.hasChildren then
        Flux._stackIndex = Flux._stackIndex + 1
        Flux._IDStack[Flux._stackIndex] = id
    end

    return widget
end

function Flux.End()
    if Flux._stackIndex <= 1 then
        error("FluxUI: Too many calls to Flux.End()")
    end
    Flux._stackIndex = Flux._stackIndex - 1
end

function Flux._cycle()
    Flux._rootWidget.lastTick = Flux._cycleTick

    -- Discard widgets from last frame that weren't rendered this frame
    for id, w in pairs(Flux._lastVDOM) do
        if w.lastTick ~= Flux._cycleTick then
            Flux._discardWidget(w)
        end
    end

    Flux._lastVDOM = Flux._VDOM
    Flux._VDOM = {["R"] = Flux._rootWidget}

    if Flux._refreshRequested then
        Flux._refreshRequested = false
        for id, w in pairs(Flux._lastVDOM) do
            if id ~= "R" then Flux._discardWidget(w) end
        end
        Flux._lastVDOM = {["R"] = Flux._rootWidget}
    end

    Flux._cycleTick = Flux._cycleTick + 1
    Flux._widgetCount = 0
    Flux._stackIndex = 1
    table.clear(Flux._usedIDs)

    -- Run user callbacks
    for _, cb in pairs(Flux._callbacks) do
        cb()
        if Flux._stackIndex ~= 1 then
            Flux._stackIndex = 1
            error("FluxUI: Callback has mismatched End() calls")
        end
    end
end

function Flux.ForceRefresh()
    Flux._refreshRequested = true
end

-- ═══════════════════════════════════════════
-- WIDGET: WINDOW
-- ═══════════════════════════════════════════
Flux._widgetDefs.Window = {
    hasChildren = true,
    Generate = function(widget, args)
        local title = args[1] or "Window"
        local width = args[2] or 320
        local height = args[3] or 400

        -- Main frame
        local win = Instance.new("Frame")
        win.Name = "FluxWindow_" .. title
        win.Size = UDim2.fromOffset(width, T.TitleH + height)
        win.Position = UDim2.fromOffset(100 + Flux._windowZCounter * 3, 80 + Flux._windowZCounter * 3)
        win.BackgroundColor3 = T.WindowBg
        win.BorderSizePixel = 0
        win.ClipsDescendants = false
        win.Active = true
        Flux._windowZCounter = Flux._windowZCounter + 1
        win.ZIndex = Flux._windowZCounter
        corner(win, T.WinCorner)
        stroke(win, T.WindowBorder, 1, 0.25)

        -- Shadow
        local shadow = Instance.new("ImageLabel")
        shadow.Name = "Shadow"
        shadow.Size = UDim2.new(1, 24, 1, 24)
        shadow.Position = UDim2.fromOffset(-12, -6)
        shadow.BackgroundTransparency = 1
        shadow.Image = "rbxassetid://6015897843"
        shadow.ImageColor3 = T.Shadow
        shadow.ImageTransparency = 0.5
        shadow.ScaleType = Enum.ScaleType.Slice
        shadow.SliceCenter = Rect.new(49, 49, 450, 450)
        shadow.ZIndex = -1
        shadow.Parent = win

        -- Accent line at top
        local accent = Instance.new("Frame")
        accent.Name = "Accent"
        accent.Size = UDim2.new(1, -2, 0, 2)
        accent.Position = UDim2.fromOffset(1, 0)
        accent.BackgroundColor3 = Color3.new(1,1,1)
        accent.BorderSizePixel = 0
        accent.ZIndex = 5
        accent.Parent = win
        local aCorner = Instance.new("UICorner")
        aCorner.CornerRadius = UDim.new(0, T.WinCorner)
        aCorner.Parent = accent
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.GradientLeft),
            ColorSequenceKeypoint.new(1, T.GradientRight),
        })
        grad.Parent = accent

        -- Title bar
        local titleBar = Instance.new("Frame")
        titleBar.Name = "TitleBar"
        titleBar.Size = UDim2.new(1, 0, 0, T.TitleH)
        titleBar.BackgroundColor3 = T.TitleBg
        titleBar.BorderSizePixel = 0
        titleBar.ZIndex = 2
        titleBar.Parent = win
        local tbCorner = Instance.new("UICorner")
        tbCorner.CornerRadius = UDim.new(0, T.WinCorner)
        tbCorner.Parent = titleBar
        -- Bottom fill to square off bottom corners of title bar
        local tbFill = Instance.new("Frame")
        tbFill.Size = UDim2.new(1, 0, 0, T.WinCorner)
        tbFill.Position = UDim2.new(0, 0, 1, -T.WinCorner)
        tbFill.BackgroundColor3 = T.TitleBg
        tbFill.BorderSizePixel = 0
        tbFill.ZIndex = 2
        tbFill.Parent = titleBar

        -- Collapse arrow
        local arrow = Instance.new("TextLabel")
        arrow.Name = "Arrow"
        arrow.Size = UDim2.fromOffset(20, T.TitleH)
        arrow.Position = UDim2.fromOffset(8, 0)
        arrow.BackgroundTransparency = 1
        arrow.Text = "▶"
        arrow.TextColor3 = T.TextDim
        arrow.Font = T.Font
        arrow.TextSize = 10
        arrow.Rotation = 90
        arrow.ZIndex = 3
        arrow.Parent = titleBar

        -- Title text
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "Title"
        titleLabel.Size = UDim2.new(1, -70, 1, 0)
        titleLabel.Position = UDim2.fromOffset(30, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        titleLabel.TextColor3 = T.Text
        titleLabel.Font = T.FontBold
        titleLabel.TextSize = T.TitleSize
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.ZIndex = 3
        titleLabel.Parent = titleBar

        -- Close button
        local closeBtn = Instance.new("TextButton")
        closeBtn.Name = "Close"
        closeBtn.Size = UDim2.fromOffset(T.TitleH - 8, T.TitleH - 8)
        closeBtn.Position = UDim2.new(1, -T.TitleH + 2, 0, 4)
        closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        closeBtn.BackgroundTransparency = 0.85
        closeBtn.Text = "×"
        closeBtn.TextColor3 = T.TextDim
        closeBtn.Font = T.FontBold
        closeBtn.TextSize = 18
        closeBtn.BorderSizePixel = 0
        closeBtn.ZIndex = 4
        closeBtn.AutoButtonColor = false
        closeBtn.Parent = titleBar
        corner(closeBtn, T.SmallCorner)

        closeBtn.MouseEnter:Connect(function()
            tw(closeBtn, {BackgroundTransparency = 0.2, TextColor3 = Color3.new(1,1,1)})
        end)
        closeBtn.MouseLeave:Connect(function()
            tw(closeBtn, {BackgroundTransparency = 0.85, TextColor3 = T.TextDim})
        end)

        -- Content area
        local content = Instance.new("Frame")
        content.Name = "Content"
        content.Size = UDim2.new(1, 0, 1, -T.TitleH)
        content.Position = UDim2.fromOffset(0, T.TitleH)
        content.BackgroundColor3 = T.ContentBg
        content.BorderSizePixel = 0
        content.ClipsDescendants = true
        content.ZIndex = 2
        content.Parent = win
        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, T.WinCorner)
        cCorner.Parent = content
        -- Top fill to square off top corners of content
        local cFill = Instance.new("Frame")
        cFill.Size = UDim2.new(1, 0, 0, T.WinCorner)
        cFill.BackgroundColor3 = T.ContentBg
        cFill.BorderSizePixel = 0
        cFill.ZIndex = 2
        cFill.Parent = content

        -- Scrolling frame inside content
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "Scroll"
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = T.ScrollGrab
        scroll.CanvasSize = UDim2.fromOffset(0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.ZIndex = 3
        scroll.Parent = content
        padding(scroll, T.Padding, T.Padding, T.Padding, T.Padding)
        local scrollList = list(scroll, T.Spacing)

        widget.ContentFrame = scroll
        widget._win = win
        widget._titleBar = titleBar
        widget._titleLabel = titleLabel
        widget._content = content
        widget._arrow = arrow
        widget._closeBtn = closeBtn
        widget._collapsed = false
        widget._contentHeight = height
        widget._closedByUser = false

        -- Dragging
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                -- Bring to front
                Flux._windowZCounter = Flux._windowZCounter + 1
                win.ZIndex = Flux._windowZCounter
                local mp = getMouse()
                Flux._dragData = {
                    frame = win,
                    offset = Vector2.new(mp.X - win.AbsolutePosition.X, mp.Y - win.AbsolutePosition.Y),
                }
            end
        end)

        -- Collapse toggle via arrow click
        local function toggleCollapse()
            widget._collapsed = not widget._collapsed
            if widget._collapsed then
                tw(arrow, {Rotation = 0})
                tw(content, {Size = UDim2.new(1, 0, 0, 0)})
                tw(win, {Size = UDim2.fromOffset(win.Size.X.Offset, T.TitleH)})
            else
                tw(arrow, {Rotation = 90})
                tw(content, {Size = UDim2.new(1, 0, 0, widget._contentHeight)})
                tw(win, {Size = UDim2.fromOffset(win.Size.X.Offset, T.TitleH + widget._contentHeight)})
            end
        end

        -- Arrow click area
        local arrowBtn = Instance.new("TextButton")
        arrowBtn.Size = UDim2.fromOffset(28, T.TitleH)
        arrowBtn.BackgroundTransparency = 1
        arrowBtn.Text = ""
        arrowBtn.ZIndex = 4
        arrowBtn.Parent = titleBar
        arrowBtn.MouseButton1Click:Connect(toggleCollapse)

        -- Close button
        closeBtn.MouseButton1Click:Connect(function()
            widget._closedByUser = true
            win.Visible = false
            if widget.states.default then
                widget.states.default:set(false)
            end
        end)

        -- Focus on content click too
        content.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                Flux._windowZCounter = Flux._windowZCounter + 1
                win.ZIndex = Flux._windowZCounter
            end
        end)

        return win
    end,

    Update = function(widget, args)
        local title = args[1] or "Window"
        widget._titleLabel.Text = title
    end,

    Discard = function(widget)
        -- nothing extra
    end,

    UpdateState = function(widget)
        if widget.states.default then
            local open = widget.states.default:get()
            widget.Instance.Visible = open
            widget._closedByUser = not open
        end
    end,
}

-- ═══════════════════════════════════════════
-- WIDGET: TEXT
-- ═══════════════════════════════════════════
Flux._widgetDefs.Text = {
    hasChildren = false,
    Generate = function(widget, args)
        local frame = Instance.new("TextLabel")
        frame.Name = "FluxText"
        frame.Size = UDim2.new(1, 0, 0, 18)
        frame.AutomaticSize = Enum.AutomaticSize.Y
        frame.BackgroundTransparency = 1
        frame.Font = T.Font
        frame.TextSize = T.FontSize
        frame.TextColor3 = T.Text
        frame.TextXAlignment = Enum.TextXAlignment.Left
        frame.TextWrapped = true
        frame.RichText = true
        frame.Text = args[1] or ""
        return frame
    end,
    Update = function(widget, args)
        widget.Instance.Text = args[1] or ""
        if args[2] then widget.Instance.TextColor3 = args[2] end
    end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: SEPARATOR
-- ═══════════════════════════════════════════
Flux._widgetDefs.Separator = {
    hasChildren = false,
    Generate = function(widget, args)
        local frame = Instance.new("Frame")
        frame.Name = "FluxSeparator"
        frame.Size = UDim2.new(1, 0, 0, T.Spacing * 2 + T.SepH)
        frame.BackgroundTransparency = 1
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, 0, 0, T.SepH)
        line.Position = UDim2.fromOffset(0, T.Spacing)
        line.BackgroundColor3 = T.Separator
        line.BorderSizePixel = 0
        line.Parent = frame
        return frame
    end,
    Update = function() end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: BUTTON
-- ═══════════════════════════════════════════
Flux._widgetDefs.Button = {
    hasChildren = false,
    Generate = function(widget, args)
        local text = args[1] or "Button"
        local btn = Instance.new("TextButton")
        btn.Name = "FluxButton"
        btn.Size = UDim2.new(1, 0, 0, T.BtnH)
        btn.AutomaticSize = Enum.AutomaticSize.X
        btn.BackgroundColor3 = T.ButtonBg
        btn.Font = T.Font
        btn.TextSize = T.FontSize
        btn.TextColor3 = T.Text
        btn.Text = text
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        corner(btn, T.Corner)
        stroke(btn, T.WindowBorder, 1, 0.5)
        padding(btn, 0, 0, 12, 12)

        btn.MouseEnter:Connect(function()
            tw(btn, {BackgroundColor3 = T.ButtonHover})
        end)
        btn.MouseLeave:Connect(function()
            tw(btn, {BackgroundColor3 = T.ButtonBg})
        end)
        btn.MouseButton1Down:Connect(function()
            tw(btn, {BackgroundColor3 = T.Accent}, 0.06)
        end)
        btn.MouseButton1Up:Connect(function()
            tw(btn, {BackgroundColor3 = T.ButtonHover})
        end)
        btn.MouseButton1Click:Connect(function()
            widget.events.clicked = true
        end)
        btn.MouseEnter:Connect(function()
            widget.events.hovered = true
        end)
        btn.MouseLeave:Connect(function()
            widget.events.hovered = false
        end)

        widget._btn = btn
        return btn
    end,
    Update = function(widget, args)
        widget._btn.Text = args[1] or "Button"
    end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: CHECKBOX
-- ═══════════════════════════════════════════
Flux._widgetDefs.Checkbox = {
    hasChildren = false,
    Generate = function(widget, args)
        local frame = Instance.new("Frame")
        frame.Name = "FluxCheckbox"
        frame.Size = UDim2.new(1, 0, 0, T.WidgetH)
        frame.BackgroundTransparency = 1

        local box = Instance.new("TextButton")
        box.Name = "Box"
        box.Size = UDim2.fromOffset(T.CheckSize, T.CheckSize)
        box.Position = UDim2.fromOffset(0, (T.WidgetH - T.CheckSize) / 2)
        box.BackgroundColor3 = T.CheckBg
        box.Text = ""
        box.BorderSizePixel = 0
        box.AutoButtonColor = false
        box.Parent = frame
        corner(box, T.SmallCorner)
        stroke(box, T.WindowBorder, 1, 0.4)

        local check = Instance.new("Frame")
        check.Name = "Check"
        check.AnchorPoint = Vector2.new(0.5, 0.5)
        check.Position = UDim2.fromScale(0.5, 0.5)
        check.Size = UDim2.fromOffset(0, 0)
        check.BackgroundColor3 = T.CheckMark
        check.BorderSizePixel = 0
        check.Parent = box
        corner(check, 3)

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, -(T.CheckSize + 8), 1, 0)
        label.Position = UDim2.fromOffset(T.CheckSize + 8, 0)
        label.BackgroundTransparency = 1
        label.Font = T.Font
        label.TextSize = T.FontSize
        label.TextColor3 = T.Text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = args[1] or "Checkbox"
        label.Parent = frame

        widget._box = box
        widget._check = check
        widget._label = label

        box.MouseEnter:Connect(function()
            tw(box, {BackgroundColor3 = T.FrameHover})
        end)
        box.MouseLeave:Connect(function()
            local st = widget.states.default
            local on = st and st:get() or false
            tw(box, {BackgroundColor3 = on and T.AccentDim or T.CheckBg})
        end)
        box.MouseButton1Click:Connect(function()
            widget.events.clicked = true
            local st = widget.states.default
            if st then st:set(not st:get()) end
        end)

        return frame
    end,
    Init = function(widget, args, state)
        if state then
            Flux._widgetDefs.Checkbox.UpdateState(widget)
        end
    end,
    Update = function(widget, args)
        widget._label.Text = args[1] or "Checkbox"
    end,
    UpdateState = function(widget)
        local st = widget.states.default
        if not st then return end
        local on = st:get()
        if on then
            tw(widget._check, {Size = UDim2.fromOffset(T.CheckSize - 6, T.CheckSize - 6)})
            tw(widget._box, {BackgroundColor3 = T.AccentDim})
        else
            tw(widget._check, {Size = UDim2.fromOffset(0, 0)})
            tw(widget._box, {BackgroundColor3 = T.CheckBg})
        end
    end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: SLIDER
-- ═══════════════════════════════════════════
Flux._widgetDefs.Slider = {
    hasChildren = false,
    Generate = function(widget, args)
        local label = args[1] or "Slider"
        local mn = args[2] or 0
        local mx = args[3] or 100
        local step = args[4]

        local frame = Instance.new("Frame")
        frame.Name = "FluxSlider"
        frame.Size = UDim2.new(1, 0, 0, T.SliderH + 18)
        frame.BackgroundTransparency = 1

        -- Label
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Font = T.Font
        lbl.TextSize = T.SmallSize
        lbl.TextColor3 = T.TextDim
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label
        lbl.Parent = frame

        -- Value label
        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0.5, 0, 0, 16)
        valLbl.Position = UDim2.fromScale(0.5, 0)
        valLbl.BackgroundTransparency = 1
        valLbl.Font = T.Font
        valLbl.TextSize = T.SmallSize
        valLbl.TextColor3 = T.Accent
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Text = "0"
        valLbl.Parent = frame

        -- Bar background
        local bar = Instance.new("Frame")
        bar.Name = "Bar"
        bar.Size = UDim2.new(1, 0, 0, T.SliderH)
        bar.Position = UDim2.fromOffset(0, 18)
        bar.BackgroundColor3 = T.SliderBg
        bar.BorderSizePixel = 0
        bar.Parent = frame
        corner(bar, T.SmallCorner)

        -- Fill
        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = T.SliderFill
        fill.BorderSizePixel = 0
        fill.Parent = bar
        corner(fill, T.SmallCorner)
        local fillGrad = Instance.new("UIGradient")
        fillGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.GradientLeft),
            ColorSequenceKeypoint.new(1, T.GradientRight),
        })
        fillGrad.Parent = fill

        -- Grab handle
        local grab = Instance.new("Frame")
        grab.Name = "Grab"
        grab.Size = UDim2.fromOffset(12, T.SliderH + 4)
        grab.AnchorPoint = Vector2.new(0.5, 0.5)
        grab.Position = UDim2.new(0, 0, 0.5, 0)
        grab.BackgroundColor3 = T.SliderGrab
        grab.BorderSizePixel = 0
        grab.ZIndex = 2
        grab.Parent = bar
        corner(grab, 3)

        widget._bar = bar
        widget._fill = fill
        widget._grab = grab
        widget._valLbl = valLbl
        widget._lbl = lbl
        widget._min = mn
        widget._max = mx
        widget._step = step

        -- Interaction
        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                Flux._sliderData = {
                    bar = bar,
                    min = mn,
                    max = mx,
                    step = step,
                    state = widget.states.default,
                }
            end
        end)

        return frame
    end,
    Init = function(widget, args, state)
        if state then
            Flux._widgetDefs.Slider.UpdateState(widget)
        end
    end,
    Update = function(widget, args)
        widget._lbl.Text = args[1] or "Slider"
        widget._min = args[2] or 0
        widget._max = args[3] or 100
        widget._step = args[4]
        -- Update slider data if actively sliding
        if Flux._sliderData and Flux._sliderData.bar == widget._bar then
            Flux._sliderData.min = widget._min
            Flux._sliderData.max = widget._max
            Flux._sliderData.step = widget._step
            Flux._sliderData.state = widget.states.default
        end
    end,
    UpdateState = function(widget)
        local st = widget.states.default
        if not st then return end
        local val = tonumber(st:get()) or 0
        local mn, mx = widget._min, widget._max
        local range = mx - mn
        local pct = range ~= 0 and math.clamp((val - mn) / range, 0, 1) or 0
        widget._fill.Size = UDim2.new(pct, 0, 1, 0)
        widget._grab.Position = UDim2.new(pct, 0, 0.5, 0)
        -- Format value
        local display = val
        if math.floor(val) == val then
            display = string.format("%d", val)
        else
            display = string.format("%.2f", val)
        end
        widget._valLbl.Text = tostring(display)
    end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: INPUT TEXT
-- ═══════════════════════════════════════════
Flux._widgetDefs.InputText = {
    hasChildren = false,
    Generate = function(widget, args)
        local label = args[1] or ""
        local placeholder = args[2] or "Type here..."

        local frame = Instance.new("Frame")
        frame.Name = "FluxInputText"
        frame.Size = UDim2.new(1, 0, 0, T.InputH + (label ~= "" and 18 or 0))
        frame.BackgroundTransparency = 1

        local yOff = 0
        if label ~= "" then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 16)
            lbl.BackgroundTransparency = 1
            lbl.Font = T.Font
            lbl.TextSize = T.SmallSize
            lbl.TextColor3 = T.TextDim
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = label
            lbl.Parent = frame
            widget._lbl = lbl
            yOff = 18
        end

        local box = Instance.new("Frame")
        box.Size = UDim2.new(1, 0, 0, T.InputH)
        box.Position = UDim2.fromOffset(0, yOff)
        box.BackgroundColor3 = T.InputBg
        box.BorderSizePixel = 0
        box.Parent = frame
        corner(box, T.Corner)
        local boxStroke = stroke(box, T.InputBorder, 1, 0.3)

        local textBox = Instance.new("TextBox")
        textBox.Size = UDim2.new(1, -16, 1, 0)
        textBox.Position = UDim2.fromOffset(8, 0)
        textBox.BackgroundTransparency = 1
        textBox.Font = T.Font
        textBox.TextSize = T.FontSize
        textBox.TextColor3 = T.Text
        textBox.PlaceholderText = placeholder
        textBox.PlaceholderColor3 = T.TextDisabled
        textBox.TextXAlignment = Enum.TextXAlignment.Left
        textBox.Text = ""
        textBox.ClearTextOnFocus = false
        textBox.Parent = box

        widget._textBox = textBox
        widget._boxStroke = boxStroke

        textBox.Focused:Connect(function()
            tw(boxStroke, {Color = T.InputFocus, Transparency = 0})
        end)
        textBox.FocusLost:Connect(function(enter)
            tw(boxStroke, {Color = T.InputBorder, Transparency = 0.3})
            widget.events.submitted = enter
            local st = widget.states.default
            if st then st:set(textBox.Text) end
        end)
        textBox:GetPropertyChangedSignal("Text"):Connect(function()
            widget.events.changed = true
            local st = widget.states.default
            if st then
                -- Avoid feedback loops
                if st:get() ~= textBox.Text then
                    st:set(textBox.Text)
                end
            end
        end)

        return frame
    end,
    Init = function(widget, args, state)
        if state then
            widget._textBox.Text = tostring(state:get() or "")
        end
    end,
    Update = function(widget, args)
        if widget._lbl then widget._lbl.Text = args[1] or "" end
        widget._textBox.PlaceholderText = args[2] or "Type here..."
    end,
    UpdateState = function(widget)
        local st = widget.states.default
        if st and widget._textBox.Text ~= tostring(st:get() or "") then
            widget._textBox.Text = tostring(st:get() or "")
        end
    end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: INPUT NUMBER
-- ═══════════════════════════════════════════
Flux._widgetDefs.InputNum = {
    hasChildren = false,
    Generate = function(widget, args)
        local label = args[1] or ""
        local mn = args[2]
        local mx = args[3]
        local step = args[4] or 1

        local frame = Instance.new("Frame")
        frame.Name = "FluxInputNum"
        frame.Size = UDim2.new(1, 0, 0, T.InputH + (label ~= "" and 18 or 0))
        frame.BackgroundTransparency = 1

        local yOff = 0
        if label ~= "" then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 16)
            lbl.BackgroundTransparency = 1
            lbl.Font = T.Font
            lbl.TextSize = T.SmallSize
            lbl.TextColor3 = T.TextDim
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = label
            lbl.Parent = frame
            widget._lbl = lbl
            yOff = 18
        end

        local box = Instance.new("Frame")
        box.Size = UDim2.new(1, 0, 0, T.InputH)
        box.Position = UDim2.fromOffset(0, yOff)
        box.BackgroundColor3 = T.InputBg
        box.BorderSizePixel = 0
        box.Parent = frame
        corner(box, T.Corner)
        local boxStroke = stroke(box, T.InputBorder, 1, 0.3)

        -- Minus button
        local minus = Instance.new("TextButton")
        minus.Size = UDim2.fromOffset(T.InputH, T.InputH)
        minus.BackgroundColor3 = T.FrameBg
        minus.Text = "−"
        minus.TextColor3 = T.Text
        minus.Font = T.FontBold
        minus.TextSize = 16
        minus.BorderSizePixel = 0
        minus.AutoButtonColor = false
        minus.Parent = box
        corner(minus, T.Corner)

        -- Plus button
        local plus = Instance.new("TextButton")
        plus.Size = UDim2.fromOffset(T.InputH, T.InputH)
        plus.Position = UDim2.new(1, -T.InputH, 0, 0)
        plus.BackgroundColor3 = T.FrameBg
        plus.Text = "+"
        plus.TextColor3 = T.Text
        plus.Font = T.FontBold
        plus.TextSize = 16
        plus.BorderSizePixel = 0
        plus.AutoButtonColor = false
        plus.Parent = box
        corner(plus, T.Corner)

        local textBox = Instance.new("TextBox")
        textBox.Size = UDim2.new(1, -(T.InputH * 2 + 8), 1, 0)
        textBox.Position = UDim2.fromOffset(T.InputH + 4, 0)
        textBox.BackgroundTransparency = 1
        textBox.Font = T.Font
        textBox.TextSize = T.FontSize
        textBox.TextColor3 = T.Text
        textBox.Text = "0"
        textBox.ClearTextOnFocus = false
        textBox.Parent = box

        widget._textBox = textBox
        widget._min = mn
        widget._max = mx
        widget._step = step

        local function clampVal(v)
            if mn then v = math.max(mn, v) end
            if mx then v = math.min(mx, v) end
            return v
        end

        minus.MouseButton1Click:Connect(function()
            local st = widget.states.default
            if st then st:set(clampVal((tonumber(st:get()) or 0) - step)) end
        end)
        plus.MouseButton1Click:Connect(function()
            local st = widget.states.default
            if st then st:set(clampVal((tonumber(st:get()) or 0) + step)) end
        end)
        textBox.FocusLost:Connect(function()
            local st = widget.states.default
            local num = tonumber(textBox.Text)
            if st and num then st:set(clampVal(num))
            elseif st then textBox.Text = tostring(st:get()) end
        end)

        for _, b in ipairs({minus, plus}) do
            b.MouseEnter:Connect(function() tw(b, {BackgroundColor3 = T.FrameHover}) end)
            b.MouseLeave:Connect(function() tw(b, {BackgroundColor3 = T.FrameBg}) end)
        end

        return frame
    end,
    Init = function(widget, args, state)
        if state then widget._textBox.Text = tostring(state:get() or 0) end
    end,
    Update = function(widget, args)
        if widget._lbl then widget._lbl.Text = args[1] or "" end
        widget._min = args[2]
        widget._max = args[3]
        widget._step = args[4] or 1
    end,
    UpdateState = function(widget)
        local st = widget.states.default
        if st then widget._textBox.Text = tostring(st:get() or 0) end
    end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: DROPDOWN
-- ═══════════════════════════════════════════
Flux._widgetDefs.Dropdown = {
    hasChildren = false,
    Generate = function(widget, args)
        local label = args[1] or "Select"
        local options = args[2] or {}

        local frame = Instance.new("Frame")
        frame.Name = "FluxDropdown"
        frame.Size = UDim2.new(1, 0, 0, T.DropH + 18)
        frame.BackgroundTransparency = 1
        frame.ClipsDescendants = false

        -- Label
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Font = T.Font
        lbl.TextSize = T.SmallSize
        lbl.TextColor3 = T.TextDim
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label
        lbl.Parent = frame

        -- Button
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, T.DropH)
        btn.Position = UDim2.fromOffset(0, 18)
        btn.BackgroundColor3 = T.InputBg
        btn.Text = ""
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Parent = frame
        corner(btn, T.Corner)
        stroke(btn, T.InputBorder, 1, 0.3)

        local selectedLbl = Instance.new("TextLabel")
        selectedLbl.Size = UDim2.new(1, -30, 1, 0)
        selectedLbl.Position = UDim2.fromOffset(10, 0)
        selectedLbl.BackgroundTransparency = 1
        selectedLbl.Font = T.Font
        selectedLbl.TextSize = T.FontSize
        selectedLbl.TextColor3 = T.Text
        selectedLbl.TextXAlignment = Enum.TextXAlignment.Left
        selectedLbl.Text = "Select..."
        selectedLbl.Parent = btn

        local arrowLbl = Instance.new("TextLabel")
        arrowLbl.Size = UDim2.fromOffset(20, T.DropH)
        arrowLbl.Position = UDim2.new(1, -24, 0, 0)
        arrowLbl.BackgroundTransparency = 1
        arrowLbl.Font = T.Font
        arrowLbl.TextSize = 10
        arrowLbl.TextColor3 = T.TextDim
        arrowLbl.Text = "▼"
        arrowLbl.Parent = btn

        -- Popup (parented to popup layer)
        local popup = Instance.new("Frame")
        popup.Name = "DropdownPopup"
        popup.BackgroundColor3 = T.DropdownBg
        popup.BorderSizePixel = 0
        popup.Visible = false
        popup.ZIndex = 9001
        popup.ClipsDescendants = true
        popup.Parent = popupLayer
        corner(popup, T.Corner)
        stroke(popup, T.WindowBorder, 1, 0.2)

        local popScroll = Instance.new("ScrollingFrame")
        popScroll.Size = UDim2.new(1, 0, 1, 0)
        popScroll.BackgroundTransparency = 1
        popScroll.BorderSizePixel = 0
        popScroll.ScrollBarThickness = 3
        popScroll.ScrollBarImageColor3 = T.ScrollGrab
        popScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        popScroll.CanvasSize = UDim2.fromOffset(0, 0)
        popScroll.Parent = popup
        padding(popScroll, 4, 4, 4, 4)
        list(popScroll, 2)

        widget._lbl = lbl
        widget._btn = btn
        widget._selectedLbl = selectedLbl
        widget._popup = popup
        widget._popScroll = popScroll
        widget._arrowLbl = arrowLbl
        widget._options = {}
        widget._isOpen = false

        local function closeDropdown()
            widget._isOpen = false
            popup.Visible = false
            tw(arrowLbl, {Rotation = 0})
            Flux._openDropdownID = nil
        end

        local function openDropdown()
            -- Close any other open dropdown
            if Flux._openDropdownID and Flux._openDropdownID ~= widget.ID then
                -- will be handled by cycle
            end
            widget._isOpen = true
            Flux._openDropdownID = widget.ID
            -- Position popup below button
            local absPos = btn.AbsolutePosition
            local absSize = btn.AbsoluteSize
            local itemCount = math.min(#(widget._currentOptions or options), 6)
            local popHeight = itemCount * 28 + 8
            popup.Position = UDim2.fromOffset(absPos.X, absPos.Y + absSize.Y + 2)
            popup.Size = UDim2.fromOffset(absSize.X, popHeight)
            popup.Visible = true
            tw(arrowLbl, {Rotation = 180})
        end

        btn.MouseButton1Click:Connect(function()
            if widget._isOpen then closeDropdown() else openDropdown() end
        end)
        btn.MouseEnter:Connect(function() tw(btn, {BackgroundColor3 = T.FrameHover}) end)
        btn.MouseLeave:Connect(function() tw(btn, {BackgroundColor3 = T.InputBg}) end)

        -- Close on outside click
        UserInputService.InputBegan:Connect(function(input)
            if not widget._isOpen then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            task.defer(function()
                local mp = getMouse()
                local inBtn = pointInRect(mp.X, mp.Y, btn.AbsolutePosition.X, btn.AbsolutePosition.Y, btn.AbsoluteSize.X, btn.AbsoluteSize.Y)
                local inPop = pointInRect(mp.X, mp.Y, popup.AbsolutePosition.X, popup.AbsolutePosition.Y, popup.AbsoluteSize.X, popup.AbsoluteSize.Y)
                if not inBtn and not inPop then
                    closeDropdown()
                end
            end)
        end)

        widget._closeDropdown = closeDropdown
        widget._openDropdown = openDropdown
        return frame
    end,
    Init = function(widget, args, state)
        Flux._widgetDefs.Dropdown._buildOptions(widget, args[2] or {})
        if state then
            widget._selectedLbl.Text = tostring(state:get() or "Select...")
        end
    end,
    Update = function(widget, args)
        widget._lbl.Text = args[1] or "Select"
        local newOpts = args[2] or {}
        -- Rebuild options if changed
        if widget._currentOptions then
            local changed = #newOpts ~= #widget._currentOptions
            if not changed then
                for i, v in ipairs(newOpts) do
                    if v ~= widget._currentOptions[i] then changed = true; break end
                end
            end
            if changed then
                Flux._widgetDefs.Dropdown._buildOptions(widget, newOpts)
            end
        end
    end,
    UpdateState = function(widget)
        local st = widget.states.default
        if st then widget._selectedLbl.Text = tostring(st:get() or "Select...") end
    end,
    Discard = function(widget)
        if widget._popup then widget._popup:Destroy() end
    end,
    _buildOptions = function(widget, options)
        widget._currentOptions = options
        -- Clear old options
        for _, child in ipairs(widget._popScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 26)
            optBtn.BackgroundColor3 = T.DropdownBg
            optBtn.Text = tostring(opt)
            optBtn.Font = T.Font
            optBtn.TextSize = T.FontSize
            optBtn.TextColor3 = T.Text
            optBtn.TextXAlignment = Enum.TextXAlignment.Left
            optBtn.BorderSizePixel = 0
            optBtn.AutoButtonColor = false
            optBtn.LayoutOrder = i
            optBtn.Parent = widget._popScroll
            corner(optBtn, T.SmallCorner)
            padding(optBtn, 0, 0, 10, 0)

            optBtn.MouseEnter:Connect(function() tw(optBtn, {BackgroundColor3 = T.DropdownHover}) end)
            optBtn.MouseLeave:Connect(function() tw(optBtn, {BackgroundColor3 = T.DropdownBg}) end)
            optBtn.MouseButton1Click:Connect(function()
                widget.events.selected = true
                widget.events.selectedValue = opt
                local st = widget.states.default
                if st then st:set(opt) end
                widget._closeDropdown()
            end)
        end
    end,
}

-- ═══════════════════════════════════════════
-- WIDGET: TREE (Collapsing Header)
-- ═══════════════════════════════════════════
Flux._widgetDefs.Tree = {
    hasChildren = true,
    Generate = function(widget, args)
        local label = args[1] or "Tree"
        local defaultOpen = args[2] or false

        local frame = Instance.new("Frame")
        frame.Name = "FluxTree"
        frame.Size = UDim2.new(1, 0, 0, T.TreeH)
        frame.BackgroundTransparency = 1
        frame.AutomaticSize = Enum.AutomaticSize.Y
        frame.ClipsDescendants = false

        -- Header button
        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, T.TreeH)
        header.BackgroundColor3 = T.TreeBg
        header.Text = ""
        header.BorderSizePixel = 0
        header.AutoButtonColor = false
        header.Parent = frame
        corner(header, T.SmallCorner)

        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.fromOffset(16, T.TreeH)
        arrow.Position = UDim2.fromOffset(6, 0)
        arrow.BackgroundTransparency = 1
        arrow.Text = "▶"
        arrow.TextColor3 = T.TextDim
        arrow.Font = T.Font
        arrow.TextSize = 9
        arrow.Rotation = defaultOpen and 90 or 0
        arrow.Parent = header

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, -30, 1, 0)
        titleLbl.Position = UDim2.fromOffset(24, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = T.FontBold
        titleLbl.TextSize = T.FontSize
        titleLbl.TextColor3 = T.Text
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Text = label
        titleLbl.Parent = header

        -- Content container
        local content = Instance.new("Frame")
        content.Name = "Content"
        content.Size = UDim2.new(1, -8, 0, 0)
        content.Position = UDim2.fromOffset(8, T.TreeH + 4)
        content.BackgroundTransparency = 1
        content.AutomaticSize = Enum.AutomaticSize.Y
        content.Visible = defaultOpen
        content.ClipsDescendants = true
        content.Parent = frame
        list(content, T.Spacing)

        widget.ContentFrame = content
        widget._header = header
        widget._arrow = arrow
        widget._titleLbl = titleLbl
        widget._expanded = defaultOpen

        header.MouseEnter:Connect(function() tw(header, {BackgroundColor3 = T.TreeHover}) end)
        header.MouseLeave:Connect(function() tw(header, {BackgroundColor3 = T.TreeBg}) end)
        header.MouseButton1Click:Connect(function()
            widget._expanded = not widget._expanded
            content.Visible = widget._expanded
            tw(arrow, {Rotation = widget._expanded and 90 or 0})
        end)

        return frame
    end,
    Update = function(widget, args)
        widget._titleLbl.Text = args[1] or "Tree"
    end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: PROGRESS BAR
-- ═══════════════════════════════════════════
Flux._widgetDefs.ProgressBar = {
    hasChildren = false,
    Generate = function(widget, args)
        local label = args[1] or ""
        local pct = args[2] or 0

        local frame = Instance.new("Frame")
        frame.Name = "FluxProgress"
        frame.Size = UDim2.new(1, 0, 0, T.ProgressH + (label ~= "" and 18 or 0))
        frame.BackgroundTransparency = 1

        local yOff = 0
        if label ~= "" then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0.5, 0, 0, 16)
            lbl.BackgroundTransparency = 1
            lbl.Font = T.Font
            lbl.TextSize = T.SmallSize
            lbl.TextColor3 = T.TextDim
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = label
            lbl.Parent = frame
            widget._lbl = lbl

            local pctLbl = Instance.new("TextLabel")
            pctLbl.Size = UDim2.new(0.5, 0, 0, 16)
            pctLbl.Position = UDim2.fromScale(0.5, 0)
            pctLbl.BackgroundTransparency = 1
            pctLbl.Font = T.Font
            pctLbl.TextSize = T.SmallSize
            pctLbl.TextColor3 = T.Accent
            pctLbl.TextXAlignment = Enum.TextXAlignment.Right
            pctLbl.Text = string.format("%d%%", pct * 100)
            pctLbl.Parent = frame
            widget._pctLbl = pctLbl
            yOff = 18
        end

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 0, T.ProgressH)
        bar.Position = UDim2.fromOffset(0, yOff)
        bar.BackgroundColor3 = T.SliderBg
        bar.BorderSizePixel = 0
        bar.Parent = frame
        corner(bar, T.SmallCorner)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
        fill.BackgroundColor3 = T.Accent
        fill.BorderSizePixel = 0
        fill.Parent = bar
        corner(fill, T.SmallCorner)
        local fillGrad = Instance.new("UIGradient")
        fillGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.GradientLeft),
            ColorSequenceKeypoint.new(1, T.GradientRight),
        })
        fillGrad.Parent = fill

        widget._fill = fill
        return frame
    end,
    Update = function(widget, args)
        local pct = math.clamp(args[2] or 0, 0, 1)
        tw(widget._fill, {Size = UDim2.new(pct, 0, 1, 0)})
        if widget._lbl then widget._lbl.Text = args[1] or "" end
        if widget._pctLbl then widget._pctLbl.Text = string.format("%d%%", pct * 100) end
    end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: COLOR PICKER
-- ═══════════════════════════════════════════
Flux._widgetDefs.ColorPicker = {
    hasChildren = false,
    Generate = function(widget, args)
        local label = args[1] or "Color"

        local frame = Instance.new("Frame")
        frame.Name = "FluxColorPicker"
        frame.Size = UDim2.new(1, 0, 0, T.WidgetH)
        frame.BackgroundTransparency = 1
        frame.AutomaticSize = Enum.AutomaticSize.Y

        -- Preview row
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, T.WidgetH)
        row.BackgroundTransparency = 1
        row.Parent = frame

        local preview = Instance.new("TextButton")
        preview.Size = UDim2.fromOffset(T.WidgetH, T.WidgetH)
        preview.BackgroundColor3 = Color3.new(1, 0, 0)
        preview.Text = ""
        preview.BorderSizePixel = 0
        preview.AutoButtonColor = false
        preview.Parent = row
        corner(preview, T.SmallCorner)
        stroke(preview, T.WindowBorder, 1, 0.4)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -(T.WidgetH + 8), 1, 0)
        lbl.Position = UDim2.fromOffset(T.WidgetH + 8, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = T.Font
        lbl.TextSize = T.FontSize
        lbl.TextColor3 = T.Text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label
        lbl.Parent = row

        -- Picker panel (hidden by default)
        local panel = Instance.new("Frame")
        panel.Name = "Panel"
        panel.Size = UDim2.new(1, 0, 0, 150)
        panel.Position = UDim2.fromOffset(0, T.WidgetH + 4)
        panel.BackgroundColor3 = T.FrameBg
        panel.BorderSizePixel = 0
        panel.Visible = false
        panel.Parent = frame
        corner(panel, T.Corner)

        -- Hue/Saturation palette
        local palette = Instance.new("ImageLabel")
        palette.Name = "Palette"
        palette.Size = UDim2.new(1, -36, 1, -10)
        palette.Position = UDim2.fromOffset(5, 5)
        palette.BackgroundColor3 = Color3.new(1, 1, 1)
        palette.Image = "rbxassetid://698052001"
        palette.BorderSizePixel = 0
        palette.Parent = panel
        corner(palette, T.SmallCorner)

        -- Palette cursor
        local cursor = Instance.new("Frame")
        cursor.Size = UDim2.fromOffset(10, 10)
        cursor.AnchorPoint = Vector2.new(0.5, 0.5)
        cursor.BackgroundTransparency = 1
        cursor.BorderSizePixel = 0
        cursor.Parent = palette
        local cursorInner = Instance.new("Frame")
        cursorInner.Size = UDim2.fromOffset(8, 8)
        cursorInner.AnchorPoint = Vector2.new(0.5, 0.5)
        cursorInner.Position = UDim2.fromScale(0.5, 0.5)
        cursorInner.BackgroundColor3 = Color3.new(1, 1, 1)
        cursorInner.BorderSizePixel = 0
        cursorInner.Parent = cursor
        corner(cursorInner, 4)
        stroke(cursorInner, Color3.new(0,0,0), 2, 0)

        -- Value bar
        local valueBar = Instance.new("ImageLabel")
        valueBar.Name = "ValueBar"
        valueBar.Size = UDim2.new(0, 20, 1, -10)
        valueBar.Position = UDim2.new(1, -27, 0, 5)
        valueBar.Image = "rbxassetid://3641079629"
        valueBar.BackgroundTransparency = 1
        valueBar.BorderSizePixel = 0
        valueBar.Parent = panel
        corner(valueBar, T.SmallCorner)

        -- Value indicator
        local valIndicator = Instance.new("Frame")
        valIndicator.Size = UDim2.new(1, 4, 0, 4)
        valIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
        valIndicator.Position = UDim2.new(0.5, 0, 0, 0)
        valIndicator.BackgroundColor3 = Color3.new(1, 1, 1)
        valIndicator.BorderSizePixel = 0
        valIndicator.Parent = valueBar
        corner(valIndicator, 2)

        widget._preview = preview
        widget._panel = panel
        widget._palette = palette
        widget._cursor = cursor
        widget._valueBar = valueBar
        widget._valIndicator = valIndicator
        widget._lbl = lbl
        widget._open = false
        widget._h = 0
        widget._s = 1
        widget._v = 1

        -- Toggle panel
        preview.MouseButton1Click:Connect(function()
            widget._open = not widget._open
            panel.Visible = widget._open
            if widget._open then
                frame.Size = UDim2.new(1, 0, 0, T.WidgetH + 158)
            else
                frame.Size = UDim2.new(1, 0, 0, T.WidgetH)
            end
        end)

        -- Palette interaction
        palette.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                Flux._colorPickerData = {
                    mode = "palette",
                    palette = palette,
                    valueBar = valueBar,
                    h = widget._h, s = widget._s, v = widget._v,
                    state = widget.states.default,
                    widget = widget,
                }
            end
        end)

        -- Value bar interaction
        valueBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                Flux._colorPickerData = {
                    mode = "value",
                    palette = palette,
                    valueBar = valueBar,
                    h = widget._h, s = widget._s, v = widget._v,
                    state = widget.states.default,
                    widget = widget,
                }
            end
        end)

        return frame
    end,
    Init = function(widget, args, state)
        if state then
            local c = state:get()
            if typeof(c) == "Color3" then
                local h, s, v = rgbToHsv(c)
                widget._h, widget._s, widget._v = h, s, v
                widget._preview.BackgroundColor3 = c
                widget._cursor.Position = UDim2.new(h, 0, 1 - s, 0)
                widget._valIndicator.Position = UDim2.new(0.5, 0, 1 - v, 0)
            end
        end
    end,
    Update = function(widget, args)
        widget._lbl.Text = args[1] or "Color"
        -- Sync from active color picker data
        if Flux._colorPickerData and Flux._colorPickerData.widget == widget then
            local cp = Flux._colorPickerData
            widget._h, widget._s, widget._v = cp.h, cp.s, cp.v
            local c = Color3.fromHSV(cp.h, cp.s, cp.v)
            widget._preview.BackgroundColor3 = c
            widget._cursor.Position = UDim2.new(cp.h, 0, 1 - cp.s, 0)
            widget._valIndicator.Position = UDim2.new(0.5, 0, 1 - cp.v, 0)
        end
    end,
    UpdateState = function(widget)
        local st = widget.states.default
        if not st then return end
        local c = st:get()
        if typeof(c) == "Color3" then
            widget._preview.BackgroundColor3 = c
            local h, s, v = rgbToHsv(c)
            widget._h, widget._s, widget._v = h, s, v
            widget._cursor.Position = UDim2.new(h, 0, 1 - s, 0)
            widget._valIndicator.Position = UDim2.new(0.5, 0, 1 - v, 0)
            if Flux._colorPickerData and Flux._colorPickerData.widget == widget then
                Flux._colorPickerData.h = h
                Flux._colorPickerData.s = s
                Flux._colorPickerData.v = v
            end
        end
    end,
    Discard = function() end,
}

-- ═══════════════════════════════════════════
-- WIDGET: TOOLTIP
-- ═══════════════════════════════════════════
local tooltipFrame = Instance.new("Frame")
tooltipFrame.Name = "Tooltip"
tooltipFrame.BackgroundColor3 = T.TitleBg
tooltipFrame.BorderSizePixel = 0
tooltipFrame.Visible = false
tooltipFrame.ZIndex = 9999
tooltipFrame.AutomaticSize = Enum.AutomaticSize.XY
tooltipFrame.Parent = popupLayer
corner(tooltipFrame, T.SmallCorner)
stroke(tooltipFrame, T.WindowBorder, 1, 0.3)
padding(tooltipFrame, 6, 6, 10, 10)
local tooltipLabel = Instance.new("TextLabel")
tooltipLabel.BackgroundTransparency = 1
tooltipLabel.Font = T.Font
tooltipLabel.TextSize = T.SmallSize
tooltipLabel.TextColor3 = T.Text
tooltipLabel.AutomaticSize = Enum.AutomaticSize.XY
tooltipLabel.TextWrapped = false
tooltipLabel.Parent = tooltipFrame

-- ═══════════════════════════════════════════
-- PUBLIC WIDGET API
-- ═══════════════════════════════════════════
function Flux.Window(args, state)
    return Flux._insert("Window", args, state)
end

function Flux.Text(args)
    return Flux._insert("Text", args)
end

function Flux.Separator()
    return Flux._insert("Separator", {})
end

function Flux.Button(args)
    local w = Flux._insert("Button", args)
    return {
        clicked = function() return w.events.clicked end,
        hovered = function() return w.events.hovered end,
    }
end

function Flux.Checkbox(args, state)
    local w = Flux._insert("Checkbox", args, state)
    return {
        clicked = function() return w.events.clicked end,
        value = function() return w.states.default and w.states.default:get() end,
    }
end

function Flux.Slider(args, state)
    local w = Flux._insert("Slider", args, state)
    return {
        value = function() return w.states.default and w.states.default:get() end,
    }
end

function Flux.InputText(args, state)
    local w = Flux._insert("InputText", args, state)
    return {
        value = function() return w.states.default and w.states.default:get() end,
        submitted = function() return w.events.submitted end,
        changed = function() return w.events.changed end,
    }
end

function Flux.InputNum(args, state)
    local w = Flux._insert("InputNum", args, state)
    return {
        value = function() return w.states.default and w.states.default:get() end,
    }
end

function Flux.Dropdown(args, state)
    local w = Flux._insert("Dropdown", args, state)
    return {
        value = function() return w.states.default and w.states.default:get() end,
        selected = function() return w.events.selected end,
    }
end

function Flux.Tree(args)
    return Flux._insert("Tree", args)
end

function Flux.ProgressBar(args)
    return Flux._insert("ProgressBar", args)
end

function Flux.ColorPicker(args, state)
    local w = Flux._insert("ColorPicker", args, state)
    return {
        value = function() return w.states.default and w.states.default:get() end,
    }
end

function Flux.Tooltip(text)
    if Flux._lastWidget and Flux._lastWidget.events and Flux._lastWidget.events.hovered then
        tooltipFrame.Visible = true
        tooltipLabel.Text = text
        local mp = getMouse()
        tooltipFrame.Position = UDim2.fromOffset(mp.X + 15, mp.Y + 10)
    end
end

function Flux.SameLine()
    -- Insert a horizontal layout marker
    -- Next widget will be placed horizontally
    -- (simplified: just add spacing inline)
end

-- ═══════════════════════════════════════════
-- DEMO WINDOW
-- ════��══════════════════════════════════════
function Flux.ShowDemoWindow()
    Flux.Window({"FluxUI Demo", 360, 500})

        Flux.Text({"Welcome to <b>FluxUI</b>  —  Modern Roblox ImGui"})
        Flux.Text({"A hybrid immediate-mode UI library.", T.TextDim})
        Flux.Separator()

        -- Buttons
        if Flux.Button({"Click Me!"}).clicked() then
            print("[FluxUI] Button clicked!")
        end

        -- Checkbox
        local check1 = Flux.State(false)
        Flux.Checkbox({"Enable Feature"}, check1)

        local check2 = Flux.State(true)
        Flux.Checkbox({"Dark Mode (always on)"}, check2)

        Flux.Separator()

        -- Slider
        local speed = Flux.State(50)
        Flux.Slider({"Speed", 0, 100}, speed)

        local volume = Flux.State(0.75)
        Flux.Slider({"Volume", 0, 1}, volume)

        Flux.Separator()

        -- Input Text
        local username = Flux.State("")
        Flux.InputText({"Username", "Enter your name..."}, username)

        -- Input Number
        local count = Flux.State(10)
        Flux.InputNum({"Count", 0, 100, 1}, count)

        Flux.Separator()

        -- Dropdown
        local selected = Flux.State("Option 1")
        Flux.Dropdown({"Choose Weapon", {"Option 1", "Option 2", "Option 3", "Sword", "Bow", "Staff"}}, selected)

        Flux.Separator()

        -- Progress Bar
        local prog = math.abs(math.sin(tick() * 0.5))
        Flux.ProgressBar({"Loading", prog})

        -- Tree / Collapsing
        Flux.Tree({"Advanced Settings"})
            Flux.Text({"These are hidden settings."})
            local secret = Flux.State(42)
            Flux.Slider({"Secret Value", 0, 100}, secret)
            Flux.Text({"Nested content works!"})
        Flux.End()

        Flux.Tree({"Color Picker", true})
            local myColor = Flux.State(Color3.fromRGB(124, 92, 252))
            Flux.ColorPicker({"Accent Color"}, myColor)
        Flux.End()

        Flux.Separator()
        Flux.Text({"FluxUI v1.0  •  Immediate Mode  •  Modern Dark Theme", T.TextDisabled})

    Flux.End()
end

-- ═══════════════════════════════════════════
-- CONNECTION & LIFECYCLE
-- ═══════════════════════════════════════════
function Flux:Connect(callback)
    if not Flux._started then
        Flux._started = true
        RunService.Heartbeat:Connect(function()
            tooltipFrame.Visible = false
            Flux._cycle()
        end)
    end
    table.insert(Flux._callbacks, callback)
    return Flux
end

function Flux:Destroy()
    Flux._started = false
    Flux._callbacks = {}
    for id, w in pairs(Flux._lastVDOM) do
        if id ~= "R" then Flux._discardWidget(w) end
    end
    Flux._lastVDOM = {["R"] = Flux._rootWidget}
    Flux._VDOM = {["R"] = Flux._rootWidget}
    Flux._states = {}
    screenGui:Destroy()
end

function Flux.UpdateTheme(changes)
    for k, v in pairs(changes) do
        T[k] = v
    end
    Flux.ForceRefresh()
end

return Flux
