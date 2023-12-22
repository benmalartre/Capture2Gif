;------------------------------------------------------------------------------------------------
; WIDGET DECLARATION
;------------------------------------------------------------------------------------------------
DeclareModule Widget
  Enumeration
    #WIDGET_STATE_DEFAULT  = 0
    #WIDGET_STATE_ACTIVE   = 1
    #WIDGET_STATE_INACTIVE = 2
    #WIDGET_STATE_HOVER    = 4
    #WIDGET_STATE_PRESS    = 8
    #WIDGET_STATE_TOGGLE   = 16
    #WIDGET_STATE_ROOT     = 32
    #WIDGET_STATE_CANVAS   = 64
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
  
  Prototype CallbackFn(*data=#Null)
  
  Structure Widget_t
    type.i
    x.i
    y.i
    width.i
    height.i
    state.i
    *parent.Widget_t
    callback.CallbackFn
    *data
  EndStructure
  
  Structure Layout_t
    mode.i
    rules.s
  EndStructure

  Structure Container_t Extends Widget_t
    List *items.Widget_t()
    *hovered.Widget_t
    *active.Widget_t
    gadget.i
    layout.i
  EndStructure
  
  Structure Text_t Extends Widget_t
    gadget.i
  EndStructure
  
  Structure String_t Extends Widget_t
    gadget.i
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
  Declare OnEvent(*widget.Container_t)
  Declare SetLayout(*p.Container_t, layout.i)
  Declare SetCallback(*widget.Widget_t, cb.CallbackFn, *data)
  Declare Resize(*widget.Widget_t, x.i, y.i, w.i, h.i)
  Declare Draw(*widget.Widget_t)
  Declare Callback(*widget.Widget_t)
  Declare GetGadgetId(*widget.Widget_t)

EndDeclareModule

;------------------------------------------------------------------------------------------------
; WIDGET IMPLEMENTATION
;------------------------------------------------------------------------------------------------
Module Widget
  Procedure _Set(*widget.Widget_t, t.i, parent.i, x.i, y.i, w.i, h.i)
    *widget\type     = t
    *widget\x        = x
    *widget\y        = y
    *widget\width    = w
    *widget\height   = h
    *widget\parent   = parent
  EndProcedure
  
  Procedure _GetRoot(*widget.Widget_t)
    If *widget\state & #WIDGET_STATE_ROOT
      ProcedureReturn *widget
    Else
      ProcedureReturn _GetRoot(*widget\parent)
    EndIf
  EndProcedure
  
  Procedure _AddItem(*parent.Container_t, *item.Widget_t)
    If Not *parent : ProcedureReturn : EndIf
    AddElement(*parent\items())
    *parent\items() = *item
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
  
  Procedure _IsInside(*widget.Widget_t, x.i, y.i) 
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
    Define canvasId = GetGadgetId(*widget)
    Define mouseX = GetGadgetAttribute(canvasId, #PB_Canvas_MouseX)
    Define mouseY = GetGadgetAttribute(canvasId, #PB_Canvas_MouseY)
    *widget\hovered = #Null
    ForEach *widget\items()
      If _IsInside(*widget\items(), mouseX, mouseY)
        *widget\items()\state = #WIDGET_STATE_HOVER
        *widget\hovered = *widget\items()
      Else
        *widget\items()\state = #WIDGET_STATE_INACTIVE
      EndIf
    Next
    ResetPath()
  EndProcedure
  
  Procedure SetLayout(*p.Container_t, layout.i)
    *p\layout = layout
    Resize(*p, *p\x, *p\y, *p\width, *p\height)
    Draw(*p)
  EndProcedure
  
  Procedure GetGadgetId(*widget.Widget_t)
    If *widget\type = #WIDGET_TYPE_CONTAINER  
      Define *container.Container_t = *widget
      ProcedureReturn *container\gadget
    Else 
      ProcedureReturn GetGadgetId(*widget\parent)
    EndIf
  EndProcedure
  
  Procedure Resize(*widget.Widget_t, x.i, y.i, w.i, h.i)
    *widget\x = x
    *widget\y = y
    *widget\width = w
    *widget\height = h
    If *widget\type = #WIDGET_TYPE_CONTAINER
      Define *container.Container_t = *widget
      ResizeGadget(*container\gadget, x, y, w, h)

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
      
    ElseIf *widget\type = #WIDGET_TYPE_TEXT
      Define *text.Text_t = *widget
      ResizeGadget(*text\gadget, x, y, w, h)
      
    ElseIf *widget\type = #WIDGET_TYPE_STRING
      Define *string.String_t = *widget
      ResizeGadget(*string\gadget, x, y, w, h)

    EndIf
    
  EndProcedure
  
  Procedure OnEvent(*widget.Container_t)
    Define event.i = EventType()    
    If event = #PB_EventType_LeftClick
      If *widget\hovered : Callback(*widget\hovered) :EndIf
      
    ElseIf event = #PB_EventType_MouseMove
      Draw(*widget)    
    EndIf   
  EndProcedure
  
  Procedure SetCallback(*widget.Widget_t, cb.CallbackFn, *data)
    *widget\callback = cb
    *widget\data = *data
  EndProcedure
  
  Procedure Callback(*widget.Widget_t)
    If *widget\callback
      *widget\callback(*widget\data)
      Widget::Resize(*widget\parent, *widget\parent\x, *widget\parent\y, 
                     *widget\parent\width, *widget\parent\height)
    EndIf
  EndProcedure

  Procedure Draw(*widget.Widget_t)
    Define fontId = GetGadgetFont(#PB_Default)
   
    If *widget\type >= #WIDGET_TYPE_CONTAINER
      Define *container.Container_t = *widget
      Define c = Bool(*container\state & #WIDGET_STATE_CANVAS)
      If c 
        StartVectorDrawing(CanvasVectorOutput(*container\gadget))
        ResetPath()
        VectorFont(fontId, 32)
        AddPathBox(0,0,GadgetWidth(*container\gadget), GadgetHeight(*container\gadget))
        VectorSourceColor(RGBA(Random(128),Random(128),Random(128),Random(255)))
        FillPath()
        _GetWidgetUnderMouse(*widget)
      EndIf
      
      ForEach *container\items()
        Draw(*container\items())
      Next
      If c: StopVectorDrawing() : EndIf
    Else
      Select *widget\type
        Case #WIDGET_TYPE_ICON
          Define *icon.Icon_t = *widget
          MovePathCursor(*widget\x, *widget\y)
          AddPathSegments(*icon\icon, #PB_Path_Relative )
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
    Define *root.Container_t = AllocateStructure(Container_t)
    Define width = WindowWidth(window, #PB_Window_InnerCoordinate)
    Define height = WindowHeight(window, #PB_Window_InnerCoordinate)
    _Set(*root, #WIDGET_TYPE_CONTAINER, #Null, 0, 0, w, h)
    *root\state = #WIDGET_STATE_ROOT
    *root\gadget = ContainerGadget(#PB_Any, 0, 0, w, h)
    *root\layout = #WIDGET_LAYOUT_VERTICAL
    *root\hovered = #Null
    ProcedureReturn *root
  EndProcedure
  
  Procedure CreateContainer(*p.Widget_t, x.i, y.i, w.i, h.i, c.b=#False, l.i=#WIDGET_LAYOUT_VERTICAL)
    Define *widget.Container_t = AllocateStructure(Container_t)
    _Set(*widget, #WIDGET_TYPE_CONTAINER, *p, x, y, w, h)
    _AddItem(*p, *widget)
    If c 
      *widget\gadget = CanvasGadget(#PB_Any, x, y, w, h, #PB_Canvas_Keyboard)
      *widget\state | #WIDGET_STATE_CANVAS 
    Else
      *widget\gadget = ContainerGadget(#PB_Any, x, y, w, h)
    EndIf
    *widget\layout = l
    *widget\hovered = #Null
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateButton(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
     Define *widget.Button_t = AllocateStructure(Button_t)
    _Set(*widget, #WIDGET_TYPE_BUTTON, *p, x, y, w, h)
    _AddItem(*p, *widget)
    *widget\text = text
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateIcon(*p.Container_t, icon.s, x.i, y.i, w.i, h.i)
    Define *widget.Icon_t = AllocateStructure(Icon_t)
    _Set(*widget, #WIDGET_TYPE_ICON, *p, x, y, w, h)
    _AddItem(*p, *widget)
    *widget\icon= icon
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateText(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
    Define *widget.Text_t = AllocateStructure(Text_t)
    *widget\gadget = TextGadget(#PB_Any, x, y, w, h, text)
    _Set(*widget, #WIDGET_TYPE_TEXT, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateString(*p.Container_t, x.i, y.i, w.i, h.i)
    Define *widget.String_t = AllocateStructure(String_t)
    *widget\gadget = StringGadget(#PB_Any, x, y, w, h, "")
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
  
  
EndModule



; IDE Options = PureBasic 5.73 LTS (Windows - x64)
; CursorPosition = 401
; FirstLine = 166
; Folding = DABY-
; EnableXP