program AegysServer;

uses
  Vcl.Forms,
  Windows,
  uPrincipalVCL in 'uPrincipalVCL.pas' {fServerControl},
  uUtilServer in 'uUtilServer.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

Var
 MutexHandle : THandle;

begin
 MutexHandle := CreateMutex(nil, True, 'AegysServer');
 If MutexHandle <> 0 Then
  Begin
   If GetLastError = ERROR_ALREADY_EXISTS Then
    Begin
     MessageBox(0, 'O Aegys - Server j� est� em execu��o!', 'Informa��o !', mb_IconHand);
     CloseHandle(MutexHandle);
     Exit;
    End;
  End;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('TabletDark');
  Application.Title := 'Servidor de Controle dos Acessos Remotos';
  Application.CreateForm(TfServerControl, fServerControl);
  Application.Run;
end.
