#ifndef MyAppName
#define MyAppName "members"
#endif

#ifndef MyAppVersion
#define MyAppVersion "1.0.0.4"
#endif

#ifndef MyAppPublisher
#define MyAppPublisher "Weather Hooligan"
#endif

#ifndef MyAppExeName
#define MyAppExeName "members.exe"
#endif

#ifndef MyBuildRoot
#define MyBuildRoot "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{8EFAAFB0-6B9A-4956-BD53-A09C3A3A0F58}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
SetupIconFile=..\windows\runner\resources\app_icon.ico
OutputDir=..\build\windows\installer
OutputBaseFilename=members_setup_{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyBuildRoot}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyBuildRoot}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyBuildRoot}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
