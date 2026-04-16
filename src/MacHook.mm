#import <Cocoa/Cocoa.h>
#include <string>
#include <iostream>
#include <CoreGraphics/CoreGraphics.h>
#include "../headers/MacHook.h"
#include "../headers/json.hpp" // The JSON parser we downloaded earlier

// Standard namespace for the JSON library
using json = nlohmann::json;

static NSWindow* gFloatingWindow = nil;
static CGEventTapProxy gEventTapProxy = NULL;
static CFMachPortRef gEventTap = NULL;
static CFRunLoopSourceRef gEventTapSource = NULL;
static NSTextField* gInputField = nil;
static NSTextField* gOutputLabel = nil;

// ⚠️ Insert your actual Gemini API key here
static NSString* const API_KEY = @"AIzaSyDLICoPEjnO_5e4syaoeXKkNpjzszx1EGA"; 

void FetchGeminiResponse(NSString* userPrompt) {
    // 1. Update UI on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [gOutputLabel setStringValue:@"Generating code..."];
    });

    // 2. Build the Request
    NSString* urlString = [NSString stringWithFormat:@"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=%@", API_KEY];
    NSURL* url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // 3. Construct the JSON payload (matching your old JS fetch)
    json payload = {
        {"system_instruction", {
            {"parts", {{ {"text", "You are an elite After Effects ExtendScript developer. Output ONLY valid ExtendScript code. No markdown, no explanation."} }}}
        }},
        {"contents", {{
            {"parts", {{ {"text", [userPrompt UTF8String]} }}}
        }}},
        {"generationConfig", {
            {"temperature", 0.2}
        }}
    };
    
    std::string payloadStr = payload.dump();
    NSData* postData = [NSData dataWithBytes:payloadStr.c_str() length:payloadStr.length()];
    [request setHTTPBody:postData];
    
    // 4. Send the Request Asynchronously
    NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [gOutputLabel setStringValue:[NSString stringWithFormat:@"Network Error: %@", [error localizedDescription]]];
            });
            return;
        }
        
        // 5. Parse the JSON response
        try {
            std::string jsonString((char*)[data bytes], [data length]);
            json responseJson = json::parse(jsonString);
            
            if (responseJson.contains("error")) {
                std::string errMsg = responseJson["error"]["message"].get<std::string>();
                dispatch_async(dispatch_get_main_queue(), ^{
                    [gOutputLabel setStringValue:[NSString stringWithUTF8String:errMsg.c_str()]];
                });
                return;
            }
            
            // Extract the generated text
            std::string generatedCode = responseJson["candidates"][0]["content"]["parts"][0]["text"].get<std::string>();
            
            // Strip markdown block ticks (```javascript ... ```)
            size_t startPos = generatedCode.find("```javascript");
            if (startPos != std::string::npos) generatedCode.erase(startPos, 13);
            size_t endPos = generatedCode.find("```");
            if (endPos != std::string::npos) generatedCode.erase(endPos, 3);
            
            // 6. Push the result to the UI and execute it on the Main Thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [gOutputLabel setStringValue:@"Execution complete."];
                
                // Rebuild your "Safety Net Wrapper" from the old hostscript.jsx
                std::string undoName = "AI Copilot Action";
                std::string wrappedScript = 
                    "app.beginUndoGroup('" + undoName + "');\n"
                    "try {\n"
                    "  (function() {\n" + generatedCode + "\n})();\n"
                    "} catch(err) {\n"
                    "  alert('AI Execution Error: ' + err.toString());\n"
                    "} finally {\n"
                    "  app.endUndoGroup();\n"
                    "}";
                
                // Send it to After Effects!
                ExecuteExtendScript(wrappedScript.c_str());
                
                // Hide the floating window so the user can see what changed
                ToggleUIWindow(); 
            });
            
        } catch (std::exception& e) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [gOutputLabel setStringValue:@"Error parsing JSON response."];
            });
        }
    }];
    
    [task resume];
}

