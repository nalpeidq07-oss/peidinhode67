--==================================================================================
--  APEX SUITE 3-in-1   |   SuperShot  •  Studs 3B  •  Dex
--  UI: Liquid Glass azul-vermelho (CanvasGroup + blur + strokes em camadas)
--==================================================================================
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local WS           = workspace

local lp       = Players.LocalPlayer
local cam      = WS.CurrentCamera
local IS_SERVER = RunService:IsServer() or lp == nil
local playerGui = (not IS_SERVER) and lp:WaitForChild("PlayerGui") or nil

local C_BLUE  = Color3.fromRGB(47, 107, 255)
local C_RED   = Color3.fromRGB(255, 59, 78)
local C_ICE   = Color3.fromRGB(190, 216, 255)
local C_DARK  = Color3.fromRGB(8, 12, 26)
local C_TEXT  = Color3.fromRGB(236, 242, 255)
local C_MUTED = Color3.fromRGB(150, 166, 196)

local function fmt(n)
	local s = tostring(math.floor(n))
	local k
	repeat s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2") until k == 0
	return s
end

local function fmtTime(s)
	if s ~= s or s == math.huge then return "--" end
	s = math.floor(s)
	if s < 60 then return s .. "s" end
	if s < 3600 then return ("%dm %02ds"):format(s // 60, s % 60) end
	if s < 86400 then return ("%dh %02dm"):format(s // 3600, (s % 3600) // 60) end
	return ("%dd %02dh"):format(s // 86400, (s % 86400) // 3600)
end

--==================================================================================
--  MÓDULO 1 — SUPER SHOT
--==================================================================================
local SS = {
	SpeedMin = 240, SpeedMax = 950,
	Range = 26, HitTime = 0.28, FlyTime = 1.4,
	UseCamera = true, Charge = 1, Charging = false, Busy = false,
}
local SS_GUIREF = {}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = (Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Blacklist)
overlapParams.MaxParts = 80

local ballCache, ballCacheTime = {}, 0

function SS:GetBall()
	local char = lp and lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	overlapParams.FilterDescendantsInstances = { char }
	local ok, parts = pcall(function()
		return WS:GetPartBoundsInRadius(hrp.Position, self.Range, overlapParams)
	end)

	if ok and parts then
		local best, bestD
		for i = 1, #parts do
			local v = parts[i]
			if v.Name == "Ball" or v:GetAttribute("Ball") then
				local d = (v.Position - hrp.Position).Magnitude
				if not bestD or d < bestD then best, bestD = v, d end
			end
		end
		if best then return best, hrp end
	end

	-- fallback cacheado (1s) para jogos onde a bola não é detectável por raio
	if os.clock() - ballCacheTime > 1 then
		ballCacheTime = os.clock()
		table.clear(ballCache)
		local ok2, desc = pcall(function() return WS:GetDescendants() end)
		if ok2 then
			for i = 1, #desc do
				local v = desc[i]
				if v.Name == "Ball" and v:IsA("BasePart") then ballCache[#ballCache + 1] = v end
			end
		end
	end

	local best, bestD
	for i = 1, #ballCache do
		local v = ballCache[i]
		if v.Parent then
			local d = (v.Position - hrp.Position).Magnitude
			if d <= self.Range and (not bestD or d < bestD) then best, bestD = v, d end
		end
	end
	return best, hrp
end

function SS:Dir(hrp)
	local look = self.UseCamera and cam.CFrame.LookVector or hrp.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

function SS:Shoot()
	if self.Busy then return end
	local ball, hrp = self:GetBall()
	if not ball or not hrp then return end
	self.Busy = true

	local dir   = self:Dir(hrp)
	local speed = self.SpeedMin + (self.SpeedMax - self.SpeedMin) * self.Charge
	local origin = hrp.CFrame
	local t0 = os.clock()
	local touched = 0

	pcall(function() ball:SetNetworkOwner(lp) end)
	pcall(function()
		sethiddenproperty(lp, "SimulationRadius", math.huge)
		sethiddenproperty(lp, "MaxSimulationRadius", math.huge)
	end)

	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if not ball.Parent or not hrp.Parent or t >= self.FlyTime then
			conn:Disconnect()
			pcall(function()
				ball.AssemblyLinearVelocity = dir * (speed * 0.85)
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				hrp.CFrame = origin
			end)
			self.Busy = false
			return
		end

		if t < self.HitTime then
			hrp.CFrame = CFrame.new(ball.Position - dir * 1.6, ball.Position)
			hrp.AssemblyLinearVelocity = dir * speed
			if touched < 3 then
				touched += 1
				pcall(firetouchinterest, hrp, ball, 0)
				pcall(firetouchinterest, hrp, ball, 1)
			end
		else
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = origin
		end
		ball.AssemblyLinearVelocity = dir * speed
	end)
end

-- preview de mira
local aimTip, aimA0, aimA1, aimBeam
local function buildAim()
	if aimTip or not lp then return end
	aimTip = Instance.new("Part")
	aimTip.Name = "APEX_AimTip"
	aimTip.Size = Vector3.new(0.2, 0.2, 0.2)
	aimTip.Transparency = 1
	aimTip.Anchored = true
	aimTip.CanCollide = false
	aimTip.CanQuery = false
	aimTip.CanTouch = false
	aimTip.Parent = WS

	aimA0 = Instance.new("Attachment")
	aimA1 = Instance.new("Attachment")
	aimA1.Parent = aimTip

	aimBeam = Instance.new("Beam")
	aimBeam.Attachment0 = aimA0
	aimBeam.Attachment1 = aimA1
	aimBeam.Width0 = 1.4
	aimBeam.Width1 = 0.35
	aimBeam.FaceCamera = true
	aimBeam.LightEmission = 1
	aimBeam.LightInfluence = 0
	aimBeam.Color = ColorSequence.new(C_BLUE, C_RED)
	aimBeam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	aimBeam.Segments = 12
	aimBeam.Enabled = false
end

local aimConn
function SS:StartAim()
	if not lp or not lp.Character then return end
	buildAim()
	local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not aimBeam then return end
	aimA0.Parent = hrp
	aimBeam.Parent = hrp
	aimBeam.Enabled = true
	self.Charging = true
	self.Charge = 0

	if aimConn then aimConn:Disconnect() end
	aimConn = RunService.RenderStepped:Connect(function(dt)
		if not hrp.Parent then return end
		if self.Charging then
			self.Charge = math.min(1, self.Charge + dt * 1.6)
			if SS_GUIREF.chargeFill then
				SS_GUIREF.chargeFill.Size = UDim2.fromScale(self.Charge, 1)
			end
		end
		local dir = self:Dir(hrp)
		aimTip.CFrame = CFrame.new(hrp.Position + dir * (self.Range + 6) + Vector3.new(0, -1, 0))
	end)
end

function SS:EndAim()
	self.Charging = false
	if aimConn then aimConn:Disconnect() aimConn = nil end
	if aimBeam then aimBeam.Enabled = false end
	if SS_GUIREF.chargeFill then SS_GUIREF.chargeFill.Size = UDim2.fromScale(0, 1) end
	self:Shoot()
end

--==================================================================================
--  MÓDULO 2 — STUDS 3B
--==================================================================================
local Studs = {
	Running = false, Count = 0, Target = 3e9,
	Batch = 900, Size = 8, Folder = nil, Template = nil,
}

function Studs:Prepare()
	if self.Folder and self.Folder.Parent then return end
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "APEX_Studs"
	self.Folder.Parent = WS

	local t = Instance.new("Part")
	t.Name = "Studs"
	t.Anchored = true
	t.CanCollide = true
	t.CastShadow = false
	t.Massless = true
	t.Material = Enum.Material.Plastic
	t.TopSurface = Enum.SurfaceType.Studs
	t.BottomSurface = Enum.SurfaceType.Inlet
	t.Color = Color3.fromRGB(163, 162, 165)
	self.Template = t
end

function Studs:Stop()
	self.Running = false
end

function Studs:Cleanup()
	self:Stop()
	if self.Folder then
		self.Folder:Destroy()
		self.Folder = nil
	end
	self.Count = 0
end

function Studs:Start()
	if self.Running then return end
	if not lp or not lp.Character then return end
	local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	self:Prepare()
	self.Running = true
	self.Count = 0

	local baseY = math.floor(hrp.Position.Y) - 4
	local originX, originZ = hrp.Position.X, hrp.Position.Z
	local folder, tmpl = self.Folder, self.Template
	local size, batch = self.Size, self.Batch
	local target = self.Target
	local started = os.clock()
	local sY = size

	local function place(gx, gz)
		local p = tmpl:Clone()
		p.Size = Vector3.new(size, 1, size)
		p.CFrame = CFrame.new(originX + gx * sY, baseY, originZ + gz * sY)
		p.Parent = folder
		self.Count += 1
	end

	task.spawn(function()
		local r = 0
		while self.Running and self.Count < target and folder.Parent do
			local placed = 0
			if r == 0 then
				place(0, 0); placed = 1
			else
				for i = -r, r do
					place(i, -r); place(i, r); placed += 2
					if placed >= batch then break end
				end
				if placed < batch then
					for i = -r + 1, r - 1 do
						place(-r, i); place(r, i); placed += 2
						if placed >= batch then break end
					end
				end
			end
			r += 1
			task.wait()
		end
		self.Running = false
		self.Elapsed = os.clock() - started
	end)
end

--==================================================================================
--  MÓDULO 3 — DEX (embutido, otimizado)
--==================================================================================
local function buildDex()
	local nodes = {}
	local selection

	local function missing(t, f, fallback)
		if type(f) == t then return f end
		return fallback
	end

	local cloneref = missing("function", cloneref, function(...) return ... end)
	local service = setmetatable({}, {
		__index = function(self, name)
			self[name] = cloneref(game:GetService(name))
			return self[name]
		end
	})

	local oldgame = game
	local game = workspace.Parent

	local EmbeddedModules = {}

	--================== LIB ==================
	EmbeddedModules.Lib = function()
		local Main, Lib, Apps, Settings, API, RMD, env, service, plr, create, createSimple

		local function initDeps(d)
			Main, Lib, Apps, Settings = d.Main, d.Lib, d.Apps, d.Settings
			API, RMD, env, service, plr = d.API, d.RMD, d.env, d.service, d.plr
			create, createSimple = d.create, d.createSimple
		end
		local function initAfterMain() end

		local function main()
			local Lib = {}
			local renderStepped = service.RunService.RenderStepped
			local signalWait = renderStepped.wait
			local PH, SIGNAL = newproxy(), newproxy()

			local function initObj(props, mt)
				local function copy(t)
					local r = {}
					for i, v in pairs(t) do
						if v == SIGNAL then r[i] = Lib.Signal.new()
						elseif type(v) == "table" then r[i] = copy(v)
						else r[i] = v end
					end
					return r
				end
				return setmetatable(copy(props), mt)
			end

			local function getGuiMT(props, funcs)
				return {
					__index = function(self, ind) if not props[ind] then return funcs[ind] or self.Gui[ind] end end,
					__newindex = function(self, ind, val) if not props[ind] then self.Gui[ind] = val else rawset(self, ind, val) end end,
				}
			end

			Lib.FormatLuaString = (function()
				local gsub, format, char = string.gsub, string.format, string.char
				local t = { ['"'] = '\\"', ['\\'] = '\\\\' }
				for i = 0, 31 do t[char(i)] = "\\" .. format("%03d", i) end
				for i = 127, 255 do t[char(i)] = "\\" .. format("%03d", i) end
				return function(s) return gsub(s, "[\"\\\0-\31\127-\255]", t) end
			end)()

			Lib.CheckMouseInGui = function(gui)
				if not gui then return false end
				local m, p, s = Main.Mouse, gui.AbsolutePosition, gui.AbsoluteSize
				return m.X >= p.X and m.X < p.X + s.X and m.Y >= p.Y and m.Y < p.Y + s.Y
			end
			Lib.IsShiftDown = function()
				return service.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or service.UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			end
			Lib.IsCtrlDown = function()
				return service.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or service.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			end

			Lib.FastWait = function(s)
				if not s then return signalWait(renderStepped) end
				local st = os.clock()
				while os.clock() - st < s do signalWait(renderStepped) end
			end

			Lib.CreateArrow = function(size, num, dir)
				local max = num
				local f = createSimple("Frame", { BackgroundTransparency = 1, Name = "Arrow", Size = UDim2.new(0, size, 0, size) })
				local mid = math.floor(size / 2)
				for i = 1, num do
					local pos
					if dir == "up" then pos = UDim2.new(0, mid - (i - 1), 0, mid + i - math.floor(max / 2) - 1)
					elseif dir == "down" then pos = UDim2.new(0, mid - (i - 1), 0, mid - i + math.floor(max / 2) + 1)
					elseif dir == "left" then pos = UDim2.new(0, mid + i - math.floor(max / 2) - 1, 0, mid - (i - 1))
					else pos = UDim2.new(0, mid - i + math.floor(max / 2) + 1, 0, mid - (i - 1)) end
					createSimple("Frame", {
						BackgroundColor3 = Color3.fromRGB(220, 220, 220),
						BorderSizePixel = 0,
						Position = pos,
						Size = (dir == "up" or dir == "down") and UDim2.new(0, i + (i - 1), 0, 1) or UDim2.new(0, 1, 0, i + (i - 1)),
						Parent = f,
					})
				end
				return f
			end

			Lib.ParseXML = (function()
				local function impl()
					local string, pairs = string, pairs
					local trim = function(s)
						local from = s:match"^%s*()"
						return from > #s and "" or s:match(".*%S", from)
					end
					local slashchar = string.byte('/', 1)
					local E = string.byte('E', 1)
					local function parse(s, evalEntities)
						s = s:gsub('<!%-%-(.-)%-%->', '')
						local entities, tentities = {}
						if evalEntities then
							local pos = s:find('<[_%w]')
							if pos then
								s:sub(1, pos):gsub('<!ENTITY%s+([_%w]+)%s+(.)(.-)%2', function(name, q, entity)
									entities[#entities + 1] = { name = name, value = entity }
								end)
								tentities = createEntityTable(entities)
								s = replaceEntities(s:sub(pos), tentities)
							end
						end
						local t, l = {}, {}
						local addtext = function(txt)
							txt = txt:match'^%s*(.*%S)' or ''
							if #txt ~= 0 then t[#t + 1] = { text = txt } end
						end
						s:gsub('<([?!/]?)([-:_%w]+)%s*(/?>?)([^<]*)', function(typ, name, closed, txt)
							if #typ == 0 then
								local a = {}
								if #closed == 0 then
									local len = 0
									for all, aname, _, value, starttxt in string.gmatch(txt, "(.-([-_%w]+)%s*=%s*(.)(.-)%3%s*(/?>?))") do
										len = len + #all
										a[aname] = value
										if #starttxt ~= 0 then txt = txt:sub(len + 1) closed = starttxt break end
									end
								end
								t[#t + 1] = { tag = name, attrs = a, children = {} }
								if closed:byte(1) ~= slashchar then l[#l + 1] = t t = t[#t].children end
								addtext(txt)
							elseif '/' == typ then
								t = l[#l]; l[#l] = nil
								addtext(txt)
							elseif '!' == typ then
								if E == name:byte(1) then
									txt:gsub('([_%w]+)%s+(.)(.-)%2', function(name, q, entity)
										entities[#entities + 1] = { name = name, value = entity }
									end, 1)
								end
							end
						end)
						return { children = t, entities = entities, tentities = tentities }
					end
					function createEntityTable(docEntities, resultEntities)
						local ents = resultEntities or { quot = '"', apos = '\'', lt = '<', gt = '>', amp = '&', tab = '\t', nbsp = ' ' }
						for _, e in pairs(docEntities) do
							e.value = replaceEntities(e.value, ents)
							ents[e.name] = e.value
						end
						return ents
					end
					function replaceEntities(s, ents) return s:gsub('&([^;]+);', ents) end
					return parse
				end
				local f = impl
				local newEnv = setmetatable({}, { __index = getfenv() })
				setfenv(f, newEnv)
				return f()
			end)()

			Lib.ButtonAnim = function(button, data)
				local holding, disabled = false, false
				local mode = data and data.Mode or 1
				local control = {}
				if mode == 2 then
					local lerpTo = data.LerpTo or Color3.new(0, 0, 0)
					local delta = data.LerpDelta or 0.2
					control.StartColor = data.StartColor or button.BackgroundColor3
					control.PressColor = data.PressColor or control.StartColor:lerp(lerpTo, delta)
					control.HoverColor = data.HoverColor or control.StartColor:lerp(control.PressColor, 0.6)
					control.OutlineColor = data.OutlineColor
				end
				button.InputBegan:Connect(function(input)
					if disabled then return end
					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						if not holding then
							if mode == 1 then button.BackgroundTransparency = 0.4
							elseif mode == 2 then button.BackgroundColor3 = control.HoverColor end
						end
					elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						holding = true
						if mode == 1 then button.BackgroundTransparency = 0
						elseif mode == 2 then
							button.BackgroundColor3 = control.PressColor
							if control.OutlineColor then button.BorderColor3 = control.PressColor end
						end
					end
				end)
				button.InputEnded:Connect(function(input)
					if disabled then return end
					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						if not holding then
							if mode == 1 then button.BackgroundTransparency = 1
							elseif mode == 2 then button.BackgroundColor3 = control.StartColor end
						end
					elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						holding = false
						if mode == 1 then button.BackgroundTransparency = Lib.CheckMouseInGui(button) and 0.4 or 1
						elseif mode == 2 then
							button.BackgroundColor3 = Lib.CheckMouseInGui(button) and control.HoverColor or control.StartColor
							if control.OutlineColor then button.BorderColor3 = control.OutlineColor end
						end
					end
				end)
				control.Disable = function()
					disabled = true; holding = false
					if mode == 1 then button.BackgroundTransparency = 1
					elseif mode == 2 then button.BackgroundColor3 = control.StartColor end
				end
				control.Enable = function() disabled = false end
				return control
			end

			Lib.FindAndRemove = function(t, item)
				local p = table.find(t, item)
				if p then table.remove(t, p) end
			end

			Lib.AttachTo = function(obj, data)
				local target, px, py, sx, sy, resize, con
				local disabled = false
				local function update()
					if not obj or not target then return end
					local tp, ts = target.AbsolutePosition, target.AbsoluteSize
					obj.Position = UDim2.new(0, tp.X + px, 0, tp.Y + py)
					if resize then obj.Size = UDim2.new(0, ts.X + sx, 0, ts.Y + sy) end
				end
				local function setup(o, d)
					obj = o; d = d or {}
					target = d.Target
					px, py = d.PosOffX or 0, d.PosOffY or 0
					sx, sy = d.SizeOffX or 0, d.SizeOffY or 0
					resize = d.Resize or false
					if con then con:Disconnect() con = nil end
					if target then
						con = target.Changed:Connect(function(prop)
							if not disabled and (prop == "AbsolutePosition" or prop == "AbsoluteSize") then update() end
						end)
					end
					update()
				end
				setup(obj, data)
				return {
					SetData = function(o, d) setup(o, d) end,
					Enable = function() disabled = false update() end,
					Disable = function() disabled = true end,
					Destroy = function() if con then con:Disconnect() con = nil end end,
				}
			end

			Lib.ShowGui = function(gui)
				if env.gethui then gui.Parent = env.gethui()
				elseif env.protectgui then env.protectgui(gui) gui.Parent = Main.GuiHolder
				else gui.Parent = Main.GuiHolder end
			end

			Lib.ColorToBytes = function(c)
				local r = math.round
				return ("%d, %d, %d"):format(r(c.r * 255), r(c.g * 255), r(c.b * 255))
			end
			Lib.ReadFile = function(f)
				if not env.readfile then return end
				local s, c = pcall(env.readfile, f)
				if s and c then return c end
			end
			Lib.DeferFunc = function(f, ...)
				signalWait(renderStepped)
				return f(...)
			end

			-- Signal
			Lib.Signal = (function()
				local funcs = {}
				funcs.Connect = function(self, func)
					if type(func) ~= "function" then error("Attempt to connect a non-function") end
					local con = { Signal = self, Func = func }
					con.Disconnect = function()
						local p = table.find(self.Connections, con)
						if p then table.remove(self.Connections, p) end
					end
					self.Connections[#self.Connections + 1] = con
					return con
				end
				funcs.Fire = function(self, ...)
					for _, v in next, self.Connections do
						xpcall(coroutine.wrap(v.Func), function(e) warn(e .. "\n" .. debug.traceback()) end, ...)
					end
				end
				local mt = {
					__index = funcs,
					__tostring = function(s) return "Signal: " .. tostring(#s.Connections) end,
				}
				return { new = function() return setmetatable({ Connections = {} }, mt) end }
			end)()

			-- Set
			Lib.Set = (function()
				local funcs = {}
				funcs.Add = function(self, obj)
					if self.Map[obj] then return end
					self.List[#self.List + 1] = obj
					self.Map[obj] = true
					self.Changed:Fire()
				end
				funcs.AddTable = function(self, t)
					local ch
					for i = 1, #t do
						if not self.Map[t[i]] then
							self.List[#self.List + 1] = t[i]
							self.Map[t[i]] = true
							ch = true
						end
					end
					if ch then self.Changed:Fire() end
				end
				funcs.Remove = function(self, obj)
					if not self.Map[obj] then return end
					local p = table.find(self.List, obj)
					if p then table.remove(self.List, p) end
					self.Map[obj] = nil
					self.Changed:Fire()
				end
				funcs.RemoveTable = function(self, t)
					local rs = {}
					for i = 1, #t do self.Map[t[i]] = nil rs[t[i]] = true end
					for i = #self.List, 1, -1 do
						if rs[self.List[i]] then table.remove(self.List, i) end
					end
					self.Changed:Fire()
				end
				funcs.Set = function(self, obj)
					if #self.List == 1 and self.List[1] == obj then return end
					self.List = { obj }
					self.Map = { [obj] = true }
					self.Changed:Fire()
				end
				funcs.SetTable = function(self, t)
					local nl, nm = {}, {}
					self.List, self.Map = nl, nm
					table.move(t, 1, #t, 1, nl)
					for i = 1, #t do nm[t[i]] = true end
					self.Changed:Fire()
				end
				funcs.Clear = function(self)
					if #self.List == 0 then return end
					self.List = {}; self.Map = {}
					self.Changed:Fire()
				end
				local mt = { __index = funcs }
				return {
					new = function()
						return setmetatable({ List = {}, Map = {}, Changed = Lib.Signal.new() }, mt)
					end,
				}
			end)()

			-- IconMap
			Lib.IconMap = (function()
				local funcs = {}
				funcs.GetLabel = function(self)
					local l = Instance.new("ImageLabel")
					self:SetupLabel(l)
					return l
				end
				funcs.SetupLabel = function(self, obj)
					obj.BackgroundTransparency = 1
					obj.ImageRectOffset = Vector2.new(0, 0)
					obj.ImageRectSize = Vector2.new(self.IconSizeX, self.IconSizeY)
					obj.ScaleType = Enum.ScaleType.Crop
					obj.Size = UDim2.new(0, self.IconSizeX, 0, self.IconSizeY)
				end
				funcs.Display = function(self, obj, index)
					obj.Image = self.MapId
					if not self.NumX then obj.ImageRectOffset = Vector2.new(self.IconSizeX * index, 0)
					else obj.ImageRectOffset = Vector2.new(self.IconSizeX * (index % self.NumX), self.IconSizeY * math.floor(index / self.NumX)) end
				end
				funcs.DisplayByKey = function(self, obj, key)
					if self.IndexDict[key] then self:Display(obj, self.IndexDict[key])
					else
						local e = RMD.Classes[obj.ClassName]
						Apps.Explorer.ClassIcons:Display(obj, e and e.ExplorerImageIndex or 0)
					end
				end
				funcs.IconDehash = function(self, id) return math.floor(id / 14 % 14), math.floor(id % 14) end
				funcs.GetExplorerIcon = function(self, obj, index)
					index = (self.ExplorerIcons.Icons[index] or 0)
					local row, col = self:IconDehash(index)
					local pad, border = 2, 1
					obj.Position = UDim2.new(-col - (pad * (col + 1) + border) / 16, 0, -row - (pad * (row + 1) + border) / 16, 0)
					obj.Size = UDim2.new(16, 0, 16, 0)
				end
				funcs.DisplayExplorerIcons = function(self, frame, index)
					local m = frame:FindFirstChild("IconMap")
					if m then self:GetExplorerIcon(m, index)
					else
						frame.ClipsDescendants = true
						local o = Instance.new("ImageLabel", frame)
						o.BackgroundTransparency = 1
						o.Image = "http://www.roblox.com/asset/?id=" .. self.ExplorerIcons.MapId
						o.Name = "IconMap"
						self:GetExplorerIcon(o, index)
					end
				end
				funcs.SetDict = function(self, d) self.IndexDict = d end
				local mt = { __index = funcs }
				local function newLinear(mapId, ix, iy)
					return setmetatable({ MapId = mapId, IconSizeX = ix, IconSizeY = iy, IndexDict = {} }, mt)
				end
				local function new(mapId, mx, my, ix, iy)
					return setmetatable({ MapId = mapId, MapSizeX = mx, MapSizeY = my, IconSizeX = ix, IconSizeY = iy, NumX = mx / ix, IndexDict = {} }, mt)
				end
				return { new = new, newLinear = newLinear }
			end)()

			-- ScrollBar
			Lib.ScrollBar = (function()
				local funcs = {}
				local user = service.UserInputService
				local mouse = plr:GetMouse()
				local checkMouseInGui = Lib.CheckMouseInGui
				local createArrow = Lib.CreateArrow

				local function drawThumb(self)
					local total, visible = self.TotalSpace, self.VisibleSpace
					local st, stf = self.GuiElems.ScrollThumb, self.GuiElems.ScrollThumbFrame
					st.Visible = self:CanScrollUp() or self:CanScrollDown()
					if self.Horizontal then
						st.Size = UDim2.new(visible / total, 0, 1, 0)
						if st.AbsoluteSize.X < 16 then st.Size = UDim2.new(0, 16, 1, 0) end
						local fs, bs = stf.AbsoluteSize.X, st.AbsoluteSize.X
						st.Position = UDim2.new(self:GetScrollPercent() * (fs - bs) / fs, 0, 0, 0)
					else
						st.Size = UDim2.new(1, 0, visible / total, 0)
						if st.AbsoluteSize.Y < 16 then st.Size = UDim2.new(1, 0, 0, 16) end
						local fs, bs = stf.AbsoluteSize.Y, st.AbsoluteSize.Y
						st.Position = UDim2.new(0, 0, self:GetScrollPercent() * (fs - bs) / fs, 0)
					end
				end

				local function createFrame(self)
					local f = createSimple("Frame", {
						Style = 0, Active = true, BackgroundColor3 = Color3.fromRGB(90, 90, 90),
						BackgroundTransparency = 0, BorderSizePixel = 0, ClipsDescendants = false,
						Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0), Name = "ScrollBar",
					})
					local b1, b2
					if self.Horizontal then
						f.Size = UDim2.new(1, 0, 0, 16)
						b1 = createSimple("ImageButton", { Parent = f, Size = UDim2.new(0, 16, 0, 16), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false })
						createArrow(16, 4, "left").Parent = b1
						b2 = createSimple("ImageButton", { Parent = f, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 0, 16), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false })
						createArrow(16, 4, "right").Parent = b2
					else
						b1 = createSimple("ImageButton", { Parent = f, Size = UDim2.new(0, 16, 0, 16), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false })
						createArrow(16, 4, "up").Parent = b1
						b2 = createSimple("ImageButton", { Parent = f, Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(0, 16, 0, 16), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false })
						createArrow(16, 4, "down").Parent = b2
					end
					local stf = createSimple("ImageButton", { BackgroundTransparency = 1, Parent = f })
					if self.Horizontal then stf.Position = UDim2.new(0, 16, 0, 0) stf.Size = UDim2.new(1, -32, 1, 0)
					else stf.Position = UDim2.new(0, 0, 0, 16) stf.Size = UDim2.new(1, 0, 1, -32) end
					local st = createSimple("Frame", { BackgroundColor3 = Color3.fromRGB(120, 120, 120), BorderSizePixel = 0, Parent = stf })
					local markers = createSimple("Frame", { BackgroundTransparency = 1, Name = "Markers", Size = UDim2.new(1, 0, 1, 0), Parent = stf })

					local thumbPress = false
					st.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							local dir = self.Horizontal and "X" or "Y"
							local last
							thumbPress = true
							local off = mouse[dir] - st.AbsolutePosition[dir]
							local rel, mev
							rel = user.InputEnded:Connect(function(i)
								if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
									rel:Disconnect()
									if mev then mev:Disconnect() end
									thumbPress = false
								end
							end)
							mev = user.InputChanged:Connect(function(i)
								if (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) and thumbPress then
									local fs = stf.AbsoluteSize[dir] - st.AbsoluteSize[dir]
									local p = mouse[dir] - stf.AbsolutePosition[dir] - off
									if p > fs then p = fs elseif p < 0 then p = 0 end
									if last ~= p then
										last = p
										self:ScrollTo(math.floor(0.5 + p / fs * (self.TotalSpace - self.VisibleSpace)))
									end
								end
							end)
						end
					end)
					stf.InputBegan:Connect(function(input)
						if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not checkMouseInGui(st) then
							local dir = self.Horizontal and "X" or "Y"
							local sd = (mouse[dir] >= st.AbsolutePosition[dir] + st.AbsoluteSize[dir]) and 1 or 0
							local size = self.VisibleSpace - 1
							if sd == 0 then self:ScrollTo(self.Index - size) else self:ScrollTo(self.Index + size) end
						end
					end)
					b1.MouseButton1Down:Connect(function() self:ScrollTo(self.Index - self.Increment) end)
					b2.MouseButton1Down:Connect(function() self:ScrollTo(self.Index + self.Increment) end)
					f.MouseWheelForward:Connect(function() self:ScrollTo(self.Index - self.WheelIncrement) end)
					f.MouseWheelBackward:Connect(function() self:ScrollTo(self.Index + self.WheelIncrement) end)
					self.GuiElems.ScrollThumb, self.GuiElems.ScrollThumbFrame = st, stf
					self.GuiElems.Button1, self.GuiElems.Button2 = b1, b2
					self.GuiElems.MarkerFrame = markers
					return f
				end

				funcs.Update = function(self)
					self.Index = math.clamp(self.Index, 0, math.max(0, self.TotalSpace - self.VisibleSpace))
					drawThumb(self)
				end
				funcs.ScrollTo = function(self, i, nocb)
					self.Index = i
					self:Update()
					if not nocb then self.Scrolled:Fire() end
				end
				funcs.CanScrollUp = function(self) return self.Index > 0 end
				funcs.CanScrollDown = function(self) return self.Index + self.VisibleSpace < self.TotalSpace end
				funcs.GetScrollPercent = function(self) return self.Index / (self.TotalSpace - self.VisibleSpace) end
				funcs.SetScrollFrame = function(self, frame)
					if self.SU then self.SU:Disconnect() end
					if self.SD then self.SD:Disconnect() end
					self.SU = frame.MouseWheelForward:Connect(function() self:ScrollTo(self.Index - self.WheelIncrement) end)
					self.SD = frame.MouseWheelBackward:Connect(function() self:ScrollTo(self.Index + self.WheelIncrement) end)
				end
				local mt = { __index = funcs }
				return {
					new = function(hor)
						local o = setmetatable({
							Index = 0, VisibleSpace = 0, TotalSpace = 0, Increment = 1, WheelIncrement = 1,
							Markers = {}, GuiElems = {}, Horizontal = hor, Scrolled = Lib.Signal.new(),
						}, mt)
						o.Gui = createFrame(o)
						return o
					end,
				}
			end)()

			-- Window
			Lib.Window = (function()
				local funcs = {}
				local static = { MinWidth = 200, FreeWidth = 200 }
				local mouse = plr:GetMouse()
				local sidesGui, alignIndicator
				local visibleWindows = {}
				local leftSide = { Width = 300, Windows = {}, ResizeCons = {}, Hidden = true }
				local rightSide = { Width = 300, Windows = {}, ResizeCons = {}, Hidden = true }
				local displayOrderStart, sideDisplayOrder
				local sideTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local tweens = {}
				local isA = game.IsA
				local theme = { MainColor1 = Color3.fromRGB(52, 52, 52), MainColor2 = Color3.fromRGB(45, 45, 45), Button = Color3.fromRGB(60, 60, 60) }

				local function resizeHook(self, resizer, dir)
					local guiMain = self.GuiElems.Main
					resizer.InputBegan:Connect(function(input)
						if not self.Dragging and not self.Resizing and self.Resizable and self.ResizableInternal then
							local isH = dir:find("[WE]") and true
							local isV = dir:find("[NS]") and true
							local signX = dir:find("W", 1, true) and -1 or 1
							local signY = dir:find("N", 1, true) and -1 or 1
							if self.Minimized and isV then return end
							if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
								resizer.BackgroundTransparency = 0.5
							elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								local rel, mev
								local offX = input.Position.X - resizer.AbsolutePosition.X
								local offY = input.Position.Y - resizer.AbsolutePosition.Y
								self.Resizing = resizer
								rel = service.UserInputService.InputEnded:Connect(function(i)
									if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
										rel:Disconnect()
										if mev then mev:Disconnect() end
										self.Resizing = false
										resizer.BackgroundTransparency = 1
									end
								end)
								mev = service.UserInputService.InputChanged:Connect(function(i)
									if self.Resizable and self.ResizableInternal and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
										local dx = i.Position.X - resizer.AbsolutePosition.X - offX
										local dy = i.Position.Y - resizer.AbsolutePosition.Y - offY
										if guiMain.AbsoluteSize.X + dx * signX < self.MinX then dx = signX * (self.MinX - guiMain.AbsoluteSize.X) end
										if guiMain.AbsoluteSize.Y + dy * signY < self.MinY then dy = signY * (self.MinY - guiMain.AbsoluteSize.Y) end
										guiMain.Position = guiMain.Position + UDim2.new(0, (signX < 0 and dx or 0), 0, (signY < 0 and dy or 0))
										self.SizeX = self.SizeX + (isH and dx * signX or 0)
										self.SizeY = self.SizeY + (isV and dy * signY or 0)
										guiMain.Size = UDim2.new(0, self.SizeX, 0, self.Minimized and 20 or self.SizeY)
									end
								end)
							end
						end
					end)
				end

				local function moveToTop(w)
					local f = table.find(visibleWindows, w)
					if f then table.remove(visibleWindows, f) table.insert(visibleWindows, 1, w) end
				end

				local function focusInput(self, obj)
					if isA(obj, "GuiButton") then obj.MouseButton1Down:Connect(function() moveToTop(self) end)
					elseif isA(obj, "TextBox") then obj.Focused:Connect(function() moveToTop(self) end) end
				end

				local createGui = function(self)
					local gui = create({
						{ 1, "ScreenGui", { Name = "Window" } },
						{ 2, "Frame", { Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Main", Parent = { 1 }, Position = UDim2.new(0.4, 0, 0.4, 0), Size = UDim2.new(0, 300, 0, 300) } },
						{ 3, "Frame", { BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0, Name = "Content", Parent = { 2 }, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 1, -20), ClipsDescendants = true } },
						{ 4, "Frame", { BackgroundColor3 = Color3.fromRGB(33, 33, 33), BorderSizePixel = 0, Name = "Line", Parent = { 3 }, Size = UDim2.new(1, 0, 0, 1) } },
						{ 5, "TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(52, 52, 52), BorderSizePixel = 0, Name = "TopBar", Parent = { 2 }, Size = UDim2.new(1, 0, 0, 20) } },
						{ 6, "TextLabel", { BackgroundTransparency = 1, Font = 3, Name = "Title", Parent = { 5 }, Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -10, 0, 20), Text = "Window", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = 0 } },
						{ 7, "TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Close", Parent = { 5 }, Position = UDim2.new(1, -18, 0, 2), Size = UDim2.new(0, 16, 0, 16), Text = "", TextSize = 14 } },
						{ 8, "ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://5054663650", Parent = { 7 }, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0, 10, 0, 10) } },
						{ 9, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 7 } } },
						{ 10, "TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Minimize", Parent = { 5 }, Position = UDim2.new(1, -36, 0, 2), Size = UDim2.new(0, 16, 0, 16), Text = "", TextSize = 14 } },
						{ 11, "ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://5034768003", Parent = { 10 }, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0, 10, 0, 10) } },
						{ 12, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 10 } } },
						{ 13, "Frame", { BackgroundTransparency = 1, Name = "ResizeControls", Parent = { 2 }, Position = UDim2.new(0, -5, 0, -5), Size = UDim2.new(1, 10, 1, 10) } },
					})
					local names = { "North", "South", "NorthEast", "East", "West", "SouthEast", "NorthWest", "SouthWest" }
					for _, n in ipairs(names) do
						createSimple("TextButton", {
							AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3,
							Name = n, Parent = gui.Main.ResizeControls, Text = "",
						})
					end
					gui.Main.ResizeControls.North.Position = UDim2.new(0, 5, 0, 0)
					gui.Main.ResizeControls.North.Size = UDim2.new(1, -10, 0, 5)
					gui.Main.ResizeControls.South.Position = UDim2.new(0, 5, 1, -5)
					gui.Main.ResizeControls.South.Size = UDim2.new(1, -10, 0, 5)
					gui.Main.ResizeControls.NorthEast.Position = UDim2.new(1, -5, 0, 0)
					gui.Main.ResizeControls.NorthEast.Size = UDim2.new(0, 5, 0, 5)
					gui.Main.ResizeControls.SouthEast.Position = UDim2.new(1, -5, 1, -5)
					gui.Main.ResizeControls.SouthEast.Size = UDim2.new(0, 5, 0, 5)
					gui.Main.ResizeControls.East.Position = UDim2.new(1, -5, 0, 5)
					gui.Main.ResizeControls.East.Size = UDim2.new(0, 5, 1, -10)
					gui.Main.ResizeControls.West.Position = UDim2.new(0, 0, 0, 5)
					gui.Main.ResizeControls.West.Size = UDim2.new(0, 5, 1, -10)
					gui.Main.ResizeControls.NorthWest.Size = UDim2.new(0, 5, 0, 5)
					gui.Main.ResizeControls.SouthWest.Position = UDim2.new(0, 0, 1, -5)
					gui.Main.ResizeControls.SouthWest.Size = UDim2.new(0, 5, 0, 5)

					local guiMain = gui.Main
					self.GuiElems.Main = guiMain
					self.GuiElems.TopBar = guiMain.TopBar
					self.GuiElems.Content = guiMain.Content
					self.GuiElems.Line = guiMain.Content.Line
					self.GuiElems.Title = guiMain.TopBar.Title
					self.GuiElems.Close = guiMain.TopBar.Close
					self.GuiElems.Minimize = guiMain.TopBar.Minimize
					self.GuiElems.ResizeControls = guiMain.ResizeControls
					self.ContentPane = guiMain.Content

					local down = false
					guiMain.TopBar.MouseButton1Down:Connect(function() down = true end)
					guiMain.TopBar.MouseButton1Up:Connect(function() down = false end)

					guiMain.TopBar.InputBegan:Connect(function(input)
						if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and self.Draggable then
							local rel, mev
							local initX, initY = guiMain.AbsolutePosition.X, guiMain.AbsolutePosition.Y
							local offX = input.Position.X - initX
							local offY = input.Position.Y - initY
							local aPos, aSide
							rel = service.UserInputService.InputEnded:Connect(function(i)
								if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
									rel:Disconnect()
									if mev then mev:Disconnect() end
									alignIndicator.Parent = nil
									if aSide then
										local ts = (aSide == "left" and leftSide) or rightSide
										self:AlignTo(ts, aPos)
									end
								end
							end)
							mev = service.UserInputService.InputChanged:Connect(function(i)
								if (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) and down then
									local px, py = i.Position.X - offX, i.Position.Y - offY
									if self.Aligned then
										if math.sqrt((px - initX) ^ 2 + (py - initY) ^ 2) >= 5 then self:SetAligned(false) end
									else
										if py < 0 then py = 0 end
										guiMain.Position = UDim2.new(0, px, 0, py)
									end
								end
							end)
						end
					end)

					guiMain.TopBar.Close.MouseButton1Click:Connect(function() if not self.Closed then self:Close() end end)
					guiMain.TopBar.Minimize.MouseButton1Click:Connect(function()
						if not self.Closed then
							if self.Aligned then self:SetAligned(false) else self:SetMinimized() end
						end
					end)

					resizeHook(self, guiMain.ResizeControls.North, "N")
					resizeHook(self, guiMain.ResizeControls.NorthEast, "NE")
					resizeHook(self, guiMain.ResizeControls.East, "E")
					resizeHook(self, guiMain.ResizeControls.SouthEast, "SE")
					resizeHook(self, guiMain.ResizeControls.South, "S")
					resizeHook(self, guiMain.ResizeControls.SouthWest, "SW")
					resizeHook(self, guiMain.ResizeControls.West, "W")
					resizeHook(self, guiMain.ResizeControls.NorthWest, "NW")

					guiMain.Size = UDim2.new(0, self.SizeX, 0, self.SizeY)
					gui.DescendantAdded:Connect(function(o) focusInput(self, o) end)
					for _, o in ipairs(gui:GetDescendants()) do focusInput(self, o) end
					return gui
				end

				local function updateSideFrames(noTween)
					leftSide.Frame.Size = UDim2.new(0, leftSide.Width, 1, 0)
					rightSide.Frame.Size = UDim2.new(0, rightSide.Width, 1, 0)
					leftSide.Frame.Resizer.Position = UDim2.new(0, leftSide.Width, 0, 0)
					rightSide.Frame.Resizer.Position = UDim2.new(0, -5, 0, 0)
					local lh = #leftSide.Windows == 0 or leftSide.Hidden
					local rh = #rightSide.Windows == 0 or rightSide.Hidden
					local lp2 = lh and UDim2.new(0, -leftSide.Width - 10, 0, 0) or UDim2.new(0, 0, 0, 0)
					local rp = rh and UDim2.new(1, 10, 0, 0) or UDim2.new(1, -rightSide.Width, 0, 0)
					sidesGui.LeftToggle.Text = lh and ">" or "<"
					sidesGui.RightToggle.Text = rh and "<" or ">"
					leftSide.Frame.Position = lp2
					rightSide.Frame.Position = rp
					sidesGui.LeftToggle.Position = UDim2.new(0, #leftSide.Windows == 0 and -16 or 0, 0, -36)
					sidesGui.RightToggle.Position = UDim2.new(1, #rightSide.Windows == 0 and 0 or -16, 0, -36)
				end

				local function sideResized(side)
					local cur = 0
					local pos = side == leftSide and UDim2.new(0, 0, 0, 0) or UDim2.new(1, -rightSide.Width, 0, 0)
					for _, v in ipairs(side.Windows) do
						v.SizeX = side.Width
						v.GuiElems.Main.Size = UDim2.new(0, side.Width, 0, v.SizeY)
						v.GuiElems.Main.Position = UDim2.new(pos.X.Scale, pos.X.Offset, 0, cur)
						cur = cur + v.SizeY + 4
					end
				end

				local function sideResizerHook(resizer, dir, side, pos)
					local windows = side.Windows
					resizer.InputBegan:Connect(function(input)
						if side.Resizing then return end
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							local rel, iev
							local offY = input.Position.Y - resizer.AbsolutePosition.Y
							local offX = input.Position.X - resizer.AbsolutePosition.X
							side.Resizing = resizer
							rel = service.UserInputService.InputEnded:Connect(function(i)
								if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
									rel:Disconnect()
									if iev then iev:Disconnect() end
									side.Resizing = false
								end
							end)
							iev = service.UserInputService.InputChanged:Connect(function(i)
								if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
									if dir == "V" then
										local delta = i.Position.Y - resizer.AbsolutePosition.Y - offY
										if delta > 0 then
											local need = delta
											for j = pos + 1, #windows do
												local w = windows[j]
												local ns = math.max(w.SizeY - need, w.MinY or 100)
												need = need - (w.SizeY - ns)
												w.SizeY = ns
											end
											windows[pos].SizeY = windows[pos].SizeY + math.max(0, delta - need)
										else
											local need = -delta
											for j = pos, 1, -1 do
												local w = windows[j]
												local ns = math.max(w.SizeY - need, w.MinY or 100)
												need = need - (w.SizeY - ns)
												w.SizeY = ns
											end
											windows[pos + 1].SizeY = windows[pos + 1].SizeY + math.max(0, -delta - need)
										end
										updateSideFrames()
										sideResized(side)
									elseif dir == "H" then
										local maxW = math.max(300, sidesGui.AbsoluteSize.X - static.FreeWidth)
										local other = side == leftSide and rightSide or leftSide
										local delta = i.Position.X - resizer.AbsolutePosition.X - offX
										delta = side == leftSide and delta or -delta
										local prop = math.max(static.MinWidth, side.Width + delta)
										if prop + other.Width <= maxW then side.Width = prop
										else
											local no = maxW - prop
											if no >= static.MinWidth then side.Width = prop other.Width = no
											else side.Width = maxW - static.MinWidth other.Width = static.MinWidth end
										end
										updateSideFrames(true)
										sideResized(side)
										sideResized(other)
									end
								end
							end)
						end
					end)
				end

				local function renderSide(side, noTween)
					local cur = 0
					local pos = side == leftSide and UDim2.new(0, 0, 0, 0) or UDim2.new(1, -rightSide.Width, 0, 0)
					local template = side.WindowResizer:Clone()
					for _, c in ipairs(side.ResizeCons) do c:Disconnect() end
					for _, v in ipairs(side.Frame:GetChildren()) do if v.Name == "WindowResizer" then v:Destroy() end end
					side.ResizeCons = {}
					side.Resizing = nil
					for i, v in ipairs(side.Windows) do
						v.SidePos = i
						Lib.ShowGui(v.Gui)
						local sz = UDim2.new(0, side.Width, 0, v.SizeY)
						local p = UDim2.new(pos.X.Scale, pos.X.Offset, 0, cur)
						if noTween then v.GuiElems.Main.Size = sz v.GuiElems.Main.Position = p
						else
							local tw = service.TweenService:Create(v.GuiElems.Main, sideTweenInfo, { Size = sz, Position = p })
							tweens[#tweens + 1] = tw
							tw:Play()
						end
						cur = cur + v.SizeY + 4
						if i ~= #side.Windows then
							local nt = template:Clone()
							nt.Position = UDim2.new(1, -side.Width, 0, cur - 4)
							side.ResizeCons[#side.ResizeCons + 1] = v.Gui.Main:GetPropertyChangedSignal("Size"):Connect(function()
								nt.Position = UDim2.new(1, -side.Width, 0, v.GuiElems.Main.Position.Y.Offset + v.GuiElems.Main.Size.Y.Offset)
							end)
							sideResizerHook(nt, "V", side, i)
							nt.Parent = side.Frame
						end
					end
				end

				local function updateSide(side, noTween)
					local oldH, cur, need = 0, 0, 0
					local windows = side.Windows
					local height = sidesGui.AbsoluteSize.Y - (math.max(0, #windows - 1) * 4)
					for _, v in ipairs(windows) do oldH = oldH + v.SizeY end
					for i, v in ipairs(windows) do
						if i == #windows then
							v.SizeY = height - cur
							need = math.max(0, (v.MinY or 100) - v.SizeY)
						else
							v.SizeY = math.max(math.floor(v.SizeY / oldH * height), v.MinY or 100)
						end
						cur = cur + v.SizeY
					end
					if need > 0 then
						for i = #windows - 1, 1, -1 do
							local w = windows[i]
							local ns = math.max(w.SizeY - need, w.MinY or 100)
							need = need - (w.SizeY - ns)
							w.SizeY = ns
						end
						windows[#windows].SizeY = (windows[#windows].MinY or 100) - need
					end
					renderSide(side, noTween)
				end

				local function updateWindows(noTween)
					updateSideFrames(noTween)
					updateSide(leftSide, noTween)
					updateSide(rightSide, noTween)
					local c = 0
					for i = #visibleWindows, 1, -1 do
						visibleWindows[i].Gui.DisplayOrder = displayOrderStart + c
						Lib.ShowGui(visibleWindows[i].Gui)
						c = c + 1
					end
				end

				funcs.SetMinimized = function(self, set, mode)
					local old = self.Minimized
					local nv = set == nil and (not self.Minimized) or set
					self.Minimized = nv
					mode = mode or 1
					local rc = self.GuiElems.ResizeControls
					for _, n in ipairs({ "North", "NorthEast", "NorthWest", "South", "SouthEast", "SouthWest" }) do
						local c = rc:FindFirstChild(n)
						if c then c.Visible = not nv end
					end
					if mode == 1 then
						self.GuiElems.Main:TweenSize(UDim2.new(0, self.SizeX, 0, nv and 20 or self.SizeY), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
					end
					self.GuiElems.Minimize.ImageLabel.Image = nv and "rbxassetid://5060023708" or "rbxassetid://5034768003"
					if old ~= nv then
						if nv then self.OnMinimize:Fire() else self.OnRestore:Fire() end
					end
				end

				funcs.Resize = function(self, sx, sy)
					self.SizeX = sx or self.SizeX
					self.SizeY = sy or self.SizeY
					self.GuiElems.Main.Size = UDim2.new(0, self.SizeX, 0, self.SizeY)
				end
				funcs.SetSize = funcs.Resize
				funcs.SetTitle = function(self, t) self.GuiElems.Title.Text = t end
				funcs.SetResizable = function(self, v) self.Resizable = v self.GuiElems.ResizeControls.Visible = v and self.ResizableInternal end
				funcs.SetResizableInternal = function(self, v) self.ResizableInternal = v self.GuiElems.ResizeControls.Visible = self.Resizable and v end

				funcs.SetAligned = function(self, v)
					self.Aligned = v
					self:SetResizableInternal(not v)
					self.GuiElems.Main.Active = not v
					if not v then
						for i, x in ipairs(leftSide.Windows) do if x == self then table.remove(leftSide.Windows, i) break end end
						for i, x in ipairs(rightSide.Windows) do if x == self then table.remove(rightSide.Windows, i) break end end
						if not table.find(visibleWindows, self) then table.insert(visibleWindows, 1, self) end
						self.GuiElems.Minimize.ImageLabel.Image = "rbxassetid://5034768003"
						self.Side = nil
						updateWindows()
					else
						self:SetMinimized(false, 3)
						for i, x in ipairs(visibleWindows) do if x == self then table.remove(visibleWindows, i) break end end
						self.GuiElems.Minimize.ImageLabel.Image = "rbxassetid://5448127505"
					end
				end

				funcs.Add = function(self, obj, name)
					if type(obj) == "table" and obj.Gui and obj.Gui:IsA("GuiObject") then obj.Gui.Parent = self.ContentPane
					else obj.Parent = self.ContentPane end
					if name then self.Elements[name] = obj end
				end

				funcs.AlignTo = function(self, side, pos, size, silent)
					if table.find(side.Windows, self) or self.Closed then return end
					size = size or self.SizeY
					if size > 0 and size <= 1 then
						local tot = 0
						for _, v in ipairs(side.Windows) do tot = tot + v.SizeY end
						self.SizeY = (tot > 0 and tot * size * 2) or size
					else self.SizeY = (size > 0 and size or 100) end
					self:SetAligned(true)
					self.Side = side
					self.SizeX = side.Width
					self.Gui.DisplayOrder = sideDisplayOrder + 1
					for _, v in ipairs(side.Windows) do v.Gui.DisplayOrder = sideDisplayOrder end
					pos = math.min(#side.Windows + 1, pos or 1)
					self.SidePos = pos
					table.insert(side.Windows, pos, self)
					if not silent then side.Hidden = false end
				end

				funcs.Close = function(self)
					self.Closed = true
					self:SetResizableInternal(false)
					Lib.FindAndRemove(leftSide.Windows, self)
					Lib.FindAndRemove(rightSide.Windows, self)
					Lib.FindAndRemove(visibleWindows, self)
					self.ClosedSide = self.Side
					self.Side = nil
					self.OnDeactivate:Fire()
					self.Aligned = false
					self.Gui.Parent = nil
					updateWindows(true)
				end
				funcs.Hide = funcs.Close
				funcs.IsVisible = function(self) return not self.Closed and ((self.Side and not self.Side.Hidden) or not self.Side) end
				funcs.IsContentVisible = function(self) return self:IsVisible() and not self.Minimized end
				funcs.Focus = function(self) moveToTop(self) end

				funcs.Show = function(self, data)
					data = data or {}
					local align = data.Align
					local pos = data.Pos
					local size = data.Size
					local ts = (align == "left" and leftSide) or rightSide
					if not self.Closed then
						if not self.Aligned then self:SetMinimized(false)
						elseif self.Side and not data.Silent then static.SetSideVisible(self.Side, true) end
						return
					end
					self.Closed = false
					self.GuiElems.Minimize.ImageLabel.Image = "rbxassetid://5034768003"
					self:SetMinimized(false, 3)
					self:SetResizableInternal(true)
					if align then
						self:AlignTo(ts, pos, size, data.Silent)
					else
						if align == nil and self.ClosedSide then
							self:AlignTo(self.ClosedSide, self.SidePos, size, true)
							static.SetSideVisible(self.ClosedSide, true)
						else
							if table.find(visibleWindows, self) then return end
							self.GuiElems.Main.Size = UDim2.new(0, self.SizeX, 0, 20)
							local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
							local tw = service.TweenService:Create(self.GuiElems.Main, ti, { Size = UDim2.new(0, self.SizeX, 0, self.SizeY) })
							tw:Play()
							self.SizeY = size or self.SizeY
							table.insert(visibleWindows, 1, self)
							updateWindows()
						end
					end
					self.ClosedSide = nil
					self.OnActivate:Fire()
				end
				funcs.ShowAndFocus = function(self, d) self:Show(d) service.RunService.RenderStepped:wait() self:Focus() end

				static.ToggleSide = function(name)
					local s = name == "left" and leftSide or rightSide
					s.Hidden = not s.Hidden
					for _, v in ipairs(s.Windows) do
						if s.Hidden then v.OnDeactivate:Fire() else v.OnActivate:Fire() end
					end
					updateWindows()
				end
				static.SetSideVisible = function(s, vis)
					local side = type(s) == "table" and s or (s == "left" and leftSide or rightSide)
					side.Hidden = not vis
					for _, v in ipairs(side.Windows) do
						if side.Hidden then v.OnDeactivate:Fire() else v.OnActivate:Fire() end
					end
					updateWindows()
				end

				static.Init = function()
					displayOrderStart = Main.DisplayOrders.Window
					sideDisplayOrder = Main.DisplayOrders.SideWindow
					sidesGui = Instance.new("ScreenGui")

					local lf = create({
						{ 1, "Frame", { Active = true, Name = "LeftSide", BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0 } },
						{ 2, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(65, 65, 65), BorderSizePixel = 0, Name = "Resizer", Parent = { 1 }, Size = UDim2.new(0, 5, 1, 0), Text = "" } },
						{ 3, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(65, 65, 65), BorderSizePixel = 0, Name = "WindowResizer", Parent = { 1 }, Position = UDim2.new(1, -300, 0, 0), Size = UDim2.new(1, 0, 0, 4), Text = "" } },
					})
					leftSide.Frame = lf
					lf.Position = UDim2.new(0, -310, 0, 0)
					leftSide.WindowResizer = lf.WindowResizer
					lf.WindowResizer.Parent = nil
					lf.Parent = sidesGui

					local rf = create({
						{ 1, "Frame", { Active = true, Name = "RightSide", BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0 } },
						{ 2, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(65, 65, 65), BorderSizePixel = 0, Name = "Resizer", Parent = { 1 }, Size = UDim2.new(0, 5, 1, 0), Text = "" } },
						{ 3, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(65, 65, 65), BorderSizePixel = 0, Name = "WindowResizer", Parent = { 1 }, Position = UDim2.new(1, -300, 0, 0), Size = UDim2.new(1, 0, 0, 4), Text = "" } },
					})
					rightSide.Frame = rf
					rf.Position = UDim2.new(1, 10, 0, 0)
					rightSide.WindowResizer = rf.WindowResizer
					rf.WindowResizer.Parent = nil
					rf.Parent = sidesGui

					sideResizerHook(lf.Resizer, "H", leftSide)
					sideResizerHook(rf.Resizer, "H", rightSide)

					alignIndicator = Instance.new("ScreenGui")
					alignIndicator.DisplayOrder = Main.DisplayOrders.Core
					local ind = Instance.new("Frame", alignIndicator)
					ind.BackgroundColor3 = C_BLUE
					ind.BorderSizePixel = 0
					ind.BackgroundTransparency = 0.8
					ind.Name = "Indicator"
					Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 10)

					local lt = create({ { 1, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(52, 52, 52), BorderSizePixel = 0, Font = 10, Name = "LeftToggle", Position = UDim2.new(0, 0, 0, -36), Size = UDim2.new(0, 16, 0, 36), Text = "<", TextColor3 = Color3.new(1, 1, 1), TextSize = 14 } } })
					local rt = lt:Clone()
					rt.Name = "RightToggle"
					rt.Position = UDim2.new(1, -16, 0, -36)
					lt.MouseButton1Click:Connect(function() static.ToggleSide("left") end)
					rt.MouseButton1Click:Connect(function() static.ToggleSide("right") end)
					lt.Parent = sidesGui
					rt.Parent = sidesGui

					sidesGui.DisplayOrder = sideDisplayOrder - 1
					Lib.ShowGui(sidesGui)
					updateSideFrames()
				end

				local mt = { __index = funcs }
				static.new = function()
					local o = setmetatable({
						Minimized = false, Dragging = false, Resizing = false, Aligned = false,
						Draggable = true, Resizable = true, ResizableInternal = true, Alignable = true,
						Closed = true, SizeX = 300, SizeY = 300, MinX = 200, MinY = 200, PosX = 0, PosY = 0,
						GuiElems = {}, Tweens = {}, Elements = {},
						OnActivate = Lib.Signal.new(), OnDeactivate = Lib.Signal.new(),
						OnMinimize = Lib.Signal.new(), OnRestore = Lib.Signal.new(),
					}, mt)
					o.Gui = createGui(o)
					return o
				end
				return static
			end)()

			-- ContextMenu
			Lib.ContextMenu = (function()
				local funcs = {}
				local mouse

				local function createGui(self)
					local g = create({
						{ 1, "ScreenGui", { DisplayOrder = 1000000, Name = "Context", ZIndexBehavior = 1 } },
						{ 2, "Frame", { Active = true, BackgroundColor3 = Color3.fromRGB(36, 36, 36), BorderSizePixel = 0, Name = "Main", Parent = { 1 }, Position = UDim2.new(0.5, -100, 0.5, -150), Size = UDim2.new(0, 200, 0, 100) } },
						{ 3, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 2 } } },
						{ 4, "Frame", { BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0, Name = "Container", Parent = { 2 }, Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2) } },
						{ 5, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 4 } } },
						{ 6, "ScrollingFrame", { Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0), Name = "List", Parent = { 4 }, Position = UDim2.new(0, 2, 0, 2), ScrollBarImageColor3 = Color3.new(0, 0, 0), ScrollBarThickness = 4, Size = UDim2.new(1, -4, 1, -4) } },
						{ 7, "UIListLayout", { Parent = { 6 }, SortOrder = 2 } },
						{ 8, "Frame", { BackgroundColor3 = Color3.fromRGB(52, 52, 52), BorderSizePixel = 0, Name = "SearchFrame", Parent = { 4 }, Size = UDim2.new(1, 0, 0, 24), Visible = false } },
						{ 9, "Frame", { BackgroundColor3 = Color3.fromRGB(38, 38, 38), BorderSizePixel = 0, Name = "SearchContainer", Parent = { 8 }, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(1, -6, 0, 18) } },
						{ 10, "TextBox", { BackgroundTransparency = 1, Font = 3, Name = "SearchBox", Parent = { 9 }, PlaceholderColor3 = Color3.fromRGB(100, 100, 100), PlaceholderText = "Search", Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -8, 0, 18), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = 0 } },
						{ 11, "TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Entry", Parent = { 1 }, Size = UDim2.new(1, 0, 0, 22), Text = "", TextSize = 14, Visible = false } },
						{ 12, "TextLabel", { BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "EntryName", Parent = { 11 }, Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -24, 1, 0), Text = "", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 14, TextXAlignment = 0 } },
						{ 13, "TextLabel", { BackgroundTransparency = 1, Font = 3, Name = "Shortcut", Parent = { 11 }, Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -30, 1, 0), Text = "", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 14, TextXAlignment = 1 } },
						{ 14, "ImageLabel", { BackgroundTransparency = 1, Name = "Icon", Parent = { 11 }, Position = UDim2.new(0, 2, 0, 3), ScaleType = 4, Size = UDim2.new(0, 16, 0, 16) } },
						{ 15, "Frame", { BackgroundColor3 = Color3.fromRGB(55, 55, 55), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Divider", Parent = { 1 }, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 7), Visible = false } },
						{ 16, "Frame", { BackgroundColor3 = Color3.fromRGB(52, 52, 52), BorderSizePixel = 0, Name = "Line", Parent = { 15 }, Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1) } },
						{ 17, "TextLabel", { AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "DividerName", Parent = { 15 }, Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.new(1, -4, 1, 0), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextTransparency = 0.6, TextXAlignment = 0, Visible = false } },
					})
					self.GuiElems.Main = g.Main
					self.GuiElems.List = g.Main.Container.List
					self.GuiElems.Entry = g.Entry
					self.GuiElems.Divider = g.Divider
					self.GuiElems.SearchFrame = g.Main.Container.SearchFrame
					self.GuiElems.SearchBar = g.Main.Container.SearchFrame.SearchContainer.SearchBox
					Lib.ViewportTextBox.convert(self.GuiElems.SearchBar)
					self.GuiElems.SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
						local st = self.GuiElems.SearchBar.Text:lower()
						for i, item in ipairs(self.Items) do
							local e = self.ItemToEntryMap[item]
							if e and not item.Divider then e.Visible = st == "" or item.Name:lower():find(st, 1, true) ~= nil end
						end
					end)
					return g
				end

				funcs.Add = function(self, item)
					self.Items[#self.Items + 1] = {
						Name = item.Name or "Item", Icon = item.Icon or "", Shortcut = item.Shortcut or "",
						OnClick = item.OnClick, Disabled = item.Disabled or false,
						DisabledIcon = item.DisabledIcon or "", IconMap = item.IconMap, OnRightClick = item.OnRightClick,
					}
					self.Updated = nil
				end
				funcs.AddRegistered = function(self, name, dis)
					if not self.Registered[name] then return end
					self.Registered[name].Disabled = dis
					self.Items[#self.Items + 1] = self.Registered[name]
					self.Updated = nil
				end
				funcs.Register = function(self, name, item)
					self.Registered[name] = {
						Name = item.Name or "Item", Icon = item.Icon or "", Shortcut = item.Shortcut or "",
						OnClick = item.OnClick, DisabledIcon = item.DisabledIcon or "", IconMap = item.IconMap,
						OnRightClick = item.OnRightClick,
					}
				end
				funcs.AddDivider = function(self, text)
					self.QueuedDivider = false
					table.insert(self.Items, { Divider = true, Text = text })
					self.Updated = nil
				end
				funcs.QueueDivider = function(self, text)
					self.QueuedDivider = true
					self.QueuedDividerText = text or ""
				end
				funcs.Clear = function(self) self.Items = {} self.Updated = nil end

				funcs.Refresh = function(self)
					for _, v in ipairs(self.GuiElems.List:GetChildren()) do
						if not v:IsA("UIListLayout") then v:Destroy() end
					end
					local map = {}
					self.ItemToEntryMap = map
					for i, item in ipairs(self.Items) do
						if item.Divider then
							local d = self.GuiElems.Divider:Clone()
							if item.Text then
								d.Size = UDim2.new(1, 0, 0, 20)
								d.DividerName.Text = item.Text
								d.DividerName.Visible = true
							end
							d.Visible = true
							map[item] = d
							d.Parent = self.GuiElems.List
						else
							local e = self.GuiElems.Entry:Clone()
							e.EntryName.Text = item.Name
							e.Shortcut.Text = item.Shortcut
							if item.Disabled then
								e.EntryName.TextColor3 = Color3.fromRGB(150, 150, 150)
							else
								if item.OnClick then
									e.MouseButton1Click:Connect(function() item.OnClick(item.Name) self:Hide() end)
								end
								if item.OnRightClick then
									e.MouseButton2Click:Connect(function() item.OnRightClick(item.Name) self:Hide() end)
								end
							end
							e.InputBegan:Connect(function(i)
								if i.UserInputType == Enum.UserInputType.MouseMovement then e.BackgroundTransparency = 0 end
							end)
							e.InputEnded:Connect(function(i)
								if i.UserInputType == Enum.UserInputType.MouseMovement then e.BackgroundTransparency = 1 end
							end)
							e.Visible = true
							map[item] = e
							e.Parent = self.GuiElems.List
						end
					end
					self.Updated = true
				end

				funcs.Show = function(self, x, y)
					local elems = self.GuiElems
					elems.SearchFrame.Visible = self.SearchEnabled
					elems.List.Position = UDim2.new(0, 2, 0, 2 + (self.SearchEnabled and 24 or 0))
					elems.List.Size = UDim2.new(1, -4, 1, -4 - (self.SearchEnabled and 24 or 0))
					if not self.Updated then self:Refresh() end
					x, y = x or mouse.X, y or mouse.Y
					local maxX, maxY = mouse.ViewSizeX, mouse.ViewSizeY
					if x + self.Width > maxX then x = maxX - self.Width end
					elems.Main.Position = UDim2.new(0, x, 0, y)
					elems.Main.Size = UDim2.new(0, self.Width, 0, 0)
					Lib.ShowGui(self.Gui)
					local toSize = elems.List.UIListLayout.AbsoluteContentSize.Y + 6
					if self.MaxHeight and toSize > self.MaxHeight then
						elems.List.CanvasSize = UDim2.new(0, 0, 0, toSize - 6)
						toSize = self.MaxHeight
					end
					local rev = y + toSize > maxY
					if rev then
						local ny = y - toSize - (self.ReverseYOffset or 0)
						y = ny >= 0 and ny or 0
					end
					elems.Main:TweenSizeAndPosition(UDim2.new(0, self.Width, 0, toSize), UDim2.new(0, x, 0, y), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.18, true)
					local closable = false
					if self.CloseEvent then self.CloseEvent:Disconnect() end
					self.CloseEvent = service.UserInputService.InputBegan:Connect(function(input)
						if not closable then return end
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							if not Lib.CheckMouseInGui(elems.Main) then self:Hide() end
						end
					end)
					Lib.FastWait()
					closable = true
				end
				funcs.Hide = function(self) self.Gui.Parent = nil end
				funcs.ApplyTheme = function() end

				local mt = { __index = funcs }
				return {
					new = function()
						if not mouse then mouse = plr:GetMouse() end
						local o = setmetatable({
							Width = 200, MaxHeight = nil, Iconless = false, SearchEnabled = false,
							Updated = false, Items = {}, Registered = {}, GuiElems = {}, Theme = {},
						}, mt)
						o.Gui = createGui(o)
						return o
					end,
				}
			end)()

			-- CodeFrame
			Lib.CodeFrame = (function()
				local funcs = {}
				local tweenService = service.TweenService
				local keywords = {}
				for _, k in ipairs({ "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while" }) do keywords[k] = true end

				local function makeFrame(obj)
					local frame = createSimple("Frame", { BackgroundColor3 = Color3.fromRGB(36, 36, 36), BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0) })
					local lines = Instance.new("Frame", frame)
					lines.Name = "Lines"
					lines.BackgroundTransparency = 1
					lines.Size = UDim2.new(1, 0, 1, 0)
					lines.ClipsDescendants = true
					local nums = Instance.new("TextLabel", frame)
					nums.Name = "LineNumbers"
					nums.BackgroundTransparency = 1
					nums.Font = Enum.Font.Code
					nums.TextXAlignment = Enum.TextXAlignment.Right
					nums.TextYAlignment = Enum.TextYAlignment.Top
					nums.ClipsDescendants = true
					nums.RichText = true
					local cursor = Instance.new("Frame", frame)
					cursor.Name = "Cursor"
					cursor.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
					cursor.BorderSizePixel = 0
					local box = Instance.new("TextBox", frame)
					box.Name = "EditBox"
					box.MultiLine = true
					box.Visible = false
					obj.Frame = frame
					obj.Gui = frame
					obj.GuiElems = { LinesFrame = lines, LineNumbersLabel = nums, Cursor = cursor, EditBox = box }
				end

				funcs.GetText = function(self) return table.concat(self.Lines, "\n") end
				funcs.SetText = function(self, txt)
					local lines = {}
					for line in txt:gmatch("([^\n\r]*)[\n\r]?") do lines[#lines + 1] = line end
					self.Lines = lines
					self:Refresh()
				end
				funcs.Refresh = function(self)
					local frame = self.Frame.Lines
					local maxLines = math.ceil(math.max(0, frame.AbsoluteSize.Y) / self.FontSize)
					local maxCols = math.ceil(math.max(0, frame.AbsoluteSize.X) / math.ceil(self.FontSize / 2))
					local numStr = ""
					for row = 1, maxLines do
						local lf = self.LineFrames[row]
						if not lf then
							lf = Instance.new("Frame")
							lf.Name = "Line"
							lf.Position = UDim2.new(0, 0, 0, (row - 1) * self.FontSize)
							lf.Size = UDim2.new(1, 0, 0, self.FontSize)
							lf.BorderSizePixel = 0
							lf.BackgroundTransparency = 1
							local label = Instance.new("TextLabel", lf)
							label.Name = "Label"
							label.BackgroundTransparency = 1
							label.Font = Enum.Font.Code
							label.TextSize = self.FontSize
							label.Size = UDim2.new(1, 0, 0, self.FontSize)
							label.RichText = true
							label.TextXAlignment = Enum.TextXAlignment.Left
							label.TextColor3 = Color3.fromRGB(204, 204, 204)
							lf.Parent = frame
							self.LineFrames[row] = lf
						end
						local idx = self.ViewY + row
						local txt = self.Lines[idx] or ""
						lf.Label.Text = txt:gsub("<", "&lt;"):gsub(">", "&gt;")
						if self.Lines[idx] then numStr = numStr .. idx .. "\n" end
					end
					self.Frame.LineNumbers.Text = numStr
					self.Frame.LineNumbers.TextSize = self.FontSize
					self.Frame.LineNumbers.Size = UDim2.new(0, 30, 1, 0)
				end

				local mt = { __index = funcs }
				return {
					new = function()
						local o = setmetatable({ FontSize = 14, ViewY = 0, Lines = { "" }, LineFrames = {} }, mt)
						makeFrame(o)
						o:Refresh()
						o.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() o:Refresh() end)
						return o
					end,
				}
			end)()

			-- Checkbox
			Lib.Checkbox = (function()
				local funcs = {}
				local function initGui(self)
					local cb = create({
						{ 1, "ImageButton", { BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Checkbox", Size = UDim2.new(0, 16, 0, 16) } },
						{ 2, "Frame", { BackgroundColor3 = Color3.fromRGB(26, 26, 26), BorderSizePixel = 0, Name = "outline", Parent = { 1 }, Size = UDim2.new(0, 16, 0, 16) } },
						{ 3, "Frame", { BackgroundColor3 = Color3.fromRGB(36, 36, 36), BorderSizePixel = 0, Name = "filler", Parent = { 2 }, Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(0, 14, 0, 14) } },
						{ 4, "ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://6401617475", ImageColor3 = C_BLUE, Name = "check", Parent = { 3 }, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 12, 0, 12), Visible = false } },
						{ 5, "UICorner", { CornerRadius = UDim.new(0, 2), Parent = { 2 } } },
					})
					self.Gui = cb
					self.GuiElems = { Outline = cb.outline, Check = cb.outline.filler.check }
					cb.Activated:Connect(function()
						if not self.Disabled then self:SetState(not self.Toggled) self.OnInput:Fire() end
					end)
					self:Paint()
				end
				funcs.Paint = function(self)
					self.GuiElems.Outline.BackgroundColor3 = self.Disabled and Color3.fromRGB(64, 64, 64) or (self.Toggled and C_BLUE or Color3.fromRGB(26, 26, 26))
					self.GuiElems.Check.Visible = self.Toggled and true or false
				end
				funcs.SetState = function(self, v) self.Toggled = v self:Paint() end
				local mt = { __index = funcs }
				return {
					new = function()
						local o = setmetatable({ Toggled = false, Disabled = false, OnInput = Lib.Signal.new() }, mt)
						initGui(o)
						return o
					end,
				}
			end)()

			-- ViewportTextBox / Label / Frame / Button
			Lib.ViewportTextBox = (function()
				local funcs = {}
				funcs.GetText = function(self) return self.TextBox.Text end
				funcs.SetText = function(self, t) self.TextBox.Text = t end
				local mt = getGuiMT({ Gui = PH, TextBox = PH }, funcs)
				local function convert(tb)
					local o = setmetatable({ Gui = PH, TextBox = tb }, mt)
					tb.BackgroundTransparency = 1
					tb.TextXAlignment = Enum.TextXAlignment.Left
					o.Gui = tb
					return o
				end
				return { new = function()
					local tb = Instance.new("TextBox")
					tb.Size = UDim2.new(0, 100, 0, 20)
					tb.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
					tb.TextColor3 = Color3.new(1, 1, 1)
					tb.Font = Enum.Font.SourceSans
					tb.TextSize = 14
					return convert(tb)
				end, convert = convert }
			end)()

			Lib.Label = (function()
				local mt = getGuiMT({}, {})
				return { new = function()
					local l = Instance.new("TextLabel")
					l.BackgroundTransparency = 1
					l.TextXAlignment = Enum.TextXAlignment.Left
					l.TextColor3 = Color3.new(1, 1, 1)
					l.Size = UDim2.new(0, 100, 0, 20)
					l.Font = Enum.Font.SourceSans
					l.TextSize = 14
					return setmetatable({ Gui = l }, mt)
				end }
			end)()

			Lib.Frame = (function()
				local mt = getGuiMT({}, {})
				return { new = function()
					local f = Instance.new("Frame")
					f.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
					f.Size = UDim2.new(0, 50, 0, 50)
					return setmetatable({ Gui = f }, mt)
				end }
			end)()

			Lib.Button = (function()
				local props = { Gui = PH, Anim = PH, Disabled = false, OnClick = SIGNAL }
				local funcs = {}
				funcs.SetDisabled = function(self, d)
					self.Disabled = d
					if d then self.Anim:Disable() self.Gui.TextTransparency = 0.5
					else self.Anim:Enable() self.Gui.TextTransparency = 0 end
				end
				local mt = getGuiMT(props, funcs)
				return { new = function()
					local b = Instance.new("TextButton")
					b.AutoButtonColor = false
					b.TextColor3 = Color3.new(1, 1, 1)
					b.Size = UDim2.new(0, 100, 0, 20)
					b.Font = Enum.Font.SourceSans
					b.TextSize = 14
					b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
					local o = initObj(props, mt)
					o.Gui = b
					o.Anim = Lib.ButtonAnim(b, { Mode = 2, StartColor = Color3.fromRGB(60, 60, 60) })
					b.MouseButton1Click:Connect(function() if not o.Disabled then o.OnClick:Fire() end end)
					return o
				end }
			end)()

			Lib.DropDown = (function()
				local props = { Gui = PH, Context = PH, Selected = PH, CanBeEmpty = true, Options = {}, GuiElems = {}, OnSelect = SIGNAL }
				local funcs = {}
				funcs.Update = function(self)
					if #self.Options > 0 then
						if not self.Selected then
							if not self.CanBeEmpty then self.Selected = self.Options[1] self.GuiElems.Label.Text = self.Options[1]
							else self.GuiElems.Label.Text = "- Select -" end
						else self.GuiElems.Label.Text = self.Selected end
					else self.GuiElems.Label.Text = "- Select -" end
				end
				funcs.SetOptions = function(self, opts)
					self.Options = opts
					self.Context:Clear()
					for i = 1, #opts do
						self.Context:Add({ Name = opts[i], OnClick = function(v) self.Selected = v self.OnSelect:Fire(v) self:Update() end })
					end
					self:Update()
				end
				funcs.SetSelected = function(self, o) self.Selected = o self:Update() end
				local mt = getGuiMT(props, funcs)
				return { new = function()
					local f = Instance.new("TextButton")
					f.AutoButtonColor = false
					f.Text = ""
					f.Size = UDim2.new(0, 100, 0, 20)
					f.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
					local l = Lib.Label.new()
					l.Position = UDim2.new(0, 2, 0, 0)
					l.Size = UDim2.new(1, -22, 1, 0)
					l.Parent = f
					local o = initObj(props, mt)
					o.Gui = f
					o.Context = Lib.ContextMenu.new()
					o.Context.Iconless = true
					o.Context.MaxHeight = 200
					o.GuiElems = { Label = l }
					f.MouseButton1Down:Connect(function()
						o.Context.Width = f.AbsoluteSize.X
						o.Context:Show(f.AbsolutePosition.X, f.AbsolutePosition.Y + 20)
					end)
					o:Update()
					return o
				end }
			end)()

			Lib.ClickSystem = (function()
				local props = { LastItem = PH, OnDown = SIGNAL, OnRelease = SIGNAL, AllowedButtons = { 1 }, Combo = 0, MaxCombo = 2, ComboTime = 0.5, Items = {}, ItemCons = {}, ClickId = -1, LastButton = "" }
				local funcs = {}
				funcs.Trigger = function(self, item, button, x, y)
					if not table.find(self.AllowedButtons, button) then return end
					if self.LastButton ~= button or self.LastItem ~= item or self.Combo == self.MaxCombo or os.clock() - self.ClickId > self.ComboTime then
						self.Combo = 0; self.LastButton = button; self.LastItem = item
					end
					self.Combo += 1
					self.ClickId = os.clock()
					local rel
					rel = service.UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType["MouseButton" .. button] then
							rel:Disconnect()
							if Lib.CheckMouseInGui(item) and self.LastButton == button and self.LastItem == item then
								self.OnRelease:Fire(item, self.Combo, button)
							end
						end
					end)
					self.OnDown:Fire(item, self.Combo, button)
				end
				funcs.Add = function(self, item)
					if table.find(self.Items, item) then return end
					self.ItemCons[item] = {
						item.MouseButton1Down:Connect(function(x, y) self:Trigger(item, 1, x, y) end),
						item.MouseButton2Down:Connect(function(x, y) self:Trigger(item, 2, x, y) end),
					}
					self.Items[#self.Items + 1] = item
				end
				funcs.Remove = function(self, item)
					local i = table.find(self.Items, item)
					if not i then return end
					for _, c in ipairs(self.ItemCons[item]) do c:Disconnect() end
					self.ItemCons[item] = nil
					table.remove(self.Items, i)
				end
				local mt = { __index = funcs }
				return { new = function() return initObj(props, mt) end }
			end)()

			return Lib
		end

		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	--================== EXPLORER ==================
	EmbeddedModules.Explorer = function()
		local Main, Lib, Apps, Settings, API, RMD, env, service, plr, create, createSimple
		local function initDeps(d)
			Main, Lib, Apps, Settings = d.Main, d.Lib, d.Apps, d.Settings
			API, RMD, env, service, plr = d.API, d.RMD, d.env, d.service, d.plr
			create, createSimple = d.create, d.createSimple
		end
		local function initAfterMain() end

		local function main()
			local Explorer = {}
			local tree, listEntries, explorerOrders, searchResults = {}, {}, {}, {}
			local expanded, entryTemplate, treeFrame, toolBar
			local descendantAddedCon, descendantRemovingCon, itemChangedCon
			local ffa = game.FindFirstAncestorWhichIsA
			local getDescendants = game.GetDescendants
			local updateDebounce, refreshDebounce = false, false
			local nilNode = { Obj = Instance.new("Folder") }
			local scrollV, scrollH, clipboard
			local renameBox, renamingNode, searchFunc
			local sortingEnabled
			local nilMap, nilCons = {}, {}
			local DirtyParents = {}
			local addObject, removeObject, moveObject

			-- resolve de pai: obj.Parent é O(1); ffa só como fallback para nil-instances
			local function resolveNode(obj)
				local p = obj.Parent
				if p then return nodes[p] end
				return nodes[ffa(obj, "Instance")]
			end

			addObject = function(root)
				if nodes[root] then return end
				local isNil = false
				local par = resolveNode(root)

				if not par then
					if nilMap[root] then
						nilCons[root] = {
							root.ChildAdded:Connect(addObject),
							root.AncestryChanged:Connect(moveObject),
						}
						par = nilNode
						isNil = true
					else return end
				elseif par == nilNode then
					nilMap[root] = true
					nilCons[root] = {
						root.ChildAdded:Connect(addObject),
						root.AncestryChanged:Connect(moveObject),
					}
					isNil = true
				end

				local node = { Obj = root, Parent = par }
				nodes[root] = node
				par[#par + 1] = node
				par.Sorted = nil

				local insts = getDescendants(root)
				for i = 1, #insts do
					local obj = insts[i]
					if not nodes[obj] then
						local p = obj.Parent
						local pn = p and nodes[p] or nodes[ffa(obj, "Instance")]
						if pn then
							local nn = { Obj = obj, Parent = pn }
							nodes[obj] = nn
							pn[#pn + 1] = nn
							if isNil then
								nilMap[obj] = true
								nilCons[obj] = {
									obj.ChildAdded:Connect(addObject),
									obj.AncestryChanged:Connect(moveObject),
								}
							end
						end
					end
				end

				if not updateDebounce and Explorer.IsNodeVisible(par) then
					if expanded[par] then Explorer.PerformUpdate()
					elseif not refreshDebounce then Explorer.PerformRefresh() end
				end
			end

			removeObject = function(root)
				local node = nodes[root]
				if not node then return end
				if nilMap[node.Obj] then moveObject(node.Obj) return end
				local par = node.Parent
				if par then
					par.HasDel = true
					DirtyParents[par] = true
				end
				local function recur(t)
					for i = 1, #t do
						local n = t[i]
						if not n.Del then
							nodes[n.Obj] = nil
							if #n > 0 then recur(n) end
						end
					end
				end
				recur(node)
				node.Del = true
				nodes[root] = nil
				if par and not updateDebounce and Explorer.IsNodeVisible(par) then
					if expanded[par] then Explorer.PerformUpdate()
					elseif not refreshDebounce then Explorer.PerformRefresh() end
				end
			end

			moveObject = function(obj)
				local node = nodes[obj]
				if not node then return end
				local oldPar = node.Parent
				local newPar = resolveNode(obj)
				if oldPar == newPar then return end
				if not newPar then
					if nilMap[obj] then newPar = nilNode else return end
				elseif newPar == nilNode then
					nilMap[obj] = true
					nilCons[obj] = {
						obj.ChildAdded:Connect(addObject),
						obj.AncestryChanged:Connect(moveObject),
					}
				end
				if oldPar then
					local p = table.find(oldPar, node)
					if p then table.remove(oldPar, p) end
					oldPar.HasDel = true
					DirtyParents[oldPar] = true
				end
				node.Id = nil
				node.Parent = newPar
				newPar[#newPar + 1] = node
				newPar.Sorted = nil
				if not updateDebounce then
					if expanded[newPar] or (oldPar and expanded[oldPar]) then Explorer.PerformUpdate()
					elseif not refreshDebounce then Explorer.PerformRefresh() end
				end
			end

			Explorer.ViewWidth, Explorer.Index, Explorer.EntryIndent, Explorer.FreeWidth = 0, 0, 20, 32
			Explorer.GuiElems = {}
			Explorer.DirtyParents = DirtyParents

			Explorer.InitRenameBox = function()
				renameBox = create({ { 1, "TextBox", { BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0, ClearTextOnFocus = false, Font = 3, Name = "RenameBox", Position = UDim2.new(0, 26, 0, 2), Size = UDim2.new(0, 200, 0, 16), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = 0, Visible = false, ZIndex = 2 } } })
				renameBox.Parent = Explorer.Window.GuiElems.Content.List
				renameBox.FocusLost:Connect(function()
					if not renamingNode then return end
					pcall(function() renamingNode.Obj.Name = renameBox.Text end)
					renamingNode = nil
					Explorer.Refresh()
				end)
			end

			Explorer.SetRenamingNode = function(node)
				renamingNode = node
				renameBox.Text = tostring(node.Obj)
				renameBox:CaptureFocus()
				Explorer.Refresh()
			end

			Explorer.SetSortingEnabled = function(v) sortingEnabled = v Settings.Explorer.Sorting = v end

			Explorer.UpdateView = function()
				local maxNodes = math.ceil(treeFrame.AbsoluteSize.Y / 20)
				local maxX = treeFrame.AbsoluteSize.X
				local total = Explorer.ViewWidth + Explorer.FreeWidth
				scrollV.VisibleSpace = maxNodes
				scrollV.TotalSpace = #tree + 1
				scrollH.VisibleSpace = maxX
				scrollH.TotalSpace = total
				scrollV.Gui.Visible = #tree + 1 > maxNodes
				scrollH.Gui.Visible = total > maxX
				local old = treeFrame.Size
				treeFrame.Size = UDim2.new(1, (scrollV.Gui.Visible and -16 or 0), 1, (scrollH.Gui.Visible and -39 or -23))
				if old ~= treeFrame.Size then Explorer.UpdateView()
				else
					scrollV:Update()
					scrollH:Update()
					renameBox.Size = UDim2.new(0, maxX - 100, 0, 16)
					Explorer.Index = scrollV.Index
				end
			end

			Explorer.NodeSorter = function(a, b)
				if a.Del or b.Del then return false end
				local ac, bc = a.Class or a.Obj.ClassName, b.Class or b.Obj.ClassName
				a.Class, b.Class = ac, bc
				local ao = explorerOrders[ac] or 9999
				local bo = explorerOrders[bc] or 9999
				if ao ~= bo then return ao < bo end
				return tostring(a.Obj) < tostring(b.Obj)
			end

			Explorer.Update = function()
				table.clear(tree)
				local maxNameWidth, maxDepth, count = 0, 1, 1
				local useNameWidth = Settings.Explorer.UseNameWidth
				local isSearching = (expanded == Explorer.SearchExpanded)
				local textServ = service.TextService

				local function recur(root, depth)
					if depth > maxDepth then maxDepth = depth end
					depth += 1
					if sortingEnabled and not root.Sorted then
						table.sort(root, Explorer.NodeSorter)
						root.Sorted = true
					end
					for i = 1, #root do
						local n = root[i]
						if (not isSearching or searchResults[n]) and not n.Del then
							if useNameWidth then
								local w = n.NameWidth
								if not w then
									w = textServ:GetTextSize(tostring(n.Obj), 14, Enum.Font.SourceSans, Vector2.new(math.huge, 20)).X
									n.NameWidth = w
								end
								if w > maxNameWidth then maxNameWidth = w end
							end
							tree[count] = n
							count += 1
							if expanded[n] and #n > 0 then recur(n, depth) end
						end
					end
				end

				recur(nodes[game], 1)
				if env.getnilinstances and not (isSearching and not searchResults[nilNode]) then
					tree[count] = nilNode
					count += 1
					if expanded[nilNode] then recur(nilNode, 2) end
				end

				Explorer.MaxDepth = maxDepth
				Explorer.ViewWidth = useNameWidth and Explorer.EntryIndent * maxDepth + maxNameWidth + 26 or Explorer.EntryIndent * maxDepth + 226
				Explorer.UpdateView()
			end

			Explorer.NewListEntry = function(index)
				local e = entryTemplate:Clone()
				e.Position = UDim2.new(0, 0, 0, 20 * (index - 1))
				e.Indent.Expand.MouseButton1Down:Connect(function()
					local node = tree[index + Explorer.Index]
					if not node or #node == 0 then return end
					expanded[node] = not expanded[node]
					Explorer.Update()
					Explorer.Refresh()
				end)
				e.Parent = treeFrame
				return e
			end

			Explorer.Refresh = function()
				local maxNodes = math.max(math.ceil(treeFrame.AbsoluteSize.Y / 20), 0)
				local renameVisible = false
				for i = 1, maxNodes do
					local e = listEntries[i]
					if not e then e = Explorer.NewListEntry(i) listEntries[i] = e Explorer.ClickSystem:Add(e) end
					local node = tree[i + Explorer.Index]
					if node then
						local depth = Explorer.EntryIndent * Explorer.NodeDepth(node)
						e.Visible = true
						e.Position = UDim2.new(0, -scrollH.Index, 0, e.Position.Y.Offset)
						e.Size = UDim2.new(0, Explorer.ViewWidth, 0, 20)
						e.Indent.EntryName.Text = tostring(node.Obj)
						e.Indent.Position = UDim2.new(0, depth, 0, 0)
						e.Indent.Size = UDim2.new(1, -depth, 1, 0)
						Apps.Explorer.MiscIcons:DisplayExplorerIcons(e.Indent.Icon, node.Obj.ClassName)
						if Explorer.Selection.Map[node] then
							e.Indent.BackgroundColor3 = Settings.Theme.ListSelection
							e.Indent.BackgroundTransparency = 0
						else
							e.Indent.BackgroundTransparency = 1
						end
						if node == renamingNode then
							renameVisible = true
							renameBox.Position = UDim2.new(0, depth + 25 - scrollH.Index, 0, e.Position.Y.Offset + 2)
							renameBox.Visible = true
						end
						e.Indent.Expand.Visible = #node > 0 and expanded[node] ~= 0
						Apps.Explorer.MiscIcons:DisplayByKey(e.Indent.Expand.Icon, expanded[node] and "Collapse" or "Expand")
					else
						e.Visible = false
					end
				end
				if not renameVisible then renameBox.Visible = false end
				for i = maxNodes + 1, #listEntries do
					Explorer.ClickSystem:Remove(listEntries[i])
					listEntries[i]:Destroy()
					listEntries[i] = nil
				end
			end

			Explorer.PerformUpdate = function(instant)
				updateDebounce = true
				Lib.FastWait(not instant and 0.1)
				if not updateDebounce then return end
				updateDebounce = false
				if not Explorer.Window:IsVisible() then return end
				Explorer.Update()
				Explorer.Refresh()
			end

			Explorer.ForceUpdate = function(norefresh)
				updateDebounce = false
				Explorer.Update()
				if not norefresh then Explorer.Refresh() end
			end

			Explorer.PerformRefresh = function()
				refreshDebounce = true
				Lib.FastWait(0.1)
				refreshDebounce = false
				if updateDebounce or not Explorer.Window:IsVisible() then return end
				Explorer.Refresh()
			end

			Explorer.IsNodeVisible = function(node)
				if not node then return false end
				local c = node.Parent
				while c do
					if not expanded[c] then return false end
					c = c.Parent
				end
				return true
			end

			Explorer.NodeDepth = function(node)
				local d = 0
				if node == nilNode then return 1 end
				local c = node.Parent
				while c do
					if c == nilNode then d += 1 end
					c = c.Parent
					d += 1
				end
				return d
			end

			Explorer.SetupConnections = function()
				if descendantAddedCon then descendantAddedCon:Disconnect() end
				if descendantRemovingCon then descendantRemovingCon:Disconnect() end
				if itemChangedCon then itemChangedCon:Disconnect() end
				descendantAddedCon = game.DescendantAdded:Connect(function(o) pcall(addObject, o) end)
				descendantRemovingCon = game.DescendantRemoving:Connect(function(o) pcall(removeObject, o) end)
				itemChangedCon = game.ItemChanged:Connect(function(o, p)
					if p == "Parent" then
						local n = nodes[o]
						if n then moveObject(o) end
					elseif p == "Name" then
						local n = nodes[o]
						if n then n.NameWidth = nil end
					end
				end)
			end

			Explorer.ViewNode = function(node)
				if not node then return end
				Explorer.MakeNodeVisible(node)
				Explorer.ForceUpdate(true)
				for i, v in next, tree do
					if v == node then
						local rel = i - 1
						if Explorer.Index > rel then scrollV.Index = rel
						elseif Explorer.Index + scrollV.VisibleSpace - 1 <= rel then scrollV.Index = rel - scrollV.VisibleSpace + 2 end
					end
				end
				scrollV:Update()
				Explorer.Index = scrollV.Index
				Explorer.Refresh()
			end

			Explorer.MakeNodeVisible = function(node, expandRoot)
				if not node then return end
				if expandRoot then expanded[node] = true end
				local c = node.Parent
				while c do expanded[c] = true c = c.Parent end
				if not updateDebounce then coroutine.wrap(Explorer.PerformUpdate)(true) end
			end

			Explorer.GetInstancePath = function(obj)
				local path = ""
				local cur = obj
				while cur do
					if cur == game then path = "game" .. path break end
					local name = tostring(cur)
					local idx = name:match("^[%a_][%w_]*$") and ("." .. name) or ('["' .. Lib.FormatLuaString(name) .. '"]')
					local par = cur.Parent
					if par == game and API.Classes[cur.ClassName] and API.Classes[cur.ClassName].Tags.Service then
						idx = ':GetService("' .. cur.ClassName .. '")'
					end
					path = idx .. path
					cur = par
				end
				return path
			end

			Explorer.ShowRightClick = function(mousePos)
				local m = mousePos or Main.Mouse
				local ctx = Explorer.RightClickContext
				ctx:Clear()
				ctx:AddRegistered("CUT")
				ctx:AddRegistered("COPY")
				ctx:AddRegistered("PASTE", #clipboard == 0)
				ctx:AddRegistered("DUPLICATE")
				ctx:AddRegistered("DELETE")
				ctx:AddRegistered("RENAME", #Explorer.Selection.List ~= 1)
				ctx:QueueDivider()
				ctx:AddRegistered("TELEPORT_TO")
				ctx:AddRegistered("VIEW_SCRIPT")
				ctx:AddRegistered("COPY_PATH", not env.setclipboard)
				ctx:AddRegistered("INSERT_OBJECT")
				Explorer.LastRightClickX, Explorer.LastRightClickY = m.X, m.Y
				ctx:Show(m.X, m.Y)
			end

			Explorer.InitRightClick = function()
				local ctx = Lib.ContextMenu.new()
				local function sel() return Explorer.Selection.List end
				local function each(fn)
					for _, n in ipairs(sel()) do pcall(fn, n.Obj) end
				end

				ctx:Register("CUT", { Name = "Cortar", OnClick = function()
					local new = {}
					each(function(o) local ok, c = pcall(function() return o:Clone() end) if ok then new[#new + 1] = c end o:Destroy() end)
					clipboard = new
					Explorer.Selection:Clear()
				end })
				ctx:Register("COPY", { Name = "Copiar", OnClick = function()
					local new = {}
					each(function(o) local ok, c = pcall(function() return o:Clone() end) if ok then new[#new + 1] = c end end)
					clipboard = new
				end })
				ctx:Register("PASTE", { Name = "Colar", OnClick = function()
					for _, n in ipairs(sel()) do
						for _, c in ipairs(clipboard) do
							local cl = c:Clone()
							cl.Parent = n.Obj
						end
					end
				end })
				ctx:Register("DUPLICATE", { Name = "Duplicar", OnClick = function()
					for _, n in ipairs(sel()) do
						local ok, c = pcall(function() return n.Obj:Clone() end)
						if ok then c.Parent = n.Parent and n.Parent.Obj end
					end
				end })
				ctx:Register("DELETE", { Name = "Deletar", OnClick = function()
					each(function(o) o:Destroy() end)
					Explorer.Selection:Clear()
				end })
				ctx:Register("RENAME", { Name = "Renomear", OnClick = function()
					local l = sel()
					if l[1] then Explorer.SetRenamingNode(l[1]) end
				end })
				ctx:Register("TELEPORT_TO", { Name = "Teleportar", OnClick = function()
					local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if not hrp then return end
					for _, n in ipairs(sel()) do
						local o = n.Obj
						local target = o:IsA("BasePart") and o or (o:IsA("Model") and (o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart")))
						if target then hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0)) break end
					end
				end })
				ctx:Register("VIEW_SCRIPT", { Name = "Ver Script", OnClick = function()
					local l = sel()
					if l[1] then Apps.ScriptViewer.ViewScript(l[1].Obj) end
				end })
				ctx:Register("COPY_PATH", { Name = "Copiar Caminho", OnClick = function()
					local l = sel()
					if l[1] then env.setclipboard(Explorer.GetInstancePath(l[1].Obj)) end
				end })
				ctx:Register("INSERT_OBJECT", { Name = "Inserir Objeto", OnClick = function()
					local l = sel()
					if l[1] then
						local i = Instance.new("Folder")
						i.Name = "Novo"
						i.Parent = l[1].Obj
					end
				end })
				Explorer.RightClickContext = ctx
			end

			Explorer.InitEntryTemplate = function()
				entryTemplate = create({
					{ 1, "TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Entry", Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(0, 250, 0, 20), Text = "", TextSize = 14 } },
					{ 2, "Frame", { BackgroundColor3 = C_BLUE, BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Indent", Parent = { 1 }, Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -20, 1, 0) } },
					{ 3, "TextLabel", { BackgroundTransparency = 1, Font = 3, Name = "EntryName", Parent = { 2 }, Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -26, 1, 0), Text = "", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 14, TextXAlignment = 0 } },
					{ 4, "TextButton", { BackgroundTransparency = 1, ClipsDescendants = true, Font = 3, Name = "Expand", Parent = { 2 }, Position = UDim2.new(0, -20, 0, 0), Size = UDim2.new(0, 20, 0, 20), Text = "" } },
					{ 5, "ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://5642383285", ImageRectOffset = Vector2.new(144, 16), ImageRectSize = Vector2.new(16, 16), Name = "Icon", Parent = { 4 }, Position = UDim2.new(0, 2, 0, 2), ScaleType = 4, Size = UDim2.new(0, 16, 0, 16) } },
					{ 6, "ImageLabel", { BackgroundTransparency = 1, ImageRectOffset = Vector2.new(304, 0), ImageRectSize = Vector2.new(16, 16), Name = "Icon", Parent = { 2 }, Position = UDim2.new(0, 4, 0, 2), ScaleType = 4, Size = UDim2.new(0, 16, 0, 16) } },
				})

				local sys = Lib.ClickSystem.new()
				sys.AllowedButtons = { 1, 2 }
				sys.OnDown:Connect(function(item, combo, button)
					local ind = table.find(listEntries, item)
					if not ind then return end
					local node = tree[ind + Explorer.Index]
					if not node then return end
					if button == 1 then
						if combo == 2 and node.Obj:IsA("LuaSourceContainer") then Apps.ScriptViewer.ViewScript(node.Obj) end
						if not Lib.IsShiftDown() and not Lib.IsCtrlDown() then Explorer.Selection:Set(node) end
					elseif button == 2 then
						if not Explorer.Selection.Map[node] then Explorer.Selection:Set(node) end
					end
					Explorer.Refresh()
				end)
				sys.OnRelease:Connect(function(item, combo, button, position)
					local ind = table.find(listEntries, item)
					if not ind then return end
					local node = tree[ind + Explorer.Index]
					if not node then return end
					if button == 1 then
						Lib.FastWait(sys.ComboTime)
						if combo == 1 and Explorer.Selection.Map[node] then Explorer.SetRenamingNode(node) end
					elseif button == 2 then
						Explorer.ShowRightClick(position)
					end
				end)
				Explorer.ClickSystem = sys
			end

			-- coletor otimizado: só pais marcados como sujos
			Explorer.InitDelCleaner = function()
				coroutine.wrap(function()
					while true do
						if next(DirtyParents) then
							for node in next, DirtyParents do
								DirtyParents[node] = nil
								if node.HasDel then
									local i = 1
									while i <= #node do
										if node[i].Del then table.remove(node, i) else i += 1 end
									end
									node.HasDel = false
								end
							end
							if not refreshDebounce then Explorer.PerformRefresh() end
						end
						Lib.FastWait(0.35)
					end
				end)()
			end

			Explorer.Init = function()
				Explorer.ClassIcons = Lib.IconMap.newLinear("rbxasset://textures/ClassImages.PNG", 16, 16)
				Explorer.MiscIcons = Main.MiscIcons
				clipboard = {}
				Explorer.Selection = Lib.Set.new()
				Explorer.Selection.Changed:Connect(function() end)
				Explorer.InitRightClick()
				Explorer.SetSortingEnabled(Settings.Explorer.Sorting)
				Explorer.Expanded = setmetatable({}, { __mode = "k" })
				Explorer.SearchExpanded = setmetatable({}, { __mode = "k" })
				expanded = Explorer.Expanded
				nilNode.Obj.Name = "Nil Instances"

				local items = create({
					{ 1, "Folder", { Name = "ExplorerItems" } },
					{ 2, "Frame", { BackgroundColor3 = Color3.fromRGB(52, 52, 52), BorderSizePixel = 0, Name = "ToolBar", Parent = { 1 }, Size = UDim2.new(1, 0, 0, 22) } },
					{ 3, "TextBox", { BackgroundTransparency = 1, ClearTextOnFocus = false, Font = 3, Name = "SearchBox", Parent = { 2 }, PlaceholderColor3 = Color3.fromRGB(100, 100, 100), PlaceholderText = "Pesquisar", Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(1, -8, 0, 18), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = 0 } },
					{ 4, "Frame", { BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0, Name = "List", Parent = { 1 }, Position = UDim2.new(0, 0, 0, 23), Size = UDim2.new(1, 0, 1, -23), ClipsDescendants = true } },
				})
				toolBar, treeFrame = items.ToolBar, items.List

				scrollV = Lib.ScrollBar.new()
				scrollV.WheelIncrement = 3
				scrollV.Gui.Position = UDim2.new(1, -16, 0, 23)
				scrollV:SetScrollFrame(treeFrame)
				scrollV.Scrolled:Connect(function() Explorer.Index = scrollV.Index Explorer.Refresh() end)
				scrollH = Lib.ScrollBar.new(true)
				scrollH.Increment = 5
				scrollH.WheelIncrement = 20
				scrollH.Gui.Position = UDim2.new(0, 0, 1, -16)
				scrollH.Scrolled:Connect(function() Explorer.Refresh() end)

				local window = Lib.Window.new()
				Explorer.Window = window
				window:SetTitle("Explorer")
				window.GuiElems.Line.Position = UDim2.new(0, 0, 0, 22)
				Explorer.InitEntryTemplate()
				toolBar.Parent = window.GuiElems.Content
				treeFrame.Parent = window.GuiElems.Content
				scrollV.Gui.Parent = window.GuiElems.Content
				scrollH.Gui.Parent = window.GuiElems.Content
				Explorer.InitRenameBox()
				Explorer.InitDelCleaner()

				toolBar.SearchBox.FocusLost:Connect(function() end)
				window.OnActivate:Connect(function() Explorer.UpdateView() Explorer.ForceUpdate() end)

				nodes[game] = { Obj = game }
				expanded[nodes[game]] = true
				if env.getnilinstances then nodes[nilNode.Obj] = nilNode end
				Explorer.SetupConnections()

				local insts = getDescendants(game)
				for i = 1, #insts do
					local obj = insts[i]
					local p = obj.Parent
					local par = p and nodes[p]
					if par then
						local nn = { Obj = obj, Parent = par }
						nodes[obj] = nn
						par[#par + 1] = nn
					end
				end
			end

			return Explorer
		end

		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	--================== PROPERTIES ==================
	EmbeddedModules.Properties = function()
		local Main, Lib, Apps, Settings, API, RMD, env, service, plr, create, createSimple
		local function initDeps(d)
			Main, Lib, Apps, Settings = d.Main, d.Lib, d.Apps, d.Settings
			API, RMD, env, service, plr = d.API, d.RMD, d.env, d.service, d.plr
			create, createSimple = d.create, d.createSimple
		end
		local function initAfterMain() end

		local function main()
			local Properties = {}
			local window, propsFrame, scrollV, scrollH
			local props, viewList, expanded, propEntries, autoUpdateObjs = {}, {}, {}, {}, {}
			local checkboxes = {}
			local getPropChangedSignal = game.GetPropertyChangedSignal
			local isa = game.IsA

			Properties.GuiElems = {}
			Properties.Index = 0
			Properties.ViewWidth = 0
			Properties.EntryIndent = 16

			Properties.AddAttributeProp = { Category = "Attributes", Class = "", Name = "", SpecialRow = "AddAttribute", Tags = {} }

			Properties.RoundableTypes = { float = true, double = true, Color3 = true, UDim = true, UDim2 = true, Vector2 = true, Vector3 = true, NumberRange = true, Rect = true, NumberSequence = true, ColorSequence = true, Ray = true, CFrame = true }

			Properties.DefaultPropValue = {
				string = "", bool = false, double = 0, UDim = UDim.new(0, 0), UDim2 = UDim2.new(0, 0, 0, 0),
				BrickColor = BrickColor.new("Medium stone grey"), Color3 = Color3.new(1, 1, 1),
				Vector2 = Vector2.new(0, 0), Vector3 = Vector3.new(0, 0, 0),
			}

			Properties.StringToValue = function(prop, str)
				local tn = prop.ValueType.Name
				if tn == "string" or tn == "Content" then return str end
				if tn == "bool" then return str == "true" end
				if tn == "int" or tn == "int64" or tn == "float" or tn == "double" then return tonumber(str) end
				if tn == "Vector3" then
					local a = str:split(",")
					if #a >= 3 then return Vector3.new(tonumber(a[1]) or 0, tonumber(a[2]) or 0, tonumber(a[3]) or 0) end
				elseif tn == "Color3" then
					local a = str:gsub("[{}]", ""):split(",")
					if #a >= 3 then return Color3.fromRGB(tonumber(a[1]) or 0, tonumber(a[2]) or 0, tonumber(a[3]) or 0) end
				elseif tn == "UDim2" then
					local a = str:gsub("[{}]", ""):split(",")
					if #a >= 4 then return UDim2.new(tonumber(a[1]) or 0, tonumber(a[2]) or 0, tonumber(a[3]) or 0, tonumber(a[4]) or 0) end
				elseif tn == "CFrame" then
					local a = str:split(",")
					if #a >= 3 then
						local ok, r = pcall(CFrame.new, tonumber(a[1]) or 0, tonumber(a[2]) or 0, tonumber(a[3]) or 0)
						if ok then return r end
					end
				elseif tn == "NumberRange" then
					local a = str:split(",")
					if a[1] then return NumberRange.new(tonumber(a[1]) or 0, tonumber(a[2]) or tonumber(a[1]) or 0) end
				end
				return nil
			end

			Properties.ValueToString = function(prop, v)
				if prop.ValueType.Name == "Color3" then return Lib.ColorToBytes(v) end
				if prop.ValueType.Name == "NumberRange" then return v.Min .. ", " .. v.Max end
				return tostring(v)
			end

			Properties.GetIndexableProps = function(obj, classData)
				local res, c = {}, 1
				for i = 1, #classData.Properties do
					local p = classData.Properties[i]
					if pcall(function() return obj[p.Name] end) then res[c] = p c += 1 end
				end
				return res
			end

			Properties.ComputeConflicts = function(p)
				local maxC = Settings.Properties.MaxConflictCheck
				local sList = Apps.Explorer.Selection.List
				local t_clear = table.clear
				local conflictMap = {}
				local list = p and { p } or props
				if p then
					autoUpdateObjs[p.Class .. "." .. p.Name] = nil
				else t_clear(autoUpdateObjs) end
				for i = 1, #list do
					local prop = list[i]
					local gName = prop.Class .. "." .. prop.Name
					local firstVal, firstObj, found = nil, nil, false
					t_clear(conflictMap)
					for c = 1, math.min(#sList, maxC) do
						local obj = sList[c].Obj
						if isa(obj, prop.Class) then
							local ok, v = pcall(function() return obj[prop.Name] end)
							if ok then
								if not found then firstVal, firstObj, found = v, obj, true
								elseif v ~= firstVal then conflictMap[1] = true break end
							end
						end
					end
					if not conflictMap[1] then autoUpdateObjs[gName] = firstObj end
				end
				if p then Properties.Refresh() end
			end

			Properties.ShowExplorerProps = function()
				local sList = Apps.Explorer.Selection.List
				local found, c = {}, 1
				table.clear(props)
				for i = 1, #sList do
					local obj = sList[i].Obj
					local cls = obj.ClassName
					local ac = API.Classes[cls]
					while ac do
						if not found[ac.Name] then
							found[ac.Name] = true
							for _, pr in ipairs(ac.Properties) do
								if not pr.Tags.Hidden or Settings.Properties.ShowHidden then props[c] = pr c += 1 end
							end
						end
						ac = ac.Superclass
					end
				end
				table.sort(props, function(a, b)
					if a.Category ~= b.Category then
						return (API.CategoryOrder[a.Category] or 9999) < (API.CategoryOrder[b.Category] or 9999)
					end
					return a.Name < b.Name
				end)
				Properties.ComputeConflicts()
				if #props > 0 then props[#props + 1] = Properties.AddAttributeProp end
				Properties.Update()
				Properties.Refresh()
			end

			Properties.UpdateView = function()
				local maxE = math.ceil(propsFrame.AbsoluteSize.Y / 23)
				scrollV.VisibleSpace = maxE
				scrollV.TotalSpace = #viewList + 1
				scrollV.Gui.Visible = #viewList + 1 > maxE
				propsFrame.Size = UDim2.new(1, (scrollV.Gui.Visible and -16 or 0), 1, -23)
				scrollV:Update()
				Properties.Index = scrollV.Index
			end

			Properties.Update = function()
				table.clear(viewList)
				local c, lastCat = 1, nil
				for i = 1, #props do
					local p = props[i]
					if p.Category ~= lastCat then
						viewList[c] = { CategoryName = p.Category }
						c += 1
						lastCat = p.Category
					end
					viewList[c] = p
					c += 1
				end
				Properties.ViewWidth = 180
				Properties.UpdateView()
			end

			Properties.NewPropEntry = function(index)
				local e = Properties.EntryTemplate:Clone()
				e.Position = UDim2.new(0, 0, 0, 23 * (index - 1))
				local cb = Lib.Checkbox.new()
				cb.Gui.Position = UDim2.new(0, 3, 0, 3)
				cb.Gui.Parent = e.ValueFrame
				cb.OnInput:Connect(function()
					local p = viewList[index + Properties.Index]
					if p and not p.SpecialRow then Properties.SetProp(p, cb.Toggled) end
				end)
				checkboxes[index] = cb
				e.ValueFrame.ValueBox.MouseButton1Down:Connect(function()
					local p = viewList[index + Properties.Index]
					if not p or p.SpecialRow then return end
					Properties.SetInputProp(p, index)
				end)
				e.Parent = propsFrame
				return { Gui = e, GuiElems = { NameFrame = e.NameFrame, ValueFrame = e.ValueFrame, PropName = e.NameFrame.PropName, ValueBox = e.ValueFrame.ValueBox, Checkbox = cb } }
			end

			Properties.Refresh = function()
				local maxE = math.max(math.ceil(propsFrame.AbsoluteSize.Y / 23), 0)
				for i = 1, maxE do
					local ed = propEntries[i]
					if not ed then ed = Properties.NewPropEntry(i) propEntries[i] = ed end
					local e = ed.Gui
					local p = viewList[i + Properties.Index]
					if p then
						e.Visible = true
						if p.CategoryName then
							e.NameFrame.PropName.Text = p.CategoryName
							e.ValueFrame.Visible = false
							e.NameFrame.Visible = true
						else
							e.NameFrame.PropName.Text = p.Name
							e.ValueFrame.Visible = true
							e.NameFrame.Visible = true
							local v = autoUpdateObjs[p.Class .. "." .. p.Name]
							local val = v and pcall(function() return v[p.Name] end) and v[p.Name]
							if p.ValueType.Name == "bool" then
								ed.GuiElems.Checkbox.Gui.Visible = true
								ed.GuiElems.ValueBox.Visible = false
								ed.GuiElems.Checkbox:SetState(val and true or false)
							else
								ed.GuiElems.Checkbox.Gui.Visible = false
								ed.GuiElems.ValueBox.Visible = true
								ed.GuiElems.ValueBox.Text = val ~= nil and Properties.ValueToString(p, val) or ""
							end
						end
					else e.Visible = false end
				end
				for i = maxE + 1, #propEntries do
					propEntries[i].Gui:Destroy()
					propEntries[i] = nil
					checkboxes[i] = nil
				end
			end

			Properties.SetProp = function(prop, val)
				for _, n in ipairs(Apps.Explorer.Selection.List) do
					local obj = n.Obj
					if isa(obj, prop.Class) then
						pcall(function() obj[prop.Name] = val end)
					end
				end
				Properties.ComputeConflicts(prop)
			end

			Properties.InitInputBox = function()
				local box = create({ { 1, "TextBox", { BackgroundColor3 = Color3.fromRGB(38, 38, 38), BorderSizePixel = 0, ClearTextOnFocus = false, Font = 3, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 0, 22), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Visible = false, ZIndex = 5 } } })
				box.Parent = window.GuiElems.Content
				Properties.InputBox = box
				box.FocusLost:Connect(function()
					local p = Properties.InputProp
					if not p then return end
					Properties.InputProp = nil
					local v = Properties.StringToValue(p, box.Text)
					if v ~= nil then Properties.SetProp(p, v) else Properties.Refresh() end
					box.Visible = false
				end)
			end

			Properties.SetInputProp = function(prop, index)
				if prop.Tags.ReadOnly then return end
				Properties.InputProp = prop
				local box = Properties.InputBox
				box.Text = ""
				box.Position = UDim2.new(0.5, 0, 0, 23 * (index - 1))
				box.Visible = true
				box:CaptureFocus()
			end

			Properties.InitEntryTemplate = function()
				Properties.EntryTemplate = create({
					{ 1, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0, Font = 3, Name = "Entry", Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(0, 250, 0, 22), Text = "", TextSize = 14 } },
					{ 2, "Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Name = "NameFrame", Parent = { 1 }, Size = UDim2.new(0.5, -20, 1, 0) } },
					{ 3, "TextLabel", { BackgroundTransparency = 1, Font = 3, Name = "PropName", Parent = { 2 }, Position = UDim2.new(0, 2, 0, 0), Size = UDim2.new(1, -2, 1, 0), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextTruncate = 1, TextXAlignment = 0 } },
					{ 4, "Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Name = "ValueFrame", Parent = { 1 }, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0) } },
					{ 5, "TextButton", { BackgroundTransparency = 1, Font = 3, Name = "ValueBox", Parent = { 4 }, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -8, 1, 0), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextTruncate = 1, TextXAlignment = 0 } },
				})
			end

			Properties.Init = function()
				local items = create({
					{ 1, "Frame", { BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0, Name = "List", Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0), ClipsDescendants = true } },
				})
				window = Lib.Window.new()
				Properties.Window = window
				window:SetTitle("Propriedades")
				propsFrame = items.List
				scrollV = Lib.ScrollBar.new()
				scrollV.WheelIncrement = 3
				scrollV.Gui.Position = UDim2.new(1, -16, 0, 0)
				scrollV:SetScrollFrame(propsFrame)
				scrollV.Scrolled:Connect(function() Properties.Index = scrollV.Index Properties.Refresh() end)
				scrollH = Lib.ScrollBar.new(true)
				propsFrame.Parent = window.GuiElems.Content
				scrollV.Gui.Parent = window.GuiElems.Content
				scrollH.Gui.Parent = window.GuiElems.Content
				Properties.InitEntryTemplate()
				Properties.InitInputBox()
				window.OnActivate:Connect(function() Properties.Update() Properties.Refresh() end)
			end

			return Properties
		end

		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	--================== SCRIPT VIEWER ==================
	EmbeddedModules.ScriptViewer = function()
		local Main, Lib, Apps, Settings, API, RMD, env, service, plr, create, createSimple
		local function initDeps(d)
			Main, Lib, Apps, Settings = d.Main, d.Lib, d.Apps, d.Settings
			API, RMD, env, service, plr = d.API, d.RMD, d.env, d.service, d.plr
			create, createSimple = d.create, d.createSimple
		end
		local function initAfterMain() end

		local function main()
			local SV = {}
			local window, codeFrame

			SV.ViewScript = function(scr)
				local ok, src = pcall(env.decompile, scr)
				if not ok or not src then src = "-- Dex: falha ao decompilar " .. scr.ClassName end
				codeFrame:SetText((src:gsub("\0", "\\0")))
				window:Show()
			end

			SV.Init = function()
				window = Lib.Window.new()
				window:SetTitle("Script Viewer")
				window:Resize(520, 420)
				SV.Window = window
				codeFrame = Lib.CodeFrame.new()
				codeFrame.Frame.Parent = window.GuiElems.Content
				local copy = Instance.new("TextButton", window.GuiElems.Content)
				copy.BackgroundTransparency = 1
				copy.Size = UDim2.new(1, 0, 0, 20)
				copy.Text = "Copiar para o clipboard"
				copy.TextColor3 = Color3.new(1, 1, 1)
				copy.MouseButton1Click:Connect(function() if env.setclipboard then env.setclipboard(codeFrame:GetText()) end end)
			end

			return SV
		end

		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	--================== CONSOLE ==================
	EmbeddedModules.Console = function()
		local Main, Lib, Apps, Settings, API, RMD, env, service, plr, create, createSimple
		local function initDeps(d)
			Main, Lib, Apps, Settings = d.Main, d.Lib, d.Apps, d.Settings
			API, RMD, env, service, plr = d.API, d.RMD, d.env, d.service, d.plr
			create, createSimple = d.create, d.createSimple
		end
		local function initAfterMain() end

		local function main()
			local Console = {}
			local window, frame, output, input, scrollbar

			Console.Init = function()
				window = Lib.Window.new()
				window:SetTitle("Console")
				window:Resize(500, 380)
				Console.Window = window

				frame = Instance.new("Frame", window.GuiElems.Content)
				frame.Size = UDim2.new(1, 0, 1, 0)
				frame.BackgroundColor3 = Color3.fromRGB(36, 36, 36)

				output = Instance.new("ScrollingFrame", frame)
				output.Size = UDim2.new(1, -20, 1, -30)
				output.Position = UDim2.new(0, 4, 0, 4)
				output.BackgroundTransparency = 1
				output.BorderSizePixel = 0
				output.CanvasSize = UDim2.new(0, 0, 0, 0)
				output.AutomaticCanvasSize = Enum.AutomaticSize.Y
				output.ScrollBarThickness = 6
				local lay = Instance.new("UIListLayout", output)
				lay.SortOrder = Enum.SortOrder.LayoutOrder

				input = Instance.new("TextBox", frame)
				input.Size = UDim2.new(1, -8, 0, 22)
				input.Position = UDim2.new(0, 4, 1, -26)
				input.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
				input.TextColor3 = Color3.new(1, 1, 1)
				input.PlaceholderText = "executar comando"
				input.Font = Enum.Font.Code
				input.TextSize = 13
				input.ClearTextOnFocus = false
				input.TextXAlignment = Enum.TextXAlignment.Left

				local function add(text, color)
					local l = Instance.new("TextLabel", output)
					l.Size = UDim2.new(1, 0, 0, 0)
					l.AutomaticSize = Enum.AutomaticSize.Y
					l.BackgroundTransparency = 1
					l.TextWrapped = true
					l.TextXAlignment = Enum.TextXAlignment.Left
					l.Font = Enum.Font.Code
					l.TextSize = 13
					l.TextColor3 = color
					l.Text = os.date("%H:%M:%S  ") .. text
					output.CanvasPosition = Vector2.new(0, 1e9)
				end

				game:GetService("LogService").MessageOut:Connect(function(msg, t)
					if t == Enum.MessageType.MessageError then add(msg, Color3.fromRGB(255, 90, 90))
					elseif t == Enum.MessageType.MessageWarning then add(msg, Color3.fromRGB(255, 170, 80))
					else add(msg, Color3.fromRGB(200, 200, 200)) end
				end)

				input.FocusLost:Connect(function(enter)
					if enter and input.Text ~= "" then
						add("> " .. input.Text, Color3.fromRGB(120, 190, 255))
						local ok, err = pcall(function() return loadstring(input.Text)() end)
						if not ok then add(tostring(err), Color3.fromRGB(255, 90, 90)) end
						input.Text = ""
					end
				end)
			end

			return Console
		end

		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	--================== SAVE INSTANCE ==================
	EmbeddedModules.SaveInstance = function()
		local Main, Lib, Apps, Settings, API, RMD, env, service, plr, create, createSimple
		local function initDeps(d)
			Main, Lib, Apps, Settings = d.Main, d.Lib, d.Apps, d.Settings
			API, RMD, env, service, plr = d.API, d.RMD, d.env, d.service, d.plr
			create, createSimple = d.create, d.createSimple
		end
		local function initAfterMain() end

		local function main()
			local SI = {}
			local window, status

			SI.Init = function()
				window = Lib.Window.new()
				window:SetTitle("Save Instance")
				window:Resize(320, 160)
				SI.Window = window

				status = Lib.Label.new()
				status.Parent = window.GuiElems.Content
				status.Position = UDim2.new(0, 10, 0, 10)
				status.Size = UDim2.new(1, -20, 0, 20)
				status.Text = "Pronto."

				local btn = Lib.Button.new()
				btn.Parent = window.GuiElems.Content
				btn.Position = UDim2.new(0, 10, 1, -35)
				btn.Size = UDim2.new(1, -20, 0, 24)
				btn.Text = "Salvar"
				btn.OnClick:Connect(function()
					if not env.saveinstance then status.Text = "saveinstance indisponível." return end
					status.Text = "Salvando..."
					task.spawn(function()
						local name = ("Place_%d_%s"):format(game.PlaceId, os.date("%d-%m-%Y_%H-%M-%S"))
						local ok, err = pcall(env.saveinstance, game, env.parsefile(name), {
							Decompile = true, DecompileTimeout = 10, MaxThreads = 3,
							RemovePlayerCharacters = true, IgnoreDefaultProps = true,
						})
						status.Text = ok and "Salvo com sucesso." or ("Erro: " .. tostring(err))
					end)
				end)
			end

			return SI
		end

		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	--================== MAIN ==================
	local Main = {}
	local Settings = {}
	local Apps = {}
	local env = {}
	local API, RMD
	local Lib, Explorer, Properties, ScriptViewer, Console, SaveInstance

	local plr = service.Players.LocalPlayer or service.Players.PlayerAdded:Wait()

	local function create(data)
		local insts = {}
		for _, v in pairs(data) do insts[v[1]] = Instance.new(v[2]) end
		for _, v in pairs(data) do
			for prop, val in pairs(v[3]) do
				if type(val) == "table" then insts[v[1]][prop] = insts[val[1]]
				else insts[v[1]][prop] = val end
			end
		end
		return insts[1]
	end
	local function createSimple(class, props)
		local i = Instance.new(class)
		for k, v in next, props do i[k] = v end
		return i
	end

	Main.ModuleList = { "Lib", "Explorer", "Properties", "ScriptViewer", "Console", "SaveInstance" }
	Main.Elevated = false
	Main.Mouse = plr:GetMouse()
	Main.Apps = Apps
	Main.DisplayOrders = { SideWindow = 8, Window = 10, Menu = 100000, Core = 101000 }

	Main.GetInitDeps = function()
		return {
			Main = Main, Lib = Lib, Apps = Apps, Settings = Settings,
			API = API, RMD = RMD, env = env, service = service, plr = plr,
			create = create, createSimple = createSimple,
		}
	end

	Main.Error = function(str) error(str, 0) end

	Main.LoadModule = function(name)
		local control = EmbeddedModules[name]()
		Main.AppControls[name] = control
		control.InitDeps(Main.GetInitDeps())
		Apps[name] = control.Main()
		return Apps[name]
	end

	Main.InitEnv = function()
		local mt = {
			__newindex = function(self, name, func)
				if func then rawset(self, name, func) end
			end,
		}
		setmetatable(env, mt)

		env.readfile = missing("function", readfile)
		env.writefile = missing("function", writefile)
		env.makefolder = missing("function", makefolder)
		env.loadfile = missing("function", loadfile)
		env.parsefile = function(n) return tostring(n):gsub("[*\\?:<>|]+", ""):sub(1, 175) end

		env.getgc = missing("function", getgc or get_gc_objects)
		env.getscriptbytecode = missing("function", getscriptbytecode)
		env.getnilinstances = missing("function", getnilinstances or get_nil_instances)
		env.protectgui = missing("function", protect_gui or (syn and syn.protect_gui))
		env.gethui = missing("function", gethui or get_hidden_gui)
		env.setclipboard = missing("function", setclipboard or toclipboard or set_clipboard)
		env.request = missing("function", request or http_request or (syn and syn.request))

		env.saveinstance = missing("function", saveinstance) or (function()
			local ok, res = pcall(function()
				return loadstring(oldgame:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau"))()
			end)
			return ok and res or nil
		end)()

		env.decompile = missing("function", decompile) or (function()
			if not env.getscriptbytecode then return nil end
			local ok = pcall(function()
				loadstring(oldgame:HttpGet("https://raw.githubusercontent.com/infyiff/backup/refs/heads/main/konstant.lua"))()
			end)
			return ok and decompile or nil
		end)()

		env.isViableDecompileScript = function(obj)
			if obj:IsA("ModuleScript") then return true end
			if obj:IsA("LocalScript") then return true end
			if obj:IsA("Script") and obj.RunContext == Enum.RunContext.Client then return true end
			return false
		end

		env.executor = (function()
			local f = identifyexecutor or getexecutorname
			if not f then return "Executor" end
			local ok, n = pcall(f)
			return ok and tostring(n) or "Executor"
		end)()

		Main.GuiHolder = Main.Elevated and service.CoreGui or plr:FindFirstChildWhichIsA("PlayerGui")
		setmetatable(env, nil)
	end

	Main.ResetSettings = function()
		Settings.Explorer = { Sorting = true, UseNameWidth = true }
		Settings.Properties = { ShowHidden = false, MaxConflictCheck = 25 }
		Settings.Theme = { ListSelection = C_BLUE, ButtonHover = Color3.fromRGB(60, 60, 60) }
	end

	Main.FetchAPI = function()
		local raw
		if Main.Elevated then
			local cached = Lib.ReadFile("dex/rbx_api.dat")
			if cached and cached ~= "" then raw = cached end
		end
		if not raw then
			local ok, r = pcall(function()
				return oldgame:HttpGet("http://setup.roblox.com/" .. Main.RobloxVersion .. "-API-Dump.json")
			end)
			if ok and r and #r > 100 then raw = r end
		end
		if not raw then
			local ok, r = pcall(function()
				return oldgame:HttpGet("https://raw.githubusercontent.com/infyiff/backup/refs/heads/main/rbx_api.dat")
			end)
			if ok then raw = r end
		end
		if not raw then error("Falha ao obter API dump") end

		local api = service.HttpService:JSONDecode(raw)
		local classes, enums, catOrder, seen = {}, {}, {}, {}
		for _, class in pairs(api.Classes) do
			local nc = { Name = class.Name, Superclass = class.Superclass, Properties = {}, Tags = {} }
			if class.Tags then for _, t in pairs(class.Tags) do nc.Tags[t] = true end end
			for _, m in pairs(class.Members) do
				if m.MemberType == "Property" then
					local cat = (m.Category or "Other"):match("^%s*(.-)%s*$")
					if not seen[cat] then catOrder[#catOrder + 1] = cat seen[cat] = true end
					nc.Properties[#nc.Properties + 1] = {
						Name = m.Name, Class = class.Name, Category = cat,
						ValueType = m.ValueType, Tags = (function()
							local t = {}
							if m.Tags then for _, x in pairs(m.Tags) do t[x] = true end end
							return t
						end)(),
					}
				end
			end
			classes[class.Name] = nc
		end
		for _, c in pairs(classes) do c.Superclass = classes[c.Superclass] end
		for _, e in pairs(api.Enums) do enums[e.Name] = e end
		local order = {}
		for i, v in ipairs(catOrder) do order[v] = i end
		order.Attributes = #catOrder + 1
		return { Classes = classes, Enums = enums, CategoryOrder = order }
	end

	Main.FetchRMD = function()
		local raw
		if Main.Elevated then
			local cached = Lib.ReadFile("dex/rbx_rmd.dat")
			if cached and cached ~= "" then raw = cached end
		end
		if not raw then
			local ok, r = pcall(function()
				return oldgame:HttpGet("https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/ReflectionMetadata.xml")
			end)
			if ok then raw = r end
		end
		if not raw then return { Classes = {}, Enums = {}, PropertyOrders = {} } end

		local ok, parsed = pcall(function() return Lib.ParseXML(raw) end)
		if not ok or not parsed then return { Classes = {}, Enums = {}, PropertyOrders = {} } end

		local classes = {}
		local classList = parsed.children[1] and parsed.children[1].children and parsed.children[1].children[1]
		if classList then
			for _, c in ipairs(classList.children or {}) do
				local name, data
				for _, ch in ipairs(c.children or {}) do
					if ch.tag == "Properties" then
						data = {}
						for _, p in ipairs(ch.children) do
							if p.attrs and p.children[1] then data[p.attrs.name] = p.children[1].text end
						end
						name = data.Name
					end
				end
				if name then classes[name] = data end
			end
		end
		return { Classes = classes, Enums = {}, PropertyOrders = {} }
	end

	Main.SetupFilesystem = function()
		if not env.writefile or not env.makefolder then return end
		pcall(env.makefolder, "dex")
	end

	Main.ShowGui = function(gui)
		if env.gethui then gui.Parent = env.gethui()
		elseif env.protectgui then env.protectgui(gui) gui.Parent = Main.GuiHolder
		else gui.Parent = Main.GuiHolder end
	end

	Main.Init = function()
		Main.Elevated = pcall(function() return service.CoreGui:GetFullName() end)
		Main.InitEnv()
		Main.ResetSettings()
		Main.SetupFilesystem()

		local function version()
			local ok, v = pcall(function() return oldgame:HttpGet("http://setup.roblox.com/versionQTStudio") end)
			if ok and v and #v > 0 then return v end
			local ok2, v2 = pcall(function()
				return oldgame:HttpGet("https://raw.githubusercontent.com/infyiff/backup/refs/heads/main/deps_version.dat")
			end)
			return ok2 and v2:gsub("%s+", "") or "version-0"
		end
		Main.RobloxVersion = version()

		Main.MiscIcons = nil
		Lib = Main.LoadModule("Lib")
		Main.MiscIcons = Lib.IconMap.new("http://www.roblox.com/asset/?id=6511490623", 256, 256, 16, 16)
		Main.MiscIcons:SetDict({
			Copy = 3, Paste = 5, Delete = 7, TeleportTo = 13, Rename = 14,
			Expand = 25, Collapse = 27, InsertObject = 30, ViewScript = 31,
		})
		Main.LargeIcons = Lib.IconMap.new("rbxassetid://6579106223", 256, 256, 32, 32)
		Main.LargeIcons:SetDict({ Explorer = 0, Properties = 1, Script_Viewer = 2, Watcher = 3, Output = 4 })

		API = Main.FetchAPI()
		RMD = Main.FetchRMD()

		Explorer = Main.LoadModule("Explorer")
		Properties = Main.LoadModule("Properties")
		ScriptViewer = Main.LoadModule("ScriptViewer")
		Console = Main.LoadModule("Console")
		SaveInstance = Main.LoadModule("SaveInstance")

		Explorer.Init()
		Properties.Init()
		ScriptViewer.Init()
		Console.Init()
		SaveInstance.Init()

		Apps.Explorer.Selection.Changed:Connect(Properties.ShowExplorerProps)

		Lib.Window.Init()
		Main.CreateMainGui()
		if Main.MainGui then Main.MainGui.Parent = nil end
		Explorer.Window:Show({ Align = "right", Pos = 1, Size = 0.5, Silent = true })
		Properties.Window:Show({ Align = "right", Pos = 2, Size = 0.5, Silent = true })
		Lib.DeferFunc(function() Lib.Window.ToggleSide("right") end)
		Main.InitDone = true
	end

	Main.CreateMainGui = function()
		local g = Instance.new("ScreenGui")
		g.Name = "DexMain"
		Main.MainGui = g
		Lib.ShowGui(g)
	end

	return Main
end

local DEX = nil
local function launchDex()
	if DEX then return DEX end
	DEX = buildDex()
	task.spawn(function()
		local ok, err = pcall(DEX.Init)
		if not ok then warn("[APEX] Dex: " .. tostring(err)) end
	end)
	return DEX
end

--==================================================================================
--  UI
--==================================================================================
local UI = {}
local gui, root, blur, launcher
local tabBtns, pages = {}, {}
local currentTab = 1
local opened = false

local function tw(obj, t, props, style, dir)
	local info = TweenInfo.new(t or 0.22, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
	local tween = TweenService:Create(obj, info, props)
	tween:Play()
	return tween
end

local function glass(parent, radius, transparency)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C_DARK
	f.BackgroundTransparency = transparency or 0.35
	f.BorderSizePixel = 0
	f.Parent = parent
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, radius or 14)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 42, 120)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(30, 40, 96)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 26, 48)),
	})
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	grad.Rotation = 35
	grad.Parent = f

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(190, 214, 255)
	stroke.Transparency = 0.72
	stroke.Thickness = 1.3
	stroke.Parent = f

	local top = Instance.new("Frame")
	top.BackgroundColor3 = Color3.new(1, 1, 1)
	top.BackgroundTransparency = 0.6
	top.BorderSizePixel = 0
	top.Size = UDim2.new(1, -24, 0, 1)
	top.Position = UDim2.new(0, 12, 0, 1)
	top.Parent = f
	local tg = Instance.new("UIGradient")
	tg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	tg.Parent = top

	return f
end

local function makeButton(parent, text, size, pos, primary)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = primary and C_BLUE or Color3.fromRGB(30, 38, 62)
	b.BackgroundTransparency = primary and 0.1 or 0.45
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 14
	b.TextColor3 = C_TEXT
	b.Text = text
	b.AutoButtonColor = false
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke")
	s.Color = primary and C_RED or C_ICE
	s.Transparency = primary and 0.5 or 0.8
	s.Thickness = 1
	s.Parent = b
	b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundTransparency = primary and 0 or 0.25 }) end)
	b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundTransparency = primary and 0.1 or 0.45 }) end)
	return b
