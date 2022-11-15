function lt
	if command -qs lsd
		lsd --tree $argv
	else
		tree $argv
	end
end
