#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <UserNotifications/UserNotifications.h>

#include <iostream>
#include <string>
#include <memory>

// Carbon框架的热键相关宏定义
#define kEventCommandKeyMask (1 << 8)
#define kEventShiftKeyMask (1 << 9)

@interface MainWindowController : NSWindowController <NSSplitViewDelegate>
@property (strong) NSImageView *imageView;
@property (strong) NSTextView *latexTextView;
- (void)updateWithImage:(NSImage *)image andLatex:(NSString *)latex;
@end

@implementation MainWindowController

- (instancetype)init {
    self = [super initWithWindow:[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
                                                          styleMask:NSWindowStyleMaskTitled |
                                                                    NSWindowStyleMaskClosable |
                                                                    NSWindowStyleMaskMiniaturizable
                                                            backing:NSBackingStoreBuffered
                                                              defer:NO]];
    if (self) {
        NSWindow *window = self.window;
        window.title = @"LaTeX转换";
        [window center];
        
        // 创建分割视图
        NSSplitView *splitView = [[NSSplitView alloc] initWithFrame:window.contentView.bounds];
        splitView.vertical = NO;
        splitView.delegate = self;
        splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        splitView.dividerStyle = NSSplitViewDividerStyleThin;
        
        // 设置分割视图的背景颜色
        splitView.wantsLayer = YES;
        splitView.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
        
        // 创建图片视图容器
        NSView *imageContainer = [[NSView alloc] init];
        imageContainer.translatesAutoresizingMaskIntoConstraints = NO;
        imageContainer.wantsLayer = YES;
        imageContainer.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
        
        // 创建图片视图
        self.imageView = [[NSImageView alloc] init];
        self.imageView.imageScaling = NSImageScaleProportionallyDown;
        self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [imageContainer addSubview:self.imageView];
        
        // 设置图片视图约束，限制最大尺寸
        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.centerXAnchor constraintEqualToAnchor:imageContainer.centerXAnchor],
            [self.imageView.centerYAnchor constraintEqualToAnchor:imageContainer.centerYAnchor],
            [self.imageView.widthAnchor constraintLessThanOrEqualToConstant:600],
            [self.imageView.heightAnchor constraintLessThanOrEqualToConstant:400],
            [self.imageView.widthAnchor constraintLessThanOrEqualToAnchor:imageContainer.widthAnchor constant:-40],
            [self.imageView.heightAnchor constraintLessThanOrEqualToAnchor:imageContainer.heightAnchor constant:-40]
        ]];
        
        // 创建文本视图容器
        NSView *textContainer = [[NSView alloc] init];
        textContainer.translatesAutoresizingMaskIntoConstraints = NO;
        textContainer.wantsLayer = YES;
        textContainer.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
        
        // 创建标题标签
        NSTextField *titleLabel = [[NSTextField alloc] init];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.editable = NO;
        titleLabel.bordered = NO;
        titleLabel.backgroundColor = [NSColor clearColor];
        titleLabel.font = [NSFont boldSystemFontOfSize:14];
        titleLabel.stringValue = @"识别结果：";
        [textContainer addSubview:titleLabel];
        
        // 创建文本视图
        NSScrollView *scrollView = [[NSScrollView alloc] init];
        scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        scrollView.hasVerticalScroller = YES;
        scrollView.hasHorizontalScroller = YES;
        scrollView.autohidesScrollers = YES;
        
        self.latexTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];
        self.latexTextView.editable = NO;
        self.latexTextView.font = [NSFont monospacedSystemFontOfSize:14 weight:NSFontWeightRegular];
        self.latexTextView.textContainerInset = NSMakeSize(10, 10);
        self.latexTextView.backgroundColor = [NSColor controlBackgroundColor];
        self.latexTextView.minSize = NSMakeSize(0.0, 0.0);
        self.latexTextView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
        self.latexTextView.verticallyResizable = YES;
        self.latexTextView.horizontallyResizable = YES;
        self.latexTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        scrollView.documentView = self.latexTextView;
        
        [textContainer addSubview:scrollView];
        
        // 设置文本容器中的约束
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:textContainer.topAnchor constant:20],
            [titleLabel.leadingAnchor constraintEqualToAnchor:textContainer.leadingAnchor constant:20],
            
            [scrollView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
            [scrollView.leadingAnchor constraintEqualToAnchor:textContainer.leadingAnchor constant:20],
            [scrollView.trailingAnchor constraintEqualToAnchor:textContainer.trailingAnchor constant:-20],
            [scrollView.bottomAnchor constraintEqualToAnchor:textContainer.bottomAnchor constant:-20]
        ]];
        
        // 添加视图到分割视图
        [splitView addSubview:imageContainer];
        [splitView addSubview:textContainer];
        
        // 为分割视图的子视图添加约束
        [NSLayoutConstraint activateConstraints:@[
            [imageContainer.leadingAnchor constraintEqualToAnchor:splitView.leadingAnchor],
            [imageContainer.trailingAnchor constraintEqualToAnchor:splitView.trailingAnchor],
            [imageContainer.heightAnchor constraintEqualToConstant:200], // 设置固定高度
            
            [textContainer.leadingAnchor constraintEqualToAnchor:splitView.leadingAnchor],
            [textContainer.trailingAnchor constraintEqualToAnchor:splitView.trailingAnchor],
            [textContainer.topAnchor constraintEqualToAnchor:imageContainer.bottomAnchor],
            [textContainer.bottomAnchor constraintEqualToAnchor:splitView.bottomAnchor]
        ]];
        
        window.contentView = splitView;
    }
    return self;
}

