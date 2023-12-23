DeclareModule Win
  Structure Window_t
    hWnd.i
    Map childrens.i()
  EndStructure
  
  Declare GetWindowByName(name.s="Softimage")
EndDeclareModule

Module Win
 CompilerIf #PB_Compiler_OS = #PB_OS_Windows

  ; helper function to enumerate open windows
  ;
  Procedure _EnumerateWindows(*window.Window_t)
    Define title.s {256}
    Define hWnd    .i
    
    hWnd = GetWindow_(GetDesktopWindow_(), #GW_CHILD)
    While hWnd
      GetWindowText_(hWnd, @title, 256)
      AddMapElement(*window\childrens(), title)
      *window\childrens() = hWnd
      hWnd = GetWindow_(hWnd, #GW_HWNDNEXT)
    Wend
  EndProcedure
  
  ; try get a window by it's name
  ;
  Procedure GetWindowByName(name.s="Softimage")
    Define window.Window_t
    _EnumerateWindows(window)
    ForEach window\childrens()
      If FindString(MapKey(window\childrens()), name)
        Debug "found xsi view"
        ProcedureReturn window\childrens()
      EndIf
    Next 
  EndProcedure
  
  Procedure.l _EnumChildWindowsProc(hWnd.l, param.l) 
    Protected *window.Window_t = param
    Protected title.s = Space(256)
    GetWindowText_(hWnd, @title, 200)
    AddMapElement(*window\childrens(), title)
    *window\childrens() = hWnd
    ProcedureReturn #True
  EndProcedure 
  
  Procedure EnumerateChildWindows(*window.Window_t, pWnd)
    EnumChildWindows_(pWnd,@_EnumChildWindowsProc(), *window)
  EndProcedure 
  
CompilerElseIf #PB_Compiler_OS = #PB_OS_MacOS
  ; try get a window by it's name
  ;
  Procedure GetWindowByName(name.s="Softimage")
    
  EndProcedure
CompilerEndIf
EndModule
; IDE Options = PureBasic 6.00 Beta 7 - C Backend (MacOS X - arm64)
; CursorPosition = 56
; FirstLine = 23
; Folding = --
; EnableXP