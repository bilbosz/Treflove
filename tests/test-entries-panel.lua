local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")
local Consts = require("app.consts")
local entries = require("game.entry.entries")
local lifetime = require("lifetime")
local media = require("utils.media")
local GroupsPanel = require("game.panels.groups-panel")
local PagesPanel = require("game.panels.pages-panel")
local PermissionsPanel = require("game.panels.permissions-panel")
local TokenPropertiesPanel = require("game.panels.token-properties-panel")
local AssetListRow = require("game.assets.workspace.asset-list-row")

---@alias TestEntriesPanelMake fun(game_screen: GameScreen, width: number, height: number): EntriesPanel

---@type table<EntryKind, TestEntriesPanelMake>
local PANELS = {
    pages = function(game_screen, width, height)
        return PagesPanel(game_screen, width, height)
    end,
    groups = function(game_screen, width, height)
        return GroupsPanel(game_screen, width, height)
    end,
    players = function(game_screen, width, height)
        return PermissionsPanel(game_screen, width, height)
    end,
    token_properties = function(game_screen, width, height)
        return TokenPropertiesPanel(game_screen, width, height)
    end
}

---@class TestEntriesCreation
---@field id string
---@field texts table<string, string> What is typed in the fields
---@field entry table<string, EntryValue> What is sent

---@class TestEntriesKindCase
---@field kind EntryKind
---@field ids string[] The list, sorted
---@field selected string The entry the case selects
---@field texts table<string, string> The selected entry's fields
---@field change {key: string, text: string, value: EntryValue} A change the checks accept
---@field refused {key: string, text: string} A change the checks refuse
---@field rename string|nil A free id, for a kind that renames
---@field taken string|nil An id the kind holds already, other than the selected one
---@field creation TestEntriesCreation|nil For a kind that creates
---@field undeletable string|nil An id `entries.check_delete` refuses, for a kind that deletes

---@type TestEntriesKindCase[]
local KINDS = {
    {
        kind = "pages",
        ids = {
            "P",
            "Q"
        },
        selected = "Q",
        texts = {
            name = "Q",
            width = "10",
            pixel_per_meter = "50",
            image = "world/q.png"
        },
        change = {
            key = "width",
            text = "12",
            value = 12
        },
        refused = {
            key = "width",
            text = "0"
        },
        rename = "Cellar",
        taken = "P",
        creation = {
            id = "Cellar",
            texts = {
                name = "Cellar",
                width = "10",
                pixel_per_meter = "4",
                image = "world/w.png"
            },
            entry = {
                name = "Cellar",
                width = 10,
                pixel_per_meter = 4,
                image = "world/w.png"
            }
        },
        undeletable = "P"
    },
    {
        kind = "groups",
        ids = {
            "guest",
            "master",
            "player"
        },
        selected = "guest",
        texts = {
            title = "Guest",
            permissions = ""
        },
        change = {
            key = "title",
            text = "Guests",
            value = "Guests"
        },
        refused = {
            key = "permissions",
            text = "read fly"
        },
        rename = "visitors",
        taken = "master",
        creation = {
            id = "scouts",
            texts = {
                title = "Scouts",
                permissions = "read  write:assets"
            },
            entry = {
                title = "Scouts",
                permissions = {
                    "read",
                    "write:assets"
                }
            }
        },
        undeletable = "player"
    },
    {
        kind = "players",
        ids = {
            "adam",
            "piotr"
        },
        selected = "piotr",
        texts = {
            group = "player",
            permissions = "view:tokens/Smaug"
        },
        change = {
            key = "group",
            text = "master",
            value = "master"
        },
        refused = {
            key = "group",
            text = "nobody"
        }
    },
    {
        kind = "token_properties",
        ids = {
            "avatar",
            "diameter",
            "hp",
            "name",
            "owners",
            "position"
        },
        selected = "hp",
        texts = {
            title = "HP",
            type = "number"
        },
        change = {
            key = "type",
            text = "string",
            value = "string"
        },
        refused = {
            key = "type",
            text = "colour"
        },
        rename = "health",
        taken = "name",
        creation = {
            id = "mood",
            texts = {
                title = "Mood",
                type = "string"
            },
            entry = {
                title = "Mood",
                type = "string"
            }
        },
        undeletable = "name"
    }
}

