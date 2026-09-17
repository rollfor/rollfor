RollForAutoLoot = RollForAutoLoot or {}
local al = RollForAutoLoot

if al.OptionsPage then return end

local hl = RollFor.colors.hl

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

-- This addon's page in RollFor's options window.
--
-- RollFor creates the canvas and registers it with the game's settings panel, then hands it
-- over and asks this to fill it in. Core does not know what is on the page and does not want
-- to: an extension keeps its own database, so it is the only thing that knows what is worth
-- showing. What core does supply is the builders -- the popup builder, the frame builder and
-- the widget set -- so a page can be assembled out of the same pieces RollFor's own page uses
-- rather than out of raw CreateFrame calls.
--
-- The settings below are this addon's own, registered through ctx.config during on_enable.
-- They live in core's toggles table, so they already answer to /rf config -- but core's own
-- page renders an explicit list of its own settings and nothing else, so this page is where
-- they are actually visible.

-- What this addon is for, in its own words. Core does not hold a copy: it has no use for one,
-- since this page is the only thing that shows it.
local SUMMARY = string.format(
  "Master-loots the items you tick straight to yourself when the corpse opens.\n" ..
  "Tick items boss by boss, or a whole quality under General to sweep up everything of it.\n" ..
  "Hold Shift while opening a corpse to loot it yourself instead.\n" ..
  "Open the list with %s.",
  hl("/rf autoloot")
)

local SIDE_INSET, TOP_INSET = 16, 16

-- Vertical gap above each kind of line. Mirrors what RollFor uses on its own page so the two
-- look like one addon; nothing enforces that, and nothing has to.
local paddings = {
  section_header = 13,
  paragraph = 9,
  checkbox = 5
}

-- Prose is followed by a bigger gap than the one between two controls, so the tabs
-- underneath read as a new thought rather than the summary's last line.
local after_paragraph_padding = 16

-- The open tab's content sits in a bordered panel under the tabs, the way a tabbed window
-- draws one, so it is plain which tab the settings belong to. Same border as the SoftRes import
-- window's text box, so the addons draw a box the same way.
local panel_backdrop = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

-- Room between the panel's border and what is inside it, on every side.
local PANEL_INSET = 12

-- How far the panel reaches out to the left of the summary, towards the edge of the page.
local PANEL_OUTDENT = 14

-- How far in from the panel's left edge the first tab sits, which keeps it off the rounded corner.
local TABS_INDENT = 8

-- How far a line sits to the right of the summary. The tabs follow the panel out to the left.
local indents = {
  tabs = TABS_INDENT - PANEL_OUTDENT
}

-- How far the panel reaches up under the tabs. The open tab's artwork hangs a few pixels below
-- the row, and it is drawn over the panel, so it covers the border's top edge beneath it and
-- reads as joined to the panel rather than resting on it.
local PANEL_TAB_OVERLAP = 2

-- The settings this page draws, in the order they read: the feature, then what it says out
-- loud. Each one is a key in core's config, which is where register_toggle put it.
--
-- There is no Enabled switch above them. Core only injects one onto the page it draws for an
-- extension that supplies none of its own, so a page like this one would have to carry its own
-- -- and this addon declares hide_enabled_option instead, because the first setting below is
-- already that switch.
local TOGGLES = {
  { key = "auto_loot",          label = "Auto-loot" },
  { key = "auto_loot_announce", label = "Announce auto-looted items" },
  { key = "auto_loot_messages", label = "Auto-loot messages" }
}

-- Everything under the summary is split into tabs, in the order they are drawn. The summary
-- stays above them: it says what the addon is for, which is true whichever tab is open.
local TABS = { "General", "Loot" }

