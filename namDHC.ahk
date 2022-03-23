#singleInstance off
#noEnv
#Persistent
detectHiddenWindows On
setTitleMatchmode 3
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1

/*
 v1.0		- Initial release

 v1.01		- Added ISO input media support
			- Minor fixes
			
 v1.02		- Removed superfluous code
			- Some spelling mistakes fixed
			- Minor GUI changes

 v1.03		- Fixed Cancel all jobs button
			- Fixed output folder editfield allowing invalid characters
			- Fixed files only being removed from listview after successful operation (when selected)
			- Minor GUI bugs fixed
			- GUI changes
			- Added time elapsed to report
			- Changed about window

 v1.04		- Added update functionality
			- Minor speedups (changed JSON library)
*/

#Include SelectFolderEx.ahk
#Include ClassImageButton.ahk
#Include ConsoleClass.ahk
#Include JSON.ahk

onExit("quitApp", 1)

; Default global values 
; ---------------------
currentAppVersion := "1.04"
checkForUpdatesAtStartup := "yes"
chdmanLocation := a_scriptDir "\chdman.exe"
chdmanVerArray := ["0.236", "0.237", "0.238", "0.239", "0.240"]
githubRepoURL := "https://api.github.com/repos/umageddon/namDHC/releases/latest" 
mainAppName := "namDHC"
mainAppNameVerbose := mainAppName " - Verbose"
runAppName := mainAppName " - Job"
runAppNameChdman := runAppName " - chdman"
runAppNameConsole := runAppName " - Console"
jobTimeoutSec := 3
chdmanTimeoutTimeSec := 5
waitTimeConsoleSec := 15
chdmanOptionMaxPerSide := 9
jobQueueSize := 3
jobQueueSizeLimit := 10
outputFolder := a_workingDir
playFinishedSong := "yes"
removeFileEntryAfterFinish := "yes"
showJobConsole := "no"
showVerboseWin := "no"
verboseWinPosH := 400 
verboseWinPosW := 800
verboseWinPosX := 775
verboseWinPosY := 150
mainWinPosX := 800
mainWinPosY := 100

; Read ini to write over global variables if changed previously
ini("read", ["jobQueueSize"
			,"outputFolder"
			,"showJobConsole"
			,"showVerboseWin"
			,"playFinishedSong"
			,"removeFileEntryAfterFinish"
			,"mainWinPosX"
			,"mainWinPosY"
			,"verboseWinPosW"
			,"verboseWinPosH"
			,"verboseWinPosX"
			,"verboseWinPosY"
			,"checkForUpdatesAtStartup"])

if ( !fileExist(chdmanLocation) ) {
	msgbox 16, % "Fatal Error", % "CHDMAN.EXE not found!`n`nMake sure the chdman executable is located in the same directory as namDHC and try again.`n`nThe following chdman verions are supported:`n" arrayToString(chdmanVerArray)
	exitApp
}


; Run a chdman thread
; Will be called when running chdman - As to allow for a one file executable
;-------------------------------------------------------------
if ( a_args[1] == "threadMode" ) {
	#include threads.ahk
}

; Kill all processes so only one instance is running
;---------------------------------------------------
killAllProcess()

; Set working global variables
; ----------------------------
scannedFiles := {}, queuedMsgData := [], job := {workTally:{}, workQueue:[]}
GUI := { chdmanOpt:{}, dropdowns:{job:{}, media:{}}, buttons:{normal:[], hover:[], clicked:[], disabled:[]}, menu:{namesOrder:[], File:[], Settings:[], About:[]} }

; Set GUI variables
; -----------------
GUI.dropdowns["job"] :=		{create:"Create CHD files from media", extract:"Extract images from CHD files", info:"Get info from CHD files", verify:"Verify CHD files", addMeta:"Add metadata to CHD files", delMeta:"Delete metadata from CHD files"}
GUI.dropdowns["media"] :=	{cd:"CD image", hd:"Hard disk image", ld:"LaserDisc image", raw:"Raw image"}
GUI.buttons["default"] :=	{normal:[0, 0xFFCCCCCC, "", "", 3], 			hover:[0, 0xFFBBBBBB, "", 0xFF555555, 3], 	clicked:[0, 0xFFCFCFCF, "", 0xFFAAAAAA, 3], disabled:[0, 0xFFE0E0E0, "", 0xFFAAAAAA, 3] }
GUI.buttons["cancel"] :=	{normal:[0, 0xFFFC6D62, "", "White", 3], 		hover:[0, 0xFFff8e85, "", "White", 3], 		clicked:[0, 0xFFfad5d2, "", "White", 3], 	disabled:[0, 0xFFfad5d2, "", "White", 3]}
GUI.buttons["start"] :=		{normal:[0, 0xFF74b6cc, "", 0xFF444444, 3],	hover:[0, 0xFF84bed1, "", "White", 3], 		clicked:[0, 0xFFa5d6e6, "", "White", 3], 	disabled:[0, 0xFFd3dde0, "", 0xFF888888, 3] }	

; Set menu variables
; -------------------
GUI.menu["namesOrder"] := ["File", "Settings", "About"]
GUI.menu.File[1] :=		{name:"Quit",											gotolabel:"quitApp",					saveVar:""}
GUI.menu.About[1] :=	{name:"About",											gotolabel:"menuSelected",				saveVar:""}
GUI.menu.Settings[1] :=	{name:"Check for updates automatically",				gotolabel:"menuSelected",				saveVar:"checkForUpdatesAtStartup"}
GUI.menu.Settings[2] :=	{name:"Number of jobs to run concurrently",				gotolabel:":SubSettingsConcurrently",	saveVar:""}
GUI.menu.Settings[3] :=	{name:"Show a verbose window",							gotolabel:"menuSelected",				saveVar:"showVerboseWin", Fn:"showVerboseWindow"}
GUI.menu.Settings[4] :=	{name:"Show a console window for each new job",			gotolabel:"menuSelected",				saveVar:"showJobConsole"}
GUI.menu.Settings[5] :=	{name:"Play a sound when finished jobs",				gotolabel:"menuSelected",				saveVar:"playFinishedSong"}
GUI.menu.Settings[6] :=	{name:"Remove entry from list when successful",			gotolabel:"menuSelected",				saveVar:"removeFileEntryAfterFinish"}


; Set misc GUI variables
; -------------------------
GUI.templateHDDropdownList :=  ""		; Hard drive template dropdown list
. "|Conner CFA170A  -  163MB||"
. "Rodime R0201  -  5MB|"
. "Rodime R0202  -  10MB|"
. "Rodime R0203  -  15MB|"
. "Rodime R0204  -  20MB|"
. "Seagate ST-213  -  10MB|"
. "Segate ST-225  -  20MB|"
. "Seagate ST-251  -  40MB|"
. "Seagate ST-3600N  -  487MB|"
. "Maxtor LXT-213S  -  238MB|"
. "Maxtor LXT-340S  -  376MB|"
. "Maxtor MXT-540SL  -  733MB|"
. "Micropolis 1528  -  1272MB|"


/* 
GUI CHDMAN options

Format:
-------
	name:				String	- Friendly name of option - used as a reference
	paramString:		String	- String used in actual chdman command
	description:		String	- String used to describe option in the GUI
	editField:			String	- Creates an editfield for the option containting the string supplied
	- useQuotes:		Boolean	- TRUE will add quotes around the users editfield when submitting to chdman - only used with editField
	dropdownOptions:	String	- Creates a dropdown with the options supplied.  Must be in autohotkey format (ie- seperated by '|')
	- dropdownValues:	Array	- Used with dropdownOptions - Supplies a different set of values to submit when selecting a dropdown option
	hidden:				Boolean	- TRUE to hide the option in the GUI
	masterOf:			String	- Supply the element name this 'masters over' - the 'subordinate' option will only be enabled when this option is checked
	xInset:				Number	- Number to pixels move option right in the GUI
*/	

GUI.chdmanOpt.force :=				{name: "force",				paramString: "f",	description: "Force overwriting an existing output file"}
GUI.chdmanOpt.verbose :=			{name: "verbose",			paramString: "v",	description: "Verbose output", 								hidden: true}
GUI.chdmanOpt.outputBin :=			{name: "outputbin",			paramString: "ob",	description: "Output filename for binary data", 			editField: "filename.bin", useQuotes:true}
GUI.chdmanOpt.inputParent :=		{name: "inputparent", 		paramString: "ip",	description: "Input Parent", 								editField: "filename.ext", useQuotes:true}
GUI.chdmanOpt.inputStartFrame :=	{name: "inputstartframe", 	paramString: "isf",	description: "Input Start Frame", 							editField: 0}
GUI.chdmanOpt.inputFrames :=		{name: "inputframes", 		paramString: "if",	description: "Effective length of input in frames", 		editField: 0}
GUI.chdmanOpt.inputStartByte :=		{name: "inputstartbyte", 	paramString: "isb",	description: "Starting byte offset within the input", 		editField: 0}
GUI.chdmanOpt.outputParent :=		{name: "outputparent",		paramString: "op",	description: "Output parent file for CHD", 					editField: "filename.chd", useQuotes:true}
GUI.chdmanOpt.hunkSize :=			{name: "hunksize",			paramString: "hs",	description: "Size of each hunk (in bytes)", 				editField: 19584}
GUI.chdmanOpt.inputStartHunk :=		{name: "inputstarthunk",	paramString: "ish",	description: "Starting hunk offset within the input", 		editField: 0}
GUI.chdmanOpt.inputBytes :=			{name: "inputBytes",		paramString: "ib",	description: "Effective length of input (in bytes)", 		editField: 0}
GUI.chdmanOpt.compression :=		{name: "compression",		paramString: "c",	description: "Compression codecs to use", 					editField: "cdlz,cdzl,cdfl"}
GUI.chdmanOpt.inputHunks :=			{name: "inputhunks",		paramString: "ih",	description: "Effective length of input (in hunks)", 		editField: 0}
GUI.chdmanOpt.numProcessors :=		{name :"numprocessors",		paramString: "np",	description: "Max number of CPU threads to use", 			dropdownOptions: procCountDDList()}
GUI.chdmanOpt.template :=			{name: "template",			paramString: "tp",	description: "Hard drive template to use", 					dropdownOptions: GUI.templateHDDropDownList, dropdownValues:[0,1,2,3,4,5,6,7,8,9,10,11,12]}
GUI.chdmanOpt.chs :=				{name: "chs",				paramString: "chs",	description: "CHS Values [cyl, heads, sectors]", 			editField: "332,16,63"}
GUI.chdmanOpt.ident :=				{name: "ident",				paramString: "id",	description: "Name of ident file for CHS info", 			editField: "filename.chs", useQuotes:true}
GUI.chdmanOpt.size :=				{name: "size",				paramString: "s",	description: "Size of output file (in bytes)", 				editField: 0}
GUI.chdmanOpt.unitSize :=			{name: "unitsize",			paramString: "us",	description: "Size of each unit (in bytes)", 				editField: 0}
GUI.chdmanOpt.sectorSize :=			{name: "sectorsize",		paramString: "ss",	description: "Size of each hard disk sector (in bytes)", 	editField: 512}
GUI.chdmanOpt.deleteInputFiles :=	{name: "deleteInputFiles",						description: "Delete input files after completing job", 	masterOf: "deleteInputDir"}
GUI.chdmanOpt.deleteInputDir :=		{name: "deleteInputDir",						description: "Also delete input directory", 				xInset:10}
GUI.chdmanOpt.createSubDir :=		{name: "createSubDir",							description: "Create a new directory for each job"}
GUI.chdmanOpt.keepIncomplete :=		{name: "keepIncomplete",						description: "Keep failed or cancelled output files"}


; Create Main GUI and its elements
createMainGUI()
createProgressBars() 
createMenus()

showVerboseWindow(showVerboseWin)			; Check or uncheck item "Show verbose window"  and show the window 
selectJob()									; Select 1st selection in job dropdown list and trigger refreshGUI()																	

mainAppHWND := winExist(mainAppName)
mainAppMenuGet := DllCall("GetMenu", "uint", mainAppHWND)		; Save menu to retrieve later
mainMenuVisible := true


