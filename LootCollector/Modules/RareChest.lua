-- Rare and chest discovery tracker for Ascension / LootCollector.
-- Keeps its records separate from item-only Worldforged discoveries.
local L = LootCollector
local RC = L:NewModule("RareChest", "AceEvent-3.0")
local PREFIX = "LCR1"
local ICONS = {
  rare = "Interface\\Icons\\Achievement_Boss_Archimonde",
  chest = "Interface\\Icons\\INV_Misc_Chest_01",
  highrisk = "Interface\\Icons\\INV_Misc_Chest_03",
  warmode = "Interface\\Icons\\INV_Misc_Chest_04",
  object = "Interface\\Icons\\INV_Misc_Gear_01",
}
-- Public chat must not contain unescaped WoW pipe sequences or control bytes.
local function clean(s, max)
  s = tostring(s or ""):gsub("[%c|]", " "):gsub("%s+", " ")
  return s:sub(1, max or 100)
end
local function safeChatText(s)
  -- Strip pipes (including |H, |c, |T and |K markup) and ASCII controls.
  return tostring(s or ""):gsub("[%c|]", " ")
end
local function db()
  LootCollectorDB_Asc = LootCollectorDB_Asc or {}
  LootCollectorDB_Asc.global = LootCollectorDB_Asc.global or {}
  local g = LootCollectorDB_Asc.global
  g.rareChest = g.rareChest or { records = {}, version = 1 }
  g.rareChest.records = g.rareChest.records or {}
  return g.rareChest
end
local function key(kind, map, x, y, name)
  -- A rare creature is one world entity, not a new record for every target
  -- transition or player-position sample. Chests remain location-specific.
  local base = table.concat({kind, tostring(map or 0), clean(name, 60):lower()}, ":")
  if kind == "rare" or kind == "object" then return base end
  return base .. ":" .. string.format("%.2f:%.2f", tonumber(x) or 0, tonumber(y) or 0)
end
function RC:GetPosition()
  local c, map, x, y
  if L.GetPlayerZoneMapPosition then c, map, x, y = L:GetPlayerZoneMapPosition() end
  if not map or not x or not y or (x == 0 and y == 0) then
    if SetMapToCurrentZone then SetMapToCurrentZone() end
    if GetPlayerMapPosition then x, y = GetPlayerMapPosition("player") end
    if GetCurrentMapAreaID then map = GetCurrentMapAreaID() end
    if GetCurrentMapContinent then c = GetCurrentMapContinent() end
  end
  if not map or not x or not y or (x == 0 and y == 0) then return nil end
  return tonumber(c) or 0, tonumber(map), tonumber(x), tonumber(y)
end
function RC:Upsert(rec, share)
  if type(rec) ~= "table" or not rec.name or not rec.kind then return false end
  rec.name = clean(rec.name, 100); rec.kind = clean(rec.kind, 16)
  rec.map = tonumber(rec.map) or 0; rec.x = tonumber(rec.x) or 0; rec.y = tonumber(rec.y) or 0
  if rec.map <= 0 or rec.x < 0 or rec.x > 1 or rec.y < 0 or rec.y > 1 then return false end
  rec.updated = tonumber(rec.updated) or time()
  rec.key = key(rec.kind, rec.map, rec.x, rec.y, rec.name)
  local records = db().records
  local old = records[rec.key]
  -- Migrate duplicate rare pins created by earlier versions that keyed rares
  -- by exact coordinates. Consolidate all same-name/same-map rare records.
  if rec.kind == "rare" then
    for existingKey, existing in pairs(records) do
      if existingKey ~= rec.key and existing.kind == "rare"
        and tonumber(existing.map) == tonumber(rec.map)
        and clean(existing.name, 100):lower() == rec.name:lower() then
        if not old then old = existing end
        records[existingKey] = nil
      end
    end
    if old then records[rec.key] = old end
  end
  local isNew = old == nil
  if old then
    -- Keep the first credible location for a rare; target toggling and movement
    -- must not create a trail of duplicate pins for the same named entity.
    old.level = rec.level or old.level; old.respawn = rec.respawn or old.respawn
    old.drops = (rec.drops and rec.drops ~= "") and rec.drops or old.drops
    old.notes = (rec.notes and rec.notes ~= "") and rec.notes or old.notes
    old.lastSeen = math.max(tonumber(old.lastSeen) or 0, tonumber(rec.lastSeen) or 0)
    old.updated = math.max(tonumber(old.updated) or 0, rec.updated)
    rec = old
  else records[rec.key] = rec end
  self:RefreshPins()
  -- Share newly discovered records only. Repeated targeting does not flood chat.
  if share and isNew then self:Share(rec) end
  return true
