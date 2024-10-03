function gap --wraps='git add --all --patch' --description 'alias gap=git add --all --patch'
    git add -A --patch $argv
end
