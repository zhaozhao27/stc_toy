pull:
	git pull
	git submodule sync --recursive
	git submodule update --recursive --init