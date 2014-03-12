//
//  FTController.m
//  FileTruck
//
//  Created by Chris Grant on 12/03/2014.
//  Copyright (c) 2014 ScottLogic. All rights reserved.
//

#import "FTController.h"
#import <AppKit/AppKit.h>

@interface FTController ()

@property NSBundle *bundle;

@end

@implementation FTController

- (id)initWithBundle:(NSBundle *)plugin {
    if(self = [super init]) {
        self.bundle = plugin;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(observed:)
                                                     name:@"PBXProjectSaveNotification"
                                                   object:nil];
    }
    return self;
}

-(void)observed:(NSNotification*)notification {
    if(self.monitorForChanges) {
        [self runScriptOnCurrentProject];
    }
}

- (void)runScriptOnCurrentProject {
    NSString *path = [FTController findProjectFilePath];
    NSString *scriptPath = [FTController findScriptFilePathInBundle:self.bundle];
    if (path && scriptPath) {
        [self runScript:scriptPath onProjectFile:path];
    }
}

- (void)runScript:(NSString*)script onProjectFile:(NSString*)project {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:script];
    
    NSArray *arguments = @[project];
    [task setArguments: arguments];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    NSString *scriptResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [self showAlertWithTitle:@"FileTruck" infoText:@"Script Results:" andContent:scriptResult];
}

+ (NSString*)findProjectFilePath {
    if(![[self windowController] isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        return nil;
    }
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
        NSString *path = folderURL.path;
        return [path stringByAppendingPathComponent:@"project.pbxproj"];
    }
    return nil;
}

+ (NSString*)findScriptFilePathInBundle:(NSBundle*)bundle {
    return [bundle pathForResource:@"projparse" ofType:nil];
}

+ (NSWindowController *)windowController {
    NSMutableArray *windowControllers = [NSMutableArray new];
    
    for(NSWindow *window in [NSApp windows]) {
        id controller = [window windowController];
        if([controller isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
            [windowControllers addObject:controller];
        }
    }
    
    if(windowControllers.count != 1) {
        [NSException raise:@"There should only be 1 window controller" format:@"Multiple window controllers!"];
        return nil;
    }
    
    return windowControllers.firstObject;
}

- (void)showAlertWithTitle:(NSString *)title infoText:(NSString *)infoText andContent:(NSString *)content {
    NSAlert *alert = [NSAlert alertWithMessageText:title
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", infoText];
    
    NSScrollView *scrollview = [[NSScrollView alloc] initWithFrame:CGRectMake(0, 0, 600, 350)];
    [scrollview setBorderType:NSLineBorder];
    [scrollview setHasVerticalScroller:YES];
    [scrollview setHasHorizontalScroller:NO];
    [scrollview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    alert.accessoryView = scrollview;
    
    NSSize contentSize = [scrollview contentSize];
    NSTextView *contentTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    [contentTextView setMinSize:NSMakeSize(0.0, contentSize.height)];
    [contentTextView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [contentTextView setVerticallyResizable:YES];
    [contentTextView setHorizontallyResizable:NO];
    [contentTextView setAutoresizingMask:NSViewWidthSizable];
    [[contentTextView textContainer] setContainerSize:NSMakeSize(contentSize.width, FLT_MAX)];
    [[contentTextView textContainer] setWidthTracksTextView:YES];
    [contentTextView insertText:content];
    [contentTextView setEditable:NO];
    [scrollview setDocumentView:contentTextView];
    
    [alert runModal];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
