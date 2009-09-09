

-- The Gnomish Yellow Pages
-- let your stumpy little fingers do the walking

local VERSION = ("$Revision: 58 $"):match("%d+")

local faction = UnitFactionGroup("player")
local realmName = GetRealmName()

local serverKey = realmName.."-"..faction
local player = UnitName("player")
local playerGUID

local BlizzardSendWho

local function OpenTradeLink(tradeString)
--	ShowUIPanel(ItemRefTooltip)
--	if ( not ItemRefTooltip:IsShown() ) then
--		ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
--	end
	ItemRefTooltip:SetHyperlink(tradeString)
end

local tradeList = { 2259, 2018, 7411, 4036, 45357, 25229, 2108, 3908,  2550, 3273 }
local spellList = {}

--[[
 the SetBackdrop system has some texture coordinate problems, so i wrote this to emulate

 i'm creating an invisible frame for sizing simplicity, but the textures are actually parented to the real frame (so they a1re place in the correct drawing layer)
 even tho they are referenced from this invisible frame (as indices into the frame table)
]]

local textureQuads = {
	LEFT = 0,
	RIGHT = 1,
	TOP = 2,
	BOTTOM = 3,
	TOPLEFT = 4,
	TOPRIGHT = 5,
	BOTTOMLEFT = 6,
	BOTTOMRIGHT = 7,
}

local function ResizeBetterBackdrop(frame)
	if not frame then
		return
	end

	local w,h = frame:GetWidth()-frame.edgeSize*2, frame:GetHeight()-frame.edgeSize*2

	for k,i in pairs({"LEFT", "RIGHT"}) do
		local t = frame["texture"..i]

		local y = h/frame.edgeSize

		local q = textureQuads[i]

		t:SetTexCoord(q*.125, q*.125+.125, 0, y)
	end

	for k,i in pairs({"TOP", "BOTTOM"}) do
		local t = frame["texture"..i]

		local y = w/frame.edgeSize

		local q = textureQuads[i]

		local x1 = q*.125
		local x2 = q*.125+.125

		t:SetTexCoord(x1,0, x2,0, x1,y, x2, y)
	end

	frame.textureBG:SetTexCoord(0,w/frame.tileSize, 0,h/frame.tileSize)
end

local function SetBetterBackdrop(frame, bd)
	if not frame.backDrop then
		frame.backDrop = CreateFrame("Frame", nil, frame)


		for k,i in pairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "LEFT", "RIGHT", "TOP", "BOTTOM"}) do
			frame.backDrop["texture"..i] =  frame:CreateTexture(nil, "BACKGROUND")
		end

		frame.backDrop.textureBG = frame:CreateTexture(nil,"BACKGROUND")
	end

	frame.backDrop.edgeSize = bd.edgeSize
	frame.backDrop.tileSize = bd.tileSize

	frame.backDrop:SetPoint("TOPLEFT",frame,"TOPLEFT",-bd.insets.left/2, bd.insets.top/2)
	frame.backDrop:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",bd.insets.right/2, -bd.insets.bottom/2)

	local w,h = frame:GetWidth()-bd.edgeSize*2, frame:GetHeight()-bd.edgeSize*2

	frame.backDrop.textureBG:SetTexture(bd.bgFile, bd.tile)

	for k,i in pairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}) do
		local t = frame.backDrop["texture"..i]

		t:SetTexture(bd.edgeFile)
		t:SetPoint(i, frame.backDrop)
		t:SetWidth(bd.edgeSize)
		t:SetHeight(bd.edgeSize)

		local q = textureQuads[i]

		t:SetTexCoord(q*.125,q*.125+.125, 0,1)

	end

	for k,i in pairs({"LEFT", "RIGHT"}) do
		local t = frame.backDrop["texture"..i]

		t:SetTexture(bd.edgeFile, true)
		t:SetPoint(i, frame.backDrop)
		t:SetPoint("BOTTOM", frame.backDrop, "BOTTOM", 0, bd.edgeSize)
		t:SetPoint("TOP", frame.backDrop, "TOP", 0, -bd.edgeSize)
		t:SetWidth(bd.edgeSize)

		local y = h/bd.edgeSize

		local q = textureQuads[i]

		t:SetTexCoord(q*.125, q*.125+.125, 0, y)
	end

	for k,i in pairs({"TOP", "BOTTOM"}) do
		local t = frame.backDrop["texture"..i]

		t:SetTexture(bd.edgeFile, true)
		t:SetPoint(i, frame.backDrop)
		t:SetPoint("LEFT", frame.backDrop, "LEFT", bd.edgeSize, 0)
		t:SetPoint("RIGHT", frame.backDrop, "RIGHT", -bd.edgeSize, 0)
		t:SetHeight(bd.edgeSize)

		local y = w/bd.edgeSize

		local q = textureQuads[i]

		local x1 = q*.125
		local x2 = q*.125+.125

		t:SetTexCoord(x1,0, x2,0, x1,y, x2, y)
	end

	frame.backDrop.textureBG:SetPoint("TOPLEFT", frame.backDrop, "TOPLEFT", bd.edgeSize, -bd.edgeSize)
	frame.backDrop.textureBG:SetPoint("BOTTOMRIGHT", frame.backDrop, "BOTTOMRIGHT", -bd.edgeSize, bd.edgeSize)


	frame.backDrop.textureBG:SetTexCoord(0,w/bd.tileSize, 0,h/bd.tileSize)

	frame.backDrop:SetScript("OnSizeChanged", ResizeBetterBackdrop)
end

local UserInputDialog = {}

