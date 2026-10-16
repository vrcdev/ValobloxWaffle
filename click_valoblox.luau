local uis = game:GetService("UserInputService")
local players = game:GetService("Players")
local ws = game:GetService("Workspace")
local run = game:GetService("RunService")
local http_service = game:GetService("HttpService")
local lp = players.LocalPlayer
local vec2 = Vector2.new
local rgb = Color3.fromRGB
local min, max, abs = math.min, math.max, math.abs

local Library = getgenv().Library or Library

local Utility = getgenv().Utility
if Utility and Utility.AddImage then
	pcall(function()
		if makefolder then
			pcall(makefolder, "Abyss") pcall(makefolder, "Abyss/Caches") pcall(makefolder, "Abyss/Assets")
			pcall(makefolder, "Abyss/Assets/UI") pcall(makefolder, "Abyss/Configs") pcall(makefolder, "Abyss/Scripts")
			pcall(makefolder, "Waffle") pcall(makefolder, "Waffle/Assets")
		end
		local T = Library.Theme
		T.Gradient = T.Gradient or Utility.AddImage("Abyss/Assets/UI/Gradient.png", "https://raw.githubusercontent.com/mvonwalk/Exterium/main/Gradient.png")
		T.Hue = T.Hue or Utility.AddImage("Abyss/Assets/UI/Hue.png", "https://raw.githubusercontent.com/mvonwalk/Exterium/main/HuePicker.png")
		T.Saturation = T.Saturation or Utility.AddImage("Abyss/Assets/UI/Saturation.png", "https://raw.githubusercontent.com/mvonwalk/Exterium/main/SaturationPicker.png")
		T.SaturationCursor = T.SaturationCursor or Utility.AddImage("Abyss/Assets/UI/HueCursor.png", "https://raw.githubusercontent.com/mvonwalk/splix-assets/main/Images-cursor.png")
		T.Logo = T.Logo or Utility.AddImage("Waffle/Assets/waffle.png", "https://raw.githubusercontent.com/vrcdev/ValobloxWaffle/main/waffle.png")
		T.Astolfo = T.Astolfo or Utility.AddImage("Abyss/Assets/UI/Astolfo.png", "https://i.imgur.com/T20cWY9.png")
		T.Aiko = T.Aiko or Utility.AddImage("Abyss/Assets/UI/Aiko.png", "https://i.imgur.com/1gRIdko.png")
		T.Rem = T.Rem or Utility.AddImage("Abyss/Assets/UI/Rem.png", "https://i.imgur.com/ykbRkhJ.png")
		T.Violet = T.Violet or Utility.AddImage("Abyss/Assets/UI/Violet.png", "https://i.imgur.com/7B56w4a.png")
		T.Asuka = T.Asuka or Utility.AddImage("Abyss/Assets/UI/Asuka.png", "https://i.imgur.com/3hwztNM.png")
	end)
end

local Flags = Library.Flags
local function flag(name, default)
	local v = Flags[name]
	if v == nil then return default end
	return v
end
local function teamEq(a, b)
	if a == nil or b == nil then return false end
	if a == b then return true end
	return tostring(a) == tostring(b)
end
local CFG = {FOV = 220, Smooth = 0.3, WallCheck = true, AimPart = "Head", Chance = 100}

local DEAD = false

