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
@property NSMutableArray *monitoredFilePaths;
@property NSMutableArray *projectSubscribers;
@property NSMutableArray *projectFiles;

@end

@implementation FTController

NSString const *MonitoredPathsKey = @"MonitoredPaths";

- (id)initWithBundle:(NSBundle *)plugin {
    if(self = [super init]) {
        self.bundle = plugin;
        
        [self initialiseMonitoredFilePaths];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(projectSavedNotification:)
                                                     name:@"PBXProjectSaveNotification"
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(projectOpened:)
                                                     name:@"PBXProjectDidOpenNotification"
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(projectClosed:)
                                                     name:@"PBXProjectDidCloseNotification"
                                                   object:nil];
    }
    return self;
}

-(void)addProjectFilesSubscriberBlock:(ProjectFileSubscriber)block {
    if(!self.projectSubscribers) {
        self.projectSubscribers = [NSMutableArray new];
    }
    
    ProjectFileSubscriber copy = [block copy];
    [self.projectSubscribers addObject:copy];
    
    block(self.projectFiles);
}

- (NSString *)preferencesFilePath {
    NSError *error;
    NSURL *appSupportDir = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                  inDomain:NSUserDomainMask
                                                         appropriateForURL:nil
                                                                    create:YES
                                                                     error:&error];
    if(error) {
        NSLog(@"Error finding directory - %@", error.debugDescription);
    }
    
    NSString *s = [[appSupportDir.path stringByAppendingPathComponent:@"FileTruck"]
                   stringByAppendingPathComponent:@"fileTruckPreferences.plist"];
    return s;
}

- (void)initialiseMonitoredFilePaths {
    NSString *s = [self preferencesFilePath];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:s isDirectory:NULL]) {
        NSString *path = [self.bundle pathForResource:@"fileTruckPreferences" ofType:@"plist"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        
        NSError *creationError;
        if(![[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil]) {
            NSLog(@"Could not create file. %@", creationError);
        }
    }
    
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:s];
    if([plist.allKeys containsObject:MonitoredPathsKey]) {
        self.monitoredFilePaths = [plist[MonitoredPathsKey] mutableCopy];
    }
    else {
        self.monitoredFilePaths = [NSMutableArray new];
    }
}

- (void)projectSavedNotification:(NSNotification*)notification {
    id object = [notification object];
    NSString *path = [object path];
    if([self.monitoredFilePaths containsObject:path]) {
        [self runScriptOnProjectPath:path];
    }
}

- (void)projectOpened:(NSNotification*)notification {
#warning TODO - Remove this horrible hack. Refresh Project Files can't find anything if it's called straight away.
    [self performSelector:@selector(refreshProjectFiles) withObject:nil afterDelay:2.0];
}

- (void)projectClosed:(NSNotification*)notification {
    [self refreshProjectFiles];
}

- (void)runScriptOnItem:(IDEFileNavigableItem*)item {
    NSString *scriptPath = [FTController findScriptFilePathInBundle:self.bundle];
    if(scriptPath) {
        IDEFileReference *fileReference = [item representedObject];
        NSURL *folderURL = fileReference.resolvedFilePath.fileURL;
        NSString *path = folderURL.path;
        [self runScriptOnProjectPath:path];
    }
}

- (void)runScriptOnProjectPath:(NSString*)path {
    NSString *scriptPath = [FTController findScriptFilePathInBundle:self.bundle];
    if(scriptPath) {
        path = [path stringByAppendingPathComponent:@"project.pbxproj"];
        if (path) {
            [self runScript:scriptPath onProjectFile:path];
        }
    }
}

- (void)runScript:(NSString*)script onProjectFile:(NSString*)project {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:script];
    
    // note: change "full-list" to "sort" to get file sorting
    NSArray *arguments = @[@"sort", project];
    [task setArguments: arguments];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    NSString *scriptResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [self showAlertWithTitle:@"FileTruck" infoText:@"Script Results:" andContent:scriptResult];
}

