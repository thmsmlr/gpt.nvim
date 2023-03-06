<p align="center">
  <h3 align="center">gpt.nvim</h3>
</p>
<p align="center">
  <img src="assets/typing.svg" alt="Typing SVG" />
</p>

<hr/>

Installation is easy. 
With your favorite package manager,

```lua
{
  "thmsmlr/gpt.nvim",
  config = function()
    require('gpt').setup({
      api_key = os.getenv("OPENAI_API_KEY")
    })

    opts = { silent = true, noremap = true }
    vim.keymap.set('v', '<C-g>r', require('gpt').replace, opts)
    vim.keymap.set('v', '<C-g>p', require('gpt').visual_prompt, opts)
    vim.keymap.set('i', '<C-g>p', require('gpt').prompt, opts)
  end
}
```

You can get an API key via the [OpenAI user settings page](https://platform.openai.com/account/api-keys)

## Usage

There are three ways to use the plugin:

1. In Visual Mode, select text and use it as the prompt with `<C-g>p`.
ChatGPT will respond 2 lines below the selection.

https://user-images.githubusercontent.com/167206/223190592-bbcfe5b5-f6be-48c2-aa30-8a1fee005cf6.mp4

1. In Insert Mode, `<C-g>p` will ask you for a prompt.
ChatGPT will insert it's response into the buffer at the cursor's location.

https://user-images.githubusercontent.com/167206/223190833-282b281f-033c-485d-8c93-786dd0b0e075.mp4

3. In Visual Mode, select text and rewrite it using `<C-g>r`.
It'll ask you for the prompt to customize how GPT rewrites the selection.

https://user-images.githubusercontent.com/167206/223190891-d05676bf-cfff-474f-821b-103fe6bbf435.mp4


