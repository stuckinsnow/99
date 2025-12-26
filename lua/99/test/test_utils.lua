local Logger = require("99.logger.logger")
local M = {}

local _id = 1
local function get_id()
    _id = _id + 1
    return _id
end

function M.next_frame()
    local next = false
    vim.schedule(function()
        next = true
    end)

    vim.wait(1000, function()
        return next
    end)
end

M.created_files = {}

--- @class _99.test.ProviderRequest
--- @field query string
--- @field request _99.Request
--- @field observer _99.ProviderObserver?

--- @class _99.test.Provider : _99.Provider
--- @field request _99.test.ProviderRequest?
local TestProvider = {}
TestProvider.__index = TestProvider

function TestProvider.new()
    return setmetatable({}, TestProvider)
end

--- @param query string
---@param request _99.Request
---@param observer _99.ProviderObserver?
function TestProvider:make_request(query, request, observer)
    local id = get_id()
    Logger:debug("make_request", "tmp_file", request.config.tmp_file, "id", id)
    self.request = {
        query = query,
        request = request,
        observer = observer,
        id = id,
    }
end

--- @param status _99.Request.ResponseState
--- @param result string
function TestProvider:resolve(status, result)
    assert(self.request, "you cannot call resolve until make_request is called")
    local obs = self.request.observer
    if obs then
        obs.on_complete(status, result)
    end
    self.request = nil
end

--- @param line string
function TestProvider:stdout(line)
    assert(self.request, "you cannot call stdout until make_request is called")
    local obs = self.request.observer
    if obs then
        obs.on_stdout(line)
    end
end

--- @param line string
function TestProvider:stderr(line)
    assert(self.request, "you cannot call stderr until make_request is called")
    local obs = self.request.observer
    if obs then
        obs.on_stderr(line)
    end
end

M.TestProvider = TestProvider

function M.clean_files()
    for _, bufnr in ipairs(M.created_files) do
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    M.created_files = {}
end

---@param contents string[]
---@param file_type string?
---@param row number?
---@param col number?
function M.create_file(contents, file_type, row, col)
    assert(type(contents) == "table", "contents must be a table of strings")
    file_type = file_type or "lua"
    local bufnr = vim.api.nvim_create_buf(false, false)

    vim.api.nvim_set_current_buf(bufnr)
    vim.bo[bufnr].ft = file_type
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_win_set_cursor(0, { row or 1, col or 0 })

    table.insert(M.created_files, bufnr)
    return bufnr
end

return M
