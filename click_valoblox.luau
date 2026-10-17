local uis = game:GetService("UserInputService")
local players = game:GetService("Players")
local ws = game:GetService("Workspace")
local rs = game:GetService("ReplicatedStorage")
local run = game:GetService("RunService")
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
		T.Aiko = T.Aiko or Utility.AddImage("Abyss/Assets/UI/Aiko.png", "https://i.imgur.com/ykbRkhJ.png")
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

local CFG = {FOV = 220, Smooth = 0.3, WallCheck = true, AimPart = "HeadHB", Chance = 100}
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
	return char:FindFirstChild(CFG.AimPart) or char:FindFirstChild("HeadHB") or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end
local function friendly(p)
	local c = charOf(p)
	return c ~= nil and c:FindFirstChild("TeammateHightlight") ~= nil
end

local function w2s(v3)
	local camera = ws.CurrentCamera
	local sp, on = camera:WorldToViewportPoint(v3)
	return vec2(sp.X, sp.Y), on, sp.Z
end

local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
local function rayVisible(toPos, char)
	local cam = ws.CurrentCamera
	local from = cam.CFrame.Position
	visParams.FilterDescendantsInstances = {charOf(lp), char, cam}
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
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HeadHB")
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
						if d < bestScore and (flag("wallbang", false) or not CFG.WallCheck or rayVisible(part.Position, char)) then
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
			if checkcaller() or getnamecallmethod() ~= "FireServer" or self.Name ~= "Shoot" then
				return oldNC(self, ...)
			end
			if not flag("silent_aim", true) or not curTarget or not curTarget.Parent then return oldNC(self, ...) end
			if math.random(1, 100) > (flag("aim_chance", CFG.Chance) or 100) then return oldNC(self, ...) end
			local a = {...}
			local targetPos = curTarget.Position
			a[1] = curTarget
			a[2] = targetPos
			local origin = a[5]
			if typeof(origin) == "Vector3" then
				a[3] = (origin - targetPos).Unit
			else
				a[3] = a[3] or Vector3.new(0, 1, 0)
			end
			if flag("wb_debug", false) then
				local owner = curTarget.Parent and curTarget.Parent.Name or "?"
				print("[valo] shoot ->", owner)
			end
			return oldNC(self, unpack(a))
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
	if now - lastTB < flag("tb_delay", 0.05) then return end
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

local lastAuto = 0
conn(run.RenderStepped, function()
	if DEAD or not flag("auto_fire", false) then return end
	local want = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	if not want and flag("af_autoshoot", false) and curTarget then want = true end
	if not want then return end
	local now = os.clock()
	if now - lastAuto < flag("af_delay", 0.12) then return end
	lastAuto = now
	if mouse1click then pcall(mouse1click) end
end)

local skinModels = {}
local skinBases = {}
local skinOptions = {}
pcall(function()
	local fp = rs.WeaponEngine.Skins.FirstPerson
	for _, gunF in ipairs(fp:GetChildren()) do
		for _, m in ipairs(gunF:GetChildren()) do
			if m:IsA("Model") then
				local key = m.Name:gsub("^v_", "")
				skinModels[key] = m
				skinBases[key] = gunF.Name
				table.insert(skinOptions, key)
			end
		end
	end
	table.sort(skinOptions)
	if #skinOptions == 0 then skinOptions[1] = "none" end
end)

local ghostModel, ghostLive, ghostHandle = nil, nil, nil
local ghostNameMap, ghostOffsets = {}, {}
local function clearGhost()
	if ghostModel then pcall(function() ghostModel:Destroy() end) end
	ghostModel, ghostLive, ghostHandle = nil, nil, nil
	ghostNameMap, ghostOffsets = {}, {}
end

local function liveWeaponModel()
	local arms = ws.CurrentCamera:FindFirstChild("Arms")
	if not arms then return nil end
	for _, c in ipairs(arms:GetChildren()) do
		if c:IsA("Model") then return c end
	end
	return nil
end

local function applySkin(key)
	clearGhost()
	local src = skinModels[key]
	if not src then return end
	local ok, clone = pcall(function() return src:Clone() end)
	if not ok or not clone then return end
	local gv = clone:FindFirstChild("GunVisual") or clone
	local srcGv = src:FindFirstChild("GunVisual") or src
	local srcHandle = srcGv:FindFirstChild("Handle", true) or srcGv.PrimaryPart or srcGv:FindFirstChildWhichIsA("BasePart", true)
	if not srcHandle then pcall(function() clone:Destroy() end) return end
	local hc = srcHandle.CFrame
	local cloneParts = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") then d:Destroy()
		elseif d:IsA("BasePart") then table.insert(cloneParts, d) end
	end
	for _, cp in ipairs(cloneParts) do
		ghostNameMap[cp] = cp.Name
		local sp = srcGv:FindFirstChild(cp.Name, true)
		ghostOffsets[cp] = hc:Inverse() * (sp and sp.CFrame or cp.CFrame)
		cp.Anchored = true cp.CanCollide = false cp.CanQuery = false cp.CanTouch = false
	end
	clone.Name = "waffle_skin"
	clone.Parent = ws
	ghostModel = clone
