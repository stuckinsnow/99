--- Paint (mark) regions to include as context in subsequent operations
--- Allows building up multiple context regions before executing a command

--- @class _99.Paint.Region
--- @field bufnr number
--- @field start_line number 1-indexed
--- @field end_line number 1-indexed
--- @field lines string[] The actual text content

--- @class _99.Paint.Opts
--- @field enabled boolean Whether paint is enabled
--- @field hl_group string Highlight group for painted regions
--- @field sign_text string Sign text for painted lines
--- @field sign_hl_group string Highlight group for signs

local M = {}

local default_opts = {
  enabled = true,
  hl_group = "Visual",
  sign_text = "▎",
  sign_hl_group = "DiagnosticInfo",
}

--- @type _99.Paint.Opts
local current_opts = vim.deepcopy(default_opts)

--- @type _99.Paint.Region[]
local painted_regions = {}

local ns_id = vim.api.nvim_create_namespace("99.paint")

--- Add a visual selection to painted regions
--- @param range _99.Range
function M.add_region(range)
  if not current_opts.enabled then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(
    range.buffer,
    range.start.row - 1,
    range.end_.row,
    false
  )

  local region = {
    bufnr = range.buffer,
    start_line = range.start.row,
    end_line = range.end_.row,
    lines = lines,
  }

  table.insert(painted_regions, region)

  -- Add visual highlight
  for line_num = range.start.row - 1, range.end_.row - 1 do
    vim.api.nvim_buf_set_extmark(range.buffer, ns_id, line_num, 0, {
      end_line = line_num + 1,
      hl_group = current_opts.hl_group,
      hl_eol = true,
      priority = 100,
    })

    -- Add sign
    vim.api.nvim_buf_set_extmark(range.buffer, ns_id, line_num, 0, {
      sign_text = current_opts.sign_text,
      sign_hl_group = current_opts.sign_hl_group,
      priority = 100,
    })
  end
end

--- Get all painted regions for the current buffer
--- @param bufnr number
--- @return _99.Paint.Region[]
function M.get_regions(bufnr)
  local result = {}
  for _, region in ipairs(painted_regions) do
    if region.bufnr == bufnr then
      table.insert(result, region)
    end
  end
  return result
end

--- Get all painted regions from all buffers
--- @return _99.Paint.Region[]
function M.get_all_regions()
  return vim.deepcopy(painted_regions)
end

--- Get painted regions as formatted text for context
--- @param bufnr number
--- @return string
function M.get_context_text(bufnr)
  local regions = M.get_regions(bufnr)
  if #regions == 0 then
    return ""
  end

  local parts = {}
  table.insert(parts, "\n--- Additional Context (Painted Regions) ---\n")

  for i, region in ipairs(regions) do
    table.insert(parts, string.format("\n-- Region %d (lines %d-%d):\n", i, region.start_line, region.end_line))
    table.insert(parts, table.concat(region.lines, "\n"))
    table.insert(parts, "\n")
  end

  table.insert(parts, "--- End Additional Context ---\n")

  return table.concat(parts)
end

--- Clear all painted regions
--- @param bufnr? number Optional buffer number, clears all if not specified
function M.clear(bufnr)
  if bufnr then
    -- Clear for specific buffer
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    local new_regions = {}
    for _, region in ipairs(painted_regions) do
      if region.bufnr ~= bufnr then
        table.insert(new_regions, region)
      end
    end
    painted_regions = new_regions
  else
    -- Clear all
    for _, region in ipairs(painted_regions) do
      if vim.api.nvim_buf_is_valid(region.bufnr) then
        vim.api.nvim_buf_clear_namespace(region.bufnr, ns_id, 0, -1)
      end
    end
    painted_regions = {}
  end
end

--- Clear the last painted region
function M.clear_last()
  if #painted_regions == 0 then
    return
  end

  local region = table.remove(painted_regions)
  if vim.api.nvim_buf_is_valid(region.bufnr) then
    -- Clear extmarks for this region
    local marks = vim.api.nvim_buf_get_extmarks(
      region.bufnr,
      ns_id,
      { region.start_line - 1, 0 },
      { region.end_line - 1, -1 },
      {}
    )
    for _, mark in ipairs(marks) do
      vim.api.nvim_buf_del_extmark(region.bufnr, ns_id, mark[1])
    end
  end
end

--- Get count of painted regions
--- @return number
function M.count()
  return #painted_regions
end

--- Check if paint is enabled
--- @return boolean
function M.is_enabled()
  return current_opts.enabled
end

--- Configure paint options
--- @param opts _99.Paint.Opts?
function M.setup(opts)
  current_opts = vim.tbl_deep_extend("force", default_opts, opts or {})
end

return M
