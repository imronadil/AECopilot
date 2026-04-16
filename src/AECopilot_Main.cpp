#include "AEConfig.h"
#include "entry.h"
#include "AE_GeneralPlug.h"
#include "AE_Macros.h"
#include "../headers/MacHook.h"

extern "C" DllExport
PF_Err EntryPointFunc(
    struct SPBasicSuite *pica_basicP,
    A_long major_version,
    A_long minor_version,
    AEGP_PluginID aegp_plugin_id,
    AEGP_GlobalRefcon *global_refconP) 
{
    PF_Err err = A_Err_NONE;

    try {
        // Start listening for Ctrl + Space immediately when AE loads
        InitMacUIHook();
        
    } catch (...) {
        err = A_Err_GENERIC;
    }

    return err;
}
