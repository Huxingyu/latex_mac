#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <UserNotifications/UserNotifications.h>

#include <iostream>
#include <string>
#include <memory>

// Carbon框架的热键相关宏定义
#define kEventCommandKeyMask (1 << 8)
#define kEventShiftKeyMask (1 << 9)

@interface AppDelegate : NSObject <NSApplicationDelegate, UNUserNotificationCenterDelegate>
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) id shortcutMonitor;
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
            
            // 读取错误输出
            NSFileHandle *errorFile = [errorPipe fileHandleForReading];
            NSData *errorData = [errorFile readDataToEndOfFile];
            NSString *error = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
            
            // 打印输出用于调试
            if (error.length > 0) {
                NSLog(@"pix2tex error: %@", error);
            }
            
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