//
//  GAAppDelegate.m
//  GoAgentX
//
//  Created by Xu Jiwei on 12-2-13.
//  Copyright (c) 2012年 xujiwei.com. All rights reserved.
//

#import "GAAppDelegate.h"


@implementation GAAppDelegate

@synthesize window = _window;

#pragma mark -
#pragma mark Helper

- (NSString *)pathInApplicationSupportFolder:(NSString *)path {
    NSString *folder = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
                         stringByAppendingPathComponent:@"Application Support"]
                        stringByAppendingPathComponent:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
    return [folder stringByAppendingPathComponent:path];
}


- (NSString *)copyFolderToApplicationSupport:(NSString *)folder {
    NSString *srcPath = [[NSBundle mainBundle] resourcePath];
    NSLog(@"\nsrcPath: %@", srcPath);
    NSString *copyPath = [self pathInApplicationSupportFolder:folder];
    NSLog(@"\ncopyPath: %@", copyPath);
    [[NSFileManager defaultManager] removeItemAtPath:copyPath error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:[copyPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:[srcPath stringByAppendingPathComponent:@"west-chamber-proxy"]
                                            toPath:copyPath error:NULL];
    return copyPath;
}

- (NSString *)copyLocalToApplicationSupport {
    return [self copyFolderToApplicationSupport:@"local"];
}


- (NSDictionary *)defaultSettings {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"GoAgentDefaultSettings" ofType:@"plist"]];
    return dict;
}


- (void)setStatusToRunning:(BOOL)running {
    NSInteger port = [[NSUserDefaults standardUserDefaults] integerForKey:@"GoAgent:Local:Port"];
    NSString *statusText = [NSString stringWithFormat:@"正在运行，端口 %ld", port];
    NSImage *statusImage = [NSImage imageNamed:@"status_running"];
    NSString *buttonTitle = @"停止";
    
    if (!running) {
        statusText = @"已停止";
        statusImage = [NSImage imageNamed:@"status_stopped"];
        buttonTitle = @"启动";
    }
    
    statusBarItem.toolTip = statusText;
    statusTextLabel.stringValue = statusText;
    statusImageView.image = statusImage;
    statusMenuItem.title = statusText;
    statusMenuItem.image = statusImage;
    statusToggleButton.title = buttonTitle;
}

- (NSArray *)connectionModes {
    return [NSArray arrayWithObjects:@"HTTP", @"HTTPS", nil];
}


- (NSArray *)gaeProfiles {
    return [NSArray arrayWithObjects:@"google_cn", @"google_hk", @"google_ipv6", nil];;
}


#pragma mark -
#pragma mark Setup

- (void)setupStatusItem {
    statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:23.0];
    statusBarItem.image = [NSImage imageNamed:@"status_item_icon"];
    statusBarItem.alternateImage = [NSImage imageNamed:@"status_item_icon_alt"];
    statusBarItem.menu = statusBarItemMenu;
    statusBarItem.toolTip = @"GoAgent is NOT Running";
    [statusBarItem setHighlightMode:YES];
}


- (BOOL)checkIfGoAgentInstalled {
    NSString *goagentPath = [self pathInApplicationSupportFolder:@"goagent"];
    NSString *proxypyPath  = [[goagentPath stringByAppendingPathComponent:@"local"] stringByAppendingPathComponent:@"westchamberproxy.py"];
    
    return [[NSFileManager defaultManager] fileExistsAtPath:proxypyPath];
}


- (void)installFromFolder:(NSString *)path {
    NSString *goagentPath = [self pathInApplicationSupportFolder:@"goagent"];
    [[NSFileManager defaultManager] removeItemAtPath:goagentPath error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:goagentPath withIntermediateDirectories:YES attributes:nil error:NULL];
    
    [[NSFileManager defaultManager] copyItemAtPath:path
                                            toPath:[goagentPath stringByAppendingPathComponent:@"local"] error:NULL];
    
}


- (void)showInstallPanel:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/liruqi/GoAgentX/downloads"]];
}


#pragma mark -
#pragma mark 菜单事件

