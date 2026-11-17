APP_NAME   = OnTop
BUILD_DIR  = .build/release
APP_BUNDLE = $(APP_NAME).app
CONTENTS   = $(APP_BUNDLE)/Contents

# Developer ID signing / notarization. Override on the command line, e.g.
#   make notarize SIGN_ID="Developer ID Application: Jane Doe (ABCDE12345)"
# SIGN_ID may be a partial name if exactly one matching certificate exists.
SIGN_ID        ?= Developer ID Application
NOTARY_PROFILE ?= ontop-notary

.PHONY: all build app universal run sensors power icon sign notarize install uninstall clean

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

## Code-sign the universal app with your Developer ID + hardened runtime.
sign: universal
	codesign --force --timestamp --options runtime --sign "$(SIGN_ID)" $(APP_BUNDLE)
	codesign --verify --strict --verbose=2 $(APP_BUNDLE)
	@echo "Signed $(APP_BUNDLE) with: $(SIGN_ID)"

## Notarize + staple. Needs: notarytool store-credentials "$(NOTARY_PROFILE)" ...
notarize: sign
	ditto -c -k --keepParent $(APP_BUNDLE) $(APP_NAME).zip
	xcrun notarytool submit $(APP_NAME).zip --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(APP_BUNDLE)
	spctl --assess --verbose=4 $(APP_BUNDLE) || true
	@echo "Notarized + stapled $(APP_BUNDLE) — distribute this bundle."

## Copy the app into /Applications.
install: app
	rm -rf /Applications/$(APP_BUNDLE)
	cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

uninstall:
	rm -rf /Applications/$(APP_BUNDLE)

clean:
	rm -rf .build $(APP_BUNDLE)
