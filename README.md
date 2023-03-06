<h1 align="center">gpt.nvim</h1>
<img align="center" src="https://readme-typing-svg.demolab.com?font=Fira+Code&duration=2500&pause=1000&color=969696&center=true&width=435&lines=Twitter's+Favorite+LLM+in+Neovim;Looking+for+an+AI-ffordable+option;AI-caramba;Robo-cop+out" alt="Typing SVG" />

Twitter's favorite LLM in your VIM.

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

1. In Visual Mode, select text and rewrite it using `<C-g>r`.
It'll ask you for the prompt to customize how GPT rewrites the selection.

[Video1]

2. In Visual Mode, select text and use it as the prompt with `<C-g>p`.
ChatGPT will respond 2 lines below the selection.

[Video2]

3. In Normal Mode, `<C-g>p` will ask you for a prompt.
ChatGPT will insert it's response into the buffer at the cursor's location.

[Video3]

