!ifndef BUILD_UNINSTALLER
!include nsDialogs.nsh
!include FileFunc.nsh

Function LiloAvatarNormalizeInstallDir
  ; The directory page can return a parent folder such as D:\ or D:\Apps.
  ; Always install into an application-owned child folder.
  ${GetFileName} "$INSTDIR" $R0
  ${if} $R0 != "LiloAvatar"
    StrCpy $INSTDIR "$INSTDIR\LiloAvatar"
  ${endIf}
FunctionEnd

Function LiloAvatarFindForeignInstallRootItem
  ; Returns the first item in $INSTDIR that is not owned by LiloAvatar.
  ; Result is written to $R3. "0" means the folder is absent, empty, or safe.
  StrCpy $R3 "0"
  IfFileExists "$INSTDIR\*.*" 0 liloavatarScanInstallRootNoClose
  FindFirst $R1 $R2 "$INSTDIR\*.*"
  liloavatarScanInstallRoot:
    StrCmp $R2 "" liloavatarScanInstallRootDone
    StrCmp $R2 "." liloavatarScanInstallRootNext
    StrCmp $R2 ".." liloavatarScanInstallRootNext
    StrCmp $R2 "LiloAvatar.exe" liloavatarScanInstallRootNext
    StrCmp $R2 "Uninstall LiloAvatar.exe" liloavatarScanInstallRootNext
    StrCmp $R2 "uninstallerIcon.ico" liloavatarScanInstallRootNext
    StrCmp $R2 "locales" liloavatarScanInstallRootNext
    StrCmp $R2 "resources" liloavatarScanInstallRootNext
    StrCmp $R2 "swiftshader" liloavatarScanInstallRootNext
    StrCmp $R2 "chrome_100_percent.pak" liloavatarScanInstallRootNext
    StrCmp $R2 "chrome_200_percent.pak" liloavatarScanInstallRootNext
    StrCmp $R2 "d3dcompiler_47.dll" liloavatarScanInstallRootNext
    StrCmp $R2 "ffmpeg.dll" liloavatarScanInstallRootNext
    StrCmp $R2 "icudtl.dat" liloavatarScanInstallRootNext
    StrCmp $R2 "libEGL.dll" liloavatarScanInstallRootNext
    StrCmp $R2 "libGLESv2.dll" liloavatarScanInstallRootNext
    StrCmp $R2 "LICENSE.electron.txt" liloavatarScanInstallRootNext
    StrCmp $R2 "LICENSES.chromium.html" liloavatarScanInstallRootNext
    StrCmp $R2 "resources.pak" liloavatarScanInstallRootNext
    StrCmp $R2 "snapshot_blob.bin" liloavatarScanInstallRootNext
    StrCmp $R2 "v8_context_snapshot.bin" liloavatarScanInstallRootNext
    StrCmp $R2 "vk_swiftshader.dll" liloavatarScanInstallRootNext
    StrCmp $R2 "vk_swiftshader_icd.json" liloavatarScanInstallRootNext
    StrCmp $R2 "vulkan-1.dll" liloavatarScanInstallRootNext
    StrCpy $R3 "$R2"
    Goto liloavatarScanInstallRootDone

  liloavatarScanInstallRootNext:
    FindNext $R1 $R2
    Goto liloavatarScanInstallRoot

  liloavatarScanInstallRootDone:
    FindClose $R1
  liloavatarScanInstallRootNoClose:
FunctionEnd

