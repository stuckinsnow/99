--- Diagonal lines animation style for processing indicators
--- Shows animated diagonal line patterns across the target region
--- with multi-line status text overlay in the middle.
---
--- This is a SEPARATE animation option from inline-marks.
--- Based on code from https://github.com/olimorris/codecompanion.nvim/discussions/1297
--- Credit https://github.com/lucobellic

--- @class _99.DiagonalLines.Opts
--- @field enabled boolean Whether diagonal lines animation is enabled
--- @field hl_group string Highlight group for the diagonal pattern
--- @field status_hl_group string Highlight group for the status text
--- @field priority number Priority for extmarks
--- @field repeat_interval number Milliseconds between animation frame updates
--- @field max_status_lines number Maximum number of status lines to show
--- @field show_status boolean Whether to show status text in the block (set to false if using noice)

--- @class _99.DiagonalLines.Context
--- @field bufnr number
--- @field start_line number 1-indexed
--- @field end_line number 1-indexed

--- @class _99.DiagonalLines.ActiveAnim
--- @field bufnr number
--- @field ns_id number
--- @field start_line number 0-indexed
--- @field end_line number 0-indexed
--- @field block_spinner _99.BlockSpinner|nil
--- @field status_lines string[] Buffer of status messages
--- @field status_extmarks number[] Extmark IDs for status lines

local M = {}

local default_opts = {
  enabled = false,
  hl_group = "Comment",
  status_hl_group = "DiagnosticVirtualTextWarn",
  priority = 2048,
  repeat_interval = 100,
  max_status_lines = 5,
  show_status = true, -- Set to false if using noice_status
}

--- @type _99.DiagonalLines.Opts
local current_opts = vim.deepcopy(default_opts)

--- @type table<number, _99.DiagonalLines.ActiveAnim>
local active_anims = {}

--- Strip ANSI codes from a string
--- @param str string
--- @return string
local function strip_ansi(str)
  return str:gsub("\27%[[%d;]*m", "")
end

--- Update status text display in the middle of the region
--- @param anim _99.DiagonalLines.ActiveAnim
local function update_status_display(anim)
  -- Don't show status if disabled
  if not current_opts.show_status then
    return
  end
  
  -- Clear old status extmarks
  for _, eid in ipairs(anim.status_extmarks) do
    pcall(vim.api.nvim_buf_del_extmark, anim.bufnr, anim.ns_id, eid)
  end
  anim.status_extmarks = {}
  
  if #anim.status_lines == 0 then
    return
  end
  
  -- Calculate available space
  local total_lines = anim.end_line - anim.start_line + 1
  local max_lines = math.min(current_opts.max_status_lines, total_lines)
  
  -- Get last N status lines
  local start_idx = math.max(1, #anim.status_lines - max_lines + 1)
  local display_lines = {}
  for i = start_idx, #anim.status_lines do
    display_lines[#display_lines + 1] = strip_ansi(anim.status_lines[i])
  end
  
  -- Calculate center position
  local center_line = anim.start_line + math.floor(total_lines / 2)
  local start_display_line = center_line - math.floor(#display_lines / 2)
  
  -- Display status lines
  for i, text in ipairs(display_lines) do
    local line = start_display_line + i - 1
    if line >= anim.start_line and line <= anim.end_line then
      local ok, eid = pcall(vim.api.nvim_buf_set_extmark, anim.bufnr, anim.ns_id, line, 0, {
        virt_text = { { "  " .. text, current_opts.status_hl_group } },
        virt_text_pos = "overlay",
        priority = current_opts.priority + 1,
      })
      if ok then
        anim.status_extmarks[#anim.status_extmarks + 1] = eid
      end
    end
  end
end

--- Create diagonal lines animation for a given context
--- @param context _99.DiagonalLines.Context
--- @param id string|number|nil Optional unique identifier
--- @return number ns_id The namespace id for this animation
function M.create(context, id)
  if not current_opts.enabled then
    return -1
  end

  local ns_name = "99.diagonal_lines_" .. tostring(id or vim.uv.hrtime())
  local ns_id = vim.api.nvim_create_namespace(ns_name)

  local BlockSpinner = require("99.ops.block-spinner")

  local block_spinner = BlockSpinner.new({
    bufnr = context.bufnr,
    ns_id = ns_id,
    start_line = context.start_line,
    end_line = context.end_line,
    opts = {
      hl_group = current_opts.hl_group,
      repeat_interval = current_opts.repeat_interval,
      extmark = {
        virt_text_pos = "overlay",
        priority = current_opts.priority,
      },
    },
  })

  local anim = {
    bufnr = context.bufnr,
    ns_id = ns_id,
    start_line = context.start_line - 1, -- 0-indexed
    end_line = context.end_line - 1,     -- 0-indexed
    block_spinner = block_spinner,
    status_lines = {},
    status_extmarks = {},
  }
  active_anims[ns_id] = anim

  block_spinner:start()

  return ns_id
end

--- Update the status text displayed in the middle
--- @param ns_id number
--- @param line string
function M.update_status(ns_id, line)
  if ns_id < 0 then
    return
  end

  local anim = active_anims[ns_id]
  if not anim then
    return
  end
  
  -- Don't process status if disabled
  if not current_opts.show_status then
    return
  end
  
  -- Add line to buffer
  anim.status_lines[#anim.status_lines + 1] = line
  
  -- Keep only last max_lines * 2 in memory
  if #anim.status_lines > current_opts.max_status_lines * 2 then
    table.remove(anim.status_lines, 1)
  end
  
  update_status_display(anim)
end

--- Clear diagonal lines animation for a given namespace
--- @param ns_id number
function M.clear(ns_id)
  if ns_id < 0 then
    return
  end

  local anim = active_anims[ns_id]
  if anim then
    if anim.block_spinner then
      anim.block_spinner:stop()
    end
    if vim.api.nvim_buf_is_valid(anim.bufnr) then
      vim.api.nvim_buf_clear_namespace(anim.bufnr, ns_id, 0, -1)
    end
  end

  active_anims[ns_id] = nil
end

--- Clear all active diagonal line animations
function M.clear_all()
  for ns_id, _ in pairs(active_anims) do
    M.clear(ns_id)
  end
  active_anims = {}
end

--- Check if diagonal lines animation is enabled
--- @return boolean
function M.is_enabled()
  return current_opts.enabled
end

--- Configure diagonal lines options
--- @param opts _99.DiagonalLines.Opts?
function M.setup(opts)
  current_opts = vim.tbl_deep_extend("force", default_opts, opts or {})
end

--- Get current options (for debugging/testing)
--- @return _99.DiagonalLines.Opts
function M.get_opts()
  return vim.deepcopy(current_opts)
end

return M
