function lla
	if command -qs lsd
		lsd -la $argv
	else
		/bin/ls -lA $argv
	end
end