end
function RC:Record(kind, name, extra)
  local c, map, x, y = self:GetPosition()
  if not map then return false, "Could not determine your map position; open the zone map and try again." end
  extra = extra or {}
  return self:Upsert({ kind=kind, name=name, c=c, map=map, x=x, y=y, level=extra.level,
    respawn=extra.respawn, drops=extra.drops, notes=extra.notes, lastSeen=time(), updated=time() }, true)
end
function RC:Share(r)
  local Comm = L:GetModule("Comm", true)
  if not Comm or not Comm.channelId or Comm.channelId <= 0 or not SendChatMessage then return end
  -- Compact bounded message. Avoid arbitrary serialized Lua from other players.
  local msg = table.concat({PREFIX, r.kind, r.map, string.format("%.4f",r.x), string.format("%.4f",r.y),
    r.level or 0, r.respawn or 0, clean(r.name,45), clean(r.drops or "",35), clean(r.notes or "",25)}, "|")
  if #msg <= 235 then SendChatMessage(safeChatText(msg), "CHANNEL", nil, Comm.channelId) end
end
-- AceEvent passes the event name before the CHAT_MSG_CHANNEL payload.
-- CHAT_MSG_CHANNEL payload: message, sender, language, channelName, ...
function RC:OnChannelMessage(_, msg, sender, _, channelName)
  local Comm = L:GetModule("Comm", true)
  if not Comm then return end
  -- Some client builds expose a numeric channel index in later payload slots;
  -- only compare the named channel field when it is actually a string.
  if type(channelName) ~= "string" or channelName:lower() ~= tostring(Comm.channelName or ""):lower() then return end
  if type(msg) ~= "string" or msg:sub(1, #PREFIX+1) ~= PREFIX .. "|" then return end
  local fields = {}
  for part in (msg .. "|"):gmatch("(.-)|") do fields[#fields+1] = part end
  if #fields < 10 then return end
  local kind = fields[2]
  if kind ~= "rare" and kind ~= "chest" and kind ~= "highrisk" and kind ~= "warmode" and kind ~= "object" then return end
  local map, x, y = tonumber(fields[3]), tonumber(fields[4]), tonumber(fields[5])
  if not map or not x or not y or map <= 0 or x < 0 or x > 1 or y < 0 or y > 1 then return end
  self:Upsert({kind=kind, map=map, x=x, y=y, level=tonumber(fields[6]), respawn=tonumber(fields[7]), name=fields[8], drops=fields[9], notes=fields[10], updated=time(), source=clean(sender,32)}, false)
end
-- Chat sharing is separate from the automatic discovery synchronization channel.
function RC:ChatShareText(r)
  if not r then return nil end
  local label=({rare="Rare",chest="Chest",highrisk="High-Risk Chest",warmode="War Mode Chest"})[r.kind] or "Discovery"
  local msg="[LootCollector "..label.."] "..clean(r.name,90).." @ Map "..tostring(r.map or "?")
  if r.x and r.y then msg=msg..string.format(" (%.1f, %.1f)",r.x*100,r.y*100) end
  if r.minLevel or r.maxLevel then msg=msg.." Lv "..tostring(r.minLevel or r.level or "?").."-"..tostring(r.maxLevel or r.level or "?")
  elseif r.level and tonumber(r.level)>0 then msg=msg.." Lv "..tostring(r.level) end
  if r.respawn and tonumber(r.respawn)>0 then msg=msg.." Respawn ~"..tostring(r.respawn).."m" end
  if r.drops and r.drops~="" then msg=msg.." Drops: "..clean(r.drops,180) end
  return msg
end
function RC:ShareToChat(r,target)
  local msg=self:ChatShareText(r); if not msg then return end
  if target=="GUILD" and IsInGuild and IsInGuild() and SendChatMessage then
    SendChatMessage(safeChatText(msg),"GUILD"); return
  end
  -- Paste into the active chat edit box, so the player controls where it goes.
  local edit=(ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) or nil
  if not edit and ChatFrame1EditBox and ChatFrame1EditBox:IsShown() then edit=ChatFrame1EditBox end
  if edit and edit.Insert then edit:Insert(msg)
  elseif ChatFrame_OpenChat then ChatFrame_OpenChat(msg)
  else print(msg) end
end
function RC:ShowShareMenu(r,anchor)
  if not r then return end
  if not self.shareMenuFrame then
    self.shareMenuFrame=CreateFrame("Frame","LootCollectorRareChestShareMenu",UIParent,"UIDropDownMenuTemplate")
  end
  local menu={
    {text=clean(r.name,70),isTitle=true,notCheckable=true},
    {text="Share rare/chest + location",isTitle=true,notCheckable=true},
    {text="Link to Guild Chat",notCheckable=true,func=function() RC:ShareToChat(r,"GUILD") end},
    {text="Link to Current Chat",notCheckable=true,func=function() RC:ShareToChat(r,"PASTE") end},
    {text="Close",notCheckable=true,func=function() if CloseDropDownMenus then CloseDropDownMenus() end end},
  }
  if EasyMenu then EasyMenu(menu,self.shareMenuFrame,"cursor",0,0,"MENU",2)
  elseif UIDropDownMenu_Initialize and ToggleDropDownMenu then
    UIDropDownMenu_Initialize(self.shareMenuFrame,function(_,level)
      if level~=1 then return end
      for _,entry in ipairs(menu) do UIDropDownMenu_AddButton(entry,level) end
    end,"MENU")
    ToggleDropDownMenu(1,nil,self.shareMenuFrame,anchor,0,0)
  end
end
function RC:RefreshPins()
  if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
  if not WorldMapDetailFrame or not WorldMapButton then return end
  self:EnsurePins()
  local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID()
  local w, h = WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight()
  if not w or w <= 0 or not h or h <= 0 then return end
  for _, pin in ipairs(self.pins or {}) do pin:Hide() end
  local i = 0
  for _, rec in pairs(db().records) do
    if tonumber(rec.map) == tonumber(mapID) then
      i = i + 1; local pin = self.pins[i]
      if not pin then break end
      pin.record = rec; pin.icon:SetTexture(ICONS[rec.kind] or ICONS.object)
      pin:ClearAllPoints(); pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", rec.x*w, -rec.y*h)
      pin:Show()
    end
  end
end
function RC:EnsurePins()
  self.pins = self.pins or {}
  for i=1,80 do
    if not self.pins[i] then
      local p = CreateFrame("Button", nil, WorldMapDetailFrame)
      p:SetSize(20,20); p:RegisterForClicks("LeftButtonUp","RightButtonUp"); p:SetFrameStrata("TOOLTIP"); p:SetFrameLevel((WorldMapDetailFrame:GetFrameLevel() or 0) + 20); p:EnableMouse(true)
      p.icon = p:CreateTexture(nil,"OVERLAY"); p.icon:SetAllPoints(p)
      p:SetScript("OnEnter", function(btn)
        local r=btn.record; if not r then return end
        GameTooltip:SetOwner(btn,"ANCHOR_RIGHT"); GameTooltip:SetFrameStrata("TOOLTIP"); GameTooltip:ClearLines(); GameTooltip:AddLine(r.name,1,0.82,0)
        local kindLabel = ({rare="Rare creature",chest="Chest",highrisk="High-Risk chest",warmode="War Mode chest",object="Object"})[r.kind] or tostring(r.kind or "object")
        GameTooltip:AddLine(kindLabel .. (r.level and r.level>0 and (" · Level "..r.level) or ""),1,1,1)
        if r.minLevel or r.maxLevel then GameTooltip:AddLine("Level range: "..tostring(r.minLevel or r.level or "?").."–"..tostring(r.maxLevel or r.level or "?"),1,1,1) end
        if r.respawn and r.respawn>0 then GameTooltip:AddLine("Estimated respawn: "..r.respawn.." min",0.6,0.9,1) end
        if r.drops and r.drops~="" then GameTooltip:AddLine("Drops: "..r.drops,0.7,1,0.7,true) end
        if r.notes and r.notes~="" then GameTooltip:AddLine(r.notes,0.8,0.8,0.8,true) end
        if r.lastSeen then GameTooltip:AddLine("Last seen: "..date("%Y-%m-%d %H:%M",r.lastSeen),0.7,0.7,0.7) end
        GameTooltip:Show()
      end)
      p:SetScript("OnLeave", function() GameTooltip:Hide() end)
      p:SetScript("OnClick",function(btn,mouseButton) if mouseButton=="RightButton" and btn.record then RC:ShowShareMenu(btn.record,btn) end end)
      self.pins[i]=p
    end
  end
end
function RC:Export()
  local out = {"# LootCollector rare/chest import format: kind|mapID|x|y|name|level|respawnMinutes|drops|notes"}
  for _,r in pairs(db().records) do out[#out+1]=table.concat({r.kind,r.map,string.format("%.4f",r.x),string.format("%.4f",r.y),r.name,r.level or "",r.respawn or "",r.drops or "",r.notes or ""},"|") end
  print("|cffffcc00LootCollector:|r Copy the following import lines from your SavedVariables or use /lcrare list. Records: "..#out-1)
end
function RC:ImportLine(line)
  local f={}; for v in (line.."|"):gmatch("(.-)|") do f[#f+1]=v end
  if #f<5 then return false end
  return self:Upsert({kind=f[1],map=tonumber(f[2]),x=tonumber(f[3]),y=tonumber(f[4]),name=f[5],level=tonumber(f[6]),respawn=tonumber(f[7]),drops=f[8],notes=f[9],minLevel=tonumber(f[10]),maxLevel=tonumber(f[11]),updated=time()},true)
end

-- Searchable browser integrated with the main LootCollector pane.
function RC:GetRecords() return db().records end
function RC:EnsureDeleteDialog()
  if StaticPopupDialogs["LC_RARECHEST_DELETE"] then return end
  StaticPopupDialogs["LC_RARECHEST_DELETE"]={text="Erase this discovery from your local database? It may be shared again by another player.",button1=YES,button2=NO,timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function()
    if RC.pendingDeleteKey then db().records[RC.pendingDeleteKey]=nil end
    RC.pendingDeleteKey=nil; RC:RefreshPins()
    local V=L:GetModule("Viewer",true); if V and V.RefreshRareChestList then V:RefreshRareChestList(true) end
  end,OnCancel=function() RC.pendingDeleteKey=nil end}
end
function RC:ShowBrowser(kindFilter)
  if kindFilter ~= nil then self.browserKindFilter = kindFilter end
  if not self.browser then
    local f = CreateFrame("Frame", "LootCollectorRareChestBrowser", UIParent)
    f:SetSize(520, 430); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(100)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8}})
    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOPLEFT",18,-16); title:SetText("LootCollector - Creatures & Chests")
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)
    local search=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); search:SetSize(260,22); search:SetPoint("TOPLEFT",18,-48); search:SetAutoFocus(false); search:SetTextInsets(5,5,0,0)
    search:SetScript("OnTextChanged",function() RC:RefreshBrowser() end)
    local hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); hint:SetPoint("LEFT",search,"RIGHT",10,0); hint:SetText("Search name, type, drops, notes")
    local count=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); count:SetPoint("RIGHT",f,"TOPRIGHT",-22,-84)
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",18,-110); scroll:SetPoint("BOTTOMRIGHT",-36,18)
    local content=CreateFrame("Frame",nil,scroll); content:SetSize(450,1); scroll:SetScrollChild(content)
    f.search=search; f.count=count; f.content=content; f.rows={}; f.scroll=scroll
    self.browser=f

  end
  if not StaticPopupDialogs["LC_RARECHEST_DELETE"] then
    StaticPopupDialogs["LC_RARECHEST_DELETE"]={text="Erase this discovery from your local database? Other players may share it again.",button1=YES,button2=NO,timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function()
      if RC.pendingDeleteKey then db().records[RC.pendingDeleteKey]=nil end
      RC.pendingDeleteKey=nil; RC:RefreshPins(); RC:RefreshBrowser()
    end,OnCancel=function() RC.pendingDeleteKey=nil end}
  end
  self.browser:Show(); self:RefreshBrowser()
