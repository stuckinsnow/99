-- luacheck: globals describe it assert
local _99 = require("99")
local test_utils = require("99.test.test_utils")
---@diagnostic disable-next-line: undefined-field
local eq = assert.are.same

describe("typescript", function()
  it("should test a typescript file", function()
    local ts_content = {
      "",
      "const foo = function() {}",
    }
    local p, buffer = test_utils.fif_setup(ts_content, 2, 16, "typescript")
    local state = _99.__get_state()

    _99.fill_in_function()

    eq(1, state:active_request_count())
    eq(ts_content, test_utils.r(buffer))

    p:resolve("success", "function() {\n    return 42;\n}")
    test_utils.next_frame()

    local expected_state = {
      "",
      "const foo = function() {",
      "    return 42;",
      "}",
    }
    eq(expected_state, test_utils.r(buffer))
    eq(0, state:active_request_count())
  end)
end)