- (void)showMainWindow:(id)sender {
    [self.window setLevel:NSFloatingWindowLevel];
    if ([self.window canBecomeMainWindow]) {
        [self.window makeMainWindow];
    }
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeKeyWindow];
}


- (void)exitApplication:(id)sender {
    [NSApp terminate:nil];
}


- (void)showHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/ohdarling88/GoAgentX"]];
}


#pragma mark -
#pragma mark 运行状态

- (void)toggleServiceStatus:(id)sender {
    if (proxyRunner == nil) {
        proxyRunner = [GACommandRunner new];
    }
    
    GACommandRunner *runner = proxyRunner;
    
    if ([runner isTaskRunning]) {
        [runner terminateTask];
        [self setStatusToRunning:NO];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"GoAgent:LastRunPID"];
        
    } else {
        // 关闭可能的上次运行的 goagent
        NSInteger lastRunPID = [[NSUserDefaults standardUserDefaults] integerForKey:@"GoAgent:LastRunPID"];
        if (lastRunPID > 0) {
            const char *killCmd = [[NSString stringWithFormat:@"kill %ld", lastRunPID] UTF8String];
            system(killCmd);
        }
        
        // 复制一份 local 到 Application Support
        NSString *copyPath = [self copyLocalToApplicationSupport];
        
        // 生成 proxy.ini
        NSDictionary *defaults = [self defaultSettings];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *proxyini = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"proxyinitemplate" ofType:nil] 
                                                       encoding:NSUTF8StringEncoding error:NULL];
        for (NSString *key in [defaults allKeys]) {
            NSString *value = [userDefaults stringForKey:key] ?: @"";
            if ([key isEqualToString:@"GoAgent:Local:GAEProfile"]) {
                value = [[self gaeProfiles] objectAtIndex:[value intValue]];
            } else if ([key isEqualToString:@"GoAgent:Local:ConnectMode"]) {
                value = [[self connectionModes] objectAtIndex:[value intValue]];
            }
            proxyini = [proxyini stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"{%@}", key]
                                                           withString:value];
        }
        NSLog(@"\ncurrent directory: %@", copyPath);
        [proxyini writeToFile:[copyPath stringByAppendingPathComponent:@"config.py"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        [statusLogTextView clear];
        [statusLogTextView appendString:@"正在启动...\n"];
        
        // 启动代理
        NSArray *arguments = [NSArray arrayWithObjects:@"python", @"westchamberproxy.py", nil];
        [runner runCommand:@"/usr/bin/env"
          currentDirectory:copyPath
                 arguments:arguments
                 inputText:nil
            outputTextView:statusLogTextView 
        terminationHandler:^(NSTask *theTask) {
            [self setStatusToRunning:NO];
            [statusLogTextView appendString:@"服务已停止\n"];
        }];
        
        [statusLogTextView appendString:@"启动完成\n"];
        
        [[NSUserDefaults standardUserDefaults] setInteger:[runner processId] forKey:@"GoAgent:LastRunPID"];
        
        [self setStatusToRunning:YES];
    }
}


- (void)clearStatusLog:(id)sender {
    [statusLogTextView clear];
}


#pragma mark -
#pragma mark 客户端设置

- (void)applyClientSettings:(id)sender {
    [proxyRunner terminateTask];
    sleep(1);
    [self toggleServiceStatus:nil];
}


#pragma mark -
#pragma mark Window delegate

- (BOOL)windowShouldClose:(id)sender {
    [self.window orderOut:nil];
    return NO;
}


#pragma mark -
#pragma mark App delegate

- (void)applicationWillTerminate:(NSNotification *)notification {
    [proxyRunner terminateTask];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // 设置状态日志最大为10K
    statusLogTextView.maxLength = 10000;
    
    // 注册默认偏好设置
    [[NSUserDefaults standardUserDefaults] registerDefaults:[self defaultSettings]];
    
    // 设置 MenuBar 图标
    [self setupStatusItem];

    [self showMainWindow:nil];
    [self toggleServiceStatus:nil];
}


@end