if ( checkForUpdatesAtStartup == "yes" )
	checkForUpdates()

onMessage(0x03,		"moveGUIWin")			; If windows are moved, save positions in moveGUIWin()
onMessage(0x004A,	"receiveData")			; Receive messages from threads

log(mainAppName " ready.")

return

; -----------------------------------------------------
; End Autoexec
; -----------------------------------------------------




; -----------------------------------------------------
; Functions
; -----------------------------------------------------

; A Menu item was selected
;-------------------------
menuSelected() 
{
	global
	local selMenuObj, varName, fn
	
	switch a_ThisMenu {
		case "SettingsMenu":
			selMenuObj := GUI.menu.settings[a_ThisMenuItemPos]									; Reference menu setting
			varName := selMenuObj.saveVar														; Get variable name
			%varName% := (%varName% == "no")? "yes":"no"										; Toggle variable setting
			menu, SettingsMenu, % ((%varName% == "yes")? "Check":"UnCheck"), % selMenuObj.name	; Check or uncheck in menu
			ini("write", varName)																; Write new setting
			if ( isFunc(selMenuObj.Fn) ) {														; Check if function needs to be called
				fn := selMenuObj.Fn
				%fn%(%varName%)																	; Call function
			}

		case "SubSettingsConcurrently":											; Menu: Settings: User selected number of jobs to run concurrently
			loop % jobQueueSizeLimit											; Uncheck all 
				menu, SubSettingsConcurrently, UnCheck, % a_index
			menu, SubSettingsConcurrently, Check, % A_ThisMenuItemPos			; Check selected
			jobQueueSize := A_ThisMenuItemPos									; Set variable
			ini("write", "jobQueueSize")
			log("Saved jobQueueSize")
		
		case "AboutMenu":														; Menu: About
			guiToggle("disable", "all")
			gui 1:+OwnDialogs
			
			gui 4: destroy
			gui 4: margin, 20 20
			gui 4: font, s15 Q5 w700 c000000
			gui 4: add, text, x10 y10, % mainAppName
			
			gui 4: font, s10 Q5 w700 c000000
			gui 4: add, text, x100 y17, % " v" currentAppVersion
			
			gui 4: font, s10 Q5 w400 c000000
			gui 4: add, text, x10 y35, % "A Windows frontend for the MAME CHDMAN tool"
			
			gui 4: add, button, x10 y70 w130 h22 gcheckForUpdates, % "Check for updates"
			
			gui 4: add, link, x10 y110, Github: <a href="https://github.com/umageddon/namDHC">https://github.com/umageddon/namDHC</a>
			gui 4: add, link, x10 y130, MAME Info: <a href="https://www.mamedev.org/">https://www.mamedev.org/</a>
			
			gui 4: font, s9 Q5 w400 c000000
			gui 4: add, text, x10 y165, % "(C) Copyright 2022 Umageddon"
			gui 4: show, w500 center, About
			Gui 4:+LastFound +AlwaysOnTop +ToolWindow
			controlFocus,, About 												; Removes outline around html anchor
			return
	}
}

4GuiClose() 
{
	gui 4:destroy
	refreshGUI()
	return
}

; Drop down job and media selections
; ------------------------------------
selectJob()
{
	global
	gui 1:submit, nohide

	switch dropdownMedia {
		case GUI.dropdowns.media.cd: 	job.Media := "cd"
		case GUI.dropdowns.media.hd:	job.Media := "hd"
		case GUI.dropdowns.media.ld:	job.Media := "ld"
		case GUI.dropdowns.media.raw:	job.Media := "raw"
	}
	
	switch dropdownJob {
		case GUI.dropdowns.job.create:		job.Cmd := "create" job.Media, 	job.Desc := "Create CHD from a " stringUpper(job.Media) " image",		job.FinPreTxt := "Jobs created"
		case GUI.dropdowns.job.extract:		job.Cmd := "extract" job.Media, job.Desc := "Extract a " stringUpper(job.Media) " image from CHD",		job.FinPreTxt := "Jobs extracted"
		case GUI.dropdowns.job.info:		job.Cmd := "info", 				job.Desc := "Get info from CHD",										job.FinPreTxt := "Read info from jobs"
		case GUI.dropdowns.job.verify:		job.Cmd := "verify",			job.Desc := "Verify CHD",												job.FinPreTxt := "Jobs verified"
		
		;case GUI.dropdowns.job.addMeta:		job.Cmd := "addmeta", 			job.Desc := "Add Metadata to CHD",									job.FinPreTxt := "Jobs with metadata added to"
		;case GUI.dropdowns.job.delMeta:		job.Cmd := "delmeta", 			job.Desc := "Delete Metadata from CHD",								job.FinPreTxt := "Jobs with metadata deleted from"
	}
	
	switch job.Cmd {
		case "extractcd":	job.InputExtTypes := ["chd"],						job.OutputExtTypes := ["cue", "toc", "gdi"],job.Options := [GUI.chdmanOpt.force, GUI.chdmanOpt.createSubDir, GUI.chdmanOpt.deleteInputFiles, GUI.chdmanOpt.keepIncomplete, GUI.chdmanOpt.outputBin, GUI.chdmanOpt.inputParent]
		case "extractld":	job.InputExtTypes := ["chd"],						job.OutputExtTypes := ["raw"],				job.Options := [GUI.chdmanOpt.force, GUI.chdmanOpt.deleteInputFiles, GUI.chdmanOpt.keepIncomplete, GUI.chdmanOpt.inputParent, GUI.chdmanOpt.inputStartFrame, GUI.chdmanOpt.inputFrames]
		case "extracthd":	job.InputExtTypes := ["chd"],						job.OutputExtTypes := ["img"],				job.Options := [GUI.chdmanOpt.force, GUI.chdmanOpt.deleteInputFiles, GUI.chdmanOpt.keepIncomplete, GUI.chdmanOpt.inputParent, GUI.chdmanOpt.inputStartByte, GUI.chdmanOpt.inputStartHunk, GUI.chdmanOpt.inputBytes, GUI.chdmanOpt.inputHunks]
		case "extractraw":	job.InputExtTypes := ["chd"],						job.OutputExtTypes := ["img", "raw"],		job.Options := [GUI.chdmanOpt.force, GUI.chdmanOpt.deleteInputFiles, GUI.chdmanOpt.keepIncomplete, GUI.chdmanOpt.inputParent, GUI.chdmanOpt.inputStartByte, GUI.chdmanOpt.inputStartHunk, GUI.chdmanOpt.inputBytes, GUI.chdmanOpt.inputHunks]
		case "createcd": 	job.InputExtTypes := ["cue", "toc", "gdi", "iso"],	job.OutputExtTypes := ["chd"],				job.Options := [GUI.chdmanOpt.force, GUI.chdmanOpt.deleteInputFiles, GUI.chdmanOpt.deleteInputDir, GUI.chdmanOpt.keepIncomplete, GUI.chdmanOpt.numProcessors, GUI.chdmanOpt.outputParent, GUI.chdmanOpt.hunkSize, GUI.chdmanOpt.compression]
		case "createld":	job.InputExtTypes := ["raw"],						job.OutputExtTypes := ["chd"],				job.Options := [GUI.chdmanOpt.force, GUI.chdmanOpt.deleteInputFiles, GUI.chdmanOpt.deleteInputDir, GUI.chdmanOpt.keepIncomplete, GUI.chdmanOpt.numProcessors, GUI.chdmanOpt.outputParent, GUI.chdmanOpt.inputStartFrame, GUI.chdmanOpt.inputFrames, GUI.chdmanOpt.hunkSize, GUI.chdmanOpt.compression]
		case "createhd":	job.InputExtTypes := ["img"],						job.OutputExtTypes := ["chd"],				job.Options := [GUI.chdmanOpt.force, GUI.chdmanOpt.deleteInputFiles, GUI.chdmanOpt.deleteInputDir, GUI.chdmanOpt.keepIncomplete, GUI.chdmanOpt.numProcessors, GUI.chdmanOpt.compression, GUI.chdmanOpt.outputParent, GUI.chdmanOpt.size, GUI.chdmanOpt.inputStartByte, GUI.chdmanOpt.inputStartHunk, GUI.chdmanOpt.inputBytes, GUI.chdmanOpt.inputHunks, GUI.chdmanOpt.hunkSize, GUI.chdmanOpt.ident, GUI.chdmanOpt.template, GUI.chdmanOpt.chs, GUI.chdmanOpt.sectorSize]
		case "createraw":	job.InputExtTypes := ["img", "raw"],				job.OutputExtTypes := ["chd"],				job.Options := [GUI.chdmanOpt.force, GUI.chdmanOpt.deleteInputFiles, GUI.chdmanOpt.deleteInputDir, GUI.chdmanOpt.keepIncomplete, GUI.chdmanOpt.numProcessors, GUI.chdmanOpt.outputParent, GUI.chdmanOpt.inputStartByte, GUI.chdmanOpt.inputStartHunk, GUI.chdmanOpt.inputBytes, GUI.chdmanOpt.inputHunks, GUI.chdmanOpt.hunkSize, GUI.chdmanOpt.unitSize, GUI.chdmanOpt.compression]
		case "info":		job.InputExtTypes := ["chd"],						job.OutputExtTypes := [""],					job.Options := []
		case "verify":		job.InputExtTypes := ["chd"],						job.OutputExtTypes := [""],					job.Options := []
	}
	
	refreshGUI(true) ; Any selection from media or job dropdown needs to reset GUI
}


; User pressed input or output files button
; Show Ext menu
; --------------------------------------------
buttonExtSelect()
{
	switch a_guicontrol {
		case "buttonInputExtType":
			menu, InputExtTypes, Show, 873, 172 					; Hardcoded x,y positions as element position returns are wonky...
		case "buttonOutputExtType":
			menu, OutputExtTypes, Show, 873, 480
	}
}

	
; User selected an extension from the input/output extension menu
; ------------------------------------------------------------------
menuExtHandler(init:=false)
{
	global job
	
	if ( init == true ) {													; Create and populate extension menu lists
		for idx, type in ["InputExtTypes", "OutputExtTypes"] {	
			menu, % type, deleteAll											; Clear all old Input & Output menu items
			
			job["selected" type] := []										; Clear global Array of Input & Output extensions
			for idx2, ext in job[type] {									; Parse through job.InputExtTypes & job.OutputExtTypes
				if ( !ext )
					continue
				menu, % type, add, % ext, % "menuExtHandler"				; Add extension item to the menu
				if ( dropdownJob == GUI.dropdowns.job.extract && type == "OutputExtTypes" && idx2 > 1 )
					continue												; By default, only check one extension of the Output menu if we are extracting an image
				else {
					menu, % type, Check, % ext								; Otherwise, check all extension menu items
					job["selected" type].push(ext)							; Then add it to the input & output global selected extension array
				}
			}
		}
	}
	else if ( a_ThisMenu ) {													; An extension menu was selected
		selectedExtList := "selected" strReplace(a_ThisMenu, "extTypes", "") "ExtTypes"
		job[selectedExtList] := []										; Re-build either of these Arrays: job.selectedOutputExtTypes[] or job.selectedInputExtTypes[]
		
		switch a_ThisMenu {												; a_ThisMenu is either 'InputExtTypes' or 'OutputExtTypes'
			case "OutputExtTypes":										; Only one output extension is allowed to be checked
				for idx, val in job.OutputExtTypes
					menu, OutputExtTypes, Uncheck, % val				; Uncheck all menu items, 
				menu, OutputExtTypes, Check, % a_ThisMenuItem			; Then check what was clicked, so only one is ever checked
		
			case "InputExtTypes": 
				menu, InputExtTypes, Togglecheck, % a_ThisMenuItem		; Toggle checking item
		}
		
		for idx, val in job[a_ThisMenu]
			if ( isMenuChecked(a_ThisMenu, idx) ) {
				job[selectedExtList].push(val)							; Add checked extension item(s) to the global array for reference later
			}

		if ( job["selected" type "ExtTypes"].length() == 0 ) {
			menu, % a_ThisMenu, check, % a_ThisMenuItem					; Make sure at least one item is checked
			job[selectedExtList].push(a_ThisMenuItem)
		}
	}
	
	for idx2, type in ["InputExtTypes", "OutputExtTypes"]
		guiCtrl({(type) "Text": arrayToString(job["selected" type])})				; Populate the input & output extension text lists in the GUI
}


