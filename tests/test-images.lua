local test = require("tests.lib.test")
local images = require("graphics.images")

---@class TestImageLog
---@field made {source: string, settings: {mipmaps: boolean}}[] Every image made, in order
---@field calls string[] The filter calls, in order

---@return TestImageLog
local function install_graphics()
    local log = {
        made = {},
        calls = {}
    }
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love = love or {}
    ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
    love.graphics = {
        newImage = function(source, settings)
            table.insert(log.made, {
                source = source,
                settings = settings
            })
            return {
                getDimensions = function()
                    return 64, 64
                end,
                setFilter = function(_, min, mag)
                    table.insert(log.calls, "setFilter(" .. min .. ", " .. mag .. ")")
                end,
                setMipmapFilter = function(_, mode)
                    table.insert(log.calls, "setMipmapFilter(" .. mode .. ")")
                end
            }
        end
    }
    return log
end

test.suite("images")

test.case("an image is made with its mipmaps, filtered linearly within and between the levels", function()
    local log = install_graphics()
    images.new("a.png")
    test.assert_eq(#log.made, 1)
    test.assert_eq(log.made[1].source, "a.png")
    test.assert_deep_eq(log.made[1].settings, {
        mipmaps = true
    })
    test.assert_deep_eq(log.calls, {
        "setFilter(linear, linear)",
        "setMipmapFilter(linear)"
    })
end)

test.case("one image per path, made on first use, until forgotten", function()
    local log = install_graphics()
    images.clear()
    local a = images.get("a.png")
    test.assert_eq(images.get("a.png"), a, "cached")
    local b = images.get("b.png")
    test.assert_true(b ~= a, "another path")
    test.assert_eq(#log.made, 2)

    images.forget("a.png")
    test.assert_true(images.get("a.png") ~= a, "forgotten")
    test.assert_eq(images.get("b.png"), b, "the other path is kept")

    images.clear()
    test.assert_true(images.get("b.png") ~= b, "cleared")
end)
