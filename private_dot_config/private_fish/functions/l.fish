function l
	if command -qs lsd
		lsd -F --group-dirs first $argv
	else
		/bin/ls -CF $argv
	end
end
