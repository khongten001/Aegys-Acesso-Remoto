unit uAegysThreads;

{$I ..\Includes\uAegys.inc}

{
   Aegys Remote Access Project.
  Criado por XyberX (Gilbero Rocha da Silva), o Aegys Remote Access Project tem como objetivo o uso de Acesso remoto
  Gratuito para utiliza��o de pessoas em geral.
   O Aegys Remote Access Project tem como desenvolvedores e mantedores hoje

  Membros do Grupo :

  XyberX (Gilberto Rocha)    - Admin - Criador e Administrador  do pacote.
  Wendel Fassarela           - Devel and Admin
  Mobius One                 - Devel, Tester and Admin.
  Gustavo                    - Devel and Admin.
  Roniery                    - Devel and Admin.
  Alexandre Abbade           - Devel and Admin.
  e Outros como voc�, venha participar tamb�m.
}

Interface

Uses
 SysUtils, Classes, Variants,
 {$IFDEF MSWINDOWS}
    Windows,
 {$ENDIF}
 {$IFDEF FPC}
  Forms,
 {$ELSE}
  {$IF DEFINED(HAS_FMX)}
   {$IF NOT(DEFINED(ANDROID)) and NOT(DEFINED(IOS))}
     FMX.Forms,
   {$IFEND}
  {$ELSE}
     vcl.Forms,
  {$IFEND}
 {$ENDIF}
 uAegysBufferPack, uAegysConsts,
 uAegysDataTypes;

Type
 TOnBeforeExecuteData  = Procedure (Var aPackList   : TPackList)   Of Object;
 TOnActionRequest      = Procedure (aType           : Char)        Of Object;
 TOnDisconnect         = Procedure (Sender          : TObject)     Of Object;
 TOnExecuteData        = Procedure (Var aPackList   : TPackList;
                                    aPackNo         : AeInt64)     Of Object;
 TOnDataReceive        = Procedure (aData           : TAegysBytes) Of Object;
 TOnAbortData          = Procedure                                 Of Object;
 TOnThreadRequestError = Procedure (ErrorCode       : Integer;
                                    MessageError    : String)      Of Object;
 TOnServiceCommands    = Procedure (InternalCommand : TInternalCommand;
                                    Command         : String)      Of Object;
 TOnClientCommands     = Procedure (CommandType     : TCommandType;
                                    Connection,
                                    ID,
                                    Command         : String;
                                    MultiPack       : Boolean;
                                    PackCount       : AeInteger;
                                    aBuf            : TAegysBytes) Of Object;

Type
 TAegysThread = Class(TThread)
 Protected
  Procedure ProcessMessages;
  Procedure Execute;Override;
 Private
  pPackList                               : PPackList;
  pAegysClient                            : TComponent;
  vDelayThread                            : Integer;
  vOnBeforeExecuteData                    : TOnBeforeExecuteData;
  vOnDataReceive                          : TOnDataReceive;
  vOnExecuteData                          : TOnExecuteData;
  vAbortData                              : TOnAbortData;
  vOnThreadRequestError                   : TOnThreadRequestError;
  vOnCheckDisconnect                      : TOnActionRequest;
  vOnServiceCommands                      : TOnServiceCommands;
  vOnClientCommands                       : TOnClientCommands;
  vOnDisconnect                           : TOnDisconnect;
  abInternalCommand                       : TInternalCommand;
  abCommandType                           : TCommandType;
  abPackCount,
  abPackNo                                : Integer;
  abMultiPack                             : Boolean;
  abConnection,
  abOwner,
  abID,
  abCommand                               : String;
  abBuf                                   : TAegysBytes;
  Procedure ServiceCommands;
  Procedure ClientCommands;
  Procedure ExecuteData;
 Public
  Procedure   Kill;
  Destructor  Destroy; Override;
  Constructor Create(Var aPackList        : TPackList;
                     Var aAegysClient     : TComponent;
                     aDelayThread         : Integer;
                     OnBeforeExecuteData  : TOnBeforeExecuteData;
                     OnDataReceive        : TOnDataReceive;
                     OnExecuteData        : TOnExecuteData;
                     OnAbortData          : TOnAbortData;
                     OnServiceCommands    : TOnServiceCommands;
                     OnClientCommands     : TOnClientCommands;
                     OnThreadRequestError : TOnThreadRequestError;
                     OnCheckDisconnect    : TOnActionRequest;
                     OnDisconnect         : TOnDisconnect);
End;

Implementation

Uses uAegysBase, uAegysTools;

Procedure TAegysThread.ProcessMessages;
Begin
 {$IFNDEF FPC}
   {$IF NOT(DEFINED(ANDROID)) and NOT(DEFINED(IOS))}
     Application.ProcessMessages;
   {$IFEND}
 {$ENDIF}