; Scan files and add to queue
; ----------------------------------
addFolderFiles()
{
	global job, scannedFiles, mainAppName
	newFiles := [], extList := "", numAdded := 0
	
	gui 1:submit, nohide
	gui 1:+OwnDialogs 
	
	guiToggle("disable", "all")
	
	if ( !isObject(scannedFiles[job.Cmd]) )
		scannedFiles[job.Cmd] := []
	
	switch ( a_GuiControl ) {
		case "buttonAddFiles":
			for idx, ext in job.InputExtTypes
				extList .= "*." ext ";"
			fileSelectFile, newInputList, M3, % "::{20d04fe0-3aea-1069-a2d8-08002b30309d}", % "Select files", % extList
			if ( !errorLevel )
				loop, parse, newInputList, % "`n" 
				{
					if ( a_index == 1 )
						path := regExReplace(a_Loopfield, "\\$")
					else 
						newFiles.push(path "\" a_Loopfield)
				}
		
		case "buttonAddFolder":
			inputFolder := selectFolderEx("", "Select a folder containing " arrayToString(job.InputExtTypes) " type files.", winExist(mainAppName))
			if ( inputFolder.SelectedDir ) {
				inputFolder := regExReplace(inputFolder.SelectedDir, "\\$")
				for idx, thisExt in job.InputExtTypes {
					loop, Files, % inputFolder "\*." thisExt, FR 
						newFiles.push(a_LoopFileLongPath)
				}
			}
	}
	
	if ( newFiles.length() ) {
		gui 1: listView, listViewInputFiles
		for idx, thisFile in newFiles {
			if ( !inArray(thisFile, scannedFiles[job.Cmd]) ) {
				numAdded++
				log("Adding '" thisFile "'")
				SB_SetText("Adding '" thisFile "'", 1, 1)
				LV_add("", thisFile)
				scannedFiles[job.Cmd].push(thisFile)
			} else  {
				log("Skip adding '" thisFile "' - Already in queue")
				SB_SetText("Skip adding '" thisFile "' - Already in queue", 1)
			}
		}
		
		if ( numAdded > 0 ) {
			log("Added " numAdded " files")
			reportQueuedFiles()
		}
	}

	refreshGUI()
}


; Listview containting input files was clicked
; --------------------------------------------
listViewInputFiles()
{
	global
	local suffx, idx, val
	
	if ( a_guievent == "I" )
		return
	
	if ( LV_GetCount("S") > 0 )  {
		suffx := (LV_GetCount("S") > 1) ? "s" : ""
		guiCtrl({buttonRemoveInputFiles:"Remove file" suffx, buttonclearInputFiles:"Clear selection" suffx})
		for idx, val in [4,6]																					; Apply buttons 'Remove selections' and 'Clear selections' skin after changing text
			imageButton.create(GUIbutton%val%, GUI.buttons.default.normal, GUI.buttons.default.hover, GUI.buttons.default.clicked, GUI.buttons.default.disabled) ; Default button colors
		guiToggle("enable", ["buttonRemoveInputFiles", "buttonclearInputFiles"])
	}
	else
		guiToggle("disable", ["buttonclearInputFiles", "buttonRemoveInputFiles"]) 
		
	guiToggle((LV_GetCount()>0?"enable":"disable"), ["buttonselectAllInputFiles"]) 	

}


; Select from input listview files
; --------------------------------
selectInputFiles()
{
	global job, scannedFiles
	row := 0, removeThese := []
	
	gui 1:submit, nohide
	gui 1:+OwnDialogs
	gui 1: listView, listViewInputFiles 					; Select the listview for manipulation
	
	if ( inStr(a_GuiControl, "SelectAll") ) {
		LV_Modify(0, "Select")
	}
	else if ( inStr(a_GuiControl, "Clear") ) {
		LV_Modify(0, "-Select")
	}
	else if ( inStr(a_GuiControl, "Remove") ) {
		guiToggle("disable", "all")
		loop {
			row := LV_GetNext(row)										; Get selected download from list and move to next
			if ( !row ) 												; Break if no more selected
				break
			removeThese.push(row)
		}
		while ( removeThese.length() ) {
			row := removeThese.pop()
			LV_GetText(removeThisFile, row , 1)
			LV_Delete(row)
			removeFromArray(removeThisFile, scannedFiles[job.Cmd])
			log("Removed '" removeThisFile "' from the " stringUpper(job.Cmd) " queue")
			SB_setText("Removed '" removeThisFile "' from the " stringUpper(job.Cmd) " queue", 1)
		}
		reportQueuedFiles()
	}
	refreshGUI()
	controlFocus, SysListView321, %mainAppName%
}

reportQueuedFiles() 
{
	global scannedFiles, job
	log( scannedFiles[job.Cmd].length()? scannedFiles[job.Cmd].length() " jobs in the " stringUpper(job.Cmd) " queue. Ready to start!" : "No jobs in the " stringUpper(job.Cmd) " file queue" )
	SB_setText( scannedFiles[job.Cmd].length()? scannedFiles[job.Cmd].length() " jobs in the " stringUpper(job.Cmd) " queue. Ready to start!" : "No jobs in the " stringUpper(job.Cmd) " file queue" )
}


; Select output folder
; --------------------
editOutputFolder()
{
	global editOutputFolder, outputFolder
	badChar := false
	
	gui 1:submit, nohide
	gui 1:+OwnDialogs
	
	newFolder := editOutputFolder
	if ( a_guiControl == "buttonBrowseOutput" ) {
		newFolder := selectFolderEx(outputFolder, "Select a folder to save converted files to", mainAppHWND)
		newFolder := newFolder.selectedDir
	}
	if ( !newFolder || newFolder == outputFolder ) 
		return
	for idx, val in ["*", "?", "<", ">", "/", "|", """"] {
		if ( inStr(newfolder, val) ) {
			badChar := true
			break
		}
	}
	folderChk := splitPath(newFolder)
	if ( !folderChk.drv || !folderChk.dir || badChar ) 			; Make sure newFolder is a valid directory string
		msgBox % "Invalid output folder"
	else {
		outputFolder := regExReplace(newFolder, "\\$")
		log("'" outputFolder "' selected as output folder")
		SB_SetText("'" outputFolder "' selected as new output folder" , 1)
		ini("write", "outputFolder")
		refreshGUI()
		controlFocus,, %mainAppName%
	}
	guiCtrl({editOutputFolder:outputFolder})	; Replace edit field with new outputfolderor reverts back to old value if new value invalid
}



; A chdman option checkbox was clicked
; ---------------------------------
checkboxOption(ctrl:="")
{
	global GUI
	
	gui 1:submit, nohide
	opt := strReplace(a_guicontrol?a_guicontrol:ctrl, "_checkbox")
	guiToggle((%a_guiControl%? "enable":"disable"), [opt "_dropdown", opt "_edit"])		; Enable or disable corepsnding dropdown or editfield according to checked status
	if ( GUI.chdmanOpt[opt].hasKey("masterOf") ) {										; Disable the 'slave' checkbox if masterOf is set as an option
		guiToggle((%a_guiControl%? "enable":"disable"), [GUI.chdmanOpt[opt].masterOf "_checkbox", GUI.chdmanOpt[opt].masterOf "_dropdown", GUI.chdmanOpt[opt].masterOf "_edit"])
		guiCtrl({(GUI.chdmanOpt[opt].masterOf "_checkbox"):0})
	}
}



; Convert job button - Start the jobs!
; ------------------------------------
buttonStartJobs()
{
	global
	local fnMsg, runCmd, thisJob, gPos, y, dropdownCHDInfoList:="", file, filefull, dir, x1, x2, y
	static CHDInfoFileNum
	gui 1:submit, nohide
	gui 1:+OwnDialogs
	
	switch job.Cmd { 
		case "createcd", "createhd", "createraw", "createld", "extractcd", "extracthd", "extractraw", "extractld":
			SB_SetText("Creating work Queue" , 1)
			log("Creating work queue")
			job.workQueue := createjob(job.Cmd, job.Options, OutputExtTypes, scannedFiles[job.Cmd], regExReplace(outputFolder, "\\$"))	; Create a queue (object) of files to process
		
		case "verify":
			job.workQueue := createjob("verify", "", "", scannedFiles["verify"])
		
		case "info":
			guiToggle("disable", "all")
			CHDInfoFileNum := 1, x1 := 20, x2:= 150, y := 20
			gui 3: destroy
			gui 3: margin, 20, 20
			gui 3: font, s12 Q5 w700 c000000
			gui 3: add, text, x20 y%y% w500 vtextCHDInfoTitle, % ""
			y += 40
			loop 12 {
				gui 3: font, s9 Q5 w700 c000000
				gui 3: add, text, x%x1% y%y% w100 vtextCHDInfoTextInfoTitle_%a_index%, % ""
				gui 3: font, s9 Q5 w400 c000000
				gui 3: add, edit, x%x2% y+-13 w615 veditCHDInfoTextInfo_%a_index% readonly, % ""
				y += 23
			}
			y += 30
			gui 3: font, s9 Q5 w700 c000000
			gui 3: add, text, x%x1% y%y%, % "Hunks"
			gui 3: add, text, x130 y%y%, % "Type"
			gui 3: add, text, x260  y%y%, % "Percent"
			gui 3: font, s9 Q5 w400 c000000
			loop 4 {
				y += 20
				gui 3: add, text, x%x1% y%y% w150 vtextCHDInfoHunks_%a_index%, % ""
				gui 3: add, text, x130 y%y% w150 vtextCHDInfoType_%a_index%, % ""	; recombine words that were seperated with strSplit  
				gui 3: add, text, x260 y%y% w150 vtextCHDInfoPercent_%a_index%, % ""
			}
			y += 40
			gui 3: font, s9 Q5 w700 c000000
			gui 3: add, text, x%x1% y%y% w150, % "Metadata"
			gui 3: font, s8 Q5 w400 c000000, % "Consolas"
			y += 20
			gui 3: add, edit, x%x1% y%y% w750 h250 veditMetadata readonly, % ""
			y+= 270
			gui 3: font, s9 Q5 w400 c000000
			gui 3: add, button, x20 w120 y%y% h30 gselectCHDInfo vbuttonCHDInfoLeft hwndbuttonCHDInfoPrevHWND disabled, % "< Prev file"
			imageButton.create(buttonCHDInfoPrevHWND, GUI.buttons.default.normal, GUI.buttons.default.hover, GUI.buttons.default.clicked, GUI.buttons.default.disabled) ; Default button colors
			
			for idx, filefull in scannedFiles["info"]
				dropdownCHDInfoList .= splitPath(filefull).file "|" ; Create CHD info dropdown list
			y+=5
			gui 3: add, dropdownlist, x160 y%y% w475 vdropdownCHDInfo gselectCHDInfo altsubmit, % regExReplace(dropdownCHDInfoList, "\|$")
			y-=5
			gui 3: font, s9 Q5 w400 c000000
			gui 3: add, button, x+15 y%y% w120 h30 gselectCHDInfo vbuttonCHDInfoRight hwndbuttonCHDInfoNextHWND,  % " Next file >"
			imageButton.create(buttonCHDInfoNextHWND, GUI.buttons.default.normal, GUI.buttons.default.hover, GUI.buttons.default.clicked, GUI.buttons.default.disabled) ; Default button colors
			Gui 3:+LastFound +AlwaysOnTop +ToolWindow
			gui 3:show, autosize, % "CHD Info"

			selectCHDInfo:
				gui 3:submit, nohide
				switch a_guiControl {
					case "buttonCHDInfoLeft":
						CHDInfoFileNum--
					case "buttonCHDInfoRight":
						CHDInfoFileNum++
					case "dropdownCHDInfo":
						CHDInfoFileNum := dropdownCHDInfo
				}
				if ( showCHDInfo(scannedFiles["info"][CHDInfoFileNum]) == false )
					return

				guiCtrl("choose", {dropdownCHDInfo:CHDInfoFileNum}, 3)					; Choose dropdown to match newly selected item in CHD info
				controlFocus, ComboBox1, % "CHD Info"									; Keep focus on dropdown to allow arrow keys to also select next and previous files
				
				guiToggle("enable", ["buttonCHDInfoLeft","buttonCHDInfoRight"], 3)		; Enable both selection buttons by default
				if ( CHDInfoFileNum == 1 )												; Then disable the appropriate button according to selection number (first or last in list)
					guiToggle("disable", "buttonCHDInfoLeft", 3)						
				else if ( CHDInfoFileNum == scannedFiles["info"].length() )
					guiToggle("disable", "buttonCHDInfoRight", 3)
				return
			
			3GUIClose:
				gui 3: destroy
				refreshGUI()
			return

		case "addMeta":
		case "delMeta":
		case default:
	}
	if ( job.workQueue.length() == 0 )																							; Nothing to do!
		return
	
	msgData := [], thisJob := {}, availPSlots := []
	job.workTally := {started:false, running:0, total:job.workQueue.length(), success:0, cancelled:0, skipped:0, withError:0, finished:0, haltedMsg:"", report:""}		; Set variables
	workQueueSize := (job.workTally.total < jobQueueSize)? job.workTally.total : jobQueueSize									; If number of jobs is less then queue count, only display those progress bars

	dllCall("SetMenu", "uint", mainAppHWND, "uint", 0), mainMenuVisible := false											; Hide main menu bar (selecting menu when running jobs stops messages from being receieved from threads)								
	guiToggle("disable", "all")																								; Disable all controls while job is in progress
	guiToggle("hide", "buttonStartJobs")
	guiToggle(["show", "enable"], "buttonCancelAllJobs")
	
	gPos := (job.Cmd == "verify" || job.Cmd == "info")? guiGetCtrlPos("groupboxJob") : guiGetCtrlPos("groupboxOptions")		; Move and show progress bars
	y := gPos.y + gPos.h + 25																								; Assign y (x are from 'gPos') values to groupbox x & y positions
	guiCtrl("moveDraw", {groupBoxProgress:"x5 y" (gPos.y + gPos.h) + 5 " h" workQueueSize*25 + 60})							; Move and resize progress groupbox
	guiCtrl("moveDraw", {progressAll:"y" y, progressTextAll: "y" y+4}) 														; Set All Progress bar and it's text Y position
	guiCtrl( {progressAll:0, progressTextAll:"0 jobs of " job.workTally.total " completed - 0%"})
	guiToggle(["show","enable"], ["groupBoxProgress", "progressAll", "progressTextAll"])									; Show total progress bars
	y += 35
	loop % workQueueSize {																	
		guiCtrl("moveDraw", {("progress" a_index):"y" y, ("progressText" a_index):"y" y+4, ("progressCancelButton" a_index):"y" y})	; Move the progress bars into place
		y += 25
		guiCtrl({("progress" a_index):0, ("progressText" a_index): ""})														; Clear the bars text and zero out percentage
		guiToggle(["enable","show"],["progress" a_index, "progressText" a_index, "progressCancelButton" a_index])			; Enable and show job progress bars
		availPSlots.push(a_index)																							; Add available progress slots to queue
	}
	gui 1:show, autosize																									; Resize main window to fit progress bars
	
	log(job.workTally.total " " stringUpper(job.Cmd) " jobs starting ...")
	SB_SetText(job.workTally.total " " stringUpper(job.Cmd) " jobs started" , 1)
	setTimer, jobTimeoutTimer, 1000																							; Check for timeout of chdman or thread
	job.workTally.started := true
	job.startTime := A_TickCount
	
	loop {
		if ( availPSlots.length() > 0 && job.workQueue.length() > 0 ) {									; Wait for an available slot in the queue to be added
			thisJob := job.workQueue.removeAt(1)														; Grab the first job from the work queue and assign parameters to variable
			thisJob.pSlot := availPSlots.removeAt(1)												; Assign the progress bar a y position from available queue
			msgData[thisJob.pSlot] := {}
			msgData[a_index].timeout := 0

			runCmd := a_ScriptName " threadMode " (showJobConsole == "yes" ? "console" : "")		; "threadmode" flag tells script to run this script as a thread
			run % runCmd ,,, pid																	; Run it
			thisJob.pid := pid
			
			while ( pid <> msgData[thisJob.pSlot].pid ) {											; Wait for confirmation that msg was receieved												
				sendAppMessage(json(thisJob), "ahk_class AutoHotkey ahk_pid " pid)
				sleep 25
			}
		}
		
		if ( job.workTally.finished == job.workTally.total || job.workTally.started == false )
			break																					; Job queue has finished
	
		sleep 250
	}
	
	setTimer, jobTimeoutTimer, off
	job.workTally.started := false
	job.endTime := a_Tickcount
	
	if ( job.workTally.haltedMsg ) {																; There was a fatal error that didnt allow any jobs to be attempted
		log("Fatal Error: " job.workTally.haltedMsg)
		SB_SetText("Fatal Error: " job.workTally.haltedMsg , 1)
		msgBox, 16, % "Fatal Error", job.workTally.haltedMsg "`n"
	}
	else {																							; {normal:0, cancelled:0, skipped:0, withError:0, halt:0}
		fnMsg := "Total number of jobs attempted: " job.workTally.total "`n"
		fnMsg .= job.workTally.success ? job.FinPreTxt " sucessfully: " job.workTally.success "`n" : ""
		fnMsg .= job.workTally.cancelled ? "Jobs cancelled by the user: " job.workTally.cancelled "`n" : ""
		fnMsg .= job.workTally.skipped ? "Jobs skipped because the output file already exists: " job.workTally.skipped "`n" : ""
		fnMsg .= job.workTally.withError ? "Jobs that finished with errors: " job.workTally.withError : ""
		fnMsg .= "Total time to finish: " millisecToTime(job.endTime-job.startTime)
	
		SB_SetText("Jobs finished" (job.workTally.withError ? " with some errors":"!"), 1)
		log( regExReplace(strReplace(fnMsg, "`n", ", "), ", $", "") )
		
		if ( playFinishedSong == "yes" && job.workTally.success )									; Play sounds to indicate we are done (only if at least one successful job)
			playSound()		
	
		msgBox, 4, % mainAppName, % "Finished!`nWould you like to see a report?"
		ifMsgBox Yes
		{
			gui 3: destroy
			gui 3: margin, 10, 20
			gui 3: font, s11 Q5 w700 c000000
			gui 3: add, text,, % job.Desc " report"
			gui 3: font, s9 Q5 w400 c000000
			gui 3: add, edit, y+15 w800 h500, % fnMsg "`n`n`n" job.workTally.report
			gui 3: add, button, x350 y+15 w100 h24 gfinishJob, OK									; go to finishJob here
			gui 3: show, autosize center, REPORT
			Gui 3: -sysmenu +LastFound +AlwaysOnTop +ToolWindow
			controlFocus,, REPORT
			return
		}
		else
			finishJob()
	}
}



; All jobs have finished or user pressed okay after report
; --------------------------------------------------------
finishJob()
{		
	gui 3: destroy
	refreshGUI()
}


; Cancel a single job in progress
; -------------------------------
progressCancelButton()
{
	global msgData
	
	if ( !a_guiControl )
		return
	pSlot := strReplace(a_guiControl, "progressCancelButton", "")
	msgBox, 4,, % "Cancel job " msgData[pSlot].idx " - " stringUpper(msgData[pSlot].cmd) ": " msgData[pSlot].workingTitle "?", 15
	ifMsgBox Yes
		cancelJob(pSlot)
}


; Cancel all jobs currently running
; ---------------------------------
cancelAllJobs()
{
	global
	
	if ( job.workTally.started == false || job.workTally.running == 0  )
		return
	
	gui 1:+OwnDialogs
	msgBox, 4,, % "Are you sure you want to cancel all jobs?", 15
	ifMsgBox No
		return
	
	job.workTally.cancelled += job.workQueue.length()
	job.workTally.finished += job.workQueue.length()
	job.workTally.started := false
	job.workQueue := []													; Clear the work Queue
	loop % jobQueueSize
		cancelJob(a_index)
}


; User cancels job
; --------------------------------
cancelJob(pSlot)
{
	global msgData
	critical
	
	if ( !pSlot || !msgData[pSlot].pid )
		return

	log("Job " msgData[pSlot].idx " - User requested to cancel...")
	msgData[pSlot].kill := "true"
	return sendAppMessage(json(msgData[pSlot]), "ahk_class AutoHotkey ahk_pid  " msgData[pSlot].pid)
}




; Create the main GUI
; -------------------
createMainGUI() 
{
	global
	local thisOptName, key, thisOpt, thisBtn
	
	gui 1:add, button, 		hidden default h0 w0 y0 y0 geditOutputFolder,		; For output edit field (default button
	
	gui 1:add, statusBar
	SB_SetParts(640, 175)
	SB_SetText("  namDHC v" currentAppVersion " for CHDMAN", 2)

	gui 1:add, groupBox, 	x5 w800 h425 vgroupboxJob, Job

	gui 1:add, text, 		x15 y30, % "Job type:"
	gui 1:add, dropDownList,x+5 y28 w200 vdropdownJob gselectJob, % GUI.dropdowns.job.create "||" GUI.dropdowns.job.extract "|" GUI.dropdowns.job.info "|" GUI.dropdowns.job.verify 	;"|" GUI.dropdowns.job.addMeta "|" GUI.dropdowns.job.delMeta

	gui 1:add, text, 		x+30 y30, % "Media type:"
	gui 1:add, dropDownList,x+5 y28 w200 vdropdownMedia gselectJob, % GUI.dropdowns.media.cd "||" GUI.dropdowns.media.hd "|" GUI.dropdowns.media.ld "|" GUI.dropdowns.media.raw

	gui 1:add, text, 		x15 y65, % "Input files"
	
	gui 1:add, button, 		x15 y83 w80 h22 vbuttonAddFiles gaddFolderFiles hwndGUIbutton2, % "Add files"
	gui 1:add, button, 		x+5 y83 w90 h22 vbuttonAddFolder gaddFolderFiles hwndGUIbutton3, % "Add a folder"
	
	gui 1:add, text, 		x475 y93, % "Input file types: "
	gui 1: font, Q5 s9 w700 c000000
	gui 1:add, text, 		x+3 y93 w110 vInputExtTypesText, % ""
	gui 1: font, Q5 s9 w400 c000000
	gui 1:add, button,		x663 y83 w130 h22 gbuttonExtSelect vbuttonInputExtType hwndGUIbutton1, % "Select input file types"
	
	gui 1:add, listView, 	x15 y110 w778 h153 vlistViewInputFiles glistViewInputFiles altsubmit, % "File"
	
	gui 1:add, button, 		x15 y267 w90 vbuttonSelectAllInputFiles gselectInputFiles hwndGUIbutton5, % "Select all"
	gui 1:add, button, 		x+5 y267 w90 vbuttonClearInputFiles gselectInputFiles hwndGUIbutton6, % "Clear selection"
	gui 1:add, button, 		x+20 y267 w90 vbuttonRemoveInputFiles gselectInputFiles hwndGUIbutton4, % "Remove selection"

	gui 1:add, text, 		x15 y305, % "Output Folder"
	gui 1:add, button, 		x15 y324 w90 vbuttonBrowseOutput geditOutputFolder hwndGUIbutton8, % "Select a folder"
	gui 1:add, text, 		x485 y335,% "Output file type: "
	gui 1: font, Q5 s9 w700 c000000
	gui 1:add, text, 		x+3 y335 w100 vOutputExtTypesText, % ""
	gui 1: font, Q5 s9 w400 c000000
	gui 1:add, button,		x663 y324 w130 h24 vbuttonOutputExtType gbuttonExtSelect hwndGUIbutton7, % "Select output file type"
	
	gui 1:add, edit, 		x15 y352 w778 veditOutputFolder +wantReturn, % outputFolder
	
	gui 1:add, button,		x320 y385 w160 h35 vbuttonStartJobs gbuttonStartJobs hwndstartButtonHWND, % "Start all jobs!"
	
	gui 1:add, button,		hidden x320 y385 w160 h35 vbuttonCancelAllJobs gcancelAllJobs hwndcancelButtonHWND, % "CANCEL ALL JOBS"
	imageButton.create(cancelButtonHWND, GUI.buttons.cancel.normal, GUI.buttons.cancel.hover, GUI.buttons.cancel.clicked)

	gui 1:add, groupBox, 	x5 w800 y435 vgroupboxOptions, % "CHDMAN Options"		; Position and height will be set in refreshGUI()

	loop 8 {	; Stylize default buttons
		thisBtn := "GUIbutton" a_index
		imageButton.create(%thisBtn%, GUI.buttons.default.normal, GUI.buttons.default.hover, GUI.buttons.default.clicked, GUI.buttons.default.disabled) ; Default button colors
	}
	
	for key, thisOpt in GUI.chdmanOpt
	{
		if ( thisOpt.hidden == true )
			continue
		thisOptName := thisOpt.name
		gui 1:add, checkbox,		hidden w200 gcheckboxOption -wrap v%thisOptName%_checkbox,	; Options are moved to their positions when refreshGUI(true) is called
		gui 1:add, edit,			hidden w165 v%thisOptName%_edit,
		gui 1:add, dropdownList, 	hidden w165 altsubmit v%thisOptName%_dropdown,				; ... so we can use for dropdown list to place at same location (default is hidden)
	}
}


; Create GUI progress bar section
; -------------------------------
createProgressBars()
{
	global
	local thisBtn
	
	gui 1:add, groupBox, w800 vgroupBoxProgress, Progress

	gui 1: font, Q5 s9 w700 cFFFFFF
	gui 1:add, progress, hidden x20 w770 h22 backgroundAAAAAA vprogressAll cgreen, 0		; Progress bars y values will be determined with refreshGUI()
	gui 1:add, text,	 hidden x30 w750 h22 +backgroundTrans -wrap vprogressTextAll

	loop % jobQueueSizeLimit {																; Draw but hide all progress bars - we will only show what is called for later
		gui 1:add, progress, hidden x20 w740 h22 backgroundAAAAAA vprogress%a_index% c17A2B8, 0				
		gui 1:add, text,	 hidden x30 w720 h22 +backgroundTrans -wrap vprogressText%a_index%
		gui 1:add, button,	 hidden x+15 w25 vprogressCancelButton%a_index% gprogressCancelButton hwndprogCancelbutton%a_index%, % "X"
		thisBtn := "progCancelbutton" a_index
		imageButton.create(%thisBtn%, GUI.buttons.cancel.normal,	GUI.buttons.cancel.hover, GUI.buttons.cancel.clicked)
	}
}


; Create GUI Menus
; ----------------
createMenus() 
{
	global GUI, jobQueueSizeLimit, jobQueueSize
	
	loop % jobQueueSizeLimit
		menu, SubSettingsConcurrently, Add, %a_index%, % "menuSelected"
	menu, SubSettingsConcurrently, Check, % jobQueueSize						; Select current jobQueue number

	loop % GUI.menu.namesOrder.length() {
		menuName := GUI.menu.namesOrder[a_index]
		menuArray := GUI.menu[menuName]
		
		loop % menuArray.length() {
			menuItem :=  menuArray[a_index]
			menu, % menuName "Menu", add, % menuItem.name, % menuItem.gotolabel
		
			if ( menuItem.saveVar ) {
				saveVar := menuItem.saveVar
				menu, % menuName "Menu", % (%saveVar% == "yes"? "Check":"UnCheck"), % menuItem.name
			}
		}
		menu, MainMenu, add, % menuName, % ":" menuName "Menu"
	}
	gui 1:menu, MainMenu
	
	; Input & Output extension dummy menus to populate with refreshGUI() later
	menu, % "InputExtTypes", add							
	menu, % "OutputExtTypes", add
}


; Refreshes GUI to reflect current settings or to default (clear) with true param
; -------------------------------------------------------------------------------
refreshGUI(resetGUI:=false) {
	global
	local opt, key, val, idx, optNum, checkOpt, changeOpt, x, y, yH, gPos, menuName
	static selectedJob
	gui 1:submit, nohide

	; Refresh GUI to defaults
	; ---------------------------------------
	if ( resetGUI ) { 																			; Only hide & clear all checkboxes, editboxes and dropdowns if changing jobs or media types
		for key, opt in GUI.chdmanOpt {
			guiToggle("hide", [opt.name "_checkbox", opt.name "_edit", opt.name "_dropdown"])	; Hide all checkboxes, editfields and dropdowns	
			guiCtrl({(opt.name "_checkbox"):0})													; Uncheck all checkboxs
		}
		
		if ( job.Options.length() == 0 )	{															
			guiToggle("hide", "groupboxOptions")												; No options to show for this job, so hide the group
			guiCtrl("moveDraw", {groupboxOptions:"h0"})											; Resize options groupbox height for no options
		}
		else {																					; Show or hide checkbox options
			guiToggle("show", "groupboxOptions")
			gPos := guiGetCtrlPos("groupboxOptions")											; Assign x & y values to groupbox x & y positions
			idx := 0, yH := 0, x := gPos.x+10, y := gPos.y										
			
			for optNum, opt in job.Options { 													; Show appropriate options according to selected type of job and media type
				if ( !opt || opt.hidden )
					continue
				
				if ( opt.hasKey("editField") )													; The option can ONLY have either a dropdown or editfield
					changeOpt := opt.name "_edit"
				else if ( opt.hasKey("dropdownOptions") )
					changeOpt := opt.name "_dropdown"
				checkOpt := opt.name "_checkbox"

				if ( idx == chdmanOptionMaxPerSide )											; We've run out of vertical room to show more chdman options so new options go into next column
					x += 400, y := gPos.y, yH := 1, idx := 0									
				else 
					yH++, idx++
				
				guiCtrl({(changeOpt):inStr(changeOpt,"dropdown") ? opt.dropdownOptions : opt.editField})	; Populate option dropdown list from GUI.chdmanOpt array	
				guiCtrl({(checkOpt):" " (opt.description? opt.description : opt.name)}) 					; Label the checkbox -- Default to using the chdman opt.name parameter if no description
				guiCtrl("moveDraw", {(checkOpt):"x" x + (opt.xInset? opt.xInset:0) " y" y+(yH*25), (changeOpt):"x" x+210 " y" y +(yH*25)-3})	; Move the chdman option editbox or dropdown control into place and Move the checkbox into place
				guiToggle("show", [checkOpt, changeOpt])													; Show the option and its coresponding editfield or dropdownlist
			}
			guiCtrl("moveDraw", {groupboxOptions:"h" ceil((optNum >9 ? 9 : optNum)*25)+30})					; Resize options groupbox height to fit all  options
		}
		
		; Reset and populate the input and output extension menus
		; -------------------------------------------------------
		menuExtHandler(true) 

		; Populate listview
		; ---------------------------------------
		gui 1: listView, listViewInputFiles													; Select the main file listview										
		LV_delete()																			; Delete all entries
		for idx, thisFile in scannedFiles[job.Cmd]
			LV_add("", thisFile)															; Re-populate listview with scanned files
		controlFocus, SysListView321, %mainAppName%											; Focus on listview  to stop one item being selected
	} 
	; End resetGUI

	
	
	; Changes depending on job selected
	; ---------------------------------------
	switch dropdownJob {
		case GUI.dropdowns.job.create:
			if ( selectedJob <> dropdownJob ) {																													; Stop recursive selection												
				newStartButtonLabel := "START CREATING NEW CHD"	
				guiCtrl({dropdownMedia:"|" GUI.dropdowns.media.cd "|" GUI.dropdowns.media.hd "|" GUI.dropdowns.media.ld "|" GUI.dropdowns.media.raw})
				guiCtrl("choose", {dropdownMedia:"|1"}) 																										; Choose first item in media dropdown and fire the selection
			}
		
		case GUI.dropdowns.job.extract:
			if ( selectedJob <> dropdownJob ) {																													; Stop recursive selection												
				newStartButtonLabel := "START EXTRACTING MEDIA"
				guiCtrl({dropdownMedia:"|" GUI.dropdowns.media.cd "|" GUI.dropdowns.media.hd "|" GUI.dropdowns.media.ld "|" GUI.dropdowns.media.raw})
				guiCtrl("choose", {dropdownMedia:"|1"}) 																										; Choose first item in media dropdown and fire the selection
			}
		
		case GUI.dropdowns.job.info:
			guiToggle("disable", ["dropdownMedia", "buttonOutputExtType", "buttonInputExtType", "editOutputFolder", "buttonBrowseOutput"])
			if ( selectedJob <> dropdownJob ) {
				newStartButtonLabel := "GET INFO FROM CHD FILES"
				guiCtrl({dropdownMedia:"|CHD Files"})
				guiCtrl("choose", {dropdownMedia:1}) ; Choose first item in media dropdown but since its disabled, dont fire the selection
			}
			
		case GUI.dropdowns.job.verify:
			guiToggle("disable", ["dropdownMedia", "buttonOutputExtType", "buttonInputExtType", "editOutputFolder", "buttonBrowseOutput"])
			if ( selectedJob <> dropdownJob ) {
				newStartButtonLabel := "START CHD VERIFICATION"
				guiCtrl({dropdownMedia:"|CHD Files"})
				guiCtrl("choose", {dropdownMedia:1}) ; Choose first item in media dropdown but since its disabled, dont fire the selection
			}
		
		;case GUI.dropdowns.job.delMeta, GUI.dropdowns.job.addMeta:
		default:
			newStartButtonLabel := "START JOBS!"
			guiToggle("disable", "all")
			guiToggle("enable", "dropdownJob")
			msgbox % "Not implemented yet"
	}
	selectedJob := dropdownJob

	
	; Enable buttons, dropdowns and menus
	; ---------------------------------------
	guiToggle("hide", "buttonCancelAllJobs")
	guiToggle("show", "buttonStartJobs")
	guiToggle("enable", ["dropdownJob", "dropdownMedia", "buttonAddFiles", "buttonAddFolder", "buttonInputExtType", "listViewInputFiles", "buttonBrowseOutput", "editOutputFolder", "buttonOutputExtType"])
	guiToggle((scannedFiles[job.Cmd].length()>0 ? "enable":"disable"), ["buttonStartJobs", "buttonselectAllInputFiles"]) 		; Enable start button if there are jobs in the listview
	
	
	; Start button label
	; ---------------------------------------
	if ( newStartButtonLabel ) {
		guiCtrl({buttonStartJobs:newStartButtonLabel})
		imageButton.create(startButtonHWND, GUI.buttons.start.normal, GUI.buttons.start.hover, GUI.buttons.start.clicked, GUI.buttons.start.disabled)	; Default button colors,  must be set after changing button text
	}
	

	; Enable ALL chdman option checkboxes
	; ---------------------------------------
	for optNum, opt in job.Options															
		guiToggle("enable", opt.name "_checkbox")
	
	
	; Enable or disable chdman option editfields, dropdowns or slave options depending on the checked status
	; ---------------------------------------
	for optNum, opt in job.Options														
		guiToggle((guiCtrlGet(opt.name "_checkbox") ? "enable":"disable"), [opt.name "_dropdown", opt.name "_edit", opt.masterOf "_checkbox", opt.masterOf "_dropdown", opt.masterOf "_edit"]) ; If checked, enable or disable dropdown or editfields

	
	; Hide progress bars, progress text & progress groupbox
	; ---------------------------------------
	guiToggle("hide", ["progressAll", "progressTextAll", "groupBoxProgress"])
	loop % jobQueueSizeLimit
		guiToggle("hide", ["progress" a_index, "progressText" a_index, "progressCancelButton" a_index])


	; Show the main menu
	; ---------------------------------------
	if ( !mainMenuVisible && mainAppMenuGet ) {
		dllCall("SetMenu", "uint", mainAppHWND, "uint", mainAppMenuGet) 					
		mainAppMenuGet := DllCall("GetMenu", "uint", mainAppHWND)
		mainMenuVisible := true
	}
	
	; Set status text
	; ---------------------------------------
	SB_SetText(scannedFiles[job.Cmd].length()? scannedFiles[job.Cmd].length() " jobs in the " stringUpper(job.Cmd) " queue. Ready to start!" : "Add files to the job queue to start", 1)
	
	; Show and resize main GUI
	; ---------------------------------------
	gui 1:show, autosize x%mainWinPosX% y%mainWinPosY%, % mainAppName
}




; Show or hide the verbose window
; -------------------------------
showVerboseWindow(show:="yes")
{
	global
	static created
	
	if ( !created ) {
		created := true
		gui 2:-sysmenu +resize
		gui 2:margin, 5, 10
		gui 2:add, edit, % "w" verboseWinPosW-10 " h" verboseWinPosH-20 " readonly veditVerbose",
	}
	if ( show == "yes" ) {
		gui 2:show, % "w" verboseWinPosW " h" verboseWinPosH " x" verboseWinPosX " y" verboseWinPosY, % mainAppNameVerbose
		sendMessage 0x115, 7, 0, Edit1, % mainAppNameVerbose		; Scroll to bottom of log
		controlFocus,, % mainAppNameVerbose
	}
	else if ( show == "no" ) {
		gui 2:hide
	}
}


; Show CHD info info seperate window
; -- grab new data 'JIT'
; ----------------------------------
showCHDInfo(fullFileName)
{
	global
	local a, line, file, infoLineNum := 0, compressLineNum := 0, metadataTxt := ""
	
	if ( !fileExist(fullFileName) )
		return false
		
	file := splitPath(fullFilename)
	guiCtrl({"textCHDInfoTitle":file.file}, 3)																	; Change Title to filename
	loop, parse, % runCMD(chdmanLocation " info -v -i """ fullFilename """", file.dir).msg, % "`n"				; Loop through chdman 'info' stdOut
	{
		if ( a_index == 1 )																						; Skip first line of output
			continue
		line := regExReplace(a_loopField, "`n|`r")																; Remove all CR/LF
		if ( inStr(line, "Metadata") ) {																		; If we find string 'Metadata' in line, we know to add text to metadata string
			line := strReplace(line, "Metadata:")																; Remove 'Metadata:' as its redundant
			metadataTxt .= trim(line, " ") "`n"
		}
		if ( inStr(line, "TRACK:") ) {																			; Finding 'TRACK:' in text informs us we are in metadata section of output
			line := trim(line, " "), line := strReplace(line, " ", " | "), line := strReplace(line, ":", ": ")  ; Fix formatting ...
			metadataTxt .= strReplace(line, ".") "`n`n"															; ... and add it to the metadata string
		}
		else if ( inStr(line, ": ") ) {																			; Otherwise all data is part of file information
			infoLineNum++																						; Increase line number counter
			a := strSplit(line, ": ")																			; Split text into parts
			guiCtrl({("textCHDInfoTextInfoTitle_" infoLineNum):trim(a[1], " ") ": "}, 3)						; Add part 1 as subtitle (ie - "File name", "Size", "SHA1", etc)
			guiCtrl({("editCHDInfoTextInfo_" infoLineNum):trim(a[2], " ")}, 3)									; Part 2 is the information itself 
		}
		else if ( line == "----------  -------  ------------------------------------" )								; When we find this string, we know we are in the overview Compression section
			compressLineNum := 1																					; ... So flag it, use flag as the line counter and move to next loop
		else if ( compressLineNum ) {																					
			line := trim(line, a_space)
			line := regExReplace(line, "      |     |    |   |  ", ";")												; Change all "|" into ";" in line and remove redundant space
			a := strSplit(line, ";")																				; Then split it into part
			if ( a[1] ) {
				guiCtrl({("textCHDInfoHunks_" compressLineNum):trim(a[1], a_space)}, 3)								; Part 1 is Hunks
				guiCtrl({("textCHDInfoType_" compressLineNum):trim(a[3] " " a[4] " " a[5] " " a[6], a_space)}, 3)	; Part 2 is Compression Type
				guiCtrl({("textCHDInfoPercent_" compressLineNum):trim(a[2], a_space)}, 3)							; Part 3 is percentage of compression
			}
			compressLineNum++																						; Add to meta line number
		}
	}
	guiCtrl({"editMetadata": metadataTxt}, 3)
	controlFocus, , % "CHD Info"
	return true
}



; Receieve message data from thread script
; ----------------------------------------
receiveData(wParam, ByRef lParam) 
{
	global msgData, queuedMsgData
	
	data := json(strGet( numGet(lParam + 2*A_PtrSize) ,, "utf-8"))
	msgData[data.pSlot] := data		; Assign globally so we can use anywhere in script - mainly to kill job if user selects	
	queuedMsgData.push(data)
	
	parseMsgData()
}
	
	
	
; Parse data receieved from thread script 
; --------------------------------------
parseMsgData()							; This is split from receieveData so parsing can be called in other parts of the script without having to receive data from thread
{
	global 
	local recvData, percentAll
	static report := []
	
	while ( queuedMsgData.length() > 0 ) {
		recvData := queuedMsgData.removeAt(1)
		
		if ( recvData.log )
			log("Job " recvData.idx " - " recvData.log)
		
		if ( recvData.report )
			report[recvData.idx] .= recvData.report		; Static variable adds to end report data

		switch recvData.status {
			case "started":
				job.workTally.running++
			
			case "success":
				job.workTally.success++
				SB_SetText("Job " recvData.idx " finished successfully!", 1)
				if ( removeFileEntryAfterFinish == "yes" ) {
					removeFromArray(recvData.fromFileFull, scannedFiles[recvData.cmd])
					loop % LV_GetCount()												; Clear finished files from scanned files
						if ( LV_GetText2(a_index) == recvData.fromFileFull )
							LV_Delete(a_index)
				}

			case "fileExists":
				job.workTally.skipped++
				SB_SetText("Job " recvData.idx " skipped", 1)
			
			case "error":
				job.workTally.withError++
				SB_SetText("Job " recvData.idx " failed", 1)
				
			case "killed":
				job.workTally.cancelled++
				SB_SetText("Job " recvData.idx " cancelled", 1)
			
			case "halted":
				job.workTally.cancelled += job.workQueue.length() + 1				; Tally up totals
				job.workQueue := []											; Empty the work queue
				job.workTally.haltedMsg := recvData.log						; Set flag and error log
				log("Fatal Error. Halted all jobs")
				
			case "finished":
				job.workTally.finished++
				job.workTally.report .= report[recvData.idx]
				msgData[recvData.pSlot] := ""
				report[recvData.idx] := ""

				percentAll := ceil((job.workTally.finished/job.workTally.total)*100)
				guiCtrl({progressAll:percentAll, progressTextAll:job.workTally.finished " jobs of " job.workTally.total " completed " (job.workTally.withError ? "(" job.workTally.withError " error" (job.workTally.withError>1? "s)":")") : "")" - " percentAll "%" })
				availPSlots.push(recvData.pSlot)										; Add an available slot to array
		}
		
		if ( recvData.progress )
			guiControl,1:, % "progress" recvData.pSlot, % recvData.progress
		if ( recvData.progressText )
			guiControl,1:, % "progressText" recvData.pSlot, % recvData.progressText
	}
}


; Job timeout timer
; Timer is set to call this function every 1000 ms
; ----------------------
jobTimeoutTimer() 
{
	global msgData, jobQueueSize, jobTimeoutSec, queuedMsgData
	
	loop % jobQueueSize {			 	; Loop though jobs to check to see whos msgData is empty - hense to response from thread script
		if ( !msgData[a_index] )		; If data exists return 
			continue
		else
			msgData[a_index].timeout++	; Otherwise add 1 to timer counter
		
		if ( msgData[a_index].timeout >= jobTimeoutSec ) {			; If timer counter exceeds threashold, we will assume thread is locked up or has errored out 
			processPIDClose(msgData[a_index].chdmanPID, 5, 150)		; So attempt to close the process associated with it
			
			msgData[a_index].status := "error"						; Update msgData[] with messages and send "error" flag for that job, then parse the data
			msgData[a_index].log := "Error: Job timed out"
			msgData[a_index].report := "`nError: Job timed out`n`n`n"
			msgData[a_index].progress := 100
			msgData[a_index].progressText := "Timed out -  " msgData[a_index].workingTitle
			queuedMsgData.push(msgData[a_index])
			parseMsgData()
			
			msgData[a_index].log := ""								; Update msgData[] again, but now send "finished" flag and parse again 
			msgData[a_index].report := ""
			msgData[a_index].status := "finished"
			queuedMsgData.push(msgData[a_index])
			parseMsgData()
			return true
		}
	}
	return false
}




; Create  or add to the input files queue (return a work queue)
; -------------------------------------------------------
createJob(command, theseJobOpts, OutputExtTypes="", inputFiles="", outputFolder="") 
{
	global
	local wQueue := [], idx, thisOpt, optVal, cmdOpts := "", fromFileFull, fileFull, toExt

	gui 1:submit, nohide
	
	for idx, thisOpt in (isObject(theseJobOpts) ? theseJobOpts : [])								; Parse through supplied Options associated with job
	{
		if ( guiCtrlGet(thisOpt.name "_checkbox", 1) == 0 )											; Skip if the checkbox is not checked
			continue
		if ( thisOpt.editField )
			optVal := guiCtrlGet(thisOpt.name "_edit")
		else if ( thisOpt.dropdownOptions ) {
			optVal := guiCtrlGet(thisOpt.name "_dropdown")											; Get the dropdown value for the current GUI.chdmanOpt
			optVal := isObject(thisOpt.dropdownValues) ? thisOpt.dropdownValues[optVal] : optVal	; If this dropdown option contains a dropdownValues array, optVal becomes the index for that array
		}
		if ( thisOpt.paramString ) {
			optVal := optVal ? (thisOpt.useQuotes ? " """ optVal """" : " " optVal) : ""
			cmdOpts .= " -" thisOpt.paramString . optVal 											; Create the chdman options string
		}
	}
	
	for idx1, fromFileFull in (isObject(inputFiles) ?  inputFiles : [])
	{
		fileFull := splitPath(fromFileFull)
		OutputExtTypes := isObject(OutputExtTypes) ? OutputExtTypes : ["dummy"]
		for idx, toExt in OutputExtTypes {
			q := {}
			q.idx				:= wQueue.length() + 1
			q.id 				:= command q.idx
			q.hostPID			:= dllCall("GetCurrentProcessId")
			q.cmd 				:= command
			q.cmdOpts			:= cmdOpts
			q.workingDir 		:= fileFull.dir
			q.outputFolder 		:= outputFolder ? outputFolder : ""
			q.fromFile 			:= fileFull.file
			q.fromFileExt		:= fileFull.ext
			q.fromFileNoExt 	:= fileFull.noExt
			q.fromFileFull		:= fromFileFull
			if ( command <> "verify" && command <> "info" ) {
				q.toFile		:= fileFull.noExt "." toExt
				q.toFileExt 	:= toExt
				q.toFileNoExt	:= fileFull.noExt								; For the target file, we use the same base filename as the source
				q.toFileFull	:= outputFolder "\" fileFull.noExt "." toExt
			}
			q.createSubDir		:= createSubDir_checkbox
			q.deleteInputDir	:= deleteInputDir_checkbox
			q.deleteInputFiles 	:= deleteInputFiles_checkbox
			q.keepIncomplete 	:= keepIncomplete_checkbox
			q.workingTitle 		:= (q.toFile ? q.toFile : q.fromFile)
			
			wQueue.push(q)														; Push data to array
		}
	}
	return wQueue
}


; List filenames from CUE, GDI and TOC files 
; ------------------------------------------
getFilesFromCUEGDITOC(inputFiles) 
{
	fileList := []
	if ( !isObject(inputFiles) )
		inputFiles := Array(inputFiles)
		
	for idx, thisFile in inputFiles {
		if ( !fileExist(thisFile) )
			continue
		f := splitPath(thisFile)
		
		switch f.ext {
		case "cue", "toc":
			loop, Read, % thisFile 
			{
				if ( stPos := inStr(a_loopReadLine, "FILE """, true) ) {
					stPos += 6
					endPos := inStr(a_loopReadLine, """", true, -1)
					file := subStr(a_loopReadLine, stPos, (endPos-stPos))
					fileList.push(f.dir "\" file)
				}
			}

		case "gdi":
			loop, Read, % thisFile 
			{
				if ( a_loopReadLine is digit && a_index > 1 ) {
					loop parse, a_loopReadLine, %a_space%
						if ( inStr(a_LoopField, ".") ) 
							fileList.push(f.dir "\" a_loopField)
				}
			}
		}
		fileList.push(thisFile)
	}
	return fileList
}



; Log messages and send to verbose window
; --------------------------------------
log(newMsg:="", newline:=true, clear:=false, timestamp:=true) 
{
	global mainAppNameVerbose, editVerbose
	
	if ( !newMsg ) 
		return false
	
	newMsg := timestamp ? "[" a_Hour ":" a_Min ":" a_Sec "]  " newMsg : newMsg
	msg := clear? newMsg : guiCtrlGet("editVerbose", 2) . newMsg

	guiCtrl({editVerbose:msg (newline? "`n" : "")}, 2)
	sendMessage 0x115, 7, 0, Edit1, % mainAppNameVerbose	; Scroll to bottom of log
}



; Read or write to ini file
; -------------------------
ini(job="read", var:="") 
{
	global
	local varsArry := isObject(var)? var : [var]
	
	if ( varsArry[1] == "" )
		return false

	for idx, varName in varsArry {
		if ( job == "read" ) {
			defaultVar := %varName%
			iniRead, %varName%, % mainAppName ".ini", Settings, % varName
			if ( !%varName% || %varName% == "ERROR" || %varName% == "" ) {
				%varName% := defaultVar
			}
		}
		else if ( job == "write" ) {
			if ( !%varName% || %varName% == "ERROR" || %varName% == "" )
				%varName% := %varName%
			iniWrite, % %varName%, % mainAppName ".ini", Settings, % varName
			;log("Saved " varName " with value " %varName%)
		}
	}
}



playSound() 
{
	SoundBeep, 300, 100
	SoundBeep, 600, 600
}



; Send data across script instances
; -------------------------------------------------------
sendAppMessage(ByRef StringToSend, ByRef TargetScriptTitle) 
{
  VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)
  SizeInBytes := strPutVar(StringToSend, StringToSend, "utf-8")
  NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)
  NumPut(&StringToSend, CopyDataStruct, 2*A_PtrSize)
  Prev_DetectHiddenWindows := A_DetectHiddenWindows
  Prev_TitleMatchMode := A_TitleMatchMode
  DetectHiddenWindows On
  SetTitleMatchMode 2
  SendMessage, 0x4a, 0, &CopyDataStruct,, % TargetScriptTitle
  DetectHiddenWindows %Prev_DetectHiddenWindows%
  SetTitleMatchMode %Prev_TitleMatchMode%
  return errorLevel
 }

strPutVar(string, ByRef var, encoding)
{
	varSetCapacity( var, StrPut(string, encoding) * ((encoding="utf-16"||encoding="cp1200") ? 2 : 1) )
	return StrPut(string, &var, encoding)
}


; runCMD v0.94 by SKAN on D34E/D37C @ autohotkey.com/boards/viewtopic.php?t=74647
; Based on StdOutToVar.ahk by Sean @ autohotkey.com/board/topic/15455-stdouttovar      

runCMD(CmdLine, workingDir:="", codepage:="CP0", Fn:="RunCMD_Output")  
{
	local
	global a_Args

	Fn := isFunc(Fn) ? func(Fn) : 0
	,dllCall("CreatePipe", "PtrP",hPipeR:=0, "PtrP",hPipeW:=0, "Ptr",0, "Int",0)
	,dllCall("SetHandleInformation", "Ptr",hPipeW, "Int",1, "Int",1)
	,dllCall("SetNamedPipeHandleState","Ptr",hPipeR, "UIntP",PIPE_NOWAIT:=1, "Ptr",0, "Ptr",0)
	,P8 := (A_PtrSize=8)
	,varSetCapacity(SI, P8 ? 104 : 68, 0)                          ; STARTUPINFO structure
	,numPut(P8 ? 104 : 68, SI)                                     ; size of STARTUPINFO
	,numPut(STARTF_USESTDHANDLES:=0x100, SI, P8 ? 60 : 44,"UInt")  ; dwFlags
	,numPut(hPipeW, SI, P8 ? 88 : 60)                              ; hStdOutput
	,numPut(hPipeW, SI, P8 ? 96 : 64)                              ; hStdError
	,varSetCapacity(PI, P8 ? 24 : 16)                              ; PROCESS_INFORMATION structure

	if not dllCall("CreateProcess", "Ptr",0, "Str",CmdLine, "Ptr",0, "Int",0, "Int",True,"Int",0x08000000 | dllCall("GetPriorityClass", "Ptr",-1, "UInt"), "Int",0,"Ptr", workingDir ? &workingDir : 0, "Ptr",&SI, "Ptr",&PI)  
		return Format("{1:}", "", ErrorLevel := -1, dllCall("CloseHandle", "Ptr",hPipeW), dllCall("CloseHandle", "Ptr",hPipeR))

	dllCall("CloseHandle", "Ptr",hPipeW)
	,a_Args.runCMD := {"PID": NumGet(PI, P8 ? 16 : 8, "UInt")}
	,file := fileOpen(hPipeR, "h", codepage)
	,lineNum := 1,  sOutput := ""
	while ( a_Args.runCMD.PID + dllCall("Sleep", "Int", 50) && dllCall("PeekNamedPipe", "Ptr",hPipeR, "Ptr",0, "Int",0, "Ptr",0, "Ptr",0, "Ptr",0) ) {
		while ( a_Args.runCMD.PID && (line := file.readLine()) ) {
			sOutput .= Fn ? Fn.call(line, lineNum++, a_Args.runCMD.PID) : line
		}
	}
	
	a_Args.runCMD.PID := 0
	hProcess := numGet(PI, 0), hThread  := numGet(PI, a_PtrSize)
	,dllCall("GetExitCodeProcess", "Ptr",hProcess, "PtrP",ExitCode:=0), dllCall("CloseHandle", "Ptr",hProcess)
	,dllCall("CloseHandle", "Ptr",hThread), dllCall("CloseHandle", "Ptr",hPipeR)
	
	return {"msg":sOutput, "exitcode":ExitCode}
}


; Create a folder
; ---------------------------------------------
createFolder(newFolder) 
{
	if ( fileExist(newFolder) == "D" ) {	; Folder exists
		createdFolder := newFolder
	}
	else {
		if ( !splitPath(newFolder).drv ) {						; No drive letter can be assertained, so it's invalid
			createdFolder := false
		} else {												; Output folder is valid but dosent exist
			fileCreateDir, % regExReplace(newFolder, "\\$")
			createdFolder := errorLevel? false : newFolder
		}
	}
	return createdFolder										; Returns the folder name if created or it exists, or false if no folder was created
}

; Kill all namDHC process (including chdman.exe)
; -----------------------------------------------
killAllProcess() 
{
	global mainAppName, mainAppNameVerbose, runAppName, runAppNameConsole

	while ( true ) {
		process, close, % "chdman.exe"
		if ( !errorLevel )
			break
	}

	for idx, app in [mainAppName, mainAppNameVerbose, runAppName, runAppNameConsole] {
		hwnd := winExist(app)
		winActivate % "ahk_id " hwnd
		winClose % "ahk_id " hwnd
		if ( winExist("ahk_id " hwnd) ) {
			postMessage, 0x0112, 0xF060,,, % "ahk_id " hwnd
			winKill % "ahk_id " hwnd
		}
	}
}

; Check if menu item has a checkmark (is checked)
; -----------------------------------------------
isMenuChecked(menuName, itemNumber)  
{
	static MIIM_STATE := 1, MFS_CHECKED := 0x8
	hMenu := MenuGetHandle(menuName)
	VarSetCapacity(MENUITEMINFO, size := 4*4 + A_PtrSize*8, 0)
	NumPut(size, MENUITEMINFO)
	NumPut(MIIM_STATE, MENUITEMINFO, 4, "UInt")
	DllCall("GetMenuItemInfo", Ptr, hMenu, UInt, itemNumber - 1, UInt, true, Ptr, &MENUITEMINFO)
	return !!(NumGet(MENUITEMINFO, 4*3, "UInt") & MFS_CHECKED)
}


; Disable a windows close button
; ------------------------------
disableCloseButton(hWnd="") 
{
	If ( hWnd == "" )
		hWnd := winExist("A")
	hSysMenu := dllCall("GetSystemMenu","Int",hWnd,"Int",FALSE)
	nCnt := dllCall("GetMenuItemCount","Int",hSysMenu)
	dllCall("RemoveMenu","Int",hSysMenu,"UInt",nCnt-1,"Uint","0x400")
	dllCall("RemoveMenu","Int",hSysMenu,"UInt",nCnt-2,"Uint","0x400")
	dllCall("DrawMenuBar","Int",hWnd)
	return ""
}


; Merge two objects or arrays
; -------------------------
mergeObj(sourceObj, targetObj) 
{
	targetObj := isObject(targetObj) ? targetObj : {}
	for k, v In sourceObj {
		if ( isObject(v) ) {
			if ( !targetObj.hasKey(k) )
				targetObj[k] := {}
			mergeObj(v, targetObj[k])
		} else
			targetObj[k] := v
	}
}

; Show an object as text
; ----------------------
showObj(obj, s := "") 
{
	static str
	if (s == "")
		str := ""
	for idx, v In obj {
		n := (s == "" ? idx : s . ", " . idx)
		if isObject(v)
			showObj(v, n)
		else
			str .= "[" . n . "] = " . v . "`r`n"
	}
	return rTrim(str, "`r`n")
}


procCountDDList()
{
	loop % envGet("NUMBER_OF_PROCESSORS")
		lst .= a_index "|"					; Create processor count dropdown list
	return "|" lst "|"						; Last "|" is to select last as default
}

; Splitpath function
; -------------------
splitPath(inputFile) 
{
	splitPath inputFile, file, dir, ext, noext, drv
	return {file:file, dir:dir, ext:ext, noext:noext, drv:drv}
}


; To allow an inline call of the LV_GetText() function
; -----------------------------------------------------
LV_GetText2(row, byRef rtn="")				
{
	rtn := LV_GetText(str, row)
	return str
}


; Get position of a GUI control
; --------------------------------
guiGetCtrlPos(ctrl, guiNum:=1) 
{
	guiControlGet, rtn, %guiNum%:Pos, %ctrl%
	return {x:rtnx, y:rtny, w:rtnw, h:rtnh}
}


; Convert string to lowercase
; ----------------------------
stringLower(str) 
{
	stringLower, rtn, str
	return rtn
}


;Convert string to uppercase
; ---------------------------
stringUpper(str, title:=false) 
{
	stringUpper, rtn, str, % title? "T":""
	return rtn
}


; Check if value is in array
; ---------------------------
inArray(cVal, arry) 
{
	for idx, val in arry
		if ( cVal == val )
			return true
	return false
}


; Create a string of items seperated by a delimeter from an array
; ---------------------------------------------------------------
arrayToString(thisArray, delim:=", ")
{
	for idx, val in thisArray
		rtn .= val delim
	return regExReplace(rtn, delim, "", "", 1, -1)
}


; Create an Array from a string with delimeters
; ---------------------------------------------
arrayFromString(string, delim:=",") 
{
	rtnArray := []
	loop parse, string, % delim
		rtnArray.push(a_loopfield)
	return rtnArray
}


; Remove an item from an array
; -------------------------------
removeFromArray(removeItem, byRef thisArray)
{
	if ( !isObject(thisArray) )
		return thisArray
	
	for idx, val in thisArray {
		if ( val == removeItem ) {
			thisArray.removeAt(idx)
			break
		}
	}
	return thisArray
}

; Get Windows current default font
; by SKAN
; ------------------------
guiDefaultFont() 
{
	varSetCapacity(LF, szLF := 28 + (A_IsUnicode ? 64 : 32), 0) ; LOGFONT structure
	if DllCall("GetObject", "Ptr", DllCall("GetStockObject", "Int", 17, "Ptr"), "Int", szLF, "Ptr", &LF)
	return {name: StrGet(&LF + 28, 32), size: Round(Abs(NumGet(LF, 0, "Int")) * (72 / A_ScreenDPI), 1)
			, weight: NumGet(LF, 16, "Int"), quality: NumGet(LF, 26, "UChar")}
	return False
}


; GUI window was moved
; --------------------
moveGUIWin(wParam, lParam)
{
	global mainWinPosX, mainWinPosY, verboseWinPosX, verboseWinPosY, mainAppName, mainAppNameVerbose
	
	if ( a_gui == 1 ) {
		winGetPos, mainWinPosX, mainWinPosY,,, % mainAppName
		setTimer, writemoveGUIWin, -1000
	}
	else if ( a_gui == 2 ) {
		winGetPos, verboseWinPosX, verboseWinPosY,,, % mainAppNameVerbose
		setTimer, writemoveGUIWin, -1000
	}
	return
	writemoveGUIWin:
		ini("write", ["mainWinPosX", "mainWinPosY"])
		ini("write", ["verboseWinPosX", "verboseWinPosY"])
	return
}


; Verbose window was resized
; --------------------------
2GuiSize(guiHwnd, eventInfo, W, H) 
{
	global verboseWinPosH := H, verboseWinPosW := W
	
	autoXYWH("wh", "editVerbose") 						; Resize edit control with window
	setTimer, write2GuiSize, -1000					
	return
	write2GuiSize:
		ini("write", ["verboseWinPosH", "verboseWinPosW"])
	return	
}


; =================================================================================
; Function: AutoXYWH
;   Move and resize control automatically when GUI resizes.
; Parameters:
;   DimSize - Can be one or more of x/y/w/h  optional followed by a fraction
;             add a '*' to DimSize to 'MoveDraw' the controls rather then just 'Move', this is recommended for Groupboxes
;   cList   - variadic list of ControlIDs
;             ControlID can be a control HWND, associated variable name, ClassNN or displayed text.
;             The later (displayed text) is possible but not recommend since not very reliable 
; Examples:
;   AutoXYWH("xy", "Btn1", "Btn2")
;   AutoXYWH("w0.5 h 0.75", hEdit, "displayed text", "vLabel", "Button1")
;   AutoXYWH("*w0.5 h 0.75", hGroupbox1, "GrbChoices")
; ---------------------------------------------------------------------------------
; Version: 2015-5-29 / Added 'reset' option (by tmplinshi)
;          2014-7-03 / toralf
;          2014-1-2  / tmplinshi
; requires AHK version : 1.1.13.01+
; =================================================================================
autoXYWH(DimSize, cList*)  ; http://ahkscript.org/boards/viewtopic.php?t=1079
{      
  static cInfo := {}
 
  If (DimSize = "reset")
    Return cInfo := {}
 
  for i, ctrl in cList {
    ctrlID := A_Gui ":" ctrl
    If ( cInfo[ctrlID].x = "" ){
        guiControlGet, i, %A_Gui%:Pos, %ctrl%
        MMD := InStr(DimSize, "*") ? "MoveDraw" : "Move"
        fx := fy := fw := fh := 0
        For i, dim in (a := StrSplit(RegExReplace(DimSize, "i)[^xywh]")))
            If !RegExMatch(DimSize, "i)" dim "\s*\K[\d.-]+", f%dim%)
              f%dim% := 1
        cInfo[ctrlID] := { x:ix, fx:fx, y:iy, fy:fy, w:iw, fw:fw, h:ih, fh:fh, gw:A_GuiWidth, gh:A_GuiHeight, a:a , m:MMD}
    }Else If ( cInfo[ctrlID].a.1) {
        dgx := dgw := A_GuiWidth  - cInfo[ctrlID].gw  , dgy := dgh := A_GuiHeight - cInfo[ctrlID].gh
        For i, dim in cInfo[ctrlID]["a"]
            Options .= dim (dg%dim% * cInfo[ctrlID]["f" dim] + cInfo[ctrlID][dim]) A_Space
        GuiControl, % A_Gui ":" cInfo[ctrlID].m , % ctrl, % Options
} } 
}


; Function replacement for guiControl
; ------------------------------------
; Example usages:
; guiCtrl({thisButton:"New Button Text"}, 1) - works on GUI #1
; guiCtrl("move", {stuff:"x9 w200", thing:"x1 y2"}, 3)

guiCtrl(arg1:="", arg2:="", arg3:="") 
{
	if ( isObject(arg1) )
		obj := arg1, guiNum := arg2 ? arg2 : 1
	else
		obj := arg2, cmd := arg1, guiNum := arg3 ? arg3 : 1

	for ele, newVal in obj
		guiControl, %guiNum%:%cmd%, % ele, % newVal
} 


; guiToggle GUI controls
; ------------------------------------------
guiToggle(doWhat, whichControls, guiNum:=1) 
{
	global mainAppName
	
	if ( !doWhat || !whichControls )
		return false
	
	doWhatArray := isObject(doWhat) ? doWhat : [doWhat]
	ctlArray := isObject(whichControls) ? whichControls : (whichControls == "all" ? getWinControls(mainAppName, "Static") : [whichControls])

	for idx, dw in doWhatArray
		for idx2, ctl in ctlArray
			guiControl %guiNum%:%dw%, % ctl
}



; Function replacement for guiControlGet
; --------------------------------------
guiCtrlGet(ctrl, guiNum:=1) 
{
	guiControlGet, rtn, %guiNum%:, %ctrl%
	return rtn
}



; Get a windows control elements as an array
; -------------------------------------------
getWinControls(win, ignoreStr:="") 
{
	rtnArray := []
	winGet, ctrList, ControlList, % win
	loop, parse, ctrList, `n
	{
		if ( ignoreStr && inStr(a_loopfield, ignoreStr) ) ; Dont disable text elements
			continue
		rtnArray.push(a_loopfield)	
	}
	return rtnArray
}



; Draw spaces by count
; --------------------
drawSpace(num:=1) 
{
	if ( num < 1 ) 
		return ""
	loop % num
		rtn .= a_space
	return rtn
}

; Draw a line by count
; --------------------
drawLine(num:=1) 
{
	if ( num < 1 )
		return ""
	loop % num
		rtn .= "─"
	return rtn	
}

; Get an envirmoent variable
; --------------------------
envGet(enviro) 
{
	envGet, rtn, % enviro
	return rtn
}


; Delete a file 
; -------------
fileDelete(file, attempts:=5, sleepdelay:=200) 
{
	loop % (attempts < 1 ? 1 : attempts) { 			; 5 attempts to delete the file
		fileDelete, % file
		if ( errorLevel == 0 )						; Success
			return true
		sleep % sleepdelay
	}
	return false
}


; Delete a folder
; ---------------
folderDelete(dir, attempts:=5, sleepdelay:=200) 
{
	loop % (attempts < 1 ? 1 : attempts) {
		fileRemoveDir % dir, 0						; Attempt to delete the directory 5 times
		if ( errorLevel == 0 )						; Success
			return true
		sleep % sleepdelay
	}
	return false
}


; Attempt to close a process by PID
; ---------------------------------
processPIDClose(procPID, attempts:=5, sleepdelay:=200) 
{
	loop % attempts {
		process, close, % procPID
		if ( errorLevel == procPID )				; ErrorLevel returns PID if successful, or 0 if unsuccessful
			return true
		sleep % sleepdelay
	}
	return false
}



/*
Milliseconds to HH:MM:SS
Thanks Odlanir
https://www.autohotkey.com/boards/viewtopic.php?t=45476
*/
millisecToTime(msec) 
{
	secs := floor(mod((msec / 1000), 60))
	mins := floor(mod((msec / (1000 * 60)), 60) )
	hour := floor(mod((msec / (1000 * 60 * 60)), 24))
	return Format("{:02}:{:02}:{:02}", hour, mins, secs)
}


; Thanks maestrith 
; https://www.autohotkey.com/board/topic/88685-download-a-url-to-a-variable/
URLDownloadToVar(url){
	try {
		hObject:=ComObjCreate("WinHttp.WinHttpRequest.5.1")
		hObject.Open("GET",url)
		hObject.Send()
		return hObject.ResponseText
	}
}


checkForUpdates(wParam:="", userClicked:=false) 
{
	global currentAppVersion, mainAppName, githubRepoURL
	gui 4:+OwnDialogs
	
	log("Checking for updates ... ")
	
	if ( !a_isCompiled ) {
	 	if ( userClicked )
			msgbox 16, % "Error", % "Can only update compiled binaries"
		log("Error updating: Can only update compiled binaries")  ; no time-stamp
		return
	}
		
	/*
	obj.tag_name 						= version (ie-"namDHCv1.03")
	obj.body							= version changes
	obj.assets[1].browser_download_url	= URL *should* point to chdman.exe
	obj.assets[2].browser_download_url	= URL *should* point to namDHC.exe
	obj.assets[3].browser_download_url	= URL *should* point to namDHC_vx.xx.zip
	obj.created_at						= date created
	*/	
	JSON := URLDownloadToVar(githubRepoURL)
	obj := json(JSON)
	
	if ( !isObject(obj) )
		log("Error updating: Update info invalid")
	
	else if ( obj.message && inStr(obj.message, "limit exceeded") )
		log("Error updating: Github API limit exceeded")

	else if ( !obj.tag_name )
		log("Error updating: Update info invalid")
		
	else {
		newVersion := strReplace(obj.tag_name, "namDHCv", "")
		
		if ( newVersion == currentAppVersion ) {
			if ( userClicked )
				msgbox 64, % "No new updates found", % "You are running the current version"
			log("No new updates found. You are running the current version")
			return
		}
		
		else if ( newVersion < currentAppVersion ) {
			if ( userClicked )
				msgbox 16, % "Error", % "Your version is newer then the current release!"
			log("Your version is newer then the current release!")
		}
		else if ( newVersion > currentAppVersion ) {
			log("An update was found: v" newVersion)
			msgBox, 68, % "Update available", % "A new version of " mainAppName " is available!`n`nCurrent version: v" currentAppVersion "`nLatest version: v" newVersion "`n`nChanges:`n" strReplace(obj.body, "-", "    -") "`n`nDo you want to update?"
			ifmsgbox Yes 
			{
				for idx, asset in obj.assets {
					if ( inStr(asset.browser_download_url, "namDHC.exe") )
						thisBinURL := asset.browser_download_url
				}
				if ( !thisBinURL ) {
					msgbox 16, % "Error", % "Error downloading update!"
					log("Error updating: Update binary couldn't be found in the repo!")
					return
				}
				tempDir := a_Temp "\namDHC"
				fileCreateDir, % tempDir
				tempEXEFullFile := tempDir "\namDHC.exe"
				urlDownloadToFile, % thisBinURL, % tempEXEFullFile
				if ( !fileExist(tempEXEFullFile) ) {
					msgbox 16, % "Error", % "Error downloading update!"
					log("Error updating: There was an error downloading the update")
					return
				}
				batchFile := tempDir "\update.bat"
				fileDelete(batchFile, 5, 10)
				batchText := "@timeout /t 1 /nobreak > NUL`r`n@del """ a_ScriptFullPath """ > NUL`r`n@copy """ tempEXEFullFile """ """ a_ScriptFullPath """ > NUL`r`n@start " a_ScriptFullPath "`r`n@exit 0`r`n"
				fileAppend, % batchText, % batchFile
				sleep 25
				run % batchFile
				exitApp
			}
		}
	}
}

; Close App
; ---------
GuiClose()
{
	quitApp()
	exitApp			 ; Just in case
}

quitApp() 
{
	exitApp
}