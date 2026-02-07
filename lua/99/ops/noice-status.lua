--- Noice.nvim status notifications for AI processing
--- Shows status updates in noice notifications (bottom right corner)
--- Based on code from https://github.com/olimorris/codecompanion.nvim/discussions/813

--- @class _99.NoiceStatus.Opts
--- @field enabled boolean Whether noice status is enabled
--- @field client_name string Name shown as the client in progress

--- @class _99.NoiceStatus.Active
--- @field message table Noice message object
--- @field id number Request ID
--- @field stopped boolean Whether updates have stopped

local M = {}

local default_opts = {
  enabled = false,
  client_name = "99 AI",
}

--- @type _99.NoiceStatus.Opts
local current_opts = vim.deepcopy(default_opts)

--- @type table<number, _99.NoiceStatus.Active>
local active_status = {}

local throttle_time = 200

--- Check if noice is available
--- @return boolean
local function has_noice()
  local ok = pcall(require, "noice.message")
  return ok
end

--- Create a progress message
--- @param id number Request ID
--- @return table|nil Noice message object
local function create_progress_message(id)
  if not has_noice() then
    return nil
  end
  
  local Message = require("noice.message")
  local msg = Message("lsp", "progress")
  
  msg.opts.progress = {
    client_id = "99_ai_" .. id,
    client = current_opts.client_name,
    id = id,
    message = "Starting...",
  }
  
  return msg
end

--- Update progress message display
--- @param status _99.NoiceStatus.Active
local function update_display(status)
  if not has_noice() or status.stopped then
    return
  end
  
  local Format = require("noice.text.format")
  local Manager = require("noice.message.manager")
  
  Manager.add(Format.format(status.message, "lsp_progress"))
  
  vim.defer_fn(function()
    update_display(status)
  end, throttle_time)
end

--- Finish and remove status message
--- @param status _99.NoiceStatus.Active
--- @param final_message string Final status message
local function finish_status(status, final_message)
  if not has_noice() then
    return
  end
  
  status.stopped = true
  status.message.opts.progress.message = final_message
  
  local Format = require("noice.text.format")
  local Manager = require("noice.message.manager")
  local Router = require("noice.message.router")
  
  Manager.add(Format.format(status.message, "lsp_progress"))
  Router.update()
  
  vim.defer_fn(function()
    Manager.remove(status.message)
  end, 2000)
end

--- Create a new status notification
--- @param id string|number Request identifier
--- @return number id Namespace ID (just returns the id for API consistency)
function M.create(id)
  if not current_opts.enabled or not has_noice() then
    return -1
  end
  
  local numeric_id = tonumber(id) or vim.uv.hrtime()
  local message = create_progress_message(numeric_id)
  
  if not message then
    return -1
  end
  
  local status = {
    message = message,
    id = numeric_id,
    stopped = false,
  }
  
  active_status[numeric_id] = status
  update_display(status)
  
  return numeric_id
end

--- Update status text in the notification
--- @param id number
--- @param line string
function M.update_status(id, line)
  if id < 0 then
    return
  end
  
  if not has_noice() then
    return
  end
  
  local status = active_status[id]
  if not status or status.stopped then
    return
  end
  
  -- Strip ANSI codes
  local clean_line = line:gsub("\27%[[%d;]*m", "")
  status.message.opts.progress.message = clean_line
end

--- Clear a status notification
--- @param id number
function M.clear(id)
  if id < 0 then
    return
  end
  
  local status = active_status[id]
  if not status then
    return
  end
  
  finish_status(status, "Completed")
  active_status[id] = nil
end

--- Clear all active status notifications
function M.clear_all()
  for id, _ in pairs(active_status) do
    M.clear(id)
  end
  active_status = {}
end

--- Check if noice status is enabled
--- @return boolean
function M.is_enabled()
  return current_opts.enabled and has_noice()
end

--- Configure noice status options
--- @param opts _99.NoiceStatus.Opts?
function M.setup(opts)
  current_opts = vim.tbl_deep_extend("force", default_opts, opts or {})
end

--- Get current options
--- @return _99.NoiceStatus.Opts
function M.get_opts()
  return vim.deepcopy(current_opts)
end

return M
