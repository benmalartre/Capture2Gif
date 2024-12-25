;========================================================================================
; Memory Module Declaration
;========================================================================================
DeclareModule Memory

  #ALIGN_BITS =  16
  
  Macro AlignMemory(_memory, _alignment)
    (_memory + (_alignment - _memory % _alignment))
  EndMacro
  
  Declare AllocateAlignedMemory(size.i)
  Declare ReAllocateAlignedMemory(*memory, oldsize.i, size.i)
  Declare FreeAlignedMemory(*memory, size.i)
  Declare ShiftAlign(*data, nb.i, src_size, dst_size.i)
  Declare UnshiftAlign(*data, nb.i, src_size, dst_size.i)
  
EndDeclareModule

;========================================================================================
; Memory Module Implementation
;========================================================================================
Module Memory
  ;--------------------------------------------------------------------------------------
  ; ALLOCATE ALIGNED MEMORY
  ;--------------------------------------------------------------------------------------
  Procedure AllocateAlignedMemory(size.i)
    Protected *memory = AllocateMemory(size + #ALIGN_BITS)
    Protected *aligned
    Define offset.i = *memory % #ALIGN_BITS
    If offset <> 0
      *aligned = AlignMemory(*memory, #ALIGN_BITS)
      PokeB(*aligned + size + 1, #ALIGN_BITS - offset)
    Else
      *aligned = *memory
      PokeB(*aligned + size + 1, 0)
    EndIf
    
    ProcedureReturn *aligned
  EndProcedure
  
  ;--------------------------------------------------------------------------------------
  ; REALLOCATE ALIGNED MEMORY
  ;--------------------------------------------------------------------------------------
  Procedure ReAllocateAlignedMemory(*memory, oldsize.i, size.i)
    *memory = ReAllocateMemory(*memory - PeekB(*memory + oldsize + 1), size + #ALIGN_BITS, #PB_Memory_NoClear)
    Protected *aligned
    Protected offset.i = *memory % #ALIGN_BITS
    If offset <> 0
      *aligned = AlignMemory(*memory, #ALIGN_BITS)
      PokeB(*aligned + size + 1, #ALIGN_BITS - offset)
    Else
      *aligned = *memory
      PokeB(*aligned + size + 1, 0)
    EndIf

    ProcedureReturn *aligned 
  EndProcedure
  
  ;--------------------------------------------------------------------------------------
  ; FREE ALIGNED MEMORY
  ;--------------------------------------------------------------------------------------
  Procedure FreeAlignedMemory(*memory, size.i)
    FreeMemory(*memory - PeekB(*memory + size + 1))
  EndProcedure
  
  ;--------------------------------------------------------------------------------------
  ; Shift Align
  ;--------------------------------------------------------------------------------------
  Procedure ShiftAlign(*data, nb.i, src_size, dst_size.i)
    If dst_size > src_size
      Define offset_dst = (nb-1) * dst_size
      Define offset_src = (nb-1) * src_size
      
      Define *src, *dst
      While nb >= 0
        *src = *data + offset_src
        *dst = *data + offset_dst
        MoveMemory(*src, *dst, src_size)
        FillMemory(*dst + src_size, dst_size-src_size, 0)
        offset_dst - dst_size
        offset_src - src_size
        nb - 1  
      Wend
    EndIf
  EndProcedure
  
  ;--------------------------------------------------------------------------------------
  ; Unshift Align
  ;--------------------------------------------------------------------------------------
  Procedure UnshiftAlign(*data, nb.i, src_size, dst_size.i)
    If dst_size < src_size
      Define *src, *dst
      Define i
      For i=1 To nb-1
        *src = *data + i * src_size
        *dst = *data + i * dst_size
        MoveMemory(*src, *dst, src_size)
      Next
      FillMemory(*data + nb * dst_size, nb * src_size - nb * dst_size, 0)
    EndIf
  EndProcedure
  
EndModule
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 63
; FirstLine = 41
; Folding = --
; EnableXP