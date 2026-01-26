-- Lazy Watson - Parser Module
-- Buffer parsing for Paraglide m.* patterns

local M = {}

--- Find all message calls in a buffer
---@param bufnr number Buffer number
---@return table[] Array of matches: { key, line, col_start, col_end }
function M.find_message_calls(bufnr)
  local matches = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for line_idx, line in ipairs(lines) do
    local line_num = line_idx - 1 -- 0-indexed for nvim API

    -- Pattern 1: m.keyName() or m.keyName(args)
    -- Matches: m.auth, m.user_name, m.$key, m.camelCase123
    local pos = 1
    while pos <= #line do
      -- Look for "m." pattern
      local m_start, m_end = line:find("[^%w_]m%.", pos)
      if not m_start then
        -- Try at start of line
        m_start, m_end = line:find("^m%.", pos)
      end

      if m_start then
        -- Adjust start to point to 'm'
        local actual_start = m_end - 1 -- position of 'm'
        if line:sub(m_start, m_start) ~= "m" then
          actual_start = m_start + 1
        else
          actual_start = m_start
        end

        -- Extract the key name (identifiers can contain letters, digits, _, $)
        local after_dot = line:sub(m_end + 1)
        local key = after_dot:match("^([a-zA-Z_$][a-zA-Z0-9_$]*)")

        if key then
          -- Check if followed by (
          local after_key = line:sub(m_end + 1 + #key)
          local paren_offset = after_key:match("^(%s*)%(")

          if paren_offset then
            -- Find the closing paren
            local paren_start = m_end + #key + #paren_offset + 1
            local col_end = M._find_closing_paren(line, paren_start)

            if col_end then
              table.insert(matches, {
                key = key,
                line = line_num,
                col_start = actual_start - 1, -- 0-indexed
                col_end = col_end - 1, -- 0-indexed, position of )
              })
            end
          end
        end

        pos = m_end + 1
      else
        break
      end
    end

    -- Pattern 2: m["nested.key"]() or m['nested.key']()
    pos = 1
    while pos <= #line do
      -- Look for m[ pattern
      local bracket_match_start = line:find("[^%w_]m%[", pos) or line:find("^m%[", pos)

      if bracket_match_start then
        local m_pos = line:find("m%[", bracket_match_start)
        if m_pos then
          local after_bracket = line:sub(m_pos + 2)

          -- Match quoted string inside brackets
          local quote_char, key_content, rest = after_bracket:match("^%s*([\"'])(.-)%1%s*%](.*)")

          if key_content then
            -- Check if followed by (
            local paren_offset = rest:match("^(%s*)%(")

            if paren_offset then
              -- Calculate positions
              local key_end_in_line = m_pos + 2 + #after_bracket - #rest - 1
              local paren_start = key_end_in_line + #paren_offset + 1
              local col_end = M._find_closing_paren(line, paren_start)

              if col_end then
                table.insert(matches, {
                  key = key_content,
                  line = line_num,
                  col_start = m_pos - 1, -- 0-indexed
                  col_end = col_end - 1, -- 0-indexed
                })
              end
            end
          end

          pos = m_pos + 2
        else
          break
        end
      else
        break
      end
    end
  end

  return matches
end

--- Find the position of the closing parenthesis
---@param line string The line to search
---@param start_pos number Position of the opening paren (1-indexed)
---@return number|nil Position of closing paren (1-indexed) or nil if not found
function M._find_closing_paren(line, start_pos)
  local depth = 1
  local pos = start_pos + 1

  while pos <= #line and depth > 0 do
    local char = line:sub(pos, pos)

    if char == "(" then
      depth = depth + 1
    elseif char == ")" then
      depth = depth - 1
      if depth == 0 then
        return pos
      end
    elseif char == '"' or char == "'" or char == "`" then
      -- Skip string content
      local quote = char
      pos = pos + 1
      while pos <= #line do
        local c = line:sub(pos, pos)
        if c == quote and line:sub(pos - 1, pos - 1) ~= "\\" then
          break
        end
        pos = pos + 1
      end
    end

    pos = pos + 1
  end

  return nil
end

return M
