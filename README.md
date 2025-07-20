<div align="center">
  
# Spear

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

</div>

## Background

This plugin is heavily based (shy of being a fork really) on [Harpoon](https://github.com/ThePrimeagen/harpoon/blob/harpoon2).
The issue was that I wanted a way to have different file lists per project, and Harpoon did not allow me to do that.
So I made my own plugin! :)

## Installation
- Install using [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  'diego-velez/spear.nvim',
  dependencies = {'nvim-lua/plenary.nvim'},
  opts = {}
}
```

## Getting Started
```lua
{
  'diego-velez/spear.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    {
      '<leader>la',
      function()
        require('spear').add()
      end,
      desc = '[A]dd file to list',
    },
    {
      '<leader>lc',
      function()
        require('spear').create()
      end,
      desc = '[C]reate list',
    },
    {
      '<leader>lr',
      function()
        require('spear').rename()
      end,
      desc = '[R]ename list',
    },
    {
      '<leader>ls',
      function()
        require('spear').switch()
      end,
      desc = '[S]witch list',
    },
    {
      '<A-n>', -- I use Colemak DH btw :)
      function()
        require('spear').select(1)
      end,
    },
    {
      '<A-e>',
      function()
        require('spear').select(2)
      end,
    },
    {
      '<A-i>',
      function()
        require('spear').select(3)
      end,
    },
    {
      '<A-o>',
      function()
        require('spear').select(4)
      end,
    },
  },
  opts = {},
}
```
