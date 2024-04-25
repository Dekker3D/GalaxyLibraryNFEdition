-----------------------------------------------------------------------------------------------
-- Client Lua Script for GalaxyLibrary
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
-- By: Lemon King
-- Modified By: Xan the Dragon // Eti the Spirit // Gyro Egan to add a button to give an item to the user.

require "Item"
require "Window"
require "ChatSystemLib"
 
--[[
Exploration:
Item Browser
NPC Listing
Zone Browser
Ability Detail

Lore:
Galactic Archive (Articles)
Zone Lore (Datacubes)
--]]

-----------------------------------------------------------------------------------------------
-- GalaxyLibrary Module Definition
-----------------------------------------------------------------------------------------------
local GalaxyLibrary = {} 

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local nScanPerTick = 3000
local nItemDBScan = 250000	-- Will need to be updated on large patches
local iDatacubeId = 11098
local iDatacubeAnimSequence = 1120
local nEntryButton = 6
local tPanelDefinitions = {
	-- Entry Menu Panel
	[0] = {id="EntryMenu",											xml=nil,		form="EntryMenuPanel",												},

	-- Sub Menu Panels
	{id="ItemDB", 		label="Item Database",		index=1,	xml=nil,		form="ItemDatabasePanel",
						strTimer="ItemScanner",		nInterval=1/30,				bContinuous=true,			
						funcOnLoop="ItemDB_OnScan2",	funcOnStart="ItemDB_OnStartScan", funcOnStop="ItemDB_OnStopScan",						enabled=true	},
							
	{id="NPCViewer",		label="Creature Viewer",	index=2,	xml=nil,		form=nil,					timer=nil,					enabled=false	},
	{id="MapViewer",		label="Nexus Cartographer",	index=3,	xml=nil,		form=nil,					timer=nil,					enabled=false	},
	{id="AbilityDB",		label="Ability Database",	index=4,	xml=nil,		form=nil,					timer=nil,					enabled=false	},
	{id="Articles",			label="Galactic Archive",	index=5,	xml=nil,		form=nil,					timer=nil,					enabled=false	},
	{id="ZoneLore",			label="Nexus Lore",			index=6,	xml=nil,		form=nil,					timer=nil,					enabled=false	},
}

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

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function GalaxyLibrary:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	self.scanlimit = iScan
	self.sheathed = false
	self.wndList = nil

	
	
	-- new variables 2.0
	self.selectedPanelId = nil
	self.wnd = {}
	self.wPanels = {}
	self.timers = {}
	self.LatestSelectedCostumeItemId = -1
	self.PrintCurrentItem = false
	
	self.tLoadErrors = {} -- If any exist


    return o
end

function GalaxyLibrary:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- GalaxyLibrary OnLoad
-----------------------------------------------------------------------------------------------
function GalaxyLibrary:OnLoad()
	-- Register Event Handlers
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("AddonEvent_ToggleGalaxyLibrary", "OnToggleGalaxyLibrary", self)
	
	self.xmlPanelsDoc = XmlDoc.CreateFromFile("Panels.xml")
	self.xmlPanelsDoc:RegisterCallback("OnMainDocumentReady", self)
end

