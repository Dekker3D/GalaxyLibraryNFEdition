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
local nItemDisplayThreshold = 5000
function GalaxyLibrary:ItemDBCategorySelect2(sCategory)
	if self.timerDelayLoad then
		self.timerDelayLoad:Stop()
		self.timerDelayLoad = nil
	end
	
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wItemScroller:DestroyChildren()
	tPanel.wItemScroller:SetVScrollPos(0)
	
	local nItems = 0
	if tPanel.tDatabase[sCategory] then
		strCurrCategory = sCategory
		local bFilters, tItems = self:OmegaFilter(tPanel.tDatabase[sCategory])
		
		if #tItems >= nItemDisplayThreshold then
		--if #tPanel.tDatabase[sCategory] >= nItemDisplayThreshold then
			--show the warning screen for filters or force load (possibility of crash)
			local wndWarning = Apollo.LoadForm(self.xmlPanelsDoc, "HighLoadWarning", tPanel.wItemScroller, self)
			local strWarning =	"A filter is suggested for this category.".."\n"..
								"".."\n"..
								"This category has a high number of items. Loading it may cause the game to crash and/or perform slowly while viewing items. Filtering before loading will resolve this issue. Would you like to load anyways?"
			wndWarning:FindChild("WarningText"):SetText(strWarning)
			wndWarning:FindChild("LoadAnywayBtn"):SetData("DelayLoadCategory")
		else
			if bFilters then
				self:DelayLoadItems(tItems)
			else
				self:DelayLoadCategory()
			end
		end
	end
	--tPanel.wItemScroller:ArrangeChildrenVert()
	--tPanel.wItemScroller:Show(nItems > 0)
end

function GalaxyLibrary:OnLoadAnyway( wndHandler, wndControl, eMouseButton )
	local strFunction = wndHandler:GetData()
	if strFunction then
		--Print(strFunction)
		self[strFunction](self)
	end
end

local nTicks = 0
local nScanPerTick = 1000
local tLoadItems = {}
function GalaxyLibrary:DelayLoadCategory()
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wItemScroller:DestroyChildren()
	tPanel.wItemScroller:SetVScrollPos(0)
		
	nTicks = 0
	self:OnDelayLoadCategory()
end

function GalaxyLibrary:OnDelayLoadCategory()
	local tPanel = self:GetPanel("ItemDB", true)
	local nMax = math.min((nTicks+1)*nScanPerTick, #tPanel.tDatabase[strCurrCategory])
	
	for idx=nTicks*nScanPerTick+1, nMax do
		local tItem = tPanel.tDatabase[strCurrCategory][idx]
		local wnd = Apollo.LoadForm(self.xmlPanelsDoc, "ItemDatabaseItem", tPanel.wItemScroller, self)
		wnd:FindChild("Icon"):SetSprite(tItem.item:GetIcon())
		wnd:FindChild("Label"):SetText(tItem.id..":"..tItem.name)
		wnd:FindChild("Label"):SetTextColor(karEvalColors[tItem.quality])
		wnd:SetData(tonumber(tItem.id))
	end
	
	tPanel.wItemScroller:ArrangeChildrenVert()
	tPanel.wItemScroller:Show(true)
	
	if nMax >= #tPanel.tDatabase[strCurrCategory] then
		if self.timerDelayLoad then
			self.timerDelayLoad:Stop()
			self.timerDelayLoad = nil
			tPanel.wLoadingScreen:Show(false)
		end
	else
		if not self.timerDelayLoad then
			tPanel.wLoadingScreen:Show(true)
			tPanel.wLoading_Pct:SetText("0%")
			self.timerDelayLoad = ApolloTimer.Create(1,true,"OnDelayLoadCategory",self)
		end
		nTicks = nTicks+1
		local pct = string.format("%0.0f", (nTicks*nScanPerTick/#tPanel.tDatabase[strCurrCategory]) * 100)
		tPanel.wLoading_Pct:SetText(pct.."%")
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

function GalaxyLibrary:QualityFilterChange( wndHandler, wndControl, eMouseButton )
	local bChecked = wndHandler:IsChecked()
	local eQuality = Item.CodeEnumItemQuality[wndHandler:GetName()]
	tQualityFilter[eQuality] = bChecked
	
	self:FilterByQuality()
end

function GalaxyLibrary:FilterByQuality(strName)
	local tPanel = self:GetPanel("ItemDB", true)
	
	for _,wnd in pairs(tPanel.wItemScroller:GetChildren()) do
		local item = Item.GetDataFromId(wnd:GetData())
		if item then --TODO: WTF???? It should be existing.
			if tQualityFilter[item:GetItemQuality()] then
				wnd:Show(true)
			else
				wnd:Show(false)
			end
		end
	end
	tPanel.wItemScroller:ArrangeChildrenVert()
end

---Level Filter--------------------------------------------------------------------------------
local nLowLevelFilter = 0
local nHighLevelFilter = 0

---Omega Filter--------------------------------------------------------------------------------
function GalaxyLibrary:OmegaFilter(tItems)
	local bFiltered = false
	local tFilteredItems = {}
	if strNameFilter ~= "" and strNameFilter ~= nil then
		bFiltered = true
	end
	for key,val in pairs(tQualityFilter) do
		bFiltered = true
		break
	end
	
	for _,item in pairs(tItems) do
		if item.name:find(nocase(strNameFilter)) then											--Name filter
			if tQualityFilter[item.quality] == nil or tQualityFilter[item.quality] then												--Quality filter
				--if item.level >= nLowLevelFilter and item.level <= nHighLevelFilter then		--Level filter
					table.insert(tFilteredItems, item)
				--end
			end
		end
	end
	
	return bFiltered, tFilteredItems
end
