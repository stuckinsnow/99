--- Inline indicator with signs (│, ┌, └) + optional spinner
--- Based on code from https://github.com/olimorris/codecompanion.nvim/discussions/1297
--- Credit https://github.com/lucobellic

--- @class _99.InlineMarks.Opts
--- @field enabled boolean Whether inline marks are enabled
--- @field unique_line_sign_text string Text used for sign when there's only a single line
--- @field first_line_sign_text string Text used for sign on the first line of multi-line section
--- @field last_line_sign_text string Text used for sign on the last line of multi-line section
--- @field middle_line_sign_text string Text used for sign on middle lines
--- @field sign_hl_group string Highlight group for signs
--- @field priority number Priority for extmarks
--- @field spinner_interval number Milliseconds between spinner frame updates

--- @class _99.InlineMarks.Context
--- @field bufnr number
--- @field start_line number 1-indexed
--- @field end_line number 1-indexed

--- @class _99.InlineMarks.ActiveMark
--- @field bufnr number
--- @field ns_id number
--- @field spinner _99.Spinner|nil

local M = {}

local default_opts = {
  enabled = false,
  unique_line_sign_text = "│",
  first_line_sign_text = "┌",
  last_line_sign_text = "└",
  middle_line_sign_text = "│",
  sign_hl_group = "Comment",
  priority = 2048,
  spinner_interval = 100,
}

--- @type _99.InlineMarks.Opts
local current_opts = vim.deepcopy(default_opts)

--- @type table<number, _99.InlineMarks.ActiveMark>
local active_marks = {}

--- Helper function to set a line extmark with specified sign text
--- @param bufnr number
--- @param ns_id number
--- @param line_num number 1-indexed line number
--- @param sign_text string
local function set_line_extmark(bufnr, ns_id, line_num, sign_text)
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_num - 1, 0, {
    sign_text = sign_text,
    sign_hl_group = current_opts.sign_hl_group,
    priority = current_opts.priority,
  })
end

--- Creates sign extmarks for inline code annotations
--- @param context _99.InlineMarks.Context
--- @param ns_id number
local function create_sign_extmarks(context, ns_id)
  local bufnr = context.bufnr
  local start_line = context.start_line
  local end_line = context.end_line

  -- Handle the case where start and end lines are the same (unique line)
  if start_line == end_line then
    set_line_extmark(bufnr, ns_id, start_line, current_opts.unique_line_sign_text)
    return
  end

  -- Set extmark for the first line
  set_line_extmark(bufnr, ns_id, start_line, current_opts.first_line_sign_text)

  -- Set extmarks for the middle lines
  for i = start_line + 1, end_line - 1 do
    set_line_extmark(bufnr, ns_id, i, current_opts.middle_line_sign_text)
  end

  -- Set extmark for the last line
  if end_line > start_line then
    set_line_extmark(bufnr, ns_id, end_line, current_opts.last_line_sign_text)
  end
end

--- Start the center spinner with "Processing..." text
--- @param mark _99.InlineMarks.ActiveMark
--- @param context _99.InlineMarks.Context
local function start_spinner(mark, context)
  local Spinner = require("99.ops.spinner")

  local start_line = context.start_line
  local end_line = context.end_line

  -- Calculate width for centering the spinner text
  local lines = vim.api.nvim_buf_get_lines(context.bufnr, start_line - 1, end_line, false)
  local width = 0
  for _, line in ipairs(lines) do
    local line_width = vim.fn.strdisplaywidth(line)
    if line_width > width then
      width = line_width
    end
  end

  -- Calculate center line for spinner placement
  local center_line = start_line + math.floor((end_line - start_line) / 2)

  local spinner = Spinner.new({
    bufnr = context.bufnr,
    ns_id = mark.ns_id,
    line_num = center_line,
    width = width,
    opts = {
      repeat_interval = current_opts.spinner_interval,
      extmark = {
        virt_text_pos = "overlay",
        priority = current_opts.priority + 1,
      },
    },
  })

  mark.spinner = spinner
  spinner:start()
end

--- Create inline marks for a given context
--- @param context _99.InlineMarks.Context
--- @param id string|number Optional unique identifier
--- @return number ns_id The namespace id for these marks
function M.create(context, id)
  if not current_opts.enabled then
    return -1
  end

  local ns_name = "99.inline_marks_" .. tostring(id or vim.uv.hrtime())
  local ns_id = vim.api.nvim_create_namespace(ns_name)

  local mark = {
    bufnr = context.bufnr,
    ns_id = ns_id,
    spinner = nil,
  }
  active_marks[ns_id] = mark

  create_sign_extmarks(context, ns_id)
  start_spinner(mark, context)

  return ns_id
end

--- Clear inline marks for a given namespace
--- @param ns_id number
function M.clear(ns_id)
  if ns_id < 0 then
    return
  end

  local mark = active_marks[ns_id]
  if mark then
    if mark.spinner then
      mark.spinner:stop()
    end
    if vim.api.nvim_buf_is_valid(mark.bufnr) then
      vim.api.nvim_buf_clear_namespace(mark.bufnr, ns_id, 0, -1)
    end
  end

  active_marks[ns_id] = nil
end

--- Clear all active inline marks
function M.clear_all()
  for ns_id, _ in pairs(active_marks) do
    M.clear(ns_id)
  end
  active_marks = {}
end

--- Check if inline marks are enabled
--- @return boolean
function M.is_enabled()
  return current_opts.enabled
end

--- Configure inline marks options
--- @param opts _99.InlineMarks.Opts?
function M.setup(opts)
  current_opts = vim.tbl_deep_extend("force", default_opts, opts or {})
end

--- Get current options (for debugging/testing)
--- @return _99.InlineMarks.Opts
function M.get_opts()
  return vim.deepcopy(current_opts)
end

return M
