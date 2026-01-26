-- Lazy Watson - Inlang i18n Preview for Neovim
-- Displays translation values as virtual text for Paraglide m.keyName() calls

local parser = require("lazy-watson.parser")
local loader = require("lazy-watson.loader")
local display = require("lazy-watson.display")

local M = {}

-- Default configuration
M.config = {
  enabled = true,
  debounce_ms = 150,
  virtual_text = {
    prefix = " -> ",
    hl_group = "Comment",
    hl_missing_key = "DiagnosticError",
    hl_missing_locale = "DiagnosticWarn",
    max_length = 50,
    show_missing = true,
    missing_prefix = "  X ",
    hl_missing_locales = "DiagnosticError",
  },
  hover = {
    enabled = true,
    delay = 300,
  },
  project_pattern = "project.inlang/settings.json",
}

-- State
local state = {
  enabled = true,
  current_locale = nil,
  project_root = nil,
  messages = {}, -- { [locale] = { [key] = "translation" } }
  attached_buffers = {},
  namespace = nil,
  file_watchers = {},
  debounce_timers = {},
  settings = nil, -- { baseLocale, locales, pathPattern }
}

-- Supported filetypes
local supported_filetypes = {
  javascript = true,
  typescript = true,
  svelte = true,
  javascriptreact = true,
  typescriptreact = true,
}

--- Initialize the plugin
---@param opts table|nil Configuration options
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  state.enabled = M.config.enabled
  state.namespace = vim.api.nvim_create_namespace("lazy_watson")

  -- Set up autocommands
  local augroup = vim.api.nvim_create_augroup("LazyWatson", { clear = true })

  -- Attach to supported filetypes
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = { "javascript", "typescript", "svelte", "javascriptreact", "typescriptreact" },
    callback = function(args)
      M._attach_buffer(args.buf)
    end,
  })

  -- Update on text changes (debounced)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    callback = function(args)
      if state.attached_buffers[args.buf] then
        M._debounced_update(args.buf)
      end
    end,
  })

  -- Cleanup on buffer delete
  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    callback = function(args)
      M._detach_buffer(args.buf)
    end,
  })

  -- CursorHold for hover preview
  if M.config.hover.enabled then
    vim.api.nvim_create_autocmd("CursorHold", {
      group = augroup,
      callback = function(args)
        if state.attached_buffers[args.buf] and state.enabled then
          M._trigger_hover()
        end
      end,
    })
  end

  -- Attach to current buffer if it's a supported filetype
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  if supported_filetypes[ft] then
    M._attach_buffer(bufnr)
  end
end