Function LiloAvatarRescueForeignInstallRootItems
  ; During upgrades, the old uninstaller may delete the whole install folder.
  ; Move foreign items out first so third-party/user files are preserved while
  ; the upgrade can continue.
  StrCpy $R6 ""

  liloavatarRescueForeignLoop:
    Call LiloAvatarFindForeignInstallRootItem
    ${if} $R3 == "0"
      Return
    ${endIf}

    ${if} $R6 == ""
      CreateDirectory "$APPDATA\LiloAvatar"
      CreateDirectory "$APPDATA\LiloAvatar\install-root-rescue"
      StrCpy $R8 "1"

      liloavatarPickForeignRescueDir:
        StrCpy $R6 "$APPDATA\LiloAvatar\install-root-rescue\upgrade-$R8"
        IfFileExists "$R6\*.*" 0 liloavatarForeignRescueDirReady
        IntOp $R8 $R8 + 1
        IntCmp $R8 1000 liloavatarForeignRescueDirExhausted liloavatarPickForeignRescueDir liloavatarForeignRescueDirExhausted

      liloavatarForeignRescueDirReady:
        ClearErrors
        CreateDirectory "$R6"
        IfErrors liloavatarForeignRescueDirFailed
    ${endIf}

    ClearErrors
    Rename "$INSTDIR\$R3" "$R6\$R3"
    IfErrors liloavatarForeignRescueMoveFailed
    DetailPrint "Moved non-LiloAvatar install-root item out of upgrade path: $INSTDIR\$R3 -> $R6\$R3"
    Goto liloavatarRescueForeignLoop

  liloavatarForeignRescueDirExhausted:
    MessageBox MB_ICONSTOP|MB_OK "LiloAvatar could not create a unique rescue folder under:$\r$\n$\r$\n$APPDATA\LiloAvatar\install-root-rescue$\r$\n$\r$\nPlease move non-LiloAvatar content out of the install folder, then run setup again."
    Abort

  liloavatarForeignRescueDirFailed:
    MessageBox MB_ICONSTOP|MB_OK "LiloAvatar could not create a rescue folder:$\r$\n$\r$\n$R6$\r$\n$\r$\nPlease move non-LiloAvatar content out of the install folder, then run setup again."
    Abort

  liloavatarForeignRescueMoveFailed:
    MessageBox MB_ICONSTOP|MB_OK "LiloAvatar could not move non-LiloAvatar content out of the install folder:$\r$\n$\r$\n$INSTDIR\$R3$\r$\n$\r$\nTarget rescue folder:$\r$\n$R6$\r$\n$\r$\nPlease close programs that may be using this folder, or move it manually, then run setup again."
    Abort
FunctionEnd

Function LiloAvatarValidateInstallDir
  Call LiloAvatarNormalizeInstallDir

  ${GetFileName} "$INSTDIR" $R0
  ${if} $R0 != "LiloAvatar"
    MessageBox MB_ICONSTOP|MB_OK "Please install LiloAvatar into its own folder, for example:$\r$\n$\r$\nD:\LiloAvatar$\r$\nD:\Apps\LiloAvatar$\r$\n$\r$\nCurrent path:$\r$\n$INSTDIR"
    Abort
  ${endIf}

  Call LiloAvatarFindForeignInstallRootItem
  ${if} $R3 != "0"
    MessageBox MB_ICONSTOP|MB_OK "The selected LiloAvatar install folder already contains non-LiloAvatar content:$\r$\n$\r$\n$INSTDIR\$R3$\r$\n$\r$\nTo protect your files and other software, choose an empty folder or a folder used only by LiloAvatar."
    Abort
  ${endIf}

  ; Refuse a doomed install when the target drive is nearly full. The payload is
  ; ~330 MB and the installer re-extracts it once during repair, so require a
  ; safe margin instead of failing half-way through copying files. ${DriveSpace}
  ; reports free space in MB for the install drive's root.
  ${GetRoot} "$INSTDIR" $R4
  ${DriveSpace} "$R4\" "/D=F /S=M" $R5
  ${if} $R5 < 600
    MessageBox MB_ICONSTOP|MB_OK "目标磁盘可用空间不足，无法安全安装LiloAvatar。$\r$\n$\r$\n所在磁盘：$R4$\r$\n当前可用：$R5 MB$\r$\n至少需要：600 MB$\r$\n$\r$\n请清理磁盘空间，或将LiloAvatar安装到其他磁盘后重试。"
    Abort
  ${endIf}
FunctionEnd