local SKEL_R15 = {
	{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"}, {"UpperTorso", "RightUpperArm"},
	{"LeftUpperArm", "LeftLowerArm"}, {"RightUpperArm", "RightLowerArm"},
	{"LeftLowerArm", "LeftHand"}, {"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"}, {"LowerTorso", "RightUpperLeg"},
	{"LeftUpperLeg", "LeftLowerLeg"}, {"RightUpperLeg", "RightLowerLeg"},
	{"LeftLowerLeg", "LeftFoot"}, {"RightLowerLeg", "RightFoot"},
}
local SKEL_R6 = {
	{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
	{"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local function charOf(p)
	local c = p.Character
	if not c then c = ws:FindFirstChild(p.Name) end
	if c and c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then return c end
	return nil
end
local function humanoidOf(char) return char:FindFirstChildOfClass("Humanoid") end
local function aimPart(char)
	return char:FindFirstChild(CFG.AimPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end
local function friendly(p)
	return teamEq(p.Team, lp.Team)
end

local function w2s(v3)
	local camera = ws.CurrentCamera
	local sp, on = camera:WorldToViewportPoint(v3)
	return vec2(sp.X, sp.Y), on, sp.Z
end

local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
local function rayVisible(toPos, char)
	local from = ws.CurrentCamera.CFrame.Position
	visParams.FilterDescendantsInstances = {charOf(lp), char, ws.CurrentCamera}
	return ws:Raycast(from, toPos - from, visParams) == nil
end

local function mkLine() local l = Drawing.new("Line") l.Thickness = 1.5 l.Visible = false return l end
local function mkText() local t = Drawing.new("Text") t.Size = 13 t.Center = true t.Outline = true t.Visible = false return t end

local function makeESP()
	local e = {
		box = {mkLine(), mkLine(), mkLine(), mkLine()},
		hp = {mkLine(), mkLine()},
		name = mkText(), dist = mkText(),
		tracer = mkLine(),
		arrow = Drawing.new("Triangle"),
		skel = {},
	}
	for i = 1, #SKEL_R15 do e.skel[i] = mkLine() end
	return e
end

local espPool = {}
local colEnemy = rgb(255, 60, 60)
local colFriend = rgb(80, 200, 255)

local function updateESP(e, p)
	local camera = ws.CurrentCamera
	local function hideAll()
		for _, l in ipairs(e.box) do l.Visible = false end
		for _, l in ipairs(e.hp) do l.Visible = false end
		e.name.Visible = false e.dist.Visible = false e.tracer.Visible = false e.arrow.Visible = false
		for _, l in ipairs(e.skel) do l.Visible = false end
	end
	if not e or DEAD or not camera or not flag("esp_master", true) then hideAll() return end
	local isF = friendly(p)
	if flag("team_check", true) and isF then hideAll() return end
	local col = isF and colFriend or colEnemy
	local char = charOf(p)
	local hum = char and humanoidOf(char)
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
	if not (char and hum and root and hum.Health > 0) then hideAll() return end
	local rootPos, onScreen, depth = w2s(root.Position)
	local behind = depth < 0
	local head = char:FindFirstChild("Head")
	local headPos = head and head.Position or root.Position + Vector3.new(0, 1.6, 0)
	local top = w2s(headPos + Vector3.new(0, 0.6, 0))
	local bottom = w2s(root.Position - Vector3.new(0, 2.8, 0))
	local height = abs(top.Y - bottom.Y)
	if height ~= height or height < 8 or height > 4000 or behind then
		hideAll()
		if flag("esp_arrows", true) and behind then
			local center = vec2(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
			local dir = vec2(rootPos.X - center.X, rootPos.Y - center.Y)
			dir = dir.Magnitude > 0 and dir.Unit or vec2(0, -1)
			local tip = center + dir * min(camera.ViewportSize.X, camera.ViewportSize.Y) * 0.42
			local perp = vec2(-dir.Y, dir.X)
			e.arrow.PointA = tip
			e.arrow.PointB = tip - dir * 18 + perp * 8
			e.arrow.PointC = tip - dir * 18 - perp * 8
			e.arrow.Color = col e.arrow.Filled = true e.arrow.Visible = true
		end
		return
	end
	local width = height * 0.55
	local cx = top.X
	local boxX, boxY = cx - width / 2, min(top.Y, bottom.Y)

	if flag("esp_boxes", true) then
		local b = e.box
		b[1].From = vec2(boxX, boxY) b[1].To = vec2(boxX + width, boxY)
		b[2].From = vec2(boxX + width, boxY) b[2].To = vec2(boxX + width, boxY + height)
		b[3].From = vec2(boxX + width, boxY + height) b[3].To = vec2(boxX, boxY + height)
		b[4].From = vec2(boxX, boxY + height) b[4].To = vec2(boxX, boxY)
		for _, l in ipairs(b) do l.Color = col l.Visible = true end
	else for _, l in ipairs(e.box) do l.Visible = false end end

	if flag("esp_hp", true) then
		local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		local hpH = height * frac
		e.hp[1].From = vec2(boxX - 4, boxY + height) e.hp[1].To = vec2(boxX - 4, boxY)
		e.hp[1].Color = rgb(30, 30, 30) e.hp[1].Thickness = 3 e.hp[1].Visible = true
		e.hp[2].From = vec2(boxX - 4, boxY + height) e.hp[2].To = vec2(boxX - 4, boxY + height - hpH)
		e.hp[2].Color = rgb(min(255, (1 - frac) * 255 * 2), min(255, frac * 255 * 2), 40)
		e.hp[2].Thickness = 3 e.hp[2].Visible = true
	else for _, l in ipairs(e.hp) do l.Visible = false end end

	if flag("esp_names", true) then
		e.name.Text = p.Name
		e.name.Position = vec2(cx, boxY - 16)
		e.name.Color = col e.name.Visible = true
	else e.name.Visible = false end

	if flag("esp_dist", true) then
		e.dist.Text = string.format("%.0fm", (camera.CFrame.Position - root.Position).Magnitude * 0.28)
		e.dist.Position = vec2(cx, boxY + height + 2)
		e.dist.Color = Color3.new(1, 1, 1) e.dist.Visible = true
	else e.dist.Visible = false end

	if flag("esp_skel", true) then
		local skelSet = char:FindFirstChild("UpperTorso") and SKEL_R15 or SKEL_R6
		for i, pair in ipairs(skelSet) do
			local l = e.skel[i]
			local a, b = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
			if l and a and b then
				local sa, ona = w2s(a.Position)
				local sb, onb = w2s(b.Position)
				if ona or onb then l.From = sa l.To = sb l.Color = col l.Visible = true
				else l.Visible = false end
			elseif l then l.Visible = false end
		end
		for i = #skelSet + 1, #e.skel do e.skel[i].Visible = false end
	else for _, l in ipairs(e.skel) do l.Visible = false end end

	if flag("esp_tracers", true) and onScreen then
		e.tracer.From = vec2(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
		e.tracer.To = rootPos e.tracer.Color = col e.tracer.Visible = true
	else e.tracer.Visible = false end

	if flag("esp_arrows", true) and not onScreen and depth < 0 then
		local center = vec2(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
		local dir = vec2(rootPos.X - center.X, rootPos.Y - center.Y)
		dir = dir.Magnitude > 0 and dir.Unit or vec2(0, -1)
		local tip = center + dir * min(camera.ViewportSize.X, camera.ViewportSize.Y) * 0.42
		local perp = vec2(-dir.Y, dir.X)
		e.arrow.PointA = tip
		e.arrow.PointB = tip - dir * 18 + perp * 8
		e.arrow.PointC = tip - dir * 18 - perp * 8
		e.arrow.Color = col e.arrow.Filled = true e.arrow.Visible = true
	else e.arrow.Visible = false end
end

local curTarget = nil
local function pickTarget()
	local mPos = uis:GetMouseLocation()
	local camera = ws.CurrentCamera
	local best, bestScore = nil, flag("aim_fov", CFG.FOV)
	for _, p in ipairs(players:GetPlayers()) do
		if p ~= lp and not (flag("team_check", true) and friendly(p)) then
			local char = charOf(p)
			local hum = char and humanoidOf(char)
			if char and hum and hum.Health > 0 then
				local part = aimPart(char)
				if part then
					local sp, on = w2s(part.Position)
					if on then
						local d = (sp - mPos).Magnitude
						if d < bestScore and (not CFG.WallCheck or rayVisible(part.Position, char)) then
							best, bestScore = part, d
						end
					end
				end
			end
		end
	end
	return best
end

task.spawn(function()
	while not DEAD do
		curTarget = pickTarget()
		task.wait(0.05)
	end
end)

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1 fovCircle.NumSides = 60 fovCircle.Color = rgb(255, 255, 255)
fovCircle.Filled = false fovCircle.Visible = false

local conns = {}
local function conn(sig, fn)
	local c = sig:Connect(fn)
	table.insert(conns, c)
	return c
end

conn(run.RenderStepped, function()
	if DEAD then return end
	for _, p in ipairs(players:GetPlayers()) do
		if p ~= lp then
			local e = espPool[p]
			if not e then e = makeESP() espPool[p] = e end
			pcall(updateESP, e, p)
		end
	end
	for p, e in pairs(espPool) do
		if not p or p == lp or not p.Parent then
			if e then
				for _, l in ipairs(e.box) do l.Visible = false end
				for _, l in ipairs(e.hp) do l.Visible = false end
				e.name.Visible = false e.dist.Visible = false e.tracer.Visible = false e.arrow.Visible = false
				for _, l in ipairs(e.skel) do l.Visible = false end
			end
			if not (p and p.Parent) then espPool[p] = nil end
		end
	end
	fovCircle.Visible = flag("aim_showfov", true) and (flag("silent_aim", true) or flag("cam_aim", false))
	fovCircle.Radius = flag("aim_fov", CFG.FOV)
	fovCircle.Position = uis:GetMouseLocation()
end)

local aimBindHeld = false
local function aimHeld()
	return aimBindHeld or uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

conn(run.RenderStepped, function()
	if DEAD or not flag("cam_aim", false) or not aimHeld() or not curTarget then return end
	local cam = ws.CurrentCamera
	local look = (curTarget.Position - cam.CFrame.Position).Unit
	local goal = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + look)
	cam.CFrame = CFG.Smooth > 0 and cam.CFrame:Lerp(goal, math.clamp(CFG.Smooth, 0.05, 1)) or goal
end)

local oldNC = nil
local hooked = false
if hookmetamethod and getnamecallmethod and newcclosure then
	pcall(function()
		oldNC = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()
			if method ~= "ScreenPointToRay" and method ~= "ViewportPointToRay" then
				return oldNC(self, ...)
			end
			if checkcaller() or self ~= ws.CurrentCamera then return oldNC(self, ...) end
			if not flag("silent_aim", true) or not curTarget then return oldNC(self, ...) end
			if math.random(1, 100) > (flag("aim_chance", CFG.Chance) or 100) then return oldNC(self, ...) end
			local o = ws.CurrentCamera.CFrame.Position
			return Ray.new(o, (curTarget.Position - o).Unit)
		end))
		hooked = true
	end)
end
if not hooked then warn("[valo] namecall hook failed") end

local lastTB = 0
conn(run.RenderStepped, function()
	if DEAD or not flag("tb_enable", false) then return end
	if flag("tb_hold", false) and not uis:IsKeyDown(Enum.KeyCode.LeftAlt) then return end
	local now = os.clock()
	local delay = flag("tb_delay", 0.05)
	if now - lastTB < delay then return end
	local cam = ws.CurrentCamera
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {charOf(lp), cam}
	local hit = ws:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 800, rp)
	if not hit then return end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	if not model then return end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local plr = players:GetPlayerFromCharacter(model)
	if not plr then plr = players:FindFirstChild(model.Name) end
	if plr and hum and hum.Health > 0 and plr ~= lp and not (flag("team_check", true) and friendly(plr)) then
		lastTB = now
		if mouse1click then pcall(mouse1click) end
	end
end)

local skinModels = {}
local skinOptions = {}
pcall(function()
	for _, f in ipairs(game:GetService("ReplicatedStorage").Misc.ViewModels.Skins:GetChildren()) do
		if f:IsA("Folder") then
			for _, m in ipairs(f:GetChildren()) do
				local key = f.Name .. " " .. m.Name:gsub("^v_", "")
				skinModels[key] = m
				table.insert(skinOptions, key)
			end
		end
	end
	table.sort(skinOptions)
	if #skinOptions == 0 then skinOptions[1] = "none" end
end)

local ghostModel, ghostLive, ghostHandle = nil, nil, nil
local ghostOffsets = {}
local function clearGhost()
	if ghostModel then pcall(function() ghostModel:Destroy() end) end
	ghostModel, ghostLive, ghostHandle = nil, nil, nil
	ghostOffsets = {}
end

local function findLiveVM()
	for _, c in ipairs(ws.CurrentCamera:GetChildren()) do
		if c:IsA("Model") and c.Name:sub(1, 2) == "v_" and c ~= ghostModel then return c end
	end
	return nil
end

local function applySkin(key)
	clearGhost()
	local src = skinModels[key]
	if not src then return end
	local ok, clone = pcall(function() return src:Clone() end)
	if not ok or not clone then return end
	local srcHandle = src:FindFirstChild("Handle", true) or src.PrimaryPart or src:FindFirstChildWhichIsA("BasePart", true)
	if not srcHandle then pcall(function() clone:Destroy() end) return end
	local cps, sps = {}, {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") then d:Destroy()
		elseif d:IsA("BasePart") then table.insert(cps, d) end
	end
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(sps, d) end
	end
	local hc = srcHandle.CFrame
	for i, cp in ipairs(cps) do
		local sp = sps[i]
		if sp then
			ghostOffsets[cp] = hc:Inverse() * sp.CFrame
			cp.Anchored = true cp.CanCollide = false cp.CanQuery = false cp.CanTouch = false
		end
	end
	clone.Name = "v_ghost"
	clone.Parent = ws.CurrentCamera
	ghostModel = clone
end

conn(run.RenderStepped, function()
	if DEAD then return end
	local live = findLiveVM()
	if live ~= ghostLive then
		ghostLive = live
		ghostHandle = live and (live:FindFirstChild("Handle", true) or live.PrimaryPart or live:FindFirstChildWhichIsA("BasePart", true))
	end
	if not ghostModel then return end
	if flag("skin_on", false) and ghostLive and ghostHandle then
		local hc = ghostHandle.CFrame
		for cp, off in pairs(ghostOffsets) do
			if cp.Parent then cp.CFrame = hc * off end
		end
		for _, d in ipairs(ghostLive:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
		end
		for _, d in ipairs(ghostModel:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
		end
	else
		for _, d in ipairs(ghostModel:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
		end
	end
end)

local function noAfk()
	pcall(function()
		local vu = game:GetService("VirtualUser")
		vu:CaptureController()
		vu:ClickButton2(vec2())
	end)
end
conn(lp.Idled, function()
	if flag("anti_afk", true) then noAfk() end
end)

local Controls = {}
local Window = Library.Window("waffle // valoblox", vec2(540, 620))
Window.Watermark("waffle")
pcall(function() Window.ChangeAnime("Astolfo") end)
Window.ToggleAnime(false)

local combat = Window:Tab("combat")
local aimSec = combat:Section("silent aim", "Left")
local silentTgl = aimSec:Toggle({Title = "enabled", Flag = "silent_aim", Default = true, Callback = function(v) end})
Controls.silent_aim = silentTgl
Controls.aim_fov = aimSec:Slider({Title = "fov", Flag = "aim_fov", Min = 40, Max = 700, Default = 220, Decimals = 1, Callback = function(v) CFG.FOV = v end})
Controls.aim_part = aimSec:Dropdown({Title = "bone", Flag = "aim_part", List = {"Head", "Torso", "HumanoidRootPart"}, Default = "Head", Callback = function(v) CFG.AimPart = v end})
Controls.aim_chance = aimSec:Slider({Title = "hit chance", Flag = "aim_chance", Min = 10, Max = 100, Default = 100, Decimals = 1, Callback = function(v) CFG.Chance = v end})
Controls.aim_showfov = aimSec:Toggle({Title = "show fov", Flag = "aim_showfov", Default = true})
Controls.wall_check = aimSec:Toggle({Title = "wall check", Flag = "wall_check", Default = true, Callback = function(v) CFG.WallCheck = v end})

local camSec = combat:Section("camera aim", "Right")
local camTgl = camSec:Toggle({Title = "enabled", Flag = "cam_aim", Default = false})
Controls.cam_aim = camTgl
camTgl:Keybind({Title = "aim key", Flag = "aim_bind", Key = Enum.UserInputType.MouseButton2, StateType = "Hold",
	Callback = function(state) aimBindHeld = state end})
Controls.aim_smooth = camSec:Slider({Title = "smoothing", Flag = "aim_smooth", Min = 0, Max = 1, Default = 0.3, Decimals = 100, Callback = function(v) CFG.Smooth = v end})

local tbSec = combat:Section("triggerbot", "Right")
Controls.tb_enable = tbSec:Toggle({Title = "enabled", Flag = "tb_enable", Default = false})
Controls.tb_hold = tbSec:Toggle({Title = "hold LAlt", Flag = "tb_hold", Default = false})
Controls.tb_delay = tbSec:Slider({Title = "delay", Flag = "tb_delay", Min = 0.02, Max = 0.6, Default = 0.05, Decimals = 100})

local vis = Window:Tab("visuals")
local espSec = vis:Section("esp", "Left")
Controls.esp_master = espSec:Toggle({Title = "master", Flag = "esp_master", Default = true})
Controls.esp_boxes = espSec:Toggle({Title = "boxes", Flag = "esp_boxes", Default = true})
Controls.esp_hp = espSec:Toggle({Title = "health bar", Flag = "esp_hp", Default = true})
Controls.esp_names = espSec:Toggle({Title = "names", Flag = "esp_names", Default = true})
Controls.esp_dist = espSec:Toggle({Title = "distance", Flag = "esp_dist", Default = true})
Controls.esp_skel = espSec:Toggle({Title = "skeleton", Flag = "esp_skel", Default = true})
Controls.esp_tracers = espSec:Toggle({Title = "tracers", Flag = "esp_tracers", Default = true})
Controls.esp_arrows = espSec:Toggle({Title = "offscreen arrows", Flag = "esp_arrows", Default = true})
Controls.team_check = espSec:Toggle({Title = "team check", Flag = "team_check", Default = true})
local colSec = vis:Section("colors", "Right")
Controls.col_enemy = colSec:Colorpicker({Title = "enemy", Flag = "col_enemy", Color = colEnemy, Callback = function(v) colEnemy = v end})
Controls.col_friend = colSec:Colorpicker({Title = "friend", Flag = "col_friend", Color = colFriend, Callback = function(v) colFriend = v end})

local misc = Window:Tab("misc")
local miscSec = misc:Section("gameplay", "Left")
Controls.anti_afk = miscSec:Toggle({Title = "anti afk", Flag = "anti_afk", Default = true})
local skinSec = misc:Section("skin changer", "Right")
Controls.skin_pick = skinSec:Dropdown({Title = "skin", Flag = "skin_pick", List = skinOptions, Default = skinOptions[1] or "none"})
Controls.skin_on = skinSec:Toggle({Title = "enabled", Flag = "skin_on", Default = false})
skinSec:Button({Title = "apply skin", Callback = function() applySkin(flag("skin_pick")) end})
skinSec:Button({Title = "clear skin", Callback = clearGhost})

local function cfgPath()
	local s = flag("cfg_slot", "default")
	return s == "default" and "valo_cfg.json" or "valo_cfg_" .. s:gsub("%s+", "_") .. ".json"
end
local function saveCfg()
	pcall(function()
		local out = {}
		for k, v in pairs(Flags) do
			if typeof(v) == "Color3" then out[k] = {__col = v:ToHex()}
			elseif typeof(v) == "EnumItem" then out[k] = {__enum = tostring(v)}
			else out[k] = v end
		end
		if writefile then writefile(cfgPath(), http_service:JSONEncode(out)) end
	end)
end
local function flagColor(name, fallback)
	local v = Flags[name]
	if typeof(v) == "Color3" then return v end
	if type(v) == "string" and v:sub(1, 1) == "#" then return Color3.fromHex(v) end
	return fallback
end
local function loadCfg()
	pcall(function()
		local path = cfgPath()
		if not (isfile and isfile(path)) then return end
		local cfg = http_service:JSONDecode(readfile(path))
		for k, v in pairs(cfg) do
			local ctl = Controls[k]
			if type(v) == "table" and v.__col then v = v.__col end
			if type(v) == "string" and v:sub(1, 1) == "#" and ctl and ctl.SetHue then
				local c = Color3.fromHex(v)
				local h, s, vv = c:ToHSV()
				pcall(function() ctl:SetHue(h) ctl:SetSaturationX(s) ctl:SetSaturationY(vv) end)
				Flags[k] = v
			elseif k ~= "aim_bind" and type(v) ~= "table" then
				if ctl and ctl.Set then pcall(function() ctl:Set(v) end)
				else Flags[k] = v end
			end
		end
		CFG.FOV = flag("aim_fov", 220)
		CFG.AimPart = flag("aim_part", "Head")
		CFG.Chance = flag("aim_chance", 100)
		CFG.Smooth = flag("aim_smooth", 0.3)
		CFG.WallCheck = flag("wall_check", true)
		colEnemy = flagColor("col_enemy", colEnemy)
		colFriend = flagColor("col_friend", colFriend)
	end)
end
local function vaUnload()
	if DEAD then return end
	DEAD = true
	for _, e in pairs(espPool) do
		for _, l in ipairs(e.box) do pcall(function() l:Remove() end) end
		for _, l in ipairs(e.hp) do pcall(function() l:Remove() end) end
		pcall(function() e.name:Remove() end) pcall(function() e.dist:Remove() end)
		pcall(function() e.tracer:Remove() end) pcall(function() e.arrow:Remove() end)
		for _, l in ipairs(e.skel) do pcall(function() l:Remove() end) end
	end
	table.clear(espPool)
	pcall(function() fovCircle:Remove() end)
	if ghostLive then
		pcall(function()
			for _, d in ipairs(ghostLive:GetDescendants()) do
				if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
			end
		end)
	end
	clearGhost()
	if hooked then pcall(function() hookmetamethod(game, "__namecall", oldNC) end) end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() Library.SelfDestruct() end)
end
getgenv().__vaUnload = vaUnload

uis.InputBegan:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.End then vaUnload() end
end)

local settingsTab = Window:AddSettingsTab(vaUnload)
local cfgSec = settingsTab:Section("config", "Right")
Controls.cfg_slot = cfgSec:Dropdown({Title = "slot", Flag = "cfg_slot", List = {"default", "slot 2", "slot 3"}, Default = "default"})
cfgSec:Button({Title = "save config", Callback = saveCfg})
cfgSec:Button({Title = "load config", Callback = loadCfg})
cfgSec:Button({Title = "unload", Callback = vaUnload})

Window:SwitchTab(combat)
loadCfg()
print("[valo] waffle up — Delete toggles, End unloads")
