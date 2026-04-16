#import <Cocoa/Cocoa.h>
#include <string>
#include <iostream>
#include "../headers/MacHook.h"
#include "../headers/json.hpp" // The JSON parser we downloaded earlier

// Standard namespace for the JSON library
using json = nlohmann::json;

static NSWindow* gFloatingWindow = nil;
static id gEventMonitor = nil;
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
            
            // 6. Push the result back to the UI
            dispatch_async(dispatch_get_main_queue(), ^{
                [gOutputLabel setStringValue:[NSString stringWithUTF8String:generatedCode.c_str()]];
                
                // TODO: PHASE 3 - Send this generatedCode to AEGP_ExecuteScript!
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

void InitMacUIHook() {
    gEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                          handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        
        NSEventModifierFlags flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
        unsigned short keyCode = [event keyCode];
        
        // Ctrl + Space -> Toggle Window
        if ((flags & NSEventModifierFlagControl) && keyCode == 49) {
            ToggleUIWindow();
            return nil; 
        }
        
        if ([gFloatingWindow isVisible]) {
            // Escape -> Close Window
            if (keyCode == 53) {
                ToggleUIWindow();
                return nil; 
            }
            
            // Enter/Return -> Submit Prompt to Gemini
            if (keyCode == 36) {
                NSString* prompt = [gInputField stringValue];
                if ([prompt length] > 0) {
                    FetchGeminiResponse(prompt);
                }
                return nil;
            }
        }
        
        return event; 
    }];
}
