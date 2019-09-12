function lla
	if command -s lsd
		lsd -la $argv
	else
		/bin/ls -lA $argv
	end
end
