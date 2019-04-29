function nginx-kill
	sudo kill -QUIT ( cat /usr/local/var/run/nginx.pid )
end
