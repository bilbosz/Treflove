return {
    game = {
        page = "Old Town"
    },
    pages = {
        ["Old Town"] = {
            name = "Old Town",
            width = 175.61,
            pixel_per_meter = 50,
            image = "world/world.jpg",
            tokens = {
                "Bilbosz",
                "Gaben",
                "Bilbosza",
                "Anonim"
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
        ["Bilbosz"] = {
            name = "Bilbosz",
            diameter = 3,
            avatar = "token/bilbosz.png",
            owners = {
                "adam"
            },
            position = {
                90,
                60
            }
        },
        ["Gaben"] = {
            name = "Gaben",
            diameter = 3,
            avatar = "token/gaben.png",
            owners = {
                "piotr"
            },
            position = {
                85,
                60
            }
        },
        ["Bilbosza"] = {
            name = "Bilbosza Wielka",
            diameter = 3,
            avatar = "token/bilbosza.png",
            owners = {
                "adam"
            },
            position = {
                87.5,
                62.5
            }
        },
        ["Anonim"] = {
            name = "Anonim",
            diameter = 2,
            avatar = "token/default.png",
            position = {
                81.83,
                61.10
            }
        }
    },
    players = {
        ["adam"] = {
            name = "Adam",
            -- login: adam
            -- password: krause
            auth = "48nI0XjJ11hysenR6bLDNrlo9Vk7gktIUfV1ZZ6wiNs=",
            group = "master"
        },
        ["piotr"] = {
            name = "Piotrek",
            -- login: piotr
            -- password: stępczyński
            auth = "h56e16kPixnS4sl1flNsuzCyaD+6KUhKPFFNKu8mS0o=",
            group = "player"
        }
    }
}
