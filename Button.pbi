;================================================================================================
; IMAGES TO GIF (WINDOWS ONLY)
;================================================================================================
UseGIFImageDecoder()
UseJPEGImageDecoder()
UsePNGImageDecoder()
UseTGAImageDecoder()
UseTIFFImageDecoder()

Structure Mask_t
  b.a[16]
EndStructure

DataSection
  swap_red_blue_mask:
  Data.a 2,1,0,3,6,5,4,7,10,9,8,11,14,13,12,15
EndDataSection

;------------------------------------------------------------------------------------------------
; IMPORT C FUNCTIONS
;------------------------------------------------------------------------------------------------
ImportC "gif.lib"
  AnimatedGif_Init(filename.p-utf8, width.l, height.l, delay.i)
  AnimatedGif_Term(*writer)
  AnimatedGif_AddFrame(*writer, *datas)
EndImport


Procedure GetNumBytesPerPixels(format.i)
  
  If format & #PB_PixelFormat_ReversedY 
    Debug "Les lignes sont inversées en hauteur !"
  Else
    Debug "Les lignes ne sont pas inversées en hauteur !"
  EndIf 
  
  If format & #PB_PixelFormat_8Bits 
    Debug "8 bits (1 octet par pixel, palettisé)"
    ProcedureReturn 1
  ElseIf format & #PB_PixelFormat_16Bits
    Debug "16 bits (2 octets par pixel)"
    ProcedureReturn 2
  ElseIf format & #PB_PixelFormat_24Bits_RGB
    Debug "24 bits (3 octets par pixel (RRGGBB))"
     ProcedureReturn 3
  ElseIf format & #PB_PixelFormat_24Bits_BGR
    Debug "24 bits (3 octets par pixel (BBGGRR))"
     ProcedureReturn 3
  ElseIf format & #PB_PixelFormat_32Bits_RGB  
    Debug "32 bits (4 octets par pixel (RRGGBB))"
     ProcedureReturn 4
  ElseIf format & #PB_PixelFormat_32Bits_BGR
    Debug "32 bits (4 octets par pixel (BBGGRR))"
     ProcedureReturn 4
  EndIf
 
EndProcedure

Procedure FlipBuffer(img.i, *buffer, width.i, height.i, *m.Mask_t)
  Define tmp = CreateImage(#PB_Any, width, height, 32)
  StartDrawing(ImageOutput(tmp))
  DrawImage(ImageID(img), 0, 0)
  
  Define *input = DrawingBuffer()
  Define *output = *buffer
  Define num_pixels_in_row.i = width
  Define num_rows.i = height
  Define num_bytes.i = GetNumBytesPerPixels(DrawingBufferPixelFormat())
  Define offset_bytes.i = num_bytes * 4
    
  Define *mask = *m
  ! mov rsi, [p.p_input]                ; input buffer to rsi register
  ! mov rdi, [p.p_output]               ; output buffer to rdi register
  ! mov eax, [p.v_num_pixels_in_row]    ; image width in rax register
  ! mov ecx, [p.v_num_rows]             ; image height in rcx register
  ! mov r10, [p.p_mask]                 ; load mask in r10 register
  ! mov r8, [p.v_num_bytes]             ; load num bytes in r11 register
  ! mov r9, [p.v_offset_bytes]         ; load offset bytes in r12 register
  ! mov r15, rax                        ; num pixels in a row
  ! imul r15, r8                        ; size of a row of pixels
  ! movups xmm1, [r10]                  ; load mask in xmm1 register
  
  ! loop_over_rows:
  !   mov r11, rax                      ; reset pixels counter
  !   mov r13, rcx                      ; as we reverse iterate
  !   sub r13, 1                        ; we need the previous row
  !   imul r13, r15                     ; address of current pixel
  !   mov r14, rsi                      ; load input buffer in r14 register
  !   add r14, r13                      ; offset to current pixel
  
  ! loop_over_pixels:
  !   movups xmm0, [r14]                ; load pixel to xmm0
  !   pshufb xmm0, xmm1                 ; shuffle bytes with mask
  !   movups [rdi], xmm0                ; set fixed color to output ptr
  !   add r14, r9                       ; advance input ptr
  !   add rdi, r9                       ; advance output ptr
  !   sub r11, r8                        ; decrement pixel counter
  !   jg loop_over_pixels               ; loop next pixel
  
  ! next_row:
  !   dec rcx                           ; decrement row counter
  !   jg loop_over_rows                 ; loop next row
  StopDrawing()
EndProcedure

Procedure GetImages(path.s, List images.s())
  Define folder.i = ExamineDirectory(#PB_Any, path, "*")

  While NextDirectoryEntry(folder)
    If DirectoryEntryType(folder) = #PB_DirectoryEntry_File
      Define image = LoadImage(#PB_Any, path + "/" + DirectoryEntryName(folder))
      If IsImage(image)
        AddElement(images())
        images() = path + "/" + DirectoryEntryName(folder)
        FreeImage(image)
      EndIf
    EndIf
  Wend
  FinishDirectory(folder)
  SortList(images(),#PB_Sort_Ascending )
EndProcedure


Define i
; Define folder.s = "D:/Photos/ToGIFs/DoYouEarMe"
; Define name.s = "DoYouEarMe"
Define folder.s = "D:/Photos/ToGIFs/CousyTower"
Define name.s = "CousyTower"
Define delay.i = 16

NewList images.s()

GetImages(folder, images())

If Not ListSize(images())
  MessageRequester("Error", "No images found in desired folder")
  End  
EndIf

FirstElement(images())
Define image = LoadImage(#PB_Any, images())
Define width = ImageWidth(image)
Define height = ImageHeight(image)

Debug Str(width) + "," + Str(height)

Define *buffer = AllocateMemory(width * height * 4)
Define writer = AnimatedGif_Init( folder+"/"+name+".gif", width, height, delay)

ForEach images()
  Debug images()
  Define img = LoadImage(#PB_Any, images())
  FlipBuffer(img, *buffer, width, height, ?swap_red_blue_mask)
  AnimatedGif_AddFrame(writer, *buffer)
  FreeImage(img)
Next

AnimatedGif_Term(writer)


FreeMemory(*buffer)


; IDE Options = PureBasic 5.73 LTS (Windows - x64)
; CursorPosition = 162
; FirstLine = 106
; Folding = -
; EnableXP