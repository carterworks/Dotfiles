function repeat_until_fail
    set -l count 0
    set -l start_time (date +%s)

    while eval $argv
        set count (math $count + 1)
        echo "Run $count completed successfully"
    end

    set -l end_time (date +%s)
    set -l duration (math $end_time - $start_time)

    echo "Command failed on run $count after $duration seconds"
    return $count
end
