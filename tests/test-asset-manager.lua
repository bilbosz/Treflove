local test = require("tests.lib.test")
local mocks = require("tests.lib.mocks")
local AssetManager = require("data.asset-manager")
local Connection = require("networking.connection")
local lifetime = require("lifetime")

-- `log` records the session's release and every handler a dying procedure
-- unregisters, with the number of entries the manager still holds for the
-- session at that moment.
local log = {}
local manager, session

---@param s table
---@return integer
local function count_entries(s)
    local n = 0
    for _, rps in ipairs({manager._upload_asset_rp, manager._download_asset_rp, manager._download_missing_assets_rp}) do
        if rps[s] ~= nil then
            n = n + 1
        end
    end
    return n
end

local TestLoggingConnection = class("TestAssetLoggingConnection", Connection)

---@param id string
function TestLoggingConnection:unregister_request_handler(id)
    table.insert(log, "  unregister " .. id .. ", entries " .. count_entries(session))
    Connection.unregister_request_handler(self, id)
end

-- What AssetManager needs of a session.
local TestSession = class("TestSession")

function TestSession:init(connection)
    self._connection = connection
end

function TestSession:get_connection()
    return self._connection
end

function TestSession:release(reason)
    table.insert(log, "TestSession:release(" .. tostring(reason) .. "), entries " .. count_entries(self))
end

test.suite("AssetManager")

test.case("a session's procedures die with it, newest first, after its entries are gone", function()
    mocks.install_app()
    mocks.ensure_love_data()
    local connection = TestLoggingConnection(mocks.make_channel(), mocks.make_thread(), mocks.make_channel(), mocks.make_thread())
    manager = AssetManager()
    session = TestSession(connection)
    manager:register_session(session)
    local procedures = {manager._upload_asset_rp[session], manager._download_asset_rp[session], manager._download_missing_assets_rp[session]}
    log = {}

    lifetime.destroy(session)

    -- lua-lifetime docs/02-semantics.md, "Cascading death": the session's
    -- body first; then its dependents, newest first: the hook that removes
    -- the entries (attached last), then the three procedures.
    test.assert_deep_eq(log, {
        "TestSession:release(destroy), entries 3",
        "  unregister DownloadMissingAssetsRp, entries 0",
        "  unregister DownloadAssetRp, entries 0",
        "  unregister UploadAssetRp, entries 0"
    })
    for _, rp in ipairs(procedures) do
        test.assert_false(lifetime.alive(rp))
    end
    test.assert_eq(next(manager._upload_asset_rp), nil)
    test.assert_eq(next(manager._download_asset_rp), nil)
    test.assert_eq(next(manager._download_missing_assets_rp), nil)
    test.assert_true(lifetime.alive(connection), "the connection does not depend on the session")
end)