-----------------------------------------------------------------------------------------------
-- GalaxyLibrary OnMainDocumentReady
-----------------------------------------------------------------------------------------------
function GalaxyLibrary:OnMainDocumentReady()
    -- Register handlers for events, slash commands and timer, etc.
    Apollo.RegisterSlashCommand("galaxylibrary", "OnGalaxyLibrarySlash", self)
    Apollo.RegisterSlashCommand("gallib", "OnGalaxyLibrarySlash", self)
    Apollo.RegisterSlashCommand("gl", "OnGalaxyLibrarySlash", self)
    Apollo.RegisterSlashCommand("lkl", "OnGalaxyLibrarySlash", self)
	Apollo.RegisterSlashCommand("glprintitem", "OnGalaxyLibraryPrintItemToggle", self)

    -- load our forms
    self.wnd.Main = Apollo.LoadForm(self.xmlPanelsDoc, "GalaxyLibraryMain", nil, self)
    self.wnd.Main:Show(false)
	self.wnd.MainContainer = self.wnd.Main:FindChild("Container")
	self.wnd.BackButton = self.wnd.Main:FindChild("BackButton")
	
	for i=0, #tPanelDefinitions do
		local tPanel = tPanelDefinitions[i]
		local sId = tPanel.id
		local sForm = tPanel.form
		local wndParent = self.wnd["MainContainer"]
		local nButtonIndex = tPanel.index
		local sLabel = tPanel.label
		local fOnLoad = self[tPanel.id.."OnLoad"]
		local fOnUnload = self[tPanel.id.."OnUnload"]
		
		if sForm and wndParent then
			local wnd = Apollo.LoadForm(self.xmlPanelsDoc, sForm, wndParent, self)	
			self.wPanels[sId] = { wnd = wnd }			
			wnd:Show(false)
			
			self.timers[sId] = {}
			if tPanel.strTimer then
				self:CreateTimer(sId, tPanel.strTimer, tPanel.nInterval, tPanel.bContinuous, {
							funcOnLoop=tPanel.funcOnLoop,
							funcOnStart=tPanel.funcOnStart,
							funcOnStop=tPanel.funcOnStop
						})
			end
			
		end
		
		-- Do Button Generation
		if nButtonIndex and sLabel then
			local tPanelEntryMenu = self:GetPanel("EntryMenu", true)
			local btnContainer = tPanelEntryMenu.ButtonContainer:FindChild(tostring(nButtonIndex))
			local wnd = Apollo.LoadForm(self.xmlPanelsDoc, "EntryMenuButton", btnContainer, self)
			local btn = wnd:FindChild("btnMain")
			tPanelEntryMenu.wButtons[nButtonIndex] = { 
				wnd  = wnd,
				button = btn,
			}
			btn:SetData(sId)
			btn:SetText(sLabel)
			btn:Enable(tPanel.enabled)
			if nButtonIndex % 2 == 0 then
				btn:ChangeArt("BK3:btnMetal_TabMainRight")
			end
		end
		
		-- Run OnLoad
		if fOnLoad then
			fOnLoad(self)
		--else
		--	table.insert(self.tLoadErrors, "WARNING! No OnLoad Script found for "..sLabel)
		end
		--if not fOnUnload then
		--	table.insert(self.tLoadErrors, "WARNING! No OnUnload Script found for "..sLabel)
		--end
	end
end

-----------------------------------------------------------------------------------------------
-- GalaxyLibrary Main Functions
-----------------------------------------------------------------------------------------------
function GalaxyLibrary:OnBackButtonSignal( wndHandler, wndControl, eMouseButton )
	self:SetActivePanel("EntryMenu")
end

-- when the Close button is clicked
function GalaxyLibrary:OnClose()
	self.wnd.Main:Show(false) -- hide the window
end

-----------------------------------------------------------------------------------------------
-- GalaxyLibrary Main Event Functions
-----------------------------------------------------------------------------------------------
function GalaxyLibrary:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "Galaxy Library", {"AddonEvent_ToggleGalaxyLibrary", "", "Icon_Windows_UI_CRB_Attribute_Random1"})
end

function GalaxyLibrary:OnToggleGalaxyLibrary()
	self:OnGalaxyLibrarySlash()	-- Hack
end

-----------------------------------------------------------------------------------------------
-- GalaxyLibrary Timer Manager
-----------------------------------------------------------------------------------------------
function GalaxyLibrary:CreateTimer(strOwner, strName, nInterval, bContinuous, tFunctions)
	local strTimerName = "Timer_"..strOwner.."."..strName
	Apollo.RegisterTimerHandler(strTimerName, tFunctions.funcOnLoop, self)
	Apollo.CreateTimer(strTimerName, nInterval, bContinuous)
	Apollo.StopTimer(strTimerName)
	
	self.timers[strOwner][strName] = { strTimerName = strTimerName, bActive = false, tFunc = tFunctions }
end