end

local function makeToggle(parent, label, default, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -60, 1, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextSize = 13
	l.TextColor3 = C_MUTED
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 42, 0, 22)
	track.Position = UDim2.new(1, -42, 0.5, -11)
	track.BackgroundColor3 = Color3.fromRGB(38, 48, 74)
	track.BorderSizePixel = 0
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(0, 3, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(210, 222, 245)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local state = default and true or false
	local btn = Instance.new("TextButton")
	btn.BackgroundTransparency = 1
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.Text = ""
	btn.Parent = row

	local function render(anim)
		if anim then
			tw(knob, 0.15, { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) })
			tw(track, 0.15, { BackgroundColor3 = state and C_BLUE or Color3.fromRGB(38, 48, 74) })
		else
			knob.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
			track.BackgroundColor3 = state and C_BLUE or Color3.fromRGB(38, 48, 74)
		end
	end
	render(false)

	btn.MouseButton1Click:Connect(function()
		state = not state
		render(true)
		callback(state)
	end)

	return {
		Set = function(v) state = v render(true) end,
		Get = function() return state end,
	}
end

local function makeSlider(parent, label, min, max, default, step, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -70, 0, 16)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextSize = 13
	l.TextColor3 = C_MUTED
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = row

	local valLbl = Instance.new("TextLabel")
	valLbl.Size = UDim2.new(0, 64, 0, 16)
	valLbl.Position = UDim2.new(1, -64, 0, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.Font = Enum.Font.GothamBold
	valLbl.TextSize = 13
	valLbl.TextColor3 = C_ICE
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0, 24)
	track.BackgroundColor3 = Color3.fromRGB(30, 40, 62)
	track.BorderSizePixel = 0
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = C_BLUE
	fill.BorderSizePixel = 0
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new(C_BLUE, C_RED)
	fg.Parent = fill

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new(0, 0, 0.5, -7)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	local ks = Instance.new("UIStroke")
	ks.Color = C_BLUE
	ks.Thickness = 2
	ks.Parent = knob

	local value = default
	local function render()
		local alpha = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.new(alpha, -7, 0.5, -7)
		valLbl.Text = tostring(value)
	end
	render()

	local dragging = false
	local function fromX(x)
		local abs = track.AbsolutePosition.X
		local w = track.AbsoluteSize.X
		local alpha = math.clamp((x - abs) / math.max(w, 1), 0, 1)
		local v = min + (max - min) * alpha
		if step then v = math.floor(v / step + 0.5) * step end
		value = math.clamp(v, min, max)
		render()
		callback(value)
	end

	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			fromX(i.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)

	return { Set = function(v) value = math.clamp(v, min, max) render() callback(value) end }
