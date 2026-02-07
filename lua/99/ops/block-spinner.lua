--- Block spinner that fills a buffer region with animated diagonal lines
--- Based on code from https://github.com/olimorris/codecompanion.nvim/discussions/1297
--- Credit https://github.com/lucobellic

--- @class _99.BlockSpinner.Opts
--- @field hl_group string Highlight group for the diagonal lines
--- @field repeat_interval number Milliseconds between frame updates
--- @field extmark vim.api.keyset.set_extmark Extmark options
--- @field patterns? string[] Custom patterns to cycle through

local default_opts = {
  hl_group = "Comment",
  repeat_interval = 100,
  extmark = {
    virt_text_pos = "overlay",
    priority = 2048,
  },
  patterns = nil, -- Will use default diagonal patterns
}

--- @class _99.BlockSpinner
--- @field bufnr number
--- @field ns_id number
--- @field start_line number 0-indexed
--- @field end_line number 0-indexed
--- @field width number Width of the content area
--- @field patterns string[] Spinner patterns to cycle through
--- @field current_index number Current pattern index
--- @field timer uv.uv_timer_t|nil
--- @field stopped boolean
--- @field opts table
--- @field extmark_ids table<number, number> Extmark IDs indexed by line number
local BlockSpinner = {}
BlockSpinner.__index = BlockSpinner

--- @class _99.BlockSpinner.NewOpts
--- @field bufnr number
--- @field ns_id number
--- @field start_line number 1-indexed
--- @field end_line number 1-indexed
--- @field opts? _99.BlockSpinner.Opts

--- Creates a new BlockSpinner instance
--- @param opts _99.BlockSpinner.NewOpts
--- @return _99.BlockSpinner
function BlockSpinner.new(opts)
  local merged = vim.tbl_deep_extend("force", default_opts, opts.opts or {})
  local bufnr = opts.bufnr
  local start_line = opts.start_line - 1 -- convert to 0-indexed
  local end_line = opts.end_line - 1

  -- Calculate width from buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
  local width = 0
  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > width then
      width = w
    end
  end
  -- Ensure minimum width
  if width < 20 then
    width = 20
  end

  -- Setup patterns
  local raw_patterns = merged.patterns or {
    "╲  ",
    " ╲ ",
    "  ╲",
  }

  -- Calculate repetitions needed to fill the width
  local pattern_width = vim.fn.strdisplaywidth(raw_patterns[1])
  local repetitions = pattern_width > 0 and math.ceil(width / pattern_width) or width
  width = repetitions * pattern_width

  -- Create final patterns by repeating
  local patterns = {}
  for _, pattern in ipairs(raw_patterns) do
    table.insert(patterns, string.rep(pattern, repetitions))
  end

  local self = setmetatable({
    bufnr = bufnr,
    ns_id = opts.ns_id,
    start_line = start_line,
    end_line = end_line,
    width = width,
    patterns = patterns,
    current_index = 1,
    timer = vim.uv.new_timer(),
    stopped = false,
    opts = merged,
    extmark_ids = {},
  }, BlockSpinner)

  return self
end

--- Get virtual text for a specific line based on current animation frame
--- @param line number 0-indexed line number
--- @return string
function BlockSpinner:get_pattern_for_line(line)
  -- Offset pattern by line to create diagonal effect
  local pattern_index = ((line + self.current_index - 1) % #self.patterns) + 1
  return self.patterns[pattern_index]
end

--- Render the current frame of the diagonal animation
function BlockSpinner:render()
  if self.stopped then
    return
  end
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    self:stop()
    return
  end

  local hl = self.opts.hl_group
  local priority = self.opts.extmark.priority

  for line = self.start_line, self.end_line do
    local text = self:get_pattern_for_line(line)
    local id = self.extmark_ids[line]
    
    if id then
      -- Update existing extmark
      pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, line, 0, {
        id = id,
        virt_text = { { text, hl } },
        virt_text_pos = "overlay",
        priority = priority,
      })
    else
      -- Create new extmark
      local ok, eid = pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, line, 0, {
        virt_text = { { text, hl } },
        virt_text_pos = "overlay",
        priority = priority,
      })
      if ok then
        self.extmark_ids[line] = eid
      end
    end
  end
end

--- Start the block spinner animation
function BlockSpinner:start()
  self:render()

  self.timer:start(
    0,
    self.opts.repeat_interval,
    vim.schedule_wrap(function()
      if self.stopped then
        return
      end
      self.current_index = (self.current_index % #self.patterns) + 1
      self:render()
    end)
  )
end

--- Stop the block spinner animation
function BlockSpinner:stop()
  self.stopped = true
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end

  -- Clean up extmarks
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    for _, eid in pairs(self.extmark_ids) do
      pcall(vim.api.nvim_buf_del_extmark, self.bufnr, self.ns_id, eid)
    end
  end
  self.extmark_ids = {}
end

return BlockSpinner
