;................................................................................
;																				.
; app ...........: tigerlily's Screen Dimmer									.
; version .......: 0.4.0														.
;																				.
;................................................................................
;																				.
; author ........: tigerlily													.
; language ......: AutoHotkey V2 (alpha 122-f595abc2)							.
; github repo ...: https://git.io/tigerlilysScreenDimmer   						.
; forum thread ..: https://bit.ly/tigerlilys-screen-dimmer-AHK-forum			.
; license .......: MIT (https://git.io/tigerlilysScreenDimmerLicense)			.
;																				.
;................................................................................
; [CHANGE LOG], [PENDING] and [REMARKS] @ bottom of script						.
;................................................................................


;................................................................................
;		   ...........................................................			.
;           A U T O - E X E C U T E   &   I N I T I A L I Z A T I O N			.
;................................................................................

#SingleInstance
global mon := Monitor.New()


;................................................................................
;					  ..................................						.
;                      T R A Y  M E N U   &   I C O N S		                 	.
;................................................................................

;	Set Icon ToolTip and App Name
A_IconTip := "tigerlily's Screen Dimmer"

; Create tray menu with only a "Close App" option
,	A_TrayMenu.Delete()
,	A_TrayMenu.Add(A_IconTip, (*) => monitorMenu.Show()) 
,	A_TrayMenu.Add() 
,	A_TrayMenu.Add("Close", (*) => ExitApp()) 

; Allows a single left-click on taskbar icon to open monitor menu
,	OnMessage(0x404, (wParam, lParam, *) => lParam = 0x201 ? monitorMenu.Show() : "") 

; Try to download and set tray/menu icons without keeping images saved locally
try Download("https://i.imgur.com/WQsv9rk.png", A_ScriptDir "\tray-icon.png")
try Download("https://i.imgur.com/Ea1kZrE.png", A_ScriptDir "\close-app.png")
try TraySetIcon(A_ScriptDir "\tray-icon.png")
try A_TrayMenu.SetIcon(A_IconTip , A_ScriptDir "\tray-icon.png")
try A_TrayMenu.SetIcon("Close" , A_ScriptDir "\close-app.png")
(FileExist(A_ScriptDir "\tray-icon.png")) ? FileDelete(A_ScriptDir "\tray-icon.png") : ""
(FileExist(A_ScriptDir "\close-app.png")) ? FileDelete(A_ScriptDir "\close-app.png") : ""



;................................................................................
;								     .......		        					.
;                                     G U I       		                    	.
;................................................................................

; Create monitor config menu
	monitorMenu := Gui.New("Resize", A_IconTip)
,   monitorMenu.OnEvent("Close", (monitorMenu) => monitorMenu.Hide() )
,   monitorMenu.OnEvent("Size" , (monitorMenu, MinMax, *) => MinMax = -1 ? monitorMenu.Hide() : "" )
,   monitorMenu.SetFont("c0xC6C8C5 s8 bold")
,   monitorMenu.BackColor := 0x000000,   monitorMenu.MarginX := 20,   monitorMenu.MarginY := 20

; Get all monitor info
,   info := mon.GetInfo()
,   monitorCount := info.Length

;	x, y, width, height associative arrays to hold monitor coords, etc.
,   x := Map(), y := Map(), w := Map(), h := Map()

; Create config tabs
,   monitorMenuTabs := monitorMenu.Add("Tab3", , MonitorTabs())

;	Create empty associative arrays to hold each GUI control object for each monitor found
#Warn VarUnset, Off ; Stops useless warnings from being thrown due to dynamic variable/object creation below

;	Note: going to replace the psuedo-arrays with proper Map() objects eventually
for feature in features := ["gammaAll", "gammaRed", "gammaGreen", "gammaBlue", "contrast", "brightness", "dimmer"]
{
 	%feature%Slider			:= Map() ; slider controls
,	%feature%Title			:= Map() ; title text controls
,	%feature%SliderStart	:= Map() ; slider front-end control ("0")
,	%feature%SliderEnd		:= Map() ; slider back-end control ("100")
,	%feature%Slider_Change	:= Map() ; OnEvent functions
}
PowerOnRadio := Map(), PowerOnRadio_Change := Map(), PowerOffRadio := Map(), PowerOffRadio_Change := Map()
,	  dimmer := Map()

;	Detect hidden windows so script can see transparent dimmer overlay GUIs when present
,	DetectHiddenWindows("On")

; iterate [once for each monitor found plus 1] OR [only once for single-monitor setups]
while ((i := A_Index - ( monitorCount > 1 ? 1 : 0)) <= monitorCount)
{
	; Use the correct tab for each monitor / all monitor config
    monitorMenuTabs.UseTab( monitorCount = 1 ? "Monitor" : (!i ? "All Monitors" : "Monitor " i))

	; Get gamma output for each monitor and set All Monitors Config gamma to 100% initially
    g := (i ? mon.GetGammaRamp(i) : 100) 

    if (i)	; Specific to each monitor (e.g. not ALL monitors)
    {
	;	Get each monitor's gamma output levels	
        gR := g["Red"], gG := g["Green"], gB := g["Blue"]

	;	Get each monitor's x & y coords, width, height
    ,   x[i] := info[i]["Left"], y[i] := info[i]["Top"]			
    ,   w[i] := info[i]["Right"] - x[i], h[i] := info[i]["Bottom"] - y[i]
	
	;	Create Dimmer (Black Overlay)
    ,   dimmer[i] := Gui.New("+AlwaysOnTop +Owner +E0x20 +ToolWindow -DPIscale -Caption -SysMenu")	
    ,   dimmer[i].BackColor := "0x000000" ; Sets dimmer color as pure black

	;	Determine monitor capabilities for each monitor for brightness, contrast, power mode
        try 
        {
            b  := mon.GetBrightness(i)["Current"]
            brightnessCapability := true
        }    
        catch
            brightnessCapability := false
            
        try 
        {
            c  := mon.GetContrast(i)["Current"]
            contrastCapability := true
        }    
        catch
            contrastCapability := false
            
        try 
        {
            p  := mon.GetPowerMode(i)
            powerCapability := true
        }    
        catch
            powerCapability := false    
    }

;	Create Monitor Config controls
    gammaAllTitle[i] := monitorMenu.Add("Text", "w200 Center", "Gamma (All):")
,   gammaAllSliderStart[i] := monitorMenu.Add("Text", "Section", "0")
,   gammaAllSlider[i] := monitorMenu.Add("Slider", "ys AltSubmit ToolTip TickInterval10 Page10 Thick30 vGammaAllSlider" i, 100)
,   gammaAllSliderEnd[i] := monitorMenu.Add("Text", "ys", "100")
,   gammaAllSlider[i].OnEvent("Change", "GammaAllSlider_Change")

,   gammaRedTitle[i] := monitorMenu.Add("Text", "w200 xs Center", "Gamma (Red):")
,   gammaRedSliderStart[i] := monitorMenu.Add("Text", "xs Section", "0")
,   gammaRedSlider[i] := monitorMenu.Add("Slider", "ys AltSubmit ToolTip TickInterval10 Page10 Thick30 vGammaRedSlider" i, (i ? gR : 100))
,   gammaRedSliderEnd[i] := monitorMenu.Add("Text", "ys", "100")
,   gammaRedSlider[i].OnEvent("Change", "GammaRedSlider_Change")

,   gammaGreenTitle[i] := monitorMenu.Add("Text", "w200 xs Center", "Gamma (Green):")
,   gammaGreenSliderStart[i] := monitorMenu.Add("Text", "xs Section", "0")
,   gammaGreenSlider[i] := monitorMenu.Add("Slider", "ys AltSubmit ToolTip TickInterval10 Page10 Thick30 vGammaGreenSlider" i, (i ? gG : 100))
,   gammaGreenSliderEnd[i] := monitorMenu.Add("Text", "ys", "100")
,   gammaGreenSlider[i].OnEvent("Change", "GammaGreenSlider_Change")

,   gammaBlueTitle[i] := monitorMenu.Add("Text", "w200 xs Center", "Gamma (Blue):")
,   gammaBlueSliderStart[i] := monitorMenu.Add("Text", "xs Section", "0")
,   gammaBlueSlider[i] := monitorMenu.Add("Slider", "ys AltSubmit ToolTip TickInterval10 Page10 Thick30 vGammaBlueSlider" i, (i ? gB : 100))
,   gammaBlueSliderEnd[i] := monitorMenu.Add("Text", "ys", "100")
,   gammaBlueSlider[i].OnEvent("Change", "GammaBlueSlider_Change")

,   brightnessTitle[i] := monitorMenu.Add("Text", "w200 xs+220 ym+58 Center", "Brightness:")
,   brightnessSliderStart[i] := monitorMenu.Add("Text", "xp yp+40 Section", "0")
,   brightnessSlider[i] := monitorMenu.Add("Slider", "ys AltSubmit ToolTip TickInterval10 Page10 Thick30 " (i ? (IsSet(b) ? "" : "Disabled") : "") " vBrightnessSlider" i, (i ? (IsSet(b) ? b : 0) : 100))
,   brightnessSliderEnd[i] := monitorMenu.Add("Text", "ys", "100")
,   brightnessSlider[i].OnEvent("Change", "BrightnessSlider_Change")

,   contrastTitle[i] := monitorMenu.Add("Text", "w200 xs Center", "Contrast:")
,   contrastSliderStart[i] := monitorMenu.Add("Text", "xs Section", "0")
,   contrastSlider[i] := monitorMenu.Add("Slider", "ys AltSubmit ToolTip TickInterval10 Page10 Thick30 " (i ? (IsSet(c) ? "" : "Disabled") : "") "  vContrastSlider" i, (i ? (IsSet(c) ? c : 0) : 100))
,   contrastSliderEnd[i] := monitorMenu.Add("Text", "ys", "100")
,   contrastSlider[i].OnEvent("Change", "ContrastSlider_Change")    

,   dimmerTitle[i] := monitorMenu.Add("Text", "w200 xs Center", "Dimmer (Overlay):")
,   dimmerSliderStart[i] := monitorMenu.Add("Text", "xs Section", "0")
,   dimmerSlider[i] := monitorMenu.Add("Slider", "ys AltSubmit ToolTip TickInterval10 Page10 Thick30 vDimmerSlider" i, 0)
,   dimmerSliderEnd[i] := monitorMenu.Add("Text", "ys", "100")
,   dimmerSlider[i].OnEvent("Change", "DimmerSlider_Change")    

,   PowerOnRadio[i] := monitorMenu.Add("Radio", "xs Group " (i ? (IsSet(p) ? "" : "Disabled") : "") "  vPowerOnRadio" i, "Turn " ( i ? "Monitor" : "All Monitors" ) " On")
,   PowerOffRadio[i] := monitorMenu.Add("Radio", "xs " (i ? (IsSet(p) ? "" : "Disabled") : "") "  vPowerOffRadio" i, "Turn " ( i ? "Monitor" : "All Monitors" ) " Off")
,	PowerOnRadio[i].OnEvent("Click", "Power_Change")    
,	PowerOffRadio[i].OnEvent("Click", "Power_Change")    
}

monitorMenuTabs.UseTab("Advanced Settings")
,	monitorMenu.Add("Text", "w400", 
	"Background Modes:`n`n"
	"Some backgrounds in programs like Excel or Notepad are terribly white and even in the day time can be way too bright. The following Background Modes helps partially solve this issue by changing the background, window, and text colors system-wide.`n`n"
	"(This will reset to default system colors when you close this app)")
,	BackgroundNormalModeRadio := monitorMenu.Add("Radio", "Group vNormal", "Normal Mode (default)").OnEvent("Click", "BackgroundMode_Change") 
,	BackgroundMorningModeRadio := monitorMenu.Add("Radio", "vMorning", "Morning Mode").OnEvent("Click", "BackgroundMode_Change")
,	BackgroundDayModeRadio := monitorMenu.Add("Radio", "vDay", "Day Mode").OnEvent("Click", "BackgroundMode_Change")
,	BackgroundNightModeRadio := monitorMenu.Add("Radio", "vNight", "Night Mode").OnEvent("Click", "BackgroundMode_Change")
,	BackgroundMidnightModeRadio := monitorMenu.Add("Radio", "vMidnight", "Midnight Mode").OnEvent("Click", "BackgroundMode_Change")

,	monitorMenuTabs.UseTab("App Info / Report Bug")
,	monitorMenu.Add("Link", "w400 Center", 
	"Thanks so much for choosing to use tigerlily's Screen Dimmer!`n`n"
	"I hope you really enjoy this screen dimmer as I believe it is the best one out there. f.lux, iris, and other well known screen dimmers do not give as much control as I would like and sometimes only create a transparent black screen overlay, which is prone to annoyances.`n`n"
	"This screen dimmer allows you to adjust actual gamma color output, making your screen completely stop emitting blue, green, or red light if desired, which is way more beneficial than an arbitrary color temperature or simple screen overlay. `n`n"
	"It also allows you to turn on/off your monitors with a click of a button, which can sometimes help with focusing on a multi-monitor setup.`n`n"
	"This is a work in progress, but will eventually contain customizable hotkeys, custom timers, color temperature settings, and more.`n`n`n"
	"Please report any bugs at either:`n`n"
	"<a href=`"https://git.io/tigerlilysScreenDimmer`">---> GitHub Repository</a>`n`n" 
	"<a href=`"https://bit.ly/tigerlilys-screen-dimmer-AHK-forum`">---> AutoHotkey Forum Thread</a>`n`n`n"
	"Feel free email me directly about bugs and about any desired features you want me to add at: <a href=`"mailto: tigerlily.developer@gmail.com`">tigerlily.developer@gmail.com</a>")


; Sets "All Monitors" Tab sliders if all monitors have matching current feature setting values
if (monitorCount > 1)
{
	; Note: Going to replace dynamic variables with proper Map() objects at some point
	for feature in ["gammaRed", "gammaGreen", "gammaBlue", "contrast", "brightness"]
	{
		while ((i := A_Index) <= monitorCount)
		{
			r := (i < monitorCount ? (i + 1) : 1)
			if (%feature%Slider[i].Value = %feature%Slider[r].Value)
			{
				load%feature%All := true
			}
			else
			{
				load%feature%All := false
				break
			}			
		}

		load%feature%All = true ? %feature%Slider[0].Value := %feature%Slider[1].Value : ""

		if (feature = "gammaRed"   && load%feature%All = true 
		||  feature = "gammaGreen" && load%feature%All = true 
		||  feature = "gammaBlue"  && load%feature%All = true)
		{
			loadAll%feature%All := true
		}	
		else
		{
			loadAll%feature%All := false
		}	

	}
	if (loadAllgammaRedAll = true && loadAllgammaGreenAll = true && loadAllgammaBlueAll = true)
		gammaAllSlider[0].Value := gammaRedSlider[1].Value
}
monitorMenu.Show()



;................................................................................
;								  ...............								;
;                                  H O T K E Y S		                    	;
;................................................................................


;   Close app
^Esc::ExitApp()


;   Open config
!t::
{
    global
    monitorMenu.Show()
}

;   Emergency gamma reset hotkey
!x::
{        
    global
    Loop( monitorCount )
        mon.SetGammaRamp( , , , A_Index)
}



;................................................................................
;								...................								;
;                                F U N C T I O N S		                    	;
;................................................................................


MonitorTabs(){ ; Creates tabs based on # of monitors found

    global
    if (monitorCount = 1)
        return ["Monitor", "Advanced Settings", "App Info / Report Bug"]
    else
    {    
        monitorTabs := ["All Monitors"]
        Loop(monitorCount)
            monitorTabs.Push("Monitor " A_Index)
        monitorTabs.Push("Advanced Settings"), monitorTabs.Push("App Info / Report Bug")
        return monitorTabs
    }
}

GammaAllSlider_Change(sliderAllObj, *){

    global
    g := sliderAllObj.Value        
    if (monitorNumber := Integer(SubStr(sliderAllObj.Name, -1)))
    {
        mon.SetGammaRamp(
            gammaRedSlider[monitorNumber].Value := g, 
            gammaGreenSlider[monitorNumber].Value := g, 
            gammaBlueSlider[monitorNumber].Value := g, 
            monitorNumber)
    }
    else
    {
        Loop(monitorCount)
        {
            gammaAllSlider[A_Index].Value := g
        ,   mon.SetGammaRamp(
                gammaRedSlider[A_Index].Value := g, 
                gammaGreenSlider[A_Index].Value := g, 
                gammaBlueSlider[A_Index].Value := g, 
                A_Index)   
        ,   gammaRedSlider[0].Value := g
        ,   gammaGreenSlider[0].Value := g
        ,   gammaBlueSlider[0].Value := g
        }    
    }                             
}

GammaRedSlider_Change(sliderRedObj, *){

    global        
    gR := sliderRedObj.Value
    if (monitorNumber := Integer(SubStr(sliderRedObj.Name, -1)))
    {
        g := mon.GetGammaRamp(monitorNumber), gG := g["Green"], gB := g["Blue"]
    ,   mon.SetGammaRamp(gammaRedSlider[monitorNumber].Value := gR, gG, gB, monitorNumber)
    }    
    else
    {
        Loop(monitorCount)
        {
            g := mon.GetGammaRamp(A_Index), gG := g["Green"], gB := g["Blue"]
        ,   mon.SetGammaRamp(gammaRedSlider[A_Index].Value := gR, gG, gB, A_Index)
        }
    }    
}

GammaGreenSlider_Change(sliderGreenObj, *){

    global        
    gG := sliderGreenObj.Value
    if (monitorNumber := Integer(SubStr(sliderGreenObj.Name, -1)))
    {
        g := mon.GetGammaRamp(monitorNumber), gR := g["Red"], gB := g["Blue"]
    ,   mon.SetGammaRamp(gR, gammaGreenSlider[monitorNumber].Value := gG, gB, monitorNumber)
    }    
    else
    {
        Loop(monitorCount)
        {
            g := mon.GetGammaRamp(A_Index), gR := g["Red"], gB := g["Blue"]
        ,   mon.SetGammaRamp(gR, gammaGreenSlider[A_Index].Value := gG, gB, A_Index)
        }
    }    
}

GammaBlueSlider_Change(sliderBlueObj, *){

    global        
    gB := sliderBlueObj.Value
    if (monitorNumber := Integer(SubStr(sliderBlueObj.Name, -1)))
    {
        g := mon.GetGammaRamp(monitorNumber), gR := g["Red"], gG := g["Green"]
    ,   mon.SetGammaRamp(gR, gG, gammaBlueSlider[monitorNumber].Value := gB, monitorNumber)
    }    
    else
    {
        Loop(monitorCount)
        {
            g := mon.GetGammaRamp(A_Index), gR := g["Red"], gG := g["Green"]
        ,   mon.SetGammaRamp(gR, gG, gammaBlueSlider[A_Index].Value := gB, A_Index)
        }
    }    
}

BrightnessSlider_Change(sliderObj, *){

    global       
    Sleep(500)   
    if (brightnessCapability) 
    {
        brightness := sliderObj.Value
        if (monitorNumber := Integer(SubStr(sliderObj.Name, -1)))
            mon.SetBrightness(brightness, monitorNumber)
        else
            Loop(monitorCount)
                mon.SetBrightness(brightnessSlider[A_Index].Value := brightness, A_Index)
    }
}

ContrastSlider_Change(sliderObj, *){

    global    
    Sleep(500)   
    if (contrastCapability) 
    {
        contrast := sliderObj.Value
        if (monitorNumber := Integer(SubStr(sliderObj.Name, -1)))
            mon.SetContrast(contrast, monitorNumber)
        else
            Loop(monitorCount)
                mon.SetContrast(contrastSlider[A_Index].Value := contrast, A_Index)
    }
}

DimmerSlider_Change(sliderObj, *){

    global   
    dim := sliderObj.Value * 2.55
    if (monitorNumber := Integer(SubStr(sliderObj.Name, -1)))  
    {   
        if (dim)
        {
            WinSetTransparent( dim, "ahk_id " dimmer[monitorNumber].hWnd )
        ,   dimmer[monitorNumber].Show( "x" x[monitorNumber] " y" y[monitorNumber] " w" w[monitorNumber] " h" h[monitorNumber] )
        }
        else
        {
            WinSetTransparent( dim, "ahk_id " dimmer[monitorNumber].hWnd )
        ,   dimmer[monitorNumber].Hide()
        }
    }
    else
    {
        Loop(monitorCount)
        {
            if (dim)
            {
                WinSetTransparent( dim, "ahk_id " dimmer[A_Index].hWnd )
            ,   dimmer[A_Index].Show( "x" x[A_Index] " y" y[A_Index] " w" w[A_Index] " h" h[A_Index] )
            }
            else
            {
                WinSetTransparent( dim, "ahk_id " dimmer[A_Index].hWnd )
            ,   dimmer[A_Index].Hide()
            }  
        }      
    }        
}

Power_Change(radioObj, *){

    global          
    if (powerCapability) 
    {
        if (InStr(radioObj.Name, "On"))
        {
            if (monitorNumber := Integer(SubStr(radioObj.Name, -1)))
			{
                mon.SetPowerMode("On", monitorNumber)
            ,	PowerOnRadio[monitorNumber].Value := 0
			}	
            else
            {
                Loop(monitorCount)
                {
                    mon.SetPowerMode("On", A_Index)
                ,	PowerOnRadio[0].Value := 0
                }    
            }        
        }        
        else ; if (InStr(radioObj.Name, "Off"))
        {
            if (monitorNumber := Integer(SubStr(radioObj.Name, -1)))
			{
				mon.SetPowerMode("PowerOff", monitorNumber)
			,	PowerOffRadio[monitorNumber].Value := 0
			}
            else
            {
                Loop(monitorCount)
                {
                    mon.SetPowerMode("PowerOff", A_Index)
                ,	PowerOffRadio[0].Value := 0
                }    
            }        
        }
    }        
}

BackgroundMode_Change(radioObj, *){

	static user := DllCall("user32\GetSysColor", "int", 1) ; Desktop background color
	static backgroundModes := Map(
		"Normal"  , Map(0, 0xC8C8C8, 1, user, 2, 0xD1B499, 3, 0xDBCDBF, 4, 0xF0F0F0, 5, 0xFFFFFF, 6, 0x646464, 7, 0x0, 8, 0x0, 9, 0x0, 10, 0xB4B4B4, 11, 0xFCF7F4, 12, 0xABABAB, 13, 0xD77800, 14, 0xFFFFFF, 15, 0xF0F0F0, 16, 0xA0A0A0, 17, 0x6D6D6D, 18, 0x0, 19, 0x0, 20, 0xFFFFFF, 21, 0x696969, 22, 0xE3E3E3, 23, 0x0, 24, 0xE1FFFF, 25, 0x0, 26, 0xCC6600, 27, 0xEAD1B9, 28, 0xF2E4D7, 29, 0xD77800, 30, 0xF0F0F0),
		"Morning" , Map(0, 0xC7EDCC, 1, user, 2, 0xD1B499, 3, 0xC7EDCC, 4, 0xC7EDCC, 5, 0xC7EDCC, 6, 0x646464, 7, 0x0, 8, 0x0, 9, 0x0, 10, 0xB4B4B4, 11, 0xFCF7F4, 12, 0xC7EDCC, 13, 0xD77800, 14, 0xFFFFFF, 15, 0xC7EDCC, 16, 0xA0A0A0, 17, 0x6D6D6D, 18, 0x0, 19, 0x0, 20, 0xFFFFFF, 21, 0x696969, 22, 0xE3E3E3, 23, 0x0, 24, 0xE1FFFF, 25, 0x0, 26, 0xCC6600, 27, 0xEAD1B9, 28, 0xF2E4D7, 29, 0xD77800, 30, 0xF0F0F0),
		"Day"	  , Map(0, 0xABABAB, 1, user, 2, 0xD1B499, 3, 0xABABAB, 4, 0xABABAB, 5, 0xABABAB, 6, 0x646464, 7, 0x0, 8, 0x0, 9, 0x0, 10, 0xB4B4B4, 11, 0xFCF7F4, 12, 0xABABAB, 13, 0xD77800, 14, 0xFFFFFF, 15, 0xABABAB, 16, 0xA0A0A0, 17, 0x6D6D6D, 18, 0x0, 19, 0x0, 20, 0xFFFFFF, 21, 0x696969, 22, 0xE3E3E3, 23, 0x0, 24, 0xE1FFFF, 25, 0x0, 26, 0xCC6600, 27, 0xEAD1B9, 28, 0xF2E4D7, 29, 0xD77800, 30, 0xF0F0F0),
		"Night"	  , Map(0, 0x0, 1, 0x0, 2, 0x222223, 3, 0x222223, 4, 0x222223, 5, 0x222223, 6, 0x0, 7, 0x0, 8, 0xC6C8C5, 9, 0xC6C8C5, 10, 0x0, 11, 0x0, 12, 0x222223, 13, 0x5A5A57, 14, 0xC6C8C5, 15, 0x222223, 16, 0x0, 17, 0x808080, 18, 0xC6C8C5, 19, 0xC6C8C5, 20, 0x5A5A57, 21, 0x0, 22, 0x5A5A57, 23, 0xC6C8C5, 24, 0x0, 26, 0xF0B000, 27, 0x0, 28, 0x0, 29, 0x5A5A57, 30, 0x0),
		"Midnight", Map(0, 0x0, 1, 0x0, 2, 0x222223, 3, 0x0, 4, 0x0, 5, 0x0, 6, 0x0, 7, 0x0, 8, 0xC6C8C5, 9, 0xC6C8C5, 10, 0x0, 11, 0x0, 12, 0x0, 13, 0x5A5A57, 14, 0xC6C8C5, 15, 0x0, 16, 0x0, 17, 0x808080, 18, 0xC6C8C5, 19, 0xC6C8C5, 20, 0x5A5A57, 21, 0x0, 22, 0x5A5A57, 23, 0xC6C8C5, 24, 0x0, 26, 0xF0B000, 27, 0x0, 28, 0x0, 29, 0x5A5A57, 30, 0x0))

	for displayElement, color in backgroundModes[radioObj.Name]
		DllCall("user32\SetSysColors", "Int", 1, "IntP", displayElement, "UIntP", color)
}

;   Reset gamma on exit
OnExit("ResetGammaAndBackgroundMode")
ResetGammaAndBackgroundMode(*){

    global
    Loop( monitorCount ) 
        mon.SetGammaRamp( , , , A_Index) 

	resetBackgroundMode := {}
	resetBackgroundMode.Name := "Normal"
	BackgroundMode_Change(resetBackgroundMode)       
}



;................................................................................
;								  ................								;
;                                  C L A S S E S		                    	;
;................................................................................

;   Monitor Configuration Class
;   https://git.io/MonitorConfigurationClass

;   This is a stripped down version, including only what's needed for app
;	full version for v2 can be found above

class Monitor { 

; ===== PUBLIC METHODS ============================================================================== ;
	
	
	; ===== GET METHODS ===== ;
	
	GetInfo() => this.EnumDisplayMonitors()
	
	GetBrightness(Display := "") => this.GetSetting("GetMonitorBrightness", Display)
	
	GetContrast(Display := "") => this.GetSetting("GetMonitorContrast", Display)
	
	GetGammaRamp(Display := "") => this.GammaSetting("GetDeviceGammaRamp", , , , Display)
	
	GetPowerMode(Display := ""){
		
		static PowerModes := Map(
		0x01, "On"      , 
		0x02, "Standby" , 
		0x03, "Suspend" , 
		0x04, "Off"     ,
		0x05, "PowerOff")
		
		return PowerModes[this.GetSetting("GetVCPFeatureAndVCPFeatureReply", Display, 0xD6)["Current"]]
	}
	

	; ===== SET METHODS ===== ;
	
	SetBrightness(Brightness, Display := "") => this.SetSetting("SetMonitorBrightness", Brightness, Display)
	
	SetContrast(Contrast, Display := "") => this.SetSetting("SetMonitorContrast", Contrast, Display)
	
	SetGammaRamp(Red := 100, Green := 100, Blue := 100, Display := "") => this.GammaSetting("SetDeviceGammaRamp", Red, Green, Blue, Display)

	SetPowerMode(PowerMode, Display := ""){
	
		static PowerModes := Map(
		"On"   	  , 0x01, 
		"Standby" , 0x02,
		"Suspend" , 0x03, 
		"Off"	  , 0x04, 
		"PowerOff", 0x05)
		
		if (PowerModes.Has(PowerMode))
			if (this.SetSetting("SetMonitorVCPFeature", 0xD6, Display, PowerModes[PowerMode]))
				return PowerMode
		throw Exception("An invalid [PowerMode] parameter was passed to the SetPowerMode() Method.")
	}		

	
; ===== PRIVATE METHODS ============================================================================= ;
	
	
	; ===== CORE MONITOR METHODS ===== ;
	
	EnumDisplayMonitors(hMonitor := ""){
			    
		static EnumProc := CallbackCreate(Monitor.GetMethod("MonitorEnumProc").Bind(Monitor),, 4)
		static DisplayMonitors := []
		
		if (!DisplayMonitors.Length)
			if !(DllCall("user32\EnumDisplayMonitors", "ptr", 0, "ptr", 0, "ptr", EnumProc, "ptr", ObjPtrAddRef(DisplayMonitors), "uint"))
				return false
		return DisplayMonitors    
	}
	
	static MonitorEnumProc(hMonitor, hDC, pRECT, ObjectAddr){

		DisplayMonitors := ObjFromPtrAddRef(ObjectAddr)
		MonitorData := Monitor.GetMonitorInfo(hMonitor)
		DisplayMonitors.Push(MonitorData)
		return true
	}
	
	static GetMonitorInfo(hMonitor){ ; (MONITORINFO = 40 byte struct) + (MONITORINFOEX = 64 bytes)
	
		NumPut("uint", 104, MONITORINFOEX := BufferAlloc(104))
		if (DllCall("user32\GetMonitorInfo", "ptr", hMonitor, "ptr", MONITORINFOEX)){
			MONITORINFO := Map()
			MONITORINFO["Handle"]   := hMonitor
			MONITORINFO["Name"]     := Name := StrGet(MONITORINFOEX.Ptr + 40, 32)
			MONITORINFO["Number"]   := RegExReplace(Name, ".*(\d+)$", "$1")
			MONITORINFO["Left"]     := NumGet(MONITORINFOEX,  4, "int")
			MONITORINFO["Top"]      := NumGet(MONITORINFOEX,  8, "int")
			MONITORINFO["Right"]    := NumGet(MONITORINFOEX, 12, "int")
			MONITORINFO["Bottom"]   := NumGet(MONITORINFOEX, 16, "int")
			MONITORINFO["WALeft"]   := NumGet(MONITORINFOEX, 20, "int")
			MONITORINFO["WATop"]    := NumGet(MONITORINFOEX, 24, "int")
			MONITORINFO["WARight"]  := NumGet(MONITORINFOEX, 28, "int")
			MONITORINFO["WABottom"] := NumGet(MONITORINFOEX, 32, "int")
			MONITORINFO["Primary"]  := NumGet(MONITORINFOEX, 36, "uint")
			return MONITORINFO
		}
		throw Exception("GetMonitorInfo: " A_LastError, -1)
	}
		
	GetMonitorHandle(Display := "", hMonitor := 0){

        MonitorInfo := this.EnumDisplayMonitors()
		if ((Display != "")){
			for Info in MonitorInfo {
				if (InStr(Info["Name"], Display)){
					hMonitor := Info["Handle"]
					break
				}
			}
		}

		if (!hMonitor) ;	MONITOR_DEFAULTTONEAREST = 0x00000002
			hMonitor := DllCall("user32\MonitorFromWindow", "ptr", hWindow := 0, "uint", 0x00000002)
		return hMonitor
	}
	
	GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor){

		if (DllCall("dxva2\GetNumberOfPhysicalMonitorsFromHMONITOR", "ptr", hMonitor, "uint*", NumberOfPhysicalMonitors := 0))
			return NumberOfPhysicalMonitors
		return false
	}
	
	GetPhysicalMonitorsFromHMONITOR(hMonitor, PhysicalMonitorArraySize, ByRef PHYSICAL_MONITOR){

		PHYSICAL_MONITOR := BufferAlloc((A_PtrSize + 256) * PhysicalMonitorArraySize)
		if (DllCall("dxva2\GetPhysicalMonitorsFromHMONITOR", "ptr", hMonitor, "uint", PhysicalMonitorArraySize, "ptr", PHYSICAL_MONITOR))
			return NumGet(PHYSICAL_MONITOR, 0, "ptr")
		return false
	}
	
	DestroyPhysicalMonitors(PhysicalMonitorArraySize, PHYSICAL_MONITOR){

		if (DllCall("dxva2\DestroyPhysicalMonitors", "uint", PhysicalMonitorArraySize, "ptr", PHYSICAL_MONITOR))
			return true
		return false
	}
	
	CreateDC(DisplayName){

		if (hDC := DllCall("gdi32\CreateDC", "str", DisplayName, "ptr", 0, "ptr", 0, "ptr", 0, "ptr"))
			return hDC
		return false
	}
	
	DeleteDC(hDC){

		if (DllCall("gdi32\DeleteDC", "ptr", hDC))
			return true
		return false
	}
	
	
	; ===== HELPER METHODS ===== ;
	
	GetSetting(GetMethodName, Display := "", params*){

		if (hMonitor := this.GetMonitorHandle(Display)){
			PHYSICAL_MONITOR := ""
			PhysicalMonitors := this.GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor)
			hPhysicalMonitor := this.GetPhysicalMonitorsFromHMONITOR(hMonitor, PhysicalMonitors, PHYSICAL_MONITOR)
			Setting := this.%GetMethodName%(hPhysicalMonitor, params*)
			this.DestroyPhysicalMonitors(PhysicalMonitors, PHYSICAL_MONITOR)
			return Setting
		}
		throw Exception("Unable to get handle to monitor.`n`nError code: " Format("0x{:X}", A_LastError))
	}
	
	SetSetting(SetMethodName, Setting, Display := "", params*){

		if (hMonitor := this.GetMonitorHandle(Display)){	
			PHYSICAL_MONITOR := ""		
			PhysicalMonitors := this.GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor)
			hPhysicalMonitor := this.GetPhysicalMonitorsFromHMONITOR(hMonitor, PhysicalMonitors, PHYSICAL_MONITOR)

			if (SetMethodName = "SetMonitorVCPFeature" || SetMethodName = "SetMonitorColorTemperature"){				
				Setting := this.%SetMethodName%(hPhysicalMonitor, Setting, params*)
				this.DestroyPhysicalMonitors(PhysicalMonitors, PHYSICAL_MONITOR)
				return Setting				
			}
			else {	
				GetMethodName := RegExReplace(SetMethodName, "S(.*)", "G$1")
				GetSetting := this.%GetMethodName%(hPhysicalMonitor)
				Setting := (Setting < GetSetting["Minimum"]) ? GetSetting["Minimum"]
					    :  (Setting > GetSetting["Maximum"]) ? GetSetting["Maximum"]
					    :  (Setting)
				this.%SetMethodName%(hPhysicalMonitor, Setting)
				this.DestroyPhysicalMonitors(PhysicalMonitors, PHYSICAL_MONITOR)
				return Setting
			}
		
		} 
		throw Exception("Unable to get handle to monitor.`n`nError code: " Format("0x{:X}", A_LastError))
	}

	GammaSetting(GammaMethodName, Red := "", Green := "", Blue := "", Display := "", DisplayName := ""){

		MonitorInfo := this.EnumDisplayMonitors()
		if (Display = ""){
			for Info in MonitorInfo {
				if (Info["Primary"]){
					PrimaryMonitor := A_Index
					break
				}
			}
		}

		if (DisplayName := MonitorInfo[Display ? Display : PrimaryMonitor]["Name"]){
			if (hDC := this.CreateDC(DisplayName)){	
				if (GammaMethodName = "SetDeviceGammaRamp"){
					for Color in ["Red", "Green", "Blue"]{
						%Color% := (%Color% <    0)	?    0 
						 	    :  (%Color% >  100) ?  100
							    :  (%Color%)	
						%Color% := Round((2.56 * %Color%) - 128, 1) ; convert to decimal	
					}			
					this.SetDeviceGammaRamp(hDC, Red, Green, Blue)
					this.DeleteDC(hDC)
					
					for Color in ["Red", "Green", "Blue"]
						%Color% := Round((%Color% + 128) / 2.56, 1) ; convert back to percentage	

					return Map("Red", Red, "Green", Green, "Blue", Blue)
				}
				else { ; if (GammaMethodName = "GetDeviceGammaRamp")
					GammaRamp := this.GetDeviceGammaRamp(hDC)	
					for Color, GammaLevel in GammaRamp		
						GammaRamp[Color] := Round((GammaLevel + 128) / 2.56, 1) ; convert to percentage		
					this.DeleteDC(hDC)
					return GammaRamp
				}
			
			
			}
			this.DeleteDC(hDC)
			throw Exception("Unable to get handle to Device Context.`n`nError code: " Format("0x{:X}", A_LastError))
		}	
	
	}
	
	; ===== GET METHODS ===== ;
	
	GetMonitorBrightness(hMonitor, Minimum := 0, Current := 0, Maximum := 0){

		if (DllCall("dxva2\GetMonitorBrightness", "ptr", hMonitor, "uint*", Minimum, "uint*", Current, "uint*", Maximum))
			return Map("Minimum", Minimum, "Current", Current, "Maximum", Maximum)
		throw Exception("Unable to retreive values.`n`nError code: " Format("0x{:X}", A_LastError))
	}
	
	GetMonitorContrast(hMonitor, Minimum := 0, Current := 0, Maximum := 0){

		if (DllCall("dxva2\GetMonitorContrast", "ptr", hMonitor, "uint*", Minimum, "uint*", Current, "uint*", Maximum))
			return Map("Minimum", Minimum, "Current", Current, "Maximum", Maximum)
		throw Exception("Unable to retreive values.`n`nError code: " Format("0x{:X}", A_LastError))
	}
	
	GetDeviceGammaRamp(hMonitor){
					
		if (DllCall("gdi32\GetDeviceGammaRamp", "ptr", hMonitor, "ptr", GAMMA_RAMP := BufferAlloc(1536)))
			return Map(
			"Red"  , NumGet(GAMMA_RAMP,        2, "ushort") - 128,
			"Green", NumGet(GAMMA_RAMP,  512 + 2, "ushort") - 128,
			"Blue" , NumGet(GAMMA_RAMP, 1024 + 2, "ushort") - 128)
		throw Exception("Unable to retreive values.`n`nError code: " Format("0x{:X}", A_LastError))
	}

	GetVCPFeatureAndVCPFeatureReply(hMonitor, VCPCode, vct := 0, CurrentValue := 0, MaximumValue := 0){

		static VCP_CODE_TYPE := Map(
					0x00000000, "MC_MOMENTARY — Momentary VCP code. Sending a command of this type causes the monitor to initiate a self-timed operation and then revert to its original state. Examples include display tests and degaussing.",
					0x00000001, "MC_SET_PARAMETER — Set Parameter VCP code. Sending a command of this type changes some aspect of the monitor's operation.")
		
		if (DllCall("dxva2\GetVCPFeatureAndVCPFeatureReply", "ptr", hMonitor, "ptr", VCPCode, "uint*", vct, "uint*", CurrentValue, "uint*", MaximumValue))
			return Map("VCPCode"    ,  Format("0x{:X}", VCPCode),
					   "VCPCodeType",  VCP_CODE_TYPE[vct], 
					   "Current"	,  CurrentValue, 
					   "Maximum"	, (MaximumValue ? MaximumValue : "Undefined due to non-continuous (NC) VCP Code."))
		throw Exception("Unable to retreive values.`n`nError code: " Format("0x{:X}", A_LastError))
	}
	

	; ===== SET METHODS ===== ;
	
	SetMonitorBrightness(hMonitor, Brightness){

		if (DllCall("dxva2\SetMonitorBrightness", "ptr", hMonitor, "uint", Brightness))
			return Brightness
		throw Exception("Unable to set value.`n`nError code: " Format("0x{:X}", A_LastError))
	}
	
	SetMonitorContrast(hMonitor, Contrast){

		if (DllCall("dxva2\SetMonitorContrast", "ptr", hMonitor, "uint", Contrast))
			return Contrast
		throw Exception("Unable to set value.`n`nError code: " Format("0x{:X}", A_LastError))
	}
	
	SetDeviceGammaRamp(hMonitor, red, green, blue){

		GAMMA_RAMP := BufferAlloc(1536)	
		while ((i := A_Index - 1) < 256 ){	
			NumPut("ushort", (r := (red   + 128) * i) > 65535 ? 65535 : r, GAMMA_RAMP,        2 * i)
			NumPut("ushort", (g := (green + 128) * i) > 65535 ? 65535 : g, GAMMA_RAMP,  512 + 2 * i)
			NumPut("ushort", (b := (blue  + 128) * i) > 65535 ? 65535 : b, GAMMA_RAMP, 1024 + 2 * i)
		}
		if (DllCall("gdi32\SetDeviceGammaRamp", "ptr", hMonitor, "ptr", GAMMA_RAMP))
			return true
		throw Exception("Unable to set values.`n`nError code: " Format("0x{:X}", A_LastError))
	}		
	
	SetMonitorVCPFeature(hMonitor, VCPCode, NewValue){

		if (DllCall("dxva2\SetVCPFeature", "ptr", hMonitor, "ptr", VCPCode, "uint", NewValue))
			return Map("VCPCode", Format("0x{:X}", VCPCode), "NewValue", NewValue)
		throw Exception("Unable to set value.`n`nError code: " Format("0x{:X}", A_LastError))
	}		
}


/* 
;................................................................................
;		                      .....................		                        ;
;                              C H A N G E   L O G	                            ;
;................................................................................


	
	2020-08-20: Changed default GUI font color to a less-bright off white color easier on eyes (0xC6C8C5) 
	2020-08-20: Updated formatting, particularly section headers 


	2020-08-18: Reduced code size by creating maps dynamically instead of hard-coded
	2020-08-18: Updated "App Info / Report Bug" tab to include GitHub repo and AHK Forum thread
	2020-08-18: Removed debug value check MsgBox popup when changing monitor state to Power Off 


	2020-08-16: Added checks to make "All Monitors" tab auto-set to current system values
					if the feature for all monitors are equal
	2020-08-16: Made color shading for white-screened apps like Excel, Notepad, Paint etc.
					more robust (affects more elements than before: 5 vs. 29) 


	2020-08-15: Added "App Info / Report Bug" tab, and moved controls to that tab instead of 
					in "Advanced Settings"
	2020-08-15: Created "Background Modes" in advanced settings to adjust system-wide color 
					settings 
	2020-08-15: Made Power State controls respond quicker and de-selects radio button


	2020-08-14: Reduced codesize by removing unused methods in Monitor Class
	2020-08-14: Added tray and menu icons
	2020-08-14: Added "Advanced Settings" Tab to include contact/bug reporting info and 
					app info
	2020-08-14: Reduced codesize by changing OnEvent functions to fat arrow one-liners
    2020-08-14: Added a way to close down the app in tray menu
    2020-08-14: Made "Minimize" and "Close" buttons in GUI now both hide GUI 
    2020-08-14: Fixed a bug of all non-primary monitor gamma values setting to 
					primary gamma values


    2020-08-13: Fixed a few minor bugs affecting settings adjustment response time
    2020-08-13: Version 0.1.0 published




;................................................................................
;		                         ...............		                        ;
;                                 P E N D I N G	          	                    ;
;................................................................................
 


    - Customizable Hotkeys based on which monitor cursor is located in
    - Reduce code size by merging most GUI_Change() functions into universal function(s)
    - Custom daily/hourly/per-minute timer/auto-adjuster 
	- Adjustable screen focuser for reading, etc (blacks out desired portion of screen)
	- User Profiles to save/load personalized user settings on app start / while app is running
	- Color Temperature adjustments (may not add this)
    - Color Gain / Drive for added color adjustment (may not add this)




;................................................................................
;		                         ...............		                        ;
;                                 R E M A R K S	          	                    ;
;................................................................................



    - It appears the SetSysColors winapi is broken for some display elements in Windows 10,
					therefore I will have to find another way to make horrible white/grey
					display elements like scrollbar, caption, menu, etc. turn darker colors

    - There is quite a bit of code that I see that can use some reworking to make it more 
					condensed and readable (gui ctrl functions, etc.), I will edit this when 
					time permits



*/
