// plymouth_config.sp
// Plymouth theme configuration

// You are free to modify this file for configuring the theme.
// But, I'd recommend keeping the original integrity of this file and using pv_conf.sh instead.
// Simply, compile the theme and run pv_conf.sh to configure.
#USED_BY_PV_CONF

//This key is reserved for fading service. Please don't modify it, especially when you set Pref to 1.
//Accepted values:
//sddm: Won't show the fade that is applied to the shutdown and reboot screen.
//desktop: Will show the fade that is applied to the shutdown and reboot screen.
global.OsState = "desktop";

//This is reserved for the fake logoff screen service, which isn't available yet, lol.
//Accepted Values:
//1: Show the logoff screen instead of the shutdown screen.
//0: Show the shutdown screen instead of the logoff screen.
global.SpawnFakeLogoff = 0;

//Used for whether the hibernation resume screen should be shown or not. Please don't modify it if you use hibernation services.
//Accepted Values:
//1: Show hibernation resume screen.
//0: Show normal boot screen.
global.ReturnFromHibernation = 0;

//This key is reserved for the uninstallation script, which will revert to the previous Plymouth theme.
global.OldPlymouthTheme = "";

//Pref:
//Fading preference for the shutdown and reboot screens.
//Accepted values:
//1: Use OsState value to determine whether fade should be shown or not on the shutdown and reboot screen.
//2: Always show the fade.
//3 - Never show the fade.
global.Pref = 3;

//Defines whether hibernation should be used or not.
//This value is only read by install.sh to add/remove hibernation services.
//Accepted values:
//1: Install hibernation services,
//2: Uninstall hibernation services, if they are present.
global.UseHibernation = 0;

//Defined whether annoying wall messages should be disabled or not.
//This value is only read by `install.sh` to add/remove no-wall services.
//Accepted values:
//0: Keep wall messages.
//1: Disable wall messages.
global.DisableWall = 0;

//Title of the password screen
//Prerequisites:
//Must be a single line of text,
//Allowed up to 74 characters.
//Default value:
//"Aero7 Boot Manager"
global.PasswordTitle = "Aero7 Boot Manager";

//Overrides the message of the password screen with its value.
//Prerequisites:
//Must be a single line of text,
//Allowed up to 74 characters.
//Default value:
//""
global.OverriddenPasswordMessage = "";

//Text that is shown above the textbox.
//
//Default value:
//"Password"
global.PasswordText = "Password";

//Title of the password screen
//Prerequisites:
//Must be a single line of text,
//Allowed up to 74 characters.
//Default value:
//"Aero7 Boot Manager"
global.AnswerTitle = "Aero7 Boot Manager";

//Overrides the message of the password screen with its value.
//Prerequisites:
//Must be a single line of text,
//Allowed up to 74 characters.
//Default value:
//""
global.OverriddenAnswerMessage = "";

//Text that is shown above the textbox.
//Default value:
//"Password"
global.AnswerText = "Password";

//Defines whether elements in the Boot Manager screen (password and answer screen), such as rectangles and texts, should be scaled or not.
//Default is set to 0 because the screen may look weird.
//Accepted values:
//1: Scale elements.
//0: Don't scale elements.
global.ScaleBootManager = 0;

//Text that is shown when the system is shutting down.
//Prerequisites:
//Only a single line of text is allowed. Don't use /n.
//If you modified this key after installation, please re-run gen_blur.sh.
//Default value:
//"Shutting down..."
global.ShutdownText = "Shutting down...";

//Text that is shown when the system is rebooting.
//Use distinct shutdown and reboot labels so the current action is clear.
//Prerequisites:
//Only a single line of text is allowed. Don't use /n.
//If you modified this key after installation, please re-run gen_blur.sh.
//Default value:
//"Rebooting..."
global.RebootText = "Rebooting...";

//Text that is shown when the fake logoff will be shown.
//Prerequisites:
//Only a single line of text is allowed. Don't use /n.
//If you modified this key after installation, please re-run gen_blur.sh.
//Default value:
//"Logging off..."
global.LogoffText = "Logging off...";

//Text that is shown when the system is updating.
//This text supports formatting. Use %i for number.
//You can also use newline, unlike other screens. Simply use \n for newlines.
//If you modified this key after installation, please re-run gen_blur.sh.
//Prerequisites
//Default Value:
//"Configuring Aero7 updates\n%i% complete\nDo not turn off your computer."
global.UpdateTextMTL = "Configuring Aero7 updates\n%i% complete\nDo not turn off your computer.";

//Defines whether the shadow effect should be applied or not.
//Setting this value to 1 after installation requires re-running gen_blur.sh.
//Accepted values:
//0: Don't show a text shadow.
//1: Show a text shadow.
global.UseShadow = 1;

//Selects the Aero7 shutdown, reboot, and update artwork.
global.AuthuiStyle = "7";

//The text displayed while Aero7 starts normally.
//Default value:
//"Starting Aero7"
global.StartingText = "Starting Aero7";

//The text displayed while Aero7 returns from hibernation.
//Default value:
//"Resuming Aero7"
global.ResumingText = "Resuming Aero7";

//Project text displayed at the bottom center of the boot screen.
//Default value:
//"Aero7 Open Project"
global.CopyrightText = "Aero7 Open Project";

//Slows down your boot in seconds.
//Works when the plymouth-vista-slow-boot-animation.service is enabled.
//If you don't want to slow down your boot, keep this value as 0.
//Default value:
//0
global.BootSlowdown = 0;

#END_USED_BY_PV_CONF

// Do not modify this!
fun ReadOsState() {
    if (global.Pref == 1) {
        if (global.SpawnFakeLogoff) {
            // Logoff screen will spawn only when user is logging off, 
            // We can safely ignore this because it will return to value 'sddm' when we logoff.
            // Use global.Pref to configure this.
            return "desktop";
        }
        
        return global.OsState;
    }
    else if (global.Pref == 2) {
        return "desktop";
    }
    else {
        return "sddm";
    }
}
