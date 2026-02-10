.PHONY: build
build:
	sh build.sh

.PHONY: release
release:
	sh build.sh release

.PHONY: run
run: build
	killall Mactokio 2>/dev/null || true
	sleep 0.5
	open build/Mactokio.app

.PHONY: clean
clean:
	rm -rf build .build
