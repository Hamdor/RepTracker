local f = CreateFrame("Frame", nil, UIParent)
local events = {}
local start_x = 25
local start_y = -100

-- Return a color to a StandingId
-- @param standingId
-- @returns red green blue values between 0 and 255
local function get_standing_color(standingId)
-- Ids according to https://wow.gamepedia.com/StandingId
  if standingId == 0 then     -- 0 - Unknown
    return 0, 0, 0
  elseif standingId == 1 then -- 1 - Hated
    return 127, 0, 0
  elseif standingId == 2 then -- 2 - Hostile
    return 255, 0, 0
  elseif standingId == 3 then -- 3 - Unfriendly
    return 255, 127, 0
  elseif standingId == 4 then -- 4 - Neutral
    return 127, 127, 127
  elseif standingId == 5 then -- 5 - Friendly
    return 127, 255, 0
  elseif standingId == 6 then -- 6 - Honored
    return 0, 255, 0
  elseif standingId == 7 then -- 7 - Revered
    return 0, 127, 0
  elseif standingId == 8 then -- 8 - Exalted
    return 127, 0, 255
  end
  return 0, 0, 0
end

-- Check if the given faction should be shown
-- @param faction name
-- @returns true if the faction should be shown, false otherwise
local function show_faction(name)
  return RepTracker_Factions[string.lower(name)]
end

-- Manages all bars.
BarManager = {
  ref_pos = "TOPLEFT",
  next_x = start_x,
  next_y = start_y,
  bars={},
  cur_bar = 0,

  -- Initializes all bars (empty)
  -- @param width width of a bar
  -- @param height height of a bar
  init = function(self, width, height)
    for i=0, 10 do
      bar = CreateFrame("StatusBar", nil, UIParent)
      bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
      bar:SetPoint(self.ref_pos, self.next_x, self.next_y)
      bar:SetSize(width, height)
      bar.label = bar:CreateFontString(nil, "OVERLAY")
      bar.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
      bar.label:SetAllPoints(true)
      bar.label:SetJustifyH("LEFT") -- label is left aligned
      bar.label:SetJustifyV("TOP")  -- label is aligned to top
      RegisterStateDriver(bar, "visibility", "hide")
      self.bars[i] = bar
      self.next_y = self.next_y - height -- set next_y to next bar slot
    end
  end,

  -- Update bars according to shown factions.
  -- @param str name of faction
  -- @param min Minimum value of StatusBar
  -- @param max Maximum value of StatusBar
  -- @param standingId
  update = function(self, str, min, max, current, standingId)
    if show_faction(str) ~= true then return end
    i = self.cur_bar
    if standingId == 8 then
      -- Show full bar on Exalted (21000/21000).
      current = 21000
      max = 21000
    end
    self.bars[i]:SetMinMaxValues(min, max)
    self.bars[i]:SetValue(current)
    self.bars[i]:SetStatusBarColor(get_standing_color(standingId))
    self.bars[i].label:SetText(str..": "..current.." / "..max)
    if show_faction(str) and RepTracker_GeneralSettings.enabled then
      RegisterStateDriver(self.bars[i], "visibility", "[group]hide;show")
    else
      RegisterStateDriver(self.bars[i], "visibility", "hide")
    end
    -- Increment current bar...
    self.cur_bar = i + 1
  end,

  reset = function(self)
    self.cur_bar = 0
    -- Hide all bars.
    for k,v in pairs(self.bars) do
      RegisterStateDriver(v, "visibility", "hide")
    end
  end
}

--- Handler for ADDON_LOADED event (on login or UI reload)
function events:ADDON_LOADED(name)
  if name ~= "RepTracker" then return end
  if RepTracker_GeneralSettings then
    RepTracker_GeneralSettings = RepTracker_GeneralSettings
  else
    RepTracker_GeneralSettings = {
      enabled = true,
      bar_width = 200,
      bar_height = 10,
    }
  end
  if RepTracker_Factions then
    RepTracker_Factions = RepTracker_Factions
  else
    RepTracker_Factions = {}
  end
  -- Init bar manager
  BarManager:init(RepTracker_GeneralSettings.bar_width,
                  RepTracker_GeneralSettings.bar_height)
end

--- Handler for PLAYER_LOGOUT event (logout)
function events:PLAYER_LOGOUT(name)
  if name ~= "RepTracker" then return end
  RepTracker_GeneralSettings = RepTracker_GeneralSettings
  RepTracker_Factions = RepTracker_Factions
end

-- Handler for UPDATE_FACTION event
function events:UPDATE_FACTION(...)
  BarManager:reset()
  for idx = 1, GetNumFactions() do
    repeat
      name, _, standingId, bottomValue, topValue, earnedValue, _,
      _, isHeader, _, _, _, _ = GetFactionInfo(idx);
      -- Skip headers
      if isHeader == true then do break end end
      -- Adjust to current standing.
      topValue = topValue - bottomValue
      earnedValue = earnedValue - bottomValue
      -- Finally add this faction to a bar.
      BarManager:update(name, 0, topValue, earnedValue, standingId)
    until true
  end
end

f:SetScript("OnEvent", function(self, event, ...)
  events[event](self, ...)
end);

for k, v in pairs(events) do
  f:RegisterEvent(k)
end

--- Handle console commands
local function CommandHandler(msg, editbox)
  local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")
  if cmd == "add" and args ~= "" then
    print("adding " .. args)
    RepTracker_Factions[string.lower(args)] = true
    events:UPDATE_FACTION()
  elseif cmd == "remove" and args ~= "" then
    print("removing " .. args)
    RepTracker_Factions[string.lower(args)] = false
    events:UPDATE_FACTION()
  elseif cmd == "enable" then
    RepTracker_GeneralSettings.enabled = true
  elseif cmd == "disable" then
    RepTracker_GeneralSettings.enabled = false
  elseif cmd == "clear" then
    RepTracker_Factions = {}
  elseif cmd == "show" then
    for k, v in pairs(RepTracker_Factions) do print(k, v) end
  elseif cmd == "update" then
    events:UPDATE_FACTION() -- Force update
  else
    -- TODO: Improve help message.
    print("Syntax: /reptracker (add|remove|clear|show|update) [factionName]");
  end
end
SLASH_REPTRACKER1 = '/reptracker'
SlashCmdList["REPTRACKER"] = CommandHandler

-- Show the bars
f:Show()