Function LiloAvatarInstallDirSafetyPageCreate
  Call LiloAvatarNormalizeInstallDir
  nsDialogs::Create 1018
  Pop $R0
  ${if} $R0 == error
    Abort
  ${endIf}

  ${NSD_CreateLabel} 0 0 100% 24u "LiloAvatar will be installed into this application-owned folder:"
  Pop $R1
  ${NSD_CreateText} 0 28u 100% 14u "$INSTDIR"
  Pop $R2
  EnableWindow $R2 0
  ${NSD_CreateLabel} 0 52u 100% 48u "If you chose D:\ or D:\Apps, the installer automatically adds the LiloAvatar subfolder. Program files stay here; conversations, memories, settings, API keys, sandbox files, and downloads stay under %APPDATA%\LiloAvatar and are removed only if you explicitly choose to clear user data during uninstall."
  Pop $R3
  nsDialogs::Show
FunctionEnd

Function LiloAvatarInstallDirSafetyPageLeave
  Call LiloAvatarValidateInstallDir
FunctionEnd

Function LiloAvatarValidateInstalledPayload
  ; The installer must never report success if the Electron runtime payload is
  ; incomplete. Missing files here produce confusing launch failures later.
  IfFileExists "$INSTDIR\LiloAvatar.exe" 0 liloavatarPayloadMissing
  IfFileExists "$INSTDIR\d3dcompiler_47.dll" 0 liloavatarPayloadMissing
  IfFileExists "$INSTDIR\ffmpeg.dll" 0 liloavatarPayloadMissing
  IfFileExists "$INSTDIR\libEGL.dll" 0 liloavatarPayloadMissing
  IfFileExists "$INSTDIR\libGLESv2.dll" 0 liloavatarPayloadMissing
  IfFileExists "$INSTDIR\vk_swiftshader.dll" 0 liloavatarPayloadMissing
  IfFileExists "$INSTDIR\vulkan-1.dll" 0 liloavatarPayloadMissing
  IfFileExists "$INSTDIR\resources\app.asar" 0 liloavatarPayloadMissing
  IfFileExists "$INSTDIR\resources\app.asar.unpacked\node_modules\better-sqlite3\build\Release\better_sqlite3.node" 0 liloavatarPayloadMissing

  ClearErrors
  FileOpen $R1 "$INSTDIR\LiloAvatar.exe" r
  IfErrors liloavatarPayloadMissing
  FileSeek $R1 0 END $R3
  FileClose $R1

  ; A partially copied Electron executable can still have a valid PE header.
  ; Use a conservative lower bound (50 MB) that any complete LiloAvatar.exe far
  ; exceeds (~180 MB today), so gross truncation is caught without tying the
  ; check to a specific Electron version's exact size, which changes on every
  ; Electron bump. A tight threshold near the real size silently rejects valid
  ; installs after an Electron downgrade/optimization.
  IntCmp $R3 52428800 liloavatarPayloadValid liloavatarPayloadMissing liloavatarPayloadValid

  liloavatarPayloadValid:
    Return

  liloavatarPayloadMissing:
    MessageBox MB_ICONSTOP|MB_OK "LiloAvatar installation did not complete correctly. To avoid leaving a broken app on this computer, setup will stop now.$\r$\n$\r$\nPlease close LiloAvatar and run this installer again. If the problem continues, send this path to support:$\r$\n$INSTDIR"
    Abort
FunctionEnd

Function LiloAvatarRepairAndValidateInstalledPayload
  ; electron-builder first extracts app-64.7z to $PLUGINSDIR\7z-out and then
  ; copies that folder to $INSTDIR. In the field this copy can leave a partial
  ; install. Re-extract the embedded archive directly to $INSTDIR, then validate.
  StrCpy $R9 "$OUTDIR"
  SetOutPath "$INSTDIR"
  File /oname=$PLUGINSDIR\7za.exe "${PROJECT_DIR}\node_modules\7zip-bin\win\x64\7za.exe"

  !ifdef APP_64
    IfFileExists "$PLUGINSDIR\app-64.7z" 0 +4
    ; nsExec runs 7za.exe with a hidden window, so no console window flashes
    ; during install. ExecWait would spawn a visible console window each time.
    nsExec::ExecToLog '"$PLUGINSDIR\7za.exe" x -y -aoa "-o$INSTDIR" "$PLUGINSDIR\app-64.7z"'
    Pop $R0
    Goto liloavatarPackageExtracted
  !endif

  StrCpy $R0 "no embedded x64 package found"

  liloavatarPackageExtracted:
    SetOutPath "$R9"
    Call LiloAvatarValidateInstalledPayload
