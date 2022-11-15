function explain
    set cols (tput cols)
    curl -Gs "https://www.mankier.com/api/v2/explain/?cols=$cols" --data-urlencode "q=$argv"
end
