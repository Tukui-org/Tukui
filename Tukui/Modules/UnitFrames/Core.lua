local T, C, L = select(2, ...):unpack()
local AddOn, Plugin = ...
local oUF = Plugin.oUF or oUF
local Panels = T["Panels"]
local Noop = function() end
local TukuiUnitFrames = CreateFrame("Frame")

-- Lib globals
local strfind = strfind
local format = format
local floor = floor

-- WoW globals (I don't really wanna import all the funcs we use here, so localize the ones called a LOT, like in Health/Power functions)
local UnitIsEnemy = UnitIsEnemy
local UnitIsPlayer = UnitIsPlayer
local UnitIsFriend = UnitIsFriend
local UnitIsConnected = UnitIsConnected
local UnitPlayerControlled = UnitPlayerControlled
local UnitIsGhost = UnitIsGhost
local UnitIsDead = UnitIsDead
local UnitPowerType = UnitPowerType

TukuiUnitFrames.Units = {}
TukuiUnitFrames.Headers = {}
TukuiUnitFrames.Framework = TukuiUnitFrameFramework
TukuiUnitFrames.HighlightBorder = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	insets = {top = -2, left = -2, bottom = -2, right = -2}
}

TukuiUnitFrames.AddClassFeatures = {}

TukuiUnitFrames.RaidBuffsTrackingPosition = {
	TOPLEFT = {6, 1},
	TOPRIGHT = {-6, 1},
	BOTTOMLEFT = {6, 1},
	BOTTOMRIGHT = {-6, 1},
	LEFT = {6, 1},
	RIGHT = {-6, 1},
	TOP = {0, 0},
	BOTTOM = {0, 0},
}

function TukuiUnitFrames:DisableBlizzard()
	if not C.UnitFrames.Enable then
		return
	end
	
	for i = 1, MAX_BOSS_FRAMES do
		local Boss = _G["Boss"..i.."TargetFrame"]
		local Health = _G["Boss"..i.."TargetFrame".."HealthBar"]
		local Power = _G["Boss"..i.."TargetFrame".."ManaBar"]

		Boss:UnregisterAllEvents()
		Boss.Show = Noop
		Boss:Hide()

		Health:UnregisterAllEvents()
		Power:UnregisterAllEvents()
	end

	if C["Raid"].Enable then
		InterfaceOptionsFrameCategoriesButton10:SetHeight(0.00001)
		InterfaceOptionsFrameCategoriesButton10:SetAlpha(0)

		if CompactRaidFrameManager then
			CompactRaidFrameManager:SetParent(Panels.Hider)
		end

		if CompactUnitFrameProfiles then
			CompactUnitFrameProfiles:UnregisterAllEvents()
		end

		for i = 1, MAX_PARTY_MEMBERS do
			local PartyMember = _G["PartyMemberFrame" .. i]
			local Health = _G["PartyMemberFrame" .. i .. "HealthBar"]
			local Power = _G["PartyMemberFrame" .. i .. "ManaBar"]
			local Pet = _G["PartyMemberFrame" .. i .."PetFrame"]
			local PetHealth = _G["PartyMemberFrame" .. i .."PetFrame" .. "HealthBar"]

			PartyMember:UnregisterAllEvents()
			PartyMember:SetParent(Panels.Hider)
			PartyMember:Hide()
			Health:UnregisterAllEvents()
			Power:UnregisterAllEvents()

			Pet:UnregisterAllEvents()
			Pet:SetParent(Panels.Hider)
			PetHealth:UnregisterAllEvents()

			HidePartyFrame()
			ShowPartyFrame = Noop
			HidePartyFrame = Noop
		end
	end
end

function TukuiUnitFrames:ShortValue()
	if self <= 999 then
		return self
	end

	local Value

	if self >= 1000000 then
		Value = format("%.1fm", self / 1000000)
		return Value
	elseif self >= 1000 then
		Value = format("%.1fk", self / 1000)
		return Value
	end
end

function TukuiUnitFrames:UTF8Sub(i, dots)
	if not self then return end

	local Bytes = self:len()
	if (Bytes <= i) then
		return self
	else
		local Len, Pos = 0, 1
		while(Pos <= Bytes) do
			Len = Len + 1
			local c = self:byte(Pos)
			if (c > 0 and c <= 127) then
				Pos = Pos + 1
			elseif (c >= 192 and c <= 223) then
				Pos = Pos + 2
			elseif (c >= 224 and c <= 239) then
				Pos = Pos + 3
			elseif (c >= 240 and c <= 247) then
				Pos = Pos + 4
			end
			if (Len == i) then break end
		end

		if (Len == i and Pos <= Bytes) then
			return self:sub(1, Pos - 1)..(dots and "..." or "")
		else
			return self
		end
	end
end

function TukuiUnitFrames:MouseOnPlayer()
	local Status = self.Status
	local MouseOver = GetMouseFocus()

	if (MouseOver == self) then
		Status:Show()

		if (UnitIsPVP("player")) then
			Status:SetText("PVP")
		end
	else
		Status:Hide()
		Status:SetText()
	end
end

