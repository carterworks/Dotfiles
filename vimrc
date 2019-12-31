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

" Speeddating - for using CTRL-A/CTRL-X to increment dates, times, etc.
" Required for Org-mode
" https://github.com/tpope/vim-speeddating
Plug 'tpope/vim-speeddating'

" SyntaxRange - defining a different filetype syntax on regions of a buffer
" https://github.com/vim-scripts/SyntaxRange
Plug 'vim-scripts/SyntaxRange'

" Org-mode support for vim
" https://github.com/jceb/vim-orgmode
Plug 'jceb/vim-orgmode'

call plug#end()

" ==============================================================

" Turn on line numbers
set number

