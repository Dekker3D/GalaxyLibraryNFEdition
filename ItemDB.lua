local GalaxyLibrary = Apollo.GetAddon("Galaxy Library")
local nScanPerTick = 3000
local nItemDBScan = 250000	-- Will need to be updated on large patches

-- From Tooltips.lua
local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "ItemQuality_Inferior",
	[Item.CodeEnumItemQuality.Average] 			= "ItemQuality_Average",
	[Item.CodeEnumItemQuality.Good] 			= "ItemQuality_Good",
	[Item.CodeEnumItemQuality.Excellent] 		= "ItemQuality_Excellent",
	[Item.CodeEnumItemQuality.Superb] 			= "ItemQuality_Superb",
	[Item.CodeEnumItemQuality.Legendary] 		= "ItemQuality_Legendary",
	[Item.CodeEnumItemQuality.Artifact]		 	= "ItemQuality_Artifact",
}

local tItemDBSubCategoryFormat = {
	[2]			= {"type"},					-- Weapons


	[130]		= {"type"},					-- Amps
	[132]		= {"category", "type"},		-- Runes
}

GalaxyLibrary.tPatchItems = {
	{"Drop 1 to 3",0,50000},
	{"Drop 4",50001,73762}
}

function GalaxyLibrary:ItemDB_OnStartScan()
	-- Display and begin loading screen
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wLoadingScreen:Show(true)
	tPanel.wLoading_Pct:SetText("0%")


	local nCreatureId = 59328
	if math.random(1,100) > 90 then
		nCreatureId = 59331
	end
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:SetCostumeToCreatureId(nCreatureId)	-- :D
	end
	
	local filterFiller = tPanel.wnd:FindChild("FilterFiller")
	filterFiller:SetCostumeToCreatureId(22075)
	filterFiller:SetSpin(330)
	filterFiller:SetModelSequence(625) -- Default_Sleep
	
	--Filters
	table.insert(self.tPatchItems, {"Newest Items",self.tPatchItems[#self.tPatchItems][2]+1, nItemDBScan})
	for _, tPatch in pairs(self.tPatchItems) do
		--tPatch = {"strId",nStart,nEnd}
		local wndPatch = Apollo.LoadForm(self.xmlPanelsDoc, "ItemDBPatchFilter", tPanel.wnd:FindChild("Filters:PatchFilters"), self)
		wndPatch:SetText(tPatch[1])
		wndPatch:SetData(tPatch)
		wndPatch:Enable(true)
	end
	tPanel.wnd:FindChild("Filters:PatchFilters"):ArrangeChildrenVert()
end

function GalaxyLibrary:ItemDB_OnScan2()
	local tPanel = self:GetPanel("ItemDB", true)

	if tPanel.nScanIndex < nItemDBScan then
		local nLastIndex = math.min(tPanel.nScanIndex+nScanPerTick, nItemDBScan)
		for i=tPanel.nScanIndex+1, nLastIndex do
			local item = Item.GetDataFromId(i)
			if item then
				-- TEMP COMPATABILITY
				local category = item:GetItemCategoryName()
				if not category or category == "" then 
					category = item:GetItemFamilyName()
					if not category or category == "" then
						category = item:GetItemTypeName()
					end
				end
				if not tPanel.tDatabase[category] then
					tPanel.tDatabase[category] = {}
				end
				if not tPanel.tCategoriesByName[category] then --REDO THE RECEIVER FOR THIS.
					tPanel.tCategoriesByName[category] = true
				end
				-- TEMP COMPATABILITY
	
				local iFamilyId = item:GetItemFamily()
				local iTypeId = item:GetItemType()
				local iCategoryId = item:GetItemCategory()
				
				local sFamilyName = item:GetItemFamilyName()
				local sTypeName = item:GetItemTypeName()
				local sCategoryName = item:GetItemCategoryName()				
				
				
				local itemEntry = {
					id=i,
					item = item,
					name = item:GetName(),
					quality = Item.GetItemQuality(i),
					level = item:GetRequiredLevel(),
					powerlevel = item:GetPowerLevel(),
					
					iFamilyId = iFamilyId,
					iTypeId = iTypeId,
					iCategoryId = iCategoryId,
					
					category = category, -- TEMP COMPATABILITY
				}
				
				local tItemPlacementInfo = {
					iFamilyId = iFamilyId,
					iTypeId = iTypeId,
					iCategoryId = iCategoryId,
	
					sFamilyName = sFamilyName,
					sTypeName = sTypeName,
					sCategoryName = sCategoryName,
				}
				
				table.insert(tPanel.tDatabase[category], itemEntry)
				self:ItemDB_AddPlacementInfo(tItemPlacementInfo)
			end
		end
		
		
		tPanel.nScanIndex = nLastIndex
			
		-- Update pct
		local pct = string.format("%0.0f", (tPanel.nScanIndex / nItemDBScan) * 100)
		tPanel.wLoading_Pct:SetText(pct.."%")
	else
		self:StopTimer("ItemDB", "ItemScanner")
	end
end

local strCurrCategory = ""
function GalaxyLibrary:ItemDBCategorySelect2()
	if self.timerDelayLoad then
		self.timerDelayLoad:Stop()
		self.timerDelayLoad = nil
	end
	
	self:RefreshPage()
end

function GalaxyLibrary:RefreshPage()
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wItemScroller:DestroyChildren()
	tPanel.wItemScroller:SetVScrollPos(0)
	
	if tPanel.tDatabase[self.selectedCategory] then
		strCurrCategory = self.selectedCategory
		local tItems = tPanel.tDatabase[self.selectedCategory]
		
		local nStart = nil
		local nEnd = nil
		tItems, nStart, nEnd = self:GetItemPage(tItems, tPanel.nPageStart, true)
		tPanel.nPageEnd = nEnd or 1
		
		self:DelayLoadItems(tItems)
	end
end

function GalaxyLibrary:OnNextPage()
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wItemScroller:DestroyChildren()
	tPanel.wItemScroller:SetVScrollPos(0)
	
	if tPanel.tDatabase[self.selectedCategory] then
		strCurrCategory = self.selectedCategory
		local tItems = tPanel.tDatabase[self.selectedCategory]
		
		local nStart = nil
		local nEnd = nil
		tItems, nStart, nEnd = self:GetItemPage(tItems, tPanel.nPageEnd + 1, true)
		tPanel.nPageStart = nStart or 1
		tPanel.nPageEnd = nEnd or 1
		
		self:DelayLoadItems(tItems)
	end
	if tPanel.nPageStart ~= nil then tPanel.wPageID:SetText(tPanel.nPageStart) end
end


function GalaxyLibrary:OnPreviousPage()
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wItemScroller:DestroyChildren()
	tPanel.wItemScroller:SetVScrollPos(0)
	
	if tPanel.tDatabase[self.selectedCategory] then
		strCurrCategory = self.selectedCategory
		local tItems = tPanel.tDatabase[self.selectedCategory]
		
		local nStart = nil
		local nEnd = nil
		tItems, nStart, nEnd = self:GetItemPage(tItems, tPanel.nPageStart - 1, false)
		tPanel.nPageStart = nStart or 1
		tPanel.nPageEnd = nEnd or 1
		
		self:DelayLoadItems(tItems)
	end
	if tPanel.nPageStart ~= nil then tPanel.wPageID:SetText(tPanel.nPageStart) end
end

function GalaxyLibrary:OnPageIDChanged(wndHandler, wndControl, strFilterName)
	local _txt = wndControl:GetText()
	if _txt ~= nil and _text ~= "" then
		_txt = tonumber(_txt)
		if _txt ~= nil and _txt >= 0 then
			local tPanel = self:GetPanel("ItemDB", true)
			tPanel.nPageStart = _txt
			self:RefreshPage()
		end
	end
end

function GalaxyLibrary:DelayLoadItems(tItems)
	local tPanel = self:GetPanel("ItemDB", true)
	for _,tItem in pairs(tItems) do	
		local wnd = Apollo.LoadForm(self.xmlPanelsDoc, "ItemDatabaseItem", tPanel.wItemScroller, self)
		wnd:FindChild("Icon"):SetSprite(tItem.item:GetIcon())
		wnd:FindChild("Label"):SetText(tItem.id..":"..tItem.name)
		wnd:FindChild("Label"):SetTextColor(karEvalColors[tItem.quality])
		wnd:SetData(tonumber(tItem.id))
	end
	
	tPanel.wItemScroller:ArrangeChildrenVert()
	tPanel.wItemScroller:Show(true)
end

---Name Filter---------------------------------------------------------------------------------
local strNameFilter = ""
local bNameFilterEnabled = false

local function nocase (s)
  s = string.gsub(s, "%a", function (c)
        return string.format("[%s%s]", string.lower(c),
                                       string.upper(c))
      end)
  return s
end

function GalaxyLibrary:OnFilterNameChanged( wndHandler, wndControl, strFilterName )
	strNameFilter = nocase(strFilterName)
	if strNameFilter == nil or strNameFilter == "" then
		bNameFilterEnabled = false
	else
		bNameFilterEnabled = true
	end
	self:RefreshPage()
end

---Quality Filter------------------------------------------------------------------------------
local tQualityFilter = {}
local bQualityFilterEnabled = false

function GalaxyLibrary:QualityFilterChange( wndHandler, wndControl, eMouseButton )
	local bChecked = wndHandler:IsChecked()
	local eQuality = Item.CodeEnumItemQuality[wndHandler:GetName()]
	tQualityFilter[eQuality] = bChecked
	
	bQualityFilterEnabled = false
	for _, qual in pairs(tQualityFilter) do
		if qual == true then
			bQualityFilterEnabled = true
			break
		end
	end
	
	self:RefreshPage()
end

---Level Filter--------------------------------------------------------------------------------
local nMinLevelFilter = nil
local nMaxLevelFilter = nil

local nMinPowerLevelFilter = nil
local nMaxPowerLevelFilter = nil

function GalaxyLibrary:OnMinLevelChange( wndHandler, wndControl, eMouseButton )
	local _txt = wndControl:GetText()
	if _txt == nil then
		nMinLevelFilter = nil
		return
	end
	nMinLevelFilter = tonumber(_txt)
	self:RefreshPage()
end

function GalaxyLibrary:OnMaxLevelChange( wndHandler, wndControl, eMouseButton )
	local _txt = wndControl:GetText()
	if _txt == nil then
		nMaxLevelFilter = nil
		return
	end
	nMaxLevelFilter = tonumber(_txt)
	self:RefreshPage()
end

function GalaxyLibrary:OnMinPowerLevelChange( wndHandler, wndControl, eMouseButton )
	local _txt = wndControl:GetText()
	if _txt == nil then
		nMinPowerLevelFilter = nil
		return
	end
	nMinPowerLevelFilter = tonumber(_txt)
	self:RefreshPage()
end

function GalaxyLibrary:OnMaxPowerLevelChange( wndHandler, wndControl, eMouseButton )
	local _txt = wndControl:GetText()
	if _txt == nil then
		nMaxPowerLevelFilter = nil
		return
	end
	nMaxPowerLevelFilter = tonumber(_txt)
	self:RefreshPage()
end

---Omega Filter--------------------------------------------------------------------------------
local itemsPerPage = 11
function GalaxyLibrary:GetItemPage(tItems, ID, forward)
	local start = 1
	local stop = #tItems
	local step = 1
	if not forward then
		start = stop
		stop = 1
		step = -1
	end
	
	local foundItems = {}
	
	local firstID = nil
	local lastID = nil
	
	for i = start, stop, step do
		local item = tItems[i]
		if forward and item.id >= ID and self:OmegaFilter(item) then
			table.insert(foundItems, item)
			lastID = item.id
			if firstID == nil then firstID = lastID end
		end
		if (not forward) and item.id <= ID and self:OmegaFilter(item) then
			table.insert(foundItems, 1, item)
			lastID = item.id
			if firstID == nil then firstID = lastID end
		end
		if #foundItems >= itemsPerPage then break end
	end
	
	if not forward then
		local tmp = firstID
		firstID = lastID
		lastID = tmp
	end
	
	return foundItems, firstID, lastID
end

function GalaxyLibrary:OmegaFilter(item)
	if item == nil then return false end
	if (not bNameFilterEnabled) or (item.name ~= nil and item.name:find(strNameFilter)) then				--Name filter
		if (not bQualityFilterEnabled) or tQualityFilter[item.quality] then									--Quality filter
			if nMinLevelFilter == nil or (item.level ~= nil and item.level >= nMinLevelFilter) then			--Level filter
				if nMaxLevelFilter == nil or (item.level ~= nil and item.level <= nMaxLevelFilter) then		--Level filter
					if nMinPowerLevelFilter == nil or (item.powerlevel ~= nil and item.powerlevel >= nMinPowerLevelFilter) then			--Level filter
						if nMaxPowerLevelFilter == nil or (item.powerlevel ~= nil and item.powerlevel <= nMaxPowerLevelFilter) then		--Level filter
							return true
						end
					end
				end
			end
		end
	end
	return false
end
