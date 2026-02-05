--- Diff visualization with accept/reject flow
--- Shows AI changes in a diff view before applying

--- @class _99.Diff.Opts
--- @field enabled boolean Whether diff visualization is enabled
--- @field highlight_numbers_on_accept boolean Whether to highlight line numbers after accepting

--- @class _99.Diff.PendingChange
--- @field id number
--- @field bufnr number
--- @field original_lines string[]
--- @field new_lines string[]
--- @field start_row number 0-indexed
--- @field end_row number 0-indexed (exclusive)
--- @field extmark_ids number[] All extmark IDs for this change

local M = {}

local default_opts = {
  enabled = false,
  highlight_numbers_on_accept = true,
}

--- @type _99.Diff.Opts
local current_opts = vim.deepcopy(default_opts)

--- @type table<number, _99.Diff.PendingChange>
local pending_changes = {}

local ns_id = vim.api.nvim_create_namespace("99.diff")
local change_id_counter = 0

--- Show the diff overlay for a pending change
--- @param change _99.Diff.PendingChange
local function show_diff_overlay(change)
  vim.schedule(function()
    if not pending_changes[change.id] then
      return
    end

    local bufnr = change.bufnr
    local start_row = change.start_row
    local original = change.original_lines
    local new = change.new_lines

    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    -- Replace the buffer lines with the new code
    vim.api.nvim_buf_set_lines(bufnr, start_row, change.end_row, false, new)

    change.extmark_ids = {}

    -- Build virtual lines for the original code (red)
    local virt_lines = {}
    for _, line in ipairs(original) do
      table.insert(virt_lines, { { "- " .. line, "DiffDelete" } })
    end

    -- Place virtual lines above the changed region
    local virt_extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, 0, {
      virt_lines = virt_lines,
      virt_lines_above = true,
    })
    table.insert(change.extmark_ids, virt_extmark_id)

    -- Highlight the new code region
    local new_end_row = start_row + #new
    for i = start_row, new_end_row - 1 do
      local hl_extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, i, 0, {
        line_hl_group = "DiffAdd",
      })
      table.insert(change.extmark_ids, hl_extmark_id)
    end

    -- Update end_row to reflect the new line count
    change.end_row = new_end_row
  end)
end

--- Find the pending change at cursor position
--- @param bufnr number
--- @param row number 0-indexed cursor row
--- @return _99.Diff.PendingChange|nil
local function find_change_at_cursor(bufnr, row)
  for _, change in pairs(pending_changes) do
    if change.bufnr == bufnr then
      if row >= change.start_row and row < change.end_row then
        return change
      end
    end
  end
  return nil
end

--- Accept a specific change
--- @param change _99.Diff.PendingChange
local function accept_change(change)
  local bufnr = change.bufnr
  local start_row = change.start_row
  local end_row = change.end_row

  -- Remove all extmarks
  if change.extmark_ids and vim.api.nvim_buf_is_valid(bufnr) then
    for _, extmark_id in ipairs(change.extmark_ids) do
      pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)
    end
  end

  -- Add number highlighting to show accepted AI code
  if current_opts.highlight_numbers_on_accept then
    for i = start_row, end_row - 1 do
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, i, 0, {
        number_hl_group = "DiffAdd",
      })
    end
  end

  pending_changes[change.id] = nil
  vim.notify("AI changes accepted", vim.log.levels.INFO)
end

--- Reject a specific change
--- @param change _99.Diff.PendingChange
local function reject_change(change)
  local bufnr = change.bufnr
  local start_row = change.start_row
  local end_row = change.end_row
  local original_lines = change.original_lines

  -- Remove all extmarks
  if change.extmark_ids and vim.api.nvim_buf_is_valid(bufnr) then
    for _, extmark_id in ipairs(change.extmark_ids) do
      pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)
    end
  end

  -- Restore original lines
  vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, false, original_lines)

  pending_changes[change.id] = nil
  vim.notify("AI changes rejected", vim.log.levels.INFO)
end

--- Store a pending change for review
--- @param bufnr number
--- @param start_row number 0-indexed
--- @param end_row number 0-indexed (exclusive)
--- @param new_lines string[]
--- @return boolean success
function M.store_pending(bufnr, start_row, end_row, new_lines)
  if not current_opts.enabled then
    return false
  end

  -- Remove leading empty line if present (added by over-range.lua HACK)
  -- and adjust start_row to compensate
  if #new_lines > 0 and new_lines[1] == "" then
    table.remove(new_lines, 1)
    start_row = start_row + 1
  end

  -- Remove trailing empty line if present
  if #new_lines > 0 and new_lines[#new_lines] == "" then
    table.remove(new_lines, #new_lines)
  end

  -- Get original lines before they're replaced
  local original_lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)

  change_id_counter = change_id_counter + 1
  local change = {
    id = change_id_counter,
    bufnr = bufnr,
    original_lines = original_lines,
    new_lines = new_lines,
    start_row = start_row,
    end_row = end_row,
    extmark_ids = {},
  }

  pending_changes[change.id] = change
  show_diff_overlay(change)

  return true
end

--- Accept the change at cursor
function M.accept()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1

  local change = find_change_at_cursor(bufnr, row)
  if change then
    accept_change(change)
  else
    vim.notify("No pending AI changes at cursor", vim.log.levels.WARN)
  end
end

--- Reject the change at cursor
function M.reject()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1

  local change = find_change_at_cursor(bufnr, row)
  if change then
    reject_change(change)
  else
    vim.notify("No pending AI changes at cursor", vim.log.levels.WARN)
  end
end

--- Check if diff is enabled
--- @return boolean
function M.is_enabled()
  return current_opts.enabled
end

--- Configure diff options
--- @param opts _99.Diff.Opts?
function M.setup(opts)
  current_opts = vim.tbl_deep_extend("force", default_opts, opts or {})
end

--- Get current options
--- @return _99.Diff.Opts
function M.get_opts()
  return vim.deepcopy(current_opts)
end

return M