FunctionEnd

!macro customPageAfterChangeDir
  Page custom LiloAvatarInstallDirSafetyPageCreate LiloAvatarInstallDirSafetyPageLeave
!macroend

!macro customInstall
  Call LiloAvatarRepairAndValidateInstalledPayload

  ; Avoid electron-builder's WinShell plugin for shortcuts. Plain NSIS
  ; shortcuts are enough because the app itself sets AppUserModelID at runtime.
  SetOutPath "$INSTDIR"
  Delete "$SMPROGRAMS\LiloAvatar.lnk"
  Delete "$SMPROGRAMS\LiloAvatar\LiloAvatar.lnk"
  RMDir "$SMPROGRAMS\LiloAvatar"
  Delete "$DESKTOP\LiloAvatar.lnk"
  CreateShortCut "$DESKTOP\LiloAvatar.lnk" "$INSTDIR\LiloAvatar.exe" "" "$INSTDIR\LiloAvatar.exe" 0
  WriteRegStr SHELL_CONTEXT "${INSTALL_REGISTRY_KEY}" "KeepShortcuts" "true"
  ${if} $installMode == "all"
    WriteRegStr SHELL_CONTEXT "${UNINSTALL_REGISTRY_KEY}" "UninstallString" '"$INSTDIR\Uninstall LiloAvatar.exe" /allusers --keep-shortcuts'
    WriteRegStr SHELL_CONTEXT "${UNINSTALL_REGISTRY_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall LiloAvatar.exe" /allusers /S --keep-shortcuts'
  ${else}
    WriteRegStr SHELL_CONTEXT "${UNINSTALL_REGISTRY_KEY}" "UninstallString" '"$INSTDIR\Uninstall LiloAvatar.exe" /currentuser --keep-shortcuts'
    WriteRegStr SHELL_CONTEXT "${UNINSTALL_REGISTRY_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall LiloAvatar.exe" /currentuser /S --keep-shortcuts'
  ${endIf}
!macroend

!macro customInit
  ; Make upgrades invoke old uninstallers with --keep-shortcuts. That skips
  ; electron-builder's WinShell plugin, whose temp extraction can fail at scale.
  WriteRegStr SHELL_CONTEXT "${INSTALL_REGISTRY_KEY}" "KeepShortcuts" "true"

  ; Refuse unsafe legacy or scripted install locations before the installer runs
  ; the old uninstaller. Upgrades invoke the previous uninstaller first, so a
  ; bad historical InstallLocation must be stopped here, not in customRemoveFiles.
  ${GetFileName} "$INSTDIR" $R0
  ${if} $R0 != "LiloAvatar"
    ${if} ${FileExists} "$INSTDIR\LiloAvatar.exe"
    ${orIf} ${FileExists} "$INSTDIR\Uninstall LiloAvatar.exe"
    ${orIf} ${FileExists} "$INSTDIR\resources\app.asar"
      MessageBox MB_ICONSTOP|MB_OK "LiloAvatar is installed in an unsafe shared folder:$\r$\n$\r$\n$INSTDIR$\r$\n$\r$\nTo protect other software, this installer will not continue. Please contact support or manually move/remove only the LiloAvatar files, then install again."
      Abort
    ${else}
      Call LiloAvatarNormalizeInstallDir
    ${endIf}
  ${endIf}

  ; Even a folder named LiloAvatar can contain user-created or third-party
  ; folders. During upgrades, electron-builder invokes the *old* uninstaller
  ; before this new safe uninstaller exists, and old uninstallers recursively
  ; remove the whole install folder. If this is an existing LiloAvatar install,
  ; rescue foreign items to userData first. Fresh installs still validate and
  ; refuse non-empty foreign folders on the install-directory page.
  ${if} ${FileExists} "$INSTDIR\LiloAvatar.exe"
  ${orIf} ${FileExists} "$INSTDIR\Uninstall LiloAvatar.exe"
  ${orIf} ${FileExists} "$INSTDIR\resources\app.asar"
    Call LiloAvatarRescueForeignInstallRootItems
  ${endIf}

  ; Do not delete native module directories in customInit. This hook runs before
  ; the new payload has been fully extracted and validated; deleting here can
  ; leave an otherwise working install broken if setup is cancelled or killed.
  ; The repaired payload extraction in customInstall overwrites owned files.
