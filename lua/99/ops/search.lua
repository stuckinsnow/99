local Request = require("99.request")
local make_clean_up = require("99.ops.clean-up")
local Agents = require("99.extensions.agents")

--- @param response string
local function create_search_locations(response)
  local lines = vim.split(response, "\n")
  print(vim.inspect(lines))
end

--- @param context _99.RequestContext
---@param opts _99.ops.SearchOpts
local function search(context, opts)
  opts = opts or {}
  local user_prompt = opts.additional_prompt
  assert(user_prompt, "search requires a prompt to run, please provide prompt")

  local logger = context.logger:set_area("search")
  local request = Request.new(context)

  logger:debug("search", "with opts", opts.additional_prompt)

  -- TODO: How to surface progress..  I was thinking about a status line plugin
  -- local top_status = RequestStatus.new(
  --   250,
  --   context._99.ai_stdout_rows or 1,
  --   "Implementing",
  --   top_mark
  -- )
  local clean_up = make_clean_up(context, function()
    request:cancel()
  end)

  local full_prompt = context._99.prompts.prompts.semantic_search()
  full_prompt = context._99.prompts.prompts.prompt(user_prompt, full_prompt)
  local rules = Agents.find_rules(context._99.rules, user_prompt)
  context:add_agent_rules(rules)

  local additional_rules = opts.additional_rules
  if additional_rules then
    context:add_agent_rules(additional_rules)
  end

  request:add_prompt_content(full_prompt)
  request:start({
    on_complete = function(status, response)
      vim.schedule(clean_up)
      if status == "cancelled" then
        logger:debug("request cancelled for search")
      elseif status == "failed" then
        logger:error(
          "request failed for search",
          "error response",
          response or "no response provided"
        )
      elseif status == "success" then
        create_search_locations(response)
      end
    end,
    on_stdout = function(line)
      --- TODO: i need to figure out how to surface this information
      _ = line
    end,
    on_stderr = function(line)
      logger:debug("visual_selection#on_stderr received", "line", line)
    end,
  })
end
return search
