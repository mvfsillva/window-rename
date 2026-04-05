.PHONY: build build-debug install uninstall run clean

APP_NAME   := SpaceRenamer
BUILD_DIR  := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := /Applications

## build	— Build release .app bundle
build:
	@./scripts/build-app.sh

## build-debug	— Build debug .app bundle
build-debug:
	@./scripts/build-app.sh --debug

## install	— Copy .app to /Applications (may require sudo)
install: build
	@echo "==> Installing $(APP_BUNDLE) to $(INSTALL_DIR)/"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "==> Installed: $(INSTALL_DIR)/$(APP_NAME).app"

## uninstall	— Remove .app from /Applications
uninstall:
	@echo "==> Removing $(INSTALL_DIR)/$(APP_NAME).app"
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "==> Uninstalled."

## run		— Build and launch the app
run: build
	@echo "==> Launching $(APP_NAME)..."
	@open "$(APP_BUNDLE)"

## clean	— Remove build artifacts
clean:
	@echo "==> Cleaning build directory..."
	@rm -rf $(BUILD_DIR)
	@echo "==> Clean."

## help	— Show this help
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //' | column -t -s '	'
