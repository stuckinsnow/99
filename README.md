### TODO
- Finish Context -> RequestContext refactor
  * which should consider logger
- Fill in function tests should be reshaped.
 * there should be one test to validate basic behavior. no more programmatic tests
 * there should be a range test for replacing text
 * fill in function update code should be redone, its much simplier now
- implement function
 * Point should get a insert code at function? ... maybe?
   * perhaps Mark should get that, could be nice.
- if the function's definition in typescript is mutli-line
 * will have to get more clever with how i do function start, either body if body is available or function def + 1 line

```typescript
function display_text(
  game_state: GameState,
  text: string,
  x: number,
  y: number,
): void {
  const ctx = game_state.canvas.getContext("2d");
  assert(ctx, "cannot get game context");
  ctx.fillStyle = "white";
  ctx.fillText(text, x, y);
}
```

Then the virtual text will be displayed one line below "function" instead of first line in body
## The AI Agent That Neovim Deserves
This is an example repo where i want to test what i think the ideal AI workflow
is for people who dont have "skill issues."  This is meant to streamline the requests to AI and limit them it restricted areas.  For more general requests, please just use opencode.  Dont use neovim.

## How to use
Add the following configuration to your neovim startuource /home/theprimeagen/.tmux-sessionizer

I make the assumption you are using Lazy
```lua
	{
		"ThePrimeagen/99",
		config = function()
			local _99 = require("99")

            -- For logging that is to a file if you wish to trace through requests
            -- for reporting bugs, i would not rely on this, but instead the provided
            -- logging mechanisms within 99.  This is for more debugging purposes
            local cwd = vim.uv.cwd()
            local basename = vim.fs.basename(cwd)
			_99.setup({
				logger = {
					level = _99.DEBUG,
					path = "/tmp/" .. basename .. ".99.debug",
					print_on_error = true,
				},
				md_files = {
					"AGENT.md",
				},
			})

            -- Create your own short cuts for the different types of actions
			vim.keymap.set("n", "<leader>9f", function()
				_99.fill_in_function()
			end)
			vim.keymap.set("n", "<leader>9i", function()
				_99.implement_fn()
			end)

            -- take extra note that i have visual selection only in v mode
            -- technically whatever your last visual selection is, will be used
            -- so i have this set to visual mode so i dont screw up and use an
            -- old visual selection
            --
            -- likely ill add a mode check and assert on required visual mode
            -- so just prepare for it now
			vim.keymap.set("v", "<leader>9v", function()
				_99.visual_selection()
			end)
		end,
	},
```

## Reporting a bug
To report a bug, please provide the full running debug logs.  This may require
a bit of back and forth.

Please do not request features.  We will hold a public discussion on Twitch about
features, which will be a much better jumping point then a bunch of requests that i have to close down.  If you do make a feature request ill just shut it down instantly.

### The Great Twitch Discussion
I will conduct a stream on Jan 30 at 11am The Lords Time (Montana Time/Mountain Time (same thing))
we will do an extensive deep dive on 99 and what we think is good and bad.
