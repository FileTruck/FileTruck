//
//  FileTruck.m
//  FileTruck
//
//  Created by Chris Grant on 06/03/2014.
//  Copyright (c) 2014 ScottLogic. All rights reserved.
//

#import "FileTruck.h"

static FileTruck *sharedPlugin;

@interface FileTruck()

@property (nonatomic, strong) NSBundle *bundle;

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

        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"File"];
        if (menuItem) {
            [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"Do Action"
                                                                    action:@selector(doMenuAction)
                                                             keyEquivalent:@""];
            [actionMenuItem setTarget:self];
            [[menuItem submenu] addItem:actionMenuItem];
        }
    }
    return self;
}

- (void)doMenuAction {
    NSURL *path = [FileTruck findProjectFilePath];
    if (path) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"FileTruck"
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Path: %@", path.absoluteString];
        [alert runModal];
    }
}

+ (NSURL*)findProjectFilePath {
    IDEWorkspaceWindowController *workspaceController = (IDEWorkspaceWindowController *)[self windowController];
    IDEWorkspaceTabController *workspaceTabController = [workspaceController activeWorkspaceTabController];
    IDENavigatorArea *navigatorArea = [workspaceTabController navigatorArea];
    id currentNavigator = [navigatorArea currentNavigator];
    if (![currentNavigator isKindOfClass:NSClassFromString(@"IDEStructureNavigator")]) {
        return nil;
    }
    
    NSMutableArray *projectFiles = [NSMutableArray new];
    NSArray *navigatorObjects = [currentNavigator objects];
    [navigatorObjects enumerateObjectsUsingBlock:^(IDEFileNavigableItem *navItem, NSUInteger idx, BOOL *stop) {
        if ([navItem isKindOfClass:NSClassFromString(@"IDEContainerFileReferenceNavigableItem")]) {
            [projectFiles addObject:navItem];
        }
    }];

    if (projectFiles.count != 1) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Multiple Project Files"
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"There were %lu project files.", projectFiles.count];
        [alert runModal];
    }
    else {
        IDEFileReference *fileReference = [projectFiles.firstObject representedObject];
        NSURL *folderURL = fileReference.resolvedFilePath.fileURL;
        return folderURL;
    }
    
    return nil;
}

+ (NSWindowController *)windowController {
    return [[NSApp keyWindow] windowController];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
