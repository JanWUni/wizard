local Players = game:GetService("Players")
Players.CharacterAutoLoads = true
local assets = game:GetService("ReplicatedStorage"):WaitForChild("WizardAssets")
local Tavern = require(assets:WaitForChild("Tavern"))
local Seating = require(script.Parent.Seating)
if workspace:FindFirstChild("TavernStudy") then
    Tavern.lighting("tavern")
else
    Tavern.build(workspace)
end
local gallery = workspace.TavernStudy:FindFirstChild("EditorCardGallery")
if gallery then gallery:Destroy() end
local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "AssetLabRemotes", game:GetService("ReplicatedStorage")
local leave = Instance.new("RemoteEvent")
leave.Name, leave.Parent = "LeaveSeat", remotes
Seating.attach(workspace.TavernStudy, Players, leave)
workspace:SetAttribute("AssetLabReady", true)
