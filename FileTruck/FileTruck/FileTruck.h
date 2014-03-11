//
//  FileTruck.h
//  FileTruck
//
//  Created by Chris Grant on 06/03/2014.
//  Copyright (c) 2014 ScottLogic. All rights reserved.
//

#import <AppKit/AppKit.h>

#pragma mark - Private APIs we need to use to access the project file

@interface DVTFilePath : NSObject
@property (readonly) NSURL *fileURL;
@end

@interface IDEContainerItem : NSObject
@property (readonly) DVTFilePath *resolvedFilePath;
@end

@interface IDEFileReference : IDEContainerItem
@end

@interface IDENavigableItem : NSObject
@property (readonly) IDENavigableItem *parentItem;
@property (readonly) id representedObject;
@end

@interface IDEFileNavigableItem : IDENavigableItem
@property (readonly) NSURL *fileURL;
@end

@interface IDEStructureNavigator : NSObject
@property (retain) NSArray *objects;
@end

@interface IDENavigatorArea : NSObject
- (id)currentNavigator;
@end

@interface IDEWorkspaceTabController : NSObject
@property (readonly) IDENavigatorArea *navigatorArea;
@end

@interface IDEWorkspaceWindowController : NSObject
@property (readonly) IDEWorkspaceTabController *activeWorkspaceTabController;
@end

@interface FileTruck : NSObject

@end