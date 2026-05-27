XIncludeFile "Editor.pbi"
;-----------------------------------------------------------------------------------------------
;         Capture2Gif — compact floating control bar
;-----------------------------------------------------------------------------------------------
DeclareModule ScreenCaptureToGif
  UseModule Capture
  #APP_NAME         = "Capture2Gif"
  #BORDER_THICKNESS = 10
  #CORNER_HIT       = 20

  Enumeration
    #BORDER_NONE   = 0
    #BORDER_LEFT   = 1
    #BORDER_RIGHT  = 2
    #BORDER_TOP    = 4
    #BORDER_BOTTOM = 8
    #BORDER_CENTER = 16
  EndEnumeration

  Global TRANSPARENT_COLOR.i = RGBA(0,255,0,100)

  Structure App_t
    window.i                   ; compact control bar window
    region.i                   ; full-screen transparent selection overlay
    canvas.i                   ; canvas inside overlay
    rect.Platform::Rectangle_t ; capture rectangle (set during region selection)
    hWnd.i                     ; specific window to capture (unused)
    capture.Capture::Capture_t
    outputFolder.s
    delay.f                    ; frame interval in ms
    record.b
    close.b
    elapsed.q
    hover.i
    drag.i
    hintFont.i
    pendingStart.b             ; set by overlay Start button; processed next event tick
    gadgetRegion.i             ; "Select Region" button gadget ID
    gadgetRecord.i             ; "Record" / "Stop" button gadget ID
    btnConfirmX.f              ; overlay button bounds cached by _DrawRegion
    btnConfirmW.f
    btnCancelX.f
    btnCancelW.f
    btnBotY.f
  EndStructure

  Declare InitRectangle(*app.App_t)
  Declare _CloseRegion(*app.App_t)
  Declare _StartRecord(*app.App_t)
  Declare _StopRecord(*app.App_t)
  Declare OnRecord(*app.App_t)
  Declare Launch()
EndDeclareModule

