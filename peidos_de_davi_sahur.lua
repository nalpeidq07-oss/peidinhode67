--==================================================================================
--  APEX SUITE 3-in-1  •  SuperShot (original) + Studs 3B (SS bridge) + Dex
--==================================================================================
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local RS           = game:GetService("ReplicatedStorage")
local WS           = workspace

local lp = Players.LocalPlayer
local IS_SERVER = RunService:IsServer() or lp == nil
local playerGui = (not IS_SERVER) and lp:WaitForChild("PlayerGui") or nil

local C_BLUE  = Color3.fromRGB(58, 118, 255)
local C_RED   = Color3.fromRGB(255, 62, 82)
local C_ICE   = Color3.fromRGB(198, 220, 255)
local C_DARK  = Color3.fromRGB(9, 13, 28)
local C_TEXT  = Color3.fromRGB(240, 245, 255)
local C_MUTED = Color3.fromRGB(140, 158, 190)
local C_CARD  = Color3.fromRGB(18, 25, 45)

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
--  MÓDULO 1 — SUPER SHOT (lógica original preservada)
--==================================================================================
local SS = { SPEED = 500, RANGE = 20, HIT_TIME = 0.3, FLY_TIME = 1.5, USE_CAMERA = true }
local SS_BUSY = false

local function ssGetBall()
	local char = lp and lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local best, bestDist = nil, SS.RANGE
	local ok, desc = pcall(function() return WS:GetDescendants() end)
	if not ok then return end
	for _, v in ipairs(desc) do
		if v.Name == "Ball" and v:IsA("BasePart") then
			local d = (v.Position - hrp.Position).Magnitude
			if d < bestDist then best, bestDist = v, d end
		end
	end
	return best, hrp
end

function SS:Shoot()
	if SS_BUSY then return end
	local ball, hrp = ssGetBall()
	if not ball or not hrp then return end
	SS_BUSY = true

	local look = self.USE_CAMERA and cam.CFrame.LookVector or hrp.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z).Unit
	local origin = hrp.CFrame
	local t0 = tick()

	pcall(function() ball:SetNetworkOwner(lp) end)
	pcall(function()
		sethiddenproperty(lp, "SimulationRadius", math.huge)
		sethiddenproperty(lp, "MaxSimulationRadius", math.huge)
	end)

	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = tick() - t0
		if not ball.Parent or not hrp.Parent or t >= self.FLY_TIME then
			conn:Disconnect()
			pcall(function()
				ball.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				hrp.CFrame = origin
			end)
			SS_BUSY = false
			return
		end
		if t < self.HIT_TIME then
			hrp.CFrame = CFrame.new(ball.Position - dir * 1.5, ball.Position)
			hrp.AssemblyLinearVelocity = dir * self.SPEED
			pcall(function()
				firetouchinterest(hrp, ball, 0)
				firetouchinterest(hrp, ball, 1)
			end)
		else
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = origin
		end
		ball.AssemblyLinearVelocity = dir * self.SPEED
	end)
end

--==================================================================================
--  MÓDULO 2 — STUDS 3B + PONTE SERVER-SIDE
--==================================================================================
local Studs = { Running = false, Count = 0, Target = 3e9, Batch = 900, Size = 8, Folder = nil, Template = nil, Elapsed = 0 }

-- fonte autônoma injetada no servidor via RemoteEvent
local SS_SOURCE = [==[
local WS=workspace
local f=WS:FindFirstChild("APEX_Studs") or Instance.new("Folder")
f.Name="APEX_Studs" f.Parent=WS
local t=Instance.new("Part")
t.Anchored=true t.CanCollide=true t.CastShadow=false t.Massless=true
t.Material=Enum.Material.Plastic t.TopSurface=Enum.SurfaceType.Studs t.BottomSurface=Enum.SurfaceType.Inlet
t.Color=Color3.fromRGB(163,162,165) t.Name="Studs"
local y=math.floor(WS.CurrentCamera and 0 or 0)
local S=8 local r=0
local function p(gx,gz)
	local c=t:Clone() c.Size=Vector3.new(S,1,S) c.CFrame=CFrame.new(gx*S,y,gz*S) c.Parent=f
end
local placed=0
while true do
	if r==0 then p(0,0) placed+=1
	else
		for i=-r,r do p(i,-r) p(i,r) placed+=2 if placed>=900 then placed=0 task.wait() end end
		for i=-r+1,r-1 do p(-r,i) p(r,i) placed+=2 if placed>=900 then placed=0 task.wait() end end
	end
	r+=1
	if r%2==0 then task.wait() end
end
]==]

local REMOTE_PATTERN = "load|exec|run|script|admin|cmd|command|ss|backdoor|api|remote|main|inject|eval"

