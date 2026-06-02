local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CustomChatRemote = ReplicatedStorage:WaitForChild("CustomChatRemote")
local gui = script.Parent

local USE_CUSTOM_CHAT = true

local MAX_STORED_MESSAGES = 120
local CHAT_WIDTH = 280
local CHAT_HEIGHT = 100
local INPUT_HEIGHT = 22
local LINE_HEIGHT = 18
local ROW_GAP = 3
local CHAT_TEXT_SIZE = 14
local PLACEHOLDER_TEXT_SIZE = 12
local LETTER_FADE_TIME = 0.12
local NAME_TWEEN_TIME = 0.18
local BODY_TWEEN_TIME = 0.24
local BOTTOM_PADDING = 18
local CHAT_MOVEMENT_SINK_ACTION = "CustomChatSinkMovement"

local textChannels = TextChatService:WaitForChild("TextChannels", 10)
local generalChannel = textChannels and textChannels:WaitForChild("RBXGeneral", 10) or nil

local chatData = {}
local renderedRows = {}
local rowPool = {}
local previousInputText = ""
local inputScrollOffset = 0
local nextMessageId = 0
local totalContentHeight = 0
local scrollTarget = 0
local scrollTween = nil
local suppressOpeningSlash = false
local customChatOpen = true
local mirroringRobloxChatButton = false

local function showRobloxChat()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	end)

	pcall(function()
		local windowConfig = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if windowConfig then
			windowConfig.Enabled = true
		end
	end)

	pcall(function()
		local inputConfig = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if inputConfig then
			inputConfig.Enabled = true
		end
	end)

	pcall(function()
		local bubbleConfig = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
		if bubbleConfig then
			bubbleConfig.Enabled = true
		end
	end)
end

if not USE_CUSTOM_CHAT then
	gui.Enabled = false
	showRobloxChat()
	task.spawn(function()
		for _ = 1, 20 do
			showRobloxChat()
			task.wait(0.5)
		end
	end)
	return
end

local function hideRobloxChat()
	pcall(function()
		-- Keep Roblox's chat/topbar button available while the custom UI handles messages.
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	end)

	pcall(function()
		local windowConfig = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if windowConfig then
			windowConfig.Enabled = false
		end
	end)

	pcall(function()
		local inputConfig = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if inputConfig then
			inputConfig.Enabled = false
		end
	end)

	pcall(function()
		local bubbleConfig = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
		if bubbleConfig then
			bubbleConfig.Enabled = false
		end
	end)
end

hideRobloxChat()
task.spawn(function()
	for _ = 1, 20 do
		hideRobloxChat()
		task.wait(0.5)
	end
end)

gui.DisplayOrder = 900
gui.Enabled = true

local root = Instance.new("Frame")
root.Name = "ChatRoot"
root.AnchorPoint = Vector2.new(1, 1)
root.BackgroundTransparency = 1
root.BorderSizePixel = 0
root.Position = UDim2.new(1, -18, 1, -BOTTOM_PADDING)
root.Size = UDim2.fromOffset(CHAT_WIDTH, CHAT_HEIGHT)
root.Parent = gui

local function setCustomChatOpen(open)
	customChatOpen = open
	root.Visible = open
	if not open and input:IsFocused() then
		input:ReleaseFocus(false)
	end
end

local function mirrorRobloxChatButton()
	if mirroringRobloxChatButton then
		return
	end

	local windowConfig = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if not windowConfig then
		return
	end

	if windowConfig.Enabled then
		mirroringRobloxChatButton = true
		setCustomChatOpen(not customChatOpen)
		windowConfig.Enabled = false
		local inputConfig = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if inputConfig then
			inputConfig.Enabled = false
		end
		task.defer(function()
			mirroringRobloxChatButton = false
		end)
	end
end

local chatWindowConfig = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
if chatWindowConfig then
	chatWindowConfig:GetPropertyChangedSignal("Enabled"):Connect(mirrorRobloxChatButton)
end

