function killp --description "Select processes to kill using fzf"
    set -l fzf_args \
        --multi \
        --preview 'ps -p {1} -o pid,ppid,user,comm,args,pcpu,pmem,etime,stat' \
        --preview-label='alt-p: toggle preview, alt-j/k: scroll, tab: multi-select, enter: kill selected' \
        --preview-label-pos='bottom' \
        --preview-window 'down:20%:wrap' \
        --bind 'alt-p:toggle-preview' \
        --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up' \
        --bind 'alt-k:preview-up,alt-j:preview-down' \
        --color 'pointer:red,marker:red' \
        --header 'Select processes to kill (WARNING: This will terminate selected processes)'

    # Get process list sorted by CPU usage, PID as first column
    set -l selected_processes (ps -eo pid,comm,user,pcpu,pmem,etime,args | \
        awk 'NR==1 {printf "%-8s %-20s %-12s %5s %5s %10s %s\n", "PID", "COMMAND", "USER", "%CPU", "%MEM", "TIME", "ARGS"} 
             NR>1 {printf "%-8s %-20s %-12s %5s %5s %10s %s\n", $1, $2, $3, $4, $5, $6, substr($0, index($0, $7))}' | \
        tail -n +2 | \
        sort -k4 -nr | \
        fzf $fzf_args | \
        awk '{print $1}')

    if test -n "$selected_processes"
        echo "Selected PIDs to kill: $selected_processes"
        echo -n "Confirm killing these processes? [y/N] "
        read -l confirm
        
        if test "$confirm" = "y" -o "$confirm" = "Y"
            for pid in $selected_processes
                echo "Killing PID $pid..."
                kill $pid
            end
            echo "Done."
        else
            echo "Cancelled."
        end
    end
end