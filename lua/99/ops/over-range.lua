local Request = require("99.request")
local RequestStatus = require("99.ops.request_status")
local Mark = require("99.ops.marks")
local InlineMarks = require("99.ops.inline-marks")
local DiagonalLines = require("99.ops.diagonal-lines")
local NoiceStatus = require("99.ops.noice-status")
local Diff = require("99.ops.diff")
local geo = require("99.geo")
local make_clean_up = require("99.ops.clean-up")
local Agents = require("99.extensions.agents")

local Range = geo.Range
local Point = geo.Point

--- @param context _99.RequestContext
--- @param range _99.Range
--- @param opts? _99.ops.Opts
local function over_range(context, range, opts)
  opts = opts or {}
  local logger = context.logger:set_area("visual")

  local request = Request.new(context)
  local top_mark = Mark.mark_above_range(range)
  local bottom_mark = Mark.mark_point(range.buffer, range.end_)
  context.marks.top_mark = top_mark
  context.marks.bottom_mark = bottom_mark

  logger:debug(
    "visual request start",
    "start",
    Point.from_mark(top_mark),
    "end",
    Point.from_mark(bottom_mark)
  )

  local display_ai_status = context._99.ai_stdout_rows > 1
  local top_status = RequestStatus.new(
    250,
    context._99.ai_stdout_rows or 1,
    "Implementing",
    top_mark
  )
  local bottom_status = RequestStatus.new(250, 1, "Implementing", bottom_mark)

  local inline_marks_ns = InlineMarks.create({
    bufnr = range.buffer,
    start_line = range.start.row,
    end_line = range.end_.row,
  }, context.xid)

  local diagonal_lines_ns = DiagonalLines.create({
    bufnr = range.buffer,
    start_line = range.start.row,
    end_line = range.end_.row,
  }, context.xid)

  local noice_status_ns = NoiceStatus.create(context.xid)

  local clean_up = make_clean_up(context, function()
    top_status:stop()
    bottom_status:stop()
    InlineMarks.clear(inline_marks_ns)
    DiagonalLines.clear(diagonal_lines_ns)
    NoiceStatus.clear(noice_status_ns)
    context:clear_marks()
    request:cancel()
  end)

  local full_prompt = context._99.prompts.prompts.visual_selection(range)
  local additional_prompt = opts.additional_prompt
  if additional_prompt then
    full_prompt =
      context._99.prompts.prompts.prompt(additional_prompt, full_prompt)

    local rules = Agents.find_rules(context._99.rules, additional_prompt)
    context:add_agent_rules(rules)
  end

  local additional_rules = opts.additional_rules
  if additional_rules then
    context:add_agent_rules(additional_rules)
  end

  request:add_prompt_content(full_prompt)

  -- Only start the old spinner if inline marks and diagonal lines are not enabled
  local use_old_spinner = not InlineMarks.is_enabled() and not DiagonalLines.is_enabled()
  if use_old_spinner then
    top_status:start()
    bottom_status:start()
  end
  request:start({
    on_complete = function(status, response)
      vim.schedule(clean_up)
      if status == "cancelled" then
        logger:debug("request cancelled for visual selection, removing marks")
      elseif status == "failed" then
        logger:error(
          "request failed for visual_selection",
          "error response",
          response or "no response provided"
        )
      elseif status == "success" then
        local valid = top_mark:is_valid() and bottom_mark:is_valid()
        if not valid then
          logger:fatal(
            -- luacheck: ignore 631
            "the original visual_selection has been destroyed.  You cannot delete the original visual selection during a request"
          )
          return
        end

        local new_range = Range.from_marks(top_mark, bottom_mark)
        local lines = vim.split(response, "\n")

        --- HACK: i am adding a new line here because above range will add a mark to the line above.
        --- that way this appears to be added to "the same line" as the visual selection was
        --- originally take from
        table.insert(lines, 1, "")

        -- If diff is enabled, store as pending change for review
        if Diff.is_enabled() then
          local s_row, _ = new_range.start:to_vim()
          local e_row, _ = new_range.end_:to_vim()
          local stored = Diff.store_pending(range.buffer, s_row, e_row + 1, lines)
          if stored then
            logger:debug("stored pending change for diff review")
            return
          end
        end

        new_range:replace_text(lines)
      end
    end,
    on_stdout = function(line)
      -- Only update old spinner if it's being used
      if use_old_spinner and display_ai_status then
        top_status:push(line)
      end
      -- Also update inline marks if enabled
      if InlineMarks.is_enabled() then
        InlineMarks.update_status(inline_marks_ns, line)
      end
      -- Also update diagonal lines if enabled
      if DiagonalLines.is_enabled() then
        DiagonalLines.update_status(diagonal_lines_ns, line)
      end
      -- Also update noice status if enabled
      if NoiceStatus.is_enabled() then
        NoiceStatus.update_status(noice_status_ns, line)
      end
    end,
    on_stderr = function(line)
      logger:debug("visual_selection#on_stderr received", "line", line)
    end,
  })
end

return over_range
