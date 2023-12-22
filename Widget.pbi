;================================================================================================
; WIDGET DECLARATION
;================================================================================================
DeclareModule Widget
  Enumeration
    #WIDGET_STATE_INACTIVE = 0
    #WIDGET_STATE_ACTIVE   = 1
    #WIDGET_STATE_HOVER    = 2
    #WIDGET_STATE_PRESS    = 4
    #WIDGET_STATE_TOGGLE   = 8
  EndEnumeration
  
  Enumeration
    #WIDGET_TYPE_NONE
    #WIDGET_TYPE_BUTTON
    #WIDGET_TYPE_ICON
    #WIDGET_TYPE_TEXT
    #WIDGET_TYPE_STRING
    #WIDGET_TYPE_CHECK
    #WIDGET_TYPE_COMBO
    #WIDGET_TYPE_CONTAINER
  EndEnumeration
  
  Enumeration
    #WIDGET_LAYOUT_HORIZONTAL
    #WIDGET_LAYOUT_VERTICAL
    #WIDGET_LAYOUT_GRID
  EndEnumeration
  
  #WIDGET_PADDING_X = 6
  #WIDGET_PADDING_Y = 6
  
  Structure Widget_t
    type.i
    x.i
    y.i
    width.i
    height.i
    state.i
    *parent.Widget_t
  EndStructure
  
  Structure Layout_t
    mode.i
    rules.s
  EndStructure

  Structure Container_t Extends Widget_t
    List *items.Widget_t()
    canvas.i
    layout.i
  EndStructure
  
  Structure Text_t Extends Widget_t
    text.i
  EndStructure
  
  Structure String_t Extends Widget_t
    string.i
  EndStructure
  
  Structure Button_t Extends Widget_t
    text.s
  EndStructure
  
  Structure Icon_t Extends Widget_t
    icon.s
  EndStructure
  
  Structure Check_t Extends Widget_t
    check.i
  EndStructure
  
  Declare CreateRoot(window.i)
  Declare CreateContainer(*p.Widget_t, x.i, y.i, w.i, h.i, c.b=#False, l=#WIDGET_LAYOUT_VERTICAL)
  Declare CreateButton(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
  Declare CreateIcon(*p.Container_t, icon.s, x.i, y.i, w.i, h.i)
  Declare CreateText(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
  Declare CreateString(*p.Container_t, x.i, y.i, w.i, h.i)
  Declare CreateCheck(*p.Container_t, label.s, check.b, x.i, y.i, w.i, h.i)
  Declare SetLayout(*p.Container_t, layout.i)
  Declare Resize(*widget.Widget_t, x.i, y.i, w.i, h.i)
  Declare Draw(*widget.Widget_t)
  Declare OnEvent(*widget.Widget_t)
  Declare GetCanvasId(*widget.Widget_t)
EndDeclareModule

;================================================================================================
; WIDGET IMPLEMENTATION
;================================================================================================
Module Widget
  Procedure _Set(*widget.Widget_t, t.i, parent.i, x.i, y.i, w.i, h.i)
    *widget\type    = t
    *widget\x       = x
    *widget\y       = y
    *widget\width   = w
    *widget\height  = h
    *widget\parent  = parent
  EndProcedure
  
  Procedure _AddItem(*parent.Container_t, *item.Widget_t)
    If Not *parent : ProcedureReturn : EndIf
    AddElement(*parent\items())
    *parent\items() = *item
  EndProcedure
  
  Procedure _GetRoot(*widget.Widget_t)
    If Not *widget\parent
      ProcedureReturn *widget
    Else
      ProcedureReturn _GetRoot(*widget\parent)
    EndIf
    
  EndProcedure
  
  Procedure _RemoveItem(*parent.Container_t, *item.Widget_t)
    ForEach *parent\items()  
      If *parent\items() = *item
        DeleteElement(*parent\items())
        FreeStructure(*item)
        ProcedureReturn
      EndIf
    Next
  EndProcedure
  
  Procedure _RoundBoxPath(x.f, y.f, width.f, height.f, radius.f=6)
    MovePathCursor(x + radius,y)
    AddPathArc(x+width,y,x+width,y+height,radius)
    AddPathArc(x+width,y+height,x,y+height,radius)
    AddPathArc(x,y+height,x,y,radius)
    AddPathArc(x,y,x+width,y,radius)
    ClosePath()
  EndProcedure
  
  Procedure _GetParentLayout(*widget.Widget_t)
    If *widget\parent\type = #WIDGET_TYPE_CONTAINER
      Define *parent.Container_t = *widget\parent
      ProcedureReturn *parent\layout
    Else
      ProcedureReturn #WIDGET_LAYOUT_VERTICAL
    EndIf
  EndProcedure
  
  Procedure.b _IsInside(*widget.Widget_t, x.i, y.i) 
    Define insideBox.b = Bool(x > *widget\x And x < (*widget\x + *widget\width) And 
                            y > *widget\y And y < (*widget\y + *widget\height))
    If *widget\type = #WIDGET_TYPE_ICON
      Define *icon.Icon_t = *widget
      AddPathSegments(*icon\icon)
      Define rx.i = (x - *widget\x)
      Define ry.i = (y - *widget\y)
      ProcedureReturn Bool(rx > 0 And rx < PathBoundsWidth() And 
                           ry > 0 And ry < PathBoundsHeight())
    EndIf
    ProcedureReturn insideBox
  EndProcedure
  
  
  Procedure _GetWidgetUnderMouse(*widget.Container_t)
    Define canvasId = GetCanvasId(*widget)
    Define mouseX = GetGadgetAttribute(canvasId, #PB_Canvas_MouseX)
    Define mouseY = GetGadgetAttribute(canvasId, #PB_Canvas_MouseY)
    Define *hovered = #Null
    StartVectorDrawing(CanvasVectorOutput(canvasId))
    ForEach *widget\items()
      If _IsInside(*widget\items(), mouseX, mouseY)
        *widget\items()\state = #WIDGET_STATE_HOVER
        *hovered = *widget\items()
      Else
        *widget\items()\state = #WIDGET_STATE_INACTIVE
      EndIf
    Next
    StopVectorDrawing()
    ProcedureReturn *hovered
  EndProcedure
  
  Procedure GetCanvasId(*widget.Widget_t)
    If *widget\type = #WIDGET_TYPE_CONTAINER  
      Define *container.Container_t = *widget
      If IsGadget(*container\canvas)
        ProcedureReturn *container\canvas
      EndIf
    Else 
      ProcedureReturn GetCanvasId(*widget\parent)
    EndIf
  EndProcedure
  
  Procedure Resize(*widget.Widget_t, x.i, y.i, w.i, h.i)
    _Set(*widget, *widget\type, *widget\parent, x, y, w, h)
    If *widget\type >= #WIDGET_TYPE_CONTAINER
      Define *container.Container_t = *widget
      If IsGadget(*container\canvas) 
        ResizeGadget(*container\canvas, x, y, w, h)
      EndIf  
      Select *container\layout
        Case #WIDGET_LAYOUT_VERTICAL
          Define nh = h / ListSize(*container\items())
          Define cy = #WIDGET_PADDING_Y
          ForEach *container\items()
            If *container\items()\type >= #WIDGET_TYPE_CONTAINER
              Resize(*container\items(),x, cy, w, nh)
              cy + h / ListSize(*container\items())
            Else
              Resize(*container\items(),
                     x+#WIDGET_PADDING_X, 
                     cy + #WIDGET_PADDING_Y, 
                     w-2*#WIDGET_PADDING_X, 
                     nh)
              cy + *container\items()\height + #WIDGET_PADDING_Y
            EndIf
          Next
          
        Case #WIDGET_LAYOUT_HORIZONTAL
          Define nw = w / ListSize(*container\items())
          Define cx = #WIDGET_PADDING_X
          Define cy = #WIDGET_PADDING_Y
          ForEach *container\items()
            If *container\items()\type >= #WIDGET_TYPE_CONTAINER
              Resize(*container\items(),cx, y, nw, h)
              cx + w / ListSize(*container\items())
            Else
              Resize(*container\items(),
                     cx + #WIDGET_PADDING_X, 
                     #WIDGET_PADDING_Y, 
                     nw,
                     h-2*#WIDGET_PADDING_Y)
              cx + *container\items()\width + #WIDGET_PADDING_x
            EndIf
          Next
          
       EndSelect
    EndIf
  EndProcedure
  
  Procedure OnEvent(*widget.Widget_t)
    Define event.i = EventType()    
    If event = #PB_EventType_LeftClick
      Debug "LEFT CLICK" + Str(*widget)
      ;       Debug GetGadgetAttribute(*widget
    ElseIf event = #PB_EventType_MouseMove
      _GetWidgetUnderMouse(*widget)
      Draw(*widget)
      Debug "Widget Under mouse : "+Str(*widget)
    
    EndIf   
  EndProcedure
  
  
  Procedure Draw(*widget.Widget_t)
    If *widget\type >= #WIDGET_TYPE_CONTAINER
      Define *container.Container_t = *widget
      Define c = IsGadget(*container\canvas)
      If c 
        StartVectorDrawing(CanvasVectorOutput(c))
        Define fontId = GetGadgetFont(#PB_Default)
        VectorFont(fontId, 32)
        AddPathBox(0,0,GadgetWidth(*container\canvas), GadgetHeight(*container\canvas))
        VectorSourceColor(RGBA(Random(128),Random(128),Random(128),Random(128)))
        FillPath()
      EndIf
      ForEach *container\items()
        Draw(*container\items())
      Next
      If c: StopVectorDrawing() : EndIf
    Else
      Select *widget\type
        Case #WIDGET_TYPE_ICON
          Define *icon.Icon_t = *widget
          TranslateCoordinates(*widget\x, *widget\y)
          AddPathSegments(*icon\icon)
          VectorSourceColor(RGBA(55, 55, 55, 22))
          StrokePath(8, #PB_Path_RoundCorner|#PB_Path_RoundEnd|#PB_Path_Preserve)
          VectorSourceColor(RGBA(255, 255, 255, 120))
          StrokePath(2, #PB_Path_RoundCorner|#PB_Path_RoundEnd|#PB_Path_Preserve)
          If *icon\state = #WIDGET_STATE_HOVER
            VectorSourceColor(RGBA(155,25,25,255))
          Else
            VectorSourceColor(RGBA(25,125,25,255))
          EndIf
          FillPath()

          ResetCoordinates()
          
        Case #WIDGET_TYPE_BUTTON
          Define *button.Button_t = *widget
          _RoundBoxPath(*widget\x, *widget\y, *widget\width, *widget\height,8)
          VectorSourceColor(RGBA(55, 55, 55, 22))
          StrokePath(8, #PB_Path_RoundCorner|#PB_Path_RoundEnd|#PB_Path_Preserve)
          VectorSourceColor(RGBA(255, 255, 255, 120))
          StrokePath(2, #PB_Path_RoundCorner|#PB_Path_RoundEnd|#PB_Path_Preserve)
          VectorSourceColor(RGBA(55,55,55, 255))
          FillPath()
          MovePathCursor((*widget\width - VectorTextWidth(*button\text))/2, *widget\y)
          If *button\state = #WIDGET_STATE_HOVER
            VectorSourceColor(RGBA(120, 120, 120, 255))
          Else
            VectorSourceColor(RGBA(255, 255, 255, 255))
          EndIf
          
          DrawVectorText(*button\text)
          StrokePath(2)
          
        Case #WIDGET_TYPE_TEXT
          
      EndSelect
      
    EndIf
    
  EndProcedure
  
  
  Procedure CreateRoot(window)
    Define *widget.Container_t = AllocateStructure(Container_t)
    Define width = WindowWidth(window, #PB_Window_InnerCoordinate)
    Define height = WindowHeight(window, #PB_Window_InnerCoordinate)
    _Set(*widget, #WIDGET_TYPE_CONTAINER, #Null, 0, 0, w, h)
    *widget\canvas = 0
    *widget\layout = #WIDGET_LAYOUT_VERTICAL
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateContainer(*p.Widget_t, x.i, y.i, w.i, h.i, c.b=#False, l.i=#WIDGET_LAYOUT_VERTICAL)
    Define *widget.Container_t = AllocateStructure(Container_t)
    _Set(*widget, #WIDGET_TYPE_CONTAINER, *p, x, y, w, h)
    _AddItem(*p, *widget)
    
    If c 
      *widget\canvas = CanvasGadget(#PB_Any, x, y, w, h, #PB_Canvas_Keyboard)
    EndIf
    *widget\layout = l
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateButton(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
     Define *widget.Button_t = AllocateStructure(Button_t)
    *widget\text = text
    _Set(*widget, #WIDGET_TYPE_BUTTON, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateIcon(*p.Container_t, icon.s, x.i, y.i, w.i, h.i)
    Define *widget.Icon_t = AllocateStructure(Icon_t)
    *widget\icon= icon
    _Set(*widget, #WIDGET_TYPE_ICON, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateText(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
    Define *widget.Text_t = AllocateStructure(Text_t)
    *widget\text = TextGadget(#PB_Any, x, y, w, h, text)
    _Set(*widget, #WIDGET_TYPE_TEXT, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateString(*p.Container_t, x.i, y.i, w.i, h.i)
    Define *widget.String_t = AllocateStructure(String_t)
    *widget\string = StringGadget(#PB_Any, x, y, w, h, "")
    _Set(*widget, #WIDGET_TYPE_STRING, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateCheck(*p.Container_t, label.s, check.b, x.i, y.i, w.i, h.i)
    Define *widget.Check_t = AllocateStructure(Check_t)
    *widget\check = 0;CheckBoxGadget(#PB_Any, x, y, w, h, label)
    _Set(*widget, #WIDGET_TYPE_CHECK, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure SetLayout(*p.Container_t, layout.i)
    *p\layout = layout  
  EndProcedure
  
  
EndModule



; IDE Options = PureBasic 5.73 LTS (Windows - x64)
; CursorPosition = 152
; FirstLine = 103
; Folding = b+P9
; EnableXP