end
function RC:RefreshBrowser()
  local f=self.browser; if not f then return end
  local q=(f.search:GetText() or ""):lower(); local list={}
  for _,r in pairs(db().records) do
    local kindOK = not self.browserKindFilter or self.browserKindFilter == "all"
      or (self.browserKindFilter == "rare" and r.kind == "rare")
      or (self.browserKindFilter == "chest" and (r.kind == "chest" or r.kind == "highrisk" or r.kind == "warmode"))
    local hay=table.concat({r.name or "",r.kind or "",r.drops or "",r.notes or "",tostring(r.level or ""),tostring(r.map or "")}," "):lower()
    if kindOK and (q=="" or hay:find(q,1,true)) then list[#list+1]=r end
  end
  table.sort(list,function(a,b) return tostring(a.name):lower()<tostring(b.name):lower() end)
  f.count:SetText(#list.." records")
  for _,row in ipairs(f.rows) do row:Hide() end
  for i,r in ipairs(list) do
    local row=f.rows[i]
    if not row then
      row=CreateFrame("Button",nil,f.content); row:SetSize(445,30)
      row.bg=row:CreateTexture(nil,"BACKGROUND"); row.bg:SetAllPoints(true); row.bg:SetTexture("Interface\\Buttons\\WHITE8X8"); row.bg:SetVertexColor(0.12,0.12,0.17,0.75)
      row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); row.text:SetPoint("LEFT",7,0); row.text:SetJustifyH("LEFT"); row.text:SetWidth(365)
      row:SetScript("OnEnter",function(b) local x=b.record; if not x then return end; GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine(x.name,1,.82,0); GameTooltip:AddLine("Type: "..tostring(x.kind).." | Map: "..tostring(x.map),1,1,1); if x.level then GameTooltip:AddLine("Level: "..x.level) end; if x.respawn then GameTooltip:AddLine("Estimated respawn: "..x.respawn.." min") end; if x.drops and x.drops~="" then GameTooltip:AddLine("Drops: "..x.drops,.7,1,.7,true) end; if x.notes and x.notes~="" then GameTooltip:AddLine("Notes: "..x.notes,.8,.8,.8,true) end; GameTooltip:AddLine("Click to focus this record on the map",.6,.8,1); GameTooltip:Show() end)
      row:SetScript("OnLeave",function() GameTooltip:Hide() end)
      row:SetScript("OnClick",function(b) local x=b.record; if not x then return end; if SetMapByID then SetMapByID(x.map) elseif SetMapToCurrentZone then SetMapToCurrentZone() end; if WorldMapFrame and WorldMapFrame.Show then WorldMapFrame:Show() end; RC:RefreshPins() end)
      local del=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
      del:SetSize(55,22); del:SetPoint("RIGHT",row,"RIGHT",-3,0); del:SetText("Erase")
      del:SetScript("OnClick",function()
        if not row.record then return end
        RC.pendingDeleteKey = row.record.key
        StaticPopup_Show("LC_RARECHEST_DELETE")
      end)
      row.deleteButton=del
      f.rows[i]=row
    end
    row.record=r; row.text:SetText(string.format("|cff66ccff[%s]|r %s  |cffaaaaaaMap %s%s%s|r",tostring(r.kind),tostring(r.name),tostring(r.map),r.level and ("  Lv "..r.level) or "",r.respawn and ("  ~"..r.respawn.."m") or ""))
    row:ClearAllPoints(); row:SetPoint("TOPLEFT",f.content,"TOPLEFT",0,-(i-1)*32); row:Show()
  end
  f.content:SetHeight(math.max(1,#list*32))
end


-- Minimap discovery markers. Coordinates are zone-map normalized; the
-- visible radius is an approximation until zone dimensions are available.
function RC:EnsureMinimapPins()
  if self.minimapPins or not Minimap then return end
  self.minimapPins = {}
  for i=1,60 do
    local b=CreateFrame("Button",nil,Minimap)
    b:SetSize(13,13); b:SetFrameLevel(Minimap:GetFrameLevel()+8)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    b.icon=b:CreateTexture(nil,"OVERLAY"); b.icon:SetAllPoints(b)
    b:SetScript("OnEnter",function(btn)
      local r=btn.record; if not r then return end
      GameTooltip:SetOwner(btn,"ANCHOR_RIGHT"); GameTooltip:ClearLines()
      GameTooltip:AddLine(r.name or "Discovery",1,.82,0)
      GameTooltip:AddLine("Type: "..tostring(r.kind or "unknown"),1,1,1)
      if r.minLevel or r.maxLevel then GameTooltip:AddLine("Level range: "..tostring(r.minLevel or r.level or "?").." - "..tostring(r.maxLevel or r.level or "?"))
      elseif tonumber(r.level) and tonumber(r.level)>0 then GameTooltip:AddLine("Level: "..r.level) end
      if tonumber(r.respawn) and tonumber(r.respawn)>0 then GameTooltip:AddLine("Estimated respawn: "..r.respawn.." min",.6,.9,1) end
      if r.drops and r.drops~="" then GameTooltip:AddLine("Known drops: "..r.drops,.7,1,.7,true) end
      if r.notes and r.notes~="" then GameTooltip:AddLine(r.notes,.8,.8,.8,true) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    b:SetScript("OnClick",function(btn,button)
      if button=="RightButton" and btn.record then RC:ShowShareMenu(btn.record,btn) end
    end)
    b:Hide(); self.minimapPins[i]=b
  end
end
function RC:RefreshMinimapPins()
  if not Minimap or not Minimap:IsShown() then return end
  self:EnsureMinimapPins()
  if not self.minimapPins then return end
  for _,p in ipairs(self.minimapPins) do p:Hide() end
  -- Don't change the player's selected world-map zone just to render pins.
  local map=GetCurrentMapAreaID and GetCurrentMapAreaID()
  local px,py=GetPlayerMapPosition and GetPlayerMapPosition("player")
  if not map or not px or not py or (px==0 and py==0) then return end
  local radius=math.min(Minimap:GetWidth(),Minimap:GetHeight())/2-9
  if radius<=0 then return end
  -- Conservative zone-normalized viewing radius, adjustable if needed.
  local extent=0.018
  local facing=GetPlayerFacing and GetPlayerFacing() or 0
  local rotating=GetCVar and GetCVar("rotateMinimap")=="1"
  local count=0
  for _,r in pairs(db().records) do
    if tonumber(r.map)==tonumber(map) and r.x and r.y then
      local dx=(tonumber(r.x)-px)/extent*radius
      local dy=(py-tonumber(r.y))/extent*radius
      if rotating then
        local c,s=math.cos(facing),math.sin(facing)
        dx,dy=dx*c-dy*s,dx*s+dy*c
      end
      if dx*dx+dy*dy<=radius*radius then
        count=count+1; local pin=self.minimapPins[count]
        if not pin then break end
        pin.record=r; pin.icon:SetTexture(ICONS[r.kind] or ICONS.object)
        pin:ClearAllPoints(); pin:SetPoint("CENTER",Minimap,"CENTER",dx,dy); pin:Show()
      end
    end
  end
end
function RC:StartMinimapUpdates()
  if self.minimapDriver then return end
  local driver=CreateFrame("Frame")
  local elapsed=0
  driver:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed>=0.5 then elapsed=0; RC:RefreshMinimapPins() end
  end)
  self.minimapDriver=driver
end

-- Observed loot is learned only from a currently identifiable rare or chest.
-- Each item is counted once per loot window, never once per loot update.
local function lootEntries(rec)
  rec.dropItems = type(rec.dropItems)=="table" and rec.dropItems or {}
  return rec.dropItems
end
local function updateDropSummary(rec)
  local entries={}
  for id,item in pairs(lootEntries(rec)) do
    if type(item)=="table" and tonumber(id) and tonumber(item.count) and item.count>0 then
      entries[#entries+1]={id=tonumber(id),name=clean(item.name or ("Item "..id),70),count=item.count}
    end
  end
  table.sort(entries,function(a,b) return a.name<b.name end)
  local labels={}
  for i=1,math.min(#entries,35) do labels[#labels+1]=entries[i].name end
  if #labels>0 then rec.drops=table.concat(labels,", ") end
end
function RC:LearnDrop(rec,itemID,itemName)
  if not rec or not itemID or not itemName then return end
  local items=lootEntries(rec); local id=tostring(itemID)
  local item=items[id] or {name=clean(itemName,90),count=0}
  item.name=clean(itemName,90); item.count=(tonumber(item.count) or 0)+1
  items[id]=item; updateDropSummary(rec); rec.updated=time()
  -- Share each newly learned item using a compact versioned message.
  local Comm=L:GetModule("Comm",true)
  if Comm and tonumber(Comm.channelId) and Comm.channelId>0 and SendChatMessage then
    local msg=table.concat({"LCRD1",rec.kind,rec.map,clean(rec.name,45),itemID,clean(itemName,65)},"|")
    if #msg<=235 then SendChatMessage(safeChatText(msg),"CHANNEL",nil,Comm.channelId) end
  end
  self:RefreshPins()
  local V=L:GetModule("Viewer",true)
  if V and V.RefreshRareChestList then V:RefreshRareChestList(true) end
end
function RC:LootSource()
  if not UnitExists or not UnitExists("target") or (UnitIsPlayer and UnitIsPlayer("target")) then return nil end
  local name=UnitName("target"); if not name then return nil end
  local classification=UnitClassification and UnitClassification("target") or "normal"
  local kind
  if classification=="rare" or classification=="rareelite" or classification=="worldboss" then kind="rare"
  else
    local n=name:lower()
    if n:find("high%-risk") or n:find("high risk") then kind="highrisk"
    elseif n:find("war mode") or n:find("warmode") then kind="warmode"
    elseif n:find("chest") or n:find("cache") or n:find("coffer") or n:find("treasure") then kind="chest" end
  end
  if not kind then return nil end
  local _,map,x,y=self:GetPosition(); if not map then return nil end
  local id=key(kind,map,x,y,name)
  local records=db().records
  local rec=records[id]
  if not rec then
    self:Upsert({kind=kind,name=name,map=map,x=x,y=y,level=UnitLevel and UnitLevel("target") or nil,lastSeen=time(),updated=time()},true)
    rec=records[id]
  end
  return rec
end
function RC:CaptureLootSlot(slot)
  local session=self.lootSession
  if not session or session.seen[slot] then return end
  if not GetLootSlotLink then return end
  local link=GetLootSlotLink(slot)
  local id=link and tonumber(link:match("item:(%d+)"))
  if not id then return end
  local name=(GetItemInfo and GetItemInfo(id)) or (link and link:match("%[(.-)%]"))
  if not name then return end
  session.seen[slot]=true
  self:LearnDrop(session.rec,id,name)
end
function RC:ScanLootSlots()
  if not self.lootSession or not GetNumLootItems then return end
  for slot=1,GetNumLootItems() do self:CaptureLootSlot(slot) end
end
function RC:OnLootSlotCleared(_,slot) self:CaptureLootSlot(slot) end
function RC:OnLootClosed() self.lootSession=nil end
function RC:OnDropChannelMessage(_,msg,sender,language,channelName)
  local Comm=L:GetModule("Comm",true)
  if not Comm or type(channelName)~="string" or channelName:lower()~=tostring(Comm.channelName or ""):lower() then return end
  if type(msg)~="string" or msg:sub(1,6)~="LCRD1|" then return end
  local f={}; for part in (msg.."|"):gmatch("(.-)|") do f[#f+1]=part end
  if #f~=6 then return end
  local kind,map,name,id,itemName=f[2],tonumber(f[3]),clean(f[4],45),tonumber(f[5]),clean(f[6],65)
  if not map or not id or name=="" or itemName=="" then return end
  if kind~="rare" and kind~="chest" and kind~="highrisk" and kind~="warmode" and kind~="object" then return end
  for _,rec in pairs(db().records) do
    if rec.kind==kind and tonumber(rec.map)==map and clean(rec.name,100):lower()==name:lower() then
      local items=lootEntries(rec); local item=items[tostring(id)] or {name=itemName,count=0}
      item.name=itemName; item.count=math.max(tonumber(item.count) or 0,1)
      items[tostring(id)]=item; updateDropSummary(rec)
      self:RefreshPins()
      local V=L:GetModule("Viewer",true); if V and V.RefreshRareChestList then V:RefreshRareChestList(true) end
      return
    end
  end
end
function RC:OnInitialize()
  self:StartMinimapUpdates()
  self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetChanged")
  self:RegisterEvent("PLAYER_LOGIN", "OnLogin")
  self:RegisterEvent("WORLD_MAP_UPDATE", "RefreshPins")
  self:RegisterEvent("CHAT_MSG_CHANNEL", "OnChannelMessage")
  self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
  self:RegisterEvent("LOOT_SLOT_CLEARED", "OnLootSlotCleared")
  self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
  self:RegisterEvent("LOOT_SLOT_CHANGED", "ScanLootSlots")
  self:RegisterEvent("CHAT_MSG_CHANNEL", "OnDropChannelMessage")
  self:RegisterEvent("PLAYER_DEAD", "OnPlayerDead")
  SLASH_LOOTCOLLECTORRARE1 = "/lcrare"
  SlashCmdList = SlashCmdList or {}
  SlashCmdList.LOOTCOLLECTORRARE = function(msg)
    local cmd, rest = tostring(msg or ""):match("^(%S+)%s*(.*)$"); cmd=(cmd or "help"):lower()
    if cmd=="list" then local n=0; for _,r in pairs(db().records) do n=n+1; print(string.format("|cff66ccff%s|r [%s] map %d (%.3f, %.3f)%s",r.name,r.kind,r.map,r.x,r.y,r.respawn and (" respawn~"..r.respawn.."m") or "")) end; print("LootCollector: "..n.." rare/chest records.")
    elseif cmd=="import" then print("Import lines with /lcrare importline kind|mapID|x|y|name|level|respawnMinutes|drops|notes")
    elseif cmd=="importline" then if self:ImportLine(rest) then print("|cff66ff66LootCollector:|r Imported and shared record.") else print("|cffff6666LootCollector:|r Invalid import line.") end
    elseif cmd=="export" then self:Export()
    elseif cmd=="scan" then self:OnTargetChanged()
    else print("|cffffcc00LootCollector Rare/Chest Tracker|r: /lcrare list | /lcrare importline ... | /lcrare export | /lcrare scan") end
  end
end
function RC:OnLogin() self:RefreshPins(); self:StartMinimapUpdates(); self:RefreshMinimapPins() end
function RC:OnTargetChanged()
  if not UnitExists or not UnitExists("target") or UnitIsPlayer and UnitIsPlayer("target") then return end
  local name = UnitName("target"); if not name then return end
  local classification = UnitClassification and UnitClassification("target") or "normal"
  local level = UnitLevel and UnitLevel("target") or nil
  if classification=="rare" or classification=="rareelite" or classification=="worldboss" then
    local c,map,x,y = self:GetPosition()
    if not map then return end
    -- Record uses a stable name+map key for rares, so changing target state
    -- cannot generate additional pins. Keep first location; update last-seen.
    self:Upsert({kind="rare",name=name,c=c,map=map,x=x,y=y,level=level,notes=classification,lastSeen=time(),updated=time()},true)
  end
end
function RC:OnLootOpened()
  self.lootSession=nil
  local rec=self:LootSource()
  if not rec then return end
  self.lootSession={rec=rec,seen={}}
  self:ScanLootSlots()
end
function RC:OnPlayerDead() end
