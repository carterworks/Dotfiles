function ctx -d "Print a file or stdin, wrapped in xml tags."
  argparse 'n/no_copy' 't/tag=' -- $argv
  or return
  set _flag_tag (set -q _flag_tag && echo $_flag_tag || echo "file")
  set _flag_t $_flag_tag

  echo "_flag_tag: $_flag_tag"
  echo "_flag_t: $_flag_t"
  echo "_flag_no_copy: $_flag_no_copy"
  echo "argv: $argv"
  
  for path in $argv
    set --append output "<$_flag_tag path=\"$path\">"
    set --append output (command cat -- $path)
    set --append output "</$_flag_tag>"
  end

  printf "%s\n" $output

  if test -z "$_flag_no_copy"
    set --local copy_cmd (which pbcopy || which wl-copy || which xsel || which clip.exe)
    if test -z "$copy_cmd"
      echo "ctx: no copy command found" >&2
      return 1
    end
    printf "%s\n" $output | $copy_cmd
  end
end