function GalaxyLibrary:GetTimer(sOwner, sName)
	if sOwner and sName then
		local tOwner = self.timers[sOwner]
		if tOwner then
			local tTimer = tOwner[sName]
			return tTimer
		end
	end
end

function GalaxyLibrary:StartTimer(sOwner, sName)
	local tTimer = self:GetTimer(sOwner, sName)
	if tTimer and not tTimer.bActive then
		if self[tTimer.tFunc.funcOnStart] then
			self[tTimer.tFunc.funcOnStart](self)
		end
		Apollo.StartTimer(tTimer.strTimerName)
		tTimer.bActive = true
	end
end

function GalaxyLibrary:StopTimer(sOwner, sName)
	local tTimer = self:GetTimer(sOwner, sName)
	if tTimer and tTimer.bActive then
		if self[tTimer.tFunc.funcOnStop] then
			self[tTimer.tFunc.funcOnStop](self)
		end
		Apollo.StopTimer(tTimer.strTimerName)
		tTimer.bActive = false
	end
end

function GalaxyLibrary:IsTimerActive(sOwner, sName)
	local tTimer = self:GetTimer(sOwner, sName)
	if tTimer then
		return tTimer.bActive
	end
end

function GalaxyLibrary:StopAllTimers()
	for strOwner, tOwner in pairs(self.timers) do
		for strName, tInfo in pairs(tOwner) do
			self:StopTimer(strOwner, strName)
		end
	end
end


-----------------------------------------------------------------------------------------------
-- GalaxyLibrary Panel Functions
-----------------------------------------------------------------------------------------------
function GalaxyLibrary:GetPanel(sPanelId, bTable)
	local tPanel = self.wPanels[sPanelId]
	if tPanel then
		if bTable then
			return tPanel
		else
			return tPanel.wnd
		end
	end
end

function GalaxyLibrary:SetActivePanel(sPanelId)
	if self.selectedPanelId then
		self:PanelOnClose(self.selectedPanelId)
	end
	self.wnd.BackButton:Show(sPanelId ~= "EntryMenu")

	self:PanelOnOpen(sPanelId)
end

function GalaxyLibrary:PanelOnOpen(sPanelId)
	local fPanelOnOpen = GalaxyLibrary[sPanelId.."OnOpen"]
	if fPanelOnOpen then
		fPanelOnOpen(self)
	end
	self.selectedPanelId = sPanelId
	self:GetPanel(sPanelId):Show(true)
end

function GalaxyLibrary:PanelOnClose(sPanelId)
	local fPanelOnClose = GalaxyLibrary[sPanelId.."OnClose"]
	if fPanelOnClose then
		fPanelOnClose(self)
	end
	self:GetPanel(self.selectedPanelId):Show(false)
end
-----------------------------------------------------------------------------------------------
-- GalaxyLibrary Entry Menu Panel Functions
-----------------------------------------------------------------------------------------------
function GalaxyLibrary:EntryMenuOnLoad()
	local tPanel = self:GetPanel("EntryMenu", true)
	
	tPanel.wButtons = {}
	tPanel.ButtonContainer = tPanel.wnd:FindChild("ButtonContainer")
	tPanel.wnd:FindChild("BGDatacube"):SetCostumeToCreatureId(iDatacubeId)
	tPanel.wnd:FindChild("BGDatacube"):SetModelSequence(iDatacubeAnimSequence)
	tPanel.wnd:FindChild("BGRoboHead"):SetCostumeToCreatureId(11202)
end

function GalaxyLibrary:EntryMenuOnUnload()


end

