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

local function colorize(msg,color_hex)
  return "|cff".. color_hex .. msg .. FONT_COLOR_CODE_CLOSE
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

-- locals --------------------

local text_color = "ffe900"
local function vendorcolor(text)
  return colorize(text,text_color)
end

local function ReportSold(money)
  local gold_now = GetMoney() - money
  local gold = floor(abs(gold_now / 10000))
  local silver = floor(abs(mod(gold_now / 100, 100)))
  local copper = floor(abs(mod(gold_now, 100)))
  local COLOR_COPPER = "|cffeda55f"
  local COLOR_SILVER = "|cffc7c7cf"
  local COLOR_GOLD = "|cffffd700"

  DEFAULT_CHAT_FRAME:AddMessage(vendorcolor("VendorList") .. ", sold items for: "..COLOR_GOLD..gold.."g "..COLOR_SILVER..silver.."s "..COLOR_COPPER..copper.."c")
end

local elapsed = 1 -- slight delay at vendor open
local sold_something = false
local at_merchant = false
local money = GetMoney()

------------------------------

local function OnUpdate()
  elapsed = elapsed + arg1
  if VendorListDB.enabled and at_merchant and elapsed > 0.15 then
    elapsed = 0
    debug_print("foo")
    -- find an item and try to sell it
    for _,i in ipairs(VendorListDB.vendor_list) do
      debug_print("finding " .. i)
      local bag,slot,_ = FindBagItem(i)
      if bag and slot then
        debug_print("selling " .. i)
        UseContainerItem(bag,slot)
        sold_something = true
        return true -- sold something, exit this run
      end
    end
    -- didn't 'return', so we didn't sell something this run, check if we did before:
    if sold_something then
      sold_something = false
      ReportSold(money)
    end

    VendorList:SetScript("OnUpdate", nil)
    return false
  end
end

local function OnEvent()
  if event == "MERCHANT_SHOW" then
    debug_print("at vendor")
    at_merchant = true
    VendorList:SetScript("OnUpdate", OnUpdate)
    money = GetMoney()
  elseif at_merchant and event == "MERCHANT_CLOSED" then
    debug_print("left vendor")
    at_merchant = false
    -- Case for early exit, sold_something will be false if the selling completed properly
    if sold_something then
      sold_something = false
      ReportSold(money)
    end
    VendorList:SetScript("OnUpdate", nil) -- no sense checking anymore
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
    -- VendorList:SetScript("OnUpdate", OnUpdate)
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
    vl_print(vendorcolor("VendorList toggled ") .. (VendorListDB.enabled and colorize("on","00FF00") or colorize("off","FF0000")))
  elseif args[1] == "add" then
    if args[2] then
      table.remove(args,1)
      local item = ItemLinkToName(table.concat(args," "))
      table.insert(VendorListDB.vendor_list, item)
        vl_print(item .. vendorcolor(" added to the sell list."))
    else
      vl_print(vendorcolor("/vendorlist add [name]"))
    end
  elseif args[1] == "rem" or args[1] == "remove" then
    if args[2] then
      table.remove(args,1)
      local t = {}
      local item = ItemLinkToName(table.concat(args," "))
      for _,name in ipairs(VendorListDB.vendor_list) do
        if string.lower(name) ~= string.lower(item) then table.insert(t,name) end
      end
      VendorListDB.vendor_list = t
      vl_print(item .. vendorcolor(" removed from the sell list."))
    end
  elseif args[1] == "list" then
    local t = {}
    for _,name in ipairs(VendorListDB.vendor_list) do table.insert(t,name) end
    if next(t) == nil then
      vl_print(vendorcolor("There are curently no items being auto-sold."))
    else
      vl_print(vendorcolor("Items being auto-sold: ") .. table.concat(t, ", "))
    end
  else
    vl_print(vendorcolor("Type " .. colorize("/vendorlist","37c6c8") .. " followed by:"))
    vl_print("[" .. colorize("toggle","37c6c8") .. "] to enable/disable addon, currently: " .. (VendorListDB.enabled and colorize("enabled","00FF00") or colorize("disabled","FF0000")))
    vl_print("[" .. colorize("list","37c6c8") .. "] to see what's on the sell" .. colorize(" list","37c6c8") .. ".")
    vl_print("[" .. colorize("add","37c6c8") .. "] to " .. colorize("add","37c6c8") .. " an item by name or list to the list.")
    vl_print("[" .. colorize("rem","37c6c8") .. "] to " .. colorize("rem","37c6c8") .. "ove an item by name or list to the list.")
  end
end

SLASH_VENDORLIST1 = "/vendorlist";
SlashCmdList["VENDORLIST"] = handleCommands
