local DEBUG = false

function vl_print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function debug_print(msg)
  if DEBUG then DEFAULT_CHAT_FRAME:AddMessage(msg) end
end

local VendorList = CreateFrame("Frame")

local defaults = {
  enabled = true,
  vendor_list = {}
}

--[[
  local names = {}
  for name in string.gfind(names_string,"([^,]+)") do
    table.insert(names,name)
  end
--]]

local function clone_table(t)
  local t = {}
  for k,v in pairs(t) do
    t[k] = v
  end
  return t
end

-- taken from supermacros
local function ItemLinkToName(link)
	if ( link ) then
   	return gsub(link,"^.*%[(.*)%].*$","%1");
	end
end

-- adapted from supermacros
local function FindBagItem(item)
	if ( not item ) then return; end
	item = string.lower(ItemLinkToName(item));
	local link;
	local count, bag, slot, locked;
	local totalcount = 0;
	for i = 0,NUM_BAG_FRAMES do
		for j = 1,MAX_CONTAINER_ITEMS do
			link = GetContainerItemLink(i,j);
			if ( link ) then
				if ( item == string.lower(ItemLinkToName(link))) then
					bag, slot = i, j;
					_, count, locked = GetContainerItemInfo(i,j);
					totalcount = totalcount + count;
				end
			end
		end
	end
	return bag, slot, locked, totalcount;
end

local rcount = 0



local at_merchant = false
local function OnEvent()
  if event == "MERCHANT_SHOW" then
    debug_print("at vendor")
    at_merchant = true
  elseif event == "MERCHANT_CLOSED" then
    debug_print("left vendor")
    at_merchant = false
  end
end

local elapsed = 0
local function OnUpdate()
  elapsed = elapsed + arg1
  if VendorListDB.enabled and at_merchant and elapsed > 0.15 then
    elapsed = 0
    debug_print("foo")
    -- find an item and try to sell it
    for _,i in ipairs(VendorListDB.vendor_list) do
      debug_print("finding " .. i)
      local bag,slot,locked,_ = FindBagItem(i)
      if not locked and bag and slot then
        debug_print("selling " .. i)
        UseContainerItem(bag,slot)
        break -- only do it once per duration
      end
    end
  end
end

local function Init()
  if event == "ADDON_LOADED" and arg1 == "VendorList" then
    VendorList:UnregisterEvent("ADDON_LOADED")
    if not VendorListDB then
      VendorListDB = defaults -- initialize default settings
      else -- or check that we only have the current settings format
        local s = {}
        for k,v in pairs(defaults) do
          if VendorListDB[k] == nil -- specifically nil
            then s[k] = defaults[k]
            else s[k] = VendorListDB[k] end
        end
        VendorListDB = s
    end
    VendorList:SetScript("OnEvent", OnEvent)
    VendorList:SetScript("OnUpdate", OnUpdate)
    -- VendorList:Show()
  end
end

VendorList:RegisterEvent("MERCHANT_SHOW")
VendorList:RegisterEvent("MERCHANT_CLOSED")
VendorList:RegisterEvent("ADDON_LOADED")
VendorList:SetScript("OnEvent", Init)

local function handleCommands(msg,editbox)
  local args = {};
  for word in string.gfind(msg,'%S+') do table.insert(args,word) end

  if args[1] == "toggle" then
    VendorListDB.enabled = not VendorListDB.enabled
    vl_print("VendorList toggled " .. (VendorListDB.enabled and "on" or "off"))
  elseif args[1] == "add" then
    if args[2] then
      table.remove(args,1)
      local item = ItemLinkToName(table.concat(args," "))
      table.insert(VendorListDB.vendor_list, item)
        vl_print(item .. " added to the sell list.")
    else
      vl_print("/vendorlist add [name]")
    end
  elseif args[1] == "rem" then
    if args[2] then
      table.remove(args,1)
      local t = {}
      local item = ItemLinkToName(table.concat(args," "))
      for _,name in ipairs(VendorListDB.vendor_list) do
        if string.lower(name) ~= item then table.insert(t,name) end
      end
      VendorListDB.vendor_list = t
      vl_print(item .. " removed from the sell list.")
    end
  elseif args[1] == "list" then
    local t = {}
    for _,name in ipairs(VendorListDB.vendor_list) do table.insert(t,name) end
    vl_print("Items being auto-sold: " .. table.concat(t, ", "))
  else
    vl_print("Type /vendorlist followed by:")
    vl_print("[toggle] to enable addon.")
    vl_print("[list] to see what's on the sell list.")
    vl_print("[add] to add an item by name or list to the list.")
    vl_print("[rem] to remove an item by name or list to the list.")
  end
end

SLASH_VENDORLIST1 = "/vendorlist";
SlashCmdList["VENDORLIST"] = handleCommands
