--!strict
-- UI kit: one cartoon style for the whole game, in the style players know from top Roblox
-- simulators. Bright panels, thick dark outlines, white text with a dark outline (readable on
-- any background and on phones), chunky candy buttons that squash when pressed, a dimmed backdrop
-- behind panels and a title tab on the panel's top edge.
-- Icons are emoji so the game needs no image uploads; swap Kit.Icons for "rbxassetid://" images
-- later if you want custom art.

local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.Colors = {
	-- surfaces
	Panel = Color3.fromRGB(58, 132, 240),
	PanelLight = Color3.fromRGB(96, 168, 255),
	Card = Color3.fromRGB(104, 172, 255),
	Header = Color3.fromRGB(38, 92, 200),
	Stroke = Color3.fromRGB(16, 24, 56),
	Backdrop = Color3.fromRGB(6, 8, 20),
	Hud = Color3.fromRGB(22, 30, 62), -- HUD pills over the 3D world
	-- text
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(214, 228, 255),
	-- meaning
	Coins = Color3.fromRGB(255, 212, 60),
	Essence = Color3.fromRGB(214, 160, 255),
	Good = Color3.fromRGB(72, 206, 88),
	Bad = Color3.fromRGB(242, 72, 72),
	Accent = Color3.fromRGB(255, 160, 40),
	Premium = Color3.fromRGB(178, 92, 255),
	Locked = Color3.fromRGB(138, 146, 170),
}
local C = Kit.Colors

Kit.Fonts = {
	Title = Enum.Font.FredokaOne,
	Bold = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
}

Kit.Icons = {
	Coins = "💰",
	Essence = "💎",
	Level = "⭐",
	Goal = "🎯",
	Day = "☀️",
	Night = "🌙",
	Warning = "⚠️",
	Help = "❓",
	Pets = "🐰",
	Friends = "👥",
	Ranks = "🏆",
	Store = "🛒",
	Season = "🌕",
	Style = "🎨",
	Attack = "⚔️",
	Lock = "🔒",
	Check = "✓",
	Crown = "👑",
	Monster = "👹",
	Hunger = "🍖",
	Seed = "🌱",
	Quests = "📜",
	Rebirth = "🔁",
	Decor = "🪴",
	Garden = "🪴",
	Upgrades = "🔧",
}

function Kit.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end

