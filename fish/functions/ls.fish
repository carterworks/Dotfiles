# Defined in /Users/cmcbride/.config/fish/functions/ls.fish @ line 1
function ls
	if command -s lsd
		lsd -F --group-dirs=first $argv
	else
		/bin/ls $argv
	end
end
