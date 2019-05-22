function push-org
	rclone sync /Users/cmcbride/Org/ DropboxOrg:/Org/ -P $argv
end