local messages = Instance.new("ScrollingFrame")
messages.Name = "Messages"
messages.Active = true
messages.BackgroundTransparency = 1
messages.BorderSizePixel = 0
messages.CanvasSize = UDim2.fromOffset(0, 0)
messages.ClipsDescendants = true
messages.Position = UDim2.fromOffset(0, 0)
messages.ScrollBarThickness = 0
messages.ScrollingDirection = Enum.ScrollingDirection.Y
messages.Size = UDim2.new(1, 0, 1, -(INPUT_HEIGHT + 3))
messages.Parent = root

local inputShell = Instance.new("Frame")
inputShell.Name = "InputShell"
inputShell.AnchorPoint = Vector2.new(0, 1)
inputShell.BackgroundTransparency = 1
inputShell.BorderSizePixel = 0
inputShell.Position = UDim2.new(0, 0, 1, 0)
inputShell.Size = UDim2.new(1, 0, 0, INPUT_HEIGHT)
inputShell.Parent = root

local inputPrefix = Instance.new("TextLabel")
inputPrefix.Name = "Prefix"
inputPrefix.BackgroundTransparency = 1
inputPrefix.FontFace = Font.fromEnum(Enum.Font.GothamBold)
inputPrefix.Position = UDim2.fromOffset(0, 0)
inputPrefix.Size = UDim2.fromOffset(12, INPUT_HEIGHT)
inputPrefix.Text = ">"
inputPrefix.TextColor3 = Color3.fromRGB(255, 65, 72)
inputPrefix.TextSize = CHAT_TEXT_SIZE
inputPrefix.TextXAlignment = Enum.TextXAlignment.Left
inputPrefix.TextTransparency = 0.1
inputPrefix.Parent = inputShell

local inputVisual = Instance.new("Frame")
inputVisual.Name = "InputVisual"
inputVisual.BackgroundTransparency = 1
inputVisual.ClipsDescendants = true
inputVisual.Position = UDim2.fromOffset(13, 0)
inputVisual.Size = UDim2.new(1, -13, 1, 0)
inputVisual.Parent = inputShell

local inputVisualLayout = Instance.new("UIListLayout")
inputVisualLayout.FillDirection = Enum.FillDirection.Horizontal
inputVisualLayout.SortOrder = Enum.SortOrder.LayoutOrder
inputVisualLayout.VerticalAlignment = Enum.VerticalAlignment.Center
inputVisualLayout.Parent = inputVisual

local inputTextLayer = Instance.new("Frame")
inputTextLayer.Name = "InputTextLayer"
inputTextLayer.BackgroundTransparency = 1
inputTextLayer.Position = UDim2.fromOffset(0, 0)
inputTextLayer.Size = UDim2.new(1, 0, 1, 0)
inputTextLayer.Parent = inputVisual

inputVisualLayout.Parent = inputTextLayer

local placeholder = Instance.new("TextLabel")
placeholder.Name = "Placeholder"
placeholder.BackgroundTransparency = 1
placeholder.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
placeholder.Position = UDim2.fromOffset(13, 0)
placeholder.Size = UDim2.new(1, -13, 1, 0)
placeholder.Text = "press / to chat"
placeholder.TextColor3 = Color3.fromRGB(170, 125, 122)
placeholder.TextSize = PLACEHOLDER_TEXT_SIZE
placeholder.TextTransparency = 0.18
placeholder.TextXAlignment = Enum.TextXAlignment.Left
placeholder.Parent = inputShell

local input = Instance.new("TextBox")
input.Name = "Input"
input.BackgroundTransparency = 1
input.ClearTextOnFocus = false
input.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
input.Position = UDim2.fromOffset(13, 0)
input.Size = UDim2.new(1, -13, 1, 0)
input.Text = ""
input.TextColor3 = Color3.fromRGB(255, 239, 235)
input.TextSize = CHAT_TEXT_SIZE
input.TextTransparency = 1
input.TextXAlignment = Enum.TextXAlignment.Left
input.Parent = inputShell

local function getInputTextWidth(text)
	if text == "" then
		return 0
	end

	return TextService:GetTextSize(text, input.TextSize, Enum.Font.GothamMedium, Vector2.new(10000, INPUT_HEIGHT)).X
end

local function trim(text)
	return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

