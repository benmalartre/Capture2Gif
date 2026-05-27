XIncludeFile "Capture.pbi"

;------------------------------------------------------------------------------------------------
; GIF EDITOR MODULE
; Opens a window to preview, trim, and export recorded or loaded GIF frames.
;------------------------------------------------------------------------------------------------
DeclareModule Editor

  ; Open the editor with frames from a completed Capture session.
  ; The Capture_t is borrowed — caller must not free it while editor is open.
  ; The editor calls Capture::Export() on save, then Capture::Free() on close.
  Declare Open(*capture.Capture::Capture_t, outputFolder.s)

  ; Open the editor by loading an existing GIF file.
  Declare OpenGif(filename.s, outputFolder.s)

EndDeclareModule

Module Editor

  UseModule Capture

  ;--- Editor state ---
  Structure Editor_t
    window.i
    canvas.i          ; CanvasGadget for frame preview
    timeline.i        ; TrackBarGadget — scrubs through frames
    spinDelay.i       ; SpinGadget — delay in centiseconds
    spinStart.i       ; SpinGadget — first frame to export
    spinEnd.i         ; SpinGadget — last frame to export
    lblFrame.i        ; TextGadget — "Frame N / Total"
    lblSize.i         ; TextGadget — "WxH, N frames"
    btnPlay.i         ; play/pause toggle
    btnPrev.i
    btnNext.i
    btnFirst.i
    btnLast.i
    btnLoad.i
    btnSave.i
    previewImg.i      ; in-memory image used for canvas rendering
    *frames           ; pointer to array of frame pointers (void**)
    frameCount.i
    width.i
    height.i
    currentFrame.i
    delay.i           ; centiseconds per frame (used for playback and export)
    playing.b
    ownFrames.b       ; #True when Editor owns frames (loaded from file)
    *capture.Capture::Capture_t
    outputFolder.s
    elapsed.q
  EndStructure

  #EDITOR_W  = 860
  #EDITOR_H  = 540
  #CANVAS_X  = 8
  #CANVAS_Y  = 48
  #CANVAS_W  = 560
  #CANVAS_H  = 400
  #CTRL_X    = 580
  #CTRL_W    = 272
  #ROW_H     = 28
  #BTN_H     = 28
  #TL_Y      = 456
  #TL_H      = 28
  #PAD       = 8

  Procedure _FramePtr(*e.Editor_t, index.i)
    If index < 0 Or index >= *e\frameCount Or Not *e\frames
      ProcedureReturn #Null
    EndIf
    ProcedureReturn PeekI(*e\frames + index * SizeOf(Integer))
  EndProcedure

  Procedure _DrawFrame(*e.Editor_t)
    Define *frameData = _FramePtr(*e, *e\currentFrame)
    If Not *frameData Or Not IsImage(*e\previewImg)
      ProcedureReturn
    EndIf

    ; copy raw pixel data into the preview image
    StartDrawing(ImageOutput(*e\previewImg))
    CopyMemory(*frameData, DrawingBuffer(), *e\width * *e\height * 4)
    StopDrawing()

    ; draw scaled image onto the canvas
    StartDrawing(CanvasOutput(*e\canvas))
    DrawingMode(#PB_2DDrawing_Default)
    Box(0, 0, #CANVAS_W, #CANVAS_H, $FF202020)

    Define aspect.f = *e\width / *e\height
    Define dispW.i, dispH.i, offX.i, offY.i

    If aspect >= (#CANVAS_W / #CANVAS_H)
      dispW = #CANVAS_W
      dispH = #CANVAS_W / aspect
    Else
      dispH = #CANVAS_H
      dispW = #CANVAS_H * aspect
    EndIf
    offX = (#CANVAS_W - dispW) >> 1
    offY = (#CANVAS_H - dispH) >> 1

    DrawImage(ImageID(*e\previewImg), offX, offY, dispW, dispH)
    StopDrawing()
  EndProcedure

  Procedure _DrawTimeline(*e.Editor_t)
    ; timeline is a TrackBar — just sync its position
    SetGadgetState(*e\timeline, *e\currentFrame)
  EndProcedure

  Procedure _UpdateLabels(*e.Editor_t)
    SetGadgetText(*e\lblFrame, "Frame " + Str(*e\currentFrame) + " / " + Str(*e\frameCount - 1))
  EndProcedure

  Procedure _GoToFrame(*e.Editor_t, index.i)
    If index < 0 : index = 0 : EndIf
    If index >= *e\frameCount : index = *e\frameCount - 1 : EndIf
    *e\currentFrame = index
    _DrawFrame(*e)
    _DrawTimeline(*e)
    _UpdateLabels(*e)
  EndProcedure

  Procedure _TogglePlay(*e.Editor_t)
    *e\playing ! #True
    *e\elapsed = ElapsedMilliseconds()
    If *e\playing
      SetGadgetText(*e\btnPlay, "  ||  ")
    Else
      SetGadgetText(*e\btnPlay, "  >  ")
    EndIf
  EndProcedure

  Procedure _SaveGif(*e.Editor_t)
    Define startF = GetGadgetState(*e\spinStart)
    Define endF   = GetGadgetState(*e\spinEnd)
    Define delay  = GetGadgetState(*e\spinDelay)

    If startF < 0 : startF = 0 : EndIf
    If endF < 0 Or endF >= *e\frameCount : endF = *e\frameCount - 1 : EndIf
    If delay  < 1 : delay  = 5 : EndIf

    Define filename.s = SaveFileRequester("Save GIF", *e\outputFolder, "GIF Files|*.gif", 0)
    If filename = "" : ProcedureReturn : EndIf

    ; ensure .gif extension
    If LCase(Right(filename, 4)) <> ".gif"
      filename + ".gif"
    EndIf

    ; use Capture::Export when frames come from a live session
    If *e\capture And Not *e\ownFrames
      *e\capture\delay = delay
      Capture::Export(*e\capture, filename, startF, endF)
    Else
      AnimatedGif_WriteFrames(filename, *e\frames, *e\frameCount,
                               *e\width, *e\height, startF, endF, delay)
    EndIf
  EndProcedure

  Procedure _LoadGif(*e.Editor_t)
    Define filename.s = OpenFileRequester("Load GIF", *e\outputFolder, "GIF Files|*.gif", 0)
    If filename = "" : ProcedureReturn : EndIf

    Define newCount.i, newW.i, newH.i, newDelay.i
    Define *newFrames = GifLoad(filename, @newCount, @newW, @newH, @newDelay)
    If Not *newFrames Or newCount <= 0 : ProcedureReturn : EndIf

    ; free existing owned frames
    If *e\ownFrames And *e\frames And *e\frameCount > 0
      GifFreeFrames(*e\frames, *e\frameCount)
    EndIf
    ; free image and recreate for new size
    If IsImage(*e\previewImg) : FreeImage(*e\previewImg) : EndIf

    *e\frames      = *newFrames
    *e\frameCount  = newCount
    *e\width       = newW
    *e\height      = newH
    *e\delay       = newDelay
    *e\ownFrames   = #True
    *e\currentFrame = 0
    *e\playing     = #False

    *e\previewImg = CreateImage(#PB_Any, *e\width, *e\height, 32)

    ; update controls range
    SetGadgetAttribute(*e\spinStart, #PB_Spin_Minimum, 0)
    SetGadgetAttribute(*e\spinStart, #PB_Spin_Maximum, newCount - 1)
    SetGadgetState(*e\spinStart, 0)
    SetGadgetAttribute(*e\spinEnd, #PB_Spin_Minimum, 0)
    SetGadgetAttribute(*e\spinEnd, #PB_Spin_Maximum, newCount - 1)
    SetGadgetState(*e\spinEnd, newCount - 1)
    SetGadgetAttribute(*e\spinDelay, #PB_Spin_Minimum, 1)
    SetGadgetAttribute(*e\spinDelay, #PB_Spin_Maximum, 1000)
    SetGadgetState(*e\spinDelay, newDelay)
    SetGadgetAttribute(*e\timeline, #PB_TrackBar_Minimum, 0)
    SetGadgetAttribute(*e\timeline, #PB_TrackBar_Maximum, newCount - 1)

    SetGadgetText(*e\lblSize, Str(newW) + " x " + Str(newH) + ", " + Str(newCount) + " frames")
    SetGadgetText(*e\btnPlay, "  >  ")

    _GoToFrame(*e, 0)
  EndProcedure

  Procedure _BuildUI(*e.Editor_t)
    Define w  = #EDITOR_W
    Define h  = #EDITOR_H
    Define cx = #CTRL_X
    Define cw = #CTRL_W
    Define py = #CANVAS_Y
    Define rowH = #ROW_H
    Define pad = #PAD

    ; top bar
    *e\btnLoad = ButtonGadget(#PB_Any, pad, pad, 120, #BTN_H, "Load GIF...")
    *e\btnSave = ButtonGadget(#PB_Any, w - 130, pad, 120, #BTN_H, "Save GIF...")

    ; frame preview canvas
    *e\canvas  = CanvasGadget(#PB_Any, #CANVAS_X, #CANVAS_Y, #CANVAS_W, #CANVAS_H)

    ; right panel — controls
    Define cy = py

    TextGadget(#PB_Any, cx, cy + 4, 90, rowH - 4, "Delay (cs):")
    *e\spinDelay = SpinGadget(#PB_Any, cx + 94, cy, cw - 94 - pad, rowH, 1, 1000, #PB_Spin_Numeric)
    SetGadgetState(*e\spinDelay, *e\delay)
    cy + rowH + pad

    TextGadget(#PB_Any, cx, cy + 4, 90, rowH - 4, "Start frame:")
    *e\spinStart = SpinGadget(#PB_Any, cx + 94, cy, cw - 94 - pad, rowH, 0, *e\frameCount - 1, #PB_Spin_Numeric)
    SetGadgetState(*e\spinStart, 0)
    cy + rowH + pad

    TextGadget(#PB_Any, cx, cy + 4, 90, rowH - 4, "End frame:")
    *e\spinEnd = SpinGadget(#PB_Any, cx + 94, cy, cw - 94 - pad, rowH, 0, *e\frameCount - 1, #PB_Spin_Numeric)
    SetGadgetState(*e\spinEnd, *e\frameCount - 1)
    cy + rowH + pad

    *e\lblFrame = TextGadget(#PB_Any, cx, cy + 4, cw - pad, rowH - 4, "Frame 0 / 0")
    cy + rowH + pad

    *e\lblSize = TextGadget(#PB_Any, cx, cy + 4, cw - pad, rowH - 4,
                             Str(*e\width) + " x " + Str(*e\height) + ", " + Str(*e\frameCount) + " frames")
    cy + rowH + (pad * 2)

    ; playback buttons row
    Define btnW = (cw - pad) / 5
    *e\btnFirst = ButtonGadget(#PB_Any, cx,                     cy, btnW, #BTN_H, "|<")
    *e\btnPrev  = ButtonGadget(#PB_Any, cx + btnW,              cy, btnW, #BTN_H, " < ")
    *e\btnPlay  = ButtonGadget(#PB_Any, cx + btnW * 2,          cy, btnW, #BTN_H, "  >  ")
    *e\btnNext  = ButtonGadget(#PB_Any, cx + btnW * 3,          cy, btnW, #BTN_H, " > ")
    *e\btnLast  = ButtonGadget(#PB_Any, cx + btnW * 4,          cy, btnW, #BTN_H, ">|")

    ; timeline scrubber
    *e\timeline = TrackBarGadget(#PB_Any, pad, #TL_Y, w - (pad * 2), #TL_H, 0, *e\frameCount - 1)
    SetGadgetState(*e\timeline, 0)
  EndProcedure

  Procedure _RunLoop(*e.Editor_t)
    Define done.b = #False
    Define event.i
    Define gadget.i
    Define now.q

    _DrawFrame(*e)
    _UpdateLabels(*e)

    Repeat
      event = WaitWindowEvent(10)   ; 10 ms timeout so playback stays responsive

      If event = #PB_Event_CloseWindow And EventWindow() = *e\window
        done = #True
      EndIf

      If event = #PB_Event_Gadget And EventWindow() = *e\window
        gadget = EventGadget()

        If gadget = *e\btnLoad
          _LoadGif(*e)

        ElseIf gadget = *e\btnSave
          _SaveGif(*e)

        ElseIf gadget = *e\btnPlay
          _TogglePlay(*e)

        ElseIf gadget = *e\btnFirst
          *e\playing = #False
          SetGadgetText(*e\btnPlay, "  >  ")
          _GoToFrame(*e, GetGadgetState(*e\spinStart))

        ElseIf gadget = *e\btnLast
          *e\playing = #False
          SetGadgetText(*e\btnPlay, "  >  ")
          _GoToFrame(*e, GetGadgetState(*e\spinEnd))

        ElseIf gadget = *e\btnPrev
          *e\playing = #False
          SetGadgetText(*e\btnPlay, "  >  ")
          _GoToFrame(*e, *e\currentFrame - 1)

        ElseIf gadget = *e\btnNext
          *e\playing = #False
          SetGadgetText(*e\btnPlay, "  >  ")
          _GoToFrame(*e, *e\currentFrame + 1)

        ElseIf gadget = *e\timeline
          *e\playing = #False
          SetGadgetText(*e\btnPlay, "  >  ")
          _GoToFrame(*e, GetGadgetState(*e\timeline))

        ElseIf gadget = *e\spinDelay
          *e\delay = GetGadgetState(*e\spinDelay)

        ElseIf gadget = *e\spinStart
          Define sv = GetGadgetState(*e\spinStart)
          If sv > GetGadgetState(*e\spinEnd)
            SetGadgetState(*e\spinEnd, sv)
          EndIf

        ElseIf gadget = *e\spinEnd
          Define ev = GetGadgetState(*e\spinEnd)
          If ev < GetGadgetState(*e\spinStart)
            SetGadgetState(*e\spinStart, ev)
          EndIf

        EndIf
      EndIf

      ; advance playback
      If *e\playing And *e\frameCount > 0
        now = ElapsedMilliseconds()
        If (now - *e\elapsed) >= (*e\delay * 10)   ; delay is centiseconds, * 10 = ms
          *e\elapsed = now
          Define startF = GetGadgetState(*e\spinStart)
          Define endF   = GetGadgetState(*e\spinEnd)
          Define nextFrame = *e\currentFrame + 1
          If nextFrame > endF : nextFrame = startF : EndIf
          _GoToFrame(*e, nextFrame)
        EndIf
      EndIf

    Until done

    ; cleanup
    If IsImage(*e\previewImg) : FreeImage(*e\previewImg) : EndIf
    If IsWindow(*e\window) : CloseWindow(*e\window) : EndIf

    If *e\ownFrames And *e\frames And *e\frameCount > 0
      GifFreeFrames(*e\frames, *e\frameCount)
    ElseIf Not *e\ownFrames And *e\capture
      Capture::Free(*e\capture)
    EndIf
  EndProcedure

  Procedure _InitFromCapture(*e.Editor_t, *capture.Capture::Capture_t, outputFolder.s)
    *e\capture     = *capture
    *e\frames      = *capture\frames
    *e\frameCount  = *capture\frameCount
    *e\width       = *capture\rect\w
    *e\height      = *capture\rect\h
    *e\delay       = 5     ; default 50ms (5 centiseconds)
    *e\ownFrames   = #False
    *e\outputFolder = outputFolder
  EndProcedure

  Procedure Open(*capture.Capture::Capture_t, outputFolder.s)
    If Not *capture Or *capture\frameCount <= 0
      ProcedureReturn
    EndIf

    Define e.Editor_t
    _InitFromCapture(@e, *capture, outputFolder)

    e\previewImg = CreateImage(#PB_Any, e\width, e\height, 32)

    e\window = OpenWindow(#PB_Any, 100, 80, #EDITOR_W, #EDITOR_H, "GIF Editor",
                          #PB_Window_SystemMenu | #PB_Window_SizeGadget)
    If Not IsWindow(e\window) : ProcedureReturn : EndIf

    _BuildUI(@e)
    _RunLoop(@e)
  EndProcedure

  Procedure OpenGif(filename.s, outputFolder.s)
    Define e.Editor_t
    e\outputFolder = outputFolder
    e\ownFrames    = #True
    e\delay        = 5

    Define count.i, w.i, h.i, delay.i
    Define *frames = GifLoad(filename, @count, @w, @h, @delay)
    If Not *frames Or count <= 0
      MessageRequester("Error", "Could not load GIF: " + filename)
      ProcedureReturn
    EndIf

    e\frames      = *frames
    e\frameCount  = count
    e\width       = w
    e\height      = h
    e\delay       = delay

    e\previewImg = CreateImage(#PB_Any, e\width, e\height, 32)

    e\window = OpenWindow(#PB_Any, 100, 80, #EDITOR_W, #EDITOR_H, "GIF Editor — " + GetFilePart(filename),
                          #PB_Window_SystemMenu | #PB_Window_SizeGadget)
    If Not IsWindow(e\window) : ProcedureReturn : EndIf

    _BuildUI(@e)
    _RunLoop(@e)
  EndProcedure

EndModule
; IDE Options = PureBasic 6.00 Beta 7 - C Backend (MacOS X - arm64)
; CursorPosition = 1
; FirstLine = 1
; Folding = -
; EnableXP
