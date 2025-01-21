CC = clang++
CFLAGS = -framework Cocoa -framework Carbon -framework UserNotifications

all: latex_mac.app

latex_mac.app: latex_mac
	@mkdir -p latex_mac.app/Contents/MacOS
	@mkdir -p latex_mac.app/Contents/Resources
	@cp Info.plist latex_mac.app/Contents/
	@cp latex_mac latex_mac.app/Contents/MacOS/
	@cp cat.icns latex_mac.app/Contents/Resources/
	@xattr -cr latex_mac.app
	@codesign --force --deep --sign - --timestamp=none --options=runtime latex_mac.app

latex_mac: main.mm
	$(CC) main.mm $(CFLAGS) -o latex_mac

clean:
	rm -rf latex_mac latex_mac.app