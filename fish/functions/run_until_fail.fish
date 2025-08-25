function run_until_fail
    set -l count 0
    set -l start_time (date +%s)

    while eval $argv
        set count (math $count + 1)
        # Print success message to stderr with styling
        set_color -o green >&2
        printf "Run %s completed successfully\n" $count >&2
        set_color normal >&2
    end

    set -l end_time (date +%s)
    set -l duration (math $end_time - $start_time)

    # Print failure message to stderr with styling
    set_color -o red >&2
    printf "Command failed on run %s after %s seconds\n" $count $duration >&2
    set_color normal >&2
    return $count
end