end

local function page(parent, index)
	local p = Instance.new("Frame")
	p.Size = UDim2.new(1, -24, 1, -120)
	p.Position = UDim2.new(0, 12, 0, 104)
	p.BackgroundTransparency = 1
	p.Visible = index == 1
	p.Parent = parent
	pages[index] = p
	return p
end

function UI.Build()
	if not playerGui then return end

	gui = Instance.new("ScreenGui")
	gui.Name = "APEX"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 99999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting

	-- launcher
	launcher = Instance.new("TextButton")
	launcher.Size = UDim2.new(0, 58, 0, 58)
	launcher.Position = UDim2.new(0.5, -29, 1, -96)
	launcher.BackgroundColor3 = C_DARK
	launcher.BackgroundTransparency = 0.15
	launcher.BorderSizePixel = 0
	launcher.Text = "APEX"
	launcher.Font = Enum.Font.GothamBlack
	launcher.TextSize = 13
	launcher.TextColor3 = C_TEXT
	launcher.AutoButtonColor = false
	launcher.Parent = gui
	Instance.new("UICorner", launcher).CornerRadius = UDim.new(1, 0)
	local lg = Instance.new("UIGradient")
	lg.Color = ColorSequence.new(C_BLUE, C_RED)
	lg.Rotation = 45
	lg.Parent = launcher
	local ls = Instance.new("UIStroke")
	ls.Color = C_ICE
	ls.Transparency = 0.55
	ls.Thickness = 1.6
	ls.Parent = launcher

	-- painel
	root = Instance.new("CanvasGroup")
	root.Size = UDim2.new(0, 400, 0, 500)
	root.Position = UDim2.new(0.5, -200, 0.5, -250)
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	root.Visible = false
	root.Parent = gui

	local shadow = Instance.new("Frame")
	shadow.Size = UDim2.new(1, 6, 1, 6)
	shadow.Position = UDim2.new(0, -3, 0, 6)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.62
	shadow.BorderSizePixel = 0
	shadow.Parent = root
	Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 20)

	local panel = glass(root, 18, 0.3)
	panel.Size = UDim2.new(1, 0, 1, 0)
	panel.ClipsDescendants = true

	-- header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 58)
	header.BackgroundTransparency = 1
	header.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.new(0, 18, 0, 12)
	title.Size = UDim2.new(1, -100, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 17
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = C_TEXT
	title.Text = "APEX SUITE"
	title.Parent = header

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 18, 0, 32)
	sub.Size = UDim2.new(1, -100, 0, 14)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = C_MUTED
	sub.Text = IS_SERVER and "SERVER-SIDE  •  REPLICADO" or "CLIENT  •  RightShift abre/fecha"
	sub.Parent = header

	local close = makeButton(header, "✕", UDim2.new(0, 30, 0, 30), UDim2.new(1, -42, 0, 14))
	local min = makeButton(header, "—", UDim2.new(0, 30, 0, 30), UDim2.new(1, -78, 0, 14))
	close.MouseButton1Click:Connect(function() UI.Close() end)
	min.MouseButton1Click:Connect(function()
		local hidden = root.Size.Y.Offset < 200
		tw(root, 0.25, { Size = hidden and UDim2.new(0, 400, 0, 500) or UDim2.new(0, 400, 0, 58) })
	end)

	-- abas
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -24, 0, 34)
	bar.Position = UDim2.new(0, 12, 0, 62)
	bar.BackgroundColor3 = Color3.fromRGB(16, 22, 40)
	bar.BackgroundTransparency = 0.45
	bar.BorderSizePixel = 0
	bar.Parent = panel
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0.33, -8, 1, -8)
	indicator.Position = UDim2.new(0, 4, 0, 4)
	indicator.BackgroundColor3 = C_BLUE
	indicator.BackgroundTransparency = 0.05
	indicator.BorderSizePixel = 0
	indicator.Parent = bar
	Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 8)
	local ig = Instance.new("UIGradient")
	ig.Color = ColorSequence.new(C_BLUE, C_RED)
	ig.Parent = indicator

	local names = { "SUPER SHOT", "STUDS 3B", "DEX" }
	for i, n in ipairs(names) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.33, -8, 1, -8)
		b.Position = UDim2.new((i - 1) * 0.3333, 4, 0, 4)
		b.BackgroundTransparency = 1
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = C_MUTED
		b.Text = n
		b.Parent = bar
		tabBtns[i] = b
		b.MouseButton1Click:Connect(function()
			currentTab = i
			for k, p in ipairs(pages) do p.Visible = k == i end
			for k, tb in ipairs(tabBtns) do
				tw(tb, 0.15, { TextColor3 = k == i and C_TEXT or C_MUTED })
			end
			tw(indicator, 0.22, { Position = UDim2.new((i - 1) * 0.3333, 4, 0, 4) })
		end)
	end

	-- página 1: shot
	local p1 = page(panel, 1)
	SS_GUIREF.chargeFill = nil
	makeToggle(p1, "Usar direção da câmera", true, function(v) SS.UseCamera = v end)
	makeSlider(p1, "Força mínima", 100, 1200, 240, 10, function(v) SS.SpeedMin = v end)
	makeSlider(p1, "Força máxima", 200, 3000, 950, 10, function(v) SS.SpeedMax = v end)
	makeSlider(p1, "Alcance de captura (studs)", 8, 80, 26, 1, function(v) SS.Range = v end)

	local chargeBg = Instance.new("Frame")
	chargeBg.Size = UDim2.new(1, 0, 0, 8)
	chargeBg.Position = UDim2.new(0, 0, 0, 132)
	chargeBg.BackgroundColor3 = Color3.fromRGB(30, 40, 62)
	chargeBg.BorderSizePixel = 0
	chargeBg.Parent = p1
	Instance.new("UICorner", chargeBg).CornerRadius = UDim.new(1, 0)

	local chargeFill = Instance.new("Frame")
	chargeFill.Size = UDim2.fromScale(0, 1)
	chargeFill.BackgroundColor3 = C_RED
	chargeFill.BorderSizePixel = 0
	chargeFill.Parent = chargeBg
	Instance.new("UICorner", chargeFill).CornerRadius = UDim.new(1, 0)
	SS_GUIREF.chargeFill = chargeFill

	local shootBtn = makeButton(p1, "SEGURE PARA CARREGAR", UDim2.new(1, 0, 0, 52), UDim2.new(0, 0, 0, 156), true)
	shootBtn.Font = Enum.Font.GothamBlack
	shootBtn.TextSize = 14
	shootBtn.MouseButton1Down:Connect(function() SS:StartAim() end)
	shootBtn.MouseButton1Up:Connect(function() SS:EndAim() end)

	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(1, 0, 0, 40)
	info.Position = UDim2.new(0, 0, 1, -40)
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.Gotham
	info.TextSize = 11
	info.TextWrapped = true
	info.TextColor3 = C_MUTED
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.Text = "Aproxime-se de uma bola (\"Ball\"). Segure para carregar e solte para chutar. Direção é reta, no eixo horizontal."
	info.Parent = p1

	-- página 2: studs
	local p2 = page(panel, 2)
	makeSlider(p2, "Tamanho da peça", 4, 20, 8, 1, function(v) Studs.Size = v end)
	makeSlider(p2, "Peças por frame", 100, 4000, 900, 100, function(v) Studs.Batch = v end)

	local presets = Instance.new("Frame")
	presets.Size = UDim2.new(1, 0, 0, 30)
	presets.Position = UDim2.new(0, 0, 0, 96)
	presets.BackgroundTransparency = 1
	presets.Parent = p2
	local pl = Instance.new("UIListLayout", presets)
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.Padding = UDim.new(0, 6)

	for i, n in ipairs({ "100k", "1M", "10M", "3B" }) do
		local b = makeButton(presets, n, UDim2.new(0.25, -5, 1, 0), UDim2.new((i - 1) * 0.25, 0, 0, 0))
		b.TextSize = 12
		b.MouseButton1Click:Connect(function()
			Studs.Target = ({ 1e5, 1e6, 1e7, 3e9 })[i]
			UI.SetStatus("Alvo: " .. fmt(Studs.Target) .. " peças")
		end)
	end

	local startBtn = makeButton(p2, "INICIAR", UDim2.new(0.5, -4, 0, 44), UDim2.new(0, 0, 0, 134), true)
	local stopBtn = makeButton(p2, "PARAR", UDim2.new(0.5, -4, 0, 44), UDim2.new(0.5, 4, 0, 134))
	startBtn.Font = Enum.Font.GothamBlack
	stopBtn.Font = Enum.Font.GothamBlack

	local cleanBtn = makeButton(p2, "LIMPAR TUDO", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 184))

	local statLbl = Instance.new("TextLabel")
	statLbl.Size = UDim2.new(1, 0, 0, 76)
	statLbl.Position = UDim2.new(0, 0, 0, 224)
	statLbl.BackgroundTransparency = 1
	statLbl.Font = Enum.Font.Code
	statLbl.TextSize = 12
	statLbl.TextWrapped = true
	statLbl.TextXAlignment = Enum.TextXAlignment.Left
	statLbl.TextYAlignment = Enum.TextYAlignment.Top
	statLbl.TextColor3 = C_ICE
	statLbl.Text = "Aguardando."
	statLbl.Parent = p2

	startBtn.MouseButton1Click:Connect(function()
		if Studs.Running then return end
		if not lp or not lp.Character then UI.SetStatus("Sem personagem.") return end
		Studs:Start()
	end)
	stopBtn.MouseButton1Click:Connect(function() Studs:Stop() end)
	cleanBtn.MouseButton1Click:Connect(function()
		Studs:Cleanup()
		statLbl.Text = "Aguardando."
	end)

	task.spawn(function()
		local last = 0
		while true do
			task.wait(0.25)
			if Studs.Running then
				local rate = (Studs.Count - last) * 4
				last = Studs.Count
				local remaining = math.max(0, Studs.Target - Studs.Count)
				statLbl.Text = ("Geradas: %s / %s\nTaxa: %s/s\nETA: %s")
					:format(fmt(Studs.Count), fmt(Studs.Target), fmt(rate),
					rate > 0 and fmtTime(remaining / rate) or "--")
			end
		end
	end)

	-- página 3: dex
	local p3 = page(panel, 3)
	local dexStatus = Instance.new("TextLabel")
	dexStatus.Size = UDim2.new(1, 0, 0, 20)
	dexStatus.BackgroundTransparency = 1
	dexStatus.Font = Enum.Font.GothamBold
	dexStatus.TextSize = 12
	dexStatus.TextXAlignment = Enum.TextXAlignment.Left
	dexStatus.TextColor3 = C_MUTED
	dexStatus.Text = "Dex não iniciado."
	dexStatus.Parent = p3

	local dexBtn = makeButton(p3, "INICIAR DEX", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 26), true)
	dexBtn.Font = Enum.Font.GothamBlack
	dexBtn.MouseButton1Click:Connect(function()
		dexStatus.Text = "Carregando módulos..."
		local d = launchDex()
		task.spawn(function()
			for _ = 1, 120 do
				if d.InitDone then break end
				task.wait(0.25)
			end
			dexStatus.Text = d.InitDone and "Dex ativo. Use os botões abaixo." or "Falha/timeout ao iniciar."
			dexBtn.Visible = false
		end)
	end)

	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, 0, 0, 108)
	grid.Position = UDim2.new(0, 0, 0, 74)
	grid.BackgroundTransparency = 1
	grid.Parent = p3
	local gl = Instance.new("UIGridLayout", grid)
	gl.CellSize = UDim2.new(0.5, -4, 0, 32)
	gl.CellPadding = UDim2.new(0, 8, 0, 8)

	local dexBtns = {
		{ "Explorer", "Explorer" }, { "Propriedades", "Properties" },
		{ "Script Viewer", "ScriptViewer" }, { "Console", "Console" },
		{ "Save Instance", "SaveInstance" },
	}
	for _, pair in ipairs(dexBtns) do
		local b = makeButton(grid, pair[1], UDim2.new(0, 100, 0, 32), UDim2.new())
		b.TextSize = 12
		b.MouseButton1Click:Connect(function()
			if not DEX or not DEX.InitDone then dexStatus.Text = "Inicie o Dex primeiro." return end
			local app = DEX.Apps and DEX.Apps[pair[2]]
			if app and app.Window then app.Window:Show() end
		end)
	end

	local dexNote = Instance.new("TextLabel")
	dexNote.Size = UDim2.new(1, 0, 0, 60)
	dexNote.Position = UDim2.new(0, 0, 0, 190)
	dexNote.BackgroundTransparency = 1
	dexNote.Font = Enum.Font.Gotham
	dexNote.TextSize = 11
	dexNote.TextWrapped = true
	dexNote.TextXAlignment = Enum.TextXAlignment.Left
	dexNote.TextColor3 = C_MUTED
	dexNote.Text = "Dex é client-side por natureza (decompilação, CoreGui). API/RMD são baixadas via HttpGet com fallback."
	dexNote.Parent = p3

	-- status bar
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -24, 0, 18)
	status.Position = UDim2.new(0, 12, 1, -26)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextSize = 11
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = C_MUTED
	status.Text = "Pronto."
	status.Parent = panel

	UI.SetStatus = function(t) status.Text = t end

	-- arrastar
	local drag, dragOff = false, Vector2.new()
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag = true
			dragOff = Vector2.new(i.Position.X - root.AbsolutePosition.X, i.Position.Y - root.AbsolutePosition.Y)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			root.Position = UDim2.new(0, i.Position.X - dragOff.X, 0, i.Position.Y - dragOff.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
	end)

	launcher.MouseButton1Click:Connect(function()
		if opened then UI.Close() else UI.Open() end
	end)

	UIS.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Enum.KeyCode.RightShift and not UIS:GetFocusedTextBox() then
			if opened then UI.Close() else UI.Open() end
		end
	end)