local GAME_MASTER = {
    "read",
    "write"
}

local READER = {
    "read"
}

---@param kind EntryKind
---@param grants string[]
---@param fn fun(client: GameClient, panel: EntriesPanel, sent: GameClientEntrySend[])
local function with_panel(kind, grants, fn)
    local client = game_client.enter(grants, game_client.entries_game_data())
    ---@type boolean, any
    local ok, err = pcall(function()
        client.game_screen:get_token_panel():set_enabled(false)
        local x, w, h = game_client.side_panel_place(client)
        local panel = PANELS[kind](client.game_screen, w, h)
        panel:set_position(x, 0)
        local sent = game_client.record_entry_sends(client)
        game_client.take_notifications(client)
        fn(client, panel, sent)
    end)
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end

---@param panel EntriesPanel
---@return string[]
local function captions(panel)
    ---@type string[]
    local result = {}
    for _, button in ipairs(panel:get_list_buttons()) do
        table.insert(result, button:get_text())
    end
    return result
end

---@param panel EntriesPanel
---@return string[]
local function active_captions(panel)
    ---@type string[]
    local result = {}
    for _, button in ipairs(panel:get_list_buttons()) do
        if button:is_active() then
            table.insert(result, button:get_text())
        end
    end
    return result
end

---@param panel EntriesPanel
---@param id string
---@return TextButton
local function list_button(panel, id)
    for _, button in ipairs(panel:get_list_buttons()) do
        if button:get_text() == id then
            return button
        end
    end
    error("no list button " .. id)
end

---@param client GameClient
---@param panel EntriesPanel
---@param id string
local function click_entry(client, panel, id)
    game_client.click(client, list_button(panel, id))
end

---@param panel EntriesPanel
---@param key string
---@return TextInput|NumberInput
local function field(panel, key)
    return assert(panel:get_field_input(key), "no field " .. key)
end

---@param panel EntriesPanel
---@return table<string, string> By key, every field's text
local function texts(panel)
    ---@type table<string, string>
    local result = {}
    for _, def in ipairs(entries.FIELDS[panel:get_kind()]) do
        result[def.key] = field(panel, def.key):get_text()
    end
    return result
end

---@param panel EntriesPanel
---@param values table<string, string>
local function type_texts(panel, values)
    for key, text in pairs(values) do
        field(panel, key):set_text(text)
    end
end

---@param panel EntriesPanel
---@param read_only boolean
---@param message string
local function assert_fields_read_only(panel, read_only, message)
    for _, def in ipairs(entries.FIELDS[panel:get_kind()]) do
        local expected = read_only or def.type == "image"
        test.assert_eq(field(panel, def.key):is_read_only(), expected, message .. ": " .. def.key)
    end
end

---@param fn fun(case: TestEntriesKindCase)
---@param filter (fun(case: TestEntriesKindCase): boolean)|nil
local function for_kinds(fn, filter)
    for _, case in ipairs(KINDS) do
        if not filter or filter(case) then
            ---@type boolean, any
            local ok, err = pcall(fn, case)
            if not ok then
                error(case.kind .. ": " .. tostring(err), 0)
            end
        end
    end
end

---@param case TestEntriesKindCase
---@return boolean
local function renames(case)
    return case.rename ~= nil
end

---@param case TestEntriesKindCase
---@return boolean
local function creates(case)
    return case.creation ~= nil
end

test.suite("EntriesPanel")

test.case("the list shows every id sorted, nothing selected; a click selects one, shows it active and fills the fields", function()
    for_kinds(function(case)
        with_panel(case.kind, GAME_MASTER, function(client, panel)
            test.assert_deep_eq(captions(panel), case.ids)
            test.assert_deep_eq(active_captions(panel), {})
            test.assert_eq(panel:get_selected(), nil)
            test.assert_eq(panel:get_id_input(), nil, "no fields without a selection")
            test.assert_eq(panel:get_apply_button(), nil)
            test.assert_true(panel:get_cancel_button() ~= nil)

            click_entry(client, panel, case.selected)
            test.assert_eq(panel:get_selected(), case.selected)
            test.assert_deep_eq(active_captions(panel), {
                case.selected
            })
            test.assert_eq(assert(panel:get_id_input()):get_text(), case.selected)
            test.assert_deep_eq(texts(panel), case.texts)
            assert_fields_read_only(panel, false, "editable for the game master")
            test.assert_true(panel:get_apply_button() ~= nil)
        end)
    end)
end)

