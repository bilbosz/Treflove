return {
    game = {
        page = "Meadow"
    },
    pages = {
        Meadow = {
            name = "Meadow",
            width = 20,
            pixel_per_meter = 4,
            image = "world/world.png",
            tokens = {
                "Bilbo",
                "Smaug"
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
        Bilbo = {
            name = "Bilbo Baggins",
            diameter = 3,
            avatar = "token/bilbo.png",
            owners = {
                "adam"
            },
            position = {
                6,
                7
            }
        },
        Smaug = {
            name = "Smaug",
            diameter = 4,
            avatar = "token/smaug.png",
            position = {
                14,
                8
            }
        }
    },
    players = {
        adam = {
            name = "Adam",
            auth = "48nI0XjJ11hysenR6bLDNrlo9Vk7gktIUfV1ZZ6wiNs=",
            group = "master"
        }
    },
    groups = {
        master = {
            title = "Game master",
            permissions = {
                "read",
                "write"
            }
        }
    }
}
