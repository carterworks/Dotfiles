function manflags
    man "$argv" | awk '{$1=$1;print}' | grep "^\-"
end
