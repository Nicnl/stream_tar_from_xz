.PHONY: build dist test

# Si SEMVER est défini, on enlève le 'v', sinon on utilise '0.0.0'
SEMVER := $(if $(SEMVER),$(SEMVER:v%=%),0.0.0-dev)
TEMPLATE := nfpm-template.yaml

GIT_TAG := $(shell git describe --tags --exact-match 2>/dev/null || echo 'N/A')
GIT_COMMIT := $(if $(GIT_COMMIT),$(GIT_COMMIT),$(shell git rev-parse --short HEAD || echo 'N/A'))
BUILD_TIMESTAMP := $(shell date -u '+%Y-%m-%d %H:%M:%S')

LDFLAGS := -s -w \
		-X 'stream_tar_from_xz/version.gitHash=$(GIT_COMMIT)' \
		-X 'stream_tar_from_xz/version.gitTag=$(GIT_TAG)' \
		-X 'stream_tar_from_xz/version.buildTimestamp=$(BUILD_TIMESTAMP)'

build:
	go build -v -o build/stream_tar_from_xz main.go
	chmod +x build/stream_tar_from_xz

build-linux-amd64:
	@echo "Building for linux/amd64"
	GOOS=linux GOARCH=amd64 go build -v -o build/linux/amd64/stream_tar_from_xz -ldflags="$(LDFLAGS)" main.go

	chmod +x build/linux/amd64/stream_tar_from_xz
	@echo "Build done"

build-linux-arm64:
	@echo "Building for linux/arm64"
	GOOS=linux GOARCH=arm64 go build -v -o build/linux/arm64/stream_tar_from_xz -ldflags="$(LDFLAGS)" main.go
	chmod +x build/linux/arm64/stream_tar_from_xz
	@echo "Build done"

build-windows-amd64:
	@echo "Building for windows/amd64"
	GOOS=windows GOARCH=amd64 go build -v -o build/windows/amd64/stream_tar_from_xz.exe -ldflags="$(LDFLAGS)" main.go
	chmod +x build/windows/amd64/stream_tar_from_xz.exe
	@echo "Build done"

build-windows-arm64:
	@echo "Building for windows/arm64"
	GOOS=windows GOARCH=arm64 go build -v -o build/windows/arm64/stream_tar_from_xz.exe -ldflags="$(LDFLAGS)" main.go
	chmod +x build/windows/arm64/stream_tar_from_xz.exe
	@echo "Build done"

build-darwin-amd64:
	@echo "Building for darwin/amd64"
	GOOS=darwin GOARCH=amd64 go build -v -o build/darwin/amd64/stream_tar_from_xz -ldflags="$(LDFLAGS)" main.go
	chmod +x build/darwin/amd64/stream_tar_from_xz
	@echo "Build done"

build-darwin-arm64:
	@echo "Building for darwin/arm64"
	GOOS=darwin GOARCH=arm64 go build -v -o build/darwin/arm64/stream_tar_from_xz -ldflags="$(LDFLAGS)" main.go
	chmod +x build/darwin/arm64/stream_tar_from_xz
	@echo "Build done"

all: build-linux-amd64 build-linux-arm64 build-windows-amd64 build-windows-arm64 build-darwin-amd64 build-darwin-arm64

test:
	go test -v ./...

clean:
	rm -rf build
	rm -rf dist

install:
	cp build/stream_tar_from_xz /usr/bin/stream_tar_from_xz

uninstall:
	rm -f /usr/local/bin/stream_tar_from_xz

changelog:
	chglog init

package-amd64-linux:
	@echo "Packing for linux/amd64"
	mkdir -p dist

	@echo preparing nfpm template
	sed -e 's/$${GOARCH}/amd64/g' \
	    -e 's/$${SEMVER}/$(SEMVER)/g' $(TEMPLATE) > dist/nfpm-amd64.yaml

	GOARCH=amd64 nfpm pkg -f dist/nfpm-amd64.yaml --packager deb --target dist/stream_tar_from_xz-v$(SEMVER).amd64.deb
	GOARCH=amd64 nfpm pkg -f dist/nfpm-amd64.yaml --packager rpm --target dist/stream_tar_from_xz-v$(SEMVER).amd64.rpm
	GOARCH=amd64 nfpm pkg -f dist/nfpm-amd64.yaml --packager ipk --target dist/stream_tar_from_xz-v$(SEMVER).amd64.ipk
	GOARCH=amd64 nfpm pkg -f dist/nfpm-amd64.yaml --packager archlinux --target dist/stream_tar_from_xz-v$(SEMVER).amd64.tar.zst

	@rm dist/nfpm-amd64.yaml || true
	@echo "Pack done"

package-arm64-linux:
	@echo "Packing for linux/arm64"
	mkdir -p dist

	@echo preparing nfpm template
	@sed -e 's/$${GOARCH}/arm64/g' \
	    -e 's/$${SEMVER}/$(SEMVER)/g' $(TEMPLATE) > dist/nfpm-arm64.yaml

	GOARCH=arm64 nfpm pkg -f dist/nfpm-arm64.yaml --packager deb --target dist/stream_tar_from_xz-v$(SEMVER).arm64.deb
	GOARCH=arm64 nfpm pkg -f dist/nfpm-arm64.yaml --packager rpm --target dist/stream_tar_from_xz-v$(SEMVER).arm64.rpm
	GOARCH=arm64 nfpm pkg -f dist/nfpm-arm64.yaml --packager ipk --target dist/stream_tar_from_xz-v$(SEMVER).arm64.ipk
	GOARCH=arm64 nfpm pkg -f dist/nfpm-arm64.yaml --packager archlinux --target dist/stream_tar_from_xz-v$(SEMVER).arm64.tar.zst

	@rm dist/nfpm-arm64.yaml || true
	@echo "Pack done"

package: package-amd64-linux package-arm64-linux


show-date:
	@echo "LDFLAGS: $(LDFLAGS)"
	@echo "Current UTC time: $$(date -u '+%Y-%m-%d %H:%M:%S')"
