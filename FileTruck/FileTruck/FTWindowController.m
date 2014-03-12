//
//  FTWindowController.m
//  FileTruck
//
//  Created by Chris Grant on 12/03/2014.
//  Copyright (c) 2014 ScottLogic. All rights reserved.
//

#import "FTWindowController.h"

@interface FTWindowController ()

@property FTController *controller;

@property (weak) IBOutlet NSButton *monitorButton;
@property (weak) IBOutlet NSButton *runButton;

@end

@implementation FTWindowController

- (id)initWithController:(FTController*)controller {
    if(self = [super initWithWindowNibName:@"FTWindowController"]) {
        self.controller = controller;
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    self.monitorButton.state = self.controller.monitorForChanges ? NSOnState : NSOffState;
}

- (IBAction)monitorClicked:(NSButton *)sender {
    self.controller.monitorForChanges = self.monitorButton.state == NSOnState;
}

- (IBAction)runNowClicked:(NSButton *)sender {
    [self.controller runScriptOnCurrentProject];
}

@end
