APP_NAME   = OnTop
BUILD_DIR  = .build/release
APP_BUNDLE = $(APP_NAME).app
CONTENTS   = $(APP_BUNDLE)/Contents

.PHONY: all build app universal run sensors power icon install uninstall clean

all: app

## Compile the release binary with SwiftPM.
build:
	swift build -c release

## Regenerate the app icon (Resources/AppIcon.icns) from Tools/make_icon.swift.
icon:
	mkdir -p build
	swift Tools/make_icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
	@echo "Wrote Resources/AppIcon.icns"

## Assemble OnTop.app around the binary + Info.plist + icon.
app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(CONTENTS)/MacOS
	mkdir -p $(CONTENTS)/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(CONTENTS)/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	cp Resources/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns
	@echo "Built ./$(APP_BUNDLE)"

## Build a universal (arm64 + x86_64) app that runs on any Mac.
universal:
	swift build -c release --arch arm64 --arch x86_64
	@BIN=$$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path); \
	rm -rf $(APP_BUNDLE); \
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources; \
	cp $$BIN/$(APP_NAME) $(CONTENTS)/MacOS/$(APP_NAME); \
	cp Resources/Info.plist $(CONTENTS)/Info.plist; \
	cp Resources/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns; \
	echo "Built universal ./$(APP_BUNDLE) ($$(lipo -archs $(CONTENTS)/MacOS/$(APP_NAME)))"

## Launch the assembled app.
run: app
	open $(APP_BUNDLE)

## Print the SMC temperature sensors found on this machine.
sensors: build
	$(BUILD_DIR)/$(APP_NAME) --list-sensors

## Print the SMC power (watt) sensors (use to port PowerReader to a new model).
power: build
	$(BUILD_DIR)/$(APP_NAME) --list-power

## Copy the app into /Applications.
install: app
	rm -rf /Applications/$(APP_BUNDLE)
	cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

uninstall:
	rm -rf /Applications/$(APP_BUNDLE)

clean:
	rm -rf .build $(APP_BUNDLE)
