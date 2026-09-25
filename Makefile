APP     := zmkaid
BUILD   := build
PRODUCT := $(BUILD)/Build/Products/Release/$(APP).app
ICONSET := $(APP)/Assets.xcassets/AppIcon.appiconset

.PHONY: build run install preview icon clean

build:
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) -configuration Release \
		-derivedDataPath $(BUILD) -quiet build

# Build and launch from the build folder.
run: build
	-pkill -x $(APP)
	open $(PRODUCT)

# Copy into /Applications for everyday use.
install: build
	-pkill -x $(APP)
	rm -rf /Applications/$(APP).app
	cp -R $(PRODUCT) /Applications/
	open /Applications/$(APP).app

# Render the overlay to PNGs in ./preview without opening a window.
preview: build
	$(PRODUCT)/Contents/MacOS/$(APP) --render $(CURDIR)/preview

# Make every app icon size from one square PNG (1024 × 1024 is best): make icon ICON=path/to/icon.png
icon:
	@test -n "$(ICON)" || { echo "usage: make icon ICON=path/to/icon.png"; exit 1; }
	@for s in 16 32 128 256 512; do \
		sips -s format png -z $$s $$s "$(ICON)" --out "$(ICONSET)/icon_$${s}x$${s}.png" >/dev/null && \
		sips -s format png -z $$((s * 2)) $$((s * 2)) "$(ICON)" --out "$(ICONSET)/icon_$${s}x$${s}@2x.png" >/dev/null || exit 1; \
	done
	@echo "Wrote 10 icon sizes to $(ICONSET). Run 'make install' to use them."

clean:
	rm -rf $(BUILD) preview
