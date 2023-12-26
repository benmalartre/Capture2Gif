XIncludeFile "Platform.pbi"

Procedure ResetRect(*r.Platform::Rectangle_t)
  *r\x = 0
  *r\y = 0
  *r\w = 0
  *r\h = 0
EndProcedure


Define rect.Platform::Rectangle_t
 
 
pbWindow =  Platform::GetWindowByName("PureBasic")
If pbWindow
  Platform::GetWindowRect(pbWindow, rect)
  Debug "purebasic window ("+Str(pbWindow)+") rect :"+Str(rect\x) +","+Str(rect\y) +","+ Str(rect\w)+","+Str(rect\h)
  ResetRect(rect)

EndIf

Define window = OpenWindow(#PB_Any, 100, 100, 200, 200, "", #PB_Window_SystemMenu|#PB_Window_SizeGadget)
Platform::GetWindowRect( Platform::GetWindowID(window), rect)
 Debug "window ("+Str(WindowID(window))+") rect :"+Str(rect\x) +","+Str(rect\y) +","+ Str(rect\w)+","+Str(rect\h)
 CloseWindow(window)
 ResetRect(rect)
; IDE Options = PureBasic 6.00 Beta 7 - C Backend (MacOS X - arm64)
; CursorPosition = 22
; Folding = -
; EnableXP