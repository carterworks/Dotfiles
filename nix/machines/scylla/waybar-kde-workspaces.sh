current=$(qdbus org.kde.KWin /KWin currentDesktop 2>/dev/null || echo 1)
count=$(qdbus org.kde.KWin /VirtualDesktopManager count 2>/dev/null || echo 3)

case "$current" in
  '' | *[!0-9]*)
    current=1
    ;;
esac

case "$count" in
  '' | *[!0-9]*)
    count=3
    ;;
esac

if [ "$count" -lt 1 ]; then
  count=1
fi

if [ "$current" -lt 1 ]; then
  current=1
fi

if [ "$current" -gt "$count" ]; then
  current="$count"
fi

text=""
i=1
while [ "$i" -le "$count" ]; do
  if [ "$i" -eq "$current" ]; then
    text="${text}● "
  else
    text="${text}○ "
  fi
  i=$((i + 1))
done
text=$(printf '%s' "$text" | sed 's/ *$//')

printf '{"text":"%s","tooltip":"Desktop %s of %s"}' "$text" "$current" "$count"