---@param ctx ExtensionContext
---@param parent table -- the canvas RollFor registered for this page
---@return { show: fun() }
function M.new(ctx, parent)
  local popup, panel

  -- Which tab is open. Kept for as long as the page exists rather than reset on every visit,
  -- so leaving the settings window and coming back finds it where it was.
  local selected_tab = 1

  -- The summary is written a line per thought, so letting it wrap turns a list into prose:
  -- the continuation of a long line sits under the start of it and reads as another entry.
  -- Give it the width of the canvas it is actually in rather than the widget's own default,
  -- which is sized for a narrower page than the settings window.
  --
  -- Measured at show() rather than at build, because the settings window sizes the canvas
  -- when it displays the page. Falls back to whatever the widget chose if it is asked before
  -- then.
  local function paragraph_width(frame)
    local available = (parent.GetWidth and parent:GetWidth() or 0) - SIDE_INSET * 2

    return available > 0 and math.max(available, frame:GetWidth() or 0) or nil
  end

  local function create_popup()
    return ctx.popup_builder()
        :name("RollForAutoLootOptionsPage")
        :parent(parent)
        :point({
          point = "TOPLEFT",
          relative_frame = parent,
          relative_point = "TOPLEFT",
          x = SIDE_INSET,
          y = -TOP_INSET
        })
        :gui_elements(ctx.gui_elements)
        :backdrop_color(0, 0, 0, 0)
        :no_border()
        :build()
  end

  -- Positioned under the tabs on every show rather than here, since that is when the tabs line
  -- exists to anchor it to.
  --
  -- The border is set on the frame rather than through the builder, whose borders follow the
  -- user's frame style: neither a hairline nor a dialog box looks like a group of settings.
  -- Typed as a plain table because Popup doesn't declare the backdrop methods every popup has.
  local function create_panel()
    local result = ctx.popup_builder()
        :name("RollForAutoLootOptionsPagePanel")
        :parent(parent)
        :gui_elements(ctx.gui_elements)
        :build() --[[@as table]]

    result:SetBackdrop(panel_backdrop)
    result:SetBackdropColor(0, 0, 0, 0.3)
    result:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    return result
  end

  -- Chains each line under the one before it, left-aligned apart from its indent. The first line
  -- sits `inset` in from the frame's top-left corner.
  ---@param frame table -- the popup the line goes into
  ---@param inset number
  ---@param line_type string
  ---@param previous_type string?
  ---@param configure fun( frame: table )
  ---@return table -- the line
  local function add_line(frame, inset, line_type, previous_type, configure)
    local padding = previous_type == nil and inset
        or previous_type == "paragraph" and after_paragraph_padding
        or paddings[line_type] or 5

    return frame.add_line(line_type, function(_, line_frame, lines)
      configure(line_frame)

      local count = #lines
      local indent = indents[line_type] or 0
      line_frame:ClearAllPoints()

      if count == 0 then
        line_frame:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + indent, -padding)
      else
        local previous_indent = indents[lines[count].line_type] or 0
        line_frame:SetPoint("TOPLEFT", lines[count].frame, "BOTTOMLEFT", indent - previous_indent, -padding)
      end
    end, padding)
  end

  local function add_page_line(line_type, previous_type, configure)
    return add_line(popup, 0, line_type, previous_type, configure)
  end

  -- What went into the panel on this pass, which is what its height is measured from.
  local panel_lines = {}

  local function add_panel_line(line_type, previous_type, configure)
    table.insert(panel_lines, add_line(panel, PANEL_INSET, line_type, previous_type, configure))
  end

  -- Hangs the panel under the tabs, from just left of the summary to the page's right margin,
  -- and as tall as what is in it. The
  -- popup sizes itself to its lines as they are added, but to its own margins; the panel wants
  -- the same inset below its last line as above its first, and the page's width rather than
  -- the width of its widest line.
  ---@param tabs table -- the tabs line's frame
  local function fit_panel(tabs)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", -TABS_INDENT, PANEL_TAB_OVERLAP)

    local width = (parent.GetWidth and parent:GetWidth() or 0) - SIDE_INSET * 2
    if width > 0 then panel:SetWidth(width + PANEL_OUTDENT) end

    local height = PANEL_INSET

    for _, line in ipairs(panel_lines) do
      height = height + line.padding + line.frame:GetHeight()
    end

    panel:SetHeight(height)
  end

  -- No Enabled switch. This addon declares hide_enabled_option, because "Auto-loot" below is
  -- the same question -- and core keeps the extension on, so there would be nothing for a
  -- switch to say.
  local function add_general_tab()
    local previous

    for _, toggle in ipairs(TOGGLES) do
      add_panel_line("checkbox", previous, function(frame)
        frame:SetText(toggle.label)
        frame:SetChecked(ctx.config[toggle.key]() and true or false)
        frame.on_click = function(value) ctx.config["set_" .. toggle.key](value) end
      end)

      previous = "checkbox"
    end
  end

  local function add_loot_tab()
    add_panel_line("paragraph", nil, function(frame)
      frame:SetText("Hello world!")
    end)
  end

  local tab_contents = { add_general_tab, add_loot_tab }

  -- Rebuilt from scratch on every visit, because every checkbox on it has to show what is
  -- true now -- all of these can be changed from a slash command, or by another page,
  -- between one viewing and the next. Switching tabs takes the same path.
  local function show()
    if not popup then popup = create_popup() end
    if not panel then panel = create_panel() end

    popup:clear()
    panel:clear()
    panel_lines = {}

    add_page_line("section_header", nil, function(frame)
      frame:SetText(m.colors.blue("Summary"))
    end)

    add_page_line("paragraph", "section_header", function(frame)
      local width = paragraph_width(frame)
      if width then frame:SetWidth(width) end

      frame:SetText(SUMMARY)
    end)

    local tabs = add_page_line("tabs", "paragraph", function(frame)
      frame:SetTabs(TABS, selected_tab)
      frame.on_select = function(index)
        selected_tab = index
        show()
      end
    end)

    tab_contents[selected_tab]()
    fit_panel(tabs.frame)

    popup:Show()
    panel:Show()
  end

  return {
    show = show,
    get_frame = function() return popup end,
    get_panel = function() return panel end
  }
end

al.OptionsPage = M
return M