function TukuiUnitFrames:Highlight()
	if UnitIsUnit("focus", self.unit) then
		if C.General.HideShadows then
			self.Shadow:SetBackdrop( {edgeFile = C.Medias.Glow, edgeSize = T.Scale(4) })
		end
		
		self.Shadow:SetBackdropBorderColor(0, 1, 0, 1)
	elseif UnitIsUnit("target", self.unit) then
		if C.General.HideShadows then
			self.Shadow:SetBackdrop( {edgeFile = C.Medias.Glow, edgeSize = T.Scale(4) })
		end
		
		self.Shadow:SetBackdropBorderColor(1, 1, 0, 1)
	else
		if C.General.HideShadows then
			self.Shadow:SetBackdrop( {edgeFile = nil, edgeSize = 0 })
		end
		
		self.Shadow:SetBackdropBorderColor(0, 0, 0, 1)
	end
end

function TukuiUnitFrames:HighlightPlate()
	local Shadow = self.Shadow
	
	if Shadow then
		if UnitIsUnit("target", self.unit) then
			if not Shadow:IsShown() then
				Shadow:Show()
			end
			
			Shadow:SetBackdropBorderColor(1, 1, 0, 0.8)
		else
			if C.General.HideShadows then
				Shadow:Hide()
			else
				Shadow:SetBackdropBorderColor(0, 0, 0, 0.8)
			end
		end
	end
end

function TukuiUnitFrames:UpdateShadow(height)
	local Frame = self:GetParent()
	local Shadow = Frame.Shadow

	if not Shadow then
		return
	end

	Shadow:Point("TOPLEFT", -4, height)
end

function TukuiUnitFrames:UpdateBuffsHeaderPosition(height)
	local Frame = self:GetParent()
	local Buffs = Frame.Buffs

	if not Buffs then
		return
	end

	Buffs:ClearAllPoints()
	Buffs:Point("BOTTOMLEFT", Frame, "TOPLEFT", 0, height)
end

function TukuiUnitFrames:UpdateDebuffsHeaderPosition()
	local NumBuffs = self.visibleBuffs
	local PerRow = self.numRow
	local Size = self.size
	local Row = math.ceil((NumBuffs / PerRow))
	local Parent = self:GetParent()
	local Debuffs = Parent.Debuffs
	local Y = Size * Row
	local Addition = Size

	if NumBuffs == 0 then
		Addition = 0
	end

	Debuffs:ClearAllPoints()
	Debuffs:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", -2, Y + Addition)
end

function TukuiUnitFrames:CustomCastTimeText(duration)
	local Value = format("%.1f / %.1f", self.channeling and duration or self.max - duration, self.max)

	self.Time:SetText(Value)
end

function TukuiUnitFrames:CustomCastDelayText(duration)
	local Value = format("%.1f |cffaf5050%s %.1f|r", self.channeling and duration or self.max - duration, self.channeling and "- " or "+", self.delay)

	self.Time:SetText(Value)
end

function TukuiUnitFrames:CheckInterrupt(unit)
	if (unit == "vehicle") then
		unit = "player"
	end
	
	local Frame = self:GetParent()
	local Power = Frame.Power

	if (self.notInterruptible and UnitCanAttack("player", unit)) then
		self:SetStatusBarColor(0.87, 0.37, 0.37, 0.7)
	else
		self:SetStatusBarColor(0.29, 0.67, 0.30, 0.7)
	end
end

function TukuiUnitFrames:CheckCast(unit, name, rank, castid)
	TukuiUnitFrames.CheckInterrupt(self, unit)
end

function TukuiUnitFrames:CheckChannel(unit, name, rank)
	TukuiUnitFrames.CheckInterrupt(self, unit)
end

function TukuiUnitFrames:UpdateNamePosition()
	if (self.Power.Value:GetText() and UnitIsEnemy("player", "target")) then
		self.Name:ClearAllPoints()
		self.Name:SetPoint("CENTER", self.Panel, "CENTER", 0, 0)
	else
		self.Name:ClearAllPoints()
		self.Power.Value:SetAlpha(0)
		self.Name:SetPoint("LEFT", self.Panel, "LEFT", 4, 0)
	end
end

function TukuiUnitFrames:UpdateThreat(event, unit)
	if (not C.UnitFrames.Threat) or (unit ~= self.unit) then
		return
	end

	local Panel = self.Panel

	if Panel then
		local Status = UnitThreatSituation(unit)

		if Status and Status > 0 then
			Panel:SetBackdropBorderColor(1, 0, 0)
		else
			Panel:SetBackdropBorderColor(C["General"].BorderColor[1] * 0.7, C["General"].BorderColor[2] * 0.7, C["General"].BorderColor[3] * 0.7)
		end
	end
end

function TukuiUnitFrames:PreUpdateHealth(unit)
	local DarkTheme = C["UnitFrames"].DarkTheme
	local HostileColor = C["UnitFrames"].TargetEnemyHostileColor

	if (DarkTheme == true) or (HostileColor ~= true) then
		return
	end

	local Parent = self:GetParent()

	if UnitIsEnemy(unit, "player") then
		self.colorClass = false
	else
		self.colorClass = true
	end
end