do
	local frame
	local dialogBackdrop = {bgFile = "Interface/Tooltips/UI-Tooltip-Background",
							edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
							tile = true, tileSize = 16, edgeSize = 16,
							insets = { left = 4, right = 4, top = 4, bottom = 4 }}

	local buttonBackdrop = {bgFile = "Interface/Buttons/UI-SliderBar-Background",
							edgeFile = "Interface/Buttons/UI-SliderBar-Border",
							tile = true, tileSize = 4, edgeSize = 8,
							insets = { left = 2, right = 2, top = 2, bottom = 2 }}


	function UserInputDialog:Show(message, ...)
		if not frame then
			frame = CreateFrame("Frame")

			frame:SetBackdrop(dialogBackdrop)
			frame:SetBackdropColor(0,0,0,1)

			frame:SetFrameStrata("DIALOG")

			frame.buttons = {}

			frame:EnableMouse(true)
		end

		frame:SetWidth(320)
		frame:SetHeight(100)

		frame:SetPoint("CENTER",0,200)

		if not frame.messageText then
			frame.messageText = frame:CreateFontString(nil,nil,"GameFontNormal")

			frame.messageText:SetPoint("TOPLEFT", 5,-5)
			frame.messageText:SetPoint("BOTTOMRIGHT", -5, 50)
		end

		frame.messageText:SetText(message)


		local args = {...}
		local bwidth = 300 / math.ceil(#args/2)
		local buttonPosition = -(150 - bwidth/2)

		for i=1,#args,2 do
			if not frame.buttons[i] then
				local b = CreateFrame("Button",nil,frame)
				b:SetPoint("CENTER",buttonPosition, -35)
				b:SetBackdrop(buttonBackdrop)
				b:SetBackdropColor(0,0,0,1)
				b:SetBackdropBorderColor(1,1,1,1)

				b:SetHeight(22)
				b:SetWidth(bwidth)

				b:SetNormalFontObject("GameFontNormalSmall")
				b:SetHighlightFontObject("GameFontHighlightSmall")

				b:SetScript("OnClick", function(button)
					frame:Hide()
					if b.callBack then
						b.callBack()
					end
				end)

				frame.buttons[i] = b
			end

			frame.buttons[i]:SetText(args[i])
			frame.buttons[i].callBack = args[i+1]
			buttonPosition = buttonPosition + bwidth
		end

		frame:Show()

		frame:SetFrameStrata("FULLSCREEN_DIALOG")
	end
end


local TradeLink = {}

do
	local encodedByte = {
		'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
		'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',
		'0','1','2','3','4','5','6','7','8','9','+','/'
	}

	local decodedByte = {}

	for i=1,#encodedByte do
		local b = string.byte(encodedByte[i])
		decodedByte[b] = i - 1
	end

	local bitMapSizeGuess = { 40, 80, 45, 45, 60, 75, 80, 65, }

	local tradeIndex = 1
	local spellBit = 0
	local countDown = 5
	local bitMapSizes = {}
	local bitMapSize = bitMapSizeGuess[tradeIndex] or 0
	local timeToClose = 0
	local frameOpen = false

	local framesRegistered

	local progressBar

	local OnScanCompleteCallback

	local function ScanComplete(frame)
		frame:SetScript("OnUpdate", nil)
		frame:UnregisterEvent("TRADE_SKILL_UPDATE")
		frame:UnregisterEvent("TRADE_SKILL_CLOSE")
		frame:UnregisterEvent("TRADE_SKILL_SHOW")

		frame:Hide()

		for k,f in pairs(framesRegistered) do
			f:RegisterEvent("TRADE_SKILL_SHOW")
		end

		progressBar:Hide()

		if OnScanCompleteCallback then
			OnScanCompleteCallback(spellList)
		end
	end


	local function OnTradeSkillShow()
		if not bitMapSizes[tradeIndex] then
			bitMapSizes[tradeIndex] = bitMapSize
			spellBit = 0
			spellList[tradeList[tradeIndex]] = {}

--			DEFAULT_CHAT_FRAME:AddMessage("Scanning "..GetTradeSkillLine().." "..(bitMapSize*6).." spells")
			progressBar.textLeft:SetText("Scanning "..GetTradeSkillLine().." ("..(bitMapSize*6)..")")

			timeToClose = 90				-- let's hope it doesn't come to that
		end
	end


	local function OnTradeSkillClose(frame)
		frameOpen = false
--DEFAULT_CHAT_FRAME:AddMessage("CLOSE")
		if bitMapSizes[tradeIndex] then
			spellBit = spellBit + 1

			if spellBit <= bitMapSizes[tradeIndex]*6 then
				local percentComplete = spellBit/(bitMapSizes[tradeIndex]*6)

				progressBar.fg:SetWidth(300*percentComplete)
				progressBar.textRight:SetText(spellBit)


				local bytes = floor((spellBit-1)/6)
				local bits = (spellBit-1) - bytes*6

				local bmap = string.rep("A", bytes) .. encodedByte[bit.lshift(1, bits)+1] .. string.rep("A", bitMapSizes[tradeIndex]-bytes-1)

--				bmap = string.rep("A", bytes)

				local tradeString = string.format("trade:%d:%d:%d:%s:%s", tradeList[tradeIndex], 450, 450, playerGUID, bmap)

--				local link = "|cffffd000|H"..tradeString.."|h["..GetSpellInfo(tradeList[tradeIndex]).."]|h|r"

--DEFAULT_CHAT_FRAME:AddMessage(tradeString)
--DEFAULT_CHAT_FRAME:AddMessage(link)

				timeToClose = 30


				OpenTradeLink(tradeString)
			else
				tradeIndex = tradeIndex + 1
				bitMapSize = bitMapSizeGuess[tradeIndex] or 0

				if tradeIndex <= #tradeList then
					OnTradeSkillClose()
				else
					ScanComplete(frame)
				end
			end
		else
			bitMapSize = bitMapSize + 1
			bmap = string.rep("/", bitMapSize)

			local tradeString = string.format("trade:%d:%d:%d:%s:%s", tradeList[tradeIndex], 450, 450, playerGUID, bmap)

			OpenTradeLink(tradeString)
			timeToClose = .01
		end
	end


	local function OnTradeSkillUpdate(frame)
		if not bitMapSizes[tradeIndex] then
--			bitMapSizes[tradeIndex] = bitMapSize
--			spellBit = 0
--			spellList[tradeList[tradeIndex]] = {}

--			DEFAULT_CHAT_FRAME:AddMessage("Scanning "..GetTradeSkillLine().." "..(bitMapSize*6).." spells")
--			timeToClose = 30
		elseif spellBit > 0 then

			local numSkills = GetNumTradeSkills()


--			DEFAULT_CHAT_FRAME:AddMessage("skills = "..tonumber(numSkills))

			spellList[tradeList[tradeIndex]][spellBit] = tradeList[tradeIndex] -- placeHolder

			if numSkills then
				for i=1,numSkills do
					local recipeLink = GetTradeSkillRecipeLink(i)

					if recipeLink then
						local id = string.match(recipeLink,"enchant:(%d+)")
--DEFAULT_CHAT_FRAME:AddMessage(spellBit.." = "..id.."-"..recipeLink)
						progressBar.textLeft:SetText(recipeLink)
						spellList[tradeList[tradeIndex]][spellBit] = tonumber(id)
					end
				end

				timeToClose = .001
			end
		end
	end


	local function OnUpdate(frame, elapsed)
--DEFAULT_CHAT_FRAME:AddMessage("UPDATE")
--		countDown = countDown - elapsed
		timeToClose = timeToClose - elapsed

--DEFAULT_CHAT_FRAME:AddMessage("countDown = "..countDown)
--		if countDown < 0 then
--			OnTradeSkillClose()
--		end

		if timeToClose < 0 then
			timeToClose = 1000
			CloseTradeSkill()
		end
	end

	function TradeLink:Scan(callback)
		OnScanCompleteCallback = callback

		framesRegistered = { GetFramesRegisteredForEvent("TRADE_SKILL_SHOW") }

		for k,f in pairs(framesRegistered) do
			f:UnregisterEvent("TRADE_SKILL_SHOW")
		end


		progressBar = CreateFrame("Frame", nil, UIParent)

		progressBar:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                                            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                                            tile = true, tileSize = 16, edgeSize = 16,
                                            insets = { left = 4, right = 4, top = 4, bottom = 4 }});
		progressBar:SetBackdropColor(0,0,0,1);


		progressBar:SetFrameStrata("DIALOG")

		progressBar:SetWidth(310)
		progressBar:SetHeight(30)

		progressBar:SetPoint("CENTER",0,-150)

		progressBar.fg = progressBar:CreateTexture()
		progressBar.fg:SetTexture(.8,.7,.2,.5)
		progressBar.fg:SetPoint("LEFT",progressBar,"LEFT",5,0)
		progressBar.fg:SetHeight(20)
		progressBar.fg:SetWidth(300)

		progressBar.textLeft = progressBar:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
		progressBar.textLeft:SetText("Scanning...")
		progressBar.textLeft:SetPoint("LEFT",10,0)

		progressBar.textRight = progressBar:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
		progressBar.textRight:SetText("0%")
		progressBar.textRight:SetPoint("RIGHT",-10,0)

		progressBar:EnableMouse()

		progressBar:SetScript("OnEnter", function(frame)
			GameTooltip:ClearLines()
			GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT")

			GameTooltip:AddLine("The Gnomish Yellow Pages Is Scanning...")
			GameTooltip:AddLine("|ca0ffffffA comprehensive scan of trade skills is required.")
			GameTooltip:AddLine("|ca0ffffffThis will take a few minutes and may pause while")
			GameTooltip:AddLine("|ca0ffffffdata is collected from the server.  A scan should")
			GameTooltip:AddLine("|ca0ffffffonly be required on initial install, when a new")
			GameTooltip:AddLine("|ca0ffffffgame patch has been released, or when gyp's")
			GameTooltip:AddLine("|ca0ffffffsaved variables file has been purged.")
			GameTooltip:AddLine("|ca0ffffffDuring the scan, trade skill interaction is blocked.")

			GameTooltip:Show()
		end)

		progressBar:SetScript("OnLeave", function(frame)
			GameTooltip:Hide()
		end)

		local scanFrame = CreateFrame("Frame")


		scanFrame:RegisterEvent("TRADE_SKILL_SHOW")
		scanFrame:RegisterEvent("TRADE_SKILL_UPDATE")
		scanFrame:RegisterEvent("TRADE_SKILL_CLOSE")

		scanFrame:SetScript("OnEvent", function(frame,event)
--DEFAULT_CHAT_FRAME:AddMessage(tostring(event))
			if event == "TRADE_SKILL_SHOW" then
				OnTradeSkillShow(frame)
			end

			if event == "TRADE_SKILL_CLOSE" then
				OnTradeSkillClose(frame)
			end

			if event == "TRADE_SKILL_UPDATE" then
				OnTradeSkillUpdate(frame)
			end
		end)

		scanFrame:SetScript("OnUpdate", OnUpdate)

		OnTradeSkillClose()
	end


	function TradeLink:BitmapEncode(data, mask)
		local v = 0
		local b = 1
		local bitmap = ""

		for i=1,#data do
			if mask[data[i]] == true then
				v = v + b
			end

			b = b * 2

			if b == 64 then
				bitmap = bitmap .. encodedByte[v+1]
				v = 0
				b = 1
			end
		end

		if b>1 then
			bitmap = bitmap .. encodedByte[v+1]
		end

		return bitmap
	end


	function TradeLink:BitmapDecode(data, bitmap, maskTable)
		local mask = maskTable or {}
		local index = 1

		for i=1, string.len(bitmap) do
			local b = decodedByte[string.byte(bitmap, i)]
			local v = 1

			for j=1,6 do
				if index <= #data and data[index] then
					if bit.band(v, b) == v then
						mask[data[index]] = true
					else
						mask[data[index]] = false
					end
				end
				v = v * 2

				index = index + 1
			end
		end

		return mask
	end


	function TradeLink:BitmapBitLogic(A,B,logic)
		local length = math.min(string.len(A), string.len(B))
		local R = ""

		for i=1, length do
			local a = decodedByte[string.byte(A, i)]
			local b = decodedByte[string.byte(B, i)]

			local r = logic(a,b)

			R = R..encodedByte[r+1]
		end

		return R
	end


	function TradeLink:DumpSpells(data, bitmap)
		local index = 1
--		Config.testOut = {}

		for i=1, string.len(bitmap) do
			local b = decodedByte[string.byte(bitmap, i)]
			local v = 1

			for j=1,6 do
				if index <= #data then
					if bit.band(v, b) == v then
						DEFAULT_CHAT_FRAME:AddMessage("bit "..index.." = spell:"..data[index].." "..GetSpellLink(data[index]))