local function getDisplayName(message)
	if message.TextSource then
		local sender = Players:GetPlayerByUserId(message.TextSource.UserId)
		if sender then
			return sender.DisplayName ~= "" and sender.DisplayName or sender.Name
		end
	end

	local prefix = message.PrefixText or "Player"
	prefix = string.gsub(prefix, "<.->", "")
	prefix = string.gsub(prefix, ":%s*$", "")
	return prefix ~= "" and prefix or "Player"
end

local function recycleRow(row)
	row.Visible = false
	row.Parent = nil
	row.NameLabel.TextTransparency = 0
	row.BodyLabel.TextTransparency = 0
	row:SetAttribute("Animating", false)
	row:SetAttribute("RenderId", nil)
	table.insert(rowPool, row)
end

local function getRow()
	local row = table.remove(rowPool)
	if row then
		return row
	end

	row = Instance.new("Frame")
	row.Name = "Message"
	row.BackgroundTransparency = 1

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	nameLabel.RichText = false
	nameLabel.Size = UDim2.fromOffset(0, LINE_HEIGHT)
	nameLabel.TextColor3 = Color3.fromRGB(255, 72, 78)
	nameLabel.TextSize = CHAT_TEXT_SIZE
	nameLabel.TextTruncate = Enum.TextTruncate.None
	nameLabel.TextWrapped = false
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Top
	nameLabel.Parent = row

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "BodyLabel"
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	bodyLabel.RichText = false
	bodyLabel.TextColor3 = Color3.fromRGB(241, 228, 226)
	bodyLabel.TextSize = CHAT_TEXT_SIZE
	bodyLabel.TextTruncate = Enum.TextTruncate.None
	bodyLabel.TextWrapped = true
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.Parent = row

	return row
end

local function measureText(text, width)
	width = math.max(1, width)
	return TextService:GetTextSize(text, CHAT_TEXT_SIZE, Enum.Font.GothamMedium, Vector2.new(width, 1000))
end

local function recalculateLayout()
	local y = 0

	for _, data in ipairs(chatData) do
		local nameSize = measureText(data.nameText, CHAT_WIDTH)
		data.nameWidth = math.min(nameSize.X + 4, CHAT_WIDTH - 36)

		local availableFirstLineWidth = math.max(30, CHAT_WIDTH - data.nameWidth)
		local bodySize = measureText(data.bodyText, availableFirstLineWidth)
		data.height = math.max(LINE_HEIGHT, math.ceil(bodySize.Y)) + ROW_GAP
		data.y = y
		data.bodyWidth = availableFirstLineWidth
		y += data.height
	end

	totalContentHeight = y
	messages.CanvasSize = UDim2.fromOffset(0, totalContentHeight)
end

local function getMaxScroll()
	return math.max(0, totalContentHeight - messages.AbsoluteSize.Y)
end

local function setCanvasPosition(y)
	scrollTarget = math.clamp(y, 0, getMaxScroll())
	messages.CanvasPosition = Vector2.new(0, scrollTarget)
end

