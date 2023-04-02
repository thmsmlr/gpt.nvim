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
    vim.keymap.set('v', '<C-g>r', require('gpt').replace, {
      silent = true,
      noremap = true,
      desc = "[G]pt [R]ewrite"
    })
    vim.keymap.set('v', '<C-g>p', require('gpt').visual_prompt, {
      silent = false,
      noremap = true,
      desc = "[G]pt [P]rompt"
    })
    vim.keymap.set('n', '<C-g>p', require('gpt').prompt, {
      silent = true,
      noremap = true,
      desc = "[G]pt [P]rompt"
    })
    vim.keymap.set('n', '<C-g>c', require('gpt').cancel, {
      silent = true,
      noremap = true,
      desc = "[G]pt [C]ancel"
    })
    vim.keymap.set('i', '<C-g>p', require('gpt').prompt, {
      silent = true,
      noremap = true,
      desc = "[G]pt [P]rompt"
    })
  end
}
```

You can get an API key via the [OpenAI user settings page](https://platform.openai.com/account/api-keys)

It also requires that you have `yq` installed,

```
$ pacman -S yq
```

## Usage

There are three ways to use the plugin:

1. In Visual Mode, select text and use it as the prompt with `<C-g>p`.
ChatGPT will respond 2 lines below the selection.

https://user-images.githubusercontent.com/167206/223229448-821fd6f5-745b-4c44-a9e0-4afd6238e018.mp4

2. In Insert Mode, `<C-g>p` will ask you for a prompt.
ChatGPT will insert it's response into the buffer at the cursor's location.

https://user-images.githubusercontent.com/167206/223229643-940f2fa3-57ad-4dfb-a254-0fcc27dda13f.mp4

3. In Visual Mode, select text and rewrite it using `<C-g>r`.
It'll ask you for the prompt to customize how GPT rewrites the selection.

https://user-images.githubusercontent.com/167206/223229656-1dcb9fad-5864-492f-9aeb-6e6ec6c584d7.mp4