--						Config.testOut[#Config.testOut+1] = "bit "..index.." = spell:"..data[index].." ["..GetSpellInfo(data[index]).."]"
					end
				end
				v = v * 2

				index = index + 1
			end
		end
	end



	function TradeLink:BitmapCompress(bitmap)
		if not bitmap then return end

		local len = string.len(bitmap)
		local compressed = {}
		local n = 1

		for i=1,len,5 do
			local map = 0

			map = decodedByte[string.byte(bitmap, i) or 65]

			v = decodedByte[string.byte(bitmap,i+1) or 65]
			map = bit.lshift(map, 6) + v


			v = decodedByte[string.byte(bitmap,i+2) or 65]
			map = bit.lshift(map, 6) + v


			v = decodedByte[string.byte(bitmap,i+3) or 65]
			map = bit.lshift(map, 6) + v


			v = decodedByte[string.byte(bitmap,i+4) or 65]
			map = bit.lshift(map, 6) + v

			compressed[n] = map

			n = n + 1
		end

		return compressed
	end



-- the following only operate on COMPRESSED bitmaps
	function TradeLink:BitsShared(b1, b2)
		local sharedBits = 0
		local len = math.min(#b1,#b2)

		for i=1,len do
			result = bit.band(b1[i],b2[i] or 0)
--DEFAULT_CHAT_FRAME:AddMessage(tostring(b1[i]).." "..tostring(b2[i]).." result "..result)

			if result~=0 then
				for b=0,29 do
					if bit.band(result, 2^b)~=0 then
						sharedBits = sharedBits + 1
					end
				end
			end
		end
--DEFAULT_CHAT_FRAME:AddMessage("shared "..sharedBits)
		return sharedBits
	end


	function TradeLink:CountBits(bmap)
		local bits = 0
		local len = #bmap

		for i=1,len do
			if result~=0 then
				for b=0,29 do
					if bit.band(bmap[i], 2^b)~=0 then
						bits = bits + 1
					end
				end
			end
		end
		return bits
	end

end



local TradeButton = {}

do
	local tradeButtonParent

	function OnLeave(frame)
		GameTooltip:Hide()
	end


	function OnEnter(frame)
		GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT")

		GameTooltip:ClearLines()
		GameTooltip:AddLine(frame.tradeName,1,1,1)
		GameTooltip:AddLine("click to shop",.7,.7,.7)

		GameTooltip:Show()
	end


	function OnClick(frame, button)
		local link = frame.tradeLink
		local tradeString = string.match(link, "(trade:%d+:%d+:%d+:[0-9a-fA-F]+:[A-Za-z0-9+/]+)")

		getglobal("GYPFrame"):SetFrameStrata("LOW")
--		SetItemRef(tradeString,link,button)
		OpenTradeLink(tradeString)
	end


	function TradeButton:Create(tradeSkillList, parentFrame)
		local buttonSize = 36
		local position = 0 -- pixel

		local frameName = "GYPTradeButtons"
		local frame = CreateFrame("Frame", frameName, parentFrame)


		frame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 30,-66)
		frame:SetWidth(buttonSize * #tradeSkillList + 5 * (#tradeSkillList-1))
		frame:SetHeight(buttonSize)

		frame:Show()

		frame:SetScale(0.7)

		tradeButtonParent = frame

		for i=1,#tradeSkillList,1 do			-- iterate thru all skills in defined order for neatness (professions, secondary, class skills)
			local tradeID = tradeSkillList[i].tradeID
			local spellName = GetSpellInfo(tradeID)
			local tradeLink

			local recipeList = Config.spellList[tradeID]

			local encodingLength = floor((#recipeList+5) / 6)

			local encodedString = string.rep("/",encodingLength)

			tradeLink = "|cffffd00|Htrade:"..tradeID..":450:450:"..playerGUID..":"..encodedString.."|h["..spellName.."]|h|r"


			local spellName, _, spellIcon = GetSpellInfo(tradeID)

			local buttonName = "GYPTradeButton-"..tradeID
			local button = CreateFrame("CheckButton", buttonName, frame, "ActionButtonTemplate")

--			button:SetCheckedTexture("")
			button:SetAlpha(0.8)
			button:SetWidth(buttonSize)
			button:SetHeight(buttonSize)

			button:ClearAllPoints()
			button:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", position, 0)

			local buttonIcon = getglobal(button:GetName().."Icon")
			buttonIcon:SetAllPoints(button)
			buttonIcon:SetTexture(spellIcon)

			button.tradeLink = tradeLink
			button.tradeName = spellName
			button.tradeID = tradeID

			button:SetScript("OnClick", OnClick)
			button:SetScript("OnEnter", OnEnter)
			button:SetScript("OnLeave", OnLeave)

			position = position + (button:GetWidth()+5)
			button:Show()

--[[
				if tradeID == self.currentTrade then
					button:SetChecked(1)

					if Skillet.data.skillList[player][tradeID].scanned then
						buttonIcon:SetVertexColor(1,1,1)
					else
						buttonIcon:SetVertexColor(1,0,0)
					end
				else
					button:SetChecked(0)
				end
]]

		end
	end

	local function updateButtons(trade, button, ...)
		if button then
			if button.tradeID == trade then
				button:SetChecked(1)
			else
				button:SetChecked(0)
			end

			updateButtons(trade, ...)
		end
	end


	function TradeButton:Update(trade)
		if tradeButtonParent then
			updateButtons(trade, tradeButtonParent:GetChildren())
		end
	end
end

do
	local frame
	local master = CreateFrame("Frame")

	local function RegisterKeyFunction(frame, key, func)
		if not frame.keyFunctions then
			frame.keyFunctions = {}
		end

		frame.keyFunctions[key] = func
	end


	local function RegisterEvent(frame, event, func)
		if not frame.events then
			frame.events = {}
		end

		frame.events[event] = func
		frame:RegisterEvent(event)
	end


	local function ParseEvent(frame, event, ...)
		if frame.events[event] then
--		DEFAULT_CHAT_FRAME:AddMessage(event)
			frame.events[event](...)
		end
	end


	local recipeTotals = {}


	local st

	local timerList = {}



	local priorityWho = {}
	local backgroundWho = {}


	local whoDataPending = false
	local guildDataPending = false

	local function PrioritySendWho(who)
		timerList["ProcessWhoQueue"].countDown = 0
		if #priorityWho > 0 then
			if priorityWho[#priorityWho] ~= who then
				table.insert(priorityWho, who)
			end
		else
			table.insert(priorityWho, who)
		end
	end

	local function BackgroundSendWho(who)
		table.insert(backgroundWho, who)
	end

	local lastWho = 0

	local function ProcessWhoQueue()
		local elapsed = time() - lastWho
		if elapsed > 5 then
			if #priorityWho > 0 then
				local who = table.remove(priorityWho, 1)

				BlizzardSendWho(who)
--DEFAULT_CHAT_FRAME:AddMessage("priority "..who.." "..elapsed)
			elseif #backgroundWho > 0 then

				local who = table.remove(backgroundWho, 1)

				whoDataPending = true
				SetWhoToUI(1)
				BlizzardSendWho(who)
--DEFAULT_CHAT_FRAME:AddMessage("background "..who.." "..elapsed)
			end
		end
	end

	local selectedRows = {}

	local tradeIDbyName = {}
	local basicTradeID = {}
	local tradeList = {}

	local tradeSkillIsOpen


	local function buildBasicTradeTable(aliases)
		for n=1,#aliases do
			basicTradeID[aliases[n]] = aliases[1]
		end

		table.insert(tradeList,{ tradeID = aliases[1]})

		tradeIDbyName[GetSpellInfo(aliases[1])] = aliases[1]
	end



	buildBasicTradeTable({ 2259,3101,3464,11611,28596,28677,28675,28672,51304 })					-- alchemy
	buildBasicTradeTable({ 2018,3100,3538,9785,9788,9787,17039,17040,17041,29844,51300 })				-- bs
	buildBasicTradeTable({ 7411,7412,7413,13920,28029,51313 })							-- enchanting
	buildBasicTradeTable({ 4036,4037,4038,12656,20222,20219,30350,51306 })						-- eng
	buildBasicTradeTable({ 45357,45358,45359,45360,45361,45363 })							-- inscription
	buildBasicTradeTable({ 25229,25230,28894,28895,28897,51311 })							-- jc
	buildBasicTradeTable({ 2108,3104,3811,10656,10660,10658,10662,32549,51302 })					-- lw
	buildBasicTradeTable({ 3908,3909,3910,12180,26801,26798,26797,26790,51309 })					-- tailoring
	buildBasicTradeTable({ 2550,3102,3413,18260,33359,51296 })							-- cooking
	buildBasicTradeTable({ 3273,3274,7924,10846,27028,45542,10846 })						-- first aid

--	buildBasicTradeTable({ 2656 })

	local simpleBitmap = {}
	local currentTradeskill = nil
	local currentTradeBitmap = nil
	local currentTradeLink = nil

--[[
	tradeskill filter popup stuff:
]]
	local selectedTradeskill = nil

	local function TradeFilterToggle(button, slot)
		selectedTradeskill = tradeList[slot].tradeID
		st:SortData()
	end


	local function TradeFilterAll()
		selectedTradeskill = nil
		st:SortData()
	end


	local tradeFilterMenu = {}

	table.insert(tradeFilterMenu, { text = "All Trades", func = TradeFilterAll, fontObject = GameFontNormal})

	for i=1,#tradeList do
		table.insert(tradeFilterMenu, { text = GetSpellInfo(tradeList[i].tradeID), func = TradeFilterToggle, arg1 = i, checked = function() return selectedTradeskill == tradeList[i].tradeID end })
	end

--[[
	age filter popup stuff:
]]
	local selectedAge = nil

	local function AgeFilterSet(button, age)
		selectedAge = age
		st:SortData()
	end

	local ageFilterMenu = {
		{ text = "All", func = AgeFilterSet, arg1 = nil,  fontObject = GameFontNormal },
		{ text = "1 day", func = AgeFilterSet, arg1 = 1, checked = function() return selectedAge == 1 end },
		{ text = "1 week", func = AgeFilterSet, arg1 = 7, checked = function() return selectedAge == 7 end},
		{ text = "2 weeks", func = AgeFilterSet, arg1 = 14, checked = function() return selectedAge == 14 end },
		{ text = "1 month", func = AgeFilterSet, arg1 = 30, checked = function() return selectedAge == 30 end },
	}

--[[
	level filter popup stuff:
]]
	local selectedLevel = nil

	local function LevelFilterSet(button, level)
		selectedLevel = level
		st:SortData()
	end

	local levelFilterMenu = {
		{ text = "All", func = LevelFilterSet, arg1 = nil,  checked = function() return not selectedLevel end, fontObject = GameFontNormal },
		{ text = "100+", func = LevelFilterSet, arg1 = 100, checked = function() return selectedLevel == 100 end },
		{ text = "200+", func = LevelFilterSet, arg1 = 200, checked = function() return selectedLevel == 200 end},
		{ text = "300+", func = LevelFilterSet, arg1 = 300, checked = function() return selectedLevel == 300 end },
		{ text = "375+", func = LevelFilterSet, arg1 = 375, checked = function() return selectedLevel == 375 end },
		{ text = "450", func = LevelFilterSet, arg1 = 450, checked = function() return selectedLevel == 450 end },
	}

--[[
	player filter popup stuff:
]]
	local selectedPlayers = {["STRANGERS"] = true, ["OFFLINE"] = true}

	local function PlayerFilterSet(button, setting)
		selectedPlayers[setting] = not selectedPlayers[setting]
		st:SortData()
	end

	local playerFilterMenu = {
		{ text = "Show Strangers", func = PlayerFilterSet, arg1 = "STRANGERS", checked = function() return selectedPlayers["STRANGERS"] end},
		{ text = "Show Offline", func = PlayerFilterSet, arg1 = "OFFLINE", checked = function() return selectedPlayers["OFFLINE"] end },
	}

	local onlineColorTable = { ["r"] = 0.8, ["g"] = 0.8, ["b"] = 0.8, ["a"] = 1.0 }
	local offlineColorTable = { ["r"] = 1.0, ["g"] = 0.0, ["b"] = 0.0, ["a"] = 1.0 }
	local localColorTable = { ["r"] = 0.4, ["g"] = 0.8, ["b"] = 1.0, ["a"] = 1.0 }
	local friendColorTable = { ["r"] = 1.0, ["g"] = 0.8, ["b"] = 0.4, ["a"] = 1.0 }
	local guildColorTable = { ["r"] = 0.2, ["g"] = 1.0, ["b"] = 0.2, ["a"] = 1.0 }

	local singleSharedColorTable = 	{ ["r"] = 0.5, ["g"] = 1.0, ["b"] = 1.0, ["a"] = 1.0 }
	local sharedColorTable = 		{ ["r"] = 1.0, ["g"] = 1.0, ["b"] = 0.0, ["a"] = 1.0 }
	local noneSharedColorTable = 	{ ["r"] = 0.5, ["g"] = 0.5, ["b"] = 0.0, ["a"] = 1.0 }

	local playerList = {}
	local playerLocation = {}

	local friendList = {}
	local guildList = {}
	local guildCraftList = {}
	local playerAge = {}
	local playerWhoPending = ""

	local tradeLinkQueue = {}


	local whoAutoUpdateToggle
	local whoAutoUpdateFrequency

	local OFFLINE = "** Offline **"
	local ONLINE = "Online"

	local colorWhite = { ["r"] = 1.0, ["g"] = 1.0, ["b"] = 1.0, ["a"] = 1.0 }
	local colorBlack = { ["r"] = 0.0, ["g"] = 1.0, ["b"] = 0.0, ["a"] = 0.0 }
	local colorDark = { ["r"] = 1.1, ["g"] = 0.1, ["b"] = 0.1, ["a"] = 0.0 }

	local highlightOff = { ["r"] = 0.0, ["g"] = 0.0, ["b"] = 0.0, ["a"] = 0.0 }
	local highlightSelected = { ["r"] = 0.5, ["g"] = 0.5, ["b"] = 0.5, ["a"] = 0.5 }
	local highlightSelectedMouseOver = { ["r"] = 1, ["g"] = 1, ["b"] = 0.5, ["a"] = 0.5 }

	local selectedRows = {}

	local linkRow = {}

	if not GYPFilterMenuFrame then
		GYPFilterMenuFrame = CreateFrame("Frame", "GYPFilterMenuFrame", getglobal("UIParent"), "UIDropDownMenuTemplate")
	end


	local function SimpleTime(t)
		local mins = t/60
		local hours = mins/60
		local days = hours/24

		if days > 2 then
			return (math.floor(days*10)/10).." days"
		end

		if mins > 100 then
			return (math.floor(hours*10)/10).." hrs"
		end

		return (math.floor(mins)).." mins"
	end





	local columnHeaders = {
		{
			["name"] = "Player",
			["width"] = 100,
			["bgcolor"] = colorBlack,
			["tooltipText"] = "click to sort\rright-click to filter",
			["onclick"] =	function(button, player)
								local playerString = "player:"..player
								local playerLink = "|Hplayer:"..player.."|h["..player.."]|h"

								SetItemRef(playerString,playerLink,button)
							end,
			["rightclick"] = 	function()
									local x, y = GetCursorPosition()
									local uiScale = UIParent:GetEffectiveScale()

									EasyMenu(playerFilterMenu, GYPFilterMenuFrame, getglobal("UIParent"), x/uiScale,y/uiScale, "MENU", 5)
								end


		}, -- [1]
		{
			["name"] = "Location",
			["width"] = 150,
			["bgcolor"] = colorDark,
			["sortnext"]= 4,
			["tooltipText"] = "click to sort",
			["onclick"] = function(button, player)
								BackgroundSendWho(player)
							end
		}, -- [2]
		{
			["name"] = "Level",
			["width"] = 40,
			["align"] = "CENTER",
			["bgcolor"] = colorBlack,
			["tooltipText"] = "click to sort\rright-click to filter",
			["sortnext"]= 1,
			["rightclick"] = 	function()
									local x, y = GetCursorPosition()
									local uiScale = UIParent:GetEffectiveScale()

									EasyMenu(levelFilterMenu, GYPFilterMenuFrame, getglobal("UIParent"), x/uiScale,y/uiScale, "MENU", 5)
								end
		}, -- [3]
		{
			["name"] = "Trade",
			["width"] = 100,
			["align"] = "CENTER",
			["color"] = { ["r"] = 1.0, ["g"] = 1.0, ["b"] = 0.0, ["a"] = 1.0 },
			["bgcolor"] = colorDark,
			["tooltipText"] = "click to sort\rright-click to filter",
			["sortnext"] = 3,
			["onclick"] =	function(button, link)
								local tradeString = string.match(link, "(trade:%d+:%d+:%d+:[0-9a-fA-F]+:[A-Za-z0-9+/]+)")

								if IsShiftKeyDown() then
									if (ChatFrameEditBox:IsVisible() or WIM_EditBoxInFocus ~= nil) then
										ChatEdit_InsertLink(link)
									else
										DEFAULT_CHAT_FRAME:AddMessage(link)
									end
								elseif IsControlKeyDown() then
									local tradeID, bitmap = string.match(tradeString, "trade:(%d+):%d+:%d+:[0-9a-fA-F]+:([A-Za-z0-9+/]+)")

									tradeID = tonumber(tradeID)

									TradeLink:DumpSpells(Config.spellList[tradeID], bitmap)
								else
									getglobal("GYPFrame"):SetFrameStrata("LOW")

									OpenTradeLink(tradeString)
								end
							end,
			["rightclick"] = 	function()
									local x, y = GetCursorPosition()
									local uiScale = UIParent:GetEffectiveScale()

									EasyMenu(tradeFilterMenu, GYPFilterMenuFrame, getglobal("UIParent"), x/uiScale,y/uiScale, "MENU", 5)
								end

		}, -- [4]
		{
			["name"] = "Age",
			["width"] = 60,
			["align"] = "CENTER",
			["bgcolor"] = colorBlack,
			["defaultsort"] = "asc",
			["sortnext"]= 4,
			["sort"] = "asc",
			["tooltipText"] = "click to sort\rright-click to filter",
			["DoCellUpdate"] =	function (rowFrame, cellFrame, data, cols, row, realrow, column, fShow, ...)
									if fShow then
										local cellData = data[realrow].cols[column];

										local elapsedTime = time() - cellData.value
										local formattedElapsedTime = SimpleTime(elapsedTime)

										if formattedElapsedTime == "" then
											formattedElapsedTime = "NEW"
										end

										cellFrame.text:SetText(formattedElapsedTime)

										local daysOld = (elapsedTime / (60*60*24))
										local cr = min(1,daysOld*.5+.5)
										local cg = min(1,1-min(math.pow(daysOld,2),1)*.8)
										local cb = max(0,min(1,daysOld*(1-daysOld)))*.8+.2

										cellFrame.text:SetTextColor(cr,cg,cb)
									else
										cellFrame.text:SetText("");
									end
								end,
			["rightclick"] = 	function()

									local x, y = GetCursorPosition()
									local uiScale = UIParent:GetEffectiveScale()

									EasyMenu(ageFilterMenu, GYPFilterMenuFrame, getglobal("UIParent"), x/uiScale,y/uiScale, "MENU", 5)
								end
		}, -- [5]
		{
			["name"] = "Chat Message",
			["width"] = 100,
			["align"] = "LEFT",
			["bgcolor"] = colorDark,
			["tooltipText"] = "click to sort",
		}, -- [6]
	};


	local ChatMessageTypes = {
		["CHAT_MSG_SYSTEM"] = true,
		["CHAT_MSG_SAY"] = true,
		["CHAT_MSG_TEXT_EMOTE"] = true,
		["CHAT_MSG_YELL"] = true,
		["CHAT_MSG_WHISPER"] = true,
		["CHAT_MSG_PARTY"] = true,
		["CHAT_MSG_GUILD"] = true,
		["CHAT_MSG_OFFICER"] = true,
		["CHAT_MSG_CHANNEL"] = true,
		["CHAT_MSG_RAID"] = true,
	};


	local function CreateDividerElement(frame, texmap, orientation, size)
		local divider = CreateFrame("Frame",nil,frame)


--TODO: horizontal
		if orientation == "vertical" then
			divider:SetWidth(size)
			divider:SetPoint("TOP", frame, "TOPLEFT", 0,-2)
			divider:SetPoint("BOTTOM", frame, "BOTTOMLEFT", 0,2)

			local t = divider:CreateTexture(nil,"BACKGROUND")
			t:SetTexture(texmap, true)

			t:SetTexCoord(1,.5, 0,.5, 1,1, 0,1)
			t:SetPoint("BOTTOM", divider, "BOTTOM", 0, size)
			t:SetPoint("TOP", divider, "TOP", 0, -size)
			t:SetWidth(size)

			divider.tCenter = t

			t = divider:CreateTexture(nil,"BACKGROUND")
			t:SetTexture(texmap)

			t:SetTexCoord(.5,0, 1,0, .5,.5, 1,.5)
			t:SetPoint("BOTTOM", 0,0)
			t:SetWidth(size)
			t:SetHeight(size)

			divider.tBottom = t


			t = divider:CreateTexture(nil,"BACKGROUND")
			t:SetTexture(texmap)

			t:SetTexCoord(0,0, .5,0, 0,.5, .5,.5)
			t:SetPoint("TOP", 0,0)
			t:SetWidth(size)
			t:SetHeight(size)

			divider.tBottom = t
		end


		return divider
	end

	local function AdjustColumnWidths()
		for i=1,#st.cols do
			local col = st.head.cols[i]

			col.frame:SetWidth(columnHeaders[i].width-2)
		end


--		for j=1,#st.rows do
--			local col = st.rows[j].cols[1]

--			col:SetPoint("LEFT", row, "LEFT", 0, 0);
--		end
	end


	local function ResizeMainWindow()
		if st then
			columnHeaders[6].width =  frame:GetWidth() - 29 - 460

			local rows = floor((frame:GetHeight()-71-15) / 15)


			if rows >= #st.filtered then
				st.scrollframe:Show()
				columnHeaders[6].width = columnHeaders[6].width - 17
			else
				st.scrollframe:Hide()
--				columnHeaders[6].width = columnHeaders[6].width + 17
			end

			st:SetDisplayCols(st.cols)
			st:SetDisplayRows(rows, st.rowHeight)

			AdjustColumnWidths()

			st:Refresh()
		end
	end


	local function PlayerFunctionColor(player)
		if playerLocation[player] and not string.find(playerLocation[player], OFFLINE) then
--DEFAULT_CHAT_FRAME:AddMessage(playerLocation[player].." "..GetMinimapZoneText())
			if playerLocation[player] == GetMinimapZoneText() then
				return localColorTable
			end

			if guildList[player] then
				return guildColorTable
			end

			if friendList[player] then
				return friendColorTable
			end

			return onlineColorTable
		else
			return offlineColorTable
		end
	end


	local function PlayerFunctionLocation(player)
		return playerLocation[player] or "?"
	end

	local function LinkFunctionColor(tradeID, bitmap)
		if currentTradeskill then
			if (tradeID ~= currentTradeskill) then
				return noneSharedColorTable
			else
				if currentSingleTradeBitmap and TradeLink:BitsShared(currentSingleTradeBitmap, bitmap)~=0 then
					return singleSharedColorTable
				end

				if currentTradeBitmap and TradeLink:BitsShared(currentTradeBitmap, bitmap)==0 then
					return noneSharedColorTable
				end
			end

			return sharedColorTable
		end

		return sharedColorTable
	end



	--fnDoCellUpdate(rowFrame, cellFrame, st.data, st.cols, row, st.filtered[row], col, fShow);
	local function TimeDisplayFunction(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, ...)
		if fShow then
			local cellData = data[realrow].cols[column];

			local elapsedTime = time() - cellData.value
			local formattedElapsedTime = SimpleTime(elapsedTime)

			if formattedElapsedTime == "" then
				formattedElapsedTime = "NEW"
			end

			cellFrame.text:SetText(formattedElapsedTime)

			local daysOld = (elapsedTime / (60*60*24))
			local cr = min(1,daysOld*.5+.5)
			local cg = min(1,1-min(math.pow(daysOld,2),1)*.8)
			local cb = max(0,min(1,daysOld*(1-daysOld)))*.8+.2

			cellFrame.text:SetTextColor(cr,cg,cb)
		else
			cellFrame.text:SetText("");
		end


	end


	local function CountRecipes(tradeID)
		if not recipeTotals[tradeID] then
			local c = 0

			for s in pairs(Config.spellList[tradeID]) do
				c = c + 1
			end

			recipeTotals[tradeID] = c
		end

		return recipeTotals[tradeID]
	end


	local function AddToScrollingTable(trade,player,ad)
		if not guildCraftList[player] then

			if not ad.link or not ad.message or not ad.time then
				YPData[serverKey][trade][player] = nil
			else
				local key = trade.."-"..player
				local row = linkRow[key]

				if not row then
					local tradeID,level,bitmap  = string.match(ad.link, "trade:(%d+):(%d+):%d+:[0-9a-fA-F]+:([A-Za-z0-9+/]+)|h")
					tradeID = tonumber(tradeID)

					local basicTrade = GetSpellInfo(basicTradeID[tradeID])

					local compressedBitmap = TradeLink:BitmapCompress(bitmap)

					local basicTrade = GetSpellInfo(basicTradeID[tradeID])
					local recipeCount = TradeLink:CountBits(compressedBitmap)
					local totalRecipes = CountRecipes(basicTradeID[tradeID])

					row = #st.data + 1

					st.data[row] = {}

					st.data[row].auxData = trade.."-"..player

					st.data[row].cols = {
						{value=player, color=PlayerFunctionColor, colorargs={player}, tooltipText = "double-click to whisper player", onclickargs={player}},
						{value=PlayerFunctionLocation, args={player}, color=PlayerFunctionColor, colorargs={player}, onclickargs={player}, tooltipText = "double-click to refresh status"},
						{value=level, tooltipText = recipeCount.." of "..totalRecipes.." known recipes"},
						{value="["..basicTrade.."]", tradeID=basicTradeID[tradeID], onclickargs={ad.link}, color=LinkFunctionColor, colorargs={basicTradeID[tradeID],compressedBitmap}, tooltipText="double-click to open link\rshift-double-click to send to chat"},
						{value=ad.time},
						{value=ad.message}
					}

					linkRow[key] = row
				elseif ad.link ~= st.data[row].cols[4].onclickargs[1] then

					local tradeID,level,bitmap  = string.match(ad.link, "trade:(%d+):(%d+):%d+:[0-9a-fA-F]+:([A-Za-z0-9+/]+)|h")
					tradeID = tonumber(tradeID)

					local basicTrade = GetSpellInfo(basicTradeID[tradeID])

					local compressedBitmap = TradeLink:BitmapCompress(bitmap)

					local basicTrade = GetSpellInfo(basicTradeID[tradeID])
					local recipeCount = TradeLink:CountBits(compressedBitmap)
					local totalRecipes = CountRecipes(basicTradeID[tradeID])

					st.data[row].cols[3].value = level
					st.data[row].cols[3].tooltipText = recipeCount.." of "..totalRecipes.." known recipes"

					st.data[row].cols[4].onclickargs[1]=ad.link
					st.data[row].cols[4].colorargs[2]=compressedBitmap

					st.data[row].cols[5].value = ad.time

					st.data[row].cols[6].value = ad.message
				else
					st.data[row].cols[5].value = ad.time
					st.data[row].cols[6].value = ad.message
				end
			end
		end
	end

	local function BuildSearchWidget()
		local search_widget = CreateFrame("Frame", nil, frame)
		search_widget:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -65)
		search_widget:SetPoint("TOPLEFT", frame, "TOPRIGHT", -200, -30)

		-- Create search box
		local srchbx = CreateFrame("EditBox", nil, search_widget)
		frame.srchbx = srchbx
		srchbx:SetFontObject('GameFontHighlightSmall')
		srchbx:SetText("Search")
		srchbx:SetWidth(70)
		srchbx:SetHeight(13)
		srchbx:SetAutoFocus(false)
		srchbx:SetPoint("TOPLEFT", 0, 0)

		local left = srchbx:CreateTexture(nil, "BACKGROUND")
		left:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Left")
		left:SetTexCoord(0, 100 / 256, 0, 1)
		left:SetWidth(70)
		left:SetHeight(32)
		left:SetPoint("LEFT", srchbx, "LEFT", -10, 0)

		local right = srchbx:CreateTexture(nil, "BACKGROUND")
		right:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Right")
		right:SetTexCoord(156/256, 1, 0, 1)
		right:SetWidth(70)
		right:SetHeight(32)
		right:SetPoint("RIGHT", srchbx, "RIGHT", 10, 0)

		-- create the search button
		local srchbtn = CreateFrame("Button", nil, search_widget, "UIPanelButtonTemplate")
		srchbtn:SetWidth(60)
		srchbtn:SetHeight(25)
		srchbtn:SetText("Search")
		srchbtn:SetPoint("TOPLEFT", 90, 7)
	end

	local function BuildScrollingTable()
--		if not false then return end
		if not st then
			BuildSearchWidget()
			local ScrollPaneBackdrop  = {
				bgFile = "Interface\\AddOns\\GnomishYellowPages\\Art\\newFrameInsetBackground.tga",
				edgeFile = "Interface\\AddOns\\GnomishYellowPages\\Art\\newFrameInsetBorder.tga",
				tile = true, tileSize = 16, edgeSize = 16,
				insets = { left = 3, right = 3, top = 3, bottom = 3 }
			};


			local rows = floor((frame:GetHeight() - 71-15) / 15)
			local LibScrollingTable = LibStub("ScrollingTable")

			st = LibScrollingTable:CreateST(columnHeaders,rows,nil,nil,frame)
			st.frame:SetPoint("BOTTOMLEFT",20,20)
			st.frame:SetPoint("TOP", frame, 0, -65)
			st.frame:SetPoint("RIGHT", frame, -20,0)

			st.LibraryRefresh = st.Refresh


--			SetBetterBackdrop(st.frame,ScrollPaneBackdrop);
--			st.frame:SetBackdropColor(1,1,1,1);

			st.frame:SetBackdrop(nil);





			for i=1,#st.cols do 
				local col = st.head.cols[i]



				col.frame = CreateFrame("Frame", nil, st.frame)
				SetBetterBackdrop(col.frame,ScrollPaneBackdrop)
				col.frame:SetPoint("TOP", st.frame, "TOP", 0,0)
				col.frame:SetPoint("BOTTOM", st.frame, "BOTTOM", 0,0)

				if i > 1 then
					col.frame:SetPoint("LEFT", st.head.cols[i-1], "RIGHT", 0, 0)
				else
					col.frame:SetPoint("LEFT", st.head, "LEFT", 0, 0)
				end

				col:SetPoint("LEFT",(columnHeaders[i].width-3))
			end

			AdjustColumnWidths()



			st.scrollframe:SetScript("OnHide", nil)
			st.scrollframe:SetPoint("TOPLEFT", st.frame, "TOPLEFT", 0, -2)
			st.scrollframe:SetPoint("BOTTOMRIGHT", st.frame, "BOTTOMRIGHT", -20, 2)


			local scrolltrough = getglobal(st.frame:GetName().."ScrollTrough")
			scrolltrough:SetWidth(17)
			scrolltrough:SetPoint("TOPRIGHT", st.frame, "TOPRIGHT", 2, -1);
			scrolltrough:SetPoint("BOTTOMRIGHT", st.frame, "BOTTOMRIGHT", 2, 2);

			st.scrollframe:SetFrameLevel(st.scrollframe:GetFrameLevel()+10)

			st.rows[1]:SetPoint("TOPLEFT", st.frame, "TOPLEFT", 0, -1);
			st.rows[1]:SetPoint("TOPRIGHT", st.frame, "TOPRIGHT", -1, -1);


			st.head:SetPoint("BOTTOMLEFT", st.frame, "TOPLEFT", 2, 2);
			st.head:SetPoint("BOTTOMRIGHT", st.frame, "TOPRIGHT", 0, 2);


			st.frame.noDataFrame = CreateFrame("Frame",nil,st.frame)
			st.frame.noDataFrame:SetAllPoints(st.frame)
			SetBetterBackdrop(st.frame.noDataFrame,ScrollPaneBackdrop);
			st.frame.noDataFrame:Hide()


			local text = st.frame.noDataFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
			text:SetJustifyH("CENTER")
			text:SetPoint("CENTER",0,0)
			text:SetTextColor(1,1,1)
			text:SetText("NO DATA")

			st.data = {}


			st.Refresh = function(st)
				st:LibraryRefresh()

	--[[
				for i=1, 5 do
					if columnHeaders[i].divider then
						if #st.filtered==0 then
							columnHeaders[i].divider:Hide()
						else
							columnHeaders[i].divider:Show()
						end
					end
				end
	]]
				for i=1,st.displayRows do
					local row = i+(st.offset or 0)

					local filteredRow = st.filtered[row]

					if filteredRow and st.data[filteredRow] then
						if selectedRows[st.data[filteredRow].auxData] then
							if i ~= st.mouseOverRow then
								st:SetHighLightColor(st.rows[i],highlightSelected)
							else
								st:SetHighLightColor(st.rows[i],highlightSelectedMouseOver)
							end
						else
							if i ~= st.mouseOverRow then
								st:SetHighLightColor(st.rows[i],highlightOff)
							else
								st:SetHighLightColor(st.rows[i],st:GetDefaultHighlight())
							end
						end
					end
				end
			end

			st:RegisterEvents({
				["OnEvent"] =  function (rowFrame, cellFrame, data, cols, row, realrow, column, st, event, arg1, arg2, ...)
--	DEFAULT_CHAT_FRAME:AddMessage("EVENT "..tostring(event))
					if event == "MODIFIER_STATE_CHANGED" then
						if arg1 == "LCTRL" or arg1 == "RCTRL" then
							frame.keyCapture:EnableKeyboard(arg2==1)
						end
					end
				end,
				["OnEnter"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, st, ...)
	--				frame.keyCapture:EnableKeyboard(true)
--DEFAULT_CHAT_FRAME:AddMessage("onEnter start")
					if row then
--DEFAULT_CHAT_FRAME:AddMessage("row "..row.." realrow "..realrow.." filtered row "..st.filtered[row].." filter row + offet "..st.filtered[row+st.offset])

						cellFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

						if realrow and selectedRows[data[realrow].auxData or 0] then
							st:SetHighLightColor(rowFrame,highlightSelectedMouseOver)
						else
							st:SetHighLightColor(rowFrame,st:GetDefaultHighlight())
						end

						st.mouseOverRow = row

						local cellData = data[realrow].cols[column]

						if st.fencePicking then
							for i=1,#data do
								selectedRows[data[i].auxData] = false
							end

							local rowStart, rowEnd = st.fencePickStart, row + st.offset

							if rowStart > rowEnd then
								rowStart, rowEnd = rowEnd, rowStart
							end

							for i=rowStart, rowEnd do
								local r = st.filtered[i]
								selectedRows[data[r].auxData] = true
							end

							st:Refresh()
						else

							GameTooltip:SetOwner(cellFrame, "ANCHOR_TOPLEFT")

							GameTooltip:ClearLines()

							GameTooltip:AddLine(columnHeaders[column].name,1,1,1,true)

							local value = cellFrame.text:GetText()

							local r,g,b = cellFrame.text:GetTextColor()

							GameTooltip:AddLine(value,r,g,b,true)
							GameTooltip:AddLine(cellData.tooltipText,.7,.7,.7)

							GameTooltip:Show()
						end
					else
						GameTooltip:SetOwner(cellFrame, "ANCHOR_TOPLEFT")

						GameTooltip:ClearLines()

						local value = columnHeaders[column].name

						local r,g,b = 1,1,1

						GameTooltip:AddLine(value,r,g,b,true)
						GameTooltip:AddLine(columnHeaders[column].tooltipText,.7,.7,.7)

						GameTooltip:Show()
					end

					return true
--DEFAULT_CHAT_FRAME:AddMessage("onEnter end")
				end,
				["OnMouseDown"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, st, button, ...)
					if row  then
						if button == "LeftButton" then
							st.fencePicking = true
							st.fencePickStart = row + st.offset
							local r = st.filtered[st.fencePickStart]

							for i=1,#data do
								selectedRows[data[i].auxData] = false
							end

							selectedRows[data[r].auxData] = true

							st:Refresh()
						end
					end
				end,
				["OnMouseUp"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, st, button, ...)
					if row  then
						if button == "LeftButton" then
							st.fencePicking = false
						end
					end
				end,
				["OnLeave"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, st, ...)
--DEFAULT_CHAT_FRAME:AddMessage("onLeave start")
	--				frame.keyCapture:EnableKeyboard(false)
					cellFrame:UnregisterEvent("MODIFIER_STATE_CHANGED")

					if row  then
						if realrow and selectedRows[data[realrow].auxData or 0] then
							st:SetHighLightColor(rowFrame,highlightSelected)
						else
							st:SetHighLightColor(rowFrame,highlightOff)
						end

						if st.mouseOverRow == row then
							st.mouseOverRow = nil
						end

						GameTooltip:Hide()

						st:Refresh()
					else
						GameTooltip:Hide()
					end

					return true
--DEFAULT_CHAT_FRAME:AddMessage("onLeave end")
				end,
				["OnClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, st, button, ...)
					if row then
						if button == "LeftButton" then
							if not IsShiftKeyDown() then
								for i=1,#data do
									selectedRows[data[i].auxData] = false
								end
							end

							selectedRows[data[realrow].auxData] = true

							st:Refresh()
						end
					else
						if button == "RightButton" then
							if columnHeaders[column].rightclick then
								columnHeaders[column].rightclick()
							end
						end
					end
				end,
				["OnDoubleClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, button, st, ...)
					if row then
						local cellData = data[realrow].cols[column]

						if cellData.onclick then
							cellData.onclick(button, unpack(cellData.onclickargs or {}))
						else
							if cols[column].onclick then
								cols[column].onclick(button, unpack(cellData.onclickargs or cols[column].onclickargs or {}))
							end
						end
					end
				end,
			})



			st:SetFilter(function(self, row)
				if currentTradeskill then
					if (row.cols[4].tradeID ~= currentTradeskill) then
						return false
					end
				else
					if selectedTradeskill and (row.cols[4].tradeID ~= selectedTradeskill) then
						return false
					end
				end


				if selectedAge and ((time() - row.cols[5].value)/(60*60*24) > selectedAge) then
					return false
				end

				if not selectedPlayers["OFFLINE"] then
					if not playerLocation[row.cols[1].value] or string.find(playerLocation[row.cols[1].value],OFFLINE) then
						return false
					end
				end

				if not selectedPlayers["STRANGERS"] then
					if not guildList[row.cols[1].value] and not friendList[row.cols[1].value] then
						return false
					end
				end
	--DEFAULT_CHAT_FRAME:AddMessage(type(selectedLevel).." "..tostring(selectedLevel))

				if selectedLevel and tonumber(row.cols[3].value) < selectedLevel then
					return false
				end

				return true
			end)
		end

		local data = st.data


-- GUILD CRAFT INTERFACE
--[[
		if GuildCraft then
			local guildLinks = GuildCraft.db.factionrealm.links

			for player, links in pairs(guildLinks) do
				guildCraftList[player] = ONLINE

				for trade, link in pairs(links) do
					local key = trade.."-"..player

					local tradeID,level,bitmap  = string.match(link, "trade:(%d+):(%d+):%d+:[0-9a-fA-F]+:([A-Za-z0-9+/]+)")
					tradeID = tonumber(tradeID)
					level = tonumber(level)

					local basicTrade = GetSpellInfo(basicTradeID[tradeID])

					local compressedBitmap = TradeLink:BitmapCompress(bitmap)
					local recipeCount = TradeLink:CountBits(compressedBitmap)
					local totalRecipes = CountRecipes(basicTradeID[tradeID])

					local row = linkRow[key]

					if not row then
						row = #st.data + 1

						st.data[row] = {}

						st.data[row].auxData = key

						st.data[row].cols = {
								{value=player, color=PlayerFunctionColor, colorargs={player}, tooltipText = "double-click to whisper player", onclickargs={player}},
								{value=PlayerFunctionLocation, args={player}, color=PlayerFunctionColor, colorargs={player}, onclickargs={player}, tooltipText = "double-click to refresh status"},
								{value=level, tooltipText = recipeCount.." of "..totalRecipes.." known recipes"},
								{value="["..basicTrade.."]", tradeID=basicTradeID[tradeID], onclickargs={link}, color=LinkFunctionColor, colorargs={basicTradeID[tradeID],compressedBitmap}, tooltipText="double-click to open link\rshift-double-click to send to chat"},
								{value=time()},
								{value="guildcraft data"}
							}

						linkRow[key] = row
					else
						st.data[row].cols[3].value = level
						st.data[row].cols[3].tooltipText = recipeCount.." of "..totalRecipes.." known recipes"

						st.data[row].cols[4].onclickargs[1]=link
						st.data[row].cols[4].colorargs[2]=compressedBitmap

						st.data[row].cols[5].value = time()

						st.data[row].cols[6].value="guildcraft data"
					end
				end
			end
		end

]]


		for trade, adList in pairs(YPData[serverKey]) do
			for player, ad in pairs(adList) do
				AddToScrollingTable(trade,player, ad)

			end
		end



--		st:SetData(data)


		st:SortData()
		ResizeMainWindow()
	end


	local function CloseFrame()
		frame:Hide()
	end


	local function ToggleFrame()
		if frame:IsVisible() then
			frame:Hide()
		else
			BuildScrollingTable()
			frame:Show()
		end
	end



	local function GetSizingPoint(frame)
		local x,y = GetCursorPosition()
		local s = frame:GetEffectiveScale()

		local left,bottom,width,height = frame:GetRect()

		x = x/s - left
		y = y/s - bottom

		if x < 10 then
			if y < 10 then return "BOTTOMLEFT" end

			if y > height-10 then return "TOPLEFT" end

			return "LEFT"
		end

		if x > width-10 then
			if y < 10 then return "BOTTOMRIGHT" end

			if y > height-10 then return "TOPRIGHT" end

			return "RIGHT"
		end

		if y < 10 then return "BOTTOM" end

		if y > height-10 then return "TOP" end

		return "UNKNOWN"
	end


	local function CreateResizableWindow(frameName,windowTitle, width, height, resizeFunction)
		frame = CreateFrame("Frame",frameName,UIParent)
		frame:Hide()

		frame:SetFrameStrata("DIALOG")

		frame:SetResizable(true)
		frame:SetMovable(true)
--		frame:SetUserPlaced(true)
		frame:EnableMouse(true)

		if not Config.window then
			Config.window = {}
		end

		if not Config.window[frameName] then
			Config.window[frameName] = { x = 0, y = 0, width = width, height = height}
		end

		local x, y = Config.window[frameName].x, Config.window[frameName].y
		local width, height = Config.window[frameName].width, Config.window[frameName].height


		frame:SetPoint("CENTER",x,y)
		frame:SetWidth(width)
		frame:SetHeight(height)


		SetBetterBackdrop(frame, {
			bgFile = "Interface\\AddOns\\GnomishYellowPages\\Art\\newFrameBackground.tga",
			edgeFile = "Interface\\AddOns\\GnomishYellowPages\\Art\\newFrameBorder.tga",
			tile = true, tileSize = 48, edgeSize = 48,
			insets = { left = 8, right = 8, top = 8, bottom = 8 }
		})

		frame:SetScript("OnSizeChanged", function() resizeFunction() end)

		frame.SavePosition = function(f)
			local frameName = f:GetName()

			if frameName then
				Config.window[frameName].width = f:GetWidth()
				Config.window[frameName].height = f:GetHeight()

				local cx, cy = f:GetCenter()
				local ux, uy = UIParent:GetCenter()

				Config.window[frameName].x = cx - ux
				Config.window[frameName].y = cy - uy
			end
		end

		frame:SetScript("OnMouseDown", function() frame:StartSizing(GetSizingPoint(frame)) end)
		frame:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() frame:SavePosition() end)
		frame:SetScript("OnHide", function() frame:StopMovingOrSizing() frame:SavePosition() end)

		local windowMenu = {
			{ text = "Raise Frame", func = function() frame:SetFrameStrata("DIALOG") end },
			{ text = "Lower Frame", func = function() frame:SetFrameStrata("LOW") end },
		}

		windowMenuFrame = CreateFrame("Frame", "GYPWindowMenuFrame", getglobal("UIParent"), "UIDropDownMenuTemplate")

		local mover = CreateFrame("Frame",nil,frame)
		mover:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
		mover:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)

		mover:EnableMouse(true)

		mover:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				frame:StartMoving()
			else
				local x, y = GetCursorPosition()
				local uiScale = UIParent:GetEffectiveScale()

				EasyMenu(windowMenu, windowMenuFrame, getglobal("UIParent"), x/uiScale,y/uiScale, "MENU", 5)
			end
		end)
		mover:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() frame:SavePosition() end)
		mover:SetScript("OnHide", function() frame:StopMovingOrSizing() frame:SavePosition() end)

		mover:SetHitRectInsets(10,10,10,10)

		frame.mover = mover

		local title = CreateFrame("Frame",nil,frame)

		title:SetHeight(30)

		title.textureLeft = title:CreateTexture()
		title.textureLeft:SetTexture("Interface\\AddOns\\GnomishYellowPages\\Art\\headerTexture.tga")
		title.textureLeft:SetPoint("LEFT",0,0)
		title.textureLeft:SetWidth(60)
		title.textureLeft:SetHeight(30)
		title.textureLeft:SetTexCoord(0, 1, 0, .5)

		title.textureRight = title:CreateTexture()
		title.textureRight:SetTexture("Interface\\AddOns\\GnomishYellowPages\\Art\\headerTexture.tga")
		title.textureRight:SetPoint("RIGHT",0,0)
		title.textureRight:SetWidth(60)
		title.textureRight:SetHeight(30)
		title.textureRight:SetTexCoord(0, 1.0, 0.5, 1.0)


		title.textureCenter = title:CreateTexture()
		title.textureCenter:SetTexture("Interface\\AddOns\\GnomishYellowPages\\Art\\headerTextureCenter.tga", true)
		title.textureCenter:SetHeight(30)
--		title.textureCenter:SetWidth(30)
		title.textureCenter:SetPoint("LEFT",60,0)
		title.textureCenter:SetPoint("RIGHT",-60,0)
		title.textureCenter:SetTexCoord(0.0, 1.0, 0.0, 1.0)

		title:SetPoint("BOTTOM",frame,"TOP",0,0)

		title:EnableMouse(true)

		title:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				frame:StartMoving()
			else
				local x, y = GetCursorPosition()
				local uiScale = UIParent:GetEffectiveScale()

				EasyMenu(windowMenu, windowMenuFrame, getglobal("UIParent"), x/uiScale,y/uiScale, "MENU", 5)
			end
		end)
		title:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() frame:SavePosition() end)
		title:SetScript("OnHide", function() frame:StopMovingOrSizing() frame:SavePosition() end)

		local text = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetJustifyH("CENTER")
		text:SetPoint("CENTER",0,0)
		text:SetTextColor(1,1,.4)
		text:SetText(windowTitle)

		title:SetWidth(text:GetStringWidth()+120)

		local w = title.textureCenter:GetWidth()
		local h = title.textureCenter:GetHeight()
		title.textureCenter:SetTexCoord(0.0, (w/h), 0.0, 1.0)

		frame.title = title
