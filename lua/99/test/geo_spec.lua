-- luacheck: globals describe it assert before_each after_each
local geo = require("99.geo")
local Point = geo.Point
local Range = geo.Range
local test_utils = require("99.test.test_utils")
local eq = assert.are.same

describe("Range", function()
    local buffer

    before_each(function()
        buffer = test_utils.create_file({
            "function foo()",
            "  local x = 1",
            "  return x",
            "end",
            "",
            "function bar()",
            "  return 42",
            "end",
        }, "lua", 1, 0)
    end)

    after_each(function()
        test_utils.clean_files()
    end)

    it("replace text", function()
        local start_point = Point:new(2, 3)
        local end_point = Point:new(3, 11)
        local range = Range:new(buffer, start_point, end_point)
        local original_text = range:to_text()
        eq("local x = 1\n  return x", original_text)

        local replace_text = { "local y = 2" }
        range:replace_text(replace_text)
        local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
        eq({
            "function foo()",
            "  local y = 2",
            "end",
            "",
            "function bar()",
            "  return 42",
            "end",
        }, lines)
    end)

    it("replace text single line into multi-line", function()
        local start_point = Point:new(2, 3)
        local end_point = Point:new(3, 11)
        local range = Range:new(buffer, start_point, end_point)
        local original_text = range:to_text()
        eq("local x = 1\n  return x", original_text)

        local replace_text = {
            "local y = 2",
            "  local z = 3",
        }
        range:replace_text(replace_text)
        local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
        eq({
            "function foo()",
            "  local y = 2",
            "  local z = 3",
            "end",
            "",
            "function bar()",
            "  return 42",
            "end",
        }, lines)
    end)

    it("should create range from simple visual line selection", function()
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.api.nvim_feedkeys("V", "x", false)

        test_utils.next_frame()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>gv", true, false, true), "x", false)

        local range = Range.from_visual_selection()
        local text = range:to_text()
        eq("  local x = 1", text)
    end)
end)