#pragma mark - NSSplitViewDelegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    return 150.0; // 设置最小高度
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    return splitView.frame.size.height - 150.0; // 确保底部视图至少有150像素高
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    return NO; // 禁止折叠子视图
}

- (void)updateWithImage:(NSImage *)image andLatex:(NSString *)latex {
    // 设置图片
    self.imageView.image = image;
    
    // 更新LaTeX文本
    if (latex) {
        // 移除可能的前缀路径信息
        NSString *cleanLatex = latex;
        if ([latex containsString:@": "]) {
            NSArray *components = [latex componentsSeparatedByString:@": "];
            if (components.count > 1) {
                cleanLatex = components[1];
            }
        }
        
        // 移除多余的空白字符
        cleanLatex = [cleanLatex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // 设置文本
        [self.latexTextView setString:cleanLatex];
    } else {
        [self.latexTextView setString:@""];
    }
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, UNUserNotificationCenterDelegate>
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) id shortcutMonitor;
@property (nonatomic, strong) MainWindowController *mainWindowController;
- (void)dealloc;
@end

@implementation AppDelegate

- (void)dealloc {
    if (self.shortcutMonitor) {
        [NSEvent removeMonitor:self.shortcutMonitor];
        NSLog(@"清理快捷键监听器");
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // 配置通知中心
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    
    // 请求通知权限
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (!granted) {
            NSLog(@"通知权限被拒绝");
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"需要通知权限";
                alert.informativeText = @"请在系统偏好设置中允许应用发送通知，以便显示转换结果。";
                [alert runModal];
            });
        }
    }];
    
    // 创建状态栏图标
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *statusImage = [NSImage imageWithSystemSymbolName:@"function" accessibilityDescription:@"LaTeX转换"];
    [statusImage setTemplate:YES]; // 允许系统自动处理图标颜色
    self.statusItem.button.image = statusImage;
    
    // 创建菜单
    NSMenu *menu = [[NSMenu alloc] init];    
    [menu addItemWithTitle:@"截图转换" action:@selector(captureAndConvert) keyEquivalent:@"-"];
    [menu addItemWithTitle:@"设置" action:@selector(openSettings:) keyEquivalent:@","];
    [menu addItemWithTitle:@"退出" action:@selector(terminate:) keyEquivalent:@"q"];
    self.statusItem.menu = menu;
    
    // 注册全局快捷键 (Command + Shift + X)
    [self registerGlobalShortcut];
    
    // 创建并显示主窗口
    self.mainWindowController = [[MainWindowController alloc] init];
    [self.mainWindowController showWindow:nil];
    
    [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
        willPresentNotification:(UNNotification *)notification
        withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

- (void)registerGlobalShortcut {
    NSLog(@"开始注册全局快捷键...");
    
    // 定义快捷键组合
    EventHotKeyRef hotKeyRef;
    EventHotKeyID hotKeyID;
    hotKeyID.signature = 'htk1';
    hotKeyID.id = 1;
    
    // 注册快捷键回调
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind = kEventHotKeyPressed;
    
    InstallApplicationEventHandler(&hotKeyHandler, 1, &eventType, (__bridge void *)self, NULL);
    
    // 注册Command+Shift+-快捷键
    RegisterEventHotKey(kVK_ANSI_Minus,
                       kEventCommandKeyMask | kEventShiftKeyMask,
                       hotKeyID,
                       GetApplicationEventTarget(),
                       0,
                       &hotKeyRef);
    
    NSLog(@"全局快捷键注册成功");
}

// 快捷键回调函数
OSStatus hotKeyHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
    // 获取事件类型
    EventHotKeyID hotKeyID;
    GetEventParameter(theEvent,
                     kEventParamDirectObject,
                     typeEventHotKeyID,
                     NULL,
                     sizeof(EventHotKeyID),
                     NULL,
                     &hotKeyID);
    
    if (hotKeyID.id == 1) {
        AppDelegate *delegate = (__bridge AppDelegate *)userData;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate captureAndConvert];
        });
    }
    
    return noErr;
}