--[[
		local x = frame:CreateTexture(nil,"ARTWORK")

		x:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
		x:SetTexture("Interface/DialogFrame/UI-DialogBox-Corner")
		x:SetWidth(32)
		x:SetHeight(32)
]]
		local closeButton = CreateFrame("Button",nil,frame,"UIPanelCloseButton")
		closeButton:SetPoint("TOPRIGHT",6,6)
		closeButton:SetScript("OnClick", function() frame:Hide() end)
		closeButton:SetFrameLevel(closeButton:GetFrameLevel()+10)
		closeButton:SetHitRectInsets(8,8,8,8)

		return frame
	end


	local bid = 1
	local function CreateToggle(parent, text, value, callback)
		local toggleButton = CreateFrame("CheckButton", "CheckButtonID"..bid, parent, "UICheckButtonTemplate")
		toggleButton.text = getglobal("CheckButtonID"..bid.."Text")

		bid = bid + 1
		toggleButton:SetHeight(24)
		toggleButton:SetWidth(24)

		toggleButton.text:SetText(text)

		if value then
			toggleButton:SetChecked(true)
		end

		toggleButton.value = value


		toggleButton:SetScript("OnClick", function(self)
			self.value = self:GetChecked()

			local kids = { toggleButton:GetChildren() }

			for _, child in ipairs(kids) do
				if self.value then
				 	child:Show()
				else
					child:Hide()
				end
			end

			if callback then
				callback()
			end
		end)

		return toggleButton
	end


	local function CreateSlider(parent, text, min, max, value, units, callback)
		local slider = CreateFrame("Slider", "SliderID"..bid, parent, "OptionsSliderTemplate")
		slider.text = getglobal("SliderID"..bid.."Text")
		slider.textLow = getglobal("SliderID"..bid.."Low")
		slider.textHigh = getglobal("SliderID"..bid.."High")
		bid = bid + 1

		slider.text:SetText(text)
		slider.textLow:SetText(min)
		slider.textHigh:SetText(max)

		slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -30)
		slider:SetWidth(200)
		slider:SetHeight(17)


		slider:SetMinMaxValues(min,max)
		slider:SetValueStep(1)
		slider:SetValue(value)

		slider.tooltipText = value.." "..units
		slider.value = value


		slider:SetScript("OnValueChanged", function(self, value)
			self.tooltipText = value.." "..units
			GameTooltip:ClearLines()
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, 1);
			self.value = value

			if callback then
				callback()
			end
		end)

		return slider
	end


	local function SelectedRowsDelete()
		if selectedRows then
			for key in pairs(selectedRows) do
				if selectedRows[key] then
					local trade, player = string.split("-",key)

					YPData[serverKey][trade][player] = nil

					selectedRows[key] = nil
				end
			end

			selectedRows = {}

			if frame:IsVisible() then
				linkRow = {}
				BuildScrollingTable()
			end
		end
	end


	local function AddToPlayerList(player, age, location)
		if not playerLocation[player] then
			table.insert(playerList, player)

			playerLocation[player] = location
			playerAge[player] = age
		end
	end

	-- sample link
	-- "|cffffd000|Htrade:26790:375:375:544DE6:tz{zgfvUvy_cu{KtpwvUio]Wrs{c[ocGD><<Lt{Mx{Cm=<F<<\\A<B<D<<<<<<<<<<<<<<<|h[Tailoring]|h|r", -- [3]


	local function SaveAdvertisement(player,tradeName,level,link,message)
		local tradeData = YPData[serverKey]
