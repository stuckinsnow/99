-- luacheck: globals describe it assert before_each after_each
local Mark = require("99.ops.marks")
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

    describe("replace_text with marks", function()
        it("should replace multiline text and marks update to end of replacement", function()
            -- Create a range that spans multiple lines
            local start_point = Point:new(2, 3)
            local end_point = Point:new(3, 11)
            local range = Range:new(buffer, start_point, end_point)

            -- Create marks before replacement to track positions
            local mark_before_start = Mark.mark_point(buffer, Point:new(2, 1))
            local mark_start, mark_end = Mark.mark_range(range)

            -- Get the original text to verify the range
            local original_text = range:to_text()
            eq("local x = 1\n  return x", original_text)

            -- Replace the text with something shorter
            range:replace_text({ "local y = 2" })

            -- After replacement, both marks should be at the end of the replaced text
            -- This is the default extmark behavior
            local new_start = Point.from_mark(mark_start)
            local new_end = Point.from_mark(mark_end)
            
            -- Both marks should be pushed to the same position after replacement
            eq(new_start, new_end)

            -- Verify the buffer content changed
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

            -- Verify the mark before the range is still in place
            local before_point = Point.from_mark(mark_before_start)
            eq(Point:new(2, 1), before_point)

            mark_before_start:delete()
            mark_start:delete()
            mark_end:delete()
        end)

        it("should replace single line text and verify buffer changes", function()
            -- Create a range on a single line
            local start_point = Point:new(2, 3)
            local end_point = Point:new(2, 14)
            local range = Range:new(buffer, start_point, end_point)

            -- Get the original text
            local original_text = range:to_text()
            eq("local x = 1", original_text)

            -- Replace with longer text
            range:replace_text({ "local variable = 999" })

            -- Verify the buffer content
            local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
            eq({
                "function foo()",
                "  local variable = 999",
                "  return x",
                "end",
                "",
                "function bar()",
                "  return 42",
                "end",
            }, lines)
        end)

        it("should replace multiline text with single line", function()
            -- Create a range that spans multiple lines
            local start_point = Point:new(6, 1)
            local end_point = Point:new(8, 4)
            local range = Range:new(buffer, start_point, end_point)

            -- Replace with a single line
            range:replace_text({ "function bar() return 42 end" })

            -- Verify the buffer content - should have fewer lines now
            local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
            eq({
                "function foo()",
                "  local x = 1",
                "  return x",
                "end",
                "",
                "function bar() return 42 end",
            }, lines)
        end)

        it("should replace single line with multiline text", function()
            -- Create a range on a single line
            local start_point = Point:new(7, 3)
            local end_point = Point:new(7, 12)
            local range = Range:new(buffer, start_point, end_point)

            -- Get original text
            local original_text = range:to_text()
            eq("return 42", original_text)

            -- Replace with multiple lines
            range:replace_text({
                "local result = 42",
                "  return result"
            })

            -- Verify the buffer content
            local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
            eq({
                "function foo()",
                "  local x = 1",
                "  return x",
                "end",
                "",
                "function bar()",
                "  local result = 42",
                "  return result",
                "end",
            }, lines)
        end)

        it("should handle marks around replaced range", function()
            -- Test that marks outside the range are not affected
            local mark_line1 = Mark.mark_point(buffer, Point:new(1, 1))
            local mark_line5 = Mark.mark_point(buffer, Point:new(5, 1))
            
            -- Create a range on line 2-3
            local start_point = Point:new(2, 3)
            local end_point = Point:new(3, 11)
            local range = Range:new(buffer, start_point, end_point)

            -- Replace the text
            range:replace_text({ "local y = 2" })

            -- Marks outside the range should stay in their original positions
            local pos1 = Point.from_mark(mark_line1)
            local pos5 = Point.from_mark(mark_line5)
            
            eq(Point:new(1, 1), pos1)
            -- Line 5 becomes line 4 because we removed a line
            eq(Point:new(4, 1), pos5)

            mark_line1:delete()
            mark_line5:delete()
        end)
    end)
end)
