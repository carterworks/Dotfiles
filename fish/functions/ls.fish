function ls --wraps='eza -F --group-directories-first' --description 'alias ls=eza -F --group-directories-first'
  if command -qs eza
    eza -F --group-directories-first $argv
  else
    /bin/ls $argv
  end      
end