function TukuiUnitFrames:PostUpdateHealth(unit, min, max)
	if (not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit)) then
		if (not UnitIsConnected(unit)) then
			self.Value:SetText("|cffD7BEA5"..FRIENDS_LIST_OFFLINE.."|r")
		elseif (UnitIsDead(unit)) then
			self.Value:SetText("|cffD7BEA5"..DEAD.."|r")
		elseif (UnitIsGhost(unit)) then
			self.Value:SetText("|cffD7BEA5"..L.UnitFrames.Ghost.."|r")
		end
	else
		local r, g, b
		local IsRaid = string.match(self:GetParent():GetName(), "Button") or false

		if (min ~= max) then
			r, g, b = T.ColorGradient(min, max, 0.69, 0.31, 0.31, 0.65, 0.63, 0.35, 0.33, 0.59, 0.33)
			if (unit == "player" and self:GetAttribute("normalUnit") ~= "pet") then
				if (IsRaid) then
					self.Value:SetText("|cffff2222-"..TukuiUnitFrames.ShortValue(max-min).."|r")
				else
					self.Value:SetFormattedText("|cffAF5050%d|r |cffD7BEA5-|r |cff%02x%02x%02x%d%%|r", min, r * 255, g * 255, b * 255, floor(min / max * 100))
				end
			elseif (unit == "target" or (unit and strfind(unit, "boss%d"))) then
				self.Value:SetFormattedText("|cffAF5050%s|r |cffD7BEA5-|r |cff%02x%02x%02x%d%%|r", TukuiUnitFrames.ShortValue(min), r * 255, g * 255, b * 255, floor(min / max * 100))
			elseif (unit and strfind(unit, "arena%d")) or (unit == "focus") or (unit == "focustarget") then
				self.Value:SetText("|cff559655"..TukuiUnitFrames.ShortValue(min).."|r")
			else
				self.Value:SetText("|cffff2222-"..TukuiUnitFrames.ShortValue(max-min).."|r")
			end
		else
			if (unit == "player" and self:GetAttribute("normalUnit") ~= "pet") then
				if (IsRaid) then
					self.Value:SetText(" ")
				else
					self.Value:SetText("|cff559655"..max.."|r")
				end
			elseif (unit == "target" or unit == "focus"  or unit == "focustarget" or (unit and strfind(unit, "arena%d")) or (unit and strfind(unit, "boss%d"))) then
				self.Value:SetText("|cff559655"..TukuiUnitFrames.ShortValue(max).."|r")
			else
				self.Value:SetText(" ")
			end
		end
	end
end

function TukuiUnitFrames:PostUpdatePower(unit, current, min, max)
	local Parent = self:GetParent()
	local pType, pToken = UnitPowerType(unit)
	local Colors = T["Colors"]
	local Color = Colors.power[pToken]

	if Color then
		self.Value:SetTextColor(Color[1], Color[2], Color[3])
	end

	if (not UnitIsPlayer(unit) and not UnitPlayerControlled(unit) or not UnitIsConnected(unit)) then
		self.Value:SetText()
	elseif (UnitIsDead(unit) or UnitIsGhost(unit)) then
		self.Value:SetText()
	else
		if (current ~= max) then
			if (pType == 0) then
				if (unit == "target" or (unit and strfind(unit, "boss%d"))) then
					self.Value:SetFormattedText("%d%% |cffD7BEA5-|r %s", floor(current / max * 100), TukuiUnitFrames.ShortValue(max - (max - current)))
				elseif (unit == "player" and Parent:GetAttribute("normalUnit") == "pet" or unit == "pet") then
					self.Value:SetFormattedText("%d%%", floor(current / max * 100))
				elseif (unit and strfind(unit, "arena%d")) or unit == "focus" or unit == "focustarget" then
					self.Value:SetText(TukuiUnitFrames.ShortValue(current))
				else
					self.Value:SetFormattedText("%d%% |cffD7BEA5-|r %d", floor(current / max * 100), max - (max - current))
				end
			else
				self.Value:SetText(max - (max - current))
			end
		else
			if (unit == "pet" or unit == "target" or unit == "focus" or unit == "focustarget" or (unit and strfind(unit, "arena%d")) or (unit and strfind(unit, "boss%d"))) then
				self.Value:SetText(TukuiUnitFrames.ShortValue(current))
			else
				self.Value:SetText(current)
			end
		end
	end

	if (Parent.Name and unit == "target") then
		TukuiUnitFrames.UpdateNamePosition(Parent)
	end
end

function TukuiUnitFrames:UpdateTotemTimer(elapsed)
	self.TimeLeft = self.TimeLeft - elapsed

	if self.TimeLeft > 0 then
		self:SetValue(self.TimeLeft)
	else
		self:SetValue(0)
		self:SetScript("OnUpdate", nil)
	end
end

local function hasbit(x, p)
	return x % (p + p) >= p
end

local function setbit(x, p)
	return hasbit(x, p) and x or x + p
end

local function clearbit(x, p)
	return hasbit(x, p) and x - p or x
end

function TukuiUnitFrames:UpdateTotemOverride(event, slot)
	if slot > 4 then
		return
	end

	local Bar = self.Totems
	local Priorities = Bar.__map

	if Bar.PreUpdate then Bar:PreUpdate(slot) end

	local Totem = Bar[slot]
	local HaveTotem, Name, Start, Duration, Icon = GetTotemInfo(slot)
	local SpellID = select(7, GetSpellInfo(Name))

	local Colors = T["Colors"]

	local R, G, B = unpack(Colors.totems[slot])
	local A = 0.6

	if (HaveTotem) then
		Totem:SetAlpha(1)
		Totem.TimeLeft = (Start + Duration) - GetTime()
		Totem:SetMinMaxValues(0, Duration)
		Totem:SetScript("OnUpdate", TukuiUnitFrames.UpdateTotemTimer)
		Totem:SetStatusBarColor(R, G, B, A)

		if Totem.Icon then
			Totem.Icon:SetTexture(Icon)
			Totem.Icon:SetDesaturated(true)
		end

		Bar.activeTotems = setbit(Bar.activeTotems, 2 ^ (slot - 1))
	else
		Totem:SetAlpha(0)
		Totem:SetValue(0)
		Totem:SetScript("OnUpdate", nil)

		if Totem.Icon then
			Totem.Icon:SetTexture(nil)
		end

		Bar.activeTotems = clearbit(Bar.activeTotems, 2 ^ (slot - 1))
	end

	if Bar.PostUpdate then
		return Bar:PostUpdate(slot, HaveTotem, Name, Start, Duration, Icon)
	end
