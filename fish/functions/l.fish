function l
	if command -s lsd
		lsd -F --group-dirs first $argv
	else
		/bin/ls -CF $argv
	end
end
