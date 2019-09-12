function la
	if command -s lsd
		lsd -a $argv
	else
		/bin/ls -A $argv
	end
end