end

function TukuiUnitFrames:CreateAuraTimer(elapsed)
	if (self.TimeLeft) then
		self.Elapsed = (self.Elapsed or 0) + elapsed

		if self.Elapsed >= 0.1 then
			if not self.First then
				self.TimeLeft = self.TimeLeft - self.Elapsed
			else
				self.TimeLeft = self.TimeLeft - GetTime()
				self.First = false
			end

			if self.TimeLeft > 0 then
				local Time = T.FormatTime(self.TimeLeft)
				self.Remaining:SetText(Time)

				if self.TimeLeft <= 5 then
					self.Remaining:SetTextColor(0.99, 0.31, 0.31)
				else
					self.Remaining:SetTextColor(1, 1, 1)
				end
			else
				self.Remaining:Hide()
				self:SetScript("OnUpdate", nil)
			end

			self.Elapsed = 0
		end
	end
end

function TukuiUnitFrames:CancelPlayerBuff(index)
	if InCombatLockdown() then
		return
	end
	
	CancelUnitBuff("player", self.index)
end

function TukuiUnitFrames:PostCreateAura(button)
	-- Set "self.Buffs.isCancellable" to true to a buffs frame to be able to cancel click
	local isCancellable = button:GetParent().isCancellable
	
	-- Right-click-cancel script
	if isCancellable then
		-- Add a button.index to allow CancelUnitAura to work with player
		local Name = button:GetName()
		local Index = tonumber(Name:gsub('%D',''))

		button.index = Index
		button:SetScript("OnMouseUp", TukuiUnitFrames.CancelPlayerBuff)
	end
	
	-- Skin aura button
	if button:GetName():match("NamePlate") then
		button:SetTemplate("Default")
		button:CreateShadow()
		button:CreateShadow()
		button.cd:SetReverse(true)
		button.icon:SetInside()
		button.icon:SetTexCoord(unpack(T.IconCoord))
		button.icon:SetDrawLayer("ARTWORK")
		button.count:SetFont(C.Medias.Font, 8, "THICKOUTLINE")
	else
		button:SetTemplate("Default")
		button:CreateShadow()

		button.Remaining = button:CreateFontString(nil, "OVERLAY")
		button.Remaining:SetFont(C.Medias.Font, 12, "THINOUTLINE")
		button.Remaining:Point("CENTER", 1, 0)

		button.cd.noOCC = true
		button.cd.noCooldownCount = true
		button.cd:SetReverse(true)
		button.cd:SetFrameLevel(button:GetFrameLevel() + 1)
		button.cd:ClearAllPoints()
		button.cd:SetInside()
		button.cd:SetHideCountdownNumbers(true)

		button.icon:SetInside()
		button.icon:SetTexCoord(unpack(T.IconCoord))
		button.icon:SetDrawLayer("ARTWORK")

		button.count:Point("BOTTOMRIGHT", 3, 3)
		button.count:SetJustifyH("RIGHT")
		button.count:SetFont(C.Medias.Font, 9, "THICKOUTLINE")
		button.count:SetTextColor(0.84, 0.75, 0.65)

		button.OverlayFrame = CreateFrame("Frame", nil, button, nil)
		button.OverlayFrame:SetFrameLevel(button.cd:GetFrameLevel() + 1)
		button.overlay:SetParent(button.OverlayFrame)
		button.count:SetParent(button.OverlayFrame)
		button.Remaining:SetParent(button.OverlayFrame)

		button.Animation = button:CreateAnimationGroup()
		button.Animation:SetLooping("BOUNCE")

		button.Animation.FadeOut = button.Animation:CreateAnimation("Alpha")
		button.Animation.FadeOut:SetFromAlpha(1)
		button.Animation.FadeOut:SetToAlpha(0)
		button.Animation.FadeOut:SetDuration(.6)
		button.Animation.FadeOut:SetSmoothing("IN_OUT")
	end
end

function TukuiUnitFrames:PostUpdateAura(unit, button, index, offset, filter, isDebuff, duration, timeLeft)
	local _, _, _, DType, Duration, ExpirationTime, UnitCaster, IsStealable = UnitAura(unit, index, button.filter)

	if button then
		if(button.filter == "HARMFUL") then
			if(not UnitIsFriend("player", unit) and not button.isPlayer) then
				button.icon:SetDesaturated(true)
				button:SetBackdropBorderColor(unpack(C["General"].BorderColor))
			else
				local color = DebuffTypeColor[DType] or DebuffTypeColor.none
				button.icon:SetDesaturated(false)
				button:SetBackdropBorderColor(color.r * 0.8, color.g * 0.8, color.b * 0.8)					
			end
		else
			if button.Animation then
				if (IsStealable or DType == "Magic") and not UnitIsFriend("player", unit) and not button.Animation.Playing then
					button.Animation:Play()
					button.Animation.Playing = true
				else
					button.Animation:Stop()
					button.Animation.Playing = false
				end
			end
		end
		
		if button.Remaining then
			if Duration and Duration > 0 then
				button.Remaining:Show()
			else
				button.Remaining:Hide()
			end
			
			button:SetScript("OnUpdate", TukuiUnitFrames.CreateAuraTimer)
		end

		button.Duration = Duration
		button.TimeLeft = ExpirationTime
		button.First = true
	end
