local Logger = require("99.logger.logger")

local _id = 1
--- no, i am not going to use a uuid, in case of collision, call the police
--- @return string
local function get_id()
    local id = _id
    _id = _id + 1
    return tostring(id)
end

--- @param opts _99.Request.Opts
local function validate_opts(opts)
    assert(opts.model, "you must provide a model for hange requests to work")
    assert(opts.tmp_file, "you must provide context")
    assert(opts.provider, "you must provide a model provider")
end

--- @alias _99.Request.State "ready" | "calling-model" | "parsing-result" | "updating-file" | "cancelled"
--- @alias _99.Request.ResponseState "failed" | "success" | "cancelled"

--- @class _99.ProviderObserver
--- @field on_stdout fun(line: string): nil
--- @field on_stderr fun(line: string): nil
--- @field on_complete fun(status: _99.Request.ResponseState, res: string): nil

--- @class _99.Provider
--- @field make_request fun(self: _99.Provider, query: string, request: _99.Request, observer: _99.ProviderObserver)

local DevNullObserver = {
    name = "DevNullObserver",
    on_stdout = function() end,
    on_stderr = function() end,
    on_complete = function() end,
}

local OpenCodeProvider = {}

--- @param fn fun(...: any): nil
--- @return fun(...: any): nil
local function once(fn)
    local called = false
    return function(...)
        if called then
            return
        end
        called = true
        fn(...)
    end
end

--- @param query string
---@param request _99.Request
---@param observer _99.ProviderObserver?
function OpenCodeProvider:make_request(query, request, observer)
    observer = observer or DevNullObserver
    --- @param status _99.Request.ResponseState
    ---@param text string
    local once_complete = once(function(status, text)
        observer.on_complete(status, text)
    end)

    local id = get_id()
    Logger:debug("make_request", "tmp_file", request.config.tmp_file, "id", id)
    vim.system(
        { "opencode", "run", "-m", request.config.model, query },
        {
            text = true,
            stdout = vim.schedule_wrap(function(err, data)
                Logger:debug("STDOUT#data", "id", id, "data", data)
                if request:is_cancelled() then
                    once_complete("cancelled", "")
                    return
                end
                if err and err ~= "" then
                    Logger:debug("STDOUT#error", "id", id, "err", err)
                end
                if not err then
                    observer.on_stdout(data)
                end
            end),
            stderr = vim.schedule_wrap(function(err, data)
                Logger:debug("STDERR#data", "id", id, "data", data)
                if request:is_cancelled() then
                    once_complete("cancelled", "")
                    return
                end
                if err and err ~= "" then
                    Logger:debug("STDERR#error", "id", id, "err", err)
                end
                if not err then
                    observer.on_stderr(data)
                end
            end),
        },
        function(obj)
            if request:is_cancelled() then
                once_complete("cancelled", "")
                Logger:debug(
                    "on_complete: request has been cancelled",
                    "id",
                    id
                )
                return
            end
            if obj.code ~= 0 then
                local str = string.format(
                    "process exit code: %d\n%s",
                    obj.code,
                    vim.inspect(obj)
                )
                once_complete("failed", str)
                Logger:fatal(
                    "opencode make_query failed",
                    "id",
                    id,
                    "obj from results",
                    obj
                )
            end
            vim.schedule(function()
                local ok, res = OpenCodeProvider._retrieve_response(request)
                if ok then
                    once_complete("success", res)
                else
                    once_complete("failed", "unable to retrieve response from llm")
                end
            end)
        end
    )
end

--- @param request _99.Request
function OpenCodeProvider._retrieve_response(request)
    local tmp = request.config.tmp_file
    local success, result = pcall(function()
        return vim.fn.readfile(tmp)
    end)

    if not success then
        Logger:error(
            "retrieve_results: failed to read file",
            "tmp_name",
            tmp,
            "error",
            result
        )
        return false, ""
    end

    return true, table.concat(result, "\n")
end

--- @class _99.Request.Opts
--- @field model string
--- @field tmp_file string
--- @field provider _99.Provider?

--- @class _99.Request.Config
--- @field model string
--- @field tmp_file string
--- @field provider _99.Provider

--- @class _99.Request
--- @field config _99.Request.Config
--- @field state _99.Request.State
--- @field _content string[]
local Request = {}
Request.__index = Request

--- @param opts _99.Request.Opts
function Request.new(opts)
    opts.provider = opts.provider or OpenCodeProvider

    validate_opts(opts)

    local config = opts --[[ @as _99.Request.Config ]]

    return setmetatable({
        config = config,
        state = "ready",
        _content = {},
    }, Request)
end

function Request:cancel()
    self.state = "cancelled"
end

function Request:is_cancelled()
    return self.state == "cancelled"
end

--- @param content string
--- @return self
function Request:add_prompt_content(content)
    table.insert(self._content, content)
    return self
end

--- @param observer _99.ProviderObserver?
function Request:start(observer)
    local query = table.concat(self._content, "\n")
    observer = observer or DevNullObserver
    self.config.provider:make_request(query, self, observer)
end

return Request
