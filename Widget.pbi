;------------------------------------------------------------------------------------------------
; WIDGET DECLARATION
;------------------------------------------------------------------------------------------------
DeclareModule Widget
  Enumeration
    #WIDGET_STATE_DEFAULT  = 0
    #WIDGET_STATE_ACTIVE   = 1 << 0
    #WIDGET_STATE_DISBALE  = 1 << 1
    #WIDGET_STATE_HOVER    = 1 << 2
    #WIDGET_STATE_PRESS    = 1 << 3
    #WIDGET_STATE_TOGGLE   = 1 << 4
    #WIDGET_STATE_ROOT     = 1 << 5
    #WIDGET_STATE_CANVAS   = 1 << 6
  EndEnumeration
  
  Enumeration
    #WIDGET_TYPE_NONE
    #WIDGET_TYPE_BUTTON
    #WIDGET_TYPE_ICON
    #WIDGET_TYPE_TEXT
    #WIDGET_TYPE_STRING
    #WIDGET_TYPE_CHECK
    #WIDGET_TYPE_COMBO
    #WIDGET_TYPE_LIST
    #WIDGET_TYPE_EXPLORER
    #WIDGET_TYPE_CONTAINER
  EndEnumeration
  
  Enumeration
    #WIDGET_ALIGN_TOP     = 1 << 0
    #WIDGET_ALIGN_BOTTOM  = 1 << 1
    #WIDGET_ALIGN_LEFT    = 1 << 2
    #WIDGET_ALIGN_RIGHT   = 1 << 3
  EndEnumeration
  
  Enumeration
    #WIDGET_LAYOUT_HORIZONTAL
    #WIDGET_LAYOUT_VERTICAL
    #WIDGET_LAYOUT_GRID
  EndEnumeration
  
  #WIDGET_PADDING_X     = 6
  #WIDGET_PADDING_Y     = 6
  #WIDGET_STROKE_WIDTH  = 4
  
  Global BACKGROUND_COLOR = RGBA(120, 120, 120, 255)
  
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
    color.i
  EndStructure
  
  Structure Text_t Extends Widget_t
    gadget.i
  EndStructure
  
  Structure Explorer_t Extends Widget_t
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
    ix.i
    iy.i
    iw.i
    ih.i
    color.i
  EndStructure
  
  Structure Check_t Extends Widget_t
    check.i
  EndStructure
  
  Structure List_t Extends Widget_t
    gadget.i
  EndStructure
  
  Declare CreateRoot(window.i)
  Declare CreateContainer(*p.Widget_t, x.i, y.i, w.i, h.i, c.b=#False, l=#WIDGET_LAYOUT_VERTICAL)
  Declare CreateButton(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
  Declare CreateIcon(*p.Container_t, icon.s, x.i, y.i, w.i, h.i, c.i)
  Declare CreateText(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
  Declare CreateExplorer(*p.Container_t, x.i, y.i, w.i, h.i)
  Declare CreateString(*p.Container_t, x.i, y.i, w.i, h.i)
  Declare CreateCheck(*p.Container_t, label.s, check.b, x.i, y.i, w.i, h.i)
  Declare CreateList(*p.Container_t, label.s, x.i, y.i, w.i, h.i)
  Declare OnEvent(*widget.Container_t)
  Declare SetLayout(*p.Container_t, layout.i)
  Declare SetCallback(*widget.Widget_t, cb.CallbackFn, *data)
  Declare Resize(*widget.Widget_t, x.i, y.i, w.i, h.i)
  Declare Draw(*widget.Widget_t)
  Declare Callback(*widget.Widget_t)
  Declare GetGadgetId(*widget.Widget_t)
  Declare SetState(*widget.Widget_t, state)
  Declare ClearState(*widget.Widget_t, state)
  Declare ToggleState(*widget.Widget_t, state)
  Declare GetState(*widget.Widget_t, state)
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
      Define rx.i = x - (*widget\x + (*icon\width-*icon\iw)/2)
      Define ry.i = y - (*widget\y + (*icon\height-*icon\ih)/2)
      ProcedureReturn Bool(rx > 0 And rx < *icon\iw And 
                           ry > 0 And ry < *icon\ih)
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
        *widget\items()\state | #WIDGET_STATE_HOVER
        *widget\hovered = *widget\items()
      Else
        *widget\items()\state &~ #WIDGET_STATE_HOVER
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
      Define numItems = ListSize(*container\items())
      ResizeGadget(*container\gadget, x, y, w, h)

      Select *container\layout
        Case #WIDGET_LAYOUT_VERTICAL
          Define nh = h / numItems
          Define cy = 0
          ForEach *container\items()
            If *container\items()\type >= #WIDGET_TYPE_CONTAINER
              Resize(*container\items(),x, cy, w, nh)
            Else
              Resize(*container\items(),
                     #WIDGET_PADDING_X, 
                     cy + #WIDGET_PADDING_Y, 
                     w-2*#WIDGET_PADDING_X, 
                     nh-2*#WIDGET_PADDING_Y)
            EndIf
            cy + nh
          Next
          
        Case #WIDGET_LAYOUT_HORIZONTAL
          Define nw = w / numItems
          Define cx = 0
          Define cy = 0
          ForEach *container\items()
            If *container\items()\type >= #WIDGET_TYPE_CONTAINER
              Resize(*container\items(),cx, y, nw, h)
            Else
              Resize(*container\items(),
                     cx + #WIDGET_PADDING_X, 
                     #WIDGET_PADDING_Y, 
                     nw - 2*#WIDGET_PADDING_X,
                     h-2*#WIDGET_PADDING_Y)
            EndIf
            cx + nw
          Next
      EndSelect
      
    ElseIf *widget\type = #WIDGET_TYPE_TEXT
      Define *text.Text_t = *widget
      ResizeGadget(*text\gadget, x, y, w, h)
      
    ElseIf *widget\type = #WIDGET_TYPE_STRING
      Define *string.String_t = *widget
      ResizeGadget(*string\gadget, x, y, w, h)
      
    ElseIf *widget\type = #WIDGET_TYPE_LIST
      Define *list.List_t = *widget
      ResizeGadget(*list\gadget, x, y, w, h)

    EndIf
    
  EndProcedure
  
  Procedure OnEvent(*widget.Container_t)
    Define event.i = EventType()    
    If event = #PB_EventType_LeftClick
      If *widget\hovered 
        If GetState(*widget\hovered, #WIDGET_STATE_TOGGLE)
          ToggleState(*widget\hovered, Widget::#WIDGET_STATE_ACTIVE)
        EndIf
        
        Callback(*widget\hovered)
      EndIf
      
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
      Debug "we have callback"
      *widget\callback(*widget\data)
      Widget::Resize(*widget\parent, *widget\parent\x, *widget\parent\y, 
                     *widget\parent\width, *widget\parent\height)
    EndIf
  EndProcedure

  Procedure Draw(*widget.Widget_t)
    If *widget\type >= #WIDGET_TYPE_CONTAINER
      Define *container.Container_t = *widget
      Define c = Bool(*container\state & #WIDGET_STATE_CANVAS)
      If c 
        StartVectorDrawing(CanvasVectorOutput(*container\gadget))
        ResetPath()
        AddPathBox(0,0,GadgetWidth(*container\gadget), GadgetHeight(*container\gadget))
        VectorSourceColor(*container\color)
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
          _RoundBoxPath(*widget\x, *widget\y, *widget\width, *widget\height,8)
          Define bx = PathBoundsX()
          Define by = PathBoundsY()
          Define bw = PathBoundsWidth()
          Define bh = PathBoundsHeight()
          
          
          VectorSourceColor(RGBA(55, 55, 55, 122))
          StrokePath(#WIDGET_STROKE_WIDTH, #PB_Path_RoundCorner|#PB_Path_RoundEnd)
          MovePathCursor(*widget\x + *widget\width/2-*icon\iw/2, *widget\y + *widget\height/2-*icon\ih/2, #PB_Path_Relative)

          AddPathSegments(*icon\icon, #PB_Path_Relative )
          
          If Widget::GetState(*icon, #WIDGET_STATE_HOVER)
            VectorSourceColor(RGBA(Red(*icon\color) + 25, Green(*icon\color) + 25, Blue(*icon\color) + 25, 150))
          Else
            VectorSourceColor(RGBA(Red(*icon\color), Green(*icon\color), Blue(*icon\color), 100))
          EndIf

          StrokePath(#WIDGET_STROKE_WIDTH, #PB_Path_RoundCorner|#PB_Path_RoundEnd|#PB_Path_Preserve) 
          
          If Widget::GetState(*icon, #WIDGET_STATE_ACTIVE)
            VectorSourceColor(RGBA(255, 255, 255, 200))
            StrokePath(#WIDGET_STROKE_WIDTH/2, #PB_Path_RoundCorner|#PB_Path_RoundEnd|#PB_Path_Preserve) 
          EndIf
          
          
          VectorSourceColor(*icon\color)
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
          MovePathCursor(*widget\x +(*widget\width - VectorTextWidth(*button\text))/2, 
                         *widget\y + *widget\height/2)
          
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
  
  Procedure SetState(*widget.Widget_t, state)
    *widget\state | state
  EndProcedure
  
  Procedure ClearState(*widget.Widget_t, state)
    *widget\state &~ state
  EndProcedure
   
  Procedure ToggleState(*widget.Widget_t, state)
    *widget\state ! state
  EndProcedure
  
  Procedure GetState(*widget.Widget_t, state)
    ProcedureReturn *widget\state & state
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
    *widget\color = BACKGROUND_COLOR
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateButton(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
     Define *widget.Button_t = AllocateStructure(Button_t)
    _Set(*widget, #WIDGET_TYPE_BUTTON, *p, x, y, w, h)
    _AddItem(*p, *widget)
    *widget\text = text
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateIcon(*p.Container_t, icon.s, x.i, y.i, w.i, h.i, c.i)
    Define *widget.Icon_t = AllocateStructure(Icon_t)
    _Set(*widget, #WIDGET_TYPE_ICON, *p, x, y, w, h)
    _AddItem(*p, *widget)
    *widget\icon= icon
    StartVectorDrawing(CanvasVectorOutput(*p\gadget))
    AddPathSegments(*widget\icon)
    *widget\ix = PathBoundsX()
    *widget\iy = PathBoundsY()
    *widget\iw = PathBoundsWidth()
    *widget\ih = PathBoundsHeight()
    *widget\color  = c
    StopVectorDrawing()
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateText(*p.Container_t, text.s, x.i, y.i, w.i, h.i)
    Define *widget.Text_t = AllocateStructure(Text_t)
    *widget\gadget = TextGadget(#PB_Any, x, y, w, h, text)
    _Set(*widget, #WIDGET_TYPE_TEXT, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateExplorer(*p.Container_t, x.i, y.i, w.i, h.i)
    Define *widget.Explorer_t = AllocateStructure(Explorer_t)
    Define defaultPath.s = "/Users/malartrebenjamin/Documents/RnD/Capture2Gif"
    *widget\gadget = ExplorerComboGadget(#PB_Any, x, y, w, h, defaultPath)
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
  
  Procedure CreateList(*p.Container_t, label.s, x.i, y.i, w.i, h.i)
    Define *widget.List_t = AllocateStructure(List_t)
    *widget\gadget = ListViewGadget(#PB_Any, x, y, w, h)
   

    _Set(*widget, #WIDGET_TYPE_LIST, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure

EndModule

; IDE Options = PureBasic 6.10 beta 1 (Windows - x64)
; CursorPosition = 303
; FirstLine = 236
; Folding = Dc-X4-
; EnableXP