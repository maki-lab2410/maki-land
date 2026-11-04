!macro customInit
  # Kill any running maki-land processes before install/update so files like ffmpeg.dll are never locked
  nsExec::Exec 'taskkill /F /IM "maki-land.exe" /T'
!macroend

!macro customUnInstall
  # 1. Forcefully kill running maki-land processes before deleting files
  nsExec::Exec 'taskkill /F /IM "maki-land.exe" /T'

  # 2. Delete Windows Registry Startup (Autorun at login)
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "maki-land"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "com.makiland.windows"
  DeleteRegValue HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "maki-land"
!macroend
