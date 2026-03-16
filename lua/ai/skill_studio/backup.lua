-- lua/ai/skill_studio/backup.lua
-- Backup manager for storing and managing created skills/MCPs

local M = {}

local backup_dir = vim.fn.stdpath("data") .. "/skill_studio/backups"
local index_file = backup_dir .. "/index.json"
local index = {}

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------
function M.setup(dir)
  backup_dir = dir or backup_dir
  index_file = backup_dir .. "/index.json"
  vim.fn.mkdir(backup_dir, "p")
  M.load_index()
end

----------------------------------------------------------------------
-- Index Management
----------------------------------------------------------------------
function M.load_index()
  if vim.fn.filereadable(index_file) == 1 then
    local content = table.concat(vim.fn.readfile(index_file), "\n")
    local ok, data = pcall(vim.json.decode, content)
    if ok and data then
      index = data
    else
      index = {}
    end
  else
    index = {}
  end
end

function M.save_index()
  local content = vim.json.encode(index)
  vim.fn.writefile(vim.split(content, "\n"), index_file)
end

----------------------------------------------------------------------
-- Generate ID
----------------------------------------------------------------------
local function generate_id()
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local random = string.format("%04x", math.random(0, 0xFFFF))
  return string.format("skill_%s_%s", timestamp, random)
end

----------------------------------------------------------------------
-- Save Item
----------------------------------------------------------------------
function M.save(item)
  local id = generate_id()
  local now = os.date("%Y-%m-%dT%H:%M:%SZ")

  local record = {
    id = id,
    type = item.type,
    target = item.target,
    level = item.level,
    name = item.frontmatter and item.frontmatter.name or item.name or "unnamed",
    created_at = now,
    updated_at = now,
    data = item,
  }

  index[id] = record
  M.save_index()

  local file_path = backup_dir .. "/" .. id .. ".json"
  local content = vim.json.encode(item)
  vim.fn.writefile(vim.split(content, "\n"), file_path)

  return id
end

----------------------------------------------------------------------
-- Load Item
----------------------------------------------------------------------
function M.load(id)
  local record = index[id]
  if not record then
    return nil
  end

  local file_path = backup_dir .. "/" .. id .. ".json"
  if vim.fn.filereadable(file_path) == 0 then
    return nil
  end

  local content = table.concat(vim.fn.readfile(file_path), "\n")
  local ok, data = pcall(vim.json.decode, content)
  if ok and data then
    return vim.tbl_extend("force", data, {
      id = id,
      target = record.target,
      level = record.level,
      created_at = record.created_at,
      updated_at = record.updated_at,
    })
  end
  return nil
end

----------------------------------------------------------------------
-- Update Item
----------------------------------------------------------------------
function M.update(id, item)
  local record = index[id]
  if not record then
    return false
  end

  record.updated_at = os.date("%Y-%m-%dT%H:%M:%SZ")
  record.name = item.frontmatter and item.frontmatter.name or item.name or record.name
  record.data = item
  index[id] = record
  M.save_index()

  local file_path = backup_dir .. "/" .. id .. ".json"
  local content = vim.json.encode(item)
  vim.fn.writefile(vim.split(content, "\n"), file_path)

  return true
end

----------------------------------------------------------------------
-- Delete Item
----------------------------------------------------------------------
function M.delete(id)
  if not index[id] then
    return false
  end

  index[id] = nil
  M.save_index()

  local file_path = backup_dir .. "/" .. id .. ".json"
  vim.fn.delete(file_path)

  return true
end

----------------------------------------------------------------------
-- List Items
----------------------------------------------------------------------
function M.list(opts)
  opts = opts or {}
  local items = {}

  for id, record in pairs(index) do
    if not opts.type or record.type == opts.type then
      if not opts.target or record.target == opts.target then
        local description = ""
        if record.data and record.data.frontmatter then
          description = record.data.frontmatter.description or ""
        end
        table.insert(items, {
          id = id,
          type = record.type,
          target = record.target,
          level = record.level,
          name = record.name,
          description = description,
          created_at = record.created_at,
          updated_at = record.updated_at,
        })
      end
    end
  end

  table.sort(items, function(a, b)
    return a.updated_at > b.updated_at
  end)

  return items
end

----------------------------------------------------------------------
-- Search Items
----------------------------------------------------------------------
function M.search(query)
  local results = {}
  local query_lower = query:lower()

  for id, record in pairs(index) do
    local name = (record.name or ""):lower()
    if name:find(query_lower, 1, true) then
      table.insert(results, {
        id = id,
        type = record.type,
        target = record.target,
        level = record.level,
        name = record.name,
        created_at = record.created_at,
        updated_at = record.updated_at,
      })
    end
  end

  table.sort(results, function(a, b)
    return a.updated_at > b.updated_at
  end)

  return results
end

----------------------------------------------------------------------
-- Export/Import
----------------------------------------------------------------------
function M.export(export_path)
  local all_data = {
    index = index,
    items = {},
  }

  for id, _ in pairs(index) do
    local item = M.load(id)
    if item then
      all_data.items[id] = item
    end
  end

  local content = vim.json.encode(all_data)
  vim.fn.writefile(vim.split(content, "\n"), export_path)
  return true
end

function M.import(import_path)
  if vim.fn.filereadable(import_path) == 0 then
    return false
  end

  local content = table.concat(vim.fn.readfile(import_path), "\n")
  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data then
    return false
  end

  for id, item in pairs(data.items or {}) do
    local record = data.index and data.index[id]
    if record then
      index[id] = record
      local file_path = backup_dir .. "/" .. id .. ".json"
      local item_content = vim.json.encode(item)
      vim.fn.writefile(vim.split(item_content, "\n"), file_path)
    end
  end

  M.save_index()
  return true
end

return M