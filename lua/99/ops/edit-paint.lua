--- Edit-paint: mark regions as editable targets for multi-region visual edits

--- @class _99.EditPaint.Region
--- @field bufnr number
--- @field start_line number 1-indexed
--- @field end_line number 1-indexed
--- @field lines string[] The actual text content

--- @class _99.EditPaint.Opts
--- @field hl_group string Highlight group for edit-painted lines
--- @field sign_hl_group string Highlight group for the sign column

local M = {}

local default_opts = {
  hl_group = "99EditPaintLine",
  sign_hl_group = "99EditPaintSign",
}

--- @type _99.EditPaint.Opts
local current_opts = vim.deepcopy(default_opts)

--- @type _99.EditPaint.Region[]
local regions = {}

local ns_id = vim.api.nvim_create_namespace("99.edit_paint")

local function ensure_highlights()
  -- Light background tint for the line
  local ok, visual = pcall(vim.api.nvim_get_hl, 0, { name = "Visual" })
  local bg = (ok and visual and visual.bg) or 0x3a3a5c
  -- Lighten the bg a bit by blending toward white
  local r = math.min(255, math.floor(bg / 0x10000) + 30)
  local g = math.min(255, math.floor((bg / 0x100) % 0x100) + 30)
  local b = math.min(255, math.floor(bg % 0x100) + 30)
  local lighter = r * 0x10000 + g * 0x100 + b

  vim.api.nvim_set_hl(0, "99EditPaintLine", { bg = lighter, default = true })
  vim.api.nvim_set_hl(0, "99EditPaintSign", { fg = "#e5c07b", default = true })
end

--- @param range _99.Range
function M.add_region(range)
  ensure_highlights()

  local lines = vim.api.nvim_buf_get_lines(
    range.buffer,
    range.start.row - 1,
    range.end_.row,
    false
  )

  -- If all lines are blank, mark as empty so the AI knows to fill it
  local all_blank = true
  for _, line in ipairs(lines) do
    if line:match("%S") then
      all_blank = false
      break
    end
  end
  if all_blank then
    lines = { "-- EMPTY: area to be filled with new code" }
  end

  table.insert(regions, {
    bufnr = range.buffer,
    start_line = range.start.row,
    end_line = range.end_.row,
    lines = lines,
  })

  for line_num = range.start.row - 1, range.end_.row - 1 do
    local sign
    local total = range.end_.row - range.start.row + 1
    if total == 1 then
      sign = "│"
    elseif line_num == range.start.row - 1 then
      sign = "┌"
    elseif line_num == range.end_.row - 1 then
      sign = "└"
    else
      sign = "│"
    end

    vim.api.nvim_buf_set_extmark(range.buffer, ns_id, line_num, 0, {
      end_line = line_num + 1,
      hl_group = current_opts.hl_group,
      hl_eol = true,
      priority = 110,
    })
    vim.api.nvim_buf_set_extmark(range.buffer, ns_id, line_num, 0, {
      sign_text = sign,
      sign_hl_group = current_opts.sign_hl_group,
      priority = 110,
    })
  end
end

--- @return _99.EditPaint.Region[]
function M.get_all_regions()
  return vim.deepcopy(regions)
end

--- @return number
function M.count()
  return #regions
end

function M.clear()
  for _, region in ipairs(regions) do
    if vim.api.nvim_buf_is_valid(region.bufnr) then
      vim.api.nvim_buf_clear_namespace(region.bufnr, ns_id, 0, -1)
    end
  end
  regions = {}
end

--- Configure edit-paint highlights
--- @param opts _99.EditPaint.Opts?
function M.setup(opts)
  current_opts = vim.tbl_deep_extend("force", default_opts, opts or {})
end

return M
