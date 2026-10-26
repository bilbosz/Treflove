---@class fixture
local fixture = {}

---@param path string
---@param files string[] Output: every file under `path`
---@param directories string[] Output: every directory under `path`, parents before their content
local function _walk(path, files, directories)
    for _, item in ipairs(love.filesystem.getDirectoryItems(path)) do
        local item_path = path .. "/" .. item
        local info = love.filesystem.getInfo(item_path)
        if info and info.type == "directory" then
            table.insert(directories, item_path)
            _walk(item_path, files, directories)
        elseif info and info.type == "file" then
            table.insert(files, item_path)
        end
    end
end

---@param root string
local function _empty(root)
    ---@type string[], string[]
    local files, directories = {}, {}
    _walk(root, files, directories)
    for _, path in ipairs(files) do
        assert(love.filesystem.remove(path), "cannot remove " .. path)
    end
    -- LÖVE removes only an empty directory: the deepest go first
    for _, path in ripairs(directories) do
        assert(love.filesystem.remove(path), "cannot remove " .. path)
    end
end

---@param source_dir string A directory of the source tree, read through `love.filesystem`
---@param root string A directory of the save directory, emptied and then given a copy of what is under `source_dir`
function fixture.seed(source_dir, root)
    local info = love.filesystem.getInfo(source_dir)
    assert(info and info.type == "directory", "no fixture directory " .. source_dir)
    _empty(root)
    assert(love.filesystem.createDirectory(root), "cannot create " .. root)
    ---@type string[], string[]
    local files, directories = {}, {}
    _walk(source_dir, files, directories)
    local prefix_length = #source_dir + 1
    for _, path in ipairs(directories) do
        local target = root .. string.sub(path, prefix_length)
        assert(love.filesystem.createDirectory(target), "cannot create " .. target)
    end
    for _, path in ipairs(files) do
        local target = root .. string.sub(path, prefix_length)
        local content = assert(love.filesystem.read(path))
        assert(love.filesystem.write(target, content), "cannot write " .. target)
    end
end

return fixture
