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
M.stream = function(prompt, opts)
	if vim.g.gpt_api_key == nil then
		print("Please provide an OpenAI API key require('gpt').setup({})")
		return
	end

	local payload = {
		stream = true,
		model = "gpt-3.5-turbo",
		messages = { { role = "user", content = prompt } },
	}

	local identity = function(chunk)
		return chunk
	end

	opts = opts or {}
	local cb = opts.on_chunk or identity
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

	vim.fn.jobstart(command, {
		stdout_buffered = false,
		on_stdout = function(_, data, _)
			for _, line in ipairs(data) do
				if line ~= "" then
					-- Strip token to get down to the JSON
					line = line:gsub("^data: ", "")
					if line == "[DONE]" then
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

local function create_response_writer()
	local bufnum = vim.api.nvim_get_current_buf()
	local nsnum = vim.api.nvim_create_namespace("gpt")
	local line_start = vim.fn.line(".")
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

return M
