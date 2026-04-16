#import <Cocoa/Cocoa.h>
#include "../headers/MacHook.h"

static NSWindow* gFloatingWindow = nil;
static id gEventMonitor = nil;

void CreateFloatingWindow() {
    if (gFloatingWindow) return;

    // Define the size of your search bar (Width: 600, Height: 80)
    NSRect frame = NSMakeRect(0, 0, 600, 80); 
    
    gFloatingWindow = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:NSWindowStyleMaskBorderless
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];

    // Make the window background transparent so we can use a blur effect
    [gFloatingWindow setOpaque:NO];
    [gFloatingWindow setBackgroundColor:[NSColor clearColor]];
    [gFloatingWindow setHasShadow:YES];
    [gFloatingWindow setLevel:NSFloatingWindowLevel]; // Forces it to float above AE panels
    
    // Create a modern macOS blurred background (like Spotlight)
    NSVisualEffectView* blurView = [[NSVisualEffectView alloc] initWithFrame:frame];
    [blurView setMaterial:NSVisualEffectMaterialHUDWindow];
    [blurView setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
    [blurView setState:NSVisualEffectStateActive];
    
    // Add a simple label to prove the UI works before we wire up ImGui/Text Inputs
    NSTextField* label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 560, 40)];
    [label setStringValue:@"AI Copilot Native mode active. (Phase 1)"];
    [label setTextColor:[NSColor whiteColor]];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setFont:[NSFont systemFontOfSize:24]];
    
    [blurView addSubview:label];
    [gFloatingWindow setContentView:blurView];
    [gFloatingWindow center]; // Centers it on the user's active monitor
}

void ToggleUIWindow() {
    if (!gFloatingWindow) {
        CreateFloatingWindow();
    }

    if ([gFloatingWindow isVisible]) {
        [gFloatingWindow orderOut:nil];
    } else {
        [gFloatingWindow makeKeyAndOrderFront:nil];
    }
}

void InitMacUIHook() {
    // Because this runs inside AE, a Local Monitor captures keystrokes 
    // before After Effects processes them.
    gEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                          handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        
        NSEventModifierFlags flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
        
        // 49 is the macOS keycode for Spacebar
        if ((flags & NSEventModifierFlagControl) && [event keyCode] == 49) {
            ToggleUIWindow();
            return nil; // Consume the event so AE doesn't trigger anything else
        }
        
        // 53 is the macOS keycode for Escape. Close window if visible.
        if ([event keyCode] == 53 && [gFloatingWindow isVisible]) {
            ToggleUIWindow();
            return nil; 
        }
        
        return event; // Pass all other keystrokes back to After Effects
    }];
}