--DEFAULT_CHAT_FRAME:AddMessage("saving ad "..tostring(message).. " "..tostring(player))

		if not tradeData[tradeName] then
			tradeData[tradeName] = {}
		end

		tradeData[tradeName][player] = { ["message"] = message, ["time"] = time(), ["link"] = link, ["level"] = tonumber(level)}

		AddToPlayerList(player, 0, ONLINE)

		if frame:IsVisible() then
--			BuildScrollingTable()
			AddToScrollingTable(tradeName,player,tradeData[tradeName][player])
			st:Refresh()
		end
	end


	local function ChatMessage(message)
		if string.find(message, "|Htrade:") then
--			SaveAdvertisement(message, player)

			for link in string.gmatch(message, "|c%x+|Htrade:%d+:%d+:%d+:[0-9a-fA-F]+:[A-Za-z0-9+/]+|h%[[^]]+%]|h|r") do
				local color,profession,level,playerID,tradeName = string.match(link,"(|c%x+)|Htrade:(%d+):(%d+):%d+:([0-9a-fA-F]+):[A-Za-z0-9+/]+|h%[([^]]+)%]|h|r")

--[[
TODO:

options here would be to black list players or professions and to have a level requirement (like say 250+)

this would help cut down on data overload
]]
				local messageClean = string.gsub(message, "|Htrade:%d+:%d+:%d+:[0-9a-fA-F]+:[A-Za-z0-9+/]+|h","")

				table.insert(tradeLinkQueue, { link, messageClean } )
