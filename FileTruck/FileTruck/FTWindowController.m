//
//  FTWindowController.m
//  FileTruck
//
//  Created by Chris Grant on 12/03/2014.
//  Copyright (c) 2014 ScottLogic. All rights reserved.
//

#import "FTWindowController.h"

@interface FTWindowController () <NSTableViewDataSource>

@property FTController *controller;

@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTableColumn *projectColumn;
@property (weak) IBOutlet NSTableColumn *monitorColumn;
@property (weak) IBOutlet NSTableColumn *runNowColumn;

@property (nonatomic, strong) NSArray *projectFiles;

@end

@implementation FTWindowController

- (instancetype)initWithController:(FTController *)controller {
    if(self = [super initWithWindowNibName:@"FTWindowController"]) {
        self.controller = controller;
        __weak id weakSelf = self;
        [self.controller addProjectFilesSubscriberBlock:^(NSArray *projects) {
            if(projects) {
                [weakSelf setProjectFiles:projects];
                [[weakSelf tableView] reloadData];
            }
        }];
    }
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.projectFiles.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    IDEFileNavigableItem *item = self.projectFiles[row];
    IDEFileReference *fileReference = [item representedObject];
    NSURL *folderURL = fileReference.resolvedFilePath.fileURL;
    NSString *path = folderURL.path;

    if(tableColumn == self.projectColumn) {
        return path;
    }
    else if(tableColumn == self.monitorColumn) {
        return @([self.controller isProjectMonitored:item]);
    }
    
    return nil;
}

- (IBAction)monitorButtonClicked:(NSButtonCell *)sender {
    NSInteger clickedRow = [self.tableView clickedRow];
    IDEFileNavigableItem *item = self.projectFiles[clickedRow];
    if([self.controller isProjectMonitored:item]) {
        [self.controller unmonitorProject:item];
    }
    else {
        [self.controller monitorProject:item];
    }
}

- (IBAction)runButtonClicked:(NSButtonCell *)sender {
    NSInteger clickedRow = [self.tableView clickedRow];
    [self.controller runScriptOnItem:self.projectFiles[clickedRow]];
}

@end