end

function TukuiUnitFrames:SetGridGroupRole()
	local LFDRole = self.GroupRoleIndicator
	local Role = UnitGroupRolesAssigned(self.unit)

	if Role == "TANK" then
		LFDRole:SetColorTexture(67 / 255, 110 / 255, 238 / 255,.3)
		LFDRole:Show()
	elseif Role == "HEALER" then
		LFDRole:SetColorTexture(130 / 255, 255 / 255, 130 / 255, .15)
		LFDRole:Show()
	elseif Role == "DAMAGER" then
		LFDRole:SetColorTexture(176 / 255, 23 / 255, 31 / 255, .27)
		LFDRole:Show()
	else
		LFDRole:Hide()
	end
end

function TukuiUnitFrames:CreateAuraWatchIcon(icon)
	icon:SetTemplate()
	icon.icon:Point("TOPLEFT", 1, -1)
	icon.icon:Point("BOTTOMRIGHT", -1, 1)
	icon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.icon:SetDrawLayer("ARTWORK")

	if (icon.cd) then
		icon.cd:SetHideCountdownNumbers(true)
		icon.cd:SetReverse(true)
	end

	icon.overlay:SetTexture()
end

-- create the icon
function TukuiUnitFrames:CreateAuraWatch(frame)
	local Class = select(2, UnitClass("player"))

	local Auras = CreateFrame("Frame", nil, frame)
	Auras:SetPoint("TOPLEFT", frame.Health, 2, -2)
	Auras:SetPoint("BOTTOMRIGHT", frame.Health, -2, 2)
	Auras.presentAlpha = 1
	Auras.missingAlpha = 0
	Auras.icons = {}
	Auras.PostCreateIcon = TukuiUnitFrames.CreateAuraWatchIcon
	Auras.strictMatching = true

	if (not C["Raid"].AuraWatchTimers) then
		Auras.hideCooldown = true
	end

	local buffs = {}

	if (TukuiUnitFrames.RaidBuffsTracking["ALL"]) then
		for key, value in pairs(TukuiUnitFrames.RaidBuffsTracking["ALL"]) do
			tinsert(buffs, value)
		end
	end

	if (TukuiUnitFrames.RaidBuffsTracking[Class]) then
		for key, value in pairs(TukuiUnitFrames.RaidBuffsTracking[Class]) do
			tinsert(buffs, value)
		end
	end

	-- Cornerbuffs
	if buffs then
		for key, spell in pairs(buffs) do
			local Icon = CreateFrame("Frame", nil, Auras)
			Icon.spellID = spell[1]
			Icon.anyUnit = spell[4]
			Icon:Width(8)
			Icon:Height(8)
			Icon:SetPoint(spell[2], 0, 0)

			local Texture = Icon:CreateTexture(nil, "OVERLAY")
			Texture:SetInside(Icon)
			Texture:SetTexture(C.Medias.Blank)

			if (spell[3]) then
				Texture:SetVertexColor(unpack(spell[3]))
			else
				Texture:SetVertexColor(0.8, 0.8, 0.8)
			end

			local Count = Icon:CreateFontString(nil, "OVERLAY")
			Count:SetFont(C.Medias.Font, 8, "THINOUTLINE")
			Count:SetPoint("CENTER", unpack(TukuiUnitFrames.RaidBuffsTrackingPosition[spell[2]]))
			Icon.count = Count

			Auras.icons[spell[1]] = Icon
		end
	end

	frame.AuraWatch = Auras
end

function TukuiUnitFrames:EclipseDirection()
	local Power = UnitPower("Player", SPELL_POWER_ECLIPSE)

	if (Power < 0) then
		self.Text:SetText("|cffE5994C"..L.UnitFrames.Starfire.."|r")
	elseif (Power > 0) then
		self.Text:SetText("|cff4478BC"..L.UnitFrames.Wrath.."|r")
	else
		self.Text:SetText("")
	end
end

function TukuiUnitFrames:UpdateAltPower(minimum, current, maximum)
	if (not current) or (not maximum) then return end

	local r, g, b = T.ColorGradient(current, maximum, 0, .8 ,0 ,.8 ,.8 ,0 ,.8 ,0 ,0)

	self:SetStatusBarColor(r, g, b)
	self:SetBackdropColor(r * 0.1, g * 0.1, b * 0.1)

	if self.Value then
		local Text = self.Value

		Text:SetText(current.." / "..maximum)
	end
end

function TukuiUnitFrames:Update()
	for _, element in ipairs(self.__elements) do
		element(self, "UpdateElement", self.unit)
	end
end

