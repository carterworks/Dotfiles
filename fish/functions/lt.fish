function lt
	if command -s lsd
		lsd --tree $argv
	else
		tree $argv
	end
end
