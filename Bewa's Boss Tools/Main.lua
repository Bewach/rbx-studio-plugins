local Iris = require(script.Parent.Iris)
local Utils = require(script.Parent.Utils)

local ChangeHistoryService: ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection: Selection = game:GetService("Selection")

-- Create a new toolbar section
local toolbar: PluginToolbar = plugin:CreateToolbar("Bewa's Boss Tools")

-- Add a toolbar button inside of that section
local toggleButton: PluginToolbarButton = toolbar:CreateButton("Open Menu", "Opens the menu", "rbxassetid://17345051179")

local WIDGET_INITIAL_WIDTH: number = 250
local WIDGET_INITIAL_HEIGHT: number = 315

-- Create new "DockWidgetPluginGuiInfo" object
local widgetInfo: DockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float, -- Widget will be initialized in floating panel
	false,  -- Widget will be initially disabled
	false,  -- Don't override the previous enabled state
	WIDGET_INITIAL_WIDTH,    -- Default width of the floating window
	WIDGET_INITIAL_HEIGHT,    -- Default height of the floating window
	WIDGET_INITIAL_WIDTH,    -- Minimum width of the floating window
	WIDGET_INITIAL_HEIGHT     -- Minimum height of the floating window
)

-- Create new widget GUI
local mainWidget: DockWidgetPluginGui = plugin:CreateDockWidgetPluginGui("mainWidget", widgetInfo)
mainWidget.Title = "Bewa's Boss Tools"  -- Optional widget title
mainWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local widgetEnabled: boolean = false

Iris.UpdateGlobalConfig({
	UseScreenGUIs = false
})
Iris.UpdateGlobalConfig(Iris.TemplateConfig.sizeClear)
Iris.Disabled = true

Iris.Init(mainWidget)

