local M = {}

-- Setup API key
M.setup = function(opts)
	local api_key = opts.api_key
	if api_key == nil then
		print("Please provide an OpenAI API key")
		return
	end

	-- Make sure the share directory exists
	local share_dir = os.getenv("HOME") .. "/.local/share/nvim"
	if vim.fn.isdirectory(share_dir) == 0 then
		vim.fn.mkdir(share_dir, "p")
	end

	-- Setup API key
	vim.g.gpt_api_key = api_key
end

--[[
Given a prompt, call chatGPT and stream back the results one chunk
as a time as they are streamed back from OpenAI.

```
require('gpt').stream("What is the meaning of life?", {
	trim_leading = true, -- Trim leading whitespace of the response
	on_chunk = function(chunk)
		print(chunk)
	end
})
```
]]
--
M.stream = function(prompt_or_messages, opts)
	if vim.g.gpt_api_key == nil then
		print("Please provide an OpenAI API key require('gpt').setup({})")
		return
	end

	local messages = prompt_or_messages
	if type(prompt_or_messages) == "string" then
		messages = { { role = "user", content = prompt_or_messages } }
	end

	local model = opts.model or "gpt-4"

	local payload = {
		stream = true,
		-- model = "gpt-3.5-turbo",
		-- model = "gpt-4",
		model = model,
		messages = messages,
	}

	local identity1 = function(chunk)
		return chunk
	end

	local identity = function()
	end

	opts = opts or {}
	local cb = opts.on_chunk or identity1
	local on_exit = opts.on_exit or identity
	local trim_leading = opts.trim_leading or true
	local encoded_payload = vim.fn.json_encode(payload)

	-- Write payload to temp file
	local params_path = os.getenv("HOME") .. "/.local/share/nvim/gpt.query.json"
	local temp = io.open(params_path, "w")
	if temp ~= nil then
		temp:write(encoded_payload)
		temp:close()
	end

	local command =
		"curl --no-buffer https://api.openai.com/v1/chat/completions " ..
		"-H 'Content-Type: application/json' -H 'Authorization: Bearer " .. vim.g.gpt_api_key .. "' " ..
		"-d @" .. params_path .. " | tee ~/.local/share/nvim/gpt.log 2>/dev/null"

	-- Write command to log file
	local log = io.open(os.getenv("HOME") .. "/.local/share/nvim/gpt.log", "w")
	if log ~= nil then
		log:write(command)
		log:close()
	end

	vim.g.gpt_jobid = vim.fn.jobstart(command, {
		stdout_buffered = false,
		on_exit = on_exit,
		on_stdout = function(_, data, _)
			for _, line in ipairs(data) do
				if line ~= "" then
					-- Strip token to get down to the JSON
					line = line:gsub("^data: ", "")
					if line == "" then
						break
					end
					local json = vim.fn.json_decode(line)
					local chunk = json.choices[1].delta.content

					if chunk ~= nil then
						if trim_leading then
							chunk = chunk:gsub("^%s+", "")
							if chunk ~= "" then
								trim_leading = false
							end
						end
						cb(chunk)
					end
				end
			end
		end,
	})
end

local function get_visual_selection()
	vim.cmd('noau normal! "vy"')
	vim.cmd('noau normal! gv')
	return vim.fn.getreg('v')
end

local function send_keys(keys)
	vim.api.nvim_feedkeys(
		vim.api.nvim_replace_termcodes(keys, true, false, true),
		'm', true
	)
end

local function create_response_writer(opts)
	local line_start = opts.line_no or vim.fn.line(".")
	local bufnum = vim.api.nvim_get_current_buf()
	local nsnum = vim.api.nvim_create_namespace("gpt")
	local extmarkid = vim.api.nvim_buf_set_extmark(bufnum, nsnum, line_start, 0, {})

	local response = ""
	return function(chunk)
		-- Delete the currently written response
		local num_lines = #(vim.split(response, "\n", {}))
		vim.api.nvim_buf_set_lines(
			bufnum, line_start, line_start + num_lines,
			false, {}
		)

		-- Update the line start to wherever the extmark is now
		line_start = vim.api.nvim_buf_get_extmark_by_id(bufnum, nsnum, extmarkid, {})[1]

		-- Write out the latest
		response = response .. chunk
		vim.api.nvim_buf_set_lines(
			bufnum, line_start, line_start,
			false, vim.split(response, "\n", {})
		)

		vim.cmd('undojoin')
	end
end


--[[
In visual mode given some selected text, ask the user how they
would like it to be rewritten. Then rewrite it that way.
]]
--
M.replace = function()
	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "v" and mode ~= "V" then
		print("Please select some text")
		return
	end

	local text = get_visual_selection()

	local prompt = "Rewrite this text "
	prompt = prompt .. vim.fn.input("[Prompt]: " .. prompt)
	prompt = prompt .. ": \n\n" .. text .. "\n\nRewrite:"

	send_keys("d")

	if mode == 'V' then
		send_keys("O")
	end

	M.stream(prompt, {
		trim_leading = true,
		on_chunk = function(chunk)
			chunk = vim.split(chunk, "\n", {})
			vim.api.nvim_put(chunk, "c", mode == 'V', true)
			vim.cmd('undojoin')
		end
	})
