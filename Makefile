.PHONY: generate build build-unsigned install run update clean test kill dev notarize staple dmg release

APP_NAME := Tidbits
BUILD_DIR := .derivedData/Build/Products/Release
APP_PATH := $(BUILD_DIR)/$(APP_NAME).app
DMG_DIR := .release
DMG_PATH := $(DMG_DIR)/$(APP_NAME).dmg

# Signing.xcconfig is gitignored — xcodebuild reads it directly via -xcconfig.
# The Makefile only extracts values needed by non-xcodebuild tools (codesign, notarytool).
SIGNING_XCCONFIG := $(wildcard Signing.xcconfig)
SIGNING_CERTIFICATE ?= $(shell grep '^SIGNING_CERTIFICATE' Signing.xcconfig 2>/dev/null | cut -d= -f2- | xargs)
NOTARIZE_PROFILE ?= $(shell grep '^NOTARIZE_PROFILE' Signing.xcconfig 2>/dev/null | cut -d= -f2- | xargs)

# Kill running Tidbits app (if any)
kill:
	@pkill -9 Tidbits 2>/dev/null || true
	@sleep 0.5

# Generate Xcode project from project.yml
generate:
	@xcodegen generate
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $$(MARKETING_VERSION)' Notes/Info.plist
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion $$(CURRENT_PROJECT_VERSION)' Notes/Info.plist

# Build the app (Release). Uses Signing.xcconfig when present, otherwise ad-hoc.
build: generate
	@xcodebuild -project Tidbits.xcodeproj -scheme Tidbits -configuration Release -destination 'platform=macOS' -derivedDataPath .derivedData \
		$(if $(SIGNING_XCCONFIG),-xcconfig Signing.xcconfig,CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=) build | tail -5

# Build unsigned (explicit — for contributors without signing credentials)
build-unsigned: generate
	@xcodebuild -project Tidbits.xcodeproj -scheme Tidbits -configuration Release -destination 'platform=macOS' -derivedDataPath .derivedData \
		CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM= build | tail -5

# Install to /Applications (kills app first)
install: kill build
	@rm -rf /Applications/Tidbits.app
	@cp -R $(APP_PATH) /Applications/
	@/System/Library/CoreServices/pbs -update
	@echo "✓ Installed to /Applications/Tidbits.app"

# Run from /Applications
run:
	@open /Applications/Tidbits.app

# Build, install, and run (full update cycle)
update: install run
	@echo "✓ Tidbits updated and running"

# Clean build artifacts
clean:
	@rm -rf .derivedData
	@rm -rf Tidbits.xcodeproj
	@rm -rf $(DMG_DIR)
	@echo "✓ Cleaned"

# Run NotesCore tests
test:
	@cd NotesCore && swift test

# Dev mode: run directly from Debug build (faster iteration, no install)
dev: kill generate
	@xcodebuild -project Tidbits.xcodeproj -scheme Tidbits -configuration Debug -destination 'platform=macOS' -derivedDataPath .derivedData build | tail -5
	@open .derivedData/Build/Products/Debug/Tidbits.app
	@echo "✓ Running from build directory (not installed)"

# Submit for notarization (maintainer only — requires Signing.xcconfig)
notarize: build
	@test -n "$(NOTARIZE_PROFILE)" || (echo "Error: NOTARIZE_PROFILE not set. Create Signing.xcconfig from Signing.xcconfig.example." && exit 1)
	@ditto -c -k --keepParent $(APP_PATH) $(BUILD_DIR)/$(APP_NAME).zip
	@xcrun notarytool submit $(BUILD_DIR)/$(APP_NAME).zip \
		--keychain-profile $(NOTARIZE_PROFILE) \
		--wait
	@rm -f $(BUILD_DIR)/$(APP_NAME).zip
	@echo "✓ Notarization accepted"

# Staple the notarization ticket to the app
staple:
	@xcrun stapler staple $(APP_PATH)
	@echo "✓ Stapled"

# Package into DMG, sign, notarize, and staple (run after app is notarized + stapled)
dmg:
	@test -n "$(SIGNING_CERTIFICATE)" || (echo "Error: SIGNING_CERTIFICATE not set. Create Signing.xcconfig from Signing.xcconfig.example." && exit 1)
	@test -n "$(NOTARIZE_PROFILE)" || (echo "Error: NOTARIZE_PROFILE not set. Create Signing.xcconfig from Signing.xcconfig.example." && exit 1)
	@rm -rf $(DMG_DIR)
	@mkdir -p $(DMG_DIR)
	@set +e; \
	create-dmg \
		--volname "$(APP_NAME)" \
		--window-pos 200 120 \
		--window-size 600 400 \
		--icon-size 100 \
		--icon "$(APP_NAME).app" 150 185 \
		--app-drop-link 450 185 \
		--no-internet-enable \
		$(DMG_PATH) \
		$(APP_PATH); \
	EXIT_CODE=$$?; \
	set -e; \
	if [ $$EXIT_CODE -ne 0 ] && [ $$EXIT_CODE -ne 2 ]; then exit $$EXIT_CODE; fi
	@codesign --force --sign "$(SIGNING_CERTIFICATE)" --timestamp $(DMG_PATH)
	@xcrun notarytool submit $(DMG_PATH) \
		--keychain-profile $(NOTARIZE_PROFILE) \
		--wait
	@xcrun stapler staple $(DMG_PATH)
	@echo "✓ Release ready: $(DMG_PATH)"

# Full release pipeline: build → notarize app → staple app → create/sign/notarize DMG (maintainer only)
release: notarize staple dmg