-----------------------------------------------------------------------------------------------
-- GalaxyLibrary Item Browser Panel Functions
-----------------------------------------------------------------------------------------------
function GalaxyLibrary:ItemDBOnLoad()
	local tPanel = self:GetPanel("ItemDB", true)

	tPanel.nScanIndex = 0
	tPanel.bHasScanned = false
	tPanel.bSheathed = true
	tPanel.nCostumeIndex = 1

	
	local wCostumeContainer = tPanel.wnd:FindChild("CostumeContainer")

	tPanel.wLoadingScreen = tPanel.wnd:FindChild("LoadingScreen")
	tPanel.wLoading_Pct = tPanel.wnd:FindChild("Label_LoadingPct")
	tPanel.wLoadingScreen:Show(false)
	
	tPanel.wCategory = tPanel.wnd:FindChild("CategoriesList")
	tPanel.wItemScroller = tPanel.wnd:FindChild("ItemList")
	tPanel.wCostumes = {
		wCostumeContainer:FindChild("Body"),
		wCostumeContainer:FindChild("Head"),
	}
	
	tPanel.wCategoryList = {}
	tPanel.wItemList = {}
	
	tPanel.tCategoriesByName = {} -- TEMP
	tPanel.tCategories = {}
	tPanel.tDatabase = {}	-- Layout is by family
	tPanel.tLookup = {}
	tPanel.tLookupNames = {}	-- Family, Type, Category Names
	tPanel.tLookupNames["family"] = {}
	tPanel.tLookupNames["type"] = {}
	tPanel.tLookupNames["category"] = {}
	tPanel.tLevels = {}
	for i=1, 3 do
		tPanel.tLevels[i] = {}
	end
	
	
	-- Level Dims
	tPanel.tLevelDims = {}
	
	-- Level 1
	local wndTemp = Apollo.LoadForm(self.xmlPanelsDoc, "ItemDBTopLevel", nil, self)
	table.insert(tPanel.tLevelDims, wndTemp:GetHeight())
	wndTemp:Destroy()
	
	-- Level 2
	local wndTemp = Apollo.LoadForm(self.xmlPanelsDoc, "ItemDBMidLevel", nil, self)
	table.insert(tPanel.tLevelDims, wndTemp:GetHeight())
	wndTemp:Destroy()
	
	-- Level 3
	local wndTemp = Apollo.LoadForm(self.xmlPanelsDoc, "ItemDBLowLevel", nil, self)
	table.insert(tPanel.tLevelDims, wndTemp:GetHeight())
	wndTemp:Destroy()
end

-- local internalChatCache = nil
function GalaxyLibrary:ItemDBOnGiveMePressed(wndHandler, wndControl, eMouseButton)
	-- local selfUnit = GameLib.GetPlayerUnit()
	local currentItem = self.LatestSelectedCostumeItemId or -1
	local formattedMessage = "!item add " .. currentItem
	
	if currentItem == -1 then
		Print("Click on an item before using this button.")
		return
	end
	
	-- if not internalChatCache then
		-- local channels = ChatSystemLib:GetChannels()
		-- internalChatCache = channels[ChatSystemLib.ChatChannel_Command]
	-- end
	
	-- TO DO: Investigate message desync bug.
	-- Said "Desync" occurs on the next message the user sends. If I send "Hello, world!" after using the Gimme button, other people see that.
	-- Buuuut.... *I* see whatever `formattedMessage` was when this ran. (e.g. !item add 12345) instead of what I actually said.
	
	--internalCommandChatCache:Send(formattedMessage, "Galactic Library: NF Edition", selfUnit)
	ChatSystemLib.Command(formattedMessage)
end

function GalaxyLibrary:ItemDBOnUnload()


end

function GalaxyLibrary:ItemDBOnOpen()
	local tPanel = self:GetPanel("ItemDB", true)
	self:ItemDBGetList()
	if tPanel.bHasScanned then
		self:ItemDB_ReloadCategories()
		self:ItemDBResetPreview()
		self:ItemDBToggleSheathed(true)
	end
end

function GalaxyLibrary:ItemDB_ReloadCategories()
	local tPanel = self:GetPanel("ItemDB", true)
	self.LatestSelectedCostumeItemId = -1
	for i=1, #tPanel.tCategories do
		local wnd = Apollo.LoadForm(self.xmlPanelsDoc, "ItemDatabaseCategory", tPanel.wCategory, self)
		wnd:SetData(tPanel.tCategories[i])
		wnd:SetText(tPanel.tCategories[i])
		wnd:Show(true)
		
		local arrow = wnd:FindChild("Arrow")
		arrow:Show(false)
		
		tPanel.wCategoryList[i] = wnd
	end
	tPanel.wCategory:ArrangeChildrenVert()