function Kit.Corner(radius: number?): UICorner
	return Kit.New("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Kit.Padding(px: number, right: number?): UIPadding
	return Kit.New("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, right or px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

-- Thick dark border outline
function Kit.Stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.New("UIStroke", {
		Color = color or C.Stroke,
		Thickness = thickness or 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- Dark outline around text so it reads on any color
function Kit.TextStroke(size: number?): UIStroke
	local s = size or 18
	return Kit.New("UIStroke", {
		Color = C.Stroke,
		Thickness = if s >= 24 then 2.5 elseif s >= 17 then 2 else 1.4,
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- Vertical sheen: lighter on top. Multiplies the background, so it follows color changes.
function Kit.Gradient(bottom: number?): UIGradient
	local shade = bottom or 0.8
	return Kit.New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(shade, shade, shade)),
	})
end

function Kit.Label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Kit.Fonts.Bold,
		TextColor3 = C.Text,
		TextSize = 18,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in props do
		defaults[key] = value
	end
	if defaults.Font == Enum.Font.Gotham or defaults.Font == Enum.Font.GothamMedium then
		defaults.Font = Kit.Fonts.Body
	elseif defaults.Font == Enum.Font.GothamBold or defaults.Font == Enum.Font.GothamBlack then
		defaults.Font = Kit.Fonts.Bold
	end
	local label = Kit.New("TextLabel", defaults)
	Kit.TextStroke(defaults.TextSize).Parent = label
	return label
end

-- Squash on press, grow a little on hover. Safe to call on any GuiButton.
function Kit.Pressable(button: GuiButton)
	local scale = Kit.New("UIScale", { Parent = button })
	local fast = TweenInfo.new(0.08, Enum.EasingStyle.Quad)
	local bounce = TweenInfo.new(0.18, Enum.EasingStyle.Back)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, fast, { Scale = 1.05 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, fast, { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, bounce, { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, bounce, { Scale = 1 }):Play()
	end)
end

function Kit.Button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults: { [string]: any } = {
		BackgroundColor3 = C.Accent,
		Font = Kit.Fonts.Title,
		TextColor3 = C.Text,
		TextSize = 18,
		TextWrapped = true,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(120, 46),
	}
	for key, value in props do
		defaults[key] = value
	end
	local locked = defaults.BackgroundColor3 == C.Locked
	if locked then
		defaults.TextColor3 = Color3.fromRGB(235, 238, 245)
	end
	local button = Kit.New("TextButton", defaults, {
		Kit.Corner(14),
		Kit.Gradient(if locked then 0.92 else 0.72),
		Kit.Stroke(C.Stroke, 3),
		Kit.TextStroke(defaults.TextSize),
	})
	if not locked then
		Kit.Pressable(button)
	end
	button.Activated:Connect(onClick)
	return button
end

-- Rounded card frame (any size); children go inside
function Kit.Card(props: { [string]: any }, children: { Instance }?): Frame
	local defaults: { [string]: any } = {
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
	}
	for key, value in props do
		defaults[key] = value
	end
	local frame = Kit.New("Frame", defaults, { Kit.Corner(16), Kit.Stroke(C.Stroke, 3), Kit.Gradient(0.85) })
	for _, child in children or {} do
		child.Parent = frame
	end
	return frame
end

-- Dark rounded pill used on the HUD over the 3D world
function Kit.Pill(props: { [string]: any }, children: { Instance }?): Frame
	local defaults: { [string]: any } = {
		BackgroundColor3 = C.Hud,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}
	for key, value in props do
		defaults[key] = value
	end
	local frame = Kit.New("Frame", defaults, { Kit.Corner(14), Kit.Stroke(C.Stroke, 3) })
	for _, child in children or {} do
		child.Parent = frame
	end
	return frame
end

-- Small rounded status chip (Claimed, Locked, NEW...)
function Kit.Chip(props: { [string]: any }): TextLabel
	local color = props.BackgroundColor3 or C.Header
	local defaults: { [string]: any } = {
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		Font = Kit.Fonts.Title,
		TextSize = 15,
		TextColor3 = C.Text,
		Size = UDim2.fromOffset(80, 28),
	}
	for key, value in props do
		defaults[key] = value
	end
	local chip = Kit.Label(defaults)
	Kit.Corner(12).Parent = chip
	Kit.Stroke(C.Stroke, 2.5).Parent = chip
	Kit.Gradient(0.8).Parent = chip
	return chip
end

-- Red notification bubble with a number, on the top-right corner of a button
function Kit.Badge(parent: GuiObject): TextLabel
	local badge = Kit.Label({
		Name = "Badge",
		Text = "",
		TextSize = 14,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Bad,
		Visible = false,
		ZIndex = (parent.ZIndex or 1) + 5,
		Parent = parent,
	})
	Kit.Corner(12).Parent = badge
	Kit.Stroke(Color3.new(1, 1, 1), 2).Parent = badge
	return badge
end

-- Progress bar; returns (background, fill). Use Kit.SetBar to show progress.
function Kit.Bar(props: { [string]: any }, fillColor: Color3?): (Frame, Frame)
	local defaults: { [string]: any } = {
		BackgroundColor3 = Color3.fromRGB(18, 24, 50),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 12),
	}
	for key, value in props do
		defaults[key] = value
	end
	local back = Kit.New("Frame", defaults, { Kit.Corner(8), Kit.Stroke(C.Stroke, 2) })
	local fill = Kit.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = fillColor or C.Good,
		BorderSizePixel = 0,
		ZIndex = (defaults.ZIndex or 1) + 1,
		Parent = back,
	}, { Kit.Corner(8), Kit.Gradient(0.65) })
	return back, fill
end

function Kit.SetBar(fill: Frame, fraction: number)
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.Visible = fraction > 0.001
end

-- Centered modal panel over a dimmed backdrop (tap outside to close). Title sits on a tab across
-- the top edge, close button on the top-right corner. Returns the panel and its scrolling list.
function Kit.Panel(parent: Instance, title: string, onClose: () -> (), animate: boolean?): (Frame, ScrollingFrame)
	local backdrop = Kit.New("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Backdrop,
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 19,
		Parent = parent,
	})
	backdrop.Activated:Connect(onClose)

	local panel = Kit.New("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromScale(0.92, 0.8),
		BackgroundColor3 = C.Panel,
		ZIndex = 20,
		Parent = parent,
	}, {
		Kit.Corner(24),
		Kit.Stroke(C.Stroke, 4),
		Kit.Gradient(0.78),
		Kit.New("UISizeConstraint", { MaxSize = Vector2.new(560, 600) }),
	})
	panel.Destroying:Connect(function()
		backdrop:Destroy()
	end)

	-- Title tab across the top edge
	local tab = Kit.New("Frame", {
		Name = "Tab",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Accent,
		ZIndex = 24,
		Parent = panel,
	}, { Kit.Corner(16), Kit.Stroke(C.Stroke, 4), Kit.Gradient(0.75), Kit.New("UIPadding", { PaddingLeft = UDim.new(0, 26), PaddingRight = UDim.new(0, 26) }) })
	Kit.Label({
		Text = title,
		Font = Kit.Fonts.Title,
		TextSize = 28,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 25,
		Parent = tab,
	})

	local closeButton = Kit.Button({
		Text = "X",
		TextSize = 24,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = C.Bad,
		ZIndex = 26,
		Parent = panel,
	}, onClose)
	closeButton:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)

	local list = Kit.New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Stroke,
		ScrollBarImageTransparency = 0.2,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 21,
		Parent = panel,
	}, {
		Kit.New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		Kit.New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 16) }),
	})

	if animate then
		local scale = Kit.New("UIScale", { Scale = 0.85, Parent = panel })
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		backdrop.BackgroundTransparency = 1
		TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
	end
	return panel, list
