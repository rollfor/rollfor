package.path = "./?.lua;" .. package.path .. ";../../RollFor/src/?.lua;../../RollFor/src/libs/?.lua;../src/?.lua;../../?.lua"

-- This addon builds its own page in RollFor's options window. Core supplies the canvas and the
-- builders and asks for it; what ends up on it is entirely ours. These settings used to be on
-- core's own page, and core's page renders an explicit list of core's settings and nothing else
-- -- so this page is now the only place they are visible.
--
-- The doubles are local rather than borrowed from RollFor's test harness. Core's options
-- tests spy on its content transformer, which this page does not use: it talks to the
-- popup builder directly. Owning the page means owning the double for it.

require( "src/compat" )
local u = require( "RollForAutoLoot/test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )

u.mock_wow_api()
u.load_extension()

local OptionsPage = RollForAutoLoot.OptionsPage

-- Widgets that record what was done to them, so a test can ask what the page put on a
-- line rather than what it looks like on screen. What the real widgets draw is RollFor's
-- business, and the game's.
local function fake_widget()
  local widget = {}

  widget.SetText = function( _, text ) widget.text = text end
  widget.SetChecked = function( _, checked ) widget.checked = checked end
  widget.SetTabs = function( _, labels, selected )
    widget.labels = labels
    widget.selected = selected
  end
  widget.SetWidth = function( _, width ) widget.width = width end
  widget.GetWidth = function() return widget.width or 0 end
  widget.GetHeight = function() return 20 end
  widget.ClearAllPoints = function() end
  widget.SetPoint = function() end
  widget.Show = function() end
  widget.Hide = function() end

  return widget
end

local function fake_gui_elements()
  local elements = {}

  for _, line_type in ipairs( { "section_header", "paragraph", "tabs", "checkbox" } ) do
    elements[ line_type ] = fake_widget
  end

  return elements
end

-- A popup that keeps its lines, which is the whole of what this page does with one.
local function recording_popup_builder()
  local builder = {}
  local popup = { lines = {}, visible = false }

  popup.add_line = function( line_type, modify_fn, padding )
    local frame = fake_widget()
    modify_fn( line_type, frame, popup.lines )

    local line = { line_type = line_type, frame = frame, padding = padding }
    table.insert( popup.lines, line )

    return line
  end

  popup.clear = function() popup.lines = {} end
  popup.Show = function() popup.visible = true end
  popup.IsVisible = function() return popup.visible end
  popup.SetBackdrop = function( _, backdrop ) popup.backdrop = backdrop end
  popup.SetBackdropColor = function() end
  popup.SetBackdropBorderColor = function() end
  popup.ClearAllPoints = function() popup.anchor = nil end
  popup.SetPoint = function( _, point, relative_frame, relative_point, x, y )
    popup.anchor = { point = point, relative_frame = relative_frame, relative_point = relative_point, x = x, y = y }
  end
  popup.SetWidth = function( _, width ) popup.width = width end
  popup.SetHeight = function( _, height ) popup.height = height end

  -- Every setter the page chains, answering with itself.
  for _, setter in ipairs( {
    "name", "parent", "point", "gui_elements", "backdrop_color", "no_border"
  } ) do
    builder[ setter ] = function( self ) return self end
  end

  builder.build = function() return popup end

  return builder
end

-- What core hands over: the builders, this extension's own on/off state, and the config its
-- settings were registered into. Not the summary -- that is ours, and lives in the page.
---@param overrides table?
local function mock_context( overrides )
  local state = { enabled = true, set_to = nil, settings = {
    auto_loot = true,
    auto_loot_announce = true,
    auto_loot_messages = false
  } }

  local config = {}

  for key in pairs( state.settings ) do
    config[ key ] = function() return state.settings[ key ] end
    config[ "set_" .. key ] = function( value ) state.settings[ key ] = value end
  end

  local ctx = {
    popup_builder = recording_popup_builder,
    gui_elements = fake_gui_elements(),
    config = config,
    is_enabled = function() return state.enabled end,
    set_enabled = function( value )
      state.set_to = value
      state.enabled = value
    end,
    state = state
  }

  for key, value in pairs( overrides or {} ) do ctx[ key ] = value end

  return ctx
end

local CANVAS_WIDTH = 665

---@param ctx table
---@param canvas_width number?
local function shown_page( ctx, canvas_width )
  local canvas = u.modules().api.CreateFrame( "Frame" )
  canvas.GetWidth = function() return canvas_width or CANVAS_WIDTH end

  local page = OptionsPage.new( ctx, canvas )
  page.show()

  return page
end

-- Every line on the page, the summary and the tabs first and then what is in the panel under
-- them, in the order they read.
---@return table[]
local function all_lines( page )
  local result = {}

  for _, frame in ipairs( { page.get_frame(), page.get_panel() } ) do
    for _, entry in ipairs( frame.lines ) do table.insert( result, entry ) end
  end

  return result
end

---@return string[]
local function line_types( page )
  local result = {}

  for _, line in ipairs( all_lines( page ) ) do
    table.insert( result, line.line_type )
  end

  return result
end

---@return table
local function line( page, line_type )
  for _, entry in ipairs( all_lines( page ) ) do
    if entry.line_type == line_type then return entry.frame end
  end

  error( string.format( "There was no %s on the page.", line_type ), 2 )
end


---@return table
local function checkbox( page, label )
  for _, entry in ipairs( all_lines( page ) ) do
    if entry.line_type == "checkbox" and entry.frame.text == label then return entry.frame end
  end

  error( string.format( "There was no %q checkbox on the page.", label ), 2 )
end

---@return string[]
local function paragraphs( page )
  local result = {}

  for _, entry in ipairs( all_lines( page ) ) do
    if entry.line_type == "paragraph" then table.insert( result, entry.frame.text ) end
  end

  return result
end

---@param label string
local function select_tab( page, label )
  local tabs = line( page, "tabs" )

  for index, tab_label in ipairs( tabs.labels ) do
    if tab_label == label then return tabs.on_select( index ) end
  end

  error( string.format( "There was no %q tab on the page.", label ), 2 )
end

OptionsPageSpec = {}

-- Summary first, tabs second, and the General tab open: a checkbox means nothing until you
-- know what it is you would be turning on.
function OptionsPageSpec:should_show_a_summary_then_the_general_tab()
  local page = shown_page( mock_context() )

  eq( line_types( page ), { "section_header", "paragraph", "tabs", "checkbox", "checkbox", "checkbox" } )
end

-- This addon's own copy, not something core handed over. Matched on what the pass actually does
-- rather than the opening line, which is the part most likely to get reworded.
function OptionsPageSpec:should_say_what_the_pass_does()
  local summary = line( shown_page( mock_context() ), "paragraph" ).text

  eq( string.find( summary, "Master-loots", 1, true ) ~= nil, true )
  eq( string.find( summary, "/rf autoloot", 1, true ) ~= nil, true )
end

TabsSpec = {}

function TabsSpec:should_offer_general_then_loot()
  local tabs = line( shown_page( mock_context() ), "tabs" )

  eq( tabs.labels, { "General", "Loot" } )
  eq( tabs.selected, 1 )
end

-- The summary stays put whichever tab is open; only what is under the tabs changes.
function TabsSpec:should_show_the_loot_tab_under_the_same_summary()
  local page = shown_page( mock_context() )

  select_tab( page, "Loot" )

  eq( line_types( page ), { "section_header", "paragraph", "tabs", "paragraph" } )
  eq( line( page, "tabs" ).selected, 2 )
  eq( string.find( paragraphs( page )[ 1 ], "Master-loots", 1, true ) ~= nil, true )
  eq( paragraphs( page )[ 2 ], "Hello world!" )
end

function TabsSpec:should_switch_back_to_the_general_tab()
  local page = shown_page( mock_context() )

  select_tab( page, "Loot" )
  select_tab( page, "General" )

  eq( line_types( page ), { "section_header", "paragraph", "tabs", "checkbox", "checkbox", "checkbox" } )
  eq( checkbox( page, "Auto-loot" ).checked, true )
end

-- Coming back to the settings window finds the page on the tab it was left on.
function TabsSpec:should_keep_the_open_tab_between_visits()
  local page = shown_page( mock_context() )

  select_tab( page, "Loot" )
  page.show()

  eq( line( page, "tabs" ).selected, 2 )
  eq( paragraphs( page )[ 2 ], "Hello world!" )
end

-- The open tab's content is boxed in under the tabs, so it is plain which tab it belongs to.
PanelSpec = {}

function PanelSpec:should_put_the_tab_contents_in_the_bordered_panel()
  local page = shown_page( mock_context() )

  eq( #page.get_panel().lines, 3 )
  eq( page.get_panel().backdrop.edgeFile, "Interface\\Tooltips\\UI-Tooltip-Border" )
end

function PanelSpec:should_hang_the_panel_under_the_tabs()
  local page = shown_page( mock_context() )
  local anchor = page.get_panel().anchor

  eq( anchor.relative_frame, line( page, "tabs" ) )
  eq( anchor.point, "TOPLEFT" )
  eq( anchor.relative_point, "BOTTOMLEFT" )
end

-- Across the page rather than as wide as its widest setting, reaching further left than the
-- summary, with the first tab held in from the panel's corner.
function PanelSpec:should_span_the_page()
  local page = shown_page( mock_context() )
  local panel = page.get_panel()

  eq( panel.anchor.x, -8 )
  eq( panel.width, CANVAS_WIDTH - 32 + 14 )
end

-- Room above the first line and below the last, whichever tab is open.
function PanelSpec:should_fit_its_lines()
  local page = shown_page( mock_context() )

  eq( page.get_panel().height, 12 + 20 + 5 + 20 + 5 + 20 + 12 )

  select_tab( page, "Loot" )

  eq( page.get_panel().height, 12 + 20 + 12 )
end

SettingsSpec = {}

-- The three settings that moved here with the addon, in the order they read: the feature, then
-- what it says out loud.
function SettingsSpec:should_draw_a_checkbox_per_setting()
  local page = shown_page( mock_context() )

  eq( checkbox( page, "Auto-loot" ).checked, true )
  eq( checkbox( page, "Announce auto-looted items" ).checked, true )
  eq( checkbox( page, "Auto-loot messages" ).checked, false )
end

-- Read from the config every time the page is shown, so a value changed by a slash command
-- since the last visit is picked up rather than remembered.
function SettingsSpec:should_reread_the_config_every_time_it_is_shown()
  local ctx = mock_context()
  local page = shown_page( ctx )

  ctx.config.set_auto_loot( false )
  page.show()

  eq( checkbox( page, "Auto-loot" ).checked, false )
end

function SettingsSpec:should_write_a_clicked_checkbox_back_to_the_config()
  local ctx = mock_context()
  local page = shown_page( ctx )

  checkbox( page, "Auto-loot messages" ).on_click( true )

  eq( ctx.config.auto_loot_messages(), true )
end

ExtensionSwitchSpec = {}

-- No Enabled switch, because "Auto-loot" is already it: two switches for one question could
-- disagree, and Auto-loot ticked on a disabled extension reads as broken. The addon declares
-- hide_enabled_option, so core draws none either and keeps the extension on -- which is what
-- makes leaving it off this page safe rather than a way to strand somebody.
function ExtensionSwitchSpec:should_not_draw_an_enabled_switch()
  local page = shown_page( mock_context() )

  for _, entry in ipairs( all_lines( page ) ) do
    eq( entry.frame.text ~= "Enabled", true, "The page still draws an Enabled switch." )
  end
end

-- It never asks core either. A page that read is_enabled would be showing a value nothing can
-- change, and one that wrote it would be writing something core refuses.
function ExtensionSwitchSpec:should_not_touch_cores_enabled_state()
  local ctx = mock_context()
  shown_page( ctx )

  eq( ctx.state.set_to, nil )
end

os.exit( lu.LuaUnit.run() )