--DEFAULT_CHAT_FRAME:AddMessage("added message to queue..."..link)

			end
		end
	end


	local function UpdateWhoData()
		local numWhos, totalCount = GetNumWhoResults()

		local tradeData = YPData[serverKey]

		playerLocation[playerWhoPending] = OFFLINE

		for i=1,numWhos do
			local charname, guildname, level, race, class, zone, classFileName = GetWhoInfo(i)
			if charname == playerWhoPending then
				playerWhoPending = ""
			end

			if playerLocation[charname] then
				playerLocation[charname] = zone
			end
		end

		if st then
			st:SortData()
			st:Refresh()
		end

		whoDataPending = false
		SetWhoToUI(0)
		lastWho = time()
	end


	local function InitPlayerLocation()
		for trade,data in pairs(YPData[serverKey]) do
			for player,ad in pairs(data) do
				AddToPlayerList(player, time() - ad.time, OFFLINE)
			end
		end


		table.sort(playerList, function(a,b) return (playerAge[a] or 0)<(playerAge[b] or 0) end)
	end


	local function CreateTimer(name, countDown, triggerFunction, repeatTime)
		timerList[name] = {countDown=countDown, triggerFunction=triggerFunction, repeatTime=repeatTime}
	end


	local function DeleteTimer(name)
		timerList[name] = nil
	end


	local function UpdateHandler(this, elapsed)
		for name,timer in pairs(timerList) do
			timer.countDown = timer.countDown - elapsed
			if timer.countDown <= 0 then
				timer:triggerFunction(timer)

				if timer.repeatTime then
					timer.countDown = timer.countDown + timer.repeatTime
				else
					timerList[name] = nil
				end
			end
		end
	end


	local framesRegistered = {}

	local function TradeSkillUpdate()