end


function GalaxyLibrary:ItemDBOnClose()
	local tPanel = self:GetPanel("ItemDB", true)
	
	tPanel.wCategoryList = {}
	tPanel.wItemList = {}
	
	tPanel.wCategory:SetVScrollPos(0)
	tPanel.wItemScroller:SetVScrollPos(0)
	
	tPanel.wCategory:DestroyChildren()
	tPanel.wItemScroller:DestroyChildren()
	
	tPanel.wItemScroller:Show(false)
	
	self.LatestSelectedCostumeItemId = -1
end

function GalaxyLibrary:ItemDBGetList()
	local tPanel = self:GetPanel("ItemDB", true)
	
	if not tPanel.bHasScanned then
		self:StartTimer("ItemDB", "ItemScanner")
		--[[
		local tCategories = {}
		local tCategoriesByName = {}
		local tItemDB = {}
		for i=1, nItemDBScan do
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
				if not tCategoriesByName[category] then
					tCategoriesByName[category] = true
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
				
				table.insert(tItemDB, itemEntry)
				self:ItemDB_AddPlacementInfo(tItemPlacementInfo)
			end
		end
		for k,v in pairs(tCategoriesByName) do
			table.insert(tCategories, k)
		end
		table.sort(tCategories, function(a,b) return a < b end)

		tPanel.tCategories = tCategories
		tPanel.tDatabase = tItemDB
		
		tPanel.bHasScanned = true
		--]]
	end
end

function GalaxyLibrary:ItemDB_OnStartScan()
	-- Display and begin loading screen
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wLoadingScreen:Show(true)
	tPanel.wLoading_Pct:SetText("0%")


	local nCreatureId = 59328
	local nRandom = 0 
	for i = 1, 4 do -- math.random isn't very random atm
		nRandom = nRandom + math.random(1, 100)
	end
	nRandom = nRandom / 4
	if nRandom > 75  then
		nCreatureId = 59331
	end
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:SetCostumeToCreatureId(nCreatureId)	-- :D
	end
end


function GalaxyLibrary:ItemDB_OnStopScan()
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wLoadingScreen:Show(false)
	
	-- Cleanup
	for k,v in pairs(tPanel.tCategoriesByName) do
		table.insert(tPanel.tCategories, k)
	end
	table.sort(tPanel.tCategories, function(a,b) return a < b end)

	tPanel.tCategoriesByName = nil
	--tPanel.nScanIndex = nil
	
	tPanel.bHasScanned = true
	
	self:ItemDB_ReloadCategories()
	self:ItemDBResetPreview()
	self:ItemDBToggleSheathed(true)
end

function GalaxyLibrary:ItemDB_OnScan()
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
				if not tPanel.tCategoriesByName[category] then
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
				
				table.insert(tPanel.tDatabase, itemEntry)
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

function GalaxyLibrary:ItemDB_AddPlacementInfo(tItemInfo)
	-- SEE ACHIEVEMENTS.LUA FOR REFERENCE!
	local tPanel = self:GetPanel("ItemDB", true)
	
	local iFamilyId = tItemInfo.iFamilyId
	local iTypeId = tItemInfo.iTypeId
	local iCategoryId = tItemInfo.iCategoryId
	
	local sFamilyName = tItemInfo.sFamilyName
	local sTypeName = tItemInfo.sTypeName
	local sCategoryName = tItemInfo.sCategoryName
	
	if not tPanel.tLevels[1][iFamilyId] then
		tPanel.tLevels[1][iFamilyId] = {
			name = sFamilyName
		}
		tPanel.tLookupNames["family"][iFamilyId] = sFamilyName
	end

end

function GalaxyLibrary:BuildCategoryListing()



end

