-- How to use lua for config: https://neovim.io/doc/user/lua-guide.html
-- List of configs: https://neovim.io/doc/user/options.html
-- #region kickstart.nvim
-- Setting pulled from https://github.com/nvim-lua/kickstart.nvim/
vim.opt.number = true
vim.opt.mouse = 'a'
-- Sync clipboard between OS and Neovim
--   Schedule the setting after `UiEnter` because it can increase
--   startup time.
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)
vim.opt.breakindent = true
-- Case-insensitive searching
vim.opt.breakindent = true
vim.opt.smartcase = true
-- Save undo history after close
vim.opt.undofile = true
-- Splits
vim.opt.splitright = true
vim.opt.splitbelow = true
-- Show whitespace characters
vim.opt.list = true
vim.opt.listchars = { 
  tab = '\\uffeb\\uffeb',
  lead = '·',
  trail = '·',
  nbsp = '␣'
}
-- Preview substituions, live
vim.opt.inccommand = 'split'
-- Show cursor line
vim.opt.cursorline = true
-- Minimal number of screen lines to keep above and below the cursor
vim.opt.scrolloff = 10
-- #endregion
-- #region kickstart-keybinds.nvim
-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

