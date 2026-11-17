APP_NAME   = OnTop
BUILD_DIR  = .build/release
APP_BUNDLE = $(APP_NAME).app
CONTENTS   = $(APP_BUNDLE)/Contents

.PHONY: all build app run sensors install uninstall clean

all: app

## Compile the release binary with SwiftPM.
build:
	swift build -c release

## Assemble OnTop.app around the binary + Info.plist.
app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(CONTENTS)/MacOS
	mkdir -p $(CONTENTS)/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(CONTENTS)/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	@echo "Built ./$(APP_BUNDLE)"

## Launch the assembled app.
run: app
	open $(APP_BUNDLE)

## Print the SMC temperature sensors found on this machine.
sensors: build
	$(BUILD_DIR)/$(APP_NAME) --list-sensors

## Copy the app into /Applications.
install: app
	rm -rf /Applications/$(APP_BUNDLE)
	cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

uninstall:
	rm -rf /Applications/$(APP_BUNDLE)

clean:
	rm -rf .build $(APP_BUNDLE)