End;

Destructor TAegysThread.Destroy;
Begin
 Inherited;
End;

Constructor TAegysThread.Create(Var aPackList        : TPackList;
                                Var aAegysClient     : TComponent;
                                aDelayThread         : Integer;
                                OnBeforeExecuteData  : TOnBeforeExecuteData;
                                OnDataReceive        : TOnDataReceive;
                                OnExecuteData        : TOnExecuteData;
                                OnAbortData          : TOnAbortData;
                                OnServiceCommands    : TOnServiceCommands;
                                OnClientCommands     : TOnClientCommands;
                                OnThreadRequestError : TOnThreadRequestError;
                                OnCheckDisconnect    : TOnActionRequest;
                                OnDisconnect         : TOnDisconnect);
Begin
 If Not Assigned(aPackList) Then
  Begin
   Raise Exception.Create(cPackListNotAssigned);
   Exit;
  End;
 Inherited Create(False);
 vDelayThread          := aDelayThread;
 pPackList             := @aPackList;
 pAegysClient          := aAegysClient;
 vOnExecuteData        := OnExecuteData;
 vAbortData            := OnAbortData;
 vOnThreadRequestError := OnThreadRequestError;
 vOnBeforeExecuteData  := OnBeforeExecuteData;
 vOnDataReceive        := OnDataReceive;
 vOnServiceCommands    := OnServiceCommands;
 vOnClientCommands     := OnClientCommands;
 vOnCheckDisconnect    := OnCheckDisconnect;
 vOnDisconnect         := OnDisconnect;
 {$IFNDEF FPC}
  {$IF Defined(HAS_FMX)}
   {$IF Not Defined(HAS_UTF8)}
    Priority           := tpLowest;
   {$IFEND}
  {$ELSE}
   Priority            := tpLowest;
  {$IFEND}
 {$ELSE}
  Priority             := tpLowest;
 {$ENDIF}
End;

Procedure TAegysThread.ServiceCommands;
Begin
// Processmessages;
 If Assigned(vOnServiceCommands) Then
  vOnServiceCommands(abInternalCommand, abCommand);
End;

Procedure TAegysThread.ClientCommands;
Begin
// Processmessages;
 If Assigned(vOnClientCommands) Then
  vOnClientCommands(abCommandType, abOwner, abID, abCommand, abMultiPack, abPackCount, abBuf)
 Else If Assigned(vOnDataReceive) Then
  vOnDataReceive(abBuf);
End;

Procedure TAegysThread.ExecuteData;
Begin
// Processmessages;
 If Assigned(vOnExecuteData)     Then
  vOnExecuteData(pPackList^, abPackno);
End;

Procedure TAegysThread.Execute;
Type
 TThreadDirection     = (ttdReceive, ttdSend);
 TDirectThreadAction  = Array[0..Integer(High(TThreadDirection))] of Boolean;
Var
 ArrayOfPointer     : TArrayOfPointer;
 A, I               : AeInteger;
 vPackno            : AeInt64;
 bBuf,
 aBuf               : TAegysBytes;
 aPackClass         : TPackClass;
 aPackList          : TPackList;
 vInternalC         : Boolean;
 vBytesOptions,
 vOwner,
 vID,
 vCommand           : String;
 vInternalCommand   : TInternalCommand;
 DirectThreadAction : TDirectThreadAction;
 Procedure ParseLogin(aValue : String);
 Var
  vDataC,
  vID,
  vPWD    : String;
 Begin
  vDataC := Copy(aValue, 1, Pos('&', aValue) -1);
  Delete(aValue, 1, Pos('&', aValue));
  vID    := Copy(aValue, 1, Pos('&', aValue) -1);
  Delete(aValue, 1, Pos('&', aValue));
  If Pos('&', aValue) > 0 Then
   vPWD  := Copy(aValue, 1, Pos('&', aValue) -1)
  Else
   vPWD  := aValue;
  TAegysClient(pAegysClient).SetSessionData(vDataC, vID, vPWD);
 End;
 Procedure BeginActions;
 Var
  X : Integer;
 Begin
  For x := 0 To High(DirectThreadAction) Do
   DirectThreadAction[x] := False;
 End;
