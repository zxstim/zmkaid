APP     := zmkaid
BUILD   := build
PRODUCT := $(BUILD)/Build/Products/Release/$(APP).app

.PHONY: build run install preview clean

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

clean:
	rm -rf $(BUILD) preview
