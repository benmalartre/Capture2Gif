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
  
  rect\x = 100
  rect\y = 100
  rect\w = 100
  rect\h = 100
  
  Define img = CreateImage(#PB_Any, rect\w * 10, rect\h * 10, 32)

;   Platform::CaptureWindowImage(img, pbWindow)
  
  Define window = OpenWindow(#PB_Any, 100, 100, 800, 800, "", #PB_Window_SystemMenu|#PB_Window_SizeGadget)
;   Platform::GetWindowRect( Platform::GetWindowID(window), rect)
;   Debug "window ("+Str(WindowID(window))+") rect :"+Str(rect\x) +","+Str(rect\y) +","+ Str(rect\w)+","+Str(rect\h)
  AddKeyboardShortcut(window, #PB_Shortcut_Right, 0)
  AddKeyboardShortcut(window, #PB_Shortcut_Left, 1)
  AddKeyboardShortcut(window, #PB_Shortcut_Up, 2)
  AddKeyboardShortcut(window, #PB_Shortcut_Down, 3)
  
  Define gadget = ImageGadget(#PB_Any, 0, 0, WindowWidth(window), WindowHeight(window), ImageID(img))
  SetGadgetAttribute(gadget, #PB_Gadget_BackColor, RGB(100, 150, 100))
  Repeat
    event = WaitWindowEvent()
    If event = #PB_Event_Menu
      Select EventMenu()
        Case 0:
          rect\x - 10
        Case 1
          rect\x + 10
        Case 2
          rect\y + 10
        Case 3
          rect\y -10
      EndSelect
      
    EndIf
    
    Platform::CaptureWindowImage(img, pbWindow, rect)
    SetGadgetState(gadget, ImageID(img))
  Until event = #PB_Event_CloseWindow

 CloseWindow(window)
 ResetRect(rect)
EndIf
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 22
; Folding = -
; EnableXP