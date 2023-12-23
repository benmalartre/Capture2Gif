;================================================================================================
; IMAGES TO GIF (WINDOWS ONLY)
;================================================================================================
UseGIFImageDecoder()
UseJPEGImageDecoder()
UsePNGImageDecoder()
UseTGAImageDecoder()
UseTIFFImageDecoder()

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
  Define tmp = CreateImage(#PB_Any, width, height, 32)
  StartDrawing(ImageOutput(tmp))
  DrawImage(ImageID(img), 0, 0)
  FlipBuffer(img, *buffer, width, height, ?swap_red_blue_mask)
  AnimatedGif_AddFrame(writer, *buffer)
  FreeImage(img)
Next

AnimatedGif_Term(writer)


FreeMemory(*buffer)


; IDE Options = PureBasic 5.73 LTS (Windows - x64)
; CursorPosition = 7
; FirstLine = 34
; Folding = -
; EnableXP