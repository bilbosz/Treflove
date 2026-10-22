local test = require("tests.lib.test")
local asset_usage = require("data.asset-usage")

---@return GameData
local function game_data()
    return {
        game = {
            page = "P"
        },
        groups = {},
        players = {},
        pages = {
            P = {
                name = "P",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {
                    "T"
                }
            },
            Q = {
                name = "Q",
                width = 10,
                pixel_per_meter = 50,
                image = "world/q.png",
                tokens = {}
            }
        },
        token_properties = {
            name = {
                title = "Name",
                type = "string"
            },
            avatar = {
                title = "Avatar",
                type = "image"
            },
            badge = {
                title = "Badge",
                type = "image"
            }
        },
        tokens = {
            T = {
                name = "T",
                diameter = 3,
                avatar = "token/t.png",
                badge = "token/star.png",
                position = {
                    1,
                    2
                }
            },
            U = {
                name = "token/t.png",
                diameter = 2,
                avatar = "token/u.png",
                position = {
                    3,
                    4
                }
            }
        }
    }
end

test.suite("asset_usage")

test.case("what refers to an asset: the pages by their image, the tokens by their image properties, in name order", function()
    local data = game_data()
    test.assert_deep_eq(asset_usage.find(data, "token/t.png"), {
        "token \"T\" (avatar)"
    }, "a string property that is not an image does not count")
    test.assert_deep_eq(asset_usage.find(data, "world/w.png"), {
        "page \"P\""
    })
    test.assert_deep_eq(asset_usage.find(data, "token/star.png"), {
        "token \"T\" (badge)"
    })
    test.assert_deep_eq(asset_usage.find(data, "token/x.png"), {})
end)

test.case("a folder is referred to by everything under it", function()
    local data = game_data()
    test.assert_deep_eq(asset_usage.find(data, "token"), {
        "token \"T\" (avatar)",
        "token \"T\" (badge)",
        "token \"U\" (avatar)"
    })
    test.assert_deep_eq(asset_usage.find(data, "world"), {
        "page \"P\"",
        "page \"Q\""
    })
    test.assert_deep_eq(asset_usage.find(data, "tok"), {}, "a name prefix is not a folder")
end)

test.case("a renamed asset is followed by its references, a renamed folder by everything under it", function()
    local data = game_data()
    asset_usage.rename(data, "world/w.png", "maps/old-town.png")
    test.assert_eq(data.pages.P.image, "maps/old-town.png")
    test.assert_eq(data.pages.Q.image, "world/q.png")

    asset_usage.rename(data, "token", "people")
    test.assert_eq(data.tokens.T.avatar, "people/t.png")
    test.assert_eq(data.tokens.T.badge, "people/star.png")
    test.assert_eq(data.tokens.U.avatar, "people/u.png")
    test.assert_eq(data.tokens.U.name, "token/t.png", "a string property keeps its text")
end)
