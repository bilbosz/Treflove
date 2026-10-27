local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local Accounts = require("data.accounts")
local Asset = require("data.asset")

---@param files table<string, string>
---@param fn fun(accounts: Accounts)
local function with_accounts(files, fn)
    mocks.install_app({
        is_client = false,
        is_server = true
    })
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    local previous = mocks.install_love_filesystem(files)
    ---@type boolean, any
    local ok, err = pcall(fn, Accounts(Asset("s/accounts.lua")))
    mocks.restore_love_filesystem(previous)
    if not ok then
        error(err, 0)
    end
end

test.suite("Accounts")

test.case("a login is refused when empty, too long, or with a character outside letters, digits and _ . -", function()
    test.assert_eq(Accounts.check_login("frodo"), nil)
    test.assert_eq(Accounts.check_login("Frodo_B.2-x"), nil)
    test.assert_eq(Accounts.check_login(string.rep("a", 32)), nil)
    test.assert_eq(Accounts.check_login(""), "A login cannot be empty")
    test.assert_eq(Accounts.check_login(string.rep("a", 33)), "A login can have at most 32 characters")
    for _, login in ipairs({
        "fro do",
        "@owned",
        "frodo/x",
        "fródo",
        "a:b"
    }) do
        test.assert_eq(Accounts.check_login(login), "A login can have only letters, digits and the characters _ . -", login)
    end
end)

test.case("a name is refused when empty after trimming or too long; a password when empty", function()
    test.assert_eq(Accounts.check_name("Frodo Baggins"), nil)
    test.assert_eq(Accounts.check_name("  Frodo  "), nil)
    test.assert_eq(Accounts.check_name(string.rep("n", 64)), nil)
    test.assert_eq(Accounts.check_name(""), "A name cannot be empty")
    test.assert_eq(Accounts.check_name(" \t "), "A name cannot be empty")
    test.assert_eq(Accounts.check_name(string.rep("n", 65)), "A name can have at most 64 characters")
    test.assert_eq(Accounts.check_password("ring"), nil)
    test.assert_eq(Accounts.check_password(" "), nil)
    test.assert_eq(Accounts.check_password(""), "A password cannot be empty")
end)

test.case("no file, no accounts; an account is found by the auth of its client, never by another's", function()
    with_accounts({}, function(accounts)
        test.assert_eq(accounts:get("adam"), nil)
        test.assert_eq(accounts:find_by_auth(mocks.client_auth("adam")), nil)
    end)
    with_accounts({
        ["s/accounts.lua"] = mocks.accounts_file({
            "adam",
            "piotr"
        })
    }, function(accounts)
        test.assert_deep_eq(accounts:get("adam"), {
            name = "adam",
            auth = mocks.server_auth("adam")
        })
        test.assert_eq(accounts:find_by_auth(mocks.client_auth("adam")), "adam")
        test.assert_eq(accounts:find_by_auth(mocks.client_auth("piotr")), "piotr")
        test.assert_eq(accounts:find_by_auth(mocks.client_auth("ewa")), nil)
        test.assert_eq(accounts:find_by_auth(mocks.server_auth("adam")), nil, "the stored hash is not a client's auth")
    end)
end)

test.case("an account is created with its name trimmed and its server hash, and saved; it is found by its client's auth after a reload", function()
    local files = {}
    with_accounts(files, function(accounts)
        test.assert_deep_eq({
            accounts:create("frodo", " Frodo ", mocks.client_auth("frodo"))
        }, {
            true
        })
        test.assert_deep_eq(accounts:get("frodo"), {
            name = "Frodo",
            auth = mocks.server_auth("frodo")
        })
        test.assert_eq(accounts:find_by_auth(mocks.client_auth("frodo")), "frodo")
        local reloaded = Accounts(Asset("s/accounts.lua"))
        test.assert_eq(reloaded:find_by_auth(mocks.client_auth("frodo")), "frodo")
        test.assert_eq(assert(reloaded:get("frodo")).name, "Frodo")
    end)
    test.assert_true(files["s/accounts.lua"] ~= nil, "the file was written")
end)

test.case("a fresh root has no accounts; the first account creates the root and the accounts file", function()
    local files = {}
    with_accounts(files, function(accounts)
        test.assert_eq(love.filesystem.getInfo("s"), nil, "nothing under the root")
        test.assert_eq(accounts:get("frodo"), nil)
        test.assert_true((accounts:create("frodo", "Frodo", mocks.client_auth("frodo"))))
        test.assert_eq(assert(love.filesystem.getInfo("s")).type, "directory")
        test.assert_eq(assert(love.filesystem.getInfo("s/accounts.lua")).type, "file")
        test.assert_deep_eq(love.filesystem.getDirectoryItems("s"), {
            "accounts.lua"
        })
        test.assert_eq(Accounts(Asset("s/accounts.lua")):find_by_auth(mocks.client_auth("frodo")), "frodo", "found by a server started again")
    end)
end)

test.case("an account is refused for a taken login, a bad login or name, or no auth; nothing is saved then", function()
    local files = {
        ["s/accounts.lua"] = "return {}"
    }
    with_accounts(files, function(accounts)
        test.assert_true((accounts:create("frodo", "Frodo", mocks.client_auth("frodo"))))
        local saved = files["s/accounts.lua"]
        test.assert_deep_eq({
            accounts:create("frodo", "Another", mocks.client_auth("other"))
        }, {
            false,
            "The login \"frodo\" is taken already"
        })
        test.assert_deep_eq({
            accounts:create("@sam", "Sam", mocks.client_auth("sam"))
        }, {
            false,
            "A login can have only letters, digits and the characters _ . -"
        })
        test.assert_deep_eq({
            accounts:create("sam", "  ", mocks.client_auth("sam"))
        }, {
            false,
            "A name cannot be empty"
        })
        test.assert_deep_eq({
            accounts:create("sam", "Sam", "")
        }, {
            false,
            "An account needs a password"
        })
        test.assert_eq(files["s/accounts.lua"], saved)
        test.assert_eq(accounts:get("sam"), nil)
        test.assert_eq(assert(accounts:get("frodo")).name, "Frodo")
    end)
end)