--DEFAULT_CHAT_FRAME:AddMessage("TSUPDATE")
		local spells = {}

		for i=1,GetNumTradeSkills() do

			local recipeID = string.match(GetTradeSkillRecipeLink(i) or "","enchant:(%d+)")

			if recipeID then
				spells[tonumber(recipeID)] = true
			end
		end

		currentTradeskill = tradeIDbyName[GetTradeSkillLine()]

		if currentTradeskill then
			local bitmap = TradeLink:BitmapEncode(Config.spellList[currentTradeskill], spells)

			currentTradeBitmap = TradeLink:BitmapCompress(bitmap)
		else
			currentSingleTradeBitmap = nil
		end

		TradeButton:Update(currentTradeskill)

		if st then
			st:SortData()
			st:Refresh()
		end
	end


	local function TradeSkillOpen()
--DEFAULT_CHAT_FRAME:AddMessage("TSOPEN")
		tradeSkillIsOpen = true
	end


	local function TradeSkillClose()
--DEFAULT_CHAT_FRAME:AddMessage("TSCLOSE")
		tradeSkillIsOpen = nil
		currentTradeskill = nil
		currentTradeBitmap = nil
		currentSingleTradeBitmap = nil
		currentTradeLink = nil

		TradeButton:Update(currentTradeskill)

		if st then
			st:SortData()
			st:Refresh()
		end
	end


	local function TradeSkillValidateAndClose()
--DEFAULT_CHAT_FRAME:AddMessage("validate")
		DeleteTimer("validateTimeout")

		if IsTradeSkillLinked() and tradeLinkQueue[1] then
--DEFAULT_CHAT_FRAME:AddMessage("is valid")
			local tradeName, level = GetTradeSkillLine()
			local _,player = IsTradeSkillLinked()

			if tradeName ~= "UNKNOWN" then
				SaveAdvertisement(player,tradeName,tonumber(level),tradeLinkQueue[1][1],tradeLinkQueue[1][2])

				if tradeLinkQueue[1] then
					table.remove(tradeLinkQueue,1)
				end
			else
				if tradeLinkQueue[1] then
					table.remove(tradeLinkQueue,1)			-- delete broken links
				end
			end

			CloseTradeSkill()
		end

		RegisterEvent(master, "TRADE_SKILL_SHOW", TradeSkillOpen)

		for k,f in pairs(framesRegistered) do
			f:RegisterEvent("TRADE_SKILL_SHOW")
		end
	end



	local function TradeLinkValidate(timer)
		if not tradeSkillIsOpen then
			if #tradeLinkQueue > 0 then
				local t = tradeLinkQueue[1]

				local link = t[1]
				local message = t[2]

	--			local tradeString = string.match(link, "(trade:%d+:%d+:%d+:[0-9a-fA-F]+:[A-Za-z0-9+/]+)")
				local tradeString, bitmap = string.match(link, "(trade:%d+:%d+:%d+:[0-9a-fA-F]+):([A-Za-z0-9+/]+)")
				local tradeID = string.match(tradeString, "trade:(%d+):")

				tradeID = tonumber(tradeID)

				if not simpleBitmap[tradeID] then
					simpleBitmap[tradeID] = "//"..string.rep("A", string.len(bitmap)-2)
				end

				framesRegistered = { GetFramesRegisteredForEvent("TRADE_SKILL_SHOW") }

				for k,f in pairs(framesRegistered) do
					f:UnregisterEvent("TRADE_SKILL_SHOW")
				end

				RegisterEvent(master, "TRADE_SKILL_SHOW", TradeSkillValidateAndClose)
				OpenTradeLink(tradeString..":"..simpleBitmap[tradeID])

				CreateTimer("validateTimeout", 1.0, TradeSkillValidateAndClose)
			end
		end
	end




	local previousIndex = 0
	local whoIteration = 0
	local function WhoUpdate(timer)
		if #playerList < 1 then return end

		if not WhoFrame:IsVisible() and #backgroundWho == 0 then
			playerWhoPending = ""

			whoIteration = whoIteration + 1

			local index = previousIndex + 1

			if index > #playerList then
				index = 1
			end

			previousIndex = index

			if not friendList[playerList[index]] and not guildList[playerList[index]] then
				BackgroundSendWho("n-"..playerList[index])
				playerWhoPending = playerList[index]
			else
				timer.countDown = 1 - timer.repeatTime			-- hack to try again in 1 second since this player is not interesting to us
			end
		end
	end


	local function FriendUpdate(timer)
		for i=1,GetNumFriends() do
			local name, level, class, area, connected, status, note = GetFriendInfo(i)

			if name then
				if connected then
					playerLocation[name] = area
				else
					playerLocation[name] = OFFLINE
				end

				friendList[name] = true
			end
		end
	end


	local resetGuildRosterFlag = false
	local function GuildRosterUpdate()
		local members = GetNumGuildMembers(true)

		for i=1,members do
			local name, _, _, _, _, zone, _, _, online, status = GetGuildRosterInfo(i)

			if name then
				if online then
					playerLocation[name] = zone
				else
					local yearsOffline, monthsOffline, daysOffline, hoursOffline = GetGuildRosterLastOnline(i)
					local lastOn

					if yearsOffline == 0 and monthsOffline == 0 then
						if daysOffline > 0 then
							lastOn = (math.floor((daysOffline + hoursOffline/24)*10+5)/10).." days"
						else
							if hoursOffline == 0 then
								lastOn = "not long"
							else
								lastOn = (math.floor(hoursOffline*10+5)/10).." hours"
							end
						end
					else
						lastOn = "ages"
					end

					playerLocation[name] = OFFLINE .. " ("..lastOn..")"
				end

				guildList[name] = true
			end
		end

		guildDataPending = false

		if resetGuildRosterFlag then
			SetGuildRosterShowOffline(false)
			resetGuildRosterFlag = false
		end
	end


	local function GuildUpdate(timer)
		if IsInGuild() and not GuildFrame:IsVisible() then
			if not GetGuildRosterShowOffline() then
				SetGuildRosterShowOffline(true)
				resetGuildRosterFlag = true
			else
				GuildRoster()
			end

			guildDataPending = true
		end
	end


	local function SystemMessageParse(msg)
		if string.find(msg,"^|Hplayer:") then
			local playerLinkID, playerLinkName, level, race, class, guild, zone = string.match(msg, WHO_LIST_GUILD_FORMAT)

			if not zone then
				local _, _, _, _, _, zone = string.match(msg, WHO_LIST_FORMAT)
			end

			if playerLocation[playerLinkName] then
				playerLocation[playerLinkName] = zone
			end

			lastWho = time()
		end
	end


