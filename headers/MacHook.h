#pragma once

// Initializes the keyboard listener inside After Effects
void InitMacUIHook();

// Shows/Hides the floating custom UI
void ToggleUIWindow();

// NEW: Sends the AI-generated code string to the After Effects execution engine
void ExecuteExtendScript(const char* scriptStr);
