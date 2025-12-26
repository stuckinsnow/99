local braille_chars =
    { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- @class _99.StatusLine
--- @field index number
--- @field title_line string
local StatusLine = {}
StatusLine.__index = StatusLine

--- @param title_line string
--- @return _99.StatusLine
function StatusLine.new(title_line)
    local self = setmetatable({}, StatusLine)
    self.index = 1
    self.title_line = title_line
    return self
end

function StatusLine:update()
    self.index = self.index + 1
end

--- @return string
function StatusLine:to_string()
    return braille_chars[self.index % #braille_chars + 1]
        .. " "
        .. self.title_line
end

--- @class _99.RequestStatus
--- @field update_time number the milliseconds per update to the virtual text
--- @field status_line _99.StatusLine
--- @field lines string[]
--- @field max_lines number
--- @field running boolean
--- @field mark _99.Mark?
local RequestStatus = {}
RequestStatus.__index = RequestStatus

--- @param update_time number
--- @param max_lines number
--- @param title_line string
--- @param mark _99.Mark?
--- @return _99.RequestStatus
function RequestStatus.new(update_time, max_lines, title_line, mark)
    local self = setmetatable({}, RequestStatus)
    self.update_time = update_time
    self.max_lines = max_lines
    self.status_line = StatusLine.new(title_line)
    self.lines = {}
    self.running = false
    self.mark = mark
    return self
end

--- @return string[]
function RequestStatus:get()
    local result = { self.status_line:to_string() }
    for _, line in ipairs(self.lines) do
        table.insert(result, line)
    end
    return result
end

--- @param line string
function RequestStatus:push(line)
    table.insert(self.lines, line)
    if #self.lines > self.max_lines - 1 then
        table.remove(self.lines, 1)
    end
end

function RequestStatus:start()
    local function update_spinner()
        if not self.running then
            return
        end

        self.status_line:update()
        if self.mark then
            self.mark:set_virtual_text(self:get())
        end
        vim.defer_fn(update_spinner, self.update_time)
    end

    self.running = true
    vim.defer_fn(update_spinner, self.update_time)
end

function RequestStatus:stop()
    self.running = false
end

return RequestStatus
