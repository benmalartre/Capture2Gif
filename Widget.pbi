;------------------------------------------------------------------------------------------------
; WIDGET DECLARATION
;------------------------------------------------------------------------------------------------
DeclareModule Widget
  Enumeration
    #WIDGET_STATE_DEFAULT  = 0
    #WIDGET_STATE_ACTIVE   = 1 << 0
    #WIDGET_STATE_DISABLE  = 1 << 1
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
  
  
  Prototype CallbackFn(*data=#Null)
  
  Structure Widget_t
    name.s
    type.i
    x.i
    y.i
    width.i
    height.i
    gadget.i
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
    layout.i
  EndStructure
  
  Structure Text_t Extends Widget_t
  EndStructure
  
  Structure Explorer_t Extends Widget_t
  EndStructure
  
  Structure String_t Extends Widget_t
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
    image.i
  EndStructure
  
  Structure Check_t Extends Widget_t
    check.i
  EndStructure
  
  Structure List_t Extends Widget_t
  EndStructure
  
  Declare CreateRoot(window.i)
  Declare CreateContainer(*p.Widget_t, name.s, x.i, y.i, w.i, h.i,l=#WIDGET_LAYOUT_VERTICAL)
  Declare CreateButton(*p.Container_t, name.s, text.s, x.i, y.i, w.i, h.i)
  Declare CreateIcon(*p.Container_t, name.s, icon.s, x.i, y.i, w.i, h.i, c.i)
  Declare CreateText(*p.Container_t, name.s, text.s, x.i, y.i, w.i, h.i)
  Declare CreateExplorer(*p.Container_t, name.s, x.i, y.i, w.i, h.i)
  Declare CreateString(*p.Container_t, name.s, value.s, x.i, y.i, w.i, h.i)
  Declare CreateCheck(*p.Container_t, name.s, label.s, check.b, x.i, y.i, w.i, h.i)
  Declare CreateList(*p.Container_t, name.s, label.s, x.i, y.i, w.i, h.i)
  Declare OnEvent(*widget.Container_t)
  Declare SetCallback(*widget.Widget_t, cb.CallbackFn, *data)
  Declare Resize(*widget.Widget_t, x.i, y.i, w.i, h.i)
  Declare Callback(*widget.Widget_t)
  Declare GetGadgetId(*widget.Widget_t)
  Declare SetState(*widget.Widget_t, state)
  Declare ClearState(*widget.Widget_t, state)
  Declare ToggleState(*widget.Widget_t, state)
  Declare GetState(*widget.Widget_t, state)
  Declare GetAbsoluteX(*widget.Widget_t)
  Declare GetAbsoluteY(*widget.Widget_t)
  Declare GetWidgetByName(Map widgets(), name.s)
EndDeclareModule

;------------------------------------------------------------------------------------------------
; WIDGET IMPLEMENTATION
;------------------------------------------------------------------------------------------------
Module Widget
  Procedure _Set(*widget.Widget_t, t.i, name.s, parent.i, x.i, y.i, w.i, h.i)
    *widget\name     = name
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
    ForEach *widget\items()
      If _IsInside(*widget\items(), mouseX, mouseY)
        *widget\items()\state | #WIDGET_STATE_HOVER
      Else
        *widget\items()\state &~ #WIDGET_STATE_HOVER
      EndIf
    Next
    ResetPath()
  EndProcedure
  
  Procedure GetGadgetId(*widget.Widget_t)
    ProcedureReturn *widget\gadget
  EndProcedure
  
  Procedure GetAbsoluteX(*widget.Widget_t)
    Define x = *widget\x
    Define *parent.Widget_t = *widget\parent
    While *parent And *parent\type = #WIDGET_TYPE_CONTAINER
      x + *parent\x
      *parent = *parent\parent
    Wend  
    ProcedureReturn x
  EndProcedure
  
  Procedure GetAbsoluteY(*widget.Widget_t)
    Define y = *widget\y
    Define *parent.Widget_t = *widget\parent
    While *parent And *parent\type = #WIDGET_TYPE_CONTAINER
      y + *parent\y
      *parent = *parent\parent
    Wend  
    ProcedureReturn y
  EndProcedure
  
  Procedure GetWidgetByName(Map widgets.i(), name.s)
    Define *widget.Widget_t
    ForEach widgets()  
      *widget = widgets()
      If *widget\name = name
        ProcedureReturn *widget
      EndIf
    Next
    ProcedureReturn #Null
  EndProcedure
  
  Procedure Resize(*widget.Widget_t, x.i, y.i, w.i, h.i)
    Define oldWidth = *widget\width
    Define oldHeight = *widget\height
    If oldWidth = 0 : oldWIdth = w : EndIf
    If oldHeight = 0 : oldHeight = h : EndIf
    *widget\x = x 
    *widget\y = y
    *widget\width = w
    *widget\height = h
    If *widget\type = #WIDGET_TYPE_CONTAINER
      Define *container.Container_t = *widget
      Define numItems = ListSize(*container\items())
      ResizeGadget(*container\gadget, *widget\x, *widget\y, *widget\width, *widget\height)
      
      If Not numItems : ProcedureReturn : EndIf
      
      Select *container\layout

        Case #WIDGET_LAYOUT_VERTICAL
          
          Define nh
          Define ratio.f
          Define cy = 0
          ForEach *container\items()
            ratio = *container\items()\height / oldHeight
            nh = ratio * *widget\height
            If *container\items()\type >= #WIDGET_TYPE_CONTAINER
              Resize(*container\items(),0, cy, *widget\width, nh)
            Else
              Resize(*container\items(), 0, cy, *widget\width, nh)
            EndIf
            cy + nh
          Next
          
        Case #WIDGET_LAYOUT_HORIZONTAL
          Define cx = 0
          Define nw
          Define ratio.f
          ForEach *container\items()
            ratio = *container\items()\width / oldWidth
            nw = ratio * *widget\width
            If *container\items()\type >= #WIDGET_TYPE_CONTAINER
              Resize(*container\items(),cx, 0, nw, *widget\height)
            Else
              Resize(*container\items(), cx, 0, nw, *widget\height)
            EndIf
            cx + nw
          Next
        
      EndSelect
      
    Else
      ResizeGadget(*widget\gadget, *widget\x, *widget\y, *widget\width, *widget\height)
    EndIf
    
  EndProcedure
  
  Procedure OnEvent(*widget.Widget_t)
    Define event.i = EventType()    
    If event = #PB_EventType_LeftClick

      Callback(*widget)
      
      ToggleState(*widget, Widget::#WIDGET_STATE_ACTIVE)
      
    ElseIf event = #PB_EventType_MouseMove
 
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

  
  Procedure SetState(*widget.Widget_t, state)
    *widget\state | state
  EndProcedure
  
  Procedure ClearState(*widget.Widget_t, state)
    *widget\state &~ state
  EndProcedure
   
  Procedure ToggleState(*widget.Widget_t, state)
    *widget\state ! state
    
    SetGadgetState(*widget\gadget, *widget\state & state)
  EndProcedure
  
  Procedure GetState(*widget.Widget_t, state)
    ProcedureReturn *widget\state & state
  EndProcedure
  
  Procedure CreateRoot(window)
    Define *root.Container_t = AllocateStructure(Container_t)
    Define width = WindowWidth(window, #PB_Window_InnerCoordinate)
    Define height = WindowHeight(window, #PB_Window_InnerCoordinate)
    _Set(*root, #WIDGET_TYPE_CONTAINER, "root", #Null, 0, 0, w, h)
    *root\state = #WIDGET_STATE_ROOT
    *root\gadget = ContainerGadget(#PB_Any, 0, 0, w, h)
    *root\layout = #WIDGET_LAYOUT_VERTICAL
    ProcedureReturn *root
  EndProcedure
  
  Procedure CreateContainer(*p.Widget_t, name.s, x.i, y.i, w.i, h.i, l.i=#WIDGET_LAYOUT_VERTICAL)
    Define *widget.Container_t = AllocateStructure(Container_t)
    _Set(*widget, #WIDGET_TYPE_CONTAINER, name, *p, x, y, w, h)
    _AddItem(*p, *widget)
    *widget\gadget = ContainerGadget(#PB_Any, x, y, w, h)
    *widget\layout = l
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateButton(*p.Container_t, name.s, text.s, x.i, y.i, w.i, h.i)
     Define *widget.Button_t = AllocateStructure(Button_t)
    _Set(*widget, #WIDGET_TYPE_BUTTON, name, *p, x, y, w, h)
    _AddItem(*p, *widget)
    *widget\text = text
    *widget\gadget = ButtonGadget(#PB_Any, x, y, w, h, text)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateIcon(*p.Container_t, name.s, icon.s, x.i, y.i, w.i, h.i, c.i)
    Define *widget.Icon_t = AllocateStructure(Icon_t)
    _Set(*widget, #WIDGET_TYPE_ICON, name, *p, x, y, w, h)
    _AddItem(*p, *widget)
    *widget\icon= icon
    *widget\image = CreateImage(#PB_Any, 32,32, 24, 666);
    *widget\gadget = ButtonImageGadget(#PB_Any, x, y, w, h, ImageID(*widget\image))

    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateText(*p.Container_t, name.s, text.s, x.i, y.i, w.i, h.i)
    Define *widget.Text_t = AllocateStructure(Text_t)
    _Set(*widget, #WIDGET_TYPE_TEXT, name, *p, x, y, w, h)
    _AddItem(*p, *widget)
    *widget\gadget = TextGadget(#PB_Any, x, y, w, h, text)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateExplorer(*p.Container_t, name.s, x.i, y.i, w.i, h.i)
    Define *widget.Explorer_t = AllocateStructure(Explorer_t)
    Define defaultPath.s = "/Users/malartrebenjamin/Documents/RnD/Capture2Gif"
    _Set(*widget, #WIDGET_TYPE_TEXT, name, *p, x, y, w, h)
    _AddItem(*p, *widget)
    *widget\gadget = ExplorerComboGadget(#PB_Any, x, y, w, h, defaultPath)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateString(*p.Container_t, name.s, value.s, x.i, y.i, w.i, h.i)
    Define *widget.String_t = AllocateStructure(String_t)
    *widget\gadget = StringGadget(#PB_Any, x, y, w, h, value)
    _Set(*widget, #WIDGET_TYPE_STRING, name, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateCheck(*p.Container_t, name.s, label.s, check.b, x.i, y.i, w.i, h.i)
    Define *widget.Check_t = AllocateStructure(Check_t)
    *widget\check = 0;CheckBoxGadget(#PB_Any, x, y, w, h, label)
    _Set(*widget, #WIDGET_TYPE_CHECK, name, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure
  
  Procedure CreateList(*p.Container_t, name.s, label.s, x.i, y.i, w.i, h.i)
    Define *widget.List_t = AllocateStructure(List_t)
    *widget\gadget = ListViewGadget(#PB_Any, x, y, w, h)
    _Set(*widget, #WIDGET_TYPE_LIST, name, *p, x, y, w, h)
    _AddItem(*p, *widget)
    ProcedureReturn *widget
  EndProcedure

EndModule

; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 238
; FirstLine = 201
; Folding = X0----
; EnableXP