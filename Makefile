pb:
	  go get -u github.com/golang/protobuf/protoc-gen-go
		@echo "pb Start"
		cd configure && make pb
asset:
	mkdir assets
	cd assets;curl https://cdn.rawgit.com/v2ray/v2ray-core/e60de73c704d46d91633035e6b06184f7186a4e0/tools/release/config/geosite.dat > geosite.dat
	cd assets;curl https://cdn.rawgit.com/v2ray/v2ray-core/1777540e3d9eb7429c1ba72a93d8ef6c426bda13/release/config/geoip.dat > geoip.dat

shippedBinary:
	cd shippedBinarys; $(MAKE) shippedBinary

fetchDep:
    -go get  github.com/zhaoguomanong/AndroidLibV2ray
    go get github.com/zhaoguomanong/AndroidLibV2ray
	-cd $(GOPATH)/src/github.com/zhaoguomanong/AndroidLibV2ray/vendor/github.com/xiaokangwang/V2RayConfigureFileUtil;$(MAKE) all

	-cd $(GOPATH)/src/github.com/zhaoguomanong/AndroidLibV2ray/vendor/github.com/xiaokangwang/libV2RayAuxiliaryURL; $(MAKE) all
	-cd $(GOPATH)/src/github.com/zhaoguomanong/AndroidLibV2ray/vendor/github.com/xiaokangwang/waVingOcean/configure; $(MAKE) pb


ANDROID_HOME=$(HOME)/android-sdk-linux
export ANDROID_HOME
PATH:=$(PATH):$(GOPATH)/bin
export PATH
downloadGoMobile:
	go get golang.org/x/mobile/cmd/...
	sudo apt-get install -qq libstdc++6:i386 lib32z1 expect
	cd ~ ;curl -L https://gist.githubusercontent.com/xiaokangwang/4a0f19476d86213ef6544aa45b3d2808/raw/ff5eb88663065d7159d6272f7b2eea0bd8b7425a/ubuntu-cli-install-android-sdk.sh | sudo bash - > /dev/null
	ls ~
	ls ~/android-sdk-linux/
	gomobile init;gomobile bind -v  -tags json github.com/zhaoguomanong/AndroidLibV2ray

buildVGO:

BuildMobile:
	@echo Stub

all: asset pb shippedBinary fetchDep
	@echo DONE
