-- mod-version:3 -- lite-xl 2.1

----------------------------------------------------------------
-- NAME        : gitblame
-- DESCRIPTION : Show git author and commit message on a certain line
-- AUTHOR      : Juliardi (github.com/juliardi)
----------------------------------------------------------------

local core = require "core"
local style = require "core.style"
local common = require "core.common"
local config = require "core.config"
local command = require "core.command"
local DocView = require "core.docview"

config.plugins.gitblame = {}

config.plugins.gitblame.text_color = {200, 140, 220}

config.plugins.gitblame.font_size = 14

config.plugins.gitblame.max_commit_message_length = 50

local function get_active_view()
    if core.active_view:is(DocView) then
        return core.active_view
    end
end

local previous_scale = SCALE
local desc_font = style.code_font:copy(
  config.plugins.gitblame.font_size * SCALE
)

local function draw_blame_info_box(text, sx, sy)
  if previous_scale ~= SCALE then
    desc_font = style.code_font:copy(
      config.plugins.gitblame.font_size * SCALE
    )
    previous_scale = SCALE
  end

  local font = desc_font
  local lh = font:get_height()
  local y = sy + lh + (2 * style.padding.y)
  local width = 0

  local lines = {}
  for line in string.gmatch(text.."\n", "(.-)\n") do
      width = math.max(width, font:get_width(line))
      table.insert(lines, line)
  end

  sy = sy + lh + style.padding.y

  local height = #lines * font:get_height()

  -- draw background rect
  renderer.draw_rect(
    sx,
    sy,
    width + style.padding.x * 2,
    height + style.padding.y * 2,
    style.background3
  )

  -- draw text
  for _, line in pairs(lines) do
    common.draw_text(
      font,
      style.text,
      line,
      "left",
      sx + style.padding.x,
      y,
      width,
      lh
    )
    y = y + lh
  end
end

local function get_text_coordinates()
    local av = get_active_view()

    if av ~= nil then
        local line, _ = av.doc:get_selection()
        local x, y = av:get_line_screen_position(line)

        return x, y
    end

    return nil, nil
end

local function exec(cmd)
  local handle = io.popen(cmd)
  if handle ~= nil then
    local result = handle:read("*a")
    handle:close()

    return result
  end

  return ''
end

local function get_commit_message(commit_hash)
  local cmd = "git show --no-color --pretty=format:%s --no-patch " .. commit_hash

  local result = exec(cmd)

  if result:len() > config.plugins.gitblame.max_commit_message_length then
    result = result:sub(0, config.plugins.gitblame.max_commit_message_length) .. "..."
  end

  return result
end

local function get_blame_text()
  local av = get_active_view()

  if av ~= nil then
    local abs_filename = av.doc.abs_filename
    local line, _ = av.doc:get_selection()

    local cmd = "git blame -L " .. line .. ',' .. line .. ' ' .. abs_filename

    local blame = exec(cmd)

    local commit_hash = blame:match "%w+"

    if commit_hash == nil then
      return nil
    end

    local username = (blame:match "[(]+%w+")
    if username ~= nil then
      username = username:gsub("%(","")
    end

    local datetime = blame:match "%d+[-]?%d+[-]?%d+[ ]?%d+[:]?%d+[:]?%d+"
    local commit_message = get_commit_message(commit_hash)

    local result = "(" .. username .. ") " .. datetime .. ' | ' .. commit_hash .. ' | ' .. commit_message

    return result
  end
end

local parent_draw = DocView.draw

function DocView.draw(self)
    parent_draw(self)

    if config.plugins.gitblame.show_blame then
      local message

      local blame_text = get_blame_text()

      if blame_text ~= nil then
        message = "Git Blame | " .. blame_text

        -- let's get the coordinates for our text
        local x, y = get_text_coordinates()

        if x ~=nil and y ~= nil then
            draw_blame_info_box(message, x, y)
        end
      end

   end
end

local function predicate()
    return core.active_view:is(DocView)
end

local function toggle_gitblame()
   config.plugins.gitblame.show_blame = not config.plugins.gitblame.show_blame
end

local parent_text_input = DocView.on_text_input

function DocView.on_text_input(self, text)
  parent_text_input(self, text)

  config.plugins.gitblame.show_blame = false
end

command.add(predicate, {
    ["git blame:show"] = function()
        toggle_gitblame()
    end
})
