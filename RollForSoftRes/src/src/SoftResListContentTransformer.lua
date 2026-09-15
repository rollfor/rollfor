RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResListContentTransformer then return end

local M = {}

-- The soft-res list as lines the window draws.
--
-- Its own module for the reason every other RollFor window's transformer is: what a row says is
-- decided here, out of plain tables, where a test can read it -- the frame builds widgets, and a
-- widget is not something an assertion can ask a question of.

-- Every row is padded the same. A wider gap on the first one would disappear with that row once
-- the list scrolls -- see AutoRoundRobinQueueFrameContentTransformer.
local row_gap = 2
local empty_notice_gap = 10

-- The popup reserves a flat 23 below its content, which less the window's top padding leaves the
-- last row nearly on the border. The trailing spacer is invisible, so its padding widens that gap;
-- PendingLootContentTransformer does the same with a negative number to narrow it. 12 on top of
-- ListPopup's default padding of 16, and 5 more for the 5 SoftResListFrame adds to it.
local bottom_gap = 17

M.row_type = "softres_list_row"
M.header_type = "softres_list_header"

---@alias SoftResListColumn
---| "player"
---| "item"
---| "boss"

---@class SoftResListFrameRow
---@field player string -- already coloured
---@field count string? -- 2x, drawn left of the item; nil for a single roll and for a player who
--- reserved nothing
---@field item_link string -- a placeholder while the client doesn't have the item, or a note for a
--- player who reserved nothing
---@field item_tooltip_link TooltipItemLink?
---@field adjustment string? -- " +30", drawn right after the item link; nil when no modifier adds anything
---@field boss string -- already coloured

-- How wide the widest entry in each column draws, over the whole list. Every line of a redraw gets
-- the same one, so the header and the rows lay their columns out alike.
---@class SoftResListWidths
---@field player number
---@field count number -- 0 when nobody has more than one roll
---@field item number
---@field boss number

---@class SoftResListFrameData
---@field show_absent boolean
---@field on_toggle_absent fun( checked: boolean )
---@field sort_column SoftResListColumn
---@field sort_ascending boolean
---@field on_sort fun( column: SoftResListColumn )
---@field rows SoftResListFrameRow[]
---@field widths SoftResListWidths

---@class SoftResListContentTransformer
---@field transform fun( data: SoftResListFrameData ): table[]

---@return SoftResListContentTransformer
function M.new()
  ---@param data SoftResListFrameData
  local function transform( data )
    local content = {}

    table.insert( content, {
      type = M.header_type,
      show_absent = data.show_absent,
      on_toggle_absent = data.on_toggle_absent,
      sort_column = data.sort_column,
      sort_ascending = data.sort_ascending,
      on_sort = data.on_sort,
      widths = data.widths
    } )

    for _, row in ipairs( data.rows ) do
      table.insert( content, {
        type = M.row_type,
        player = row.player,
        item_link = row.item_link,
        item_tooltip_link = row.item_tooltip_link,
        count = row.count,
        adjustment = row.adjustment,
        boss = row.boss,
        widths = data.widths,
        padding = row_gap
      } )
    end

    if #data.rows == 0 then
      table.insert( content, { type = "text", value = "No soft-res entries.", padding = empty_notice_gap } )
    end

    table.insert( content, { type = "empty_line", padding = bottom_gap } )

    return content
  end

  return { transform = transform }
end

sr.SoftResListContentTransformer = M
return M