- (void)refreshProjectFiles {
    NSArray *windowControllers = [self windowController];
    NSMutableArray *projectFiles = [NSMutableArray new];
    
    for (NSWindowController *windowController in windowControllers) {
        if(![windowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
            break;
        }
        
        IDEWorkspaceWindowController *workspaceController = (IDEWorkspaceWindowController*)windowController;
        IDEWorkspaceTabController *workspaceTabController = [workspaceController activeWorkspaceTabController];
        IDENavigatorArea *navigatorArea = [workspaceTabController navigatorArea];
        
        // Store the identifier for the current navigator.
        NSString *oldIdentifier = [navigatorArea _currentExtensionIdentifier];
        
        // Change to the structure navigator so we can find the objects.
        [navigatorArea showNavigatorWithIdentifier:@"Xcode.IDEKit.Navigator.Structure"];
        IDEStructureNavigator *newNavigator = [navigatorArea currentNavigator];
        if (![newNavigator isKindOfClass:NSClassFromString(@"IDEStructureNavigator")]) {
            break;
        }
        NSArray *navigatorObjects = [newNavigator objects];
        
        // Move back to the old navigator.
        [navigatorArea showNavigatorWithIdentifier:oldIdentifier];
        
        // Iterate through the objects and find the project files.
        for (IDEFileNavigableItem *navItem in navigatorObjects) {
            if ([navItem isKindOfClass:NSClassFromString(@"IDEContainerFileReferenceNavigableItem")]) {
                [projectFiles addObject:navItem];
            }
        }
    }
    
    self.projectFiles = projectFiles;
    
    [self updateAllSubscribers];
}

- (void)updateAllSubscribers {
    for(ProjectFileSubscriber block in self.projectSubscribers) {
        block(self.projectFiles);
    }
}

+ (NSString*)findScriptFilePathInBundle:(NSBundle*)bundle {
    return [bundle pathForResource:@"retree" ofType:@"py"];
}

- (BOOL)isProjectMonitored:(IDEFileNavigableItem*)project {
    return [self.monitoredFilePaths containsObject:[FTController filePathStringFromProject:project]];
}

- (void)writePathsToDict {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[MonitoredPathsKey] = self.monitoredFilePaths;
    [dict writeToFile:[self preferencesFilePath] atomically:YES];
}

- (void)monitorProject:(IDEFileNavigableItem*)project {
    [self.monitoredFilePaths addObject:[FTController filePathStringFromProject:project]];
    [self writePathsToDict];
}

- (void)unmonitorProject:(IDEFileNavigableItem*)project {
    [self.monitoredFilePaths removeObject:[FTController filePathStringFromProject:project]];
    [self writePathsToDict];
}

+ (NSString*)filePathStringFromProject:(IDEFileNavigableItem*)project {
    IDEFileReference *fileReference = [project representedObject];
    NSURL *folderURL = fileReference.resolvedFilePath.fileURL;
    NSString *path = folderURL.path;
    return path;
}

- (NSArray*)windowController {
    NSMutableArray *windowControllers = [NSMutableArray new];
    
    for(NSWindow *window in [NSApp windows]) {
        id controller = [window windowController];
        if([controller isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
            [windowControllers addObject:controller];
        }
    }
    
    return windowControllers;
}

- (void)showAlertWithTitle:(NSString *)title infoText:(NSString *)infoText andContent:(NSString *)content {
    NSAlert *alert = [NSAlert alertWithMessageText:title
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", infoText];
    if(content) {
        NSScrollView *scrollview = [[NSScrollView alloc] initWithFrame:CGRectMake(0, 0, 600, 350)];
        [scrollview setBorderType:NSLineBorder];
        [scrollview setHasVerticalScroller:YES];
        [scrollview setHasHorizontalScroller:NO];
        [scrollview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        alert.accessoryView = scrollview;
        
        NSSize sSize = [scrollview contentSize];
        NSTextView *contentTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, sSize.width, sSize.height)];
        [contentTextView setMinSize:NSMakeSize(0.0, sSize.height)];
        [contentTextView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
        [contentTextView setVerticallyResizable:YES];
        [contentTextView setHorizontallyResizable:NO];
        [contentTextView setAutoresizingMask:NSViewWidthSizable];
        [[contentTextView textContainer] setContainerSize:NSMakeSize(sSize.width, FLT_MAX)];
        [[contentTextView textContainer] setWidthTracksTextView:YES];
        [contentTextView insertText:content];
        [contentTextView setEditable:NO];
        [scrollview setDocumentView:contentTextView];
    }
    
    [alert runModal];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
