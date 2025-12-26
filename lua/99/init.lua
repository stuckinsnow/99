local Logger = require("99.logger.logger")
local Level = require("99.logger.level")
local ops = require("99.ops")
local Languages = require("99.language")
local Window = require("99.window")
local get_id = require("99.id")
local RequestContext = require("99.request-context")

--- @alias _99.Cleanup fun(): nil

--- @class _99.StateProps
--- @field model string
--- @field md_files string[]
--- @field prompts _99.Prompts
--- @field ai_stdout_rows number
--- @field languages string[]
--- @field display_errors boolean
--- @field provider_override _99.Provider?
--- @field __active_requests _99.Cleanup[]

--- @return _99.StateProps
local function create_99_state()
    return {
        model = "anthropic/claude-sonnet-4-5",
        md_files = {},
        prompts = require("99.prompt_settings"),
        ai_stdout_rows = 3,
        languages = { "lua" },
        display_errors = false,
        __active_requests = {},
    }
end

--- @class _99.Options
--- @field logger _99.Logger.Options?
--- @field model string?
--- @field md_files string[]?
--- @field provider _99.Provider?
--- @field debug_log_prefix string?
--- @field display_errors? boolean

--- unanswered question -- will i need to queue messages one at a time or
--- just send them all...  So to prepare ill be sending around this state object
--- @class _99.State
--- @field model string
--- @field md_files string[]
--- @field prompts _99.Prompts
--- @field ai_stdout_rows number
--- @field languages string[]
--- @field display_errors boolean
--- @field provider_override _99.Provider?
--- @field __active_requests _99.Cleanup[]
local _99_State = {}
_99_State.__index = _99_State

--- @return _99.State
function _99_State.new()
    local props = create_99_state()
    return setmetatable(props, _99_State) -- TODO: How do i do this right?
end

local _active_request_id = 0
---@param clean_up _99.Cleanup
---@return number
function _99_State:add_active_request(clean_up)
    _active_request_id = _active_request_id + 1
    Logger:debug("adding active request", "id", _active_request_id)
    self.__active_requests[_active_request_id] = clean_up
    return _active_request_id
end

function _99_State:active_request_count()
    local count = 0
    for _ in pairs(self.__active_requests) do
        count = count + 1
    end
    return count
end

---@param id number
function _99_State:remove_active_request(id)
    local r = self.__active_requests[id]
    assert(r, "there is no active request for id.  implementation broken")
    Logger:debug("removing active request", "id", id)
    self.__active_requests[id] = nil
end

local _99_state = _99_State.new()

--- @class _99
local _99 = {
    DEBUG = Level.DEBUG,
    INFO = Level.INFO,
    WARN = Level.WARN,
    ERROR = Level.ERROR,
    FATAL = Level.FATAL,
}

--- @param operation_name string
--- @return _99.RequestContext
local function get_context(operation_name)
    local trace_id = get_id()
    local context = RequestContext.from_current_buffer(_99_state, trace_id)
    context.logger:debug("99 Request", "method", operation_name, "id", trace_id)
    return context
end

function _99.implement_fn()
    ops.implement_fn(get_context("implement_fn"))
end

function _99.fill_in_function()
    ops.fill_in_function(get_context("fill_in_function"))
end

function _99.visual()
    local context = get_context("visual")
    ops.visual(context)
end

--- View all the logs that are currently cached.  Cached log count is determined
--- by _99.Logger.Options that are passed in.
function _99.view_log()
    local logs = {}
    for _, log in ipairs(Logger.log_cache) do
        local lines = vim.split(log, "\n")
        for _, line in ipairs(lines) do
            table.insert(logs, line)
        end
    end
    Window.display_full_screen_message(logs)
end

function _99.__debug_ident()
    ops.debug_ident(_99_state)
end

function _99.stop_all_requests()
    for _, clean_up in pairs(_99_state.__active_requests) do
        clean_up()
    end
    _99_state.__active_requests = {}
end

--- if you touch this function you will be fired
--- @return _99.State
function _99.__get_state()
    return _99_state
end

--- @param opts _99.Options?
function _99.setup(opts)
    opts = opts or {}
    _99_state = _99_State.new()
    _99_state.provider_override = opts.provider

    Logger:configure(opts.logger)

    if opts.model then
        assert(type(opts.model) == "string", "opts.model is not a string")
        _99_state.model = opts.model
    end

    if opts.md_files then
        assert(type(opts.md_files) == "table", "opts.md_files is not a table")
        for _, md in ipairs(opts.md_files) do
            _99.add_md_file(md)
        end
    end

    _99_state.display_errors = opts.display_errors or false

    Languages.initialize(_99_state)
end

--- @param md string
--- @return _99
function _99.add_md_file(md)
    table.insert(_99_state.md_files, md)
    return _99
end

--- @param md string
--- @return _99
function _99.rm_md_file(md)
    for i, name in ipairs(_99_state.md_files) do
        if name == md then
            table.remove(_99_state.md_files, i)
            break
        end
    end
    return _99
end

--- @param model string
--- @return _99
function _99.set_model(model)
    _99_state.model = model
    return _99
end

function _99.__debug()
    Logger:configure({
        path = nil,
        level = Level.DEBUG,
    })
end

return _99
