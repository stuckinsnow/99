-- luacheck: globals describe it assert
local eq = assert.are.same
local RequestStatus = require("99.ops.request_status")

describe("request_status", function()
    it("setting lines and status line", function()
        local status = RequestStatus.new(2000000, 3, "TITLE")
        eq({ "⠙ TITLE" }, status:get())

        status:push("foo")
        status:push("bar")

        eq({ "⠙ TITLE", "foo", "bar" }, status:get())

        status:push("baz")

        eq({ "⠙ TITLE", "bar", "baz" }, status:get())
    end)
end)
