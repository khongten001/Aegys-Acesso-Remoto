﻿unit StreamManager;

{
   Aegys Remote Access Project.
  Criado por XyberX (Gilbero Rocha da Silva), o Aegys Remote Access Project tem como objetivo o uso de Acesso remoto
  Gratuito para utilização de pessoas em geral.
   O Aegys Remote Access Project tem como desenvolvedores e mantedores hoje

  Membros do Grupo :

  XyberX (Gilberto Rocha)    - Admin - Criador e Administrador  do pacote.
  Wendel Fassarela           - Devel and Admin
  Mobius One                 - Devel, Tester and Admin.
  Gustavo                    - Devel and Admin.
  Roniery                    - Devel and Admin.
  Alexandre Abbade           - Devel and Admin.
  e Outros como você, venha participar também.
}

interface

uses
  System.Classes,
  System.Types,
  FMX.Forms,
//  Execute.DesktopDuplicationAPI,
  FMX.Objects
  ,Vcl.Graphics
  ,Winapi.Windows
  ,Vcl.Forms
  , uAegysBufferPack,
  ActiveX,
  FMX.Graphics,
  FMX.Surfaces;

Const
 TNeutroColor     = 255;
 cJPGQual         = 25;
 cCompressionData = True;

Type
 TCaptureScreenProc = Function : TStream;

Var
 aFullBmp          : Vcl.Graphics.TBitmap;
 DllHandle         : THandle;
 CaptureScreenProc : TCaptureScreenProc = Nil;
 aConnection       : String;

procedure GetScreenToMemoryStream(Var aPackClass     : TPackClass;
                                  DrawCur            : Boolean;
                                  PixelFormat        : TPixelFormat = pf16bit;
                                  Monitor            : String       = '0';
                                  FullFrame          : Boolean      = False);

implementation

uses
  System.SysUtils, uAegysZlib, uAegysDataTypes;

Procedure DrawScreenCursor(Var Bmp: Vcl.Graphics.TBitmap; const MonitorID: Integer);
Var
 R          : TRect;
 CursorInfo : TCursorInfo;
 Left,
 Top        : Integer;
 Icon       : TIcon;
 IconInfo   : TIconInfo;
Begin
 R    := Bmp.Canvas.ClipRect;
 Icon := TIcon.Create;
 Try
  CursorInfo.cbSize := SizeOf(CursorInfo);
  If GetCursorInfo(CursorInfo) Then
   If CursorInfo.Flags = CURSOR_SHOWING Then
    Begin
     Icon.Handle:= CopyIcon(CursorInfo.hCursor);
     If GetIconInfo(Icon.Handle, IconInfo) Then
      Begin
       If CursorInfo.ptScreenPos.x > Screen.Monitors[MonitorID].Left Then
        Left := CursorInfo.ptScreenPos.x - Screen.Monitors[MonitorID].Left
       Else
        Left := CursorInfo.ptScreenPos.x;
       If CursorInfo.ptScreenPos.y > Screen.Monitors[MonitorID].Top  Then
        Top  := CursorInfo.ptScreenPos.y - Screen.Monitors[MonitorID].Top
       Else
        Top  := CursorInfo.ptScreenPos.y;
       Bmp.Canvas.Draw(Left - Integer(IconInfo.xHotspot) - R.Left,
                       Top  - Integer(IconInfo.yHotspot) - R.Top,
                       Icon);
      End;
    End;
 Finally
  Icon.Free;
 End;
End;

procedure GetScreenToMemoryStream(Var aPackClass     : TPackClass;
                                  DrawCur            : Boolean;
                                  PixelFormat        : TPixelFormat = pf16bit;
                                  Monitor            : String       = '0';
                                  FullFrame          : Boolean      = False);
Var
  aFinalBytes        : TAegysBytes;
  vMonitor           : Integer;
  aMonitor,
  aResolution        : String;
  TargetMemoryStream : TStream;
Begin
 aPackClass := Nil;
 vMonitor   := StrToInt(Monitor) +1;
 aMonitor   := IntToStr(FMX.Forms.Screen.DisplayCount);
 If (vMonitor > FMX.Forms.Screen.DisplayCount) then
  Exit;
 vMonitor := vMonitor -1;
 aResolution := Format('%s&%s&%s', [FloatToStr(Screen.Monitors[vMonitor].Height), FloatToStr(Screen.Monitors[vMonitor].Width), aMonitor]);
 Try
  Application.ProcessMessages;
  TargetMemoryStream := CaptureScreenProc;
 Finally
  Application.ProcessMessages;
 End;
 If Assigned(TargetMemoryStream) Then
  Begin
   TargetMemoryStream.Position := 0;
   If TargetMemoryStream.Size > 0 then
    Begin
     If cCompressionData Then
      ZCompressStreamBytes(TargetMemoryStream, aFinalBytes)
     Else
      Begin
       SetLength(aFinalBytes, TargetMemoryStream.Size);
       TargetMemoryStream.Read(aFinalBytes[0], Length(aFinalBytes));
      End;
     FreeAndNil(TargetMemoryStream);
     aPackClass               := TPackClass.Create;
     Try
      aPackClass.DataCheck    := tdcAsync;
      aPackClass.DataSize     := Length(aFinalBytes);
      aPackClass.ProxyToMyConnectionList := True;
      aPackClass.BufferSize   := aPackClass.DataSize;
      aPackClass.PacksGeral   := 0;
      aPackClass.PackNo       := 0;
      aPackClass.DataMode     := tdmClientCommand;
      aPackClass.DataType     := tdtDataBytes;
      aPackClass.CommandType  := tctScreenCapture;
      aPackClass.DataBytes    := aFinalBytes;
      SetLength(aFinalBytes, 0);
      aPackClass.BytesOptions := aResolution;
      aPackClass.Owner        := aConnection;
      aPackClass.Dest         := '';
     Finally
     End;
    End
   Else
    FreeAndNil(TargetMemoryStream);
  End;
End;

Initialization
 aFullBmp     := Vcl.Graphics.TBitmap.Create;
 DllHandle := LoadLibrary('AegysData.dll');
 If DllHandle > 0 Then
  @CaptureScreenProc := GetProcAddress(DllHandle, 'CaptureScreen');

Finalization
 FreeAndNil(aFullBmp);
 If DLLHandle <> 0 Then
  FreeLibrary(DLLHandle);

End.