end

--[[
Ask the user for a prompt and insert the response where the cursor
is currently positioned.
]]
--
M.prompt = function()
	local input = vim.fn.input({
		prompt = "[Prompt]: ",
		cancelreturn = "__CANCEL__"
	})

	if input == "__CANCEL__" then
		return
	end

	send_keys("<esc>")
	M.stream(input, {
		trim_leading = true,
		on_chunk = create_response_writer()
	})
end

--[[
Take the current visual selection as the prompt to chatGPT.
Insert the response one line below the current selection.
]]
--
M.visual_prompt = function()
	local mode = vim.api.nvim_get_mode().mode
	local text = get_visual_selection()

	local prompt = ""
	local input = vim.fn.input({
		prompt = "[Prompt]: " .. prompt,
		cancelreturn = "__CANCEL__"
	})

	if input == "__CANCEL__" then
		return
	end

	prompt = prompt .. input
	prompt = prompt .. "\n\n ===== \n\n" .. text .. "\n\n ===== \n\n"

	send_keys("<esc>")

	if mode == 'V' then
		send_keys("o<CR><esc>")
	end

	M.stream(prompt, {
		trim_leading = true,
		on_chunk = create_response_writer()
	})

	send_keys("<esc>")
end

M.cancel = function()
	vim.fn.jobstop(vim.g.gpt_jobid)
end

local function parse_frontmatter(chatlog)
	-- Trim leading whitespace and newlines
	chatlog = chatlog:gsub("^%s+", "")

	-- Check if first line is just "---"
	if chatlog:sub(1, 3) ~= "---" then
		return {}, chatlog
	end

	-- Find the end of the frontmatter
	local frontmatter_end = chatlog:find("---", 4, true)
	if frontmatter_end == nil then
		return {}, chatlog
	end

	-- Parse the frontmatter
	local yaml_string = chatlog:sub(4, frontmatter_end - 1)
	local rest = chatlog:sub(frontmatter_end + 4)

	-- use `yq` to convert yaml to json
	local json_string = vim.fn.system("yq -j", yaml_string)
	local frontmatter = vim.fn.json_decode(json_string)

	if frontmatter == nil then
		return {}, chatlog
	end

	return frontmatter, rest
end

local function parse_chatlog(chatlog)
	local metadata = {}
	metadata, chatlog = parse_frontmatter(chatlog)

	local messages = {}
	local currentRole = ""
	local currentContent = ""

	if metadata["prompt"] ~= nil then
		table.insert(messages, { role = "system", content = metadata["prompt"] })
	end

	-- use gmatch to find all ">>> User:" and "🤖 GPT:" patterns
	for line in chatlog:gmatch("[^\r\n]+") do
		if line:sub(1, 4) == ">>> " then -- start of a user message
			if currentRole ~= "" then -- append previous message to list
				table.insert(messages, { role = currentRole, content = currentContent })
				currentRole = "" -- reset current role
				currentContent = "" -- reset current content
			end
			currentRole = "user"
			currentContent = line:sub(5):gsub("^%s*", "") -- remove ">>> " and any leading spaces from user message
		elseif line:find("^🤖 GPT: ") then -- start of a bot message
			if currentRole ~= "" then -- append previous message to list
				table.insert(messages, { role = currentRole, content = currentContent })
				currentRole = "" -- reset current role
				currentContent = "" -- reset current content
			end
			currentRole = "assistant"
			currentContent = line:sub(9):gsub("^%s*", "") -- remove "🤖 GPT: " and any leading spaces from bot message
		else -- continuation of previous message
			currentContent = currentContent .. "\n" .. line
		end
	end

	-- append last message to
	if currentRole ~= "" then
		table.insert(messages, { role = currentRole, content = currentContent })
	end

	return messages, metadata
end

