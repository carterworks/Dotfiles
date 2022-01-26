set nocompatible

" ==============================================================
" vim-plug installation
" https://github.com/junegunn/vim-plug/wiki/tips#automatic-installation

if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" ==============================================================
" Start list of plugins
call plug#begin('~/.vim/plugged')

" Sensible Vim - defaults 
" https://github.com/tpope/vim-sensible
Plug 'tpope/vim-sensible'

" Universal Text Linking - for making hyperlinks work
" https://github.com/vim-scripts/utl.vim
Plug 'vim-scripts/utl.vim'

call plug#end()

" ==============================================================

" Turn on line numbers
set number

" Disable automatic text wrapping
autocmd VimEnter * set textwidth=0

" Copy to the MacOS clipboard
set clipboard=unnamed
