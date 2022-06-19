return {
    game = {
        page = "World", -- "World", "Athmosphere", "Map", "Shop", "Equipment", "Skills"
        params = {
            name = "Old Town"
        }
    },
    pages = {
        ["Old Town"] = {
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
            auth = "XyKeQ5OJSYgSjmsJhL4fK3pbT4bSSl+TenkDlwgpSY8=",
            group = "master"
        },
        ["piotr"] = {
            name = "Piotrek",
            -- login: piotr
            -- password: stępczyński
            auth = "deQBx+//Zt17STnCjN/oKlQf93o6MRhCcOSZdSe/31w=",
            group = "player"
        }
    }
}