Begin
 vPackno   := -1;
 aPackList := TPackList.Create;
 SetLength(bBuf, 0);
 BeginActions;
 While (Not(Terminated)) Do
  Begin
   Try
    Try
     If Not DirectThreadAction[Integer(ttdReceive)] Then
      Begin
       DirectThreadAction[Integer(ttdReceive)] := True;
       Processmessages;
       //Process Before Execute one Pack
       If Assigned(vOnBeforeExecuteData) Then
        vOnBeforeExecuteData(aPackList);
       If aPackList.Count > 0 Then
        Begin
         vInternalC := False;
         aPackClass := aPackList.Items[0];
         If aPackClass.DataType = tdtString Then
          Begin
           vInternalC := True;
           vCommand   := aPackClass.Command;
           ParseCommand(vCommand, vInternalCommand);
           If (aPackClass.CommandType  = tctNone) And
              (vInternalCommand       <> ticNone) Then
            Begin
             If vInternalCommand in [ticLogin,
                                     ticDataStatus] Then
              ParseLogin(vCommand);
             abInternalCommand := vInternalCommand;
             abCommand         := vCommand;
             ServiceCommands;
             Processmessages;
            End
           Else
            Begin
             ArrayOfPointer := [@vOwner, @vID];
             If Not (aPackClass.CommandType in [tctKeyboard, tctMouse]) Then
              ParseValues(vCommand, ArrayOfPointer);
             If (aPackClass.CommandType <> tctNone) Then
              Begin
               abInternalCommand := vInternalCommand;
               abCommand         := vCommand;
               abCommandType     := aPackClass.CommandType;
               abOwner           := vOwner;
               abID              := vID;
               abBuf             := bBuf;
               abMultiPack       := aPackClass.PacksGeral > 0;
               abPackCount       := aPackClass.PacksGeral;
               Try
                ClientCommands;
                Processmessages;
               Finally
                SetLength(abBuf, 0);
               End;
              End;
            End;
           If vInternalC Then
            aPackList.Delete(0);
          End;
         If Not vInternalC Then
          Begin
           aBuf := aPackClass.DataBytes;
           Try
            vBytesOptions  := aPackClass.BytesOptions;
            If (aPackClass.CommandType in [tctScreenCapture,  tctMonitor,
                                           tctAudio,          tctVideo]) Then
             Begin
              vOwner := aPackClass.Owner;
              vId    := aPackClass.Dest;
             End
            Else
             Begin
              ArrayOfPointer := [@vOwner, @vID];
              ParseValues(vBytesOptions, ArrayOfPointer);
             End;
            If (aPackClass.CommandType <> tctNone) Then
             Begin
              abInternalCommand := vInternalCommand;
              abCommand         := vBytesOptions;
              abCommandType     := aPackClass.CommandType;
              abOwner           := vOwner;
              abID              := vID;
              abBuf             := aBuf;
              abMultiPack       := aPackClass.PacksGeral > 0;
              abPackCount       := aPackClass.PacksGeral;
              Try
               ClientCommands;
               Processmessages;
              Finally
               SetLength(abBuf, 0);
              End;
             End;
           Finally
            aPackList.Delete(0);
            SetLength(aBuf, 0);
           End;
          End;
        End
       Else
        Begin
         If Assigned(vOnCheckDisconnect) Then
          vOnCheckDisconnect('R');
        End;
       DirectThreadAction[Integer(ttdReceive)] := False;
      End;
     If Not DirectThreadAction[Integer(ttdSend)] Then
      Begin
       DirectThreadAction[Integer(ttdSend)] := True;
       Processmessages;
       //Try Process one Pack
       vPackno := 0;
       If (pPackList^.Count > 0)         And
          (vPackno > -1)                 Then
        Begin
         A := pPackList^.Count -1;
         For I := A Downto 0 Do
          Begin
           If Terminated Then
            Break;
           vPackno  := A - I;
           abPackno := vPackno;
           ExecuteData;
          End;
        End
       Else
        Begin
         If Assigned(vOnCheckDisconnect) Then
          vOnCheckDisconnect('S');
        End;
       DirectThreadAction[Integer(ttdSend)] := False;
      End;
    Finally
     Processmessages;
    End;
   Except
    On E : Exception Do
     Begin
      If Assigned(vOnThreadRequestError) Then
       vOnThreadRequestError(500, E.Message);
      Processmessages;
      If Not Assigned(TAegysClient(pAegysClient)) Then
       Break;
      If E.Message = cSocketDisconnected Then
       Begin
        Terminate;
        If Assigned(vOnDisconnect) Then
         vOnDisconnect(TAegysClient(pAegysClient));
        Continue;
       End;
     End;
   End;
   //Delay Processor
   Processmessages;
   If vDelayThread > 0 Then
    Sleep(vDelayThread);
  End;
 FreeAndNil(aPackList);
End;

Procedure TAegysThread.Kill;
Begin
 Terminate;
 Processmessages;
 If Assigned(vAbortData) Then
  vAbortData;
 If Assigned(vOnThreadRequestError) Then
  vOnThreadRequestError(499, cThreadCancel);
End;

End.