function TukuiUnitFrames:MoveTotemBar()
	local Frame = self:GetParent()
	local Arcane = Frame.ArcaneChargeBar
	local Totems = Frame.Totems
	local Shadow = Frame.Shadow

	local T_Y, S_Y = 5, 4

	if (Arcane and Arcane:IsShown()) then
		T_Y, S_Y = 14, 12
	end

	Shadow:Point("TOPLEFT", -4, S_Y)

	Totems:ClearAllPoints()
	Totems:Point("BOTTOMLEFT", Frame, "TOPLEFT", 0, T_Y)
end

function TukuiUnitFrames:GetPartyFramesAttributes()
	return
		"TukuiParty",
		nil,
		"custom [@raid6,exists] hide;show",
		"oUF-initialConfigFunction", [[
			local header = self:GetParent()
			self:SetWidth(header:GetAttribute("initial-width"))
			self:SetHeight(header:GetAttribute("initial-height"))
		]],
		"initial-width", C.Party.Portrait and T.Scale(162) or T.Scale(206),
		"initial-height", C.Party.Portrait and T.Scale(24) or T.Scale(40),
		"showSolo", false,
		"showParty", true,
		"showPlayer", C["Party"].ShowPlayer,
		"showRaid", true,
		"groupFilter", "1,2,3,4,5,6,7,8",
		"groupingOrder", "1,2,3,4,5,6,7,8",
		"groupBy", "GROUP",
		"yOffset", T.Scale(-66)
end

function TukuiUnitFrames:GetRaidFramesAttributes()
	local Properties = C.Party.Enable and "custom [@raid6,exists] show;hide" or "solo,party,raid"

	return
		"TukuiRaid",
		nil,
		Properties,
		"oUF-initialConfigFunction", [[
			local header = self:GetParent()
			self:SetWidth(header:GetAttribute("initial-width"))
			self:SetHeight(header:GetAttribute("initial-height"))
		]],
		"initial-width", T.Scale(66),
		"initial-height", T.Scale(50),
		"showParty", true,
		"showRaid", true,
		"showPlayer", true,
		"showSolo", false,
		"xoffset", T.Scale(4),
		"yOffset", T.Scale(-4),
		"point", "TOP",
		"groupFilter", "1,2,3,4,5,6,7,8",
		"groupingOrder", "1,2,3,4,5,6,7,8",
		"groupBy", C["Raid"].GroupBy.Value,
		"maxColumns", math.ceil(40 / 5),
		"unitsPerColumn", C["Raid"].MaxUnitPerColumn,
		"columnSpacing", T.Scale(4),
		"columnAnchorPoint", "LEFT"
end

function TukuiUnitFrames:GetPetRaidFramesAttributes()
	local Properties = C.Party.Enable and "custom [@raid6,exists] show;hide" or "solo,party,raid"

	return
		"TukuiRaidPet",
		"SecureGroupPetHeaderTemplate",
		Properties,
		"showParty", false,
		"showRaid", C["Raid"].ShowPets,
		"showSolo", false,
		"maxColumns", math.ceil(40 / 5),
		"point", "TOP",
		"unitsPerColumn", C["Raid"].MaxUnitPerColumn,
		"columnSpacing", T.Scale(4),
		"columnAnchorPoint", "LEFT",
		"yOffset", T.Scale(-4),
		"xOffset", T.Scale(4),
		"initial-width", T.Scale(66),
		"initial-height", T.Scale(50),
		"oUF-initialConfigFunction", [[
			local header = self:GetParent()
			self:SetWidth(header:GetAttribute("initial-width"))
			self:SetHeight(header:GetAttribute("initial-height"))
		]]
end

function TukuiUnitFrames:MainTankAttibutes()
	return
		"TukuiMainTank",
		nil,
		"solo,party,raid",
		"oUF-initialConfigFunction", [[
			local header = self:GetParent()
			self:SetWidth(header:GetAttribute("initial-width"))
			self:SetHeight(header:GetAttribute("initial-height"))
		]],
		"initial-width", T.Scale(150),
		"initial-height", T.Scale(22),
		"showParty", false,
		"showRaid", true,
		"showPlayer", false,
		"showSolo", false,
		"groupFilter", "MAINTANK",
		"xoffset", T.Scale(10),
		"yOffset", T.Scale(-10),
		"point", "TOP",
		"unitsPerColumn", C["Raid"].MaxUnitPerColumn,
		"columnSpacing", T.Scale(7),
		"columnAnchorPoint", "LEFT"
end

function TukuiUnitFrames:MainTankTargetAttibutes()
	return
		"TukuiMainTankTarget",
		nil,
		"solo,party,raid",
		"oUF-initialConfigFunction", [[
			local header = self:GetParent()
			self:SetWidth(header:GetAttribute("initial-width"))
			self:SetHeight(header:GetAttribute("initial-height"))
			self:SetAttribute("unitsuffix", "target")
		]],
		"initial-width", T.Scale(150),
		"initial-height", T.Scale(22),
		"showParty", false,
		"showRaid", true,
		"showPlayer", false,
		"showSolo", false,
		"groupFilter", "MAINTANK",
		"xoffset", T.Scale(4),
		"yOffset", T.Scale(-4),
		"point", "TOP",
		"unitsPerColumn", C["Raid"].MaxUnitPerColumn,
		"columnSpacing", T.Scale(4),
		"columnAnchorPoint", "LEFT"
end

