--- @class _99.Location
--- @field full_path string
--- @field range _99.Range
--- @field buffer number
--- @field file_type string
--- @field marks table<string, _99.Mark>
local Location = {}
Location.__index = Location

function Location.from_range(range)
    local full_path = vim.api.nvim_buf_get_name(range.buffer)
    local file_type = vim.bo[range.buffer].ft

    return setmetatable({
        buffer = range.buffer,
        full_path = full_path,
        range = range,
        file_type = file_type,
        marks = {},
    }, Location)
end

function Location:clear_marks()
    for _, mark in pairs(self.marks) do
        mark:delete()
    end
end

return Location
