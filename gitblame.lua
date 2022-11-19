local core = require "core"
local config = require "core.config"

local gitblame = {}

local blame_pattern = "%w+[ (%w]+[ ]+%d+[-]?%d+[-]?%d+[ ]?%d+[:]?%d+[:]?%d+[ ]+[+-]?%d+"
local hash_pattern = "[0-9a-f]+"
local username_pattern = "[ ]*%w+"
local datetime_pattern = "%d+[-]?%d+[-]?%d+[ ]?%d+[:]?%d+[:]?%d+[ ]+[+-]?%d+"

local not_commited_yet_hash = "00000000"

local not_git_repo_message = "fatal: not a git repository"

local function exec(cmd)
    local proc = process.start(cmd)

    if proc then

        local output = ""

        while true do
            local rdbuf = proc:read_stdout()
            if not rdbuf then
                break
            else
                output = output .. rdbuf
            end
        end

        return output
    end

    return nil
end

local function log_data(var_name, var_value)
  if config.plugins.gitblame.debug then
    if var_value ~= nil then
      core.log("[GITBLAME] " .. var_name .. " : " .. var_value)
    else
      core.log("[GITBLAME] " .. var_name .. " : nil")
    end
  end
end

local function get_commit_message(commit_hash)
  local cmd = {"git", "show", "--no-color", "--pretty=format:%s", "--no-patch", commit_hash}

  local result = exec(cmd)

  if result:len() > config.plugins.gitblame.max_commit_message_length then
    result = result:sub(0, config.plugins.gitblame.max_commit_message_length) .. "..."
  end

  return result
end

local function truncate_blame_text(blame_text)
  local _, first_index = blame_text:find(hash_pattern)

  local last_index, _ = blame_text:find(datetime_pattern)

  return blame_text:sub(first_index+1, last_index-1)
end

function gitblame.get_blame_text(active_view)
  if active_view ~= nil then
    local abs_filename = active_view.doc.abs_filename
    local line, _ = active_view.doc:get_selection()

    local git_command = {"git", "blame", "-L", line .. "," .. line, abs_filename}

    local git_output = exec(git_command)

    log_data("git_output", git_output)

    local blame_text = git_output:match(blame_pattern)

    log_data("blame_text", blame_text)

    if blame_text == nil then
      local a, _ = git_output:find(not_git_repo_message)

      if a ~= nil then
        return "Not a git repository"
      end

      return nil
    end

    local commit_hash = blame_text:match(hash_pattern)

    log_data("commit_hash", commit_hash)

    if commit_hash == nil then
      return nil
    end

    if commit_hash == not_commited_yet_hash then
      return "Not Committed Yet"
    end

    local datetime = blame_text:match(datetime_pattern)

    log_data("datetime", datetime)

    blame_text = truncate_blame_text(blame_text)

    local username = blame_text:match(username_pattern)

    log_data("username", username)

    local commit_message = get_commit_message(commit_hash)

    local result = commit_hash .. ' | ' .. "(" .. username .. ") " .. datetime .. ' | ' ..  commit_message

    log_data("result", result)

    return result
  end
end

return gitblame
