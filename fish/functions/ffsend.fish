function ffsend
	docker run --rm -it -v (pwd):/data timvisee/ffsend $argv
end
