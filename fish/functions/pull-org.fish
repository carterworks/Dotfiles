function pull-org
	rclone sync DropboxOrg:/Org/ /Users/cmcbride/Org/ -P $argv
end
