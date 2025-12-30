---@param buffer number
---@return string
local function get_file_contents(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    return table.concat(lines, "\n")
end

--- @class _99.Prompts.SpecificOperations
--- @field visual_selection fun(range: _99.Range): string
local prompts = {
    fill_in_function = "fill in the function.  dont change the function signature. do not edit anything outside of this function.  prioritize using internal functions for work that has already been done.  any NOTE's left in the function should be removed but instructions followed. Your response should be the full function, including function declaration, do not provide the body only",
    implement_function = "implement the function that the cursor is on.  DO NOT IMPLEMENT ANYTHING ELSE.  If you see errors ignore them.  If you see non canonical code, ignore it.  Only implement <FunctionText>. make sure you inspect the current file carefully and any imports that look related.  being thorough is better than being fast.  being correct is better than being speedy.",
    output_file = "never alter any file other than TEMP_FILE.",
    visual_selection = function(range)
        return string.format([[
You receive a selection in neovim that you need to replace with new code.
The selection's contents may contain notes, incorporate the notes every time if there are some.
consider the context of the selection and what you are suppose to be implementing
<SELECTION_LOCATION>
%s
</SELECTION_LOCATION>
<SELECTION_CONTENT>
%s
</SELECTION_CONTENT>
<FILE_CONTAINING_SELECTION>
%s
</FILE_CONTAINING_SELECTION>
]], range:to_string(), range:to_text(), get_file_contents(range.buffer))
    end,
    read_tmp = "never attempt to read TEMP_FILE.  It is purely for output.  Previous contents, which may not exist, can be written over without worry",
}

--- @class _99.Prompts
local prompt_settings = {
    prompts = prompts,

    --- @param tmp_file string
    --- @return string
    tmp_file_location = function(tmp_file)
        return string.format(
            "<MustObey>\n%s\n%s\n</MustObey>\n<TEMP_FILE>%s</TEMP_FILE>",
            prompts.output_file,
            prompts.read_tmp,
            tmp_file
        )
    end,

    ---@param context _99.RequestContext
    ---@return string
    get_file_location = function(context)
        context.logger:assert(context.range, "get_file_location requires range specified")
        return string.format(
            "<Location><File>%s</File><Function>%s</Function></Location>",
            context.full_path,
            context.range:to_string()
        )
    end,

    --- @param range _99.Range
    get_range_text = function(range)
        return string.format("<FunctionText>%s</FunctionText>", range:to_text())
    end,
}

return prompt_settings