- (void)captureAndConvert {
    // 调用系统截图
    NSTask *screencapture = [[NSTask alloc] init];
    [screencapture setLaunchPath:@"/usr/sbin/screencapture"];
    
    // 临时文件路径
    NSString *tempImagePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"temp_screenshot.png"];
    
    [screencapture setArguments:@[@"-i", @"-s", tempImagePath]];
    
    [screencapture launch];
    [screencapture waitUntilExit];
    
    // 检查文件是否存在
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempImagePath]) {
        // 加载截图
        NSImage *capturedImage = [[NSImage alloc] initWithContentsOfFile:tempImagePath];
        
        // 调用pix2tex处理图片
        NSTask *pix2tex = [[NSTask alloc] init];
        
        // 设置工作目录为当前目录
        char cwd[PATH_MAX];
        if (getcwd(cwd, sizeof(cwd)) != NULL) {
            NSString *workingDirectory = [NSString stringWithUTF8String:cwd];
            [pix2tex setCurrentDirectoryPath:workingDirectory];
        }
        
        // 设置环境变量以解决SSL证书验证问题
        [pix2tex setEnvironment:@{
            @"SSL_CERT_FILE": @"/etc/ssl/cert.pem",
            @"PYTHONPATH": [[[NSProcessInfo processInfo] environment] objectForKey:@"PYTHONPATH"] ?: @""
        }];
        
        [pix2tex setLaunchPath:@"/Library/Frameworks/Python.framework/Versions/3.12/bin/pix2tex"];
        [pix2tex setArguments:@[tempImagePath]];
        
        // 设置标准输出和错误输出管道
        NSPipe *outputPipe = [NSPipe pipe];
        NSPipe *errorPipe = [NSPipe pipe];
        [pix2tex setStandardOutput:outputPipe];
        [pix2tex setStandardError:errorPipe];
        
        @try {
            [pix2tex launch];
            [pix2tex waitUntilExit];
            
            // 读取标准输出
            NSFileHandle *outputFile = [outputPipe fileHandleForReading];
            NSData *outputData = [outputFile readDataToEndOfFile];
            NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
            
            // 处理输出，移除文件路径信息
            if ([output containsString:@": "]) {
                NSArray *components = [output componentsSeparatedByString:@": "];
                if (components.count > 1) {
                    output = components[1];
                }
            }
            
            // 更新主窗口显示
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.mainWindowController updateWithImage:capturedImage andLatex:output];
            });
            
            // 读取错误输出
            NSFileHandle *errorFile = [errorPipe fileHandleForReading];
            NSData *errorData = [errorFile readDataToEndOfFile];
            NSString *error = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
            
            // 打印输出用于调试
            if (error.length > 0) {
                NSLog(@"pix2tex error: %@", error);
            }
            
            // 更新主窗口显示
            [self.mainWindowController updateWithImage:capturedImage andLatex:output];
            
            // 将结果写入剪贴板
            if (output.length > 0) {
                NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                [pasteboard clearContents];
                [pasteboard writeObjects:@[output]];
                
                // 使用UNUserNotificationCenter显示通知
                UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
                content.title = @"LaTeX公式已复制";
                content.body = output;
                content.sound = [UNNotificationSound defaultSound];
                
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                                    content:content
                                                                                    trigger:nil];
                
                [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                                   withCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"通知发送失败: %@", error);
                    }
                }];
            } else {
                // 使用UNUserNotificationCenter显示错误通知
                UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
                content.title = @"转换失败";
                content.body = @"无法转换公式，请查看控制台输出";
                content.sound = [UNNotificationSound defaultSound];
                
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                                    content:content
                                                                                    trigger:nil];
                
                [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                                   withCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"通知发送失败: %@", error);
                    }
                }];
            }
        } @catch (NSException *exception) {
            NSLog(@"pix2tex execution failed: %@", exception);
            
            // 使用UNUserNotificationCenter显示错误通知
            UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
            content.title = @"转换失败";
            content.body = @"执行pix2tex时发生错误";
            content.sound = [UNNotificationSound defaultSound];
            
            UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                                content:content
                                                                                trigger:nil];
            
            [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                               withCompletionHandler:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"通知发送失败: %@", error);
                }
            }];
        }
        
        // 删除临时文件
        [[NSFileManager defaultManager] removeItemAtPath:tempImagePath error:nil];
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [application setDelegate:delegate];
        [application run];
    }
    return 0;
}