local function setup_chatwindow(scratchpad_file)
	-- Find the last non-empty line in the buffer
	local function last_nonempty_line(buf)
		local line_count = vim.api.nvim_buf_line_count(buf)
		for i = line_count, 1, -1 do
			local line_text = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
			if #line_text > 0 then
				return i
			end
		end
		return 1
	end

	-- Trim all the empty whitespace at the end of the file
	local function trim_trailing_whitespace(buf)
		local line_count = vim.api.nvim_buf_line_count(buf)
		local last_line = last_nonempty_line(buf)
		if last_line < line_count then
			vim.api.nvim_buf_set_lines(buf, last_line, line_count, false, {})
		end
	end

	-- Check if the scratchpad file is already open in a buffer
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(bufnr) == scratchpad_file then
			-- The file is open, find the window and focus it
			for _, winid in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(winid) == bufnr then
					vim.api.nvim_set_current_win(winid)
					return
				end
			end
		end
	end

	-- The file is not open, create a new scratchpad buffer backed by the file
	vim.cmd("e " .. scratchpad_file)
	vim.cmd [[ :set ft=markdown ]]
	vim.cmd [[ :autocmd TextChanged,TextChangedI <buffer> silent write ]]
	vim.cmd [[ :set noswapfile ]]

	vim.keymap.set('n', '<C-g><CR>', function()
		-- get all the text in the buffer
		local text = table.concat(
			vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"
		)
		-- move cursor to a newline at the end of the file
		local last_line = last_nonempty_line(0)
		vim.api.nvim_buf_set_lines(0, last_line, last_line, false, { '', '🤖 GPT: ', '', '', '' })
		vim.api.nvim_win_set_cursor(0, { last_line + 4, 0 })
		local messages, metadata = parse_chatlog(text)
		M.stream(messages, {
			model = metadata["model"] or "gpt-4",
			trim_leading = true,
			on_chunk = create_response_writer({ line_no = last_line + 3 }),
			on_exit = function()
				trim_trailing_whitespace(0)
				local last_line = last_nonempty_line(0)
				vim.api.nvim_buf_set_lines(0, last_line, last_line, false, { '', '>>> ' })
				vim.api.nvim_win_set_cursor(0, { last_line + 2, 5 })
			end
		})
	end, {
		buffer = true,
		silent = false,
		noremap = true,
		desc = "[G]pt Respond"
	})

	vim.keymap.set('n', '<C-g>n', M.new_chat, {
		buffer = true,
		silent = false,
		noremap = true,
		desc = "[G]pt [N]ew Chat"
	})

	--
	-- Chat Picker code
	--
	local telescope = require("telescope.builtin")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local finders = require("telescope.finders")
	local sorters = require("telescope.sorters")

	local function fetch_md_files_with_titles()
		local command = "rg -m 1 -g '*.md' --no-heading --color=never '^title: (.+)$' ~/chat-logs | sort -r"
		local handle = assert(io.popen(command, 'r'))
		local output = assert(handle:read('*a'))
		handle:close()
		local md_files = {}
		local titles = {}

		for line in string.gmatch(output, "(.-)\n") do
			local path, title = string.match(line, "(.-):title: (.+)")
			table.insert(md_files, path)
			titles[path] = title
		end
		return md_files, titles
	end

	local function chat_picker(opts)
		local chat_logs, titles = fetch_md_files_with_titles()

		telescope.find_files({
			prompt_title = "Select Chat Log",
			cwd = "~/chat-logs",
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					setup_chatwindow(selection.value)
				end)
				return true
			end,
			finder = finders.new_table({
				results = chat_logs,
				entry_maker = function(filename)
					local shortfname = string.match(filename, ".*/(.*)")
					local date = string.match(shortfname, "%d%d%d%d%-%d%d%-%d%d%-%d%d%-%d%d")

					-- Extract the date from the filename, format it like 2023-03-02 12:15PM
					local year, month, day, hour, minute = string.match(date,
						"(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")
					local am = "AM"
					if tonumber(hour) > 12 then am = "PM" end
					hour = string.format("%02d", tonumber(hour) % 12)
					local date = string.format("%s-%s-%s %s:%s %s", year, month, day, hour, minute, am)

					local display = date
					local title = titles[filename]
					if title then
						display = "(" .. display .. ") " .. title
					end
					return {
						display = display,
						ordinal = display,
						value = filename,
					}
				end,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
		})
	end

	vim.keymap.set('n', '<C-p>', function()
		chat_picker()
	end, {
		buffer = true,
		silent = false,
		noremap = true,
		desc = "Find Chat Log"
	})
end

M.new_chat = function()
	local date = os.date("%Y-%m-%d-%H-%M-%S")
	local new_file = "~/chat-logs/" .. date .. ".chat.md"
	new_file = vim.fn.expand(new_file)

	local scratchpad_file = "~/chat-logs/latest"
	scratchpad_file = vim.fn.expand(scratchpad_file)
	vim.fn.system("touch " .. new_file)
	vim.fn.system("echo -e '---\ntitle: Untitled\nmodel: gpt-4\n---\n\n>>>' > " .. new_file)
	vim.fn.system("ln -sf " .. new_file .. " " .. scratchpad_file)

	setup_chatwindow(new_file)
end

M.open_chatwindow = function()
	local scratchpad_file = "~/chat-logs/latest"
	scratchpad_file = vim.fn.expand(scratchpad_file)

	-- If the file doesn't exist, create a new one with the current date and symlink it
	if not vim.loop.fs_access(scratchpad_file, "R") then
		local date = os.date("%Y-%m-%d-%H-%M-%S")
		local new_file = "~/chat-logs/" .. date .. ".chat.md"
		new_file = vim.fn.expand(new_file)
		vim.fn.system("touch " .. new_file)
		vim.fn.system("ln -sf " .. new_file .. " " .. scratchpad_file)
	end

	-- Resolve symlink
	scratchpad_file = vim.fn.system("readlink " .. scratchpad_file)

	setup_chatwindow(scratchpad_file)
end


return M