local irisConnected = false
Iris:Connect(function()
	local window = Iris.Window({"Bewa's Boss Tools",
		[Iris.Args.Window.NoTitleBar] = true,
		--[Iris.Args.Window.NoBackground] = true, -- the background behind the widget container
		[Iris.Args.Window.NoMove] = true,
		[Iris.Args.Window.NoResize] = true
	})
	window.state.size:set(mainWidget.AbsoluteSize)
	window.state.position:set(mainWidget.AbsolutePosition)

	---- UI ELEMENTS BEGIN HERE ----
	Iris.MenuBar() -- Menu bar for boss selection
	Iris.SameLine({[Iris.Args.SameLine.HorizontalAlignment] = Enum.HorizontalAlignment.Center})
	selectText = Iris.Text({"Selected boss:"})
	Iris.End()
	Iris.End()
	Iris.MenuBar() -- Menu bar for success text
	Iris.SameLine({[Iris.Args.SameLine.HorizontalAlignment] = Enum.HorizontalAlignment.Center})
	successText = Iris.Text({""})
	Iris.End()
	Iris.End()
	
	Iris.CollapsingHeader({"Catalog Inserter"}, {isUncollapsed = true})
	local assetIdInput = Iris.InputNum({"Asset ID",
		[Iris.Args.InputNum.Increment] = 1,
		[Iris.Args.InputNum.Min] = 0,
		[Iris.Args.InputNum.Max] = 9007199254740990,
		[Iris.Args.InputNum.NoButtons] = true
	})
	-- An absolutely terrible way to center things, but I guess it's the only thing that works
	Iris.SameLine({[Iris.Args.SameLine.HorizontalAlignment] = Enum.HorizontalAlignment.Center})
	local insertButton = Iris.Button({"Insert"})
	Iris.End()
	Iris.End()
	
	Iris.CollapsingHeader({"Arm Texture-inator"}, {isUncollapsed = true})
	Iris.SameLine({[Iris.Args.SameLine.HorizontalAlignment] = Enum.HorizontalAlignment.Center})
	local armsButton = Iris.Button({"Apply"})
	Iris.End()
	Iris.End()
	
	Iris.CollapsingHeader({"Voice Selector"}, {isUncollapsed = true})
	local voiceFolderRemove = Iris.State(false)
	Iris.Checkbox({"Remove Voice folder"}, {isChecked = voiceFolderRemove})
	local voiceIndex = Iris.State("None")
	Iris.ComboArray({"Voice"}, {index = voiceIndex}, Utils.Voices)
	Iris.SameLine({[Iris.Args.SameLine.HorizontalAlignment] = Enum.HorizontalAlignment.Center})
	local voiceButton = Iris.Button({"Apply"})
	Iris.End()
	Iris.End()
	---- UI ELEMENTS END HERE ----
	
	-- Any widget which has children (like windows) must end with an End()
	-- Here we end the main window
	Iris.End()
	if not irisConnected then
		irisConnected = true
	end

	if insertButton.clicked() then
		local assetId: number = assetIdInput.state.number:get()
		-- Make sure the user entered something
		if assetId == 0 then
			setSuccessText("Warning", "Asset ID cannot be 0")
			return
		end
		
		local character: Model? = Utils.getBossCharFromSelection(Selection:Get())
		if not character then
			setSuccessText("Warning", "Invalid selection")
			return
		end
		
		local recording: string = Utils.startRecordingChanges("Insert asset")
		
		-- Try interpreting the ID as a bundle ID
		local asset
		local success, result = pcall(function()
			return game:GetService("AssetService"):GetBundleDetailsAsync(assetId)
		end)
		if success and result["BundleType"] == "DynamicHead" then
			local bundle = result
			-- Some bundles have the dynamic head first, some have the mood first
			if bundle["Items"][1]["Name"] == "Default Mood" or bundle["Items"][1]["Name"] == "DefaultFallBackMood" then
				asset = game:GetObjects("rbxassetid://" .. bundle["Items"][2]["Id"])[1]
			else
				asset = game:GetObjects("rbxassetid://" .. bundle["Items"][1]["Id"])[1]
			end
		else
			-- Get the asset from the array of instances returned
			-- For cosmetics this will always(?) be a single instance
			local success, result = pcall(function()
				return game:GetObjects("rbxassetid://" .. assetId)[1]
			end)
			if success then
				asset = result
			else
				setSuccessText("Warning", "Invalid asset ID")
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
				return
			end
		end
		
		if asset.ClassName == "SpecialMesh" then
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
		elseif asset.ClassName == "Decal" then
			asset.Parent = character.Head
		elseif asset.ClassName == "Accessory" then
			asset.Parent = character
		else
			setSuccessText("Warning", "Cannot insert asset")
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			return
		end
		
		setSuccessText("Success")
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	
	if armsButton.clicked() then
		local arms: Model
		local selectedObjects: Instances = Selection:Get()
		-- Try to get the arms from the selected char or boss folder
		local character: Model? = Utils.getBossCharFromSelection(selectedObjects)
		if not character then
			setSuccessText("Warning", "Invalid selection")
			return
		end
		arms = character.Parent:FindFirstChild("Arms")
		if not (arms and arms:IsA("Model")) then
			setSuccessText("Warning", "I can't find the arms??")
			return
		end
		
		local recording: string = Utils.startRecordingChanges("Apply texture to arms")
		
		local character: Model = arms.Parent.Character
		local leftShirt: Shirt? = arms["Left Arm"]:FindFirstChild("Shirt", true)
		local rightShirt: Shirt? = arms["Right Arm"]:FindFirstChild("Shirt", true)
		
		if not (leftShirt or rightShirt) then
			local newLeftArm: Model = script.Parent.Arms["Left Arm"].Arm:Clone()
			local newRightArm: Model = script.Parent.Arms["Right Arm"].Arm:Clone()
			
			newLeftArm.Parent = arms["Left Arm"]
			newRightArm.Parent = arms["Right Arm"]
			
			-- Hide the original mesh arm
			arms["Left Arm"].Mesh.Scale = Vector3.zero
			arms["Right Arm"].Mesh.Scale = Vector3.zero
			
			-- Match the new arm position with the original
			arms["Left Arm"].Arm["Left Arm"].Position = arms["Left Arm"].Position
			arms["Right Arm"].Arm["Right Arm"].Position = arms["Right Arm"].Position
			
			leftShirt = arms["Left Arm"].Arm.Shirt
			rightShirt = arms["Right Arm"].Arm.Shirt
		end
		
		local bodyColors: BodyColors = character:FindFirstChildOfClass("BodyColors")
		if not bodyColors then
			if character:FindFirstChild("Left Arm") then
				leftShirt.Parent["Left Arm"].Color = character["Left Arm"].Color
				rightShirt.Parent["Right Arm"].Color = character["Right Arm"].Color
			elseif character:FindFirstChild("LeftHand") then
				leftShirt.Parent["Left Arm"].Color = character["LeftHand"].Color
				rightShirt.Parent["Right Arm"].Color = character["RightHand"].Color
			else
				-- Can you even get here?
				warn("Sorry, I can't find the arm colors")
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
				return
			end
		else
			leftShirt.Parent["Left Arm"].Color = bodyColors.LeftArmColor3
			rightShirt.Parent["Right Arm"].Color = bodyColors.RightArmColor3
		end
		leftShirt.ShirtTemplate = character.Shirt.ShirtTemplate
		leftShirt.Color3 = character.Shirt.Color3
		rightShirt.ShirtTemplate = character.Shirt.ShirtTemplate
		rightShirt.Color3 = character.Shirt.Color3
		
		setSuccessText("Success")
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	
	if voiceButton.clicked() then
		local newVoice: string = voiceIndex:get()
		
		local character: Model? = Utils.getBossCharFromSelection(Selection:Get())
		if not character then
			setSuccessText("Warning", "Invalid selection")
			return
		end
		
		local recording: string = Utils.startRecordingChanges("Change voice")
		
		-- Will set the voice even if the attribute doesn't exist
		character.Parent.Settings:SetAttribute("Voice", newVoice)
		
		-- Remove the voice folder if the user wants to
		local voiceFolder = character.Parent:FindFirstChild("Voice")
		if voiceFolderRemove:get() and voiceFolder then
			voiceFolder.Parent = nil
		end
		
		setSuccessText("Success")
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end)

