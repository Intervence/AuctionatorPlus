local _, addon = ...
AuctionatorMiniFeatures = addon

local showGlobalPriceChanges = true
local showPlayerPriceChanges = true

-- GLOBALS: _G, AuctionatorMiniFeatures, ITEM_QUALITY_COLORS, AUCTION_CREATOR, UNKNOWN, C_PetJournal, gAtrZC, gAtr_ScanDB, Atr_Col3_Heading, AUCTIONATOR_A_TIPS, ATR_BINDTYPE_UNKNOWN, ATR_CAN_BE_AUCTIONED, AUCTIONATOR_DB_MAXHIST_DAYS, AUCTIONATOR_PRICING_HISTORY
-- GLOBALS: GetMerchantItemLink, GetMerchantItemInfo, GetItemInfo, GetItemIcon, Atr_FindScan, Atr_GetScanDay_Today, Atr_GetBondType, Atr_GetCurrentPane, Atr_GetAuctionBuyout, Atr_SetTextureButton, Atr_HasHistoricalData, Atr_ShowTipWithPricing, Atr_SortHistoryData, ParseHist, Atr_SetTextureButtonByTexture
-- GLOBALS: tonumber, ipairs, pairs, type, string, table

--[[ 	BattlePets	 ]]--
local orig_Atr_GetBondType = Atr_GetBondType
function Atr_GetBondType(itemID)
	if not itemID or type(itemID) ~= "number" then
		return ATR_BINDTYPE_UNKNOWN
	else
		return orig_Atr_GetBondType(itemID)
	end
end

local orig_Atr_GetAuctionBuyout = Atr_GetAuctionBuyout
function Atr_GetAuctionBuyout(item)
	if type(item) == "string" then
		local linkType, id = item:match("^.-H([^:]+):?([^:]*)")
		-- if linkType == "battlepet" then
			-- item = C_PetJournal.GetPetInfoBySpeciesID( tonumber(id) )
		-- end
	end
	return orig_Atr_GetAuctionBuyout(item)
end

-- hooksecurefunc("Atr_SetTextureButton", function(elementName, count, itemLink)
	-- if not itemLink or GetItemIcon(itemLink) then return end
	-- local speciesID = gAtrZC.ItemIDfromLink(itemLink)
		  -- speciesID = speciesID and tonumber( string.sub(speciesID, 4) )
	-- local _, texture = C_PetJournal.GetPetInfoBySpeciesID(speciesID)

	-- Atr_SetTextureButtonByTexture (elementName, count, texture)
-- end)

--[[ 	Data Retrieval	 ]]--
function addon:GetAuctionState(itemLink)
	local itemName = GetItemInfo(itemLink)
	-- if not itemName then
		-- local speciesID = gAtrZC.ItemIDfromLink(itemLink)
			  -- speciesID = speciesID and tonumber( string.sub(speciesID, 4) )
		-- itemName = speciesID and C_PetJournal.GetPetInfoBySpeciesID(-1*speciesID)
	-- end
	if not itemName then return end

	local today = Atr_GetScanDay_Today()

	local auctionCount, referencePrice, isFreshData
	local data = Atr_FindScan(gAtrZC.ItemIDStrfromLink(itemLink), itemName)

	if data and data.whenScanned ~= 0 then
		referencePrice = data.yourWorstPrice
		auctionCount = data.numMatchesWithBuyout
		isFreshData = true
	else
		data = gAtr_ScanDB[itemName]
		referencePrice = data and gAtr_ScanDB[itemName].mr
		--referencePrice = data and (data["L"..today] or data["H"..today])
		auctionCount = referencePrice and -1 or nil
	end

	local previousPrice
	for history = today-1, today - AUCTIONATOR_DB_MAXHIST_DAYS, -1 do
		previousPrice = data and (data["L"..today] or data["H"..history])
		if previousPrice then
			break
		end
	end

	return previousPrice, referencePrice, auctionCount, isFreshData
end

function addon:GetCompareValue(itemLink)
	local itemName = GetItemInfo(itemLink)
	if not itemName then
		local linkType, id = itemLink:match("^.-H([^:]+):?([^:]*)")
		-- if linkType == "battlepet" then
			-- itemName = C_PetJournal.GetPetInfoBySpeciesID( tonumber(id) )
		-- end
	end

	if Atr_HasHistoricalData(itemName) then
		local historyData = {}
		for tag, hist in pairs(AUCTIONATOR_PRICING_HISTORY[itemName]) do
			if tag ~= "is" then
				local when, type, price = ParseHist(tag, hist)
				table.insert(historyData, {
					itemPrice = price,
					when = when
				})
			end
		end
		table.sort(historyData, Atr_SortHistoryData)

		return historyData[1] and historyData[1].itemPrice
	end
end

