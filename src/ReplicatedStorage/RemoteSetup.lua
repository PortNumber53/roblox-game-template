-- RemoteSetup: creates and provides access to RemoteEvents and RemoteFunctions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local RemoteSetup = {}

local remotesFolder = nil

function RemoteSetup.Init()
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage

	for _, name in pairs(GameConfig.Remotes) do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end

	if GameConfig.RemoteFunctions then
		for _, name in pairs(GameConfig.RemoteFunctions) do
			local rf = Instance.new("RemoteFunction")
			rf.Name = name
			rf.Parent = remotesFolder
		end
	end
end

function RemoteSetup.GetRemote(name: string): RemoteEvent
	if not remotesFolder then
		remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return remotesFolder:WaitForChild(name)
end

function RemoteSetup.GetRemoteFunction(name: string): RemoteFunction
	if not remotesFolder then
		remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return remotesFolder:WaitForChild(name)
end

return RemoteSetup