end

function UI.Open()
	if not root then return end
	opened = true
	root.Visible = true
	tw(root, 0.28, { GroupTransparency = 0, Size = UDim2.new(0, 400, 0, 500) })
	tw(blur, 0.28, { Size = 18 })
	tw(launcher, 0.2, { BackgroundTransparency = 0.6 })
end

function UI.Close()
	if not root then return end
	opened = false
	tw(root, 0.2, { GroupTransparency = 1 })
	tw(blur, 0.2, { Size = 0 })
	tw(launcher, 0.2, { BackgroundTransparency = 0.15 })
	task.delay(0.22, function() if not opened then root.Visible = false end end)
end

--==================================================================================
--  API GLOBAL
--==================================================================================
_G.Apex = {
	fireShot = function() SS:Shoot() end,
	startStuds = function(target)
		if target then Studs.Target = target end
		Studs:Start()
	end,
	stopStuds = function() Studs:Stop() end,
	cleanStuds = function() Studs:Cleanup() end,
	open = function() if UI.Open then UI.Open() end end,
	modules = { SS = SS, Studs = Studs },
}

--==================================================================================
--  BOOT
--==================================================================================
if not IS_SERVER then
	UI.Build()
	if cam then
		RunService.RenderStepped:Connect(function()
			if SS.Charging and lp and lp.Character then
				local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
				if hrp and aimA0 then aimA0.Parent = hrp end
			end
		end)
	end
else
	warn("[APEX] Rodando em contexto server-side: UI desativada, use _G.Apex.")
end

print("[APEX] 3-in-1 carregado. " .. (IS_SERVER and "Modo servidor." or "RightShift abre o menu."))