;-----------------------------------------------------------------------------------------------
Module ScreenCaptureToGif
  UseModule Capture

  Procedure.s _RandomString(len.i)
    Define s.s
    For i = 0 To len - 1
      Select Random(2)
        Case 0 : s + Chr(Random(25) + 97)
        Case 1 : s + Chr(Random(25) + 65)
        Default: s + Chr(Random(9)  + 48)
      EndSelect
    Next
    ProcedureReturn s
  EndProcedure

  ;---------------------------------------------------------------------------------------------
  ; Overlay drawing
  ;---------------------------------------------------------------------------------------------
  Procedure _DrawRegion(*app.App_t)
    Define cw = WindowWidth(*app\region,  #PB_Window_InnerCoordinate)
    Define ch = WindowHeight(*app\region, #PB_Window_InnerCoordinate)

    ; pass 1: near-zero alpha — every pixel captures mouse events, no click-through
    StartDrawing(CanvasOutput(*app\canvas))
    DrawingMode(#PB_2DDrawing_AllChannels)
    Box(0, 0, cw, ch, RGBA(0, 0, 0, 2))
    StopDrawing()

    ; pass 2: vector elements
    StartVectorDrawing(CanvasVectorOutput(*app\canvas))

    Define bx.f = *app\rect\x
    Define by.f = *app\rect\y
    Define bw.f = *app\rect\w
    Define bh.f = *app\rect\h

    If Not *app\record
      ; border
      MovePathCursor(bx, by) : AddPathLine(bx+bw, by)
      AddPathLine(bx+bw, by+bh) : AddPathLine(bx, by+bh) : ClosePath()
      VectorSourceColor(RGBA(0, 200, 255, 255))
      StrokePath(2, #PB_Path_Default)

      ; corner handles
      Define hs.f = 16
      AddPathBox(bx-hs/2,    by-hs/2,    hs, hs)
      AddPathBox(bx+bw-hs/2, by-hs/2,    hs, hs)
      AddPathBox(bx-hs/2,    by+bh-hs/2, hs, hs)
      AddPathBox(bx+bw-hs/2, by+bh-hs/2, hs, hs)
      VectorSourceColor(RGBA(0, 200, 255, 255))
      FillPath()

      ; mid-edge handles
      Define mhs.f = 10
      AddPathBox(bx+bw/2-mhs/2, by-mhs/2,       mhs, mhs)
      AddPathBox(bx+bw/2-mhs/2, by+bh-mhs/2,    mhs, mhs)
      AddPathBox(bx-mhs/2,      by+bh/2-mhs/2,  mhs, mhs)
      AddPathBox(bx+bw-mhs/2,   by+bh/2-mhs/2,  mhs, mhs)
      VectorSourceColor(RGBA(0, 200, 255, 200))
      FillPath()

      ; center cross
      Define cx.f = bx + bw/2 : Define cy.f = by + bh/2 : Define cl.f = 12
      MovePathCursor(cx-cl, cy) : AddPathLine(cx+cl, cy)
      MovePathCursor(cx, cy-cl) : AddPathLine(cx, cy+cl)
      VectorSourceColor(RGBA(0, 200, 255, 180))
      StrokePath(2, #PB_Path_Default)

      ; clickable buttons at screen bottom
      If *app\hintFont
        VectorFont(FontID(*app\hintFont))
        Define btnH.f   = 32
        Define btnY2.f  = ch - btnH - 20
        Define btnPad.f = 24
        Define cfTxt.s  = "  Start Recording  "
        Define cnTxt.s  = "  Cancel  "
        Define cfW.f    = VectorTextWidth(cfTxt) + btnPad
        Define cnW.f    = VectorTextWidth(cnTxt)  + btnPad
        Define gap.f    = 16
        Define btnX.f   = (cw - cfW - gap - cnW) / 2

        AddPathBox(btnX, btnY2, cfW, btnH)
        VectorSourceColor(RGBA(0, 180, 90, 230))
        FillPath()
        MovePathCursor(btnX + btnPad/2, btnY2 + (btnH - VectorTextHeight(cfTxt))/2)
        VectorSourceColor(RGBA(255, 255, 255, 255))
        DrawVectorText(cfTxt)

        AddPathBox(btnX+cfW+gap, btnY2, cnW, btnH)
        VectorSourceColor(RGBA(180, 50, 50, 200))
        FillPath()
        MovePathCursor(btnX+cfW+gap + btnPad/2, btnY2 + (btnH - VectorTextHeight(cnTxt))/2)
        VectorSourceColor(RGBA(255, 255, 255, 255))
        DrawVectorText(cnTxt)

        *app\btnConfirmX = btnX    : *app\btnConfirmW = cfW
        *app\btnCancelX  = btnX+cfW+gap : *app\btnCancelW = cnW
        *app\btnBotY     = btnY2
      EndIf

    Else
      ; recording — pink border
      MovePathCursor(bx, by) : AddPathLine(bx+bw, by)
      AddPathLine(bx+bw, by+bh) : AddPathLine(bx, by+bh) : ClosePath()
      VectorSourceColor(RGBA(255, 60, 140, 255))
      StrokePath(3, #PB_Path_Default)
    EndIf

    StopVectorDrawing()
  EndProcedure

  ;---------------------------------------------------------------------------------------------
  ; Axis/rectangle validation (keep dimensions a multiple of 4 for encoder alignment)
  ;---------------------------------------------------------------------------------------------
  Procedure _ValidateAxis(*p, *s)
    If PeekI(*s) < 0
      PokeI(*p, PeekI(*p) + PeekI(*s))
      PokeI(*s, -PeekI(*s))
    EndIf
    Select PeekI(*s) % 4
      Case 1: PokeI(*s, PeekI(*s)+3)
      Case 2: PokeI(*s, PeekI(*s)+2)
      Case 3: PokeI(*s, PeekI(*s)+1)
    EndSelect
  EndProcedure

  Procedure _ValidateRectangle(*rect.Platform::Rectangle_t)
    _ValidateAxis(@*rect\x, @*rect\w)
    _ValidateAxis(@*rect\y, @*rect\h)
  EndProcedure

  ;---------------------------------------------------------------------------------------------
  ; Overlay event handler
  ;---------------------------------------------------------------------------------------------
  Procedure _RegionEvent(*app.App_t, event.i)
    If EventGadget() <> *app\canvas : ProcedureReturn : EndIf
    Define mouseX = WindowMouseX(*app\region)
    Define mouseY = WindowMouseY(*app\region)
    Define type   = EventType()

    If type = #PB_EventType_LeftButtonDown
      CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
        CocoaMessage(0, WindowID(*app\region), "makeKeyWindow")
        CocoaMessage(0, WindowID(*app\region), "makeFirstResponder:", GadgetID(*app\canvas))
      CompilerEndIf

      ; overlay button hit-test (bounds cached by _DrawRegion — no vector drawing here)
      If Not *app\record And *app\btnBotY > 0
        If mouseY >= *app\btnBotY And mouseY <= *app\btnBotY + 32
          If mouseX >= *app\btnConfirmX And mouseX <= *app\btnConfirmX + *app\btnConfirmW
            ; defer _StartRecord to next event tick to avoid Cocoa re-entrancy crash
            *app\pendingStart = #True
            _CloseRegion(*app)
            ProcedureReturn
          ElseIf mouseX >= *app\btnCancelX And mouseX <= *app\btnCancelX + *app\btnCancelW
            _CloseRegion(*app)
            ProcedureReturn
          EndIf
        EndIf
      EndIf

      If *app\hover : *app\drag = *app\hover : EndIf

    ElseIf type = #PB_EventType_LeftButtonUp And *app\drag
      *app\drag = #BORDER_NONE
      _ValidateRectangle(*app\rect)

    ElseIf type = #PB_EventType_MouseMove
      If *app\drag = #BORDER_NONE
        *app\hover = #BORDER_NONE
        Define cxm = (*app\rect\x * 2 + *app\rect\w) >> 1
        Define cym = (*app\rect\y * 2 + *app\rect\h) >> 1
        If Abs(mouseX-cxm) < (#BORDER_THICKNESS*2) And Abs(mouseY-cym) < (#BORDER_THICKNESS*2)
          *app\hover | #BORDER_CENTER
        EndIf

        Define rx = *app\rect\x : Define rr = *app\rect\x + *app\rect\w
        Define ry = *app\rect\y : Define rb = *app\rect\y + *app\rect\h

        If   Abs(mouseX-rx) < #CORNER_HIT And Abs(mouseY-ry) < #CORNER_HIT
          *app\hover | #BORDER_LEFT  | #BORDER_TOP
        ElseIf Abs(mouseX-rr) < #CORNER_HIT And Abs(mouseY-ry) < #CORNER_HIT
          *app\hover | #BORDER_RIGHT | #BORDER_TOP
        ElseIf Abs(mouseX-rx) < #CORNER_HIT And Abs(mouseY-rb) < #CORNER_HIT
          *app\hover | #BORDER_LEFT  | #BORDER_BOTTOM
        ElseIf Abs(mouseX-rr) < #CORNER_HIT And Abs(mouseY-rb) < #CORNER_HIT
          *app\hover | #BORDER_RIGHT | #BORDER_BOTTOM
        ElseIf Abs(mouseX-rx) < #BORDER_THICKNESS
          *app\hover | #BORDER_LEFT
        ElseIf Abs(mouseX-rr) < #BORDER_THICKNESS
          *app\hover | #BORDER_RIGHT
        EndIf

        If Not (*app\hover & (#BORDER_TOP|#BORDER_BOTTOM))
          If   Abs(mouseY-ry) < #BORDER_THICKNESS
            *app\hover | #BORDER_TOP
          ElseIf Abs(mouseY-rb) < #BORDER_THICKNESS
            *app\hover | #BORDER_BOTTOM
          EndIf
        EndIf

        If   (*app\hover&#BORDER_LEFT And *app\hover&#BORDER_TOP) Or
             (*app\hover&#BORDER_BOTTOM And *app\hover&#BORDER_RIGHT)
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftUpRightDown)
        ElseIf (*app\hover&#BORDER_RIGHT And *app\hover&#BORDER_TOP) Or
               (*app\hover&#BORDER_BOTTOM And *app\hover&#BORDER_LEFT)
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftDownRightUp)
        ElseIf (*app\hover&#BORDER_LEFT) Or (*app\hover&#BORDER_RIGHT)
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftRight)
        ElseIf (*app\hover&#BORDER_TOP) Or (*app\hover&#BORDER_BOTTOM)
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_UpDown)
        Else
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_Default)
        EndIf

      Else
        If *app\hover&#BORDER_CENTER
          *app\rect\x = mouseX - (*app\rect\w>>1)
          *app\rect\y = mouseY - (*app\rect\h>>1)
        ElseIf *app\hover&#BORDER_LEFT And *app\hover&#BORDER_TOP
          *app\rect\w = (*app\rect\x + *app\rect\w) - mouseX
          *app\rect\h = (*app\rect\y + *app\rect\h) - mouseY
          *app\rect\x = mouseX : *app\rect\y = mouseY
        ElseIf *app\hover&#BORDER_BOTTOM And *app\hover&#BORDER_RIGHT
          *app\rect\w = mouseX - *app\rect\x
          *app\rect\h = mouseY - *app\rect\y
        ElseIf *app\hover&#BORDER_RIGHT And *app\hover&#BORDER_TOP
          *app\rect\w = mouseX - *app\rect\x
          *app\rect\h = (*app\rect\y + *app\rect\h) - mouseY
          *app\rect\y = mouseY
        ElseIf *app\hover&#BORDER_BOTTOM And *app\hover&#BORDER_LEFT
          *app\rect\w = (*app\rect\x + *app\rect\w) - mouseX
          *app\rect\h = mouseY - *app\rect\y
          *app\rect\x = mouseX
        ElseIf *app\hover&#BORDER_LEFT
          *app\rect\w = (*app\rect\x + *app\rect\w) - mouseX
          *app\rect\x = mouseX
        ElseIf *app\hover&#BORDER_RIGHT
          *app\rect\w = mouseX - *app\rect\x
        ElseIf *app\hover&#BORDER_TOP
          *app\rect\h = (*app\rect\y + *app\rect\h) - mouseY
          *app\rect\y = mouseY
        ElseIf *app\hover&#BORDER_BOTTOM
          *app\rect\h = mouseY - *app\rect\y
        EndIf
      EndIf

    ElseIf type = #PB_EventType_KeyDown
      Define key = GetGadgetAttribute(*app\canvas, #PB_Canvas_Key)
      If key = #PB_Shortcut_Return Or key = #PB_Shortcut_Space
        *app\pendingStart = #True
        _CloseRegion(*app)
        ProcedureReturn
      ElseIf key = #PB_Shortcut_Escape
        _CloseRegion(*app)
        ProcedureReturn
      EndIf
    EndIf

    _DrawRegion(*app)
  EndProcedure

  ;---------------------------------------------------------------------------------------------
  ; Close the region overlay and restore the control bar
  ;---------------------------------------------------------------------------------------------
  Procedure _CloseRegion(*app.App_t)
    If IsWindow(*app\region)
      CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
        CocoaMessage(0, WindowID(*app\region), "orderOut:", 0)
      CompilerEndIf
      CloseWindow(*app\region)
      *app\region = 0
    EndIf
    ; Control bar stays visible at level 25 — no need to explicitly activate it.
    ; Calling makeKeyAndOrderFront: from inside an event handler causes Cocoa re-entrancy crash.
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      HideWindow(*app\window, #False)
    CompilerEndIf
  EndProcedure

  ;---------------------------------------------------------------------------------------------
  ; Main event dispatcher
  ;---------------------------------------------------------------------------------------------
  Procedure _Event(*app.App_t, event.i)
    If event = #PB_Event_CloseWindow And EventWindow() = *app\window
      If *app\record : Capture::Term(*app\capture) : Capture::Free(*app\capture) : EndIf
      *app\close = #True
      ProcedureReturn
    EndIf

    Define window = EventWindow()

    If window = *app\window And event = #PB_Event_Gadget
      If EventGadget() = *app\gadgetRegion
        InitRectangle(*app)
      ElseIf EventGadget() = *app\gadgetRecord
        OnRecord(*app)
      EndIf
    EndIf

    If *app\region And window = *app\region
      CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
        If event = #PB_Event_ActivateWindow
          CocoaMessage(0, WindowID(*app\region), "makeFirstResponder:", GadgetID(*app\canvas))
        EndIf
      CompilerEndIf
      _RegionEvent(*app, event)
    EndIf

    ; deferred start — set by overlay button, safe to call here outside event handler
    If *app\pendingStart And Not *app\record
      *app\pendingStart = #False
      _StartRecord(*app)
    EndIf

    If *app\record And *app\elapsed > *app\delay
      CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
        Capture::Frame(*app\capture, #False)
      CompilerElse
        Capture::Frame(*app\capture, #True)
      CompilerEndIf
      *app\elapsed = 0
    EndIf
  EndProcedure

  ;---------------------------------------------------------------------------------------------
  ; Open the region selection overlay
  ;---------------------------------------------------------------------------------------------
  Procedure InitRectangle(*app.App_t)
    If IsWindow(*app\region) : _CloseRegion(*app) : ProcedureReturn : EndIf

    ExamineDesktops()
    Define rect.Platform::Rectangle_t
    rect\x = DesktopX(0) : rect\y = DesktopY(0)
    rect\w = DesktopWidth(0) : rect\h = DesktopHeight(0)

    *app\rect\x = 100 : *app\rect\y = 100
    *app\rect\w = rect\w - 200 : *app\rect\h = rect\h - 200

    Define flags = #PB_Window_Tool | #PB_Window_BorderLess | #PB_Window_Maximize
    CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
      *app\region = OpenWindow(#PB_Any, rect\x, rect\y, rect\w, rect\h, "", flags)
    CompilerElse
      *app\region = OpenWindow(#PB_Any, rect\x, rect\y, rect\w, rect\h, "", flags, WindowID(*app\window))
    CompilerEndIf
    SetWindowColor(*app\region, 0)
    Platform::SetWindowTransparentColor(*app\region, TRANSPARENT_COLOR)

    *app\canvas = CanvasGadget(#PB_Any, 0, 0, rect\w, rect\h, #PB_Canvas_Keyboard)
    CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
      SetGadgetAttribute(*app\canvas, #PB_Gadget_BackColor, RGBA(0, 0, 0, 0))
    CompilerElse
      SetGadgetAttribute(*app\canvas, #PB_Gadget_BackColor, TRANSPARENT_COLOR)
    CompilerEndIf

    If Not *app\hintFont
      *app\hintFont = LoadFont(#PB_Any, "Arial", 13)
    EndIf

    CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
      CocoaMessage(0, WindowID(*app\region), "setLevel:", 24)
      CocoaMessage(0, WindowID(*app\region), "makeFirstResponder:", GadgetID(*app\canvas))
    CompilerElse
      Platform::EnterWindowFullscreen(*app\region)
    CompilerEndIf
    _DrawRegion(*app)
  EndProcedure

  Procedure GetRectangle(*app.App_t, *r.Platform::Rectangle_t)
    *r\x = *app\rect\x : *r\y = *app\rect\y
    *r\w = *app\rect\w : *r\h = *app\rect\h
  EndProcedure

  ;---------------------------------------------------------------------------------------------
  Procedure _StartRecord(*app.App_t)
    CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
      If Not Platform::EnsureCaptureAccess()
        SetWindowTitle(*app\window, "NO PERMISSION - " + #APP_NAME)
        ProcedureReturn
      EndIf
    CompilerEndIf

    *app\record = #True

    If IsWindow(*app\region)
      _DrawRegion(*app)
      HideWindow(*app\region, #True)
    EndIf

    Capture::Init(*app\capture, @*app\rect, *app\hWnd)
    *app\capture\excludeHWnd = Platform::GetWindowID(*app\window)

    SetGadgetText(*app\gadgetRecord, "Stop")
    SetWindowTitle(*app\window, "REC - " + #APP_NAME)
  EndProcedure

  Procedure _StopRecord(*app.App_t)
    Capture::Term(*app\capture)
    *app\record = #False

    SetGadgetText(*app\gadgetRecord, "Record")
    SetWindowTitle(*app\window, #APP_NAME)

    If IsWindow(*app\region)
      CloseWindow(*app\region)
      *app\region = 0
    EndIf

    Editor::Open(*app\capture, *app\outputFolder)
  EndProcedure

  Procedure OnRecord(*app.App_t)
    If *app\record
      _StopRecord(*app)
    Else
      _StartRecord(*app)
    EndIf
  EndProcedure

  ;---------------------------------------------------------------------------------------------
  ; Application entry point — compact floating bar
  ;---------------------------------------------------------------------------------------------
  Procedure Launch()
    Define app.App_t
    app\delay  = 50
    app\record = #False
    app\close  = #False

    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_MacOS
        app\outputFolder = GetEnvironmentVariable("HOME") + "/Documents/captures"
      CompilerCase #PB_OS_Windows
        app\outputFolder = GetEnvironmentVariable("USERPROFILE") + "\captures"
    CompilerEndSelect
    CreateDirectory(app\outputFolder)

    ExamineDesktops()
    Define scrW  = DesktopWidth(0)
    Define winW  = 280
    Define winH  = 46
    Define winX  = (scrW - winW) / 2
    Define winY  = 44   ; just below macOS menu bar

    app\window = OpenWindow(#PB_Any, winX, winY, winW, winH,
                            #APP_NAME,
                            #PB_Window_SystemMenu)

    Platform::EnsureCaptureAccess()

    Define bw = winW / 2 - 4
    app\gadgetRegion = ButtonGadget(#PB_Any,    2, 2, bw, winH-4, "Select Region")
    app\gadgetRecord = ButtonGadget(#PB_Any, bw+6, 2, bw, winH-4, "Record")

    StickyWindow(app\window, #True)
    CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
      CocoaMessage(0, WindowID(app\window), "setLevel:", 25)
    CompilerEndIf

    Repeat
      Define startTime.q = ElapsedMilliseconds()
      _Event(app, WaitWindowEvent(10))
      app\elapsed + (ElapsedMilliseconds() - startTime)
    Until app\close

    End
  EndProcedure

EndModule

ScreenCaptureToGif::Launch()
; IDE Options = PureBasic 6.00 Beta 7 - C Backend (MacOS X - arm64)
; CursorPosition = 1
; FirstLine = 1
; Folding = ----
; EnableXP
