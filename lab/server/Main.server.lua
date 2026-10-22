local Players = game:GetService("Players")
Players.CharacterAutoLoads = false
local assets = game:GetService("ReplicatedStorage"):WaitForChild("WizardAssets")
local Tavern = require(assets:WaitForChild("Tavern"))
if workspace:FindFirstChild("TavernStudy") then
    Tavern.lighting("tavern")
else
    Tavern.build(workspace)
end
local gallery = workspace.TavernStudy:FindFirstChild("EditorCardGallery")
if gallery then gallery:Destroy() end
workspace:SetAttribute("AssetLabReady", true)
