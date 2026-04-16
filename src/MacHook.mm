#import <Cocoa/Cocoa.h>
#include <iostream>

// Objective-C++ file (.mm) is required to use Apple's Cocoa APIs
// This sets up a global keyboard monitor to listen for your hotkey (e.g., Ctrl+Space)

void SetupMacKeyboardHook() {
    // Note: To use addGlobalMonitorForEventsMatchingMask, your final AE plugin
    // will require macOS Accessibility permissions in System Settings.
    
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                           handler:^(NSEvent *event) {
        
        // Example: Check if the modifier flags include Control and the key is Space
        NSEventModifierFlags flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
        if ((flags & NSEventModifierFlagControl) && [event keyCode] == 49) { // 49 is Spacebar
            
            // TODO: Check if After Effects is the currently active application
            // If yes, trigger the transparent ImGui window to appear at the cursor
            std::cout << "Ctrl + Space triggered in macOS!" << std::endl;
            
        }
    }];
}