function GalaxyLibrary:ItemGetCategory(item)
	local debugOutput = {}
	debugOutput.Category = {}
	debugOutput.Family = {}
	debugOutput.Type = {}
	
	local itemInfoFull = {
		"Category: "..tostring(item:GetItemCategoryName()),
		"Family: "..tostring(item:GetItemFamilyName()),
		"Type: "..tostring(item:GetItemTypeName())}
	local itemInfoInt = {
		"Category: "..tostring(item:GetItemCategory()),
		"Family: "..tostring(item:GetItemFamily()),
		"Type: "..tostring(item:GetItemType())}
			
	--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Debug, table.concat(itemInfoFull, ", "), "")
	--ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Debug, table.concat(itemInfoInt, ", "), "")
	
	return item:GetItemTypeName()
end

function GalaxyLibrary:ItemDBCategorySelect(sCategory)
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.wItemScroller:DestroyChildren()
	tPanel.wItemScroller:SetVScrollPos(0)
	
	local nItems = 0
	local tPanel = self:GetPanel("ItemDB", true)
	for i=1, #tPanel.tDatabase do
		local tItem = tPanel.tDatabase[i]
		if tItem.category == sCategory then
			local wnd = Apollo.LoadForm(self.xmlPanelsDoc, "ItemDatabaseItem", tPanel.wItemScroller, self)
			wnd:FindChild("Portrait"):FindChild("Icon"):SetSprite(tPanel.tDatabase[i].item:GetIcon())
			wnd:FindChild("Label"):SetText(tPanel.tDatabase[i].name)
			wnd:FindChild("Label"):SetTextColor(karEvalColors[tItem.quality])
			wnd:SetData(tonumber(tItem.id))
			nItems = nItems + 1
		end
	end
	tPanel.wItemScroller:ArrangeChildrenVert()
	tPanel.wItemScroller:Show(nItems > 0)
end

function GalaxyLibrary:ItemDBSetPreviewItem(item, itemId)
	local tPanel = self:GetPanel("ItemDB", true)
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:SetItem(item)
	end
	self.LatestSelectedCostumeItemId = itemId or -1
	
	if self.PrintCurrentItem then
		Print("Current Item: " .. item:GetName())
	end
end

function GalaxyLibrary:ItemDBResetPreview()
	local tPanel = self:GetPanel("ItemDB", true)
	local unitPlayer = GameLib.GetPlayerUnit()
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:SetCostume(unitPlayer)
	end
	self.LatestSelectedCostumeItemId = -1
end

function GalaxyLibrary:ItemDBToggleSheathed(bForced)
	local tPanel = self:GetPanel("ItemDB", true)
	tPanel.bSheathed = bForced or not tPanel.bSheathed
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:SetSheathed(tPanel.bSheathed)
	end
end

function GalaxyLibrary:ItemDBToggleCostume(nIndex)
	local tPanel = self:GetPanel("ItemDB", true)
	
	local nCostumes = #tPanel.wCostumes
	local nSelected
	if not nIndex then
		nSelected = ( ( tPanel.nCostumeIndex + 2 ) % nCostumes ) + 1
	end
	tPanel.nCostumeIndex = nIndex or nSelected
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:Show(i == nSelected)
	end
end

function GalaxyLibrary:ItemDBOnResetPreview( wndHandler, wndControl, eMouseButton )
	self:ItemDBResetPreview()
end

function GalaxyLibrary:ItemDBOnToggleSheathed( wndHandler, wndControl, eMouseButton )
	self:ItemDBToggleSheathed()
end

function GalaxyLibrary:ItemDBOnToggleCostume( wndHandler, wndControl, eMouseButton )
	self:ItemDBToggleCostume()
end

function GalaxyLibrary:ItemDBOnRotateRight( wndHandler, wndControl, eMouseButton )
	local tPanel = self:GetPanel("ItemDB", true)
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:ToggleLeftSpin(true)
	end
end

function GalaxyLibrary:ItemDBOnRotateRightCancel( wndHandler, wndControl, eMouseButton )
	local tPanel = self:GetPanel("ItemDB", true)
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:ToggleLeftSpin(false)
	end
end

function GalaxyLibrary:ItemDBOnRotateLeft( wndHandler, wndControl, eMouseButton )
	local tPanel = self:GetPanel("ItemDB", true)
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:ToggleRightSpin(true)
	end
end

function GalaxyLibrary:ItemDBOnRotateLeftCancel( wndHandler, wndControl, eMouseButton )
	local tPanel = self:GetPanel("ItemDB", true)
	for i=1, #tPanel.wCostumes do
		tPanel.wCostumes[i]:ToggleRightSpin(false)
	end
end
-----------------------------------------------------------------------------------------------
-- GalaxyLibrary Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here
-- on SlashCommand "/ib"
function GalaxyLibrary:OnGalaxyLibrarySlash()
	self.wnd.Main:Show(true)
	self:SetActivePanel("EntryMenu")
end

function GalaxyLibrary:OnGalaxyLibraryPrintItemToggle()
	if self.PrintCurrentItem then
		self.PrintCurrentItem = false
		Print("Print Last Clicked Item: OFF")
	else
		self.PrintCurrentItem = true
		Print("Print Last Clicked Item: ON")
	end
end

--[[
function GalaxyLibrary:DoScan()
	if not self.wndList then
		self.wndList = {}
		for i=0, nItemDBScan do
			local item = Item.GetDataFromId(i)
		
			if item then
				local category = item:GetItemCategoryName()
				if not category or category == "" then 
					category = item:GetItemFamilyName()
					if not category or category == "" then
						category = item:GetItemTypeName()
					end
				end
				table.insert(self.wndList, {wnd=self:AddItem(item:GetName().. " - " .. i, category , item:GetIcon(), i)})
			end
		end
	end
end

function GalaxyLibrary:ClearAllEntries()


end

function GalaxyLibrary:CollapseAll()
	local index = 0
	--for k,v in ipairs(self.wndList) do
	for i=1, #self.wndList do
		self.wndTree:CollapseNode(i)
		--index = index + 1
	end
end

function GalaxyLibrary:ResetPlayerPreview()
	self.CostumeFull:SetCostume(GameLib.GetPlayerUnit())
	self.CostumeCloseup:SetCostume(GameLib.GetPlayerUnit())
end

-----------------------------------------------------------------------------------------------
-- GalaxyLibraryForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function GalaxyLibrary:OnOK()
	self.wndMain:Show(false) -- hide the window
end



function GalaxyLibrary:ItemListSelecton( wndHandler, wndControl, hSelected, hPrevSelected )
	wndHandler:SelectNode(hSelected)

	local id = wndHandler:GetNodeData(hSelected)
	local item = Item.GetDataFromId(id)
	
	self.selected = id
	
	if item then
		self:SetCostumeItem(item)
		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = item })
	end
end

function GalaxyLibrary:ItemListGenerateToolTip( wndHandler, wndControl, eToolTipType, x, y )
	if wndControl ~= wndHandler then
		return
	end

	wndControl:SetTooltipDoc(nil)

	local item = Item.GetDataFromId(self.selected)
	if item ~= nil then
		local xml = Tooltip.GenerateItemTooltip(item, self.bVendorOpen and 10 or 8)
		wndControl:SetTooltipDoc(xml)


		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = item })
	end
end

function GalaxyLibrary:ItemListSelectionChanging( wndHandler, wndControl, hNode, hSelected, bAllowed )
end

function GalaxyLibrary:OnResetPreview( wndHandler, wndControl, eMouseButton )
	self:ResetPlayerPreview()
end

function GalaxyLibrary:OnSheatheWeapon( wndHandler, wndControl, eMouseButton )
	self.sheathed = not self.sheathed
	self.CostumeFull:SetSheathed(self.sheathed)
	self.CostumeCloseup:SetSheathed(self.sheathed)
end


function GalaxyLibrary:OnRotateRight( wndHandler, wndControl, eMouseButton )
	self.CostumeFull:ToggleLeftSpin(true)
end

function GalaxyLibrary:OnRotateRightCancel( wndHandler, wndControl, eMouseButton )
	self.CostumeFull:ToggleLeftSpin(false)
end

function GalaxyLibrary:OnRotateLeft( wndHandler, wndControl, eMouseButton )
	self.CostumeFull:ToggleRightSpin(true)
end

