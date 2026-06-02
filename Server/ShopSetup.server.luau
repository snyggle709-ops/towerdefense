local tower = workspace:WaitForChild("Tower")
local part = tower:WaitForChild("Model"):WaitForChild("ProximityPart")

local prompt = Instance.new("ProximityPrompt")
prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.MaxActivationDistance = 15
prompt.HoldDuration = 0
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.RequiresLineOfSight = false
prompt.Parent = part