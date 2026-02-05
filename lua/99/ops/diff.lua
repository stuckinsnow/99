--- Diff visualization with accept/reject flow
--- Shows AI changes in a diff view before applying
--- Supports multiple concurrent pending changes

--- @class _99.Diff.Opts
--- @field enabled boolean Whether diff visualization is enabled

--- @class _99.Diff.PendingChange
--- @field id number
--- @field bufnr number
--- @field original_lines string[]
--- @field new_lines string[]
--- @field start_row number 0-indexed
--- @field end_row number 0-indexed (exclusive)
--- @field extmark_id number|nil

local M = {}

local default_opts = {
  enabled = false,
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

    -- Build virtual lines for the diff
    local virt_lines = {}

    -- Add header
    table.insert(virt_lines, { { "── AI Changes (9a to accept, 9r to reject) ──", "WarningMsg" } })
    table.insert(virt_lines, { { "", "Normal" } })

    -- Show removed lines (original) in red
    for _, line in ipairs(original) do
      table.insert(virt_lines, { { "- " .. line, "DiffDelete" } })
    end

    table.insert(virt_lines, { { "", "Normal" } })

    -- Show added lines (new) in green
    for _, line in ipairs(new) do
      table.insert(virt_lines, { { "+ " .. line, "DiffAdd" } })
    end

    table.insert(virt_lines, { { "", "Normal" } })
    table.insert(virt_lines, { { "────────────────────────────────────────────", "WarningMsg" } })

    -- Place virtual lines above the changed region
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local place_row = start_row
    if place_row >= line_count then
      place_row = line_count - 1
    end
    if place_row < 0 then
      place_row = 0
    end

    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, place_row, 0, {
      virt_lines = virt_lines,
      virt_lines_above = true,
    })

    change.extmark_id = extmark_id
  end)
end

--- Find the pending change at cursor position
--- @param bufnr number
--- @param row number 0-indexed cursor row
--- @return _99.Diff.PendingChange|nil
local function find_change_at_cursor(bufnr, row)
  -- First try exact match - cursor is within the change region
  for _, change in pairs(pending_changes) do
    if change.bufnr == bufnr then
      if row >= change.start_row and row < change.end_row then
        return change
      end
    end
  end

  -- Second try - find closest change above or at cursor
  local closest = nil
  local closest_dist = math.huge

  for _, change in pairs(pending_changes) do
    if change.bufnr == bufnr then
      -- Check distance from cursor to change region
      local dist
      if row < change.start_row then
        dist = change.start_row - row
      elseif row >= change.end_row then
        dist = row - change.end_row + 1
      else
        dist = 0
      end

      if dist < closest_dist then
        closest_dist = dist
        closest = change
      end
    end
  end

  return closest
end

--- Find any pending change in the buffer (fallback)
--- @param bufnr number
--- @return _99.Diff.PendingChange|nil
local function find_any_change_in_buffer(bufnr)
  for _, change in pairs(pending_changes) do
    if change.bufnr == bufnr then
      return change
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
  local new_lines = change.new_lines

  -- Remove extmark
  if change.extmark_id and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, change.extmark_id)
  end

  -- Remove from pending
  pending_changes[change.id] = nil

  -- Apply the changes
  vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, false, new_lines)

  vim.notify("AI changes accepted", vim.log.levels.INFO)
end

--- Reject a specific change
--- @param change _99.Diff.PendingChange
local function reject_change(change)
  local bufnr = change.bufnr

  -- Remove extmark
  if change.extmark_id and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, change.extmark_id)
  end

  -- Remove from pending
  pending_changes[change.id] = nil

  vim.notify("AI changes rejected", vim.log.levels.INFO)
end

--- Set up global keymaps (only once)
local keymaps_setup = false
local function setup_keymaps()
  if keymaps_setup then
    return
  end
  keymaps_setup = true

  vim.keymap.set("n", "9a", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1 -- Convert to 0-indexed

    local change = find_change_at_cursor(bufnr, row)
    if not change then
      -- Fallback: find any change in buffer
      change = find_any_change_in_buffer(bufnr)
    end

    if change then
      accept_change(change)
    else
      vim.notify("No pending AI changes at cursor", vim.log.levels.WARN)
    end
  end, { desc = "Accept AI changes at cursor" })

  vim.keymap.set("n", "9r", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1 -- Convert to 0-indexed

    local change = find_change_at_cursor(bufnr, row)
    if not change then
      -- Fallback: find any change in buffer
      change = find_any_change_in_buffer(bufnr)
    end

    if change then
      reject_change(change)
    else
      vim.notify("No pending AI changes at cursor", vim.log.levels.WARN)
    end
  end, { desc = "Reject AI changes at cursor" })
end

--- Store a pending change for review
--- @param bufnr number
--- @param start_row number 0-indexed
--- @param end_row number 0-indexed (exclusive)
--- @param new_lines string[]
--- @return boolean success Whether the change was stored (false if diff disabled)
function M.store_pending(bufnr, start_row, end_row, new_lines)
  if not current_opts.enabled then
    return false
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
    extmark_id = nil,
  }

  pending_changes[change.id] = change
  show_diff_overlay(change)
  setup_keymaps()

  return true
end

--- Accept the change at cursor (called by keymap)
function M.accept()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1

  local change = find_change_at_cursor(bufnr, row) or find_any_change_in_buffer(bufnr)
  if change then
    accept_change(change)
  end
end

--- Reject the change at cursor (called by keymap)
function M.reject()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1

  local change = find_change_at_cursor(bufnr, row) or find_any_change_in_buffer(bufnr)
  if change then
    reject_change(change)
  end
end

--- Check if there are any pending changes
--- @return boolean
function M.has_pending()
  return next(pending_changes) ~= nil
end

--- Get count of pending changes
--- @return number
function M.pending_count()
  local count = 0
  for _ in pairs(pending_changes) do
    count = count + 1
  end
  return count
end

--- Clear all pending changes
function M.clear_all()
  for id, change in pairs(pending_changes) do
    if change.extmark_id and vim.api.nvim_buf_is_valid(change.bufnr) then
      pcall(vim.api.nvim_buf_del_extmark, change.bufnr, ns_id, change.extmark_id)
    end
    pending_changes[id] = nil
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