function GalaxyLibrary:OnRotateLeftCancel( wndHandler, wndControl, eMouseButton )
	self.CostumeFull:ToggleRightSpin(false)
end
--]]

-----------------------------------------------------------------------------------------------
-- Add Item
-----------------------------------------------------------------------------------------------
--[[
function GalaxyLibrary:AddItem(name, cate, icon, id)
	--local wnd = Apollo.LoadForm("GalaxyLibrary.xml", "ListItem", self.wndItemList, self)
	--wnd:FindChild("Name"):SetText(string)
	--wnd:SetData(id)
	--return wnd
	
	if not self.wndList[cate] then
		self.wndList[cate] = { wnd = self.wndTree:AddNode(0, cate, "", nil) }
		--TreeControl.CollapseNode(self.wndList[cate].wnd)
		--self.wndTree:CollapseNode(i)
	end

	
	local wndChild = self.wndTree:AddNode(self.wndList[cate].wnd, name, icon, id)
	--self.wndTree:SetNodeImage(wndChild, icon)
	self.wndList[cate][id] = { wnd = wndChild }

end


function GalaxyLibrary:SetCostumeItem(item)
	self.CostumeFull:SetItem(item)
	self.CostumeCloseup:SetItem(item)
end
--]]


-----------------------------------------------------------------------------------------------
-- On Save
-----------------------------------------------------------------------------------------------
--[[
function GalaxyLibrary:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return nil
	end
	--return self.list
end

function GalaxyLibrary:ItemListDoubleClick( wndHandler, wndControl, hNode )
	local id = wndHandler:GetData()
	local item = Item.GetDataFromId(id)
	
	if item then
		self:SetCostumeItem(item)
	end
end
--]]

---------------------------------------------------------------------------------------------------
-- ListItem Functions
---------------------------------------------------------------------------------------------------
--[[
function GalaxyLibrary:OnListButton( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	local id = wndHandler:GetData()
	local item = Item.GetDataFromId(id)
	
	if item then
		self:SetCostumeItem(item)
	end
end



--]]


---------------------------------------------------------------------------------------------------
-- EntryMenuButton Functions
---------------------------------------------------------------------------------------------------

function GalaxyLibrary:OnEntryMenuButtonSignal( wndHandler, wndControl, eMouseButton )
	local sData = wndHandler:GetData()
	self:SetActivePanel(sData)
end

---------------------------------------------------------------------------------------------------
-- ItemDatabaseCategory Functions
---------------------------------------------------------------------------------------------------

function GalaxyLibrary:OnItemDBCategoryCheck( wndHandler, wndControl, eMouseButton )
	wndControl:FindChild("Arrow"):Show(true)
	local sCategory = wndControl:GetData()
	self:ItemDBCategorySelect2(sCategory)
end

function GalaxyLibrary:OnItemDBCategoryUncheck( wndHandler, wndControl, eMouseButton )
	wndControl:FindChild("Arrow"):Show(false)
end

---------------------------------------------------------------------------------------------------
-- ItemDatabaseItem Functions
---------------------------------------------------------------------------------------------------
function GalaxyLibrary:OnItemDBItemMouseEnter( wndHandler, wndControl, x, y )
	local nId = wndControl:GetData()
	local item = Item.GetDataFromId(nId)
	Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = nil })
end

function GalaxyLibrary:OnItemDBItemMouseUp( wndHandler, wndControl, eMouseButton )
	local nId = wndControl:GetData()
	local item = Item.GetDataFromId(nId)
	if Apollo.IsAltKeyDown() then
		Event_FireGenericEvent("ShowInventory")
		Event_FireGenericEvent("ShowItemInDressingRoom", item)
	elseif Apollo.IsShiftKeyDown() then
		Event_FireGenericEvent("ItemLink", item)
	else
		self:ItemDBSetPreviewItem(item, nId)
	end
	if item then
		self:ItemGetCategory(item)
	end
end

-----------------------------------------------------------------------------------------------
-- GalaxyLibrary Instance
-----------------------------------------------------------------------------------------------
local GalaxyLibraryInst = GalaxyLibrary:new()
GalaxyLibraryInst:Init()
