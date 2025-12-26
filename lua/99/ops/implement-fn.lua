local Context = require("99.ops.context")
local Logger = require("99.logger.logger")
local Request = require("99.request")
local editor = require("99.editor")
local Location = require("99.editor.location")
local geo = require("99.geo")
local Range = geo.Range
local Point = geo.Point
local Mark = require("99.ops.marks")
local RequestStatus = require("99.ops.request_status")

--- @param response string
---@param location _99.Location
local function update_code(response, location)
    local buffer = location.buffer
    local code_mark = location.marks.code_placement
    local pos =
        vim.api.nvim_buf_get_extmark_by_id(buffer, code_mark.nsid, code_mark.id, {})
    local row = pos[1]
    local line = vim.api.nvim_buf_get_lines(buffer, row, row + 1, false)[1]
    local col = #line

    local lines = vim.split(response, "\n")
    if #line > 0 then
        table.insert(lines, 1, "")
    end
    vim.api.nvim_buf_set_text(buffer, row, col, row, col, lines)
end

--- @param _99 _99.State
local function implement_fn(_99)
    local ts = editor.treesitter
    local cursor = Point:from_cursor()
    local buffer = vim.api.nvim_get_current_buf()
    local fn_call = ts.fn_call(buffer, cursor)

    if not fn_call then
        Logger:fatal(
            "cannot implement function, cursor was not on an identifier that is a function call"
        )
        return
    end

    local range = Range:from_ts_node(fn_call, buffer)
    local location = Location.from_range(range)
    local context = Context.new(_99):finalize(_99, location)
    local request = Request.new({
        model = _99.model,
        tmp_file = context.tmp_file,
        provider = _99.provider_override,
    })

    location.marks.end_of_fn_call = Mark.mark_end_of_range(buffer, range)
    local func = ts.containing_function(buffer, cursor)
    if func then
        location.marks.code_placement = Mark.mark_above_func(buffer, func)
    else
        location.marks.code_placement = Mark.mark_above_range(range)
    end

    local code_placement = RequestStatus.new(
        250,
        _99.ai_stdout_rows,
        "Loading",
        location.marks.code_placement
    )
    local at_call_site = RequestStatus.new(
        250,
        1,
        "Implementing Function",
        location.marks.end_of_fn_call
    )

    code_placement:start()
    at_call_site:start()
    _99:add_active_request(function()
        location:clear_marks()
        request:cancel()
        code_placement:stop()
        at_call_site:stop()
    end)

    context:add_to_request(request)
    request:add_prompt_content(_99.prompts.prompts.implement_function)
    request:start({
        on_stdout = function(line)
            code_placement:push(line)
        end,
        on_complete = function(status, response)
            code_placement:stop()
            at_call_site:stop()
            if status ~= "success" then
                location:clear_marks()
                Logger:fatal(
                    "unable to implement function, enable and check logger for more details"
                )
            end
            pcall(update_code, response, location)
            location:clear_marks()
        end,
        on_stderr = function(line)
            --- TODO: If there is an error here, what should we do ?
            --- i dont think we should display it, hence the reason
            --- why i havent done anything yet.
        end,
    })

    return request
end

return implement_fn
