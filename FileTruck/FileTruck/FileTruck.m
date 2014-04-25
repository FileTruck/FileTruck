//
//  FileTruck.m
//  FileTruck
//
//  Created by Chris Grant on 06/03/2014.
//  Copyright (c) 2014 ScottLogic. All rights reserved.
//

#import "FileTruck.h"
#import "FTWindowController.h"
#import "FTController.h"

static FileTruck *sharedPlugin;

@interface FileTruck()

@property (nonatomic, strong) NSBundle *bundle;

@property FTController *controller;

@property FTWindowController *window;

@end

@implementation FileTruck

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin {
    if (self = [super init]) {
        self.bundle = plugin;
        
        self.controller = [[FTController alloc] initWithBundle:self.bundle];
        self.window = [[FTWindowController alloc] initWithController:self.controller];

        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Editor"];
        if (menuItem) {
            [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"FileTruck"
                                                                    action:@selector(openFileTruckWindow)
                                                             keyEquivalent:@""];
            [actionMenuItem setTarget:self];
            [[menuItem submenu] addItem:actionMenuItem];
        }
    }
    return self;
}

- (void)openFileTruckWindow {
    [self.window showWindow:nil];
}

@end