function TukuiUnitFrames:Style(unit)
	if (not unit) then
		return
	end

	local Parent = self:GetParent():GetName()

	if (unit == "player") then
		TukuiUnitFrames.Player(self)
	elseif (unit == "target") then
		TukuiUnitFrames.Target(self)
	elseif (unit == "targettarget") then
		TukuiUnitFrames.TargetOfTarget(self)
	elseif (unit == "pet") then
		TukuiUnitFrames.Pet(self)
	elseif (unit == "focus") then
		TukuiUnitFrames.Focus(self)
	elseif (unit == "focustarget") then
		TukuiUnitFrames.FocusTarget(self)
	elseif unit:find("arena%d") then
		TukuiUnitFrames.Arena(self)
	elseif unit:find("boss%d") then
		TukuiUnitFrames.Boss(self)
	elseif (unit:find("raid") or unit:find("raidpet")) then
		if Parent:match("Party") then
			TukuiUnitFrames.Party(self)
		else
			TukuiUnitFrames.Raid(self)
		end
	elseif unit:match("nameplate") then
		TukuiUnitFrames.Nameplates(self)
	end

	return self
end

function TukuiUnitFrames:CreateAnchor()
	if not C.UnitFrames.Enable then
		return
	end
	
	local Anchor = CreateFrame("Frame", "TukuiActionBarAnchor", UIParent)
	Anchor:SetPoint("TOPLEFT", T.Panels.ActionBar2)
	Anchor:SetPoint("BottomRight", T.Panels.ActionBar3)

	TukuiUnitFrames.Anchor = Anchor
end

function TukuiUnitFrames:CreateUnits()
	local Movers = T["Movers"]
	
	if C.UnitFrames.Enable then
		local Player = oUF:Spawn("player")
		Player:SetPoint("BOTTOMLEFT", TukuiUnitFrames.Anchor, "TOPLEFT", 0, 8)
		Player:SetParent(Panels.PetBattleHider)
		Player:Size(250, 57)

		local Target = oUF:Spawn("target")
		Target:SetPoint("BOTTOMRIGHT", TukuiUnitFrames.Anchor, "TOPRIGHT", 0, 8)
		Target:SetParent(Panels.PetBattleHider)
		Target:Size(250, 57)

		local TargetOfTarget = oUF:Spawn("targettarget")
		TargetOfTarget:SetPoint("BOTTOM", TukuiUnitFrames.Anchor, "TOP", 0, 8)
		TargetOfTarget:SetParent(Panels.PetBattleHider)
		TargetOfTarget:Size(129, 36)

		local Pet = oUF:Spawn("pet")
		Pet:SetParent(Panels.PetBattleHider)
		Pet:SetPoint("BOTTOM", TukuiUnitFrames.Anchor, "TOP", 0, 49)
		Pet:Size(129, 36)

		local Focus = oUF:Spawn("focus")
		Focus:SetPoint("BOTTOMLEFT", TukuiUnitFrames.Anchor, "TOPLEFT", 0, 200)
		Focus:SetParent(Panels.PetBattleHider)
		Focus:Size(200, 29)

		local FocusTarget = oUF:Spawn("focustarget")
		FocusTarget:SetPoint("BOTTOM", Focus, "TOP", 0, 35)
		FocusTarget:SetParent(Panels.PetBattleHider)
		FocusTarget:Size(200, 29)

		self.Units.Player = Player
		self.Units.Target = Target
		self.Units.TargetOfTarget = TargetOfTarget
		self.Units.Pet = Pet
		self.Units.Focus = Focus
		self.Units.FocusTarget = FocusTarget

		if (C.UnitFrames.Arena) then
			local Arena = {}

			for i = 1, 5 do
				Arena[i] = oUF:Spawn("arena"..i, nil)
				Arena[i]:SetParent(Panels.PetBattleHider)
				if (i == 1) then
					Arena[i]:SetPoint("BOTTOMRIGHT", TukuiUnitFrames.Anchor, "TOPRIGHT", 0, 200)
				else
					Arena[i]:SetPoint("BOTTOM", Arena[i - 1], "TOP", 0, 35)
				end
				Arena[i]:Size(200, 29)

				Movers:RegisterFrame(Arena[i])
			end

			self.Units.Arena = Arena

			self:CreateArenaPreparationFrames()
		end

		if (C.UnitFrames.Boss) then
			local Boss = {}

			for i = 1, 5 do
				Boss[i] = oUF:Spawn("boss"..i, nil)
				Boss[i]:SetParent(Panels.PetBattleHider)
				if (i == 1) then
					Boss[i]:SetPoint("BOTTOMRIGHT", TukuiUnitFrames.Anchor, "TOPRIGHT", 0, 200)
				else
					Boss[i]:SetPoint("BOTTOM", Boss[i - 1], "TOP", 0, 35)
				end
				Boss[i]:Size(200, 29)

				Movers:RegisterFrame(Boss[i])
			end

			self.Units.Boss = Boss
		end

		if C.Party.Enable then
			local Gap = C.Party.Portrait and 74 or 28

			local Party = oUF:SpawnHeader(TukuiUnitFrames:GetPartyFramesAttributes())
			Party:SetParent(Panels.PetBattleHider)
			Party:Point("TOPLEFT", UIParent, "TOPLEFT", Gap, -46)

			TukuiUnitFrames.Headers.Party = Party

			Movers:RegisterFrame(Party)
		end

		if C.Raid.Enable then
			local Raid = oUF:SpawnHeader(TukuiUnitFrames:GetRaidFramesAttributes())
			Raid:SetParent(Panels.PetBattleHider)
			Raid:Point("TOPLEFT", UIParent, "TOPLEFT", 30, -30)

			if C.Raid.ShowPets then
				local Pet = oUF:SpawnHeader(TukuiUnitFrames:GetPetRaidFramesAttributes())
				Pet:SetParent(Panels.PetBattleHider)
				Pet:Point("TOPLEFT", Raid, "TOPRIGHT", 4, 0)

				TukuiUnitFrames.Headers.RaidPet = Pet
				Movers:RegisterFrame(Pet)
			end
	--[[
			local MainTank = oUF:SpawnHeader(TukuiUnitFrames:MainTankAttibutes())
			MainTank:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			Movers:RegisterFrame(MainTank)

			local MainTankTarget = oUF:SpawnHeader(TukuiUnitFrames:MainTankTargetAttibutes())
			MainTankTarget:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			Movers:RegisterFrame(MainTankTarget)
	]]
			TukuiUnitFrames.Headers.Raid = Raid
			Movers:RegisterFrame(Raid)
		end
		
		Movers:RegisterFrame(Player)
		Movers:RegisterFrame(Target)
		Movers:RegisterFrame(TargetOfTarget)
		Movers:RegisterFrame(Pet)
		Movers:RegisterFrame(Focus)
		Movers:RegisterFrame(FocusTarget)
	end
	
	if C.NamePlates.Enable then
		local Scale = UIParent:GetEffectiveScale()
		
		TukuiUnitFrames.NameplatesVars = {
			-- important, strongly recommend to set these to 1
			nameplateGlobalScale = 1,
			NamePlateHorizontalScale = 1,
			NamePlateVerticalScale = 1,
			
			-- optional, you may use any values
			nameplateLargerScale = 1,
			nameplateMaxScale = 1,
			nameplateMinScale = 1,
			nameplateSelectedScale = 1,
			nameplateSelfScale = 1,
		}
		
		oUF:SpawnNamePlates(nil, nil, NameplateVars)
	end
