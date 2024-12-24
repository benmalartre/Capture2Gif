;------------------------------------------------------------------------------------------------
; PREFERENCES MODULE DECLARATION
;------------------------------------------------------------------------------------------------
DeclareModule Prefs
  Structure Prefs_t
    filename.s
  EndStructure
  
  Declare Init(*prefs.Prefs_t, name.s="prefs.pref")
  Declare GetInt(*prefs.Prefs_t, group.s, key.s, defaultValue.i)
  Declare.s GetString(*prefs.Prefs_t, group.s, key.s, defaultValue.s)
  Declare SetInt(*prefs.Prefs_t, group.s, key.s, value.i)
  Declare SetString(*prefs.Prefs_t, group.s, key.s, value.s)
EndDeclareModule

;------------------------------------------------------------------------------------------------
; PREFERENCES MODULE IMPLEMENTATION
;------------------------------------------------------------------------------------------------
Module Prefs
  Procedure Init(*prefs.Prefs_t, name.s="prefs.pref");, Map defaultValues.Group_t())
    *prefs\filename = name
    If OpenPreferences(*prefs\filename )
      
      ExaminePreferenceGroups()
      ; For each group
      While NextPreferenceGroup()
        text$ = text$ + PreferenceGroupName() + #LF$ ; its name
        ; Examine keys for the current group  
        ExaminePreferenceKeys()
        ; For each key  
        While  NextPreferenceKey()                      
          text$ = text$ + PreferenceKeyName() + " = " + PreferenceKeyValue() + #LF$ ; its name and its data
        Wend
        text$ = text$ + #LF$
        Debug text$
      Wend
      ClosePreferences()
      ProcedureReturn #True
    Else
      Define file = CreateFile(#PB_Any, *prefs\filename )
      CloseFile(file)
      ProcedureReturn #False
    EndIf  
    
  EndProcedure
  
  Procedure.i GetInt(*prefs.Prefs_t, group.s, key.s, defaultValue.i)
    OpenPreferences(*prefs\filename)
    If group <> "" : PreferenceGroup(group) : EndIf
    Define result.i = ReadPreferenceInteger(key.s, defaultValue)
    ClosePreferences()
    ProcedureReturn result
  EndProcedure
  
  Procedure.s GetString(*prefs.Prefs_t, group.s, key.s, defaultValue.s)
    
    OpenPreferences(*prefs\filename)
    If group <> "" : PreferenceGroup(group) : EndIf
    Define result.s = ReadPreferenceString(key.s, defaultValue)
    ClosePreferences()
    ProcedureReturn result
  EndProcedure
  
  Procedure SetInt(*prefs.Prefs_t, group.s, key.s, value.i)
    OpenPreferences(*prefs\filename)
    If group <> "" : PreferenceGroup(group) : EndIf
    WritePreferenceInteger(key, value)
    ClosePreferences()
  EndProcedure
  
  Procedure SetString(*prefs.Prefs_t, group.s, key.s, value.s)
    OpenPreferences(*prefs\filename)
    If group <> "" : PreferenceGroup(group) : EndIf
    WritePreferenceString(key, value)
    ClosePreferences()
  EndProcedure
  
EndModule

; ; Open a preference file
;   
;   ; Examine Groups
;   ExaminePreferenceGroups()
;   ; For each group
;   While NextPreferenceGroup()
;     text$ = text$ + PreferenceGroupName() + #LF$ ; its name
;     ; Examine keys for the current group  
;     ExaminePreferenceKeys()
;     ; For each key  
;     While  NextPreferenceKey()                      
;       text$ = text$ + PreferenceKeyName() + " = " + PreferenceKeyValue() + #LF$ ; its name and its data
;     Wend
;     text$ = text$ + #LF$
;   Wend
; 
;   ; Display all groups and all keys with datas
;   MessageRequester("test.pref", text$)
; 
;   ; Close the preference file
;   ClosePreferences()    
; IDE Options = PureBasic 6.00 Beta 7 - C Backend (MacOS X - arm64)
; CursorPosition = 8
; FirstLine = 35
; Folding = --
; EnableXP