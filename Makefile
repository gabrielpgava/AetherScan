XCODEBUILD ?= xcodebuild
OPEN ?= open
PROJECT ?= AetherScan.xcodeproj
SCHEME ?= AetherScan
DESTINATION ?= platform=macOS
DERIVED_DATA ?= $(CURDIR)/build/DerivedData
CONFIGURATION ?= Debug
ICONSET ?= AetherScan/Assets.xcassets/AppIcon.appiconset

.PHONY: all build debug release run xcode icon clean help

all: build

build:
	$(XCODEBUILD) -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -destination "$(DESTINATION)" -derivedDataPath "$(DERIVED_DATA)" build

debug:
	$(MAKE) build CONFIGURATION=Debug

release:
	$(MAKE) build CONFIGURATION=Release

run: debug
	$(OPEN) "$(DERIVED_DATA)/Build/Products/Debug/AetherScan.app"

xcode:
	$(OPEN) "$(PROJECT)"

icon:
	swift Scripts/generate_app_icon.swift "$(ICONSET)/AppIcon-1024.png"
	sips -z 16 16 "$(ICONSET)/AppIcon-1024.png" --out "$(ICONSET)/AppIcon-16.png" >/dev/null
	sips -z 32 32 "$(ICONSET)/AppIcon-1024.png" --out "$(ICONSET)/AppIcon-16@2x.png" >/dev/null
	sips -z 32 32 "$(ICONSET)/AppIcon-1024.png" --out "$(ICONSET)/AppIcon-32.png" >/dev/null
	sips -z 64 64 "$(ICONSET)/AppIcon-1024.png" --out "$(ICONSET)/AppIcon-32@2x.png" >/dev/null
	sips -z 128 128 "$(ICONSET)/AppIcon-1024.png" --out "$(ICONSET)/AppIcon-128.png" >/dev/null
	sips -z 256 256 "$(ICONSET)/AppIcon-1024.png" --out "$(ICONSET)/AppIcon-128@2x.png" >/dev/null
	sips -z 256 256 "$(ICONSET)/AppIcon-1024.png" --out "$(ICONSET)/AppIcon-256.png" >/dev/null
	sips -z 512 512 "$(ICONSET)/AppIcon-1024.png" --out "$(ICONSET)/AppIcon-256@2x.png" >/dev/null
	sips -z 512 512 "$(ICONSET)/AppIcon-1024.png" --out "$(ICONSET)/AppIcon-512.png" >/dev/null

clean:
	$(XCODEBUILD) -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug -derivedDataPath "$(DERIVED_DATA)" clean
	$(XCODEBUILD) -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release -derivedDataPath "$(DERIVED_DATA)" clean

help:
	@printf '%s\n' \
	  'AetherScan build targets:' \
	  '  make / make build  Build Debug (default)' \
	  '  make debug         Build Debug' \
	  '  make release       Build Release' \
	  '  make run           Build Debug and open the app' \
	  '  make xcode         Open the Xcode project' \
	  '  make icon          Regenerate the app icon and Retina sizes' \
	  '  make clean         Clean Debug and Release products' \
	  '' \
	  'Override variables, e.g. make build CONFIGURATION=Release DESTINATION="platform=macOS,arch=arm64"'
