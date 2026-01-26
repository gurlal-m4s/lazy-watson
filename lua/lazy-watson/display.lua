-- Lazy Watson - Display Module
-- Virtual text/extmark management

local M = {}

-- State for hover window
local hover_state = {
  win = nil,
  buf = nil,
  close_autocmd = nil,
}

--- Render virtual text for all matches in a buffer
---@param bufnr number Buffer number
---@param namespace number Namespace ID
---@param matches table[] Array of matches from parser
---@param messages table Message key-value map for current locale
---@param all_messages table All locale messages { [locale] = { [key] = "translation" } }
---@param locales string[] List of all locale codes
---@param opts table Virtual text options
function M.render(bufnr, namespace, matches, messages, all_messages, locales, opts)
  -- Clear existing extmarks
  M.clear(bufnr, namespace)

  opts = opts or {}
  local prefix = opts.prefix or " -> "
  local hl_group = opts.hl_group or "Comment"
  local hl_missing_key = opts.hl_missing_key or "DiagnosticError"
  local hl_missing_locale = opts.hl_missing_locale or "DiagnosticWarn"
  local max_length = opts.max_length or 50
  local show_missing = opts.show_missing ~= false -- Default to true
  local missing_prefix = opts.missing_prefix or "  X "
  local hl_missing_locales = opts.hl_missing_locales or "DiagnosticError"

  for _, match in ipairs(matches) do
    local translation = messages[match.key]
    local virt_text = {}

    if translation then
      -- Found translation
      local text = prefix .. '"' .. M._truncate(translation, max_length) .. '"'
      table.insert(virt_text, { text, hl_group })
    else
      -- Missing translation
      if next(messages) == nil then
        -- No messages loaded at all (missing locale file)
        table.insert(virt_text, { prefix .. "[locale not loaded]", hl_missing_locale })
      else
        -- Messages loaded but key not found
        table.insert(virt_text, { prefix .. "[missing key]", hl_missing_key })
      end
    end

    -- Add missing locale indicator if enabled
    if show_missing and all_messages and locales and #locales > 0 then
      local missing_locales = {}
      for _, locale in ipairs(locales) do
        local locale_messages = all_messages[locale] or {}
        if not locale_messages[match.key] then
          table.insert(missing_locales, locale)
        end
      end

      if #missing_locales > 0 then
        table.insert(virt_text, { missing_prefix, hl_missing_locales })
        table.insert(virt_text, { table.concat(missing_locales, ", "), hl_missing_locales })
      end
    end

    -- Create extmark with virtual text
    local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, match.line, match.col_end + 1, {
      virt_text = virt_text,
      virt_text_pos = "inline",
      hl_mode = "combine",
    })

    if not ok then
      -- Fallback to eol position if inline fails
      pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, match.line, 0, {
        virt_text = virt_text,
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    end
  end
end

--- Clear all extmarks in a buffer
---@param bufnr number Buffer number
---@param namespace number Namespace ID
function M.clear(bufnr, namespace)
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, namespace, 0, -1)
  end
end

--- Truncate text to max length with ellipsis
---@param text string Text to truncate
---@param max number Maximum length
---@return string Truncated text
function M._truncate(text, max)
  if not text then
    return ""
  end

  -- Replace newlines with spaces for display
  text = text:gsub("\n", " "):gsub("\r", "")

  -- Collapse multiple spaces
  text = text:gsub("%s+", " ")

  -- Trim leading/trailing whitespace
  text = text:match("^%s*(.-)%s*$")

  if #text > max then
    return text:sub(1, max - 3) .. "..."
  end

  return text
end

--- Close any open hover window
function M.close_hover()
  if hover_state.close_autocmd then
    pcall(vim.api.nvim_del_autocmd, hover_state.close_autocmd)
    hover_state.close_autocmd = nil
  end

  if hover_state.win and vim.api.nvim_win_is_valid(hover_state.win) then
    pcall(vim.api.nvim_win_close, hover_state.win, true)
  end

  if hover_state.buf and vim.api.nvim_buf_is_valid(hover_state.buf) then
    pcall(vim.api.nvim_buf_delete, hover_state.buf, { force = true })
  end

  hover_state.win = nil
  hover_state.buf = nil
end

--- Show hover preview with all locale translations
---@param key string Translation key
---@param all_messages table All locale messages { [locale] = { [key] = "translation" } }
---@param locales string[] List of all locale codes
---@param opts table|nil Display options
function M.show_hover(key, all_messages, locales, opts)
  -- Close any existing hover first
  M.close_hover()

  opts = opts or {}
  local max_length = opts.max_length or 60

  -- Build hover content
  local lines = {}
  local highlights = {}

  -- Header with key name
  table.insert(lines, "  " .. key)
  table.insert(lines, "  " .. string.rep("─", math.min(#key + 4, 40)))
  table.insert(highlights, { line = 0, col = 2, end_col = 2 + #key, hl = "Title" })

  -- Add each locale
  for _, locale in ipairs(locales) do
    local locale_messages = all_messages[locale] or {}
    local translation = locale_messages[key]

    local line
    local hl
    if translation then
      local truncated = M._truncate(translation, max_length)
      line = string.format("  %s: \"%s\"", locale, truncated)
      hl = "Comment"
    else
      line = string.format("  %s: ⚠ [missing]", locale)
      hl = "DiagnosticWarn"
    end

    table.insert(lines, line)
    table.insert(highlights, { line = #lines - 1, col = 2, end_col = 2 + #locale, hl = "Identifier" })
    table.insert(highlights, { line = #lines - 1, col = 2 + #locale + 2, end_col = #line, hl = hl })
  end

  -- Add empty line at bottom for padding
  table.insert(lines, "")

  -- Create floating window using LSP util for consistency
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "lazy-watson-hover"

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace("lazy_watson_hover")
  for _, hl_info in ipairs(highlights) do
    pcall(vim.api.nvim_buf_add_highlight, buf, ns, hl_info.hl, hl_info.line, hl_info.col, hl_info.end_col)
  end

  -- Calculate window size
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end
  max_width = math.min(max_width + 2, 80) -- Add padding, cap at 80

  -- Open floating window
  local win_opts = {
    relative = "cursor",
    row = 1,
    col = 0,
    width = max_width,
    height = #lines,
    style = "minimal",
    border = "rounded",
    focusable = false,
    noautocmd = true,
  }

  local win = vim.api.nvim_open_win(buf, false, win_opts)
  vim.wo[win].wrap = false
  vim.wo[win].conceallevel = 2

  hover_state.win = win
  hover_state.buf = buf

  -- Close on cursor move
  hover_state.close_autocmd = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave", "WinLeave" }, {
    callback = function()
      M.close_hover()
    end,
    once = true,
  })
end

return M
