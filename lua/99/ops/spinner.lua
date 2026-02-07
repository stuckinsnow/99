--- Virtual text spinner with centered "Processing" text
--- Based on code from https://github.com/olimorris/codecompanion.nvim/discussions/1297
--- Credit https://github.com/lucobellic

--- @class _99.Spinner.Opts
--- @field spinner_text string Text to display before the spinner
--- @field spinner_frames string[] Spinner frames to use for the spinner
--- @field hl_group string Highlight group for the spinner
--- @field repeat_interval number Interval in milliseconds to update the spinner
--- @field extmark vim.api.keyset.set_extmark Extmark options passed to nvim_buf_set_extmark

local default_opts = {
  spinner_text = "  Processing",
  spinner_frames = { "⣷", "⣯", "⣟", "⡿", "⢿", "⣻", "⣽", "⣾" },
  hl_group = "DiagnosticVirtualTextWarn",
  repeat_interval = 100,
  extmark = {
    virt_text_pos = "overlay",
    priority = 2049,
  },
}

--- @class _99.Spinner
--- @field bufnr number The buffer number where the spinner is displayed
--- @field ns_id number The namespace ID for the extmark
--- @field line_num number The line number where the spinner is displayed (0-indexed)
--- @field current_index number Current index in the spinner frames array
--- @field timer uv.uv_timer_t|nil Timer used to update spinner animation
--- @field stopped boolean Whether the spinner has been stopped
--- @field opts _99.Spinner.Opts Configuration options for the spinner
--- @field virt_text_segments table[]|nil Custom virtual text segments with colors
local Spinner = {}
Spinner.__index = Spinner

--- @class _99.Spinner.NewOpts
--- @field bufnr number Buffer number to display the spinner in
--- @field ns_id number Namespace ID for the extmark
--- @field line_num number Line number to display the spinner on (1-indexed)
--- @field width? number Width of the content area for centering
--- @field opts? _99.Spinner.Opts Optional configuration options

--- Creates a new Spinner instance
--- @param opts _99.Spinner.NewOpts Options for the spinner
--- @return _99.Spinner
function Spinner.new(opts)
  local width = opts.width or 0
  local merged_opts = vim.tbl_deep_extend("force", default_opts, opts.opts or {})

  -- Calculate center position
  local width_center = width - merged_opts.spinner_text:len()
  local col = width_center > 0 and math.floor(width_center / 2) or 0

  local self = setmetatable({
    bufnr = opts.bufnr,
    ns_id = opts.ns_id,
    line_num = opts.line_num - 1,
    current_index = 1,
    timer = vim.uv.new_timer(),
    stopped = false,
    virt_text_segments = nil,
    opts = vim.tbl_deep_extend("force", merged_opts, { extmark = { virt_text_win_col = col } }),
  }, Spinner)

  return self
end

--- Updates the spinner text dynamically
--- @param text string New text to display
function Spinner:update_text(text)
  self.opts.spinner_text = text
  self.virt_text_segments = nil
end

--- Updates the spinner with colored virtual text segments
--- @param segments table[] Array of {text, hl_group} tuples
function Spinner:update_virt_text(segments)
  self.virt_text_segments = segments
end

--- Gets the virtual text content for the spinner
--- @return table[]
function Spinner:get_virtual_text()
  if self.virt_text_segments then
    -- Use colored segments with spinner frame
    local result = {}
    -- Add spinner frame at the beginning
    table.insert(result, {"  " .. self.opts.spinner_frames[self.current_index] .. " ", self.opts.hl_group})
    -- Add colored text segments
    for _, segment in ipairs(self.virt_text_segments) do
      table.insert(result, segment)
    end
    return result
  else
    -- Use simple text with spinner frame
    return { { self.opts.spinner_text .. " " .. self.opts.spinner_frames[self.current_index] .. " ", self.opts.hl_group } }
  end
end

--- @return number id of the extmark
function Spinner:set_extmark()
  return vim.api.nvim_buf_set_extmark(self.bufnr, self.ns_id, self.line_num, 0, self.opts.extmark)
end

--- Starts the spinner animation
function Spinner:start()
  self.opts.extmark.virt_text = self:get_virtual_text()
  self.opts.extmark.id = self:set_extmark()

  self.timer:start(
    0,
    self.opts.repeat_interval,
    vim.schedule_wrap(function()
      if self.stopped then
        return
      end
      self.current_index = self.current_index % #self.opts.spinner_frames + 1
      self.opts.extmark.virt_text = self:get_virtual_text()
      self:set_extmark()
    end)
  )
end

--- Stops the spinner animation
function Spinner:stop()
  self.stopped = true
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end

  if self.opts.extmark and self.opts.extmark.id then
    pcall(vim.api.nvim_buf_del_extmark, self.bufnr, self.ns_id, self.opts.extmark.id)
  end
end

return Spinner
