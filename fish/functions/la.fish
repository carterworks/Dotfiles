function la
	if command -qs lsd
		lsd -a $argv
	else
		/bin/ls -A $argv
	end
end
