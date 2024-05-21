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
	if math.random(1,100) > 75 then
		nCreatureId = 59331
	end
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:SetCostumeToCreatureId(nCreatureId)	-- :D
	end
	
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
		if (self:HasFiltersEnabled()) then
			tItems = self:OmegaFilter(tItems)
		end
		
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
		if (self:HasFiltersEnabled()) then
			tItems = self:OmegaFilter(tItems)
		end
		
		local nStart = nil
		local nEnd = nil
		tItems, nStart, nEnd = self:GetItemPage(tItems, tPanel.nPageEnd + 1, true)
		tPanel.nPageStart = nStart or 1
		tPanel.nPageEnd = nEnd or 1
		
		self:DelayLoadItems(tItems)
	end
end


function GalaxyLibrary:OnPreviousPage()
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wItemScroller:DestroyChildren()
	tPanel.wItemScroller:SetVScrollPos(0)
	
	if tPanel.tDatabase[self.selectedCategory] then
		strCurrCategory = self.selectedCategory
		local tItems = tPanel.tDatabase[self.selectedCategory]
		if (self:HasFiltersEnabled()) then
			tItems = self:OmegaFilter(tItems)
		end
		
		local nStart = nil
		local nEnd = nil
		tItems, nStart, nEnd = self:GetItemPage(tItems, tPanel.nPageStart - 1, false)
		tPanel.nPageStart = nStart or 1
		tPanel.nPageEnd = nEnd or 1
		
		self:DelayLoadItems(tItems)
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
	
	if tPanel.nPageStart ~= nil then tPanel.wPageID:SetText(tPanel.nPageStart) end
end

---Name Filter---------------------------------------------------------------------------------
local strNameFilter = ""

function GalaxyLibrary:OnFilterNameChanged( wndHandler, wndControl, strFilterName )
	strNameFilter = strFilterName
	self:FilterByName()
end

local function nocase (s)
  s = string.gsub(s, "%a", function (c)
        return string.format("[%s%s]", string.lower(c),
                                       string.upper(c))
      end)
  return s
end

function GalaxyLibrary:FilterByName()
	local tPanel = self:GetPanel("ItemDB", true)
	
	for _,wnd in pairs(tPanel.wItemScroller:GetChildren()) do
		if string.find(wnd:FindChild("Label"):GetText(), nocase(strNameFilter)) then
			wnd:Show(true)
		else
			wnd:Show(false)
		end
	end
	tPanel.wItemScroller:ArrangeChildrenVert()
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
local nLowLevelFilter = 0
local nHighLevelFilter = 0

---Omega Filter--------------------------------------------------------------------------------
function GalaxyLibrary:HasFiltersEnabled()
	local bFiltered = false
	if strNameFilter ~= "" and strNameFilter ~= nil then
		bFiltered = true
	end
	for key,val in pairs(tQualityFilter) do
		bFiltered = true
		break
	end
end

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
	if item.name:find(nocase(strNameFilter)) then											--Name filter
		if (not bQualityFilterEnabled) or tQualityFilter[item.quality] then												--Quality filter
			--if item.level >= nLowLevelFilter and item.level <= nHighLevelFilter then		--Level filter
				return true
			--end
		end
	end
	return false
end