!macroend

!endif

!macro customRemoveFiles
  ; electron-builder's default uninstaller runs `RMDir /r $INSTDIR`.
  ; That is dangerous when a user accidentally installed into a shared parent
  ; folder such as AppData\Local\Programs or D:\Software. Remove only files and
  ; subdirectories LiloAvatar owns, then remove parent folders only if empty.
  ${if} ${isUpdated}
    ; During an upgrade, fail atomically if any app file is busy. This prevents
    ; a half-removed install folder followed by a false successful install.
    CreateDirectory "$PLUGINSDIR\old-install"
    Push ""
    Call un.atomicRMDir
    Pop $R0

    ${if} $R0 != 0
      DetailPrint "LiloAvatar file is busy, aborting upgrade: $R0"
      Push ""
      Call un.restoreFiles
      Pop $R0
      Abort `Can't safely update LiloAvatar because "$INSTDIR" contains a busy file.`
    ${endif}

    Goto liloavatarRemoveFilesDone
  ${endif}

  Delete "$INSTDIR\LiloAvatar.exe"
  Delete "$INSTDIR\chrome_100_percent.pak"
  Delete "$INSTDIR\chrome_200_percent.pak"
  Delete "$INSTDIR\d3dcompiler_47.dll"
  Delete "$INSTDIR\ffmpeg.dll"
  Delete "$INSTDIR\icudtl.dat"
  Delete "$INSTDIR\libEGL.dll"
  Delete "$INSTDIR\libGLESv2.dll"
  Delete "$INSTDIR\LICENSE.electron.txt"
  Delete "$INSTDIR\LICENSES.chromium.html"
  Delete "$INSTDIR\resources.pak"
  Delete "$INSTDIR\snapshot_blob.bin"
  Delete "$INSTDIR\v8_context_snapshot.bin"
  Delete "$INSTDIR\vk_swiftshader.dll"
  Delete "$INSTDIR\vk_swiftshader_icd.json"
  Delete "$INSTDIR\vulkan-1.dll"
  Delete "$INSTDIR\Uninstall LiloAvatar.exe"
  Delete "$INSTDIR\uninstallerIcon.ico"

  ; Shortcuts are created by customInstall with plain NSIS CreateShortCut.
  ; Delete them directly so uninstall never needs WinShell.dll.
  Delete "$DESKTOP\LiloAvatar.lnk"
  Delete "$SMPROGRAMS\LiloAvatar.lnk"
  Delete "$SMPROGRAMS\LiloAvatar\LiloAvatar.lnk"
  RMDir "$SMPROGRAMS\LiloAvatar"

  Delete "$INSTDIR\resources\app.asar"
  Delete "$INSTDIR\resources\app-update.yml"
  Delete "$INSTDIR\resources\elevate.exe"
  RMDir /r "$INSTDIR\resources\app.asar.unpacked\node_modules\better-sqlite3"
  RMDir /r "$INSTDIR\resources\app.asar.unpacked\src\voice"
  RMDir "$INSTDIR\resources\app.asar.unpacked\node_modules"
  RMDir "$INSTDIR\resources\app.asar.unpacked\src"
  RMDir "$INSTDIR\resources\app.asar.unpacked"
  RMDir "$INSTDIR\resources"

  Delete "$INSTDIR\locales\am.pak"
  Delete "$INSTDIR\locales\af.pak"
  Delete "$INSTDIR\locales\ar.pak"
  Delete "$INSTDIR\locales\bg.pak"
  Delete "$INSTDIR\locales\bn.pak"
  Delete "$INSTDIR\locales\ca.pak"
  Delete "$INSTDIR\locales\cs.pak"
  Delete "$INSTDIR\locales\da.pak"
  Delete "$INSTDIR\locales\de.pak"
  Delete "$INSTDIR\locales\el.pak"
  Delete "$INSTDIR\locales\en-GB.pak"
  Delete "$INSTDIR\locales\en-US.pak"
  Delete "$INSTDIR\locales\es-419.pak"
  Delete "$INSTDIR\locales\es.pak"
  Delete "$INSTDIR\locales\et.pak"
  Delete "$INSTDIR\locales\fa.pak"
  Delete "$INSTDIR\locales\fi.pak"
  Delete "$INSTDIR\locales\fil.pak"
  Delete "$INSTDIR\locales\fr.pak"
  Delete "$INSTDIR\locales\gu.pak"
  Delete "$INSTDIR\locales\he.pak"
  Delete "$INSTDIR\locales\hi.pak"
  Delete "$INSTDIR\locales\hr.pak"
  Delete "$INSTDIR\locales\hu.pak"
  Delete "$INSTDIR\locales\id.pak"
  Delete "$INSTDIR\locales\it.pak"
  Delete "$INSTDIR\locales\ja.pak"
  Delete "$INSTDIR\locales\kn.pak"
  Delete "$INSTDIR\locales\ko.pak"
  Delete "$INSTDIR\locales\lt.pak"
  Delete "$INSTDIR\locales\lv.pak"
  Delete "$INSTDIR\locales\ml.pak"
  Delete "$INSTDIR\locales\mr.pak"
  Delete "$INSTDIR\locales\ms.pak"
  Delete "$INSTDIR\locales\nb.pak"
  Delete "$INSTDIR\locales\nl.pak"
  Delete "$INSTDIR\locales\pl.pak"
  Delete "$INSTDIR\locales\pt-BR.pak"
  Delete "$INSTDIR\locales\pt-PT.pak"
  Delete "$INSTDIR\locales\ro.pak"
  Delete "$INSTDIR\locales\ru.pak"
  Delete "$INSTDIR\locales\sk.pak"
  Delete "$INSTDIR\locales\sl.pak"
  Delete "$INSTDIR\locales\sr.pak"
  Delete "$INSTDIR\locales\sv.pak"
  Delete "$INSTDIR\locales\sw.pak"
  Delete "$INSTDIR\locales\ta.pak"
  Delete "$INSTDIR\locales\te.pak"
  Delete "$INSTDIR\locales\th.pak"
  Delete "$INSTDIR\locales\tr.pak"
  Delete "$INSTDIR\locales\uk.pak"
  Delete "$INSTDIR\locales\ur.pak"
  Delete "$INSTDIR\locales\vi.pak"
  Delete "$INSTDIR\locales\zh-CN.pak"
  Delete "$INSTDIR\locales\zh-TW.pak"
  RMDir "$INSTDIR\locales"

  ; Only succeeds when the install folder is empty. Never recurse here.
  RMDir "$INSTDIR"

  liloavatarRemoveFilesDone:
!macroend

!macro customUnInstall
  ; 卸载时询问是否同时清除用户数据。升级（${isUpdated}）走的也是卸载旧版流程，
  ; 那种情况绝不能删数据，否则更新一次记忆全没——所以只在“真卸载”时弹窗。
  ; /SD IDNO 让静默卸载默认走“保留”，不打扰、不误删。
  ${ifNot} ${isUpdated}
    MessageBox MB_YESNO|MB_ICONQUESTION "是否同时删除LiloAvatar的全部用户数据？$\r$\n$\r$\n包括：对话与记忆数据库、配置（含 API Key）、沙盒文件、下载的音乐等。$\r$\n$\r$\n选择「是」将彻底清除且无法恢复；选择「否」保留数据，方便以后重装时继续使用。" /SD IDNO IDNO keepUserData
      ; userData 目录 = %APPDATA%\<productName>，即 $APPDATA\LiloAvatar
      RMDir /r "$APPDATA\LiloAvatar"
    keepUserData:
  ${endIf}
!macroend