end

function TukuiUnitFrames:ShowArenaPreparation()
	local NumOpps = GetNumArenaOpponentSpecs()

	for i = 1, 5 do
		local Frame = self.Units.ArenaPreparation[i]

		if (i <= NumOpps) then
			local SpecID = GetArenaOpponentSpec(i)

			if (SpecID and SpecID > 0) then
				local _, Spec, _, _, _, Class = GetSpecializationInfoByID(SpecID)

				if (Class) then
					Frame.SpecClass:SetText(Spec.."  -  "..LOCALIZED_CLASS_NAMES_MALE[Class])

					if (not C.UnitFrames.DarkTheme) then
						local Color = self.Units.Arena[i].colors.class[Class]

						Frame.Health:SetStatusBarColor(unpack(Color))
					end
				else
					Frame.Health:SetStatusBarColor(0.2, 0.2, 0.2, 1)
				end

				Frame:Show()
			else
				Frame:Hide()
			end
		else
			Frame:Hide()
		end
	end
end

function TukuiUnitFrames:HideArenaPreparation()
	for i = 1, 5 do
		local Frame = self.Units.ArenaPreparation[i]

		Frame:Hide()
	end
end

function TukuiUnitFrames:OnEvent(event)
	if (event == "ARENA_OPPONENT_UPDATE") then
		self:HideArenaPreparation()
	else
		self:ShowArenaPreparation()
	end
end

function TukuiUnitFrames:UpdateRaidDebuffIndicator()
	local ORD = ns.oUF_RaidDebuffs or oUF_RaidDebuffs

	if (ORD) then
		ORD:ResetDebuffData()
		
		local _, InstanceType = IsInInstance()
		if (InstanceType == "party" or InstanceType == "raid") then
			ORD:RegisterDebuffs(TukuiUnitFrames.DebuffsTracking.RaidDebuffs.spells)
		else
			ORD:RegisterDebuffs(TukuiUnitFrames.DebuffsTracking.CCDebuffs.spells)
		end
	end
end

function TukuiUnitFrames:Enable()
	self.Backdrop = {
		bgFile = C.Medias.Blank,
		insets = {top = -T.Mult, left = -T.Mult, bottom = -T.Mult, right = -T.Mult},
	}

	oUF:RegisterStyle("Tukui", TukuiUnitFrames.Style)
	oUF:SetActiveStyle("Tukui")

	self:DisableBlizzard()
	self:CreateAnchor()
	self:CreateUnits()

	-- Arena Preparation
	if (C.UnitFrames.Enable and C.UnitFrames.Arena) then
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
		self:RegisterEvent("ARENA_OPPONENT_UPDATE")
		self:SetScript("OnEvent", self.OnEvent)
	end
	
	if (C.UnitFrames.RaidDebuffs) then
		local RaidDebuffs = CreateFrame("Frame")
		RaidDebuffs:RegisterEvent("PLAYER_ENTERING_WORLD")
		RaidDebuffs:SetScript("OnEvent", TukuiUnitFrames.UpdateRaidDebuffIndicator)
	
		local ORD = ns.oUF_RaidDebuffs or oUF_RaidDebuffs
		if (ORD) then
			ORD.ShowDispellableDebuff = true
			ORD.FilterDispellableDebuff = true
			ORD.MatchBySpellName = false
		end
	end
end

T["UnitFrames"] = TukuiUnitFrames
