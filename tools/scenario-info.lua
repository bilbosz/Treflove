---@type string
local root = (string.match(arg[0], "^(.*)/[^/]*$") or ".") .. "/.."
package.path = string.format("%s/?.lua;%s/lib/lua-lifetime/?.lua;%s/lib/lua-lifetime/?/init.lua;", root, root, root) .. package.path
require("app.globals")

local Consts = require("app.consts")

local USAGE = [[
Usage:
    luajit tools/scenario-info.lua <name> <peers|fixture>
Reads scenarios/<name>.lua and prints what scenario.sh needs of it:
    peers      the names of the peer clients it drives, one per line, none for a function scenario
    fixture    the fixture directory its server is seeded from, scenarios/fixtures/basic by default
Exit code: 0 for an answer, 2 for a usage error or a scenario that cannot be read.
]]

local EXIT_SUCCESS = 0
local EXIT_FAILURE = 2
local FIXTURE_DIRECTORY = Consts.SCENARIO_DIRECTORY .. "/fixtures"
local DEFAULT_FIXTURE = "basic"

---@param path string
---@return ScenarioFile|nil file `nil` for a function scenario
local function read(path)
    local source = io.open(string.format("%s/%s", root, path))
    if not source then
        error(string.format("no scenario %s", path), 0)
    end
    local content = source:read("*a")
    source:close()
    local chunk, err = loadstring(content, "@" .. path)
    if not chunk then
        error(err, 0)
    end
    ---@type any What the file returned
    local scenario = chunk()
    if type(scenario) == "function" then
        return nil
    end
    if type(scenario) ~= "table" then
        error(string.format("%s returns no function and no table", path), 0)
    end
    local file = scenario --[[@as ScenarioFile]]
    if file.peers ~= nil and type(file.peers) ~= "table" then
        error(string.format("%s returns peers that are not a list of strings", path), 0)
    end
    for _, peer in ipairs(file.peers or {}) do
        if type(peer) ~= "string" then
            error(string.format("%s returns peers that are not a list of strings", path), 0)
        end
    end
    if file.fixture ~= nil and type(file.fixture) ~= "string" then
        error(string.format("%s returns a fixture that is not a string", path), 0)
    end
    return file
end

---@param file ScenarioFile|nil
---@return string[]
local function peers(file)
    return file and file.peers or {}
end

---@param file ScenarioFile|nil
---@return string[]
local function fixture(file)
    return {
        string.format("%s/%s", FIXTURE_DIRECTORY, file and file.fixture or DEFAULT_FIXTURE)
    }
end

---@type table<string, fun(file: ScenarioFile|nil): string[]>
local QUESTIONS = {
    peers = peers,
    fixture = fixture
}

---@param args string[]
---@return integer exit_code
local function run(args)
    local name, question = args[1], QUESTIONS[args[2] or ""]
    if #args ~= 2 or not question then
        io.stderr:write(USAGE)
        return EXIT_FAILURE
    end
    local path = string.format("%s/%s.lua", Consts.SCENARIO_DIRECTORY, name)
    ---@type boolean, string[]|string
    local ok, lines = pcall(function()
        return question(read(path))
    end)
    if not ok or type(lines) == "string" then
        io.stderr:write(tostring(lines), "\n")
        return EXIT_FAILURE
    end
    for _, line in ipairs(lines) do
        io.stdout:write(line, "\n")
    end
    return EXIT_SUCCESS
end

local exit_code = run(arg)
io.stdout:flush()
os.exit(exit_code)