local renderQueued = false
local queueRender
local function renderVisibleRows()
	renderQueued = false

	local viewportTop = messages.CanvasPosition.Y
	local viewportBottom = viewportTop + messages.AbsoluteSize.Y
	local stillVisible = {}

	for index, data in ipairs(chatData) do
		if data.y + data.height < viewportTop or data.y > viewportBottom then
			continue
		end

		stillVisible[index] = true

		local row = renderedRows[index]
		if not row then
			row = getRow()
			renderedRows[index] = row
			row.Parent = messages
			row.Visible = true
			row:SetAttribute("RenderId", data.id)
			row.NameLabel.TextTransparency = data.seen and 0 or 1
			row.BodyLabel.TextTransparency = data.seen and 0 or 1
			row.Position = UDim2.fromOffset(data.seen and 0 or -18, data.y + (data.seen and 0 or 4))
			row:SetAttribute("Animating", not data.seen)

			if not data.seen then
				data.seen = true
				TweenService:Create(row, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = UDim2.fromOffset(0, data.y),
				}):Play()

				TweenService:Create(row.NameLabel, TweenInfo.new(NAME_TWEEN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					TextTransparency = 0,
				}):Play()

				task.delay(0.07, function()
					if row.Parent and row:GetAttribute("RenderId") == data.id then
						TweenService:Create(row.BodyLabel, TweenInfo.new(BODY_TWEEN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
							TextTransparency = 0,
						}):Play()
					end
				end)

				task.delay(0.36, function()
					if row.Parent and row:GetAttribute("RenderId") == data.id then
						row:SetAttribute("Animating", false)
						queueRender()
					end
				end)
			end
		else
			row.Position = UDim2.fromOffset(0, data.y)
		end

		row.Size = UDim2.fromOffset(CHAT_WIDTH, data.height)
		row.NameLabel.Text = data.nameText
		row.NameLabel.Size = UDim2.fromOffset(data.nameWidth, LINE_HEIGHT)
		row.NameLabel.TextColor3 = data.isSystem and Color3.fromRGB(190, 110, 255) or Color3.fromRGB(255, 72, 78)

		row.BodyLabel.Text = data.bodyText
		row.BodyLabel.Position = UDim2.fromOffset(data.nameWidth, 0)
		row.BodyLabel.Size = UDim2.fromOffset(data.bodyWidth, data.height)
		row.BodyLabel.TextColor3 = data.isSystem and Color3.fromRGB(220, 185, 255) or Color3.fromRGB(241, 228, 226)

		if data.seen and not row:GetAttribute("Animating") then
			row.NameLabel.TextTransparency = 0
			row.BodyLabel.TextTransparency = 0
		end
	end

	for index, row in pairs(renderedRows) do
		if not stillVisible[index] then
			renderedRows[index] = nil
			recycleRow(row)
		end
	end
end

function queueRender()
	if renderQueued then
		return
	end
	renderQueued = true
	task.defer(renderVisibleRows)
end

local function smoothScrollToBottom()
	local maxScroll = getMaxScroll()
	scrollTarget = maxScroll

	if scrollTween then
		scrollTween:Cancel()
	end

	scrollTween = TweenService:Create(messages, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		CanvasPosition = Vector2.new(0, maxScroll),
	})
	scrollTween:Play()
end

local function addLine(nameText, bodyText, isSystem)
	nextMessageId += 1
	table.insert(chatData, {
		id = nextMessageId,
		nameText = nameText .. ":",
		bodyText = bodyText,
		isSystem = isSystem,
		seen = false,
	})

	if #chatData > MAX_STORED_MESSAGES then
		table.remove(chatData, 1)
		for _, row in pairs(renderedRows) do
			recycleRow(row)
		end
		table.clear(renderedRows)
	end

	recalculateLayout()
	queueRender()
	smoothScrollToBottom()
end

