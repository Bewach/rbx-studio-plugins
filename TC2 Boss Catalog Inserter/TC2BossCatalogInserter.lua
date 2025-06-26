LabeledTextInput = require(script.Parent.Modules.LabeledTextInput)
CustomTextButton = require(script.Parent.Modules.CustomTextButton)

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

-- Create a new toolbar section titled "Custom Script Tools"
local toolbar = plugin:CreateToolbar("TC2 Inserter")

-- Add a toolbar button named "Create Empty Script"
local newScriptButton = toolbar:CreateButton("Insert from Catalog", "Insert an avatar item from the catalog", "rbxassetid://17345051179")

-- Make button clickable even if 3D viewport is hidden
--newScriptButton.ClickableWhenViewportHidden = true

-- Create new "DockWidgetPluginGuiInfo" object
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float, -- Widget will be initialized in floating panel
	false,  -- Widget will be initially disabled
	false,  -- Don't override the previous enabled state
	235,    -- Default width of the floating window
	55,    -- Default height of the floating window
	235,    -- Minimum width of the floating window
	55     -- Minimum height of the floating window
)

-- Create new widget GUI
local mainWidget = plugin:CreateDockWidgetPluginGui("mainWidget", widgetInfo)
mainWidget.Title = "TC2 Boss Tools"  -- Optional widget title

local assetInput = LabeledTextInput.new(
	"assedIdField", -- name suffix of gui object
	"Asset ID", -- title text of the multi choice
	"" -- default value
)
-- set/get graphemes which is essentially text character limit but graphemes measure things like emojis too
assetInput:SetMaxGraphemes(99)
-- use :GetFrame() to set the parent of the LabeledTextInput
assetInput:GetFrame().Parent = mainWidget

local insertButton = CustomTextButton.new(
	"insertButton", -- name of the gui object
	"Insert" -- the text displayed on the button
)
-- use the :getButton() method to return the ImageButton gui object
local insertButtonObject = insertButton:GetButton()
insertButtonObject.Size = UDim2.new(0, 70, 0, 25)
insertButtonObject.Position = UDim2.new(0, 80, 0, 60)

insertButtonObject.MouseButton1Click:Connect(function()
	local assetId: number = assetInput:GetValue()
	-- Make sure the user entered something
	if assetId == "" then
		return
	end
	
	-- Get the selected character
	local character: Model
	local selectedObjects = Selection:Get()
	if #selectedObjects == 1 then
		character = selectedObjects[1]
	end
	if character and character:IsA("Folder") and character:FindFirstChild("Character") then
		character = character.Character
	end
	if not (character and character:IsA("Model") and character:FindFirstChild("Humanoid")) then
		warn("Selection is not a character")
		return
	end

	-- Try to begin a recording with a specific identifier
	local recording = ChangeHistoryService:TryBeginRecording("Insert asset")
	-- Check if recording was successfully initiated
	if not recording then
		-- Handle error here. This indicates that your plugin began a previous
		-- recording and never completed it. You may only have one recording
		-- per plugin active at a time.
		warn("[ChangeHistory] Unable to begin recording: another recording is already in progress. Cancelling current operation. Please restart Studio if the issue persists.")
		ChangeHistoryService:FinishRecording("Insert asset", Enum.FinishRecordingOperation.Commit)
		return
	end
	
	-- Get the asset from the array of instances
	local asset
	local success, result = pcall(function()
		return game:GetObjects("rbxassetid://" .. assetId)[1]
	end)
	if success then
		asset = result
	else
		-- Try interpreting the ID as a bundle ID
		local success, result = pcall(function()
			return game:GetService("AssetService"):GetBundleDetailsAsync(assetId)
		end)
		if success then
			local bundle = result
			--print(bundle)
			if bundle["BundleType"] ~= "DynamicHead" then
				warn("Invalid asset ID or inserted bundle is not a dynamic head")
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
				return
			end
			-- Some bundles have the dynamic head first, some have the mood first
			if bundle["Items"][1]["Name"] == "Default Mood" or bundle["Items"][1]["Name"] == "DefaultFallBackMood" then
				asset = game:GetObjects("rbxassetid://" .. bundle["Items"][2]["Id"])[1]
			else
				asset = game:GetObjects("rbxassetid://" .. bundle["Items"][1]["Id"])[1]
			end
		else
			-- I don't think you can reach here since bundle IDs also start from 1,
			-- so the bundle check will always work
			warn("Could not insert asset: " .. tostring(result))
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			return
		end
	end
	
	if asset.ClassName == "SpecialMesh" then
		--print("we got a dynamic head over here")
		if asset.ClassName ~= "SpecialMesh" then
			warn("Asset is not a Dynamic Head")
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			return
		end
		local accessory: Accessory = script.Parent.DynamicHead:Clone()
		accessory.Parent = character
		local handle: Part = accessory.Handle
		handle.Mesh:Destroy()
		asset.Parent = handle
		local textureId = asset.TextureId
		asset.TextureId = ""
		local texture: Texture = Instance.new("Texture")
		texture.Parent = handle
		texture.Texture = textureId
		character.Head.Transparency = 1
		for i, child in character.Head:GetChildren() do
			-- Hide the face decals that normally linger when the head is invisible
			if child.ClassName == "Decal" then
				child.Transparency = 1
			end
		end
	elseif asset.ClassName == "Shirt" or asset.ClassName == "Pants" then
		character:FindFirstChild(asset.ClassName).Parent = nil
		asset.Parent = character
	else
		asset.Parent = character
	end
	--print(asset.ClassName)
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end)

insertButtonObject.Parent = mainWidget

local function onPluginButtonClicked()
	mainWidget.Enabled = not mainWidget.Enabled
end

newScriptButton.Click:Connect(onPluginButtonClicked)