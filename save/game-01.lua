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
            tokens = {"Bilbosz", "Gaben", "Bilbosza"}
        }
    },
    tokens = {
        ["Bilbosz"] = {
            name = "Bilbosz",
            radius = 3,
            avatar = "game/token/bilbosz.png",
            position = {90, 60}
        },
        ["Gaben"] = {
            name = "Gaben",
            radius = 3,
            avatar = "game/token/gaben.png",
            position = {85, 60}
        },
        ["Bilbosza"] = {
            name = "Bilbosza Wielka",
            radius = 3,
            avatar = "game/token/bilbosza.png",
            position = {87.5, 62.5}
        }
    }
}