test.case("the list sits in a scroll view at the top, the fields in one between it and the two rows of buttons", function()
    with_panel("pages", GAME_MASTER, function(client, panel)
        click_entry(client, panel, "Q")
        local w, h = panel:get_size()
        local p, s = Consts.PADDING, Consts.PANEL_FIELD_SCALE
        local list = list_button(panel, "P"):get_parent():get_parent() --[[@as ScrollView]]
        test.assert_eq(get_class_name_of(list), "ScrollView")
        local list_x, list_y, list_w, list_h = list:get_position_and_size()
        test.assert_deep_eq({
            list_x,
            list_y,
            list_w,
            list_h
        }, {
            p,
            p,
            w - 2 * p,
            h * Consts.ENTRIES_PANEL_LIST_SHARE
        })

        local cancel, apply = panel:get_cancel_button(), assert(panel:get_apply_button())
        local new, delete = assert(panel:get_new_button()), assert(panel:get_delete_button())
        local _, cancel_y = cancel:get_position()
        local _, apply_y = apply:get_position()
        local _, new_y = new:get_position()
        local _, delete_y = delete:get_position()
        local _, button_h = cancel:get_size()
        test.assert_eq(cancel_y, h - button_h * s - p, "Cancel and Apply at the bottom")
        test.assert_eq(apply_y, cancel_y)
        test.assert_eq(new_y, cancel_y - button_h * s - p * 0.5, "New and Delete above them")
        test.assert_eq(delete_y, new_y)
        test.assert_true(cancel:get_position() < apply:get_position(), "Cancel left, Apply right")
        test.assert_true(new:get_position() < delete:get_position(), "New left, Delete right")

        local id_input = assert(panel:get_id_input())
        local fields = id_input:get_parent():get_parent() --[[@as ScrollView]]
        test.assert_eq(get_class_name_of(fields), "ScrollView")
        local _, fields_y, fields_w, fields_h = fields:get_position_and_size()
        test.assert_eq(fields_y, list_y + list_h + p)
        test.assert_eq(fields_w, w)
        test.assert_eq(fields_y + fields_h, new_y - p, "the fields end a padding above the buttons")
        local browse = assert(panel:get_field_button("image"))
        local _, browse_y = browse:get_position()
        local _, browse_h = browse:get_size()
        local _, content_h = fields:get_content_size()
        test.assert_eq(content_h, browse_y + browse_h * s + p, "the content holds every field")
    end)
end)

test.case("a kind that neither creates nor deletes keeps its fields down to the Cancel and Apply row", function()
    with_panel("players", GAME_MASTER, function(client, panel)
        click_entry(client, panel, "piotr")
        test.assert_eq(panel:get_new_button(), nil)
        test.assert_eq(panel:get_delete_button(), nil)
        local fields = assert(panel:get_id_input()):get_parent():get_parent() --[[@as ScrollView]]
        local _, fields_y, _, fields_h = fields:get_position_and_size()
        local _, cancel_y = panel:get_cancel_button():get_position()
        test.assert_eq(fields_y + fields_h, cancel_y - Consts.PADDING)
    end)
end)