function Studs:ScanRemotes()
	local out = {}
	local seen = 0
	local ok = pcall(function()
		local roots = { RS, WS, game:GetService("ReplicatedFirst") }
		for _, root in ipairs(roots) do
			for _, d in ipairs(root:GetDescendants()) do
				seen += 1
				if seen > 5000 then return end
				local isRemote = d:IsA("RemoteEvent")
				if not isRemote then
					local okU, isU = pcall(function() return d:IsA("UnreliableRemoteEvent") end)
					isRemote = okU and isU
				end
				if isRemote and d.Name:lower():find(REMOTE_PATTERN) then
					out[#out + 1] = d
					if #out >= 10 then return end
				end
			end
		end
	end)
	if not ok then return {} end
	return out
end

function Studs:Inject(source)
	local list = self:ScanRemotes()
	if #list == 0 then return 0 end
	local fired = 0
	for _, r in ipairs(list) do
		local ok = pcall(function() r:FireServer(source) end)
		if ok then fired += 1 end
	end
	return fired
end

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

function Studs:Stop() self.Running = false end

function Studs:Cleanup()
	self:Stop()
	if self.Folder then self.Folder:Destroy() self.Folder = nil end
	self.Count = 0
end

function Studs:Start()
	if self.Running then return end
	local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	self:Prepare()
	self.Running = true
	self.Count = 0

	local baseY = math.floor(hrp.Position.Y) - 4
	local ox, oz = hrp.Position.X, hrp.Position.Z
	local folder, tmpl, size, batch, target = self.Folder, self.Template, self.Size, self.Batch, self.Target
	local started = os.clock()

	task.spawn(function()
		local r = 0
		while self.Running and self.Count < target and folder.Parent do
			local placed = 0
			local function place(gx, gz)
				local p = tmpl:Clone()
				p.Size = Vector3.new(size, 1, size)
				p.CFrame = CFrame.new(ox + gx * size, baseY, oz + gz * size)
				p.Parent = folder
				self.Count += 1
				placed += 1
			end
			if r == 0 then place(0, 0)
			else
				for i = -r, r do
					place(i, -r); place(i, r)
					if placed >= batch then break end
				end
				if placed < batch then
					for i = -r + 1, r - 1 do
						place(-r, i); place(r, i)
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
--  MÓDULO 3 — DEX
--==================================================================================
local function buildDex()
	local nodes = {}
	local selection
	local function missing(t, f, fb) if type(f) == t then return f end return fb end
	local cloneref = missing("function", cloneref, function(...) return ... end)
	local service = setmetatable({}, { __index = function(self, n) self[n] = cloneref(game:GetService(n)) return self[n] end })
	local oldgame = game
	local game = workspace.Parent
	local EmbeddedModules = {}

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
			local rs = service.RunService.RenderStepped
			local sw = rs.wait
			local PH, SIGNAL = newproxy(), newproxy()
			local function initObj(props, mt)
				local function cp(t)
					local r = {}
					for i, v in pairs(t) do
						if v == SIGNAL then r[i] = Lib.Signal.new()
						elseif type(v) == "table" then r[i] = cp(v)
						else r[i] = v end
					end
					return r
				end
				return setmetatable(cp(props), mt)
			end
			local function getGuiMT(props, funcs)
				return {
					__index = function(self, i) if not props[i] then return funcs[i] or self.Gui[i] end end,
					__newindex = function(self, i, v) if not props[i] then self.Gui[i] = v else rawset(self, i, v) end end,
				}
			end
			Lib.FormatLuaString = (function()
				local g, f, c = string.gsub, string.format, string.char
				local t = { ['"'] = '\\"', ['\\'] = '\\\\' }
				for i = 0, 31 do t[c(i)] = "\\" .. f("%03d", i) end
				for i = 127, 255 do t[c(i)] = "\\" .. f("%03d", i) end
				return function(s) return g(s, "[\"\\\0-\31\127-\255]", t) end
			end)()
			Lib.CheckMouseInGui = function(g)
				if not g then return false end
				local m, p, s = Main.Mouse, g.AbsolutePosition, g.AbsoluteSize
				return m.X >= p.X and m.X < p.X + s.X and m.Y >= p.Y and m.Y < p.Y + s.Y
			end
			Lib.FastWait = function(s)
				if not s then return sw(rs) end
				local t = os.clock()
				while os.clock() - t < s do sw(rs) end
			end
			Lib.FindAndRemove = function(t, i) local p = table.find(t, i) if p then table.remove(t, p) end end
			Lib.ShowGui = function(g)
				if env.gethui then g.Parent = env.gethui()
				elseif env.protectgui then env.protectgui(g) g.Parent = Main.GuiHolder
				else g.Parent = Main.GuiHolder end
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
			Lib.DeferFunc = function(f, ...) sw(rs) return f(...) end
			Lib.Signal = (function()
				local F = {}
				F.Connect = function(self, fn)
					local c = { Signal = self, Func = fn }
					c.Disconnect = function()
						local p = table.find(self.Connections, c)
						if p then table.remove(self.Connections, p) end
					end
					self.Connections[#self.Connections + 1] = c
					return c
				end
				F.Fire = function(self, ...)
					for _, v in next, self.Connections do
						xpcall(coroutine.wrap(v.Func), function(e) warn(e) end, ...)
					end
				end
				local mt = { __index = F }
				return { new = function() return setmetatable({ Connections = {} }, mt) end }
			end)()
			Lib.Set = (function()
				local F = {}
				F.Add = function(self, o) if self.Map[o] then return end self.List[#self.List + 1] = o self.Map[o] = true self.Changed:Fire() end
				F.Remove = function(self, o)
					if not self.Map[o] then return end
					local p = table.find(self.List, o)
					if p then table.remove(self.List, p) end
					self.Map[o] = nil
					self.Changed:Fire()
				end
				F.Set = function(self, o)
					if #self.List == 1 and self.List[1] == o then return end
					self.List = { o } self.Map = { [o] = true } self.Changed:Fire()
				end
				F.Clear = function(self)
					if #self.List == 0 then return end
					self.List = {} self.Map = {} self.Changed:Fire()
				end
				local mt = { __index = F }
				return { new = function() return setmetatable({ List = {}, Map = {}, Changed = Lib.Signal.new() }, mt) end }
			end)()
			Lib.IconMap = (function()
				local F = {}
				F.Display = function(self, o, i)
					o.Image = self.MapId
					o.ImageRectOffset = Vector2.new(self.IconSizeX * i, 0)
				end
				F.DisplayByKey = function(self, o, k)
					if self.IndexDict[k] then self:Display(o, self.IndexDict[k]) end
				end
				F.DisplayExplorerIcons = function(self, f, idx)
					local m = f:FindFirstChild("IconMap")
					if not m then
						f.ClipsDescendants = true
						m = Instance.new("ImageLabel", f)
						m.BackgroundTransparency = 1
						m.Name = "IconMap"
						m.Size = UDim2.new(16, 0, 16, 0)
					end
					m.Image = "rbxasset://textures/ClassImages.PNG"
					m.ImageRectOffset = Vector2.new((idx % 14) * 16, math.floor(idx / 14) * 16)
				end
				F.SetDict = function(self, d) self.IndexDict = d end
				local mt = { __index = F }
				local function newLinear(id, x, y) return setmetatable({ MapId = id, IconSizeX = x, IconSizeY = y, IndexDict = {} }, mt) end
				return { newLinear = newLinear, new = newLinear }
			end)()
			Lib.ScrollBar = (function()
				local F = {}
				F.Update = function(self)
					self.Index = math.clamp(self.Index, 0, math.max(0, self.TotalSpace - self.VisibleSpace))
					local st = self.GuiElems.Thumb
					st.Visible = self:CanScrollUp() or self:CanScrollDown()
					local total, vis = self.TotalSpace, self.VisibleSpace
					if self.Horizontal then
						st.Size = UDim2.new(vis / total, 0, 1, 0)
						if st.AbsoluteSize.X < 12 then st.Size = UDim2.new(0, 12, 1, 0) end
					else
						st.Size = UDim2.new(1, 0, vis / total, 0)
						if st.AbsoluteSize.Y < 12 then st.Size = UDim2.new(1, 0, 0, 12) end
					end
				end
				F.ScrollTo = function(self, i, nc) self.Index = i self:Update() if not nc then self.Scrolled:Fire() end end
				F.CanScrollUp = function(self) return self.Index > 0 end
				F.CanScrollDown = function(self) return self.Index + self.VisibleSpace < self.TotalSpace end
				F.SetScrollFrame = function(self, f)
					if self.A then self.A:Disconnect() end
					if self.B then self.B:Disconnect() end
					self.A = f.MouseWheelForward:Connect(function() self:ScrollTo(self.Index - self.WheelIncrement) end)
					self.B = f.MouseWheelBackward:Connect(function() self:ScrollTo(self.Index + self.WheelIncrement) end)
				end
				local mt = { __index = F }
				return {
					new = function(hor)
						local o = setmetatable({ Index = 0, VisibleSpace = 0, TotalSpace = 0, Increment = 1, WheelIncrement = 3, Horizontal = hor, Scrolled = Lib.Signal.new(), GuiElems = {} }, mt)
						local f = Instance.new("Frame")
						f.BackgroundTransparency = 1
						f.Size = hor and UDim2.new(1, 0, 0, 12) or UDim2.new(0, 12, 1, 0)
						local st = Instance.new("Frame", f)
						st.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
						st.BorderSizePixel = 0
						st.Position = hor and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
						local c = Instance.new("UICorner", st)
						c.CornerRadius = UDim.new(1, 0)
						o.GuiElems.Thumb = st
						o.Gui = f
						return o
					end,
				}
			end)()
			Lib.Window = (function()
				local F = {}
				local mouse = plr:GetMouse()
				local sides, order, visible = nil, 0, {}
				local LS = { Width = 300, Windows = {}, Hidden = true }
				local RSD = { Width = 300, Windows = {}, Hidden = true }

				local function upd(noTween)
					LS.Frame.Size = UDim2.new(0, LS.Width, 1, 0)
					RSD.Frame.Size = UDim2.new(0, RSD.Width, 1, 0)
					LS.Frame.Position = UDim2.new(0, (#LS.Windows == 0 or LS.Hidden) and -LS.Width - 8 or 0, 0, 0)
					RSD.Frame.Position = UDim2.new(1, (#RSD.Windows == 0 or RSD.Hidden) and 8 or -RSD.Width, 0, 0)
					for side, pos in pairs({ [LS] = 0, [RSD] = 1 }) do
						local cur = 0
						for _, w in ipairs(side.Windows) do
							w.GuiElems.Main.Size = UDim2.new(0, side.Width, 0, w.SizeY)
							w.GuiElems.Main.Position = UDim2.new(pos, pos == 0 and 0 or -side.Width, 0, cur)
							Lib.ShowGui(w.Gui)
							cur += w.SizeY + 4
						end
					end
					local c = 0
					for i = #visible, 1, -1 do
						visible[i].Gui.DisplayOrder = order + c
						Lib.ShowGui(visible[i].Gui)
						c += 1
					end
				end

				F.SetTitle = function(self, t) self.GuiElems.Title.Text = t end
				F.Resize = function(self, x, y)
					self.SizeX = x or self.SizeX
					self.SizeY = y or self.SizeY
					self.GuiElems.Main.Size = UDim2.new(0, self.SizeX, 0, self.SizeY)
				end
				F.IsVisible = function(self) return not self.Closed and (not self.Side or not self.Side.Hidden) end
				F.Add = function(self, o, n)
					if type(o) == "table" and o.Gui then o.Gui.Parent = self.Content else o.Parent = self.Content end
					if n then self.Elements[n] = o end
				end
				F.SetAligned = function(self, v)
					self.Aligned = v
					self.GuiElems.ResizeControls.Visible = not v
					self.GuiElems.Main.Active = not v
					if not v then
						for i, w in ipairs(LS.Windows) do if w == self then table.remove(LS.Windows, i) break end end
						for i, w in ipairs(RSD.Windows) do if w == self then table.remove(RSD.Windows, i) break end end
						if not table.find(visible, self) then table.insert(visible, 1, self) end
						self.Side = nil
					else
						for i, w in ipairs(visible) do if w == self then table.remove(visible, i) break end end
					end
					upd()
				end
				F.AlignTo = function(self, side, pos, silent)
					if table.find(side.Windows, self) or self.Closed then return end
					self:SetAligned(true)
					self.Side = side
					self.SizeX = side.Width
					pos = math.min(#side.Windows + 1, pos or 1)
					self.SidePos = pos
					table.insert(side.Windows, pos, self)
					if not silent then side.Hidden = false end
					upd()
				end
				F.Close = function(self)
					self.Closed = true
					Lib.FindAndRemove(LS.Windows, self)
					Lib.FindAndRemove(RSD.Windows, self)
					Lib.FindAndRemove(visible, self)
					self.Side = nil
					self.Gui.Parent = nil
					upd(true)
				end
				F.Hide = F.Close
				F.Show = function(self, d)
					d = d or {}
					if not self.Closed then return end
					self.Closed = false
					if d.Align then
						self:AlignTo(d.Align == "left" and LS or RSD, d.Pos, d.Silent)
					else
						self.GuiElems.Main.Size = UDim2.new(0, self.SizeX, 0, 20)
						table.insert(visible, 1, self)
						upd()
						TweenService:Create(self.GuiElems.Main, TweenInfo.new(0.2), { Size = UDim2.new(0, self.SizeX, 0, self.SizeY) }):Play()
					end
				end

				local function mk(self)
					local g = create({
						{ 1, "ScreenGui", { Name = "Window" } },
						{ 2, "Frame", { Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Main", Parent = { 1 }, Size = UDim2.new(0, 300, 0, 300) } },
						{ 3, "Frame", { BackgroundColor3 = Color3.fromRGB(40, 40, 40), BorderSizePixel = 0, Name = "Content", Parent = { 2 }, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 1, -22), ClipsDescendants = true } },
						{ 4, "TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(52, 52, 52), BorderSizePixel = 0, Name = "TopBar", Parent = { 2 }, Size = UDim2.new(1, 0, 0, 22) } },
						{ 5, "TextLabel", { BackgroundTransparency = 1, Font = 3, Name = "Title", Parent = { 4 }, Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -50, 0, 22), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = 0 } },
						{ 6, "TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, Name = "Close", Parent = { 4 }, Position = UDim2.new(1, -20, 0, 3), Size = UDim2.new(0, 16, 0, 16), Text = "✕", TextColor3 = Color3.new(1, 1, 1), TextSize = 12 } },
						{ 7, "Frame", { BackgroundTransparency = 1, Name = "ResizeControls", Parent = { 2 }, Position = UDim2.new(0, -4, 0, -4), Size = UDim2.new(1, 8, 1, 8) } },
					})
					for _, n in ipairs({ "North", "South", "East", "West", "NorthEast", "SouthEast", "NorthWest", "SouthWest" }) do
						local b = Instance.new("TextButton", g.Main.ResizeControls)
						b.BackgroundTransparency = 1
						b.BorderSizePixel = 0
						b.Text = ""
						b.Name = n
					end
					self.GuiElems = { Main = g.Main, Content = g.Main.Content, Title = g.Main.TopBar.Title, ResizeControls = g.Main.ResizeControls }
					self.Content = g.Main.Content
					g.Main.TopBar.Close.MouseButton1Click:Connect(function() if not self.Closed then self:Close() end end)
					local down, ox, oy = false, 0, 0
					g.Main.TopBar.InputBegan:Connect(function(i)
						if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
							down = true
							ox = i.Position.X - g.Main.AbsolutePosition.X
							oy = i.Position.Y - g.Main.AbsolutePosition.Y
						end
					end)
					service.UserInputService.InputChanged:Connect(function(i)
						if down and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
							g.Main.Position = UDim2.new(0, i.Position.X - ox, 0, i.Position.Y - oy)
						end
					end)
					service.UserInputService.InputEnded:Connect(function(i)
						if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then down = false end
					end)
					g.Main.Size = UDim2.new(0, self.SizeX, 0, self.SizeY)
					return g
				end

				local function initSides()
					order = Main.DisplayOrders.Window
					sides = Instance.new("ScreenGui")
					for _, pair in ipairs({ { "L", LS, 0 }, { "R", RSD, 1 } }) do
						local side = pair[2]
						local f = Instance.new("Frame", sides)
						f.Name = pair[1] .. "Side"
						f.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
						f.BorderSizePixel = 0
						side.Frame = f
						local rz = Instance.new("TextButton", f)
						rz.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
						rz.BorderSizePixel = 0
						rz.Text = ""
						rz.Size = UDim2.new(0, 4, 1, 0)
						rz.Position = pair[3] == 0 and UDim2.new(1, 0, 0, 0) or UDim2.new(0, -4, 0, 0)
						local resizing = false
						rz.InputBegan:Connect(function(i)
							if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
								resizing = true
								local sx = i.Position.X
								local startW = side.Width
								local con
								con = service.UserInputService.InputChanged:Connect(function(m)
									if resizing and m.UserInputType == Enum.UserInputType.MouseMovement then
										local d = (m.Position.X - sx) * (pair[3] == 0 and 1 or -1)
										side.Width = math.clamp(startW + d, 180, 600)
										upd(true)
									end
								end)
								service.UserInputService.InputEnded:Connect(function()
									resizing = false
									if con then con:Disconnect() end
								end)
							end
						end)
					end
					sides.DisplayOrder = Main.DisplayOrders.SideWindow - 1
					Lib.ShowGui(sides)
					upd(true)
				end

				local mt = { __index = F }
				return {
					Init = initSides,
					new = function()
						local o = setmetatable({
							Closed = true, SizeX = 300, SizeY = 300, Elements = {},
							OnActivate = Lib.Signal.new(), OnDeactivate = Lib.Signal.new(),
						}, mt)
						o.Gui = mk(o)
						return o
					end,
				}
			end)()
			Lib.ContextMenu = (function()
				local F = {}
				local mouse
				F.Add = function(self, it) self.Items[#self.Items + 1] = it self.Updated = nil end
				F.Register = function(self, n, it) self.Registered[n] = it end
				F.AddRegistered = function(self, n, dis)
					if not self.Registered[n] then return end
					self.Registered[n].Disabled = dis
					self.Items[#self.Items + 1] = self.Registered[n]
					self.Updated = nil
				end
				F.Clear = function(self) self.Items = {} self.Updated = nil end
				F.Refresh = function(self)
					for _, v in ipairs(self.List:GetChildren()) do
						if not v:IsA("UIListLayout") then v:Destroy() end
					end
					for _, it in ipairs(self.Items) do
						local b = self.Template:Clone()
						b.Name = it.Name or ""
						b.Text = it.Name or ""
						b.Visible = true
						if it.Disabled then b.TextColor3 = Color3.fromRGB(140, 140, 140)
						elseif it.OnClick then b.MouseButton1Click:Connect(function() it.OnClick(it.Name) self:Hide() end) end
						b.Parent = self.List
					end
					self.Updated = true
				end
				F.Show = function(self, x, y)
					if not self.Updated then self:Refresh() end
					x, y = x or mouse.X, y or mouse.Y
					self.Main.Position = UDim2.new(0, math.min(x, mouse.ViewSizeX - self.Width), 0, y)
					self.Main.Size = UDim2.new(0, self.Width, 0, 0)
					Lib.ShowGui(self.Gui)
					local sz = self.List.UIListLayout.AbsoluteContentSize.Y + 4
					self.Main:TweenSize(UDim2.new(0, self.Width, 0, sz), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.15, true)
					local closable = false
					if self.CE then self.CE:Disconnect() end
					self.CE = service.UserInputService.InputBegan:Connect(function(i)
						if closable and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
							if not Lib.CheckMouseInGui(self.Main) then self:Hide() end
						end
					end)
					Lib.FastWait()
					closable = true
				end
				F.Hide = function(self) self.Gui.Parent = nil end
				local mt = { __index = F }
				return {
					new = function()
						if not mouse then mouse = plr:GetMouse() end
						local o = setmetatable({ Width = 190, Items = {}, Registered = {}, Updated = false }, mt)
						local g = Instance.new("ScreenGui")
						g.DisplayOrder = 1e6
						o.Gui = g
						o.Main = Instance.new("Frame", g)
						o.Main.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
						o.Main.BorderSizePixel = 0
						o.Main.Size = UDim2.new(0, 190, 0, 100)
						local lst = Instance.new("ScrollingFrame", o.Main)
						lst.BackgroundTransparency = 1
						lst.BorderSizePixel = 0
						lst.Position = UDim2.new(0, 2, 0, 2)
						lst.Size = UDim2.new(1, -4, 1, -4)
						lst.CanvasSize = UDim2.new(0, 0, 0, 0)
						lst.AutomaticCanvasSize = Enum.AutomaticSize.Y
						lst.ScrollBarThickness = 4
						local l = Instance.new("UIListLayout", lst)
						l.SortOrder = Enum.SortOrder.LayoutOrder
						o.List = lst
						local t = Instance.new("TextButton", g)
						t.AutoButtonColor = false
						t.BackgroundTransparency = 1
						t.Font = 3
						t.TextSize = 14
						t.TextColor3 = Color3.new(1, 1, 1)
						t.TextXAlignment = 0
						t.Size = UDim2.new(1, 0, 0, 22)
						t.Visible = false
						o.Template = t
						return o
					end,
				}
			end)()
			Lib.CodeFrame = (function()
				local F = {}
				F.GetText = function(self) return table.concat(self.Lines, "\n") end
				F.SetText = function(self, t)
					local l = {}
					for line in t:gmatch("([^\n\r]*)[\n\r]?") do l[#l + 1] = line end
					self.Lines = l
					self:Refresh()
				end
				F.Refresh = function(self)
					local maxL = math.ceil(math.max(0, self.Frame.AbsoluteSize.Y) / self.Font)
					local nums = ""
					for i = 1, maxL do
						local lf = self.Rows[i]
						if not lf then
							lf = Instance.new("TextLabel", self.Frame)
							lf.BackgroundTransparency = 1
							lf.Font = Enum.Font.Code
							lf.TextSize = self.Font
							lf.TextXAlignment = Enum.TextXAlignment.Left
							lf.TextColor3 = Color3.fromRGB(205, 205, 205)
							lf.Size = UDim2.new(1, -34, 0, self.Font)
							lf.Position = UDim2.new(0, 34, 0, (i - 1) * self.Font)
							self.Rows[i] = lf
						end
						local t = self.Lines[i] or ""
						lf.Text = t:gsub("<", "&lt;"):gsub(">", "&gt;")
						if self.Lines[i] then nums = nums .. i .. "\n" end
					end
					self.Nums.Text = nums
					self.Nums.TextSize = self.Font
				end
				local mt = { __index = F }
				return {
					new = function()
						local o = setmetatable({ Font = 14, Lines = { "" }, Rows = {} }, mt)
						o.Frame = Instance.new("Frame")
						o.Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
						o.Frame.BorderSizePixel = 0
						o.Frame.Size = UDim2.new(1, 0, 1, 0)
						o.Frame.ClipsDescendants = true
						o.Nums = Instance.new("TextLabel", o.Frame)
						o.Nums.BackgroundTransparency = 1
						o.Nums.Font = Enum.Font.Code
						o.Nums.TextColor3 = Color3.fromRGB(110, 110, 110)
						o.Nums.TextXAlignment = Enum.TextXAlignment.Right
						o.Nums.TextYAlignment = Enum.TextYAlignment.Top
						o.Nums.Size = UDim2.new(0, 30, 1, 0)
						o:Refresh()
						return o
					end,
				}
			end)()
			Lib.Checkbox = (function()
				local F = {}
				F.Paint = function(self)
					self.Box.BackgroundColor3 = self.Toggled and C_BLUE or Color3.fromRGB(45, 45, 45)
					self.Dot.Visible = self.Toggled and true or false
				end
				F.SetState = function(self, v) self.Toggled = v self:Paint() end
				local mt = { __index = F }
				return {
					new = function()
						local o = setmetatable({ Toggled = false, OnInput = Lib.Signal.new() }, mt)
						local b = Instance.new("TextButton")
						b.BackgroundTransparency = 1
						b.Text = ""
						b.Size = UDim2.new(0, 16, 0, 16)
						o.Gui = b
						o.Box = Instance.new("Frame", b)
						o.Box.Size = UDim2.new(0, 16, 0, 16)
						o.Box.BorderSizePixel = 0
						Instance.new("UICorner", o.Box).CornerRadius = UDim.new(0, 4)
						o.Dot = Instance.new("Frame", o.Box)
						o.Dot.Size = UDim2.new(0, 8, 0, 8)
						o.Dot.Position = UDim2.new(0.5, -4, 0.5, -4)
						o.Dot.BorderSizePixel = 0
						Instance.new("UICorner", o.Dot).CornerRadius = UDim.new(1, 0)
						b.Activated:Connect(function() o:SetState(not o.Toggled) o.OnInput:Fire() end)
						o:Paint()
						return o
					end,
				}
			end)()
			Lib.ViewportTextBox = (function()
				local F = {}
				F.GetText = function(self) return self.Gui.Text end
				F.SetText = function(self, t) self.Gui.Text = t end
				local mt = { __index = F }
				return { new = function()
					local t = Instance.new("TextBox")
					t.Size = UDim2.new(0, 100, 0, 20)
					t.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					t.TextColor3 = Color3.new(1, 1, 1)
					t.Font = 3
					t.TextSize = 14
					t.Text = ""
					return setmetatable({ Gui = t }, mt)
				end }
			end)()
			Lib.Label = (function()
				return { new = function()
					local l = Instance.new("TextLabel")
					l.BackgroundTransparency = 1
					l.TextXAlignment = 0
					l.TextColor3 = Color3.new(1, 1, 1)
					l.Size = UDim2.new(0, 100, 0, 20)
					l.Font = 3
					l.TextSize = 14
					return { Gui = l }
				end }
			end)()
			Lib.Button = (function()
				return { new = function()
					local b = Instance.new("TextButton")
					b.AutoButtonColor = false
					b.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
					b.TextColor3 = Color3.new(1, 1, 1)
					b.Font = 3
					b.TextSize = 14
					b.Size = UDim2.new(0, 100, 0, 20)
					local o = { Gui = b, OnClick = Lib.Signal.new() }
					b.MouseButton1Click:Connect(function() o.OnClick:Fire() end)
					return o
				end }
			end)()
			Lib.ClickSystem = (function()
				local F = {}
				F.Add = function(self, it)
					self.Cons[it] = {
						it.MouseButton1Down:Connect(function(x, y) self.OnDown:Fire(it, 1, x, y) end),
						it.MouseButton2Down:Connect(function(x, y) self.OnDown:Fire(it, 2, x, y) end),
					}
				end
				F.Remove = function(self, it)
					for _, c in ipairs(self.Cons[it] or {}) do c:Disconnect() end
					self.Cons[it] = nil
				end
				local mt = { __index = F }
				return { new = function()
					local o = setmetatable({ Cons = {}, OnDown = Lib.Signal.new(), OnRelease = Lib.Signal.new(), ComboTime = 0.4 }, mt)
					return o
				end }
			end)()
			return Lib
		end
		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

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
			local tree, entries, expanded = {}, {}, {}
			local treeFrame, window, scrollV, searchBox
			local nilNode = { Obj = Instance.new("Folder") }
			local dirty = {}
			local addObj, remObj, moveObj

			local function resolve(o)
				local p = o.Parent
				return p and nodes[p] or nodes[game.FindFirstAncestorWhichIsA(o, "Instance")]
			end

			addObj = function(root)
				if nodes[root] then return end
				local par = resolve(root)
				if not par then return end
				local n = { Obj = root, Parent = par }
				nodes[root] = n
				par[#par + 1] = n
				par.Sorted = nil
				for _, o in ipairs(game:GetDescendants()) do end
				for _, o in ipairs(root:GetDescendants()) do
					if not nodes[o] then
						local p = o.Parent
						local pn = p and nodes[p]
						if pn then
							local nn = { Obj = o, Parent = pn }
							nodes[o] = nn
							pn[#pn + 1] = nn
						end
					end
				end
				if Explorer.Window and Explorer.Window:IsVisible() then Explorer.ForceUpdate() end
			end

			remObj = function(root)
				local n = nodes[root]
				if not n then return end
				local par = n.Parent
				if par then
					par.HasDel = true
					dirty[par] = true
				end
				local function rc(t)
					for i = 1, #t do
						local x = t[i]
						if not x.Del then
							nodes[x.Obj] = nil
							if #x > 0 then rc(x) end
						end
					end
				end
				rc(n)
				n.Del = true
				nodes[root] = nil
				if par then dirty[par] = true end
			end

			moveObj = function(o)
				local n = nodes[o]
				if not n then return end
				local op = n.Parent
				local np = resolve(o)
				if op == np or not np then return end
				if op then
					local i = table.find(op, n)
					if i then table.remove(op, i) end
					op.HasDel = true
					dirty[op] = true
				end
				n.Parent = np
				np[#np + 1] = n
				np.Sorted = nil
				dirty[np] = true
			end

			Explorer.ViewWidth, Explorer.Index, Explorer.EntryIndent = 0, 0, 20

			Explorer.NodeDepth = function(n)
				local d = 0
				local c = n.Parent
				while c do d += 1 c = c.Parent end
				return d
			end

			Explorer.Update = function()
				table.clear(tree)
				local count, maxD = 1, 1
				local function rc(root, depth)
					if depth > maxD then maxD = depth end
					depth += 1
					if not root.Sorted then
						table.sort(root, function(a, b)
							if a.Del or b.Del then return false end
							return tostring(a.Obj) < tostring(b.Obj)
						end)
						root.Sorted = true
					end
					for i = 1, #root do
						local n = root[i]
						if not n.Del then
							tree[count] = n
							count += 1
							if expanded[n] and #n > 0 then rc(n, depth) end
						end
					end
				end
				rc(nodes[game] or {}, 1)
				Explorer.ViewWidth = Explorer.EntryIndent * maxD + 240
				if treeFrame then
					scrollV.TotalSpace = #tree
					scrollV.VisibleSpace = math.ceil(treeFrame.AbsoluteSize.Y / 20)
					scrollV.Gui.Visible = #tree > scrollV.VisibleSpace
					scrollV:Update()
					Explorer.Index = scrollV.Index
				end
			end

			Explorer.Refresh = function()
				if not treeFrame then return end
				local max = math.max(math.ceil(treeFrame.AbsoluteSize.Y / 20), 0)
				for i = 1, max do
					local e = entries[i]
					if not e then
						e = Explorer.Template:Clone()
						e.Parent = treeFrame
						entries[i] = e
						e.Expand.MouseButton1Click:Connect(function()
							local n = tree[i + Explorer.Index]
							if not n or #n == 0 then return end
							expanded[n] = not expanded[n]
							Explorer.ForceUpdate()
						end)
						e.MouseButton1Click:Connect(function()
							local n = tree[i + Explorer.Index]
							if n then Explorer.Selection:Set(n) end
						end)
					end
					local n = tree[i + Explorer.Index]
					if n then
						local d = Explorer.EntryIndent * Explorer.NodeDepth(n)
						e.Visible = true
						e.Position = UDim2.new(0, 0, 0, (i - 1) * 20)
						e.Size = UDim2.new(0, Explorer.ViewWidth, 0, 20)
						e.Name_2.Text = tostring(n.Obj)
						e.Name_2.Position = UDim2.new(0, d + 22, 0, 0)
						e.Name_2.Size = UDim2.new(1, -(d + 24), 1, 0)
						e.Expand.Visible = #n > 0
						e.Expand.Text = expanded[n] and "−" or "+"
						e.Bg.BackgroundTransparency = Explorer.Selection.Map[n] and 0.15 or 1
					else e.Visible = false end
				end
				for i = max + 1, #entries do entries[i]:Destroy() entries[i] = nil end
			end

			Explorer.ForceUpdate = function()
				Explorer.Update()
				Explorer.Refresh()
			end

			Explorer.Init = function()
				Explorer.Selection = Lib.Set.new()
				Explorer.Selection.Changed:Connect(function() Explorer.Refresh() end)

				Explorer.Template = create({
					{ 1, "TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", Size = UDim2.new(0, 250, 0, 20) } },
					{ 2, "Frame", { BackgroundColor3 = C_BLUE, BorderSizePixel = 0, Name = "Bg", Parent = { 1 }, Position = UDim2.new(0, 18, 0, 1), Size = UDim2.new(1, -18, 1, -2) } },
					{ 3, "TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, Font = 3, Name = "Expand", Parent = { 1 }, Size = UDim2.new(0, 16, 0, 20), Text = "+", TextColor3 = Color3.fromRGB(180, 200, 230), TextSize = 15 } },
					{ 4, "TextLabel", { BackgroundTransparency = 1, Font = 3, Name = "Name_2", Parent = { 1 }, Size = UDim2.new(1, -24, 1, 0), Text = "", TextColor3 = Color3.fromRGB(220, 225, 235), TextSize = 13, TextXAlignment = 0 } },
				})

				window = Lib.Window.new()
				Explorer.Window = window
				window:SetTitle("Explorer")

				local bar = Instance.new("Frame", window.Content)
				bar.Size = UDim2.new(1, 0, 0, 24)
				bar.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
				bar.BorderSizePixel = 0

				searchBox = Instance.new("TextBox", bar)
				searchBox.BackgroundTransparency = 1
				searchBox.PlaceholderText = "filtrar"
				searchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
				searchBox.Text = ""
				searchBox.TextColor3 = Color3.new(1, 1, 1)
				searchBox.Font = 3
				searchBox.TextSize = 13
				searchBox.TextXAlignment = 0
				searchBox.Size = UDim2.new(1, -8, 1, 0)
				searchBox.Position = UDim2.new(0, 4, 0, 0)

				treeFrame = Instance.new("Frame", window.Content)
				treeFrame.Position = UDim2.new(0, 0, 0, 24)
				treeFrame.Size = UDim2.new(1, 0, 1, -24)
				treeFrame.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
				treeFrame.BorderSizePixel = 0
				treeFrame.ClipsDescendants = true

				scrollV = Lib.ScrollBar.new()
				scrollV.Gui.Parent = window.Content
				scrollV.Gui.Position = UDim2.new(1, -12, 0, 24)
				scrollV.Gui.Size = UDim2.new(0, 12, 1, -24)
				scrollV:SetScrollFrame(treeFrame)
				scrollV.Scrolled:Connect(function() Explorer.Refresh() end)

				nodes[game] = { Obj = game }
				expanded[nodes[game]] = true
				for _, o in ipairs(game:GetDescendants()) do
					local p = o.Parent
					local par = p and nodes[p]
					if par then
						local nn = { Obj = o, Parent = par }
						nodes[o] = nn
						par[#par + 1] = nn
					end
				end
				game.DescendantAdded:Connect(function(o) pcall(addObj, o) end)
				game.DescendantRemoving:Connect(function(o) pcall(remObj, o) end)
				window.OnActivate:Connect(function() Explorer.ForceUpdate() end)

				coroutine.wrap(function()
					while true do
						if next(dirty) then
							for n in next, dirty do
								dirty[n] = nil
								if n.HasDel then
									local i = 1
									while i <= #n do
										if n[i].Del then table.remove(n, i) else i += 1 end
									end
									n.HasDel = false
								end
							end
							if window:IsVisible() then Explorer.Refresh() end
						end
						Lib.FastWait(0.3)
					end
				end)()
			end
			return Explorer
		end
		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	EmbeddedModules.Properties = function()
		local Main, Lib, Apps, Settings, API, RMD, env, service, plr
		local function initDeps(d)
			Main, Lib, Apps, Settings = d.Main, d.Lib, d.Apps, d.Settings
			API, RMD, env, service, plr = d.API, d.RMD, d.env, d.service, d.plr
		end
		local function initAfterMain() end
		local function main()
			local P = {}
			local window, frame, scrollV, rows = nil, nil, nil, {}
			local list = {}

			P.Build = function()
				local sel = Apps.Explorer.Selection.List
				table.clear(list)
				local found = {}
				for _, n in ipairs(sel) do
					local c = n.Obj.ClassName
					local ac = API.Classes[c]
					while ac do
						if not found[ac.Name] then
							found[ac.Name] = true
							for _, pr in ipairs(ac.Properties) do
								if not pr.Tags.Hidden then list[#list + 1] = { Obj = n.Obj, Prop = pr } end
							end
						end
						ac = ac.Superclass
					end
				end
				table.sort(list, function(a, b) return a.Prop.Name < b.Prop.Name end)
				P.Refresh()
			end

			P.Refresh = function()
				if not frame then return end
				local max = math.max(math.ceil(frame.AbsoluteSize.Y / 22), 0)
				for i = 1, max do
					local r = rows[i]
					if not r then
						r = P.Template:Clone()
						r.Parent = frame
						rows[i] = r
						r.MouseButton1Click:Connect(function()
							local it = list[i + P.Index]
							if not it then return end
							local box = Instance.new("TextBox", r)
							box.Size = UDim2.new(0.5, -4, 1, 0)
							box.Position = UDim2.new(0.5, 2, 0, 0)
							box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
							box.TextColor3 = Color3.new(1, 1, 1)
							box.Text = ""
							box.Font = 3
							box.TextSize = 13
							box:CaptureFocus()
							box.FocusLost:Connect(function()
								local v = tonumber(box.Text) or box.Text
								for _, n in ipairs(Apps.Explorer.Selection.List) do
									pcall(function() n.Obj[it.Prop.Name] = v end)
								end
								box:Destroy()
								P.Refresh()
							end)
						end)
					end
					local it = list[i + P.Index]
					if it then
						r.Visible = true
						r.NameL.Text = it.Prop.Name
						local ok, v = pcall(function() return it.Obj[it.Prop.Name] end)
						r.ValL.Text = ok and tostring(v) or ""
					else r.Visible = false end
				end
				for i = max + 1, #rows do rows[i]:Destroy() rows[i] = nil end
			end

			P.Init = function()
				window = Lib.Window.new()
				P.Window = window
				window:SetTitle("Propriedades")
				frame = Instance.new("Frame", window.Content)
				frame.Size = UDim2.new(1, 0, 1, 0)
				frame.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
				frame.BorderSizePixel = 0
				frame.ClipsDescendants = true
				scrollV = Lib.ScrollBar.new()
				scrollV.Gui.Parent = window.Content
				scrollV.Gui.Position = UDim2.new(1, -12, 0, 0)
				scrollV.Gui.Size = UDim2.new(0, 12, 1, 0)
				scrollV:SetScrollFrame(frame)
				scrollV.Scrolled:Connect(function() P.Refresh() end)
				P.Index = 0
				P.Template = create({
					{ 1, "TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", Size = UDim2.new(1, 0, 0, 22) } },
					{ 2, "TextLabel", { BackgroundTransparency = 1, Font = 3, Name = "NameL", Parent = { 1 }, Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(0.5, -10, 1, 0), Text = "", TextColor3 = Color3.fromRGB(170, 180, 195), TextSize = 13, TextXAlignment = 0, TextTruncate = 1 } },
					{ 3, "TextLabel", { BackgroundTransparency = 1, Font = 3, Name = "ValL", Parent = { 1 }, Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), Text = "", TextColor3 = Color3.fromRGB(225, 230, 240), TextSize = 13, TextXAlignment = 0, TextTruncate = 1 } },
				})
				Apps.Explorer.Selection.Changed:Connect(P.Build)
			end
			return P
		end
		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	EmbeddedModules.ScriptViewer = function()
		local Main, Lib, Apps, env
		local function initDeps(d)
			Main, Lib, Apps, env = d.Main, d.Lib, d.Apps, d.env
		end
		local function initAfterMain() end
		local function main()
			local SV = {}
			SV.ViewScript = function(s)
				local ok, src = pcall(env.decompile, s)
				if not ok or not src then src = "-- falha ao decompilar" end
				SV.Code:SetText(src)
				SV.Window:Show()
			end
			SV.Init = function()
				SV.Window = Lib.Window.new()
				SV.Window:SetTitle("Script Viewer")
				SV.Window:Resize(520, 420)
				SV.Code = Lib.CodeFrame.new()
				SV.Code.Frame.Parent = SV.Window.Content
			end
			return SV
		end
		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	EmbeddedModules.Console = function()
		local Main, Lib, Apps, env
		local function initDeps(d)
			Main, Lib, Apps, env = d.Main, d.Lib, d.Apps, d.env
		end
		local function initAfterMain() end
		local function main()
			local C = {}
			C.Init = function()
				C.Window = Lib.Window.new()
				C.Window:SetTitle("Console")
				C.Window:Resize(480, 340)
				local out = Instance.new("ScrollingFrame", C.Window.Content)
				out.Size = UDim2.new(1, 0, 1, -26)
				out.BackgroundTransparency = 1
				out.BorderSizePixel = 0
				out.AutomaticCanvasSize = Enum.AutomaticSize.Y
				out.ScrollBarThickness = 4
				local l = Instance.new("UIListLayout", out)
				l.SortOrder = Enum.SortOrder.LayoutOrder
				local inp = Instance.new("TextBox", C.Window.Content)
				inp.Size = UDim2.new(1, 0, 0, 22)
				inp.Position = UDim2.new(0, 0, 1, -22)
				inp.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
				inp.TextColor3 = Color3.new(1, 1, 1)
				inp.Font = Enum.Font.Code
				inp.TextSize = 12
				inp.PlaceholderText = "comando"
				inp.ClearTextOnFocus = false
				inp.TextXAlignment = 0
				local function add(t, c)
					local lb = Instance.new("TextLabel", out)
					lb.Size = UDim2.new(1, 0, 0, 0)
					lb.AutomaticSize = Enum.AutomaticSize.Y
					lb.BackgroundTransparency = 1
					lb.Font = Enum.Font.Code
					lb.TextSize = 12
					lb.TextWrapped = true
					lb.TextXAlignment = 0
					lb.TextColor3 = c
					lb.Text = t
				end
				game:GetService("LogService").MessageOut:Connect(function(m, t)
					add(m, t == Enum.MessageType.MessageError and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(200, 200, 200))
				end)
				inp.FocusLost:Connect(function(e)
					if e and inp.Text ~= "" then
						add("> " .. inp.Text, Color3.fromRGB(120, 190, 255))
						pcall(function() return loadstring(inp.Text)() end)
						inp.Text = ""
					end
				end)
			end
			return C
		end
		return { InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main }
	end

	local Main, Settings, Apps, env = {}, {}, {}, {}
	local API, RMD, Lib, Explorer, Properties, ScriptViewer, Console
	local plr = service.Players.LocalPlayer or service.Players.PlayerAdded:Wait()

	local function create(d)
		local i = {}
		for _, v in pairs(d) do i[v[1]] = Instance.new(v[2]) end
		for _, v in pairs(d) do
			for p, x in pairs(v[3]) do
				if type(x) == "table" then i[v[1]][p] = i[x[1]] else i[v[1]][p] = x end
			end
		end
		return i[1]
	end
	local function createSimple(c, p)
		local i = Instance.new(c)
		for k, v in next, p do i[k] = v end
		return i
	end

	Main.Apps = Apps
	Main.Mouse = plr:GetMouse()
	Main.DisplayOrders = { SideWindow = 8, Window = 10 }

	Main.GetInitDeps = function()
		return { Main = Main, Lib = Lib, Apps = Apps, Settings = Settings, API = API, RMD = RMD, env = env, service = service, plr = plr, create = create, createSimple = createSimple }
	end

	Main.InitEnv = function()
		env.readfile = missing("function", readfile)
		env.writefile = missing("function", writefile)
		env.getnilinstances = missing("function", getnilinstances or get_nil_instances)
		env.setclipboard = missing("function", setclipboard or toclipboard or set_clipboard)
		env.gethui = missing("function", gethui or get_hidden_gui)
		env.protectgui = missing("function", protect_gui)
		env.decompile = missing("function", decompile)
		env.isViableDecompileScript = function() return env.decompile ~= nil end
		Main.GuiHolder = service.CoreGui or plr:FindFirstChildWhichIsA("PlayerGui")
	end

	Main.FetchAPI = function()
		local raw
		local ok, r = pcall(function() return oldgame:HttpGet("http://setup.roblox.com/versionQTStudio") end)
		local ver = ok and r or "version-0"
		local ok2, r2 = pcall(function() return oldgame:HttpGet("http://setup.roblox.com/" .. ver .. "-API-Dump.json") end)
		if ok2 then raw = r2 end
		if not raw then
			local ok3, r3 = pcall(function() return oldgame:HttpGet("https://raw.githubusercontent.com/infyiff/backup/refs/heads/main/rbx_api.dat") end)
			if ok3 then raw = r3 end
		end
		if not raw then error("API dump indisponível") end
		local api = service.HttpService:JSONDecode(raw)
		local classes = {}
		for _, c in pairs(api.Classes) do
			local nc = { Name = c.Name, Superclass = c.Superclass, Properties = {} }
			for _, m in pairs(c.Members) do
				if m.MemberType == "Property" then
					local tags = {}
					if m.Tags then for _, t in pairs(m.Tags) do tags[t] = true end end
					nc.Properties[#nc.Properties + 1] = { Name = m.Name, Class = c.Name, ValueType = m.ValueType, Tags = tags }
				end
			end
			classes[c.Name] = nc
		end
		for _, c in pairs(classes) do c.Superclass = classes[c.Superclass] end
		return { Classes = classes, CategoryOrder = {} }
	end

	Main.Init = function()
		Main.InitEnv()
		Lib = EmbeddedModules.Lib()
		Lib.InitDeps(Main.GetInitDeps())
		Apps.Lib = Lib.Main()
		API = Main.FetchAPI()
		RMD = { Classes = {} }

		local deps = Main.GetInitDeps()
		for _, name in ipairs({ "Explorer", "Properties", "ScriptViewer", "Console" }) do
			local c = EmbeddedModules[name]()
			c.InitDeps(deps)
			Apps[name] = c.Main()
		end

		Lib.Window.Init()
		Apps.Explorer.Init()
		Apps.Properties.Init()
		Apps.ScriptViewer.Init()
		Apps.Console.Init()

		Apps.Explorer.Window:Show({ Align = "right", Pos = 1, Silent = true })
		Apps.Properties.Window:Show({ Align = "right", Pos = 2, Silent = true })
		Main.InitDone = true
	end

	return Main
end

local DEX
local function launchDex()
	if DEX then return DEX end
	DEX = buildDex()
	task.spawn(function()
		local ok, e = pcall(DEX.Init)
		if not ok then warn("[APEX] dex: " .. tostring(e)) end
	end)
	return DEX
end

--==================================================================================
--  UI — Liquid Glass refinada
--==================================================================================
local UI = {}
local gui, root, panel, scale, blur, launcher, statusLbl
local pages, tabBtns, indicator, opened = {}, {}, nil, false

local function tw(o, t, p, s, d)
	TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quint, d or Enum.EasingDirection.Out), p):Play()
end

local function card(parent, y, h)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, h)
	f.Position = UDim2.new(0, 0, 0, y)
	f.BackgroundColor3 = C_CARD
	f.BackgroundTransparency = 0.55
	f.BorderSizePixel = 0
	f.Parent = parent
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
	local s = Instance.new("UIStroke")
	s.Color = C_ICE
	s.Transparency = 0.88
	s.Thickness = 1
	s.Parent = f
	return f
end

local function btn(parent, text, size, pos, primary)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = primary and C_BLUE or Color3.fromRGB(26, 34, 56)
	b.BackgroundTransparency = primary and 0.05 or 0.35
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = C_TEXT
	b.Text = text
	b.AutoButtonColor = false
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	if primary then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(C_BLUE, C_RED)
		g.Rotation = 20
		g.Parent = b
	end
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(1, 1, 1)
	s.Transparency = primary and 0.55 or 0.88
	s.Thickness = 1
	s.Parent = b
	b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundTransparency = primary and 0 or 0.15 }) end)
	b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundTransparency = primary and 0.05 or 0.35 }) end)
	return b
end

local function toggleRow(parent, label, def, cb)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -24, 0, 30)
	row.Position = UDim2.new(0, 12, 0, 0)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -56, 1, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextSize = 12
	l.TextColor3 = C_MUTED
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 38, 0, 20)
	track.Position = UDim2.new(1, -38, 0.5, -10)
	track.BackgroundColor3 = Color3.fromRGB(34, 44, 68)
	track.BorderSizePixel = 0
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.BackgroundColor3 = Color3.fromRGB(226, 234, 248)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local state = def and true or false
	local function paint(anim)
		local pos = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
		local col = state and C_BLUE or Color3.fromRGB(34, 44, 68)
		if anim then
			tw(knob, 0.14, { Position = pos })
			tw(track, 0.14, { BackgroundColor3 = col })
		else
			knob.Position = pos
			track.BackgroundColor3 = col
		end
	end
	paint(false)

	local hit = Instance.new("TextButton", row)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.new(1, 0, 1, 0)
	hit.MouseButton1Click:Connect(function() state = not state paint(true) cb(state) end)

	return { Set = function(v) state = v paint(true) end }
end

local function sliderRow(parent, label, y, min, max, def, step, cb)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -24, 0, 34)
	row.Position = UDim2.new(0, 12, 0, y)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -60, 0, 14)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextSize = 11
	l.TextColor3 = C_MUTED
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = row

	local chip = Instance.new("Frame")
	chip.Size = UDim2.new(0, 54, 0, 16)
	chip.Position = UDim2.new(1, -54, 0, 0)
	chip.BackgroundColor3 = Color3.fromRGB(24, 32, 52)
	chip.BorderSizePixel = 0
	chip.Parent = row
	Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 5)

	local val = Instance.new("TextLabel", chip)
	val.Size = UDim2.new(1, 0, 1, 0)
	val.BackgroundTransparency = 1
	val.Font = Enum.Font.GothamBold
	val.TextSize = 11
	val.TextColor3 = C_ICE
	val.Text = tostring(def)

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 5)
	track.Position = UDim2.new(0, 0, 0, 21)
	track.BackgroundColor3 = Color3.fromRGB(28, 37, 58)
	track.BorderSizePixel = 0
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame", track)
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BorderSizePixel = 0
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new(C_BLUE, C_RED)
	fg.Parent = fill

	local knob = Instance.new("Frame", track)
	knob.Size = UDim2.new(0, 12, 0, 12)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	local ks = Instance.new("UIStroke", knob)
	ks.Color = C_BLUE
	ks.Thickness = 2

	local value = def
	local function paint()
		local a = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.new(a, -6, 0.5, -6)
		val.Text = tostring(value)
	end
	paint()

	local drag = false
	local function set(x)
		local w = track.AbsoluteSize.X
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(w, 1), 0, 1)
		local v = min + (max - min) * a
		if step then v = math.floor(v / step + 0.5) * step end
		value = math.clamp(v, min, max)
		paint()
		cb(value)
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag = true
			set(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then set(i.Position.X) end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
	end)
	return { Set = function(v) value = math.clamp(v, min, max) paint() cb(value) end }
end

function UI.Build()
	if not playerGui then return end

	gui = Instance.new("ScreenGui")
	gui.Name = "APEX"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 99999
	gui.Parent = playerGui

	blur = Instance.new("BlurEffect", Lighting)
	blur.Size = 0

	launcher = Instance.new("TextButton")
	launcher.Size = UDim2.new(0, 54, 0, 54)
	launcher.Position = UDim2.new(0.5, -27, 1, -92)
	launcher.BackgroundColor3 = C_DARK
	launcher.BackgroundTransparency = 0.12
	launcher.BorderSizePixel = 0
	launcher.Text = "A"
	launcher.Font = Enum.Font.GothamBlack
	launcher.TextSize = 20
	launcher.TextColor3 = C_TEXT
	launcher.AutoButtonColor = false
	launcher.Parent = gui
	Instance.new("UICorner", launcher).CornerRadius = UDim.new(1, 0)
	local lg = Instance.new("UIGradient")
	lg.Color = ColorSequence.new(C_BLUE, C_RED)
	lg.Rotation = 45
	lg.Parent = launcher
	local ls = Instance.new("UIStroke", launcher)
	ls.Color = C_ICE
	ls.Transparency = 0.6
	ls.Thickness = 1.4

	root = Instance.new("CanvasGroup")
	root.Size = UDim2.new(0, 420, 0, 540)
	root.Position = UDim2.new(0.5, -210, 0.5, -270)
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	root.Visible = false
	root.Parent = gui

	scale = Instance.new("UIScale", root)
	scale.Scale = 0.94

	local sh1 = Instance.new("Frame", root)
	sh1.Size = UDim2.new(1, 10, 1, 14)
	sh1.Position = UDim2.new(0, -5, 0, 8)
	sh1.BackgroundColor3 = Color3.new(0, 0, 0)
	sh1.BackgroundTransparency = 0.7
	sh1.BorderSizePixel = 0
	Instance.new("UICorner", sh1).CornerRadius = UDim.new(0, 26)

	panel = Instance.new("Frame")
	panel.Size = UDim2.new(1, 0, 1, 0)
	panel.BackgroundColor3 = C_DARK
	panel.BackgroundTransparency = 0.22
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = root
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 22)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 48, 132)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 28, 62)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(118, 24, 46)),
	})
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	grad.Rotation = 38
	grad.Parent = panel

	local stroke = Instance.new("UIStroke", panel)
	stroke.Color = Color3.fromRGB(200, 222, 255)
	stroke.Transparency = 0.74
	stroke.Thickness = 1.2

	local topHi = Instance.new("Frame", panel)
	topHi.Size = UDim2.new(1, -44, 0, 1)
	topHi.Position = UDim2.new(0, 22, 0, 1)
	topHi.BackgroundColor3 = Color3.new(1, 1, 1)
	topHi.BackgroundTransparency = 0.45
	topHi.BorderSizePixel = 0
	local thg = Instance.new("UIGradient", topHi)
	thg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})

	local botHi = Instance.new("Frame", panel)
	botHi.Size = UDim2.new(1, -60, 0, 1)
	botHi.Position = UDim2.new(0, 30, 1, -1)
	botHi.BackgroundColor3 = C_RED
	botHi.BackgroundTransparency = 0.6
	botHi.BorderSizePixel = 0
	local bhg = Instance.new("UIGradient", botHi)
	bhg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- header
	local header = Instance.new("Frame", panel)
	header.Size = UDim2.new(1, 0, 0, 62)
	header.BackgroundTransparency = 1

	local badge = Instance.new("Frame", header)
	badge.Size = UDim2.new(0, 32, 0, 32)
	badge.Position = UDim2.new(0, 18, 0, 15)
	badge.BackgroundColor3 = C_BLUE
	badge.BackgroundTransparency = 0.1
	badge.BorderSizePixel = 0
	Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 9)
	local bg2 = Instance.new("UIGradient", badge)
	bg2.Color = ColorSequence.new(C_BLUE, C_RED)
	bg2.Rotation = 40
	local btxt = Instance.new("TextLabel", badge)
	btxt.Size = UDim2.new(1, 0, 1, 0)
	btxt.BackgroundTransparency = 1
	btxt.Font = Enum.Font.GothamBlack
	btxt.TextSize = 16
	btxt.TextColor3 = Color3.new(1, 1, 1)
	btxt.Text = "A"

	local title = Instance.new("TextLabel", header)
	title.Position = UDim2.new(0, 58, 0, 14)
	title.Size = UDim2.new(1, -140, 0, 18)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 15
	title.TextXAlignment = 0
	title.TextColor3 = C_TEXT
	title.Text = "APEX SUITE"

	local sub = Instance.new("TextLabel", header)
	sub.Position = UDim2.new(0, 58, 0, 32)
	sub.Size = UDim2.new(1, -140, 0, 14)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 10
	sub.TextXAlignment = 0
	sub.TextColor3 = C_MUTED
	sub.Text = (IS_SERVER and "SERVER  •  replicação nativa" or "CLIENT  •  RightShift")

	local close = btn(header, "✕", UDim2.new(0, 26, 0, 26), UDim2.new(1, -38, 0, 18))
	local min = btn(header, "—", UDim2.new(0, 26, 0, 26), UDim2.new(1, -70, 0, 18))
	close.MouseButton1Click:Connect(function() UI.Close() end)
	min.MouseButton1Click:Connect(function()
		tw(root, 0.24, { Size = root.Size.Y.Offset < 200 and UDim2.new(0, 420, 0, 540) or UDim2.new(0, 420, 0, 62) })
	end)

	local hair = Instance.new("Frame", panel)
	hair.Size = UDim2.new(1, -36, 0, 1)
	hair.Position = UDim2.new(0, 18, 0, 61)
	hair.BorderSizePixel = 0
	hair.BackgroundColor3 = C_BLUE
	hair.BackgroundTransparency = 0.3
	local hg = Instance.new("UIGradient", hair)
	hg.Color = ColorSequence.new(C_BLUE, C_RED)
	hg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.9),
	})

	-- tabs
	local bar = Instance.new("Frame", panel)
	bar.Size = UDim2.new(1, -36, 0, 30)
	bar.Position = UDim2.new(0, 18, 0, 70)
	bar.BackgroundColor3 = Color3.fromRGB(14, 20, 38)
	bar.BackgroundTransparency = 0.4
	bar.BorderSizePixel = 0
	bar.Parent = panel
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 9)

	indicator = Instance.new("Frame", bar)
	indicator.Size = UDim2.new(0.3333, -4, 1, -6)
	indicator.Position = UDim2.new(0, 2, 0, 3)
	indicator.BackgroundColor3 = C_BLUE
	indicator.BackgroundTransparency = 0.02
	indicator.BorderSizePixel = 0
	Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 7)
	local ig2 = Instance.new("UIGradient", indicator)
	ig2.Color = ColorSequence.new(C_BLUE, C_RED)
	local ist = Instance.new("UIStroke", indicator)
	ist.Color = Color3.new(1, 1, 1)
	ist.Transparency = 0.6
	ist.Thickness = 1

	local labels = { "SUPER SHOT", "STUDS 3B", "DEX" }
	for i, n in ipairs(labels) do
		local b = Instance.new("TextButton", bar)
		b.Size = UDim2.new(0.3333, -4, 1, -6)
		b.Position = UDim2.new((i - 1) / 3, 2, 0, 3)
		b.BackgroundTransparency = 1
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.TextColor3 = i == 1 and C_TEXT or C_MUTED
		b.Text = n
		tabBtns[i] = b
		b.MouseButton1Click:Connect(function()
			for k, p in ipairs(pages) do p.Visible = k == i end
			for k, t in ipairs(tabBtns) do tw(t, 0.14, { TextColor3 = k == i and C_TEXT or C_MUTED }) end
			tw(indicator, 0.2, { Position = UDim2.new((i - 1) / 3, 2, 0, 3) })
		end)
	end

	local function page(i)
		local p = Instance.new("Frame", panel)
		p.Size = UDim2.new(1, -36, 1, -150)
		p.Position = UDim2.new(0, 18, 0, 108)
		p.BackgroundTransparency = 1
		p.Visible = i == 1
		pages[i] = p
		return p
	end

	-- página 1
	local p1 = page(1)
	local c1 = card(p1, 0, 34)
	toggleRow(c1, "Direção da câmera", true, function(v) SS.USE_CAMERA = v end)
	sliderRow(p1, "FORÇA DO CHUTE", 42, 100, 2000, 500, 25, function(v) SS.SPEED = v end)
	sliderRow(p1, "ALCANCE DA BOLA", 80, 8, 80, 20, 1, function(v) SS.RANGE = v end)
	sliderRow(p1, "TEMPO DE CONTATO", 118, 5, 60, 30, 1, function(v) SS.HIT_TIME = v / 100 end)

	local shoot = btn(p1, "EXECUTAR SUPER SHOT", UDim2.new(1, 0, 0, 46), UDim2.new(0, 0, 0, 160), true)
	shoot.Font = Enum.Font.GothamBlack
	shoot.TextSize = 13
	shoot.MouseButton1Click:Connect(function() SS:Shoot() end)

	local note1 = Instance.new("TextLabel", p1)
	note1.Size = UDim2.new(1, 0, 0, 34)
	note1.Position = UDim2.new(0, 0, 0, 212)
	note1.BackgroundTransparency = 1
	note1.Font = Enum.Font.Gotham
	note1.TextSize = 10
	note1.TextWrapped = true
	note1.TextXAlignment = 0
	note1.TextYAlignment = 0
	note1.TextColor3 = C_MUTED
	note1.Text = "Aproxime-se de uma parte \"Ball\". Direção reta, no plano horizontal.  Network owner forçado para replicar."

	-- página 2
	local p2 = page(2)
	sliderRow(p2, "TAMANHO DA PEÇA", 0, 4, 20, 8, 1, function(v) Studs.Size = v end)
	sliderRow(p2, "PEÇAS / FRAME", 38, 100, 4000, 900, 100, function(v) Studs.Batch = v end)

	local presetRow = Instance.new("Frame", p2)
	presetRow.Size = UDim2.new(1, 0, 0, 26)
	presetRow.Position = UDim2.new(0, 0, 0, 80)
	presetRow.BackgroundTransparency = 1
	local pll = Instance.new("UIListLayout", presetRow)
	pll.FillDirection = Enum.FillDirection.Horizontal
	pll.Padding = UDim.new(0, 5)
	for i, n in ipairs({ "100K", "1M", "10M", "3B" }) do
		local b = btn(presetRow, n, UDim2.new(0.25, -4, 1, 0), UDim2.new((i - 1) / 4, 0, 0, 0))
		b.TextSize = 11
		b.MouseButton1Click:Connect(function()
			Studs.Target = ({ 1e5, 1e6, 1e7, 3e9 })[i]
			UI.Status("alvo: " .. fmt(Studs.Target))
		end)
	end

	local repCard = card(p2, 114, 62)
	local repTitle = Instance.new("TextLabel", repCard)
	repTitle.Position = UDim2.new(0, 12, 0, 6)
	repTitle.Size = UDim2.new(1, -24, 0, 14)
	repTitle.BackgroundTransparency = 1
	repTitle.Font = Enum.Font.GothamBold
	repTitle.TextSize = 10
	repTitle.TextColor3 = C_ICE
	repTitle.TextXAlignment = 0
	repTitle.Text = "PONTE SERVER-SIDE"
	local repInfo = Instance.new("TextLabel", repCard)
	repInfo.Position = UDim2.new(0, 12, 0, 22)
	repInfo.Size = UDim2.new(1, -110, 0, 30)
	repInfo.BackgroundTransparency = 1
	repInfo.Font = Enum.Font.Gotham
	repInfo.TextSize = 10
	repInfo.TextWrapped = true
	repInfo.TextXAlignment = 0
	repInfo.TextYAlignment = 0
	repInfo.TextColor3 = C_MUTED
	repInfo.Text = "Varre remotes e injeta o gerador no servidor."
	local inject = btn(repCard, "INJETAR", UDim2.new(0, 84, 0, 24), UDim2.new(1, -96, 0, 8))
	inject.TextSize = 11
	inject.MouseButton1Click:Connect(function()
		local n = Studs:Inject(SS_SOURCE)
		repInfo.Text = n > 0 and ("disparado em " .. n .. " remote(s)") or "nenhum remote candidato."
	end)

	local startB = btn(p2, "INICIAR LOCAL", UDim2.new(0.5, -3, 0, 40), UDim2.new(0, 0, 0, 186), true)
	local stopB = btn(p2, "PARAR", UDim2.new(0.5, -3, 0, 40), UDim2.new(0.5, 3, 0, 186))
	startB.Font = Enum.Font.GothamBlack
	stopB.Font = Enum.Font.GothamBlack
	local cleanB = btn(p2, "LIMPAR FOLDER", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 232))

	local statL = Instance.new("TextLabel", p2)
	statL.Size = UDim2.new(1, 0, 0, 60)
	statL.Position = UDim2.new(0, 0, 0, 266)
	statL.BackgroundTransparency = 1
	statL.Font = Enum.Font.Code
	statL.TextSize = 11
	statL.TextWrapped = true
	statL.TextXAlignment = 0
	statL.TextYAlignment = 0
	statL.TextColor3 = C_ICE
	statL.Text = "—"

	startB.MouseButton1Click:Connect(function()
		if Studs.Running then return end
		Studs:Start()
		if not IS_SERVER then Studs:Inject(SS_SOURCE) end
	end)
	stopB.MouseButton1Click:Connect(function() Studs:Stop() end)
	cleanB.MouseButton1Click:Connect(function() Studs:Cleanup() statL.Text = "—" end)

	task.spawn(function()
		local last = 0
		while true do
			task.wait(0.3)
			if Studs.Running then
				local rate = (Studs.Count - last) / 0.3
				last = Studs.Count
				local rem = math.max(0, Studs.Target - Studs.Count)
				statL.Text = ("local: %s / %s\n%s/s  •  eta %s")
					:format(fmt(Studs.Count), fmt(Studs.Target), fmt(rate), rate > 1 and fmtTime(rem / rate) or "--")
			end
		end
	end)

	-- página 3
	local p3 = page(3)
	local dexCard = card(p3, 0, 92)
	local dexT = Instance.new("TextLabel", dexCard)
	dexT.Position = UDim2.new(0, 12, 0, 8)
	dexT.Size = UDim2.new(1, -24, 0, 14)
	dexT.BackgroundTransparency = 1
	dexT.Font = Enum.Font.GothamBold
	dexT.TextSize = 10
	dexT.TextColor3 = C_ICE
	dexT.TextXAlignment = 0
	dexT.Text = "DEX — DEBUG SUITE"

	local dexS = Instance.new("TextLabel", dexCard)
	dexS.Position = UDim2.new(0, 12, 0, 24)
	dexS.Size = UDim2.new(1, -24, 0, 14)
	dexS.BackgroundTransparency = 1
	dexS.Font = Enum.Font.Gotham
	dexS.TextSize = 10
	dexS.TextColor3 = C_MUTED
	dexS.TextXAlignment = 0
	dexS.Text = "não iniciado"

	local dexB = btn(dexCard, "INICIAR", UDim2.new(1, -24, 0, 26), UDim2.new(0, 12, 0, 46), true)
	dexB.TextSize = 11
	dexB.MouseButton1Click:Connect(function()
		dexS.Text = "carregando..."
		local d = launchDex()
		task.spawn(function()
			for _ = 1, 160 do
				if d.InitDone then break end
				task.wait(0.25)
			end
			dexS.Text = d.InitDone and "ativo" or "falhou"
			dexB.Visible = false
		end)
	end)

	local grid = Instance.new("Frame", p3)
	grid.Size = UDim2.new(1, 0, 0, 100)
	grid.Position = UDim2.new(0, 0, 0, 102)
	grid.BackgroundTransparency = 1
	local gl = Instance.new("UIGridLayout", grid)
	gl.CellSize = UDim2.new(0.5, -3, 0, 30)
	gl.CellPadding = UDim2.new(0, 6, 0, 6)

	for _, pair in ipairs({ { "Explorer", "Explorer" }, { "Propriedades", "Properties" }, { "Script Viewer", "ScriptViewer" }, { "Console", "Console" } }) do
		local b = btn(grid, pair[1], UDim2.new(0, 100, 0, 30), UDim2.new())
		b.TextSize = 11
		b.MouseButton1Click:Connect(function()
			if not DEX or not DEX.InitDone then dexS.Text = "inicie primeiro" return end
			local a = DEX.Apps[pair[2]]
			if a and a.Window then a.Window:Show() end
		end)
	end

	-- rodapé
	local foot = Instance.new("Frame", panel)
	foot.Size = UDim2.new(1, -36, 0, 22)
	foot.Position = UDim2.new(0, 18, 1, -32)
	foot.BackgroundTransparency = 1

	statusLbl = Instance.new("TextLabel", foot)
	statusLbl.Size = UDim2.new(1, -110, 1, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 10
	statusLbl.TextXAlignment = 0
	statusLbl.TextColor3 = C_MUTED
	statusLbl.Text = "pronto"

	local chip = Instance.new("TextLabel", foot)
	chip.Size = UDim2.new(0, 100, 0, 16)
	chip.Position = UDim2.new(1, -100, 0.5, -8)
	chip.BackgroundColor3 = IS_SERVER and C_BLUE or Color3.fromRGB(30, 40, 62)
	chip.BackgroundTransparency = 0.4
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = 9
	chip.TextColor3 = C_ICE
	chip.Text = IS_SERVER and "SERVER-SIDE" or "CLIENT"
	Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 5)

	UI.Status = function(t) statusLbl.Text = t end

	local drag, off = false, Vector2.new()
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag = true
			off = Vector2.new(i.Position.X - root.AbsolutePosition.X, i.Position.Y - root.AbsolutePosition.Y)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			root.Position = UDim2.new(0, i.Position.X - off.X, 0, i.Position.Y - off.Y)
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
	tw(root, 0.26, { GroupTransparency = 0 })
	tw(scale, 0.26, { Scale = 1 }, Enum.EasingStyle.Back)
	tw(blur, 0.26, { Size = 18 })
	tw(launcher, 0.2, { BackgroundTransparency = 0.6 })
end

function UI.Close()
	if not root then return end
	opened = false
	tw(root, 0.18, { GroupTransparency = 1 })
	tw(scale, 0.18, { Scale = 0.94 })
	tw(blur, 0.18, { Size = 0 })
	tw(launcher, 0.2, { BackgroundTransparency = 0.12 })
	task.delay(0.2, function() if not opened then root.Visible = false end end)
end

_G.Apex = {
	fireShot = function() SS:Shoot() end,
	startStuds = function(t) if t then Studs.Target = t end Studs:Start() if not IS_SERVER then Studs:Inject(SS_SOURCE) end end,
	stopStuds = function() Studs:Stop() end,
	cleanStuds = function() Studs:Cleanup() end,
	injectStuds = function() return Studs:Inject(SS_SOURCE) end,
	scanRemotes = function() return Studs:ScanRemotes() end,
	modules = { SS = SS, Studs = Studs },
}

if not IS_SERVER then
	UI.Build()
else
	warn("[APEX] contexto server-side: UI off, use _G.Apex.")
end

print("[APEX] carregado — " .. (IS_SERVER and "servidor (replicação nativa)" or "cliente (ponte SS disponível)"))
