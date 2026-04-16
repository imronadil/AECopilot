#include "AEConfig.h"
#include "entry.h"
#include "AE_GeneralPlug.h"
#include "AE_Macros.h"
#include "AEGP_SuiteHandler.h" // Required to access AE's internal functions
#include "../headers/MacHook.h"

// We store these globally so our Execute function can access them later
static SPBasicSuite* s_pica_basicP = NULL;
static AEGP_PluginID s_aegp_plugin_id = 0;

// This function is called by your MacHook.mm file when Gemini replies
void ExecuteExtendScript(const char* scriptStr) {
    if (!s_pica_basicP) return;
    
    // SuiteHandler is Adobe's helper class to load API suites
    AEGP_SuiteHandler suites(s_pica_basicP);
    
    try {
        // We use UtilitySuite to execute raw ExtendScript natively
        // TRUE means we are using platform encoding (UTF-8)
        suites.UtilitySuite3()->AEGP_ExecuteScript(s_aegp_plugin_id, scriptStr, TRUE, NULL, NULL);
    } catch (...) {
        // If the AI wrote terrible code, this catch prevents AE from crashing
    }
}

extern "C" DllExport
PF_Err EntryPointFunc(
    struct SPBasicSuite *pica_basicP,
    A_long major_version,
    A_long minor_version,
    AEGP_PluginID aegp_plugin_id,
    AEGP_GlobalRefcon *global_refconP) 
{
    // Save the pointers provided by After Effects
    s_pica_basicP = pica_basicP;
    s_aegp_plugin_id = aegp_plugin_id;

    PF_Err err = A_Err_NONE;

    try {
        InitMacUIHook();
    } catch (...) {
        err = A_Err_GENERIC;
    }

    return err;
}