--- Toggle preview on/off
function M.toggle()
  state.enabled = not state.enabled
  if state.enabled then
    vim.notify("Lazy Watson enabled", vim.log.levels.INFO)
    -- Re-render all attached buffers
    for bufnr, _ in pairs(state.attached_buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        M._update_buffer(bufnr)
      end
    end
  else
    vim.notify("Lazy Watson disabled", vim.log.levels.INFO)
    -- Clear all virtual text
    for bufnr, _ in pairs(state.attached_buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        display.clear(bufnr, state.namespace)
      end
    end
  end
end

--- Load messages for all locales
function M._load_all_locales()
  if not state.project_root or not state.settings then
    return
  end

  for _, locale in ipairs(state.settings.locales) do
    state.messages[locale] = loader.load_messages(
      state.project_root,
      state.settings.pathPattern,
      locale
    )
  end
end

--- Force reload and re-render
function M.refresh()
  -- Clear message cache
  state.messages = {}

  -- Reload messages for all locales
  M._load_all_locales()

  -- Re-render all attached buffers
  for bufnr, _ in pairs(state.attached_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      M._update_buffer(bufnr)
    end
  end

  vim.notify("Lazy Watson translations refreshed", vim.log.levels.INFO)
end

--- Open locale picker
function M.select_locale()
  if not state.settings or not state.settings.locales then
    vim.notify("No inlang project found", vim.log.levels.WARN)
    return
  end

  vim.ui.select(state.settings.locales, {
    prompt = "Select locale:",
    format_item = function(locale)
      local marker = ""
      if locale == state.current_locale then
        marker = " (current)"
      elseif locale == state.settings.baseLocale then
        marker = " (base)"
      end
      return locale .. marker
    end,
  }, function(choice)
    if choice then
      state.current_locale = choice

      -- Load messages for new locale if not cached
      if not state.messages[choice] and state.project_root and state.settings then
        state.messages[choice] = loader.load_messages(
          state.project_root,
          state.settings.pathPattern,
          choice
        )
      end

      -- Re-render all attached buffers
      for bufnr, _ in pairs(state.attached_buffers) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          M._update_buffer(bufnr)
        end
      end

      vim.notify("Locale set to: " .. choice, vim.log.levels.INFO)
    end
  end)
end

--- Get translation key at cursor position
---@return string|nil The translation key or nil if not found
function M.get_key_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1] - 1 -- 0-indexed
  local col = cursor[2]

  local matches = parser.find_message_calls(bufnr)

  for _, match in ipairs(matches) do
    if match.line == line_num then
      -- Check if cursor is within the match range
      if col >= match.col_start and col <= match.col_end then
        return match.key
      end
    end
  end

  return nil
end

--- Show hover preview for key at cursor
--- Can be called manually via keybinding or triggered by CursorHold
function M.show_hover()
  local key = M.get_key_at_cursor()
  if not key then
    return false
  end

  if not state.settings or not state.settings.locales then
    return false
  end

  display.show_hover(key, state.messages, state.settings.locales, {
    max_length = M.config.virtual_text.max_length,
  })

  return true
end

--- Internal: Trigger hover preview on CursorHold
function M._trigger_hover()
  M.show_hover()
end

--- Attach to a buffer
---@param bufnr number Buffer number
function M._attach_buffer(bufnr)
  if state.attached_buffers[bufnr] then
    return
  end

  -- Get the file path
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then
    return
  end

  -- Find project root if not already found
  if not state.project_root then
    state.project_root = loader.find_project_root(filepath, M.config.project_pattern)
    if state.project_root then
      -- Load settings
      state.settings = loader.load_settings(state.project_root, M.config.project_pattern)
      if state.settings then
        state.current_locale = state.settings.baseLocale

        -- Load messages for ALL locales (needed for hover and missing indicator)
        M._load_all_locales()

        -- Set up file watchers
        M._setup_file_watchers()
      end
    end
  end

  state.attached_buffers[bufnr] = true

  -- Initial render
  if state.enabled then
    M._update_buffer(bufnr)
  end
end

--- Detach from a buffer
---@param bufnr number Buffer number
function M._detach_buffer(bufnr)
  state.attached_buffers[bufnr] = nil

  -- Cancel any pending debounce timer
  if state.debounce_timers[bufnr] then
    state.debounce_timers[bufnr]:stop()
    state.debounce_timers[bufnr]:close()
    state.debounce_timers[bufnr] = nil
  end
end

--- Debounced update for a buffer
---@param bufnr number Buffer number
function M._debounced_update(bufnr)
  -- Cancel existing timer
  if state.debounce_timers[bufnr] then
    state.debounce_timers[bufnr]:stop()
  else
    state.debounce_timers[bufnr] = vim.uv.new_timer()
  end

  state.debounce_timers[bufnr]:start(M.config.debounce_ms, 0, vim.schedule_wrap(function()
    if vim.api.nvim_buf_is_valid(bufnr) and state.enabled then
      M._update_buffer(bufnr)
    end
  end))
end

--- Update virtual text for a buffer
---@param bufnr number Buffer number
function M._update_buffer(bufnr)
  if not state.enabled then
    return
  end

  local locale = state.current_locale
  local messages = state.messages[locale] or {}
  local locales = state.settings and state.settings.locales or {}

  -- Parse buffer for message calls
  local matches = parser.find_message_calls(bufnr)

  -- Render virtual text with all locale info for missing indicator
  display.render(bufnr, state.namespace, matches, messages, state.messages, locales, M.config.virtual_text)
end

--- Set up file watchers for message files
function M._setup_file_watchers()
  -- Clean up existing watchers
  for _, watcher in ipairs(state.file_watchers) do
    watcher:stop()
    watcher:close()
  end
  state.file_watchers = {}

  if not state.project_root or not state.settings then
    return
  end

  -- Watch message files for each locale
  for _, locale in ipairs(state.settings.locales) do
    local message_path = loader.get_message_path(
      state.project_root,
      state.settings.pathPattern,
      locale
    )

    if message_path and vim.fn.filereadable(message_path) == 1 then
      local watcher = vim.uv.new_fs_event()
      if watcher then
        watcher:start(message_path, {}, vim.schedule_wrap(function(err, _, _)
          if not err then
            -- Reload messages for this locale
            state.messages[locale] = loader.load_messages(
              state.project_root,
              state.settings.pathPattern,
              locale
            )

            -- Refresh all buffers (needed for missing indicator which shows all locales)
            for bufnr, _ in pairs(state.attached_buffers) do
              if vim.api.nvim_buf_is_valid(bufnr) then
                M._update_buffer(bufnr)
              end
            end
          end
        end))
        table.insert(state.file_watchers, watcher)
      end
    end
  end
end

return M
