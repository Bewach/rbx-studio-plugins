local Utils = {}

local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Colors taken from Bootstrap
Utils.Colors = {
	white = Color3.fromHex("fff"),
	success = Color3.fromHex("28a745"),
	warning = Color3.fromHex("ffc107"),
	danger = Color3.fromHex("dc3545")
}

function Utils.getBossCharFromSelection(selectedObjects: Instances): Model|nil
	-- Get the selected character
	local character: Model
	if #selectedObjects == 1 then
		character = selectedObjects[1]
	end
	-- If the selected object is a folder, try to get the character from the folder
	if character and character:IsA("Folder") and character:FindFirstChild("Character") then
		character = character.Character
	end
	-- If arms are selected, try to get the character
	if character and character:IsA("Model") and character.Name == "Arms" then
		character = character.Parent.Character
	end
	-- Validate that the selected object is a character
	if not (character and character:IsA("Model") and character:FindFirstChild("Humanoid")) then
		warn("Selection is not a boss")
		return
	end
	return character
end

function Utils.startRecordingChanges(name: string): string
	-- Try to begin a recording with a specific identifier
	local recording: string? = ChangeHistoryService:TryBeginRecording(name)
	-- Check if recording was successfully initiated
	if not recording then
		-- Handle error here. This indicates that your plugin began a previous
		-- recording and never completed it. You may only have one recording
		-- per plugin active at a time.
		warn("[ChangeHistory] Unable to begin recording: another recording is already in progress. Cancelling current operation. Please restart Studio if the issue persists.")
		ChangeHistoryService:FinishRecording(name, Enum.FinishRecordingOperation.Commit)
		return
	end
	return recording
end

return Utils