end

conn(run.RenderStepped, function()
	if DEAD then return end
	local live = liveWeaponModel()
	if live ~= ghostLive then
		ghostLive = live
		ghostHandle = live and (live:FindFirstChild("Handle", true) or live.PrimaryPart or live:FindFirstChildWhichIsA("BasePart", true))
		ghostNameMap = {}
		if ghostModel and live then
			for _, d in ipairs(ghostModel:GetDescendants()) do
				if d:IsA("BasePart") then ghostNameMap[d] = d.Name end
			end
		end
	end
	if not ghostModel then return end
	if flag("skin_on", false) and ghostLive and ghostHandle then
		local hc = ghostHandle.CFrame
		for cp, off in pairs(ghostOffsets) do
			if cp.Parent then
				local mate = ghostLive:FindFirstChild(ghostNameMap[cp] or cp.Name, true)
				cp.CFrame = (mate and mate:IsA("BasePart")) and mate.CFrame or (hc * off)
			end
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
pcall(function() Window.Watermark("waffle") end)
pcall(function() Window.ChangeAnime("Astolfo") end)
pcall(function() Window.ToggleAnime(false) end)

local combat = Window:Tab("combat")
local aimSec = combat:Section("silent aim", "Left")
local silentTgl = aimSec:Toggle({Title = "enabled", Flag = "silent_aim", Default = true, Callback = function(v) end})
Controls.silent_aim = silentTgl
Controls.aim_fov = aimSec:Slider({Title = "fov", Flag = "aim_fov", Min = 40, Max = 700, Default = 220, Decimals = 1, Callback = function(v) CFG.FOV = v end})
Controls.aim_part = aimSec:Dropdown({Title = "bone", Flag = "aim_part", List = {"HeadHB", "Head", "HumanoidRootPart"}, Default = "HeadHB", Callback = function(v) CFG.AimPart = v end})
Controls.aim_chance = aimSec:Slider({Title = "hit chance", Flag = "aim_chance", Min = 10, Max = 100, Default = 100, Decimals = 1, Callback = function(v) CFG.Chance = v end})
Controls.aim_showfov = aimSec:Toggle({Title = "show fov", Flag = "aim_showfov", Default = true})
Controls.wall_check = aimSec:Toggle({Title = "wall check", Flag = "wall_check", Default = true, Callback = function(v) CFG.WallCheck = v end})
Controls.wallbang = aimSec:Toggle({Title = "wallbang", Flag = "wallbang", Default = false})
Controls.wb_debug = aimSec:Toggle({Title = "shot debug", Flag = "wb_debug", Default = false})

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

local afSec = combat:Section("auto fire", "Right")
Controls.auto_fire = afSec:Toggle({Title = "enabled", Flag = "auto_fire", Default = false})
Controls.af_delay = afSec:Slider({Title = "fire delay", Flag = "af_delay", Min = 0.02, Max = 0.5, Default = 0.12, Decimals = 100})
Controls.af_autoshoot = afSec:Toggle({Title = "auto shoot visible", Flag = "af_autoshoot", Default = false})

local vis = Window:Tab("visuals")
local espSec = vis:Section("esp", "Left")
Controls.esp_master = espSec:Toggle({Title = "master", Flag = "esp_master", Default = true})
Controls.esp_boxes = espSec:Toggle({Title = "boxes", Flag = "esp_boxes", Default = true})
Controls.esp_hp = espSec:Toggle({Title = "health bar", Flag = "esp_hp", Default = true})
Controls.esp_names = espSec:Toggle({Title = "names", Flag = "esp_names", Default = true})
Controls.esp_dist = espSec:Toggle({Title = "distance", Flag = "esp_dist", Default = true})
Controls.esp_skel = espSec:Toggle({Title = "skeleton", Flag = "esp_skel", Default = true})

local espSec2 = vis:Section("esp 2", "Right")
Controls.esp_tracers = espSec2:Toggle({Title = "tracers", Flag = "esp_tracers", Default = true})
Controls.esp_arrows = espSec2:Toggle({Title = "offscreen arrows", Flag = "esp_arrows", Default = true})
Controls.team_check = espSec2:Toggle({Title = "team check", Flag = "team_check", Default = true})
Controls.enemy_col = espSec2:ColorPicker({Title = "enemy color", Flag = "enemy_col", Default = colEnemy, Callback = function(v) colEnemy = v end})
Controls.friend_col = espSec2:ColorPicker({Title = "friend color", Flag = "friend_col", Default = colFriend, Callback = function(v) colFriend = v end})

local misc = Window:Tab("misc")
local skinSec = misc:Section("skin changer", "Left")
Controls.skin_pick = skinSec:Dropdown({Title = "skin", Flag = "skin_pick", List = skinOptions, Default = skinOptions[1]})
Controls.skin_on = skinSec:Toggle({Title = "enabled", Flag = "skin_on", Default = false})
skinSec:Button({Title = "apply skin", Callback = function() applySkin(flag("skin_pick", skinOptions[1])) end})
skinSec:Button({Title = "clear skin", Callback = function() clearGhost() end})
skinSec:Button({Title = "unlock all skins (probe)", Callback = function()
	pcall(function()
		local f = rs:FindFirstChild("Events") and rs.Events:FindFirstChild("UnlockAllSkins")
		if f then
			local r = f:InvokeServer()
			print("[valo] UnlockAllSkins ->", typeof(r), tostring(r))
		end
	end)
end})

local miscSec = misc:Section("misc", "Right")
Controls.anti_afk = miscSec:Toggle({Title = "anti afk", Flag = "anti_afk", Default = true})

local unloadAll
local settings = Window:AddSettingsTab(function() if unloadAll then unloadAll() end end)
local cfgSec = settings:Section("config", "Right")
local slots = {"slot 1", "slot 2", "slot 3"}
local slotFiles = {["slot 1"] = "valo_cfg.json", ["slot 2"] = "valo_cfg_slot_2.json", ["slot 3"] = "valo_cfg_slot_3.json"}
local curSlot = "slot 1"
cfgSec:Dropdown({Title = "slot", Flag = "cfg_slot", List = slots, Default = "slot 1", Callback = function(v) curSlot = v end})
cfgSec:Button({Title = "save", Callback = function()
	pcall(function()
		local data = {}
		for k in pairs(Flags) do data[k] = Flags[k] end
		data._cfg = {FOV = CFG.FOV, Smooth = CFG.Smooth, WallCheck = CFG.WallCheck, AimPart = CFG.AimPart, Chance = CFG.Chance}
		data._col = {e = {colEnemy.R * 255, colEnemy.G * 255, colEnemy.B * 255}, f = {colFriend.R * 255, colFriend.G * 255, colFriend.B * 255}}
		writefile(slotFiles[curSlot], game:GetService("HttpService"):JSONEncode(data))
	end)
end})
cfgSec:Button({Title = "load", Callback = function()
	pcall(function()
		if not isfile(slotFiles[curSlot]) then return end
		local data = game:GetService("HttpService"):JSONDecode(readfile(slotFiles[curSlot]))
		if data._cfg then
			CFG.FOV = data._cfg.FOV CFG.Smooth = data._cfg.Smooth CFG.WallCheck = data._cfg.WallCheck
			CFG.AimPart = data._cfg.AimPart CFG.Chance = data._cfg.Chance
		end
		if data._col then
			colEnemy = rgb(data._col.e[1], data._col.e[2], data._col.e[3])
			colFriend = rgb(data._col.f[1], data._col.f[2], data._col.f[3])
		end
		for k, v in pairs(data) do
			if k ~= "_cfg" and k ~= "_col" then
				Flags[k] = v
				local c = Controls[k]
				if c and c.SetValue then pcall(function() c:SetValue(v) end)
				elseif c and c.Set then pcall(function() c:Set(v) end) end
			end
		end
	end)
end})
unloadAll = function()
	if DEAD then return end
	DEAD = true
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	for _, e in pairs(espPool) do
		for _, l in ipairs(e.box) do pcall(function() l:Remove() end) end
		for _, l in ipairs(e.hp) do pcall(function() l:Remove() end) end
		pcall(function() e.name:Remove() end) pcall(function() e.dist:Remove() end)
		pcall(function() e.tracer:Remove() end) pcall(function() e.arrow:Remove() end)
		for _, l in ipairs(e.skel) do pcall(function() l:Remove() end) end
	end
	pcall(function() fovCircle:Remove() end)
	clearGhost()
	if hooked then pcall(function() hookmetamethod(game, "__namecall", oldNC) end) end
	pcall(function() Library.SelfDestruct() end)
end

settings:Section("unload", "Left"):Button({Title = "unload (End)", Callback = unloadAll})

conn(uis.InputBegan, function(inp)
	if inp.KeyCode == Enum.KeyCode.End then unloadAll() end
end)

pcall(function() Window:SwitchTab(combat) end)
