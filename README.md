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

## Usage

There are three ways to use the plugin:

1. In Visual Mode, select text and use it as the prompt with `<C-g>p`.
ChatGPT will respond 2 lines below the selection.



https://user-images.githubusercontent.com/167206/223226836-2108a1c0-9a34-43cd-afa9-7cf2a351612e.mp4






1. In Insert Mode, `<C-g>p` will ask you for a prompt.
ChatGPT will insert it's response into the buffer at the cursor's location.



https://user-images.githubusercontent.com/167206/223226876-842103e9-5928-4599-9965-6b163d3fb07b.mp4



3. In Visual Mode, select text and rewrite it using `<C-g>r`.
It'll ask you for the prompt to customize how GPT rewrites the selection.



https://user-images.githubusercontent.com/167206/223226916-4858c39d-36ef-475f-87b7-25aed4a61ea8.mp4