void CreateFloatingWindow() {
    if (gFloatingWindow) return;

    // Made the window taller to fit the input and the output (Width: 600, Height: 160)
    NSRect frame = NSMakeRect(0, 0, 600, 160); 
    
    gFloatingWindow = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:NSWindowStyleMaskBorderless
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];

    [gFloatingWindow setOpaque:NO];
    [gFloatingWindow setBackgroundColor:[NSColor clearColor]];
    [gFloatingWindow setHasShadow:YES];
    [gFloatingWindow setLevel:NSFloatingWindowLevel];
    
    NSVisualEffectView* blurView = [[NSVisualEffectView alloc] initWithFrame:frame];
    [blurView setMaterial:NSVisualEffectMaterialHUDWindow];
    [blurView setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
    [blurView setState:NSVisualEffectStateActive];
    
    // Create the Search Input Field
    gInputField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 90, 560, 50)];
    [gInputField setPlaceholderString:@"Ask Copilot..."];
    [gInputField setFont:[NSFont systemFontOfSize:24]];
    [gInputField setFocusRingType:NSFocusRingTypeNone];
    [gInputField setBezeled:NO];
    [gInputField setDrawsBackground:NO];
    [gInputField setTextColor:[NSColor whiteColor]];
    
    // Create the Output/Status Label
    gOutputLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 560, 60)];
    [gOutputLabel setStringValue:@"Ready."];
    [gOutputLabel setTextColor:[NSColor colorWithCalibratedWhite:0.8 alpha:1.0]];
    [gOutputLabel setBezeled:NO];
    [gOutputLabel setDrawsBackground:NO];
    [gOutputLabel setEditable:NO];
    [gOutputLabel setSelectable:YES]; // Allow copying the code
    [gOutputLabel setFont:[NSFont fontWithName:@"Courier" size:12]];
    
    [blurView addSubview:gInputField];
    [blurView addSubview:gOutputLabel];
    [gFloatingWindow setContentView:blurView];
    [gFloatingWindow center];
}

void ToggleUIWindow() {
    if (!gFloatingWindow) {
        CreateFloatingWindow();
    }

    if ([gFloatingWindow isVisible]) {
        [gFloatingWindow orderOut:nil];
        [gInputField setStringValue:@""]; // Clear input on hide
    } else {
        [gFloatingWindow makeKeyAndOrderFront:nil];
        [gFloatingWindow makeFirstResponder:gInputField]; // Auto-focus the search bar
    }
}

// Global CGEventTap callback function
static CGEventRef EventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if (type == kCGEventKeyDown) {
        CGKeyCode keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        CGEventFlags flags = CGEventGetFlags(event);
        
        // Debug: Log all key presses
        NSLog(@"🔍 Key pressed - keyCode: %u, flags: %llu", keyCode, flags);
        
        // Ctrl + Space (keyCode 49 = space, Control flag)
        bool isCtrlSpaceControl = (keyCode == 49) && (flags & kCGEventFlagMaskControl);
        bool isCtrlSpaceCommand = (keyCode == 49) && (flags & kCGEventFlagMaskCommand);
        bool isCtrlSpace = isCtrlSpaceControl || isCtrlSpaceCommand;
        
        if (isCtrlSpace) {
            NSLog(@"✅ Ctrl+Space detected! (Control: %d, Command: %d)", isCtrlSpaceControl, isCtrlSpaceCommand);
            // Dispatch to main thread to update UI
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"📢 Toggling UI window...");
                ToggleUIWindow();
            });
            return NULL; // Consume the event so it doesn't propagate
        }
        
        // If window is visible, handle Escape and Enter keys
        if ([gFloatingWindow isVisible]) {
            // Escape (keyCode 53)
            if (keyCode == 53) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ToggleUIWindow();
                });
                return NULL;
            }
            
            // Enter/Return (keyCode 36)
            if (keyCode == 36) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString* prompt = [gInputField stringValue];
                    if ([prompt length] > 0) {
                        FetchGeminiResponse(prompt);
                    }
                });
                return NULL;
            }
        }
    }
    
    return event;
}

void InitMacUIHook() {
    NSLog(@"=== AECopilot: InitMacUIHook called ===");
    
    // Check if we have accessibility permissions
    if (!AXIsProcessTrusted()) {
        NSLog(@"❌ CRITICAL: AXIsProcessTrusted() = NO. AECopilot needs accessibility permissions!");
        NSLog(@"   Go to: System Preferences > Security & Privacy > Accessibility");
        NSLog(@"   Then add After Effects to the list and grant it access.");
        return;
    }
    
    NSLog(@"✅ Accessibility permissions granted");
    
    // Create the event tap to monitor global key events
    CGEventMask eventMask = CGEventMaskBit(kCGEventKeyDown);
    gEventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, eventMask, EventTapCallback, NULL);
    
    if (!gEventTap) {
        NSLog(@"❌ FAILED: CGEventTapCreate returned NULL");
        NSLog(@"   This means the event tap could not be created.");
        return;
    }
    
    NSLog(@"✅ CGEventTap created successfully");
    
    // Add to the main run loop
    gEventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, gEventTap, 0);
    if (!gEventTapSource) {
        NSLog(@"❌ FAILED: CFMachPortCreateRunLoopSource returned NULL");
        return;
    }
    
    NSLog(@"✅ RunLoop source created");
    
    CFRunLoopAddSource(CFRunLoopGetMain(), gEventTapSource, kCFRunLoopDefaultMode);
    NSLog(@"✅ Added source to main run loop");
    
    // Enable the event tap
    CGEventTapEnable(gEventTap, true);
    NSLog(@"✅ CGEventTap enabled");
    
    NSLog(@"🎉 AECopilot FULLY INITIALIZED - Ctrl+Space hotkey is ACTIVE!");
}
