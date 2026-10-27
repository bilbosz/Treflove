return {
    name = "",
    game = {
        page = "Table"
    },
    pages = {
        Table = {
            name = "Table",
            width = 20,
            pixel_per_meter = 51.2,
            image = "world/table.png",
            tokens = {
                "Hero"
            }
        }
    },
    token_properties = {
        name = {
            title = "Name",
            type = "string"
        },
        diameter = {
            title = "Diameter",
            type = "number"
        },
        avatar = {
            title = "Avatar",
            type = "image"
        },
        owners = {
            title = "Owners",
            type = "array"
        },
        position = {
            title = "Position",
            type = "array"
        }
    },
    tokens = {
        Hero = {
            name = "Hero",
            diameter = 1,
            avatar = "token/default.png",
            owners = {},
            position = {
                10,
                7.5
            }
        }
    },
    players = {},
    groups = {
        master = {
            title = "Game master",
            permissions = {
                "read",
                "write"
            }
        },
        player = {
            title = "Player",
            permissions = {
                "read",
                "write:tokens/@owned"
            }
        }
    }
}