--["link"] = "|cffffd000|Htrade:13920:245:300:2EAC490:4//fb7a8f5Z/muyHPAAAAAAAwAAAAAAAAAAAAAAAAAAAAAAAAA|h[Enchanting]|h|r",

	local function UpdateDatabase(oldList, newList)
		for serverKey, serverData in pairs(YPData) do
			serverData["UNKNOWN"] = nil								-- delete any malformed ads

			for tradeName, tradeData in pairs(serverData) do
				local spellMask = {}

				local tradeID = tradeIDbyName[tradeName]

				if tradeName ~= "UNKNOWN" then
					for player, ad in pairs(tradeData) do
						local tradeInfo,bitmap = string.match(ad.link, "(trade:%d+:%d+:%d+:[0-9a-fA-F]+:)([A-Za-z0-9+/]+)")
--DEFAULT_CHAT_FRAME:AddMessage("UPDATING "..player.." "..ad.link.." "..tostring(tradeID))
						spellMask = TradeLink:BitmapDecode(oldList[tradeID], bitmap, spellMask)

						local newBitmap = TradeLink:BitmapEncode(newList[tradeID], spellMask)

						if newBitmap ~= bitmap then
	--						local xormap = TradeLink:BitmapBitLogic(newBitmap, bitmap, bit.bxor)

	--						TradeLink:DumpSpells(newList, xormap)

							ad.link = "|cffffd000|H"..tradeInfo..newBitmap.."|h["..tradeName.."]|h|r"
						end
					end
				else

				end
			end
		end
	end



	local function InitSystem(spellList)
		local version, build = GetBuildInfo()
		build = tonumber(build)
		Config.dataVersion = tonumber(Config.dataVersion)

		if Config.dataVersion ~= build then
			if not Config.spellList then
				YPData = {}
			else
				UpdateDatabase(Config.spellList, spellList)
			end

			Config.spellList = spellList
		end

		Config.dataVersion = build

		if not YPData then YPData = {} end
		if not YPData[serverKey] then YPData[serverKey] = {} end


		InitPlayerLocation()

		frame = CreateResizableWindow("GYPFrame", "Gnomish Yellow Pages (rev"..VERSION..")", 700, 400, ResizeMainWindow)

		frame:SetMinResize(600,200)

		frame:SetScript("OnEvent", EventHandler)

		SLASH_GNOMISHYELLOWPAGES1 = "/gnomishyellowpages"
		SLASH_GNOMISHYELLOWPAGES2 = "/GYP"
		SLASH_GNOMISHYELLOWPAGES3 = "/yp"
		SLASH_GNOMISHYELLOWPAGES4 = "/yellowpages"
		SlashCmdList["GNOMISHYELLOWPAGES"] = function() ToggleFrame() end

		local oldClose = CloseSpecialWindows

		CloseSpecialWindows = function()
			if not frame:IsVisible() then
				return oldClose()
			else
				frame:Hide()
				return 1
			end
		end

		frame.keyCapture = CreateFrame("Frame", nil, frame)

--		frame.keyCapture:SetPoint("TOPLEFT",0,0)
--		frame.keyCapture:SetPoint("BOTTOMRIGHT",0,0)
--		frame.keyCapture:SetFrameLevel(frame:GetFrameLevel()+50)
--		frame.keyCapture:EnableMouse(true)

		local function keyboardEnabler(eventFrame, event, arg1, arg2)
			if event == "MODIFIER_STATE_CHANGED" then
				if arg1 == "LCTRL" or arg1 == "RCTRL" then
					frame.keyCapture:EnableKeyboard(arg2==1)
				end
			end
		end

		frame.mover:SetScript("OnEnter", function(frame) frame:RegisterEvent("MODIFIER_STATE_CHANGED") end)
		frame.mover:SetScript("OnLeave", function(frame) frame:UnregisterEvent("MODIFIER_STATE_CHANGED") end)
		frame.mover:SetScript("OnEvent", keyboardEnabler)

		frame.keyCapture:SetScript("OnKeyUp", function(frame, key)
			if frame.keyFunctions[key] then
				frame.keyFunctions[key]()
			end

			if not IsControlKeyDown() then
				frame:EnableKeyboard(false)
			end
		end)

		local function DeleteEntries()
			if selectedRows then
				local count = 0

				for k,s in pairs(selectedRows) do
					if s then
						count = count + 1
					end
				end

				if count > 1 then
					UserInputDialog:Show("Okay to delete "..count.." yellow pages entries?", "Okay", SelectedRowsDelete, "Cancel", function () end)
				else
					UserInputDialog:Show("Okay to delete this entry?", "Okay", SelectedRowsDelete, "Cancel", function () end)
				end
			end
		end

		RegisterKeyFunction(frame.keyCapture, "X", DeleteEntries)

		local oldFriendsFrame_OnEvent = FriendsFrame_OnEvent

		FriendsFrame_OnEvent = function (...)
			if event == "WHO_LIST_UPDATE" then
				if not whoDataPending or WhoFrame:IsVisible() then
					oldFriendsFrame_OnEvent(...)
				end
			elseif event == "GUILD_ROSTER_UPDATE" then
				if not guildDataPending or GuildFrame:IsVisible() then
					oldFriendsFrame_OnEvent(...)
				end
			else
				oldFriendsFrame_OnEvent(...)
			end
		end

		BlizzardSendWho = SendWho
		SendWho = PrioritySendWho

		hooksecurefunc("SelectTradeSkill", function(index)
			if index then
				local spells = {}

				local found,_,recipeID = string.find(GetTradeSkillRecipeLink(index) or "","enchant:(%d+)")

				if found then
					spells[tonumber(recipeID)] = true
				end

				currentTradeskill = tradeIDbyName[GetTradeSkillLine()]

				if currentTradeskill then
					local bitmap = TradeLink:BitmapEncode(Config.spellList[currentTradeskill], spells)

					currentSingleTradeBitmap = TradeLink:BitmapCompress(bitmap)
				else
					currentSingleTradeBitmap = nil
				end
			else
				currentSingleTradeBitmap = nil
			end

			if st then
				st:SortData()
				st:Refresh()
			end
		end)

		hooksecurefunc("SetItemRef", function(s,link,button)
			if string.find(s,"trade:") then
				currentTradeLink = link
--DEFAULT_CHAT_FRAME:AddMessage("string = "..s);
			end
		end)

		LoadAddOn("Skillet")

		if Skillet then
			local original_SkilletSetSelectedSkill = Skillet.SetSelectedSkill

			function Skillet:SetSelectedSkill(skillIndex, wasClicked)
				if skillIndex then
					SelectTradeSkill(skillIndex)
				end

				original_SkilletSetSelectedSkill(Skillet,skillIndex, wasClicked)
			end
		end

		local optionsPanel = CreateFrame( "Frame", "GYPConfigPanel", UIParent );

		optionsPanel.name  = "Gnomish Yellow Pages"
		optionsPanel.okay = function(self) end
		optionsPanel.cancel = function(self) end

		InterfaceOptions_AddCategory(optionsPanel);

		local function WhoTimerAdjustment()
			Config["WhoUpdate"] = whoAutoUpdateToggle.value
			Config["WhoFrequency"] = whoAutoUpdateFrequency.value

			if whoAutoUpdateToggle.value then
				CreateTimer("whoUpdater", whoAutoUpdateFrequency.value, WhoUpdate, whoAutoUpdateFrequency.value)
			else
				DeleteTimer("whoUpdater")
			end
		end

		whoAutoUpdateToggle = CreateToggle(optionsPanel, "Auto Update Stranger Locations", Config["WhoUpdate"], WhoTimerAdjustment)
		whoAutoUpdateFrequency = CreateSlider(whoAutoUpdateToggle, "Frequency for Update", 10, 60, Config["WhoFrequency"], "seconds", WhoTimerAdjustment)

		whoAutoUpdateToggle:SetPoint("TOPLEFT", 50,-50)

		WhoTimerAdjustment()

		CreateTimer("friendUpdater", 15, FriendUpdate, 60)
		CreateTimer("guildUpdater", 5, GuildUpdate, 60)
		CreateTimer("ProcessWhoQueue", 1, ProcessWhoQueue, 1)
		CreateTimer("tradeLinkValidate", 5, TradeLinkValidate, 5)

		TradeButton:Create(tradeList, frame)

		RegisterEvent(master, "WHO_LIST_UPDATE", UpdateWhoData)
		RegisterEvent(master, "GUILD_ROSTER_UPDATE", GuildRosterUpdate)
		RegisterEvent(master, "TRADE_SKILL_SHOW", TradeSkillOpen)
		RegisterEvent(master, "TRADE_SKILL_CLOSE", TradeSkillClose)
		RegisterEvent(master, "TRADE_SKILL_UPDATE", TradeSkillUpdate)
		RegisterEvent(master, "CHAT_MSG_SYSTEM", SystemMessageParse)
	end


	local function OnLoad()
		local guid = UnitGUID("player")
		playerGUID = string.gsub(guid,"0x0+", "")

		local version, build = GetBuildInfo()
		build = tonumber(build)

		if not Config then
			Config = { ["WhoUpdate"] = true, ["WhoFrequency"] = 10 }
		end

		Config.dataVersion = tonumber(Config.dataVersion)

		if Config.dataVersion ~= build or not Config.spellList then
			if not GYPSpellData or not GYPSpellData[build] then
				TradeLink:Scan(InitSystem)			-- Scan() calls InitSystem with newly discovered spellList
			else
				InitSystem(GYPSpellData[build])			-- call InitSystem with packaged spell data for this build
			end
		else
			InitSystem(Config.spellList)				-- call InitSystem with the current spell data
		end
	end


	local function ChatEventHandler(message)
		ChatMessage(message)
	end

	for v in pairs(ChatMessageTypes) do
		RegisterEvent(master, v,  ChatEventHandler)
	end

	if not IsAddOnLoaded("AddonLoader") then
		RegisterEvent(master, "PLAYER_ENTERING_WORLD", function()
			CreateTimer("Load", 5, OnLoad)
			master:UnregisterEvent("PLAYER_ENTERING_WORLD")
		end )
	else
		RegisterEvent(master, "ADDON_LOADED", function(addOn)
			if addOn == "GnomishYellowPages" then
				CreateTimer("Load", 5, OnLoad)
				master:UnregisterEvent("ADDON_LOADED")
			end
		end)
--		OnLoad()
	end


--	RegisterEvent(master, "PLAYER_ENTERING_WORLD", function() OnLoad() master:UnregisterEvent("PLAYER_ENTERING_WORLD") end )


	master:SetScript("OnEvent", ParseEvent)
	master:SetScript("OnUpdate", UpdateHandler)
end

