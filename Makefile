APP_NAME = Frame
BUNDLE = dist/$(APP_NAME).app
BIN = $(BUNDLE)/Contents/MacOS/$(APP_NAME)
ICON = $(BUNDLE)/Contents/Resources/AppIcon.icns
SRCS = $(shell find Sources -name '*.swift' | sort)
SIGN_ID ?= Apple Development: menziesj722@gmail.com (SX5S9CC8KP)
MACOS = 26.0

.PHONY: all build install run clean test unlock

all: build

build: $(BIN)

$(BIN): $(SRCS) Resources/Info.plist scripts/make_icon.swift
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	swiftc -parse-as-library -o /tmp/frame-make-icon scripts/make_icon.swift
	/tmp/frame-make-icon "$(ICON)"
	swiftc -O -parse-as-library \
		-target arm64-apple-macos$(MACOS) \
		-o $(BIN) $(SRCS)
	codesign --force --deep --sign "$(SIGN_ID)" \
		--identifier com.shualabs.frame \
		--options runtime \
		$(BUNDLE)

install: build
	killall Frame 2>/dev/null || true
	rm -rf "$(HOME)/Applications/$(APP_NAME).app"
	mkdir -p "$(HOME)/Applications"
	cp -R $(BUNDLE) "$(HOME)/Applications/$(APP_NAME).app"
	open "$(HOME)/Applications/$(APP_NAME).app"

unlock:
	killall Frame 2>/dev/null || true
	tccutil reset ScreenCapture com.shualabs.frame
	$(MAKE) install

run: build
	open $(BUNDLE)

test:
	swiftc -parse-as-library -O \
		-target arm64-apple-macos$(MACOS) \
		-o /tmp/frame-redact-tests \
		Tests/RedactTests.swift Sources/RedactPatterns.swift
	/tmp/frame-redact-tests

clean:
	rm -rf dist