test.case("the list's buttons scrolled out of view are disabled, so Tab skips them", function()
    with_panel("groups", GAME_MASTER, function(client, panel)
        local data = assert(client.app.data)
        for i = 1, 40 do
            data.groups[string.format("g%02d", i)] = {
                title = "G",
                permissions = {}
            }
        end
        panel:on_entries_change("groups", "g40")
        local buttons = panel:get_list_buttons()
        test.assert_eq(#buttons, 43)
        test.assert_true(buttons[1]:is_enabled())
        test.assert_false(buttons[#buttons]:is_enabled(), "below the view")
        local list = buttons[1]:get_parent():get_parent() --[[@as ScrollView]]
        local _, max_y = list:get_max_scroll()
        list:set_scroll(0, max_y)
        panel:on_update(0)
        test.assert_false(buttons[1]:is_enabled(), "above the view")
        test.assert_true(buttons[#buttons]:is_enabled())
    end)
end)

test.case("Apply sends only the fields that differ from the data; nothing differing sends nothing", function()
    for_kinds(function(case)
        with_panel(case.kind, GAME_MASTER, function(client, panel, sent)
            click_entry(client, panel, case.selected)
            game_client.click(client, assert(panel:get_apply_button()))
            test.assert_deep_eq(sent, {}, "nothing changed")
            field(panel, case.change.key):set_text(case.change.text)
            game_client.click(client, assert(panel:get_apply_button()))
            test.assert_deep_eq(sent, {
                {
                    method = "update_entry",
                    kind = case.kind,
                    id = case.selected,
                    changes = {
                        [case.change.key] = case.change.value
                    }
                }
            })
            test.assert_deep_eq(game_client.take_notifications(client), {})
            test.assert_deep_eq(texts(panel)[case.change.key], case.change.text, "the field keeps the text")
            test.assert_deep_eq(entries.get(assert(client.app.data), case.kind, case.selected), entries.get(game_client.entries_game_data(), case.kind, case.selected), "nothing applied to the data")
        end)
    end)
end)

test.case("Enter in a field applies", function()
    with_panel("groups", GAME_MASTER, function(client, panel, sent)
        click_entry(client, panel, "guest")
        local title = field(panel, "title")
        title:set_text("Guests")
        title:on_enter()
        test.assert_deep_eq(sent, {
            {
                method = "update_entry",
                kind = "groups",
                id = "guest",
                changes = {
                    title = "Guests"
                }
            }
        })
    end)
end)

test.case("a new id in the Id field sends a rename, with the changes", function()
    for_kinds(function(case)
        with_panel(case.kind, GAME_MASTER, function(client, panel, sent)
            click_entry(client, panel, case.selected)
            local id_input = assert(panel:get_id_input())
            test.assert_false(id_input:is_read_only())
            id_input:set_text(assert(case.rename))
            game_client.click(client, assert(panel:get_apply_button()))
            field(panel, case.change.key):set_text(case.change.text)
            game_client.click(client, assert(panel:get_apply_button()))
            test.assert_deep_eq(sent, {
                {
                    method = "update_entry",
                    kind = case.kind,
                    id = case.selected,
                    changes = {},
                    new_id = case.rename
                },
                {
                    method = "update_entry",
                    kind = case.kind,
                    id = case.selected,
                    changes = {
                        [case.change.key] = case.change.value
                    },
                    new_id = case.rename
                }
            })
            test.assert_eq(panel:get_selected(), case.selected, "renamed once the server answers")
        end)
    end, renames)
end)

test.case("the players panel shows the login read-only, without New or Delete", function()
    with_panel("players", GAME_MASTER, function(client, panel)
        test.assert_eq(panel:get_new_button(), nil)
        click_entry(client, panel, "piotr")
        test.assert_true(assert(panel:get_id_input()):is_read_only())
        test.assert_eq(panel:get_delete_button(), nil)
        test.assert_true(panel:get_apply_button() ~= nil)
    end)
end)

test.case("New empties the fields and makes the Id field editable; Apply sends the creation", function()
    for_kinds(function(case)
        with_panel(case.kind, GAME_MASTER, function(client, panel, sent)
            local creation = assert(case.creation)
            click_entry(client, panel, case.selected)
            game_client.click(client, assert(panel:get_new_button()))
            test.assert_true(panel:is_new())
            test.assert_eq(panel:get_selected(), nil)
            test.assert_deep_eq(active_captions(panel), {})
            local id_input = assert(panel:get_id_input())
            test.assert_eq(id_input:get_text(), "")
            test.assert_false(id_input:is_read_only())
            for key, text in pairs(texts(panel)) do
                test.assert_eq(text, "", "empty: " .. key)
            end
            test.assert_eq(panel:get_delete_button(), nil, "nothing to delete")

            id_input:set_text(creation.id)
            type_texts(panel, creation.texts)
            game_client.click(client, assert(panel:get_apply_button()))
            test.assert_deep_eq(sent, {
                {
                    method = "create_entry",
                    kind = case.kind,
                    id = creation.id,
                    entry = creation.entry
                }
            })
            test.assert_deep_eq(game_client.take_notifications(client), {})
            test.assert_eq(entries.get(assert(client.app.data), case.kind, creation.id), nil, "nothing applied to the data")
        end)
    end, creates)
end)

test.case("Cancel refills the fields from the data; in the new-entry state it goes back to no selection", function()
    with_panel("pages", GAME_MASTER, function(client, panel, sent)
        click_entry(client, panel, "Q")
        field(panel, "name"):set_text("Cellar")
        assert(panel:get_id_input()):set_text("Cellar")
        game_client.click(client, panel:get_cancel_button())
        test.assert_eq(panel:get_selected(), "Q")
        test.assert_eq(field(panel, "name"):get_text(), "Q")
        test.assert_eq(assert(panel:get_id_input()):get_text(), "Q")

        game_client.click(client, assert(panel:get_new_button()))
        game_client.click(client, panel:get_cancel_button())
        test.assert_false(panel:is_new())
        test.assert_eq(panel:get_selected(), nil)
        test.assert_eq(panel:get_id_input(), nil)
        test.assert_deep_eq(sent, {})
    end)
end)

test.case("an answered creation selects the new entry", function()
    with_panel("groups", GAME_MASTER, function(client, panel)
        game_client.click(client, assert(panel:get_new_button()))
        assert(panel:get_id_input()):set_text("scouts")
        type_texts(panel, {
            title = "Scouts"
        })
        game_client.click(client, assert(panel:get_apply_button()))
        local data = assert(client.app.data)
        data.groups.scouts = {
            title = "Scouts",
            permissions = {}
        }
        panel:on_entries_change("groups", "scouts")
        test.assert_false(panel:is_new())
        test.assert_eq(panel:get_selected(), "scouts")
        test.assert_deep_eq(active_captions(panel), {
            "scouts"
        })
    end)
end)

test.case("Delete sends the deletion of the selected entry", function()
    for_kinds(function(case)
        with_panel(case.kind, GAME_MASTER, function(client, panel, sent)
            click_entry(client, panel, case.selected)
            game_client.click(client, assert(panel:get_delete_button()))
            test.assert_deep_eq(sent, {
                {
                    method = "delete_entry",
                    kind = case.kind,
                    id = case.selected
                }
            })
            test.assert_deep_eq(game_client.take_notifications(client), {})
            test.assert_eq(panel:get_selected(), case.selected, "deleted once the server answers")
        end)
    end, creates)
end)

test.case("a deletion the checks refuse is notified and nothing is sent", function()
    for_kinds(function(case)
        with_panel(case.kind, GAME_MASTER, function(client, panel, sent)
            click_entry(client, panel, assert(case.undeletable))
            game_client.click(client, assert(panel:get_delete_button()))
            test.assert_eq(#game_client.take_notifications(client), 1)
            test.assert_deep_eq(sent, {})
        end)
    end, creates)
end)

test.case("a change the checks refuse is notified and nothing is sent; the fields keep their text", function()
    for_kinds(function(case)
        with_panel(case.kind, GAME_MASTER, function(client, panel, sent)
            click_entry(client, panel, case.selected)
            field(panel, case.refused.key):set_text(case.refused.text)
            game_client.click(client, assert(panel:get_apply_button()))
            test.assert_eq(#game_client.take_notifications(client), 1)
            test.assert_deep_eq(sent, {})
            test.assert_eq(field(panel, case.refused.key):get_text(), case.refused.text)
        end)
    end)
end)

test.case("a rename to a taken id is notified and nothing is sent", function()
    for_kinds(function(case)
        with_panel(case.kind, GAME_MASTER, function(client, panel, sent)
            click_entry(client, panel, case.selected)
            assert(panel:get_id_input()):set_text(assert(case.taken))
            field(panel, case.change.key):set_text(case.change.text)
            game_client.click(client, assert(panel:get_apply_button()))
            test.assert_eq(#game_client.take_notifications(client), 1)
            test.assert_deep_eq(sent, {})
        end)
    end, renames)
end)

test.case("a creation the checks refuse, a taken id or an empty field, is notified and nothing is sent", function()
    for_kinds(function(case)
        with_panel(case.kind, GAME_MASTER, function(client, panel, sent)
            local creation = assert(case.creation)
            game_client.click(client, assert(panel:get_new_button()))
            assert(panel:get_id_input()):set_text(assert(case.taken))
            type_texts(panel, creation.texts)
            game_client.click(client, assert(panel:get_apply_button()))
            test.assert_eq(#game_client.take_notifications(client), 1, "a taken id")

            assert(panel:get_id_input()):set_text(creation.id)
            field(panel, entries.FIELDS[case.kind][1].key):set_text("")
            game_client.click(client, assert(panel:get_apply_button()))
            test.assert_eq(#game_client.take_notifications(client), 1, "an empty field")
            test.assert_deep_eq(sent, {})
            test.assert_true(panel:is_new(), "still the new entry")
        end)
    end, creates)
end)

test.case("a number field without a number refuses the whole apply with a notification", function()
    with_panel("pages", GAME_MASTER, function(client, panel, sent)
        click_entry(client, panel, "Q")
        field(panel, "width"):set_text("")
        field(panel, "name"):set_text("Cellar")
        game_client.click(client, assert(panel:get_apply_button()))
        test.assert_eq(#game_client.take_notifications(client), 1)
        test.assert_deep_eq(sent, {})
        test.assert_eq(field(panel, "width"):get_text(), "")
        test.assert_eq(field(panel, "name"):get_text(), "Cellar")

        game_client.click(client, assert(panel:get_new_button()))
        assert(panel:get_id_input()):set_text("Cellar")
        type_texts(panel, {
            name = "Cellar",
            width = "10",
            image = "world/w.png"
        })
        game_client.click(client, assert(panel:get_apply_button()))
        test.assert_eq(#game_client.take_notifications(client), 1, "pixel_per_meter left empty")
        test.assert_deep_eq(sent, {})
    end)
end)

test.case("without write the fields are read-only, with Cancel and no Apply, New or Delete", function()
    for_kinds(function(case)
        with_panel(case.kind, READER, function(client, panel, sent)
            test.assert_eq(panel:get_new_button(), nil)
            click_entry(client, panel, case.selected)
            test.assert_deep_eq(texts(panel), case.texts, "shown all the same")
            assert_fields_read_only(panel, true, "read-only")
            test.assert_true(assert(panel:get_id_input()):is_read_only())
            test.assert_eq(panel:get_apply_button(), nil)
            test.assert_eq(panel:get_delete_button(), nil)
            test.assert_true(panel:get_cancel_button() ~= nil)
            field(panel, case.change.key):on_enter()
            panel:apply()
            panel:delete()
            panel:start_new()
            test.assert_false(panel:is_new())
            test.assert_deep_eq(sent, {})
        end)
    end)
end)

test.case("write on one entry makes that one editable and deletable, the others read-only, and no New", function()
    with_panel("pages", {
        "read",
        "write:pages/Q"
    }, function(client, panel)
        test.assert_eq(panel:get_new_button(), nil, "no write on the whole kind")
        click_entry(client, panel, "Q")
        assert_fields_read_only(panel, false, "Q")
        test.assert_false(assert(panel:get_id_input()):is_read_only())
        test.assert_true(panel:get_apply_button() ~= nil)
        test.assert_true(panel:get_delete_button() ~= nil)
        click_entry(client, panel, "P")
        assert_fields_read_only(panel, true, "P")
        test.assert_eq(panel:get_apply_button(), nil)
        test.assert_eq(panel:get_delete_button(), nil)
    end)
end)

test.case("a change of the grants re-gates the panel and keeps what the fields hold", function()
    with_panel("groups", GAME_MASTER, function(client, panel)
        click_entry(client, panel, "guest")
        field(panel, "title"):set_text("Guests")
        client.session:set_grants(READER)
        panel:on_grants_change()
        assert_fields_read_only(panel, true, "read-only")
        test.assert_eq(panel:get_apply_button(), nil)
        test.assert_eq(panel:get_new_button(), nil)
        test.assert_eq(field(panel, "title"):get_text(), "Guests")
        client.session:set_grants(GAME_MASTER)
        panel:on_grants_change()
        assert_fields_read_only(panel, false, "editable again")
        test.assert_true(panel:get_new_button() ~= nil)
    end)
end)

test.case("the new-entry state ends when the grants no longer allow a creation", function()
    with_panel("groups", GAME_MASTER, function(client, panel)
        game_client.click(client, assert(panel:get_new_button()))
        client.session:set_grants(READER)
        panel:on_grants_change()
        test.assert_false(panel:is_new())
        test.assert_eq(panel:get_id_input(), nil)
    end)
end)

test.case("a renamed selected entry stays selected under its new id, its fields refilled", function()
    with_panel("pages", GAME_MASTER, function(client, panel)
        click_entry(client, panel, "Q")
        field(panel, "name"):set_text("typed")
        local data = assert(client.app.data)
        data.pages.Cellar = data.pages.Q
        data.pages.Q = nil
        data.pages.Cellar.name = "Cellar"
        panel:on_entries_change("pages", "Cellar")
        test.assert_eq(panel:get_selected(), "Cellar")
        test.assert_deep_eq(captions(panel), {
            "Cellar",
            "P"
        })
        test.assert_deep_eq(active_captions(panel), {
            "Cellar"
        })
        test.assert_eq(assert(panel:get_id_input()):get_text(), "Cellar")
        test.assert_eq(field(panel, "name"):get_text(), "Cellar")
    end)
end)

test.case("a deleted selected entry leaves the panel with no selection", function()
    with_panel("token_properties", GAME_MASTER, function(client, panel)
        click_entry(client, panel, "hp")
        assert(client.app.data).token_properties.hp = nil
        panel:on_entries_change("token_properties", "hp")
        test.assert_eq(panel:get_selected(), nil)
        test.assert_eq(panel:get_id_input(), nil)
        test.assert_eq(panel:get_delete_button(), nil)
        test.assert_eq(panel:get_apply_button(), nil)
        test.assert_deep_eq(captions(panel), {
            "avatar",
            "diameter",
            "name",
            "owners",
            "position"
        })
    end)
end)

test.case("a change of the selected entry refills its fields; another entry's, or another kind's, keeps what they hold", function()
    with_panel("groups", GAME_MASTER, function(client, panel)
        click_entry(client, panel, "guest")
        field(panel, "title"):set_text("typed")
        local data = assert(client.app.data)
        data.groups.master.title = "Masters"
        panel:on_entries_change("groups", "master")
        panel:on_entries_change("pages", "guest")
        test.assert_eq(field(panel, "title"):get_text(), "typed")
        test.assert_eq(panel:get_selected(), "guest")

        data.groups.guest.title = "Visitors"
        panel:on_entries_change("groups", "guest")
        test.assert_eq(field(panel, "title"):get_text(), "Visitors")
    end)
end)

test.case("a created entry joins the list", function()
    with_panel("pages", GAME_MASTER, function(client, panel)
        assert(client.app.data).pages.Attic = {
            name = "Attic",
            width = 5,
            pixel_per_meter = 10,
            image = "world/w.png",
            tokens = {}
        }
        panel:on_entries_change("pages", "Attic")
        test.assert_deep_eq(captions(panel), {
            "Attic",
            "P",
            "Q"
        })
        test.assert_eq(panel:get_selected(), nil)
    end)
end)

test.case("a resize keeps the selection and what the fields hold", function()
    with_panel("pages", GAME_MASTER, function(client, panel)
        click_entry(client, panel, "Q")
        field(panel, "name"):set_text("typed")
        local w, h = panel:get_size()
        panel:on_resize(w * 0.5, h)
        test.assert_eq(panel:get_selected(), "Q")
        test.assert_eq(field(panel, "name"):get_text(), "typed")
        local _, _, input_w = field(panel, "name"):get_position_and_size()
        test.assert_eq(input_w, w * 0.5 - 2 * Consts.PADDING)
    end)
end)

test.case("the grants fields hold the grants separated by spaces and send them split on whitespace", function()
    with_panel("groups", GAME_MASTER, function(client, panel, sent)
        click_entry(client, panel, "player")
        local grants = field(panel, "permissions")
        test.assert_eq(grants:get_text(), "read write:tokens/@owned")
        grants:set_text("  read   write:tokens/@owned ")
        game_client.click(client, assert(panel:get_apply_button()))
        test.assert_deep_eq(sent, {}, "the same grants")
        grants:set_text("read\twrite:assets  write:tokens/@owned")
        game_client.click(client, assert(panel:get_apply_button()))
        test.assert_deep_eq(sent, {
            {
                method = "update_entry",
                kind = "groups",
                id = "player",
                changes = {
                    permissions = {
                        "read",
                        "write:assets",
                        "write:tokens/@owned"
                    }
                }
            }
        })
    end)
end)

test.case("a player without grants of their own shows an empty field; emptying one sends no grants", function()
    with_panel("players", GAME_MASTER, function(client, panel, sent)
        click_entry(client, panel, "adam")
        local grants = field(panel, "permissions")
        test.assert_eq(grants:get_text(), "")
        game_client.click(client, assert(panel:get_apply_button()))
        test.assert_deep_eq(sent, {}, "absent and empty are the same")

        click_entry(client, panel, "piotr")
        field(panel, "permissions"):set_text("")
        game_client.click(client, assert(panel:get_apply_button()))
        test.assert_deep_eq(sent, {
            {
                method = "update_entry",
                kind = "players",
                id = "piotr",
                changes = {
                    permissions = {}
                }
            }
        })
    end)
end)

---@param client GameClient
---@param panel EntriesPanel
---@return AssetsWorkspaceScreen
local function browse(client, panel)
    game_client.click(client, assert(panel:get_field_button("image")))
    local screen = client.app.screen_manager:get_screen() --[[@as AssetsWorkspaceScreen]]
    test.assert_eq(get_class_name_of(screen), "AssetsWorkspaceScreen")
    game_client.pop_request(client, "ListAssetsRp")
    game_client.answer(client, "ListAssetsRp", {
        success = true,
        entries = game_client.asset_entries(),
        writable = true
    })
    return screen
end

---@param screen AssetsWorkspaceScreen
---@param label string
---@return AssetEntry
local function workspace_entry(screen, label)
    for _, row in ipairs(screen:get_list():get_rows()) do
        if AssetListRow.get_label(row:get_entry()) == label then
            return row:get_entry()
        end
    end
    error("no row " .. label)
end

test.case("the image field's Browse... opens the assets workspace at the image; Use fills the field and returns to the game", function()
    with_panel("pages", GAME_MASTER, function(client, panel, sent)
        click_entry(client, panel, "P")
        local browse_button = assert(panel:get_field_button("image"))
        test.assert_eq(browse_button:get_text(), "Browse...")
        field(panel, "name"):set_text("typed")
        local screen = browse(client, panel)
        ---@diagnostic disable-next-line: invisible
        local pick = assert(screen._pick)
        test.assert_eq(pick.path, "world/w.png")
        test.assert_eq(pick.media_type, media.Type.IMAGE)
        test.assert_true(pick.on_pick ~= nil)
        test.assert_eq(assert(screen:get_selected()).path, "world/w.png")

        screen:go_up()
        screen:select_entry(workspace_entry(screen, "token/"))
        screen:open_selected()
        screen:select_entry(workspace_entry(screen, "s.png"))
        screen:run_action("use")
        test.assert_eq(client.app.screen_manager:get_screen(), client.game_screen)
        test.assert_false(lifetime.alive(screen))
        test.assert_eq(field(panel, "image"):get_text(), "token/s.png")
        test.assert_eq(field(panel, "name"):get_text(), "typed", "what was typed is kept")
        test.assert_deep_eq(sent, {}, "sent with the next Apply")
        game_client.click(client, assert(panel:get_apply_button()))
        test.assert_deep_eq(sent, {
            {
                method = "update_entry",
                kind = "pages",
                id = "P",
                changes = {
                    name = "typed",
                    image = "token/s.png"
                }
            }
        })
    end)
end)

test.case("a page the player may not write shows its image in the workspace, without Use", function()
    with_panel("pages", READER, function(client, panel)
        click_entry(client, panel, "P")
        local button = assert(panel:get_field_button("image"))
        test.assert_eq(button:get_text(), "Show in assets...")
        local screen = browse(client, panel)
        ---@diagnostic disable-next-line: invisible
        test.assert_eq(assert(screen._pick).on_pick, nil)
        test.assert_eq(screen:get_details():get_action_button("use"), nil)
        client.app.backstack_manager:back()
        test.assert_eq(client.app.screen_manager:get_screen(), client.game_screen)
    end)
end)

test.case("a destroyed panel takes its controls and stops following the list's scroll", function()
    with_panel("pages", GAME_MASTER, function(client, panel)
        click_entry(client, panel, "Q")
        local input, button = field(panel, "name"), list_button(panel, "Q")
        lifetime.destroy(panel)
        test.assert_false(lifetime.alive(input))
        test.assert_false(lifetime.alive(button))
        client.app.update_event:trigger(0.016)
    end)
end)
