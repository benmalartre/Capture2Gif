DeclareModule Platform
  Structure Rectangle_t
    x.i
    y.i
    w.i
    h.i
  EndStructure
  
  Structure Window_t
    hWnd.i
    Map childrens.i()
  EndStructure
  
  Declare GetWindowID(window)
  Declare GetWindowById(id.i)
  Declare GetWindowByName(name.s="Softimage")
  Declare GetWindowRect(window.i, *rect.Rectangle_t)
  Declare SetWindowTransparency(window.i, transparency.i=255)
  Declare SetWindowTransparentColor(window, color)
  Declare EnsureCaptureAccess()
  Declare CaptureWindowImage(img.i, window.i,*rect.Rectangle_t=#Null)
  Declare CaptureDesktopImage(img.i, *rect.Rectangle_t)
  
  Declare EnterWindowFullscreen(window)
  Declare ExitWindowFullscreen(window, x.i, y.i, width.i, height.i, title.s="")

  CompilerIf #PB_Compiler_OS = #PB_OS_MacOS    
    #NSApplicationPresentationDefault         = 0
    #NSApplicationPresentationAutoHideDock    = 1 << 0
    #NSApplicationPresentationAutoHideMenuBar = 1 << 2
    
    #NSBorderlessWindowMask                   = 0
    #NSTitledWindowMask                       = 1 << 0
    #NSClosableWindowMask                     = 1 << 1
    #NSMiniaturizableWindowMask               = 1 << 2
    #NSResizableWindowMask                    = 1 << 3
    
    #CGWindowListOptionAll                    = 0
    #CGWindowListOptionOnScreenOnly           = 1 << 0
    #CGWindowListOptionOnScreenAboveWindow    = 1 << 1
    #CGWindowListOptionOnScreenBelowWindow    = 1 << 2
    #CGWindowListOptionIncludingWindow        = 1 << 3
    #CGWindowListExcludeDesktopElements       = 1 << 4   
    
    #CGWindowImageBoundsIgnoreFraming         = 1 << 0
    
    ImportC ""
      CGPreflightScreenCaptureAccess()
      CGRequestScreenCaptureAccess()
      CGMainDisplayID()
      CGDisplayCreateImage(display)
      CGImageGetHeight(image)
      CGImageGetWidth(image)
      CGImageRelease(image)
      CGWindowListCreate(options, window)
      CGWindowListCreateDescriptionFromArray(arr)
      CGWindowListCreateImage(x.CGFloat, y.CGFloat, w.CGFloat, h.CGFloat, windowOption, windowID, imageOption)

      CFArrayCreate(allocator, values, numValues, callBacks)
      CFArrayGetCount(arr)
      CFArrayGetValueAtIndex(arr, index)
      CFRelease(arr)
      CFDictionaryGetValue(dict,key)
      CFStringCreateWithCharacters(alloc,text.p-Unicode,len)
      CFNumberGetValue(number,type,*value)
      CGRectMakeWithDictionaryRepresentation(desc, *rect.Rectangle_t)
    EndImport
  CompilerEndIf
EndDeclareModule

Module Platform
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ; get window id
    Procedure GetWindowID(window.i)
      ProcedureReturn WindowID(window)
    EndProcedure
    
    ; grand screen access for recording (unused on windows)
    Procedure EnsureCaptureAccess()
    EndProcedure
    
   ; helper function to capture window image
    Procedure CaptureWindowImage(img.i, window.i, *rect.Rectangle_t=#Null)
      Define dstDC = DrawingBuffer()
      Define srcDC = GetDC_(window)
      
      If dstDC And srcDC
        BitBlt_(dstDC,0,0,*rect\w,*rect\h,srcDC,*rect\x,*rect\y,#SRCCOPY)
      EndIf
      ReleaseDC_(window, srcDC)
    EndProcedure
    
    ; helper function to capture desktop image
   Procedure CaptureDesktopImage(img.i, *rect.Rectangle_t)
     Define window = GetDesktopWindow_() 
     CaptureWindowImage(img.i, window, *rect)
    EndProcedure
    
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
  
   ; get window by id
  ;
  Procedure GetWindowById(id.i)
    ProcedureReturn #Null
  EndProcedure
  
  ; try get a window by it's name
  ;
  Procedure GetWindowByName(name.s="Softimage")
    Define window.Window_t
    _EnumerateWindows(window)
    ForEach window\childrens()
      If FindString(MapKey(window\childrens()), name)
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
  
  ; get window rectangle
  Procedure GetWindowRect(window, *rect.Rectangle_t)
    GetWindowRect_(window, *rect)
  EndProcedure
  
  Procedure EnumerateChildWindows(*window.Window_t, pWnd)
    EnumChildWindows_(pWnd,@_EnumChildWindowsProc(), *window)
  EndProcedure 
  
  ; fullscreen

  Procedure EnterWindowFullscreen(window)
    Protected hWnd = WindowID(window)
    SetWindowState(window, #PB_Window_Normal)
    SetWindowLong_(hWnd, #GWL_STYLE, GetWindowLong_(hWnd, #GWL_STYLE)|#WS_CAPTION|#WS_SIZEBOX) 
  EndProcedure
  
  Procedure ExitWindowFullscreen(window, x.i, y.i, width.i, height.i, title.s="")
    Protected hWnd = WindowID(window)
    SetWindowState(window, #PB_Window_Maximize)
    SetWindowLong_(hWnd, #GWL_STYLE, GetWindowLong_(hWnd, #GWL_STYLE)&~#WS_CAPTION&~#WS_SIZEBOX) 
  EndProcedure
  
   Procedure SetWindowTransparency(window, transparency=255)
    Protected *windowID=WindowID(Window), exStyle=GetWindowLongPtr_(*windowID, #GWL_EXSTYLE)
    If Transparency>=0 And Transparency<=255
     SetWindowLongPtr_(*windowID, #GWL_EXSTYLE, exStyle | #WS_EX_LAYERED)
     SetLayeredWindowAttributes_(*windowID, 0, Transparency, #LWA_ALPHA)
  
     ProcedureReturn #True
    EndIf
  EndProcedure
  
  Procedure SetWindowTransparentColor(window, color)
    Protected *windowID=WindowID(Window), exStyle=GetWindowLongPtr_(*windowID, #GWL_EXSTYLE)
    SetWindowLongPtr_(*windowID, #GWL_EXSTYLE, exStyle | #WS_EX_LAYERED)
    SetLayeredWindowAttributes_(*windowID, color, #Null, #LWA_COLORKEY)
    
    ProcedureReturn #True

   EndProcedure

CompilerElseIf #PB_Compiler_OS = #PB_OS_MacOS
  ; get window core graphic id
  Procedure GetWindowID(window)
    ProcedureReturn CocoaMessage(0, WindowID(window), "windowNumber")
  EndProcedure
  
  ; request screen access for recording
  Procedure EnsureCaptureAccess()
    If Not CGPreflightScreenCaptureAccess()
      CGRequestScreenCaptureAccess()       
    EndIf 
  EndProcedure
    
  ; helper function to capture window image
  ; rect coordinates are in screen space
  ; null rect will capture the whole window
  Procedure CaptureWindowImage(img.i, window.i, *rect.Rectangle_t=#Null)
    Protected cgImage, rect.NSRect
    If *rect
      cgImage = CGWindowListCreateImage(*rect\x, *rect\y, *rect\w, *rect\h, 8, window, 1)
    Else
      cgImage = CGWindowListCreateImage(0, 0, 0, 0, 8, window, 1)
    EndIf
    
    Define size.NSSize
    size\width = CGImageGetWidth(cgImage)
    size\height = CGImageGetHeight(cgImage)
    
    nsImage = CocoaMessage(0, CocoaMessage(0, 0, "NSImage alloc"), 
                           "initWithCGImage:", cgImage, "size:@", @size)
    CGImageRelease(cgImage)
    
    rect\origin\x = 0
    rect\origin\y = 0
    rect\size\width = ImageWidth(img)
    rect\size\height = ImageHeight(img)

    StartDrawing(ImageOutput(img))
    CocoaMessage(0, nsImage, "drawInRect:@", @rect)
    StopDrawing()
    
    CGImageRelease(nsImage)
  EndProcedure
  
  ; helper function to capture desktop image
  Procedure CaptureDesktopImage(img.i, *rect.Rectangle_t)
    
    Define cgImage, nsImage, srcRect.NSRect, dstRect.NSRect, desktopRect.NSRect

    ; grab full screen image
    CocoaMessage(@desktopRect, CocoaMessage(0, 0, "NSScreen mainScreen"), "frame")
    
    cgImage = CGDisplayCreateImage(CGMainDisplayID())
    nsImage = CocoaMessage(0, CocoaMessage(0, 0, "NSImage alloc"), 
                           "initWithCGImage:", cgImage, "size:@", @desktopRect\size)
    
    ; extract rectangle region
    Protected delta.CGFloat = 1.0 
    
    srcRect\origin\x = *rect\x
    srcRect\origin\y = desktopRect\size\height - (*rect\y + *rect\h)
    srcRect\size\width = *rect\w
    srcRect\size\height = *rect\h
    
    dstRect\origin\x = 0
    dstRect\origin\y = 0
    dstRect\size\width = *rect\w
    dstRect\size\height = *rect\h

    StartDrawing(ImageOutput(img))
    CocoaMessage(0, nsImage, "drawInRect:@", @dstRect, "fromRect:@", @srcRect, 
                 "operation:", #NSCompositeSourceOver, "fraction:@", @delta)
    StopDrawing()
    
    CGImageRelease(nsImage)
    CGImageRelease(cgImage)
  EndProcedure
  
  ; helper to get cocoa string value
  Procedure.s _PeekNSString(string)
    ProcedureReturn PeekS(CocoaMessage(0, string, "UTF8String"), -1, #PB_UTF8)
  EndProcedure
  
  ; try get a window by it's name
  ;
  Procedure GetWindowByName(name.s="Softimage")
    Define windows = CGWindowListCreate(#CGWindowListOptionOnScreenOnly, 0)
    Define descriptions = CGWindowListCreateDescriptionFromArray(windows)

    If descriptions
      count = CFArrayGetCount(descriptions)
      For i = 0 To count-1
        desc = CFArrayGetValueAtIndex(descriptions,i)
        windowName = CFDictionaryGetValue(desc, CFStringCreateWithCharacters(0,"kCGWindowName",13))
              
        If FindString(_PeekNSString(windowName), name)
          Define bounds = CFDictionaryGetValue(desc, CFStringCreateWithCharacters(0,"kCGWindowBounds",15))        
          Define window =  CFArrayGetValueAtIndex(windows,i)
          CFRelease(descriptions)
          CFRelease(windows)
          ProcedureReturn window
        EndIf
      Next

    EndIf
    CFRelease(descriptions)
    CFRelease(windows)
    ProcedureReturn #Null
  EndProcedure
  
  ; get window by id
  ;
  Procedure GetWindowById(id.i)
    Define windows = CGWindowListCreate(#CGWindowListOptionAll, 0)
    Define descriptions = CGWindowListCreateDescriptionFromArray(windows)

    count = CFArrayGetCount(descriptions)
    For i = 0 To count-1
      desc = CFArrayGetValueAtIndex(descriptions,i)
      windowId = CFDictionaryGetValue(desc, CFStringCreateWithCharacters(0,"kCGWindowNumber",15))
      CFNumberGetValue(windowId, 5, @cid)

      If cid = id
        Define window =  CFArrayGetValueAtIndex(windows,i)
        CFRelease(descriptions)
        CFRelease(windows)
        ProcedureReturn window
      EndIf
    Next

    CFRelease(descriptions)
    CFRelease(windows)
    ProcedureReturn #Null
  EndProcedure
  
  ; get window rectangle
  Procedure GetWindowRect(window, *rect.Rectangle_t)
    Define windows = CFArrayCreate(0, @window, 1, 0)
    Define descriptions = CGWindowListCreateDescriptionFromArray(windows)
    
    Define rect.CGRect
    Define desc = CFArrayGetValueAtIndex(descriptions, 0)
    Define bounds = CFDictionaryGetValue(desc, CFStringCreateWithCharacters(0,"kCGWindowBounds",15))
    CGRectMakeWithDictionaryRepresentation(bounds, @rect)

    *rect\x = rect\origin\x
    *rect\y = rect\origin\y
    *rect\w = rect\size\width
    *rect\h = rect\size\height
    
  EndProcedure
  
  ;--[ Window fullscreen procedures ]----------------------------------------------------------------

  Procedure EnterWindowFullscreen(window)
    Define sharedApp = CocoaMessage(0, 0, "NSApplication sharedApplication")
    CocoaMessage(0, WindowID(window), "setStyleMask:", #NSBorderlessWindowMask)
    CocoaMessage(0, sharedApp, "setPresentationOptions:", 
                 #NSApplicationPresentationAutoHideDock | #NSApplicationPresentationAutoHideMenuBar)
    ExamineDesktops()
    ResizeWindow(window, 0, 0, DesktopWidth(0), DesktopHeight(0))
  EndProcedure
  
  Procedure ExitWindowFullscreen(window, x.i, y.i, width.i, height.i, title.s="")
    Define sharedApp = CocoaMessage(0, 0, "NSApplication sharedApplication")
    CocoaMessage(0, sharedApp, "setPresentationOptions:", #NSApplicationPresentationDefault)
    CocoaMessage(0, WindowID(window), "setStyleMask:", 
                 #NSTitledWindowMask | #NSClosableWindowMask | #NSMiniaturizableWindowMask | #NSResizableWindowMask)
    If title : SetWindowTitle(0, title) : EndIf
    ResizeWindow(window, x, y, width, height)
  EndProcedure
  
   Procedure SetWindowTransparency(window.i, transparency.i=255)
    Protected *windowID=WindowID(window), alpha.CGFloat=transparency/255.0
    If transparency>=0 And transparency<=255
      CocoaMessage(0, *windowID, "setOpaque:", #NO)
      If CocoaMessage(0, *windowID, "isOpaque")=#NO
        CocoaMessage(0, *windowID, "setAlphaValue:@", @alpha)
        ProcedureReturn #True
      EndIf
    EndIf
  EndProcedure
  
CompilerEndIf
EndModule

; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 82
; FirstLine = 51
; Folding = -----
; EnableXP