function setSuccessText(state: "Success"|"Warning"|"Danger", message: string|nil)
	successText.Instance.TextColor3 = Utils.Colors[state]
	if not message then
		successText.Instance.Text = state
	else
		successText.Instance.Text = message
	end
end

Selection.SelectionChanged:Connect(function()
	if not irisConnected then
		return
	end
	
	local selectedObjects = Selection:Get()
	successText.Instance.Text = ""
	if #selectedObjects == 1 then
		local selected = selectedObjects[1]
		if selected.ClassName == "Folder" then
			selectText.Instance.Text = "Selected boss: " .. selected.Name
		else
			selectText.Instance.Text = "Selected boss: " .. selected.Parent.Name
		end
	else
		selectText.Instance.Text = "Selected boss: ..."
	end
end)

-- Pressing the X button on the window will close the widget
mainWidget:BindToClose(function()
	widgetEnabled = false
	mainWidget.Enabled = false
	Iris.Disabled = true
	toggleButton:SetActive(false)
end)

-- Toggle the widget's enabled state with the toolbar button
toggleButton.Click:Connect(function()
	widgetEnabled = not widgetEnabled
	mainWidget.Enabled = widgetEnabled
	Iris.Disabled = not widgetEnabled
	toggleButton:SetActive(widgetEnabled)
end)

-- This is quite important. We need to ensure Iris properly shutdowns and closes any connections.
plugin.Unloading:Connect(function()
	Iris.Shutdown()
	widgetEnabled = false
	mainWidget.Enabled = false
	Iris.Disabled = true
	toggleButton:SetActive(false)
	irisConnected = false
end)