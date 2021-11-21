return {
    game = {
        screen = "World", -- "World", "Athmosphere", "Map", "Shop", "Equipment", "Skills"
        params = {
            name = "Old Town"
        }
    },
    worlds = {
        ["Old Town"] = {
            width = 175.61,
            image = "game/world/world.jpg",
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
            avatar = "game/token/bilbosz.png",
            position = {
                90,
                60
            }
        },
        ["Gaben"] = {
            name = "Gaben",
            diameter = 3,
            avatar = "game/token/gaben.png",
            position = {
                85,
                60
            }
        },
        ["Bilbosza"] = {
            name = "Bilbosza Wielka",
            diameter = 3,
            avatar = "game/token/bilbosza.png",
            position = {
                87.5,
                62.5
            }
        },
        ["Anonim"] = {
            name = "Anonim",
            diameter = 2,
            avatar = "game/token/default.png",
            position = {
                81.83,
                61.10
            }
        }
    },
    players = {
        ["adam"] = {
            name = "Adam",
            password = "hash(env[TREFLUN_LOVE_SALT] .. name .. createTime .. inappsalt .. (to co wysłał klient -> hash(inappsalt .. haslo_adam)))",
            createTime = "timestamp"
        },
        ["piotr"] = {
            login = "Piotrek",
            password = "env[TREFLUN_LOVE_SALT] .. name .. createTime .. inappsalt .. (to co wysłał klient -> hash(inappsalt .. haslo_piotr)))",
            createTime = "timestamp"
        }
    }
}
