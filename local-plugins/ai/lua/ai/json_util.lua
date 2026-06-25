-- lua/ai/json_util.lua
-- 公共 JSON / JSONC / 表合并工具
-- 替代 opencode.lua / claude_code.lua / config_resolver.lua 中的三份重复实现

local M = {}

----------------------------------------------------------------------
-- tbl_is_array(t): 判断 table 是否为纯数组
----------------------------------------------------------------------
function M.tbl_is_array(t)
  if type(t) ~= "table" then
    return false
  end
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then
      return false
    end
  end
  return i > 0
end

----------------------------------------------------------------------
-- strip_jsonc_comments(content): 去除 JSONC 注释和尾随逗号
----------------------------------------------------------------------
function M.strip_jsonc_comments(content)
  local result = {}
  local in_string = false
  local escape_next = false
  local i = 1

  while i <= #content do
    local char = content:sub(i, i)

    if escape_next then
      table.insert(result, char)
      escape_next = false
      i = i + 1
    elseif char == "\\" and in_string then
      table.insert(result, char)
      escape_next = true
      i = i + 1
    elseif char == '"' then
      table.insert(result, char)
      in_string = not in_string
      i = i + 1
    elseif not in_string then
      if char == "/" and i < #content then
        local next_char = content:sub(i + 1, i + 1)
        if next_char == "/" then
          while i <= #content and content:sub(i, i) ~= "\n" do
            i = i + 1
          end
        elseif next_char == "*" then
          i = i + 2
          while i <= #content do
            if content:sub(i, i) == "*" and i < #content and content:sub(i + 1, i + 1) == "/" then
              i = i + 2
              break
            end
            i = i + 1
          end
        else
          table.insert(result, char)
          i = i + 1
        end
      else
        table.insert(result, char)
        i = i + 1
      end
    else
      table.insert(result, char)
      i = i + 1
    end
  end

  local clean = table.concat(result)
  -- 去除尾随逗号 (JSON 不允许)
  clean = clean:gsub(",%s*([}%]])", "%1")
  return clean
end

----------------------------------------------------------------------
-- format_json(obj, indent): 序列化 lua 表为格式化 JSON
-- 数组按原序输出，对象按 key 字典序输出（确保可重现）
----------------------------------------------------------------------
function M.format_json(obj, indent)
  indent = indent or 0
  local spacing = string.rep("  ", indent)

  if type(obj) == "table" then
    if next(obj) == nil then
      return "{}"
    end

    local items = {}

    if M.tbl_is_array(obj) then
      for _, v in ipairs(obj) do
        table.insert(items, spacing .. "  " .. M.format_json(v, indent + 1))
      end
      return "[\n" .. table.concat(items, ",\n") .. "\n" .. spacing .. "]"
    else
      local sorted_keys = {}
      for k in pairs(obj) do
        table.insert(sorted_keys, k)
      end
      table.sort(sorted_keys, function(a, b)
        return tostring(a) < tostring(b)
      end)

      for _, k in ipairs(sorted_keys) do
        local v = obj[k]
        local key = type(k) == "number" and tostring(k) or string.format("%q", k)
        table.insert(items, spacing .. "  " .. key .. ": " .. M.format_json(v, indent + 1))
      end
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. spacing .. "}"
    end
  elseif type(obj) == "string" then
    local escaped = obj:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    -- #16 修复: 只在必要时转义控制字符，提高性能
    if obj:match("[%z\x01-\x1f]") then
      escaped = escaped:gsub("[%z\x01-\x1f]", function(c)
        return string.format("\\u%04x", c:byte())
      end)
    end
    return '"' .. escaped .. '"'
  elseif type(obj) == "number" then
    -- M-09 修复: 处理 NaN 和 Infinity，它们不是有效 JSON
    if obj ~= obj then
      return "null" -- NaN → null
    elseif obj == math.huge or obj == -math.huge then
      return "null" -- Infinity → null
    end
    return tostring(obj)
  elseif type(obj) == "boolean" then
    return tostring(obj)
  elseif obj == nil then
    return "null"
  else
    return tostring(obj)
  end
end

----------------------------------------------------------------------
-- deep_merge(base, override): 深合并两个 table
-- 数组（纯 array）直接被 override 整个替换；object 递归合并
----------------------------------------------------------------------
function M.deep_merge(base, override)
  if type(base) ~= "table" or type(override) ~= "table" then
    return override
  end

  local result = vim.deepcopy(base)
  for key, value in pairs(override) do
    if M.tbl_is_array(value) and M.tbl_is_array(result[key]) then
      result[key] = vim.deepcopy(value)
    elseif type(value) == "table" and type(result[key]) == "table" then
      result[key] = M.deep_merge(result[key], value)
    else
      result[key] = value
    end
  end
  return result
end

----------------------------------------------------------------------
-- parse_jsonc_file(path): 读取 JSONC 文件并解析为 lua table
-- 返回: table|nil, error_message|nil
----------------------------------------------------------------------
function M.parse_jsonc_file(path)
  if vim.fn.filereadable(path) == 0 then
    return nil, "File not readable: " .. path
  end

  local content = table.concat(vim.fn.readfile(path), "\n")
  local clean = M.strip_jsonc_comments(content)

  local ok, parsed = pcall(vim.json.decode, clean)
  if not ok then
    return nil, "JSON parse error: " .. tostring(parsed)
  end
  return parsed, nil
end

return M
