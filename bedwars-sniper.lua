-- bedwars-sniper.lua  — queue sniper for normal (<=3 players) and duels (0 players) lobbies
--
-- FOR EVERYONE: anybody runs this one line, in any executor, from a BedWars lobby:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/officerbilly6-hub/bedwars-sniper.lua/main/bedwars-sniper.lua"))()
--
-- to share it, nothing has to be filled in; here is the exact URL with your own account baked in. That's the whole setup:
--   1. put this file in a PUBLIC repo, path stays bedwars-sniper.lua (raw URL must end in .lua)
--   2. the URL must be a raw.githubusercontent.com link, not a github.com page
--   3. hand the line to people; nothing to configure on their side, no key system
-- a URL that opens as a web page returns HTML and fails with "unexpected symbol near '<'"
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local lp           = Players.LocalPlayer

local SCAN          = 250      -- ms between polls
local JOIN_COOLDOWN = 4500     -- ms minimum between join attempts
local MAX_CHECKS    = 400      -- stop after this many polls without a hit
local NORMAL_MAX    = 3        -- normal servers at or under this are sniped
local DUELS_MAX     = 0        -- duels servers at or under this are sniped

local mode, running = "both", false   -- both | normal | duels | auto
local stats = { hits = 0, attempts = 0, last = "-" }

if not game:IsLoaded() then repeat task.wait(0.2) until game:IsLoaded() end

--------------------------------------------------------------------------
-- lobby model
--------------------------------------------------------------------------
-- the game hangs each available lobby off a folder; grab whatever container
-- looks like it by name, falling back to a full workspace scan
local function lobbyRoots()
	local out = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name:find("lobby") or obj.Name:find("Lobby") then
			out[#out + 1] = obj
		end
	end
	if #out == 0 then out[1] = workspace end
	return out
end

-- "duels" | "normal" | nil, decided by the nearest labelled ancestor
local function lobbyMode(inst)
	local node = inst
	for _ = 1, 5 do
		node = node.Parent
		if not node or node == workspace then break end
		local n = node.Name:lower()
		if n:find("duel") then return "duels" end
		if n:find("normal") or n:find("solo") or n:find("duo") or n:find("squad") then return "normal" end
	end
	return nil
end

-- players already seated in a server, counted from the humanoid/character models
local function seated(inst)
	local n = 0
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and not d:IsDescendantOf(workspace.CurrentCamera) then
			n += 1
		end
	end
	return n
end

-- returns instance, mode, count for the emptiest lobby that passes the filter
local function bestLobby()
	local best, bestMode, bestCount
	for _, root in ipairs(lobbyRoots()) do
		for _, cand in ipairs(root:GetChildren()) do
			if cand:IsA("Model") or cand:IsA("MeshPart") or cand:IsA("BasePart") then
				local d = lobbyMode(cand)
				if d == "duels" and mode ~= "normal" then
					local c = seated(cand)
					if c <= DUELS_MAX and (not bestCount or c < bestCount) then
						best, bestMode, bestCount = cand, d, c
					end
				elseif d == "normal" and mode ~= "duels" then
					local c = seated(cand)
					if c <= NORMAL_MAX and (not bestCount or c < bestCount) then
						best, bestMode, bestCount = cand, d, c
					end
				end
			end
		end
	end
	return best, bestMode, bestCount
end

--------------------------------------------------------------------------
-- join
--------------------------------------------------------------------------
-- ladder of every join-ish remote in the game, built once
local joins = {}
for _, obj in ipairs(game:GetDescendants()) do
	local n = obj.Name:lower()
	if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
		and (n:find("join") or n:find("queue") or n:find("teleport")) then
		joins[#joins + 1] = obj
	end
end

local function tryJoin(target)
	stats.attempts += 1
	for _, remote in ipairs(joins) do
		for _, arg in ipairs({ target, target.Name, target:GetFullName() }) do
			pcall(function()
				if remote:IsA("RemoteFunction") then
					remote:InvokeServer(arg)
				else
					remote:FireServer(arg)
				end
			end)
			task.wait(0.08)
		end
	end
end

--------------------------------------------------------------------------
-- loop
--------------------------------------------------------------------------
local function loop()
	if running then return end
	running = true
	local checks, lastJoin = 0, 0
	while running do
		checks += 1
		if checks > MAX_CHECKS then
			stats.last = "gave up after " .. MAX_CHECKS .. " polls"
			running = false
			break
		end

		local target, dmode, count = bestLobby()
		if target then
			stats.last = ("%s @ %d players"):format(dmode, count)
			stats.hits += 1
			if mode == "auto" and os.clock() * 1000 - lastJoin > JOIN_COOLDOWN then
				lastJoin = os.clock() * 1000
				tryJoin(target)
			end
			if mode ~= "auto" then
				stats.last = stats.last .. " (found)"
				break
			end
		else
			stats.last = "no lobbies yet"
		end
		task.wait(SCAN / 1000)
	end
	running = false
end

local function stop() running = false end

--------------------------------------------------------------------------
-- gui
--------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.Parent = "BedwarsSniper", false, lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size, frame.Position, frame.AnchorPoint = UDim2.fromOffset(236, 250), UDim2.fromScale(1, 0.5), Vector2.new(1, 0.5)
frame.BackgroundColor3, frame.BorderSizePixel, frame.Parent = Color3.fromRGB(16, 16, 20), 0, gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local list = Instance.new("UIListLayout", frame)
list.Padding, list.SortOrder = UDim.new(0, 4), Enum.SortOrder.LayoutOrder

local title = Instance.new("TextLabel")
title.Size, title.BackgroundTransparency, title.Font = UDim2.new(1, -14, 0, 26), 1, Enum.Font.GothamBold
title.TextColor3, title.TextSize, title.Parent = Color3.new(1, 1, 1), 14, frame
title.Text = "bedwars sniper"

local info = Instance.new("TextLabel")
info.Size, info.BackgroundTransparency, info.Font = UDim2.new(1, -14, 0, 34), 1, Enum.Font.Code
info.TextColor3, info.TextSize, info.TextWrapped, info.TextXAlignment = Color3.fromRGB(150, 150, 160), 11, true, Enum.TextXAlignment.Left
info.Parent = frame

local function btn(text, color, fn)
	local b = Instance.new("TextButton")
	b.Size, b.BackgroundColor3, b.TextColor3, b.Font = UDim2.new(1, -14, 0, 26), color, Color3.new(1, 1, 1), Enum.Font.GothamMedium
	b.Text, b.TextSize, b.Parent = text, 13, frame
	b.MouseButton1Click:Connect(fn)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
	return b
end

local function setMode(m)
	mode = m
	info.Text = "mode: " .. m .. "\n" .. stats.last
end

btn("scan only (F4)", Color3.fromRGB(38, 38, 46), function() setMode("both"); loop() end)
btn("auto-join both (F5)", Color3.fromRGB(38, 38, 46), function() setMode("auto"); loop() end)
btn("normal  <=3", Color3.fromRGB(38, 38, 46), function() setMode("normal"); loop() end)
btn("duels  0", Color3.fromRGB(38, 38, 46), function() setMode("duels"); loop() end)
btn("stop", Color3.fromRGB(56, 32, 32), stop)

UIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.F4 then setMode("both"); loop() end
	if i.KeyCode == Enum.KeyCode.F5 then setMode("auto"); loop() end
	if i.KeyCode == Enum.KeyCode.F6 then stop() end
end)

setMode("both")
print(("bedwars sniper ready - %d join remotes, %d lobby roots"):format(#joins, #lobbyRoots()))
