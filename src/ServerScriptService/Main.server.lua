-- Main server entry point: bootstraps all server services

local GameManager = require(script.Parent:WaitForChild("GameManager"))

GameManager.Init()