end

-- A rounded card row inside a list
function Kit.Row(parent: Instance, order: number, height: number?): Frame
	return Kit.New("Frame", {
		Size = UDim2.new(1, 0, 0, height or 64),
		BackgroundColor3 = C.Card,
		LayoutOrder = order,
		ZIndex = 22,
		Parent = parent,
	}, { Kit.Corner(14), Kit.Padding(8, 10), Kit.Stroke(C.Stroke, 2.5), Kit.Gradient(0.88) })
end

function Kit.Input(props: { [string]: any }): TextBox
	local defaults: { [string]: any } = {
		BackgroundColor3 = Color3.fromRGB(245, 248, 255),
		Font = Kit.Fonts.Bold,
		TextColor3 = C.Stroke,
		PlaceholderColor3 = Color3.fromRGB(120, 130, 160),
		TextSize = 17,
		ClearTextOnFocus = false,
		Text = "",
		Size = UDim2.fromOffset(80, 40),
		ZIndex = 23,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Kit.New("TextBox", defaults, { Kit.Corner(10), Kit.Stroke(C.Stroke, 2.5) })
end

-- Small button placed from the right edge of a row (index 1 = rightmost)
function Kit.RowButton(row: Instance, index: number, text: string, color: Color3?, onClick: () -> (), width: number?): TextButton
	local w = width or 80
	return Kit.Button({
		Text = text,
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(index - 1) * (w + 8), 0.5, 0),
		Size = UDim2.fromOffset(w, 42),
		BackgroundColor3 = color or C.Accent,
		ZIndex = 23,
		Parent = row,
	}, onClick)
end

-- Section heading inside a list
function Kit.Heading(parent: Instance, text: string, order: number): TextLabel
	local label = Kit.Label({
		Text = text,
		Font = Kit.Fonts.Title,
		TextSize = 24,
		TextColor3 = C.Coins,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = order,
		ZIndex = 22,
		Parent = parent,
	})
	Kit.New("UIPadding", { PaddingTop = UDim.new(0, 8), Parent = label })
	return label
end

return Kit