local function rebuildInputVisual()
	if suppressOpeningSlash and input.Text == "/" then
		input.Text = ""
		return
	end

	local text = input.Text
	placeholder.Visible = text == "" and not input:IsFocused()

	local visibleWidth = inputVisual.AbsoluteSize.X
	local cursorPosition = input.CursorPosition > 0 and input.CursorPosition or (#text + 1)
	local cursorText = string.sub(text, 1, math.max(0, cursorPosition - 1))
	local cursorX = getInputTextWidth(cursorText)
	local totalWidth = getInputTextWidth(text)
	local maxOffset = math.max(0, totalWidth - visibleWidth + 8)

	if cursorX - inputScrollOffset > visibleWidth - 6 then
		inputScrollOffset = cursorX - visibleWidth + 6
	elseif cursorX - inputScrollOffset < 0 then
		inputScrollOffset = cursorX
	end

	inputScrollOffset = math.clamp(inputScrollOffset, 0, maxOffset)
	inputTextLayer.Position = UDim2.fromOffset(-inputScrollOffset, 0)
	inputTextLayer.Size = UDim2.fromOffset(math.max(visibleWidth, totalWidth + 12), INPUT_HEIGHT)

	for _, child in ipairs(inputTextLayer:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	for index = 1, #text do
		local char = string.sub(text, index, index)
		local letter = Instance.new("TextLabel")
		letter.Name = "Letter"
		letter.AutomaticSize = Enum.AutomaticSize.X
		letter.BackgroundTransparency = 1
		letter.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
		letter.LayoutOrder = index
		letter.Size = UDim2.fromOffset(0, INPUT_HEIGHT)
		letter.Text = char == " " and "\u{00A0}" or char
		letter.TextColor3 = Color3.fromRGB(255, 239, 235)
		letter.TextSize = CHAT_TEXT_SIZE
		letter.TextTransparency = index > #previousInputText and 1 or 0
		letter.Parent = inputTextLayer

		if index > #previousInputText then
			TweenService:Create(letter, TweenInfo.new(LETTER_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
			}):Play()
		end
	end

	previousInputText = text
end

local function isPointInsideRoot(point)
	local position = root.AbsolutePosition
	local size = root.AbsoluteSize
	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

local function sendCurrentText()
	local text = trim(input.Text)
	input.Text = ""
	previousInputText = ""
	inputScrollOffset = 0
	rebuildInputVisual()

	if text == "" then
		return
	end

	if string.sub(text, 1, 1) == "/" then
		CustomChatRemote:FireServer(text)
		return
	end

	if not generalChannel then
		addLine("SYSTEM", "TextChatService channel missing", true)
		return
	end

	local ok, err = pcall(function()
		generalChannel:SendAsync(text)
	end)
	if not ok then
		addLine("SYSTEM", "failed to send message", true)
		warn("[CustomChat] Failed to send TextChatService message:", err)
	end
end

local function focusChat()
	setCustomChatOpen(true)
	suppressOpeningSlash = true
	input.Text = ""
	previousInputText = ""
	inputScrollOffset = 0
	input:CaptureFocus()
	placeholder.Visible = false
	task.defer(function()
		input.Text = ""
		rebuildInputVisual()
		suppressOpeningSlash = false
	end)
end

input:GetPropertyChangedSignal("Text"):Connect(rebuildInputVisual)
input:GetPropertyChangedSignal("CursorPosition"):Connect(rebuildInputVisual)

input.Focused:Connect(function()
	ContextActionService:BindActionAtPriority(
		CHAT_MOVEMENT_SINK_ACTION,
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		3000,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.Space
	)
	placeholder.Visible = false
	TweenService:Create(inputPrefix, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()
end)

input.FocusLost:Connect(function(enterPressed)
	ContextActionService:UnbindAction(CHAT_MOVEMENT_SINK_ACTION)
	if enterPressed then
		sendCurrentText()
	end
	placeholder.Visible = input.Text == ""
	TweenService:Create(inputPrefix, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0.1,
	}):Play()
end)

messages:GetPropertyChangedSignal("CanvasPosition"):Connect(queueRender)
messages:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	recalculateLayout()
	queueRender()
end)

UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
	if gameProcessed or input:IsFocused() then
		return
	end

	if inputObject.KeyCode == Enum.KeyCode.Slash then
		focusChat()
	end
end)

UserInputService.InputChanged:Connect(function(inputObject, gameProcessed)
	if gameProcessed then
		return
	end

	if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
		if not isPointInsideRoot(UserInputService:GetMouseLocation()) then
			return
		end

		setCanvasPosition(messages.CanvasPosition.Y - inputObject.Position.Z * LINE_HEIGHT * 1.15)
		queueRender()
	end
end)

TextChatService.MessageReceived:Connect(function(message)
	if not message.TextSource then
		return
	end

	local name = getDisplayName(message)
	addLine(name, message.Text, false)
end)

CustomChatRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and payload.kind == "system" then
		addLine("SYSTEM", tostring(payload.text or ""), true)
	elseif typeof(payload) == "table" and payload.kind == "playSound" then
		local soundId = tostring(payload.soundId or "")
		if soundId == "" then
			return
		end

		local sound = Instance.new("Sound")
		sound.Name = "ChatCommandSound"
		sound.SoundId = soundId
		sound.Volume = tonumber(payload.volume) or 1
		sound.PlaybackSpeed = tonumber(payload.playbackSpeed) or 1
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Once(function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
		task.delay(5, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
end)