local up, down = " |TInterface\\BUTTONS\\Arrow-Up-Up:0|t", " |TInterface\\BUTTONS\\Arrow-Down-Up:0|t"
function addon:GetItemPriceInfo(itemLink)
	-- prevPrice = the price seen in previous scans
	local prevPrice, price, numAvailable, freshData = addon:GetAuctionState(itemLink)
	local itemPrice = price or Atr_GetAuctionBuyout(itemLink)
	if not itemPrice then return end

	-- historyData = the price we asked for this item the last time
	local historyData = addon:GetCompareValue(itemLink)

	local changeIndicator = ""
	-- global pricing changes
	if showGlobalPriceChanges then
		if prevPrice and itemPrice > prevPrice then
			changeIndicator = changeIndicator .. "G"..up
		elseif prevPrice and itemPrice < prevPrice then
			changeIndicator = changeIndicator .. "G"..down
		end
	end

	-- player pricing changes
	if showPlayerPriceChanges then
		if historyData and itemPrice > historyData then
			changeIndicator = changeIndicator .. "P"..up
		elseif historyData and itemPrice < historyData then
			changeIndicator = changeIndicator .. "P"..down
		end
	end

	local PriceAfterAHCut = itemPrice * 0.95	
	local priceText = string.format("%s|cFF%s %s   |   %s|r", changeIndicator,
	(numAvailable and numAvailable ~= 0) and "FFFFFF" or "FF0000",
	gAtrZC.priceToMoneyString(itemPrice), gAtrZC.priceToMoneyString(PriceAfterAHCut))

	-- local priceText = string.format("%s|cFF%s%s|r", changeIndicator,
	-- (numAvailable and numAvailable ~= 0) and "FFFFFF" or "FF0000",
	-- itemPrice and gAtrZC.priceToMoneyString(itemPrice) or UNKNOWN)
	-- GetCoinTextureString(itemPrice) or gAtrZC.priceToMoneyString(itemPrice)

	return priceText
end

--[[ 	Data Display	 ]]--
function addon:SetToolipPriceInfo(tip, priceText)
	if not priceText or not tip then return end
	
	if tip.AddLine then
		local aucPriceLine = tip:NumLines()
		_G[tip:GetName() .. "TextRight"..aucPriceLine]:SetText(priceText)
	end
	-- else
		-- if not tip.value then
			-- tip.value = tip:CreateFontString(nil, "ARTWORK", "GameTooltipText")
		-- end
		-- tip.value:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -12, (tip:GetName() == "FloatingBattlePetTooltip") and 36 or 8)
		-- tip.value:SetPoint("TOPRIGHT", tip.PetTypeTexture, "BOTTOMRIGHT", -4, -16)
		-- tip.value:SetText(priceText)
	-- end
end

hooksecurefunc("Atr_STWP_AddAuctionInfo", function(tip, xstring, link, auctionPrice)
	if AUCTIONATOR_A_TIPS ~= 1 then return end

	local itemID = gAtrZC.ItemIDfromLink(link)
		  itemID = tonumber(itemID)
	local bondtype = Atr_GetBondType(itemID)

	if (bondtype == ATR_CAN_BE_AUCTIONED or bondtype == ATR_BINDTYPE_UNKNOWN) and xstring == "" then
		local priceText = addon:GetItemPriceInfo(link)
		addon:SetToolipPriceInfo(tip, priceText)
	end
end)

-- show auctionator tooltip when at a merchant
hooksecurefunc(GameTooltip, "SetMerchantItem", function(tip, merchantID)
	if Atr_ShowTipWithPricing then
		local itemLink = GetMerchantItemLink(merchantID)
		local _, _, _, num = GetMerchantItemInfo(merchantID)
		Atr_ShowTipWithPricing(tip, itemLink, num)
	end
end)

-- show auction owners
hooksecurefunc(AtrScan, "CondenseAndSort", function(self)
	local sorted
	for i, sd in ipairs (self.scanData) do
		-- if self.numMatches > 2 then
			-- sorted = self.sortedData[1]
			-- sorted.owner = "Multiple"
		-- else
			for k = 1, self.numMatches do
				sorted = self.sortedData[k]
				if sd.owner
					and (not sorted.owner or not sorted.owner:find(sd.owner))
					and sorted.stackSize == sd.stackSize and sorted.buyoutPrice == sd.buyoutPrice then
					sorted.owner = (sorted.owner and "Multiple Sellers" or sd.owner)
					-- sorted.owner = (sorted.owner and sorted.owner..", " or "") .. sd.owner
				end
			end		
		--end
		

	end
end)

local columnWidth = 192 -- 140
hooksecurefunc("Atr_ShowCurrentAuctions", function()
	local scan = Atr_GetCurrentPane().activeScan
	if scan.whenScanned == 0 then return end

	local row, rowText, data, spacing, textWidth, lineText
	for i = 1, 12 do
		row = _G["AuctionatorEntry"..i]
		rowText = _G["AuctionatorEntry"..i.."_EntryText"]

		data = scan.sortedData[ row:GetID() ]
		if data and data.owner then
			textWidth = rowText:GetStringWidth()
			spacing = textWidth < columnWidth and "|T"..":1:"..(columnWidth-textWidth).."|t" or ""
			lineText = rowText:GetText()
			--if lineText ~= "" then lineText = lineText .. " " end
			lineText = string.format("%s%s%s", lineText, spacing, data.owner or "")

			rowText:SetText(lineText)
		end
	end

	textWidth = Atr_Col3_Heading:GetStringWidth()
	spacing = textWidth < columnWidth and "|T"..":1:"..(columnWidth-textWidth).."|t" or ""
	Atr_Col3_Heading:SetText( string.format("%s%s%s", Atr_Col3_Heading:GetText(), spacing, AUCTION_CREATOR) )

end)
