﻿unit StreamManager;

interface

uses
  Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, System.SysUtils, Forms, Windows, Classes, Graphics,
  Soap.EncdDecd, System.NetEncoding, uScanlineComparer;

Const
 TCompressionJPG   = 10;
 CompareFromDelphi = False;

Type
 TRGBArray   = ARRAY[0..32767] OF TRGBTriple;
 pRGBArray   = ^TRGBArray;
 TImageViewQ = (tiv_MonoC = Integer(pf1Bit), tiv_Medium = Integer(pf8Bit), tiv_Alta = Integer(pf15Bit), tiv_Real = Integer(pf24bit));

 Procedure GetScreenToBmp(DrawCur    : Boolean;
                          Var Bmp    : TMemoryStream;
                          Width      : Integer = -1;
                          Height     : Integer = -1;
                          ImageViewQ : TImageViewQ = tiv_Medium);
 Procedure CompareStream(MyFirstStream, MyCompareStream: TMemoryStream; Width, Height: Integer; ImageViewQ : TImageViewQ = tiv_Medium);Overload;
 Procedure CompareStream(MyFirstStream, MySecondStream, MyCompareStream : TMemoryStream);Overload;
 Function  CompareStreamData(MyFirstStream, MySecondStream, MyCompareStream : TMemoryStream; CapMouse : Boolean) : Boolean;
 Function  CompareStreamS(FirstStream,
                          SecondStream      : String;
                          Var CompareStream : String;
                          CapMouse          : Boolean = False) : Boolean;
 Procedure ResumeStream(MyFirstStream, MySecondStream, MyCompareStream: TMemoryStream);
 Function  MakePNGtoString(Imagem : TGraphic)  : String;
 Function  Base64FromImage(Imagem : TMemoryStream)  : String;
 Function  Base64FromFileStream(FileStream : TFileStream) : String;
 Function  ImageFromBase64(Const Base64 : String;
                           Tipo: TGraphicClass) : TGraphic;
 Function  MemoryStreamFromBase64(Const Base64 : String) : TMemoryStream;
 Procedure FileStreamFromBase64(Const Base64 : String; Var FileStream : TFileStream);
 Procedure ResizeBmp(bmp: TBitmap; Width, Height: Integer);

Var
 ASMSize,
 muASM   : Integer;
 pdst    : Pointer;

implementation

Uses Form_Main;

// Resize the Bitmap
{function ResizeBmp(Bitmap: TBitmap; const NewWidth, NewHeight: integer): TBitmap;
begin
  Bitmap.Canvas.StretchDraw(Rect(0, 0, NewWidth, NewHeight), Bitmap);
  Bitmap.SetSize(NewWidth, NewHeight);

  Result := Bitmap;
end;  }


Function PadronizaTamanho(Imagem: TGraphic; W, H: Integer;
                          Tipo: TGraphicClass) : TGraphic;
Var
 B : TBitmap;
Begin
 B := TBitmap.Create;
 Try
  B.SetSize(W, H);
  B.Canvas.StretchDraw(Rect(0, 0, W, H), Imagem);
  If Tipo = Nil Then
   Result := TGraphic(Imagem.ClassType.Create)
  Else
   Result := Tipo.Create;
  Result.Assign(B);
  If Result is TJpegimage Then
   Begin
    TJpegimage(Result).CompressionQuality := 70; //90% de qualidade
    TJpegimage(Result).Performance        := TJPEGPerformance.jpBestQuality; //jpBestSpeed;
    TJpegimage(Result).Compress;
   End;
 Finally
  FreeAndNil(B);
 End;
End;

// Resize the Bitmap ( Best quality )
Procedure ResizeBmp(bmp: TBitmap; Width, Height: Integer);
Var
 SrcBMP: TBitmap;
 DestBMP: TBitmap;
Begin
 SrcBMP := TBitmap.Create;
 DestBMP := TBitmap.Create;
 Try
  SrcBMP.Assign(bmp);
  Try
   DestBMP.Width := Width;
   DestBMP.Height := Height;
   SetStretchBltMode(DestBMP.Canvas.Handle, HALFTONE);
   StretchBlt(DestBMP.Canvas.Handle, 0, 0, DestBMP.Width, DestBMP.Height, SrcBMP.Canvas.Handle, 0, 0, SrcBMP.Width, SrcBMP.Height, SRCCOPY);
   bmp.Assign(DestBMP);
  Finally
   FreeAndNil(DestBMP);
  End;
 Finally
  FreeAndNil(SrcBMP);
 End;
End;

Procedure ConverteBMPToJPG(Var StreamName : TMemoryStream);
Var
 JPG : TJpegimage;
 bmp : TBitmap;
Begin
 JPG := TJpegimage.Create;
 bmp := TBitmap.Create;
 Try
  JPG.CompressionQuality := 90; //90% de qualidade
  JPG.Performance        := TJPEGPerformance.jpBestQuality; //jpBestSpeed;
  BMP.LoadFromStream(StreamName);
  JPG.Assign(BMP);
  JPG.Compress;
  JPG.SaveToStream(StreamName);
 Finally
  JPG.DisposeOf;
  bmp.DisposeOf;
 End;
End;

Procedure SmoothResize(abmp : TBitmap; NuWidth, NuHeight : Integer);
Var
 weight,
 total_red,
 total_green,
 total_blue,
 xscale,
 yscale,
 sfrom_y,
 sfrom_x      : Single;
 ix, iy,
 new_red,
 new_green,
 new_blue,
 ifrom_y,
 ifrom_x,
 to_y,
 to_x         : Integer;
 weight_x,
 weight_y     : Array[0..1] of Single;
 bTmp         : TBitmap;
 sli, slo     : pRGBArray;
Begin
 abmp.PixelFormat := pf24bit;
 bTmp             := TBitmap.Create;
 bTmp.PixelFormat := pf24bit;
 bTmp.Width       := NuWidth;
 bTmp.Height      := NuHeight;
 xscale           := bTmp.Width / (abmp.Width-1);
 yscale           := bTmp.Height / (abmp.Height-1);
 For to_y := 0 To bTmp.Height -1 Do
  Begin
   sfrom_y := to_y / yscale;
   ifrom_y := Trunc(sfrom_y);
   weight_y[1] := sfrom_y - ifrom_y;
   weight_y[0] := 1 - weight_y[1];
   For to_x := 0 To bTmp.Width -1 Do
    Begin
     sfrom_x := to_x / xscale;
     ifrom_x := Trunc(sfrom_x);
     weight_x[1] := sfrom_x - ifrom_x;
     weight_x[0] := 1 - weight_x[1];
     total_red   := 0.0;
     total_green := 0.0;
     total_blue  := 0.0;
     For ix := 0 To 1 Do
      Begin
       For iy := 0 To 1 Do
        Begin
         sli := abmp.Scanline[ifrom_y + iy];
         new_red := sli[ifrom_x + ix].R;
         new_green := sli[ifrom_x + ix].G;
         new_blue := sli[ifrom_x + ix].B;
         weight := weight_x[ix] * weight_y[iy];
         total_red   := total_red   + new_red   * weight;
         total_green := total_green + new_green * weight;
         total_blue  := total_blue  + new_blue  * weight;
        End;
      End;
     slo := bTmp.ScanLine[to_y];
     slo[to_x].R := Round(total_red);
     slo[to_x].G := Round(total_green);
     slo[to_x].B := Round(total_blue);
    End;
  End;
 abmp.Width  := bTmp.Width;
 abmp.Height := bTmp.Height;
 abmp.Canvas.Draw(0,0,bTmp);
 bTmp.Free;
End;

// Screenshot
Procedure GetScreenToBmp(DrawCur    : Boolean;
                         Var Bmp    : TMemoryStream;
                         Width      : Integer = -1;
                         Height     : Integer = -1;
                         ImageViewQ : TImageViewQ = tiv_Medium);
 Type
  PRGB32Array = ^TRGB32Array;
  TRGB32Array = Packed Array[0..MaxInt Div SizeOf(TRGBQuad)-1] Of TRGBQuad;
 Procedure MakeGrey(Bitmap : TBitmap);
 Var
  w, h,
  y, x  : Integer;
  sl    : PRGB32Array;
  grey  : Byte;
 Begin
  Bitmap.PixelFormat := pf32bit;
  w                  := Bitmap.Width;
  h                  := Bitmap.Height;
  For y := 0 To h - 1 Do
   Begin
    sl := Bitmap.ScanLine[y];
    For x := 0 To w - 1 Do
     Begin
      With sl[x] Do
       Begin
        grey     := (rgbBlue + rgbGreen + rgbRed) div 3;
        rgbBlue  := grey;
        rgbGreen := grey;
        rgbRed   := grey;
       End;
     End;
   End;
 End;
Var
 Mybmp     : TBitmap;
 Cursorx,
 Cursory   : Integer;
 DrawPos   : TPoint;
 MyCursor  : TIcon;
 hld       : hwnd;
 Threadld  : dword;
 mp        : TPoint;
 pIconInfo : TIconInfo;
Const
 CAPTUREBLT = $40000000;
Var
 hdcScreen,
 hdcCompatible : hdc;
 hbmScreen     : HBITMAP;
Begin
 hdcScreen     := CreateDC('DISPLAY', nil, nil, nil);
 hdcCompatible := CreateCompatibleDC(hdcScreen);
 hbmScreen     := CreateCompatibleBitmap(hdcScreen, GetDeviceCaps(hdcScreen, HORZRES),
                                         GetDeviceCaps(hdcScreen, VERTRES));
 SelectObject(hdcCompatible, hbmScreen);
 Mybmp        := TBitmap.Create;
 Mybmp.Handle := hbmScreen;
 BitBlt(hdcCompatible, 0, 0, Mybmp.Width, Mybmp.Height, hdcScreen, 0, 0, SRCCOPY or CAPTUREBLT);
 DeleteDC(hdcScreen);
 DeleteDC(hdcCompatible);
 If DrawCur Then
  Begin
   GetCursorPos(DrawPos);
   MyCursor := TIcon.Create;
   GetCursorPos(mp);
   hld := WindowFromPoint(mp);
   Threadld := GetWindowThreadProcessId(hld, nil);
   AttachThreadInput(GetCurrentThreadId, Threadld, True);
   MyCursor.Handle := Getcursor();
   AttachThreadInput(GetCurrentThreadId, Threadld, false);
   GetIconInfo(MyCursor.Handle, pIconInfo);
   Cursorx := DrawPos.x - round(pIconInfo.xHotspot);
   Cursory := DrawPos.y - round(pIconInfo.yHotspot);
   Mybmp.Canvas.Draw(Cursorx, Cursory, MyCursor);
   DeleteObject(pIconInfo.hbmColor);
   DeleteObject(pIconInfo.hbmMask);
   MyCursor.ReleaseHandle;
   FreeAndNil(MyCursor);
  End;
 If (Width <> -1) And (Height<> -1) Then
  SmoothResize(Mybmp, Width, Height);
 Mybmp.PixelFormat := pf8bit;
 If ImageViewQ = tiv_MonoC Then
  Begin
   MakeGrey(Mybmp);
   Mybmp.PixelFormat := pf4bit;
  End
 Else
  Mybmp.PixelFormat := TPixelFormat(ImageViewQ);
 Try
  Mybmp.SaveToStream(Bmp);
 Except
  Bmp.SetSize(0);
  Bmp.Clear;
 End;
 If Mybmp <> Nil Then
  FreeAndNil(Mybmp);
End;

Function CompareStreamASM(Const s, d: Pointer; Var c: Pointer) : Integer; Assembler;
Var
 src     : ^AnsiChar;
 dest    : ^AnsiChar;
 n1, n2  : Cardinal;
Begin
 Asm
  mov muASM, 0
  mov pdst, ECX              //Move resolutado pra PDST
  mov src, EAX               //Move S pra src
  mov dest, EDX              //Move D pra dest
  call System.@LStrLen       //Tamanho de string S
  mov n1, EAX                //Move tamanho do S para n1
  mov EAX, dest              //Move dest para EAX
  call System.@LStrLen       //Tamanho do dst/D
  mov n2, EAX                //Move Tamanho D para n2
  mov EDX, EAX               //Move tamanho D para EDX segundo parametro setlenght
  mov EAX, pdst              //Move Result/pdst para EAX primeiro parametro strlenght
  call System.@LStrSetLength //Seta parametro pdst para tamanho n2
  mov ECX, ASMSize           //Mov n2 para ECX para controlar loopings
  test ECX, ECX              //Testa ECX
  jz @@end                   //Se EXX = 0 Termina
  push ESI                   //Guarda ESI na pilha
  push EDI
  mov EAX, pdst              //EAX := pdst; //Endereço da string de resultado
  mov ESI, src               //ESI := src; //String de origem
  mov EDI, dest
  mov EDX, [EAX]             //EDX := pdst^; //String de resultado
  @@cycle:
   mov AL, [ESI]             //Move um caracter do primeiro stream para AL
   cmp AL, [EDI]             //Copara caracter com o segundo stream
   je @@igual                //Se for igual pula para igual
   mov AL, [EDI]             //Se defente copia Carcter do Segund stream para AL
   mov [EDX], AL             //Coloca caracter no terceiro stream
   mov muASM, 1
   cmp AL, AL                //Apenas para gerra um Je
   je @@incremento           //Incrementa caracter
  @@igual:
   mov AL, '0'               //Se for igual Coloca '0' em AL
   mov [EDX], AL             //Move '0' para terceiro Stream
  @@incremento:
   inc ESI
   inc EDI
   inc EDX
   dec ECX
   cmp ECX, 0
   ja @@cycle
   pop EDI
   pop ESI                   //Recupera ESI na pilha
  @@end:
 End;
 Result := muASM;
End;

Function CompareStreamData(MyFirstStream,
                           MySecondStream,
                           MyCompareStream    : TMemoryStream;
                           CapMouse : Boolean) : Boolean;
Var
 P1, P2, P3 : Pointer;
Begin
 MyFirstStream.Position := 0;
// MySecondStream.Clear;
 MyCompareStream.Clear;
// GetScreenToBmp(CapMouse, MySecondStream);
 If MyFirstStream.Size <> MySecondStream.Size Then
  MyFirstStream.SetSize(MySecondStream.Size);
 MyFirstStream.Position := 0;
 P1      := MyFirstStream.Memory;
 P2      := MySecondStream.Memory;
 P3      := MyCompareStream.Memory;
 muASM   := 0;
 ASMSize := MySecondStream.Size;
 If CompareStreamASM(P1, P2, P3) = 0 Then
  Result := False
 Else
  Begin
   MyCompareStream.Clear;
   MyCompareStream.Write(P3^, MySecondStream.Size);
   MyFirstStream.Clear;
   MyFirstStream.CopyFrom(MySecondStream, 0);
   Result := True;
  End;
 Asm
  mov EDX, 0                 //Move tamanho D para EDX segundo parametro setlenght
  mov EAX, pdst              //Move Result/pdst para EAX primeiro para metro strlenght
  call System.@LStrSetLength //Seta parametro pdst para tamanho n2
 End;
End;

procedure CompareStream(MyFirstStream,
                        MySecondStream,
                        MyCompareStream : TMemoryStream);
Var
 vCopy          : Boolean;
 I              : Integer;
 P1,
 P2,
 P3             : ^AnsiChar;
begin
  Try
   MyFirstStream.Position := 0;
   MySecondStream.Position := 0;
   P1 := MyFirstStream.Memory;
   P2 := MySecondStream.Memory;
   MyCompareStream.Clear;
   MyCompareStream.SetSize(0);
   MyCompareStream.SetSize(MyFirstStream.Size);
   P3 := MyCompareStream.Memory;
   vCopy := False;
   For I := 0 to MyFirstStream.Size - 1 do
    Begin
     If P1^ = P2^ Then
      P3^ := '0'
     Else
      Begin
       P3^ := P2^;
       vCopy := True;
      End;
     Inc(P1);
     Inc(P2);
     Inc(P3);
    End;
   If vCopy Then
    Begin
     MyFirstStream.Clear;
     MyFirstStream.SetSize(0);
     MySecondStream.Position := 0;
     MyFirstStream.CopyFrom(MySecondStream, MySecondStream.Size);
    End
   Else
    Begin
     MyCompareStream.Clear;
     MyCompareStream.SetSize(0);
    End;
  Finally
//   MySecondStream.Clear;
//   MySecondStream.SetSize(0);
  End;
end;

Function CompareBits(Value1, Value2         : AnsiString;
                     StartIn, BitsToCompare : Integer;
                     Var ReturnBits         : AnsiString;
                     ReturnValue            : Boolean = False) : Boolean;
Var
 vString1,
 vString2  : String;
 vLength   : Integer;
 Function CreateNullBits(Qtde : Integer) : String;
 Var
  I : Integer;
 Begin
  Result := '';
  For I := 0 to Qtde -1 Do
   Result := Result + '0';
 End;
 Function ComparedBits(Value1, Value2 : String) : String;
 Var
  I : Integer;
 Begin
  Result := '';
  If Length(Value2) <> Length(Value1) Then
   Result := Value1
  Else
   Begin
    For I := 1 to Length(Value1) Do
     Begin
      If Value1[I] = Value2[I] Then
       Result := Result + '0'
      Else
       Result := Result + Value2[I];
     End;
   End;
 End;
Begin
 vLength := Length(Value1) - (StartIn + BitsToCompare);
 If vLength > 0 Then
  vLength := BitsToCompare
 Else
  vLength := Length(Value1) - StartIn;
 vString1 := Copy(Value1, StartIn, vLength);
 vLength := Length(Value2) - (StartIn + BitsToCompare);
 If vLength > 0 Then
  vLength := BitsToCompare
 Else
  vLength := Length(Value2) - StartIn;
 vString2 := Copy(Value2, StartIn, vLength);
 Result   := vString1 = vString2;
 If ReturnValue Then
  Begin
   If Result Then
    ReturnBits := CreateNullBits(vLength)
   Else
    ReturnBits := ComparedBits(vString1, vString2);
  End;
End;

procedure CompareStreamDelphi(FirstStream,
                              SecondStream      : String;
                              Var CompareStream : String);
Var
 vSource,
 vDest,
 vCompared : TBitmap;
 vFirstStream,
 vSecondStream,
 vComparedStream : TStringStream;
Begin
 vSource                := TBitmap.Create;
 vDest                  := TBitmap.Create;
 vCompared              := TBitmap.Create;
 vFirstStream           := TStringStream.Create(FirstStream);
 vFirstStream.Position  := 0;
 vSecondStream          := TStringStream.Create(SecondStream);
 vSecondStream.Position := 0;
 vComparedStream        := TStringStream.Create;
 Try
  vSource.LoadFromStream(vFirstStream);
  vDest.LoadFromStream(vSecondStream);
  GenerateComparer(vSource, vDest, vCompared); //, TPixelFormat(ImageViewQ));
  vCompared.SaveToStream(vComparedStream);
  vComparedStream.Position := 0;
  CompareStream := vComparedStream.DataString;
 Finally
  vSource.Free;
  vDest.Free;
  vCompared.Free;
  vFirstStream.Free;
  vSecondStream.Free;
  vComparedStream.Free;
 End;
End;

Function CompareStreamS(FirstStream,
                        SecondStream      : String;
                        Var CompareStream : String;
                        CapMouse          : Boolean = False) : Boolean;
Var
 I : Integer;
 vResult : AnsiString;
 vFirstStream,
 vSecondStream,
 vCompareStream : TMemoryStream;
 Function MemoryStreamToString(Value : TMemoryStream) : String;
 Var
  vStringStream : TStringStream;
 Begin
  vStringStream := TStringStream.Create;
  Try
   Value.SaveToStream(vStringStream);
   Result := vStringStream.DataString;
  Finally
   FreeAndNil(vStringStream);
  End;
 End;
 Procedure StringToMemoryStream(Value : String; Var Result : TMemoryStream);
 Var
  vStringStream : TStringStream;
 Begin
  vStringStream := TStringStream.Create(Value);
  Result        := TMemoryStream.Create;
  Try
   vStringStream.Position := 0;
   vStringStream.SaveToStream(Result);
  Finally
   FreeAndNil(vStringStream);
   Result.Position := 0;
  End;
 End;
Begin
 If CompareFromDelphi Then
  CompareStreamDelphi(FirstStream, SecondStream, CompareStream)
 Else
  Begin
   StringToMemoryStream(FirstStream,  vFirstStream);
   StringToMemoryStream(SecondStream, vSecondStream);
   vCompareStream  := TMemoryStream.Create;
   Try
    Result := CompareStreamData(vFirstStream, vSecondStream, vCompareStream, CapMouse);
    If Result Then
     CompareStream := MemoryStreamToString(vCompareStream);
   Finally
    vFirstStream.Free;
    vSecondStream.Free;
    vCompareStream.Free;
   End;
  End;
End;

{
Function  CompareStreamS(FirstStream,
                         SecondStream      : String;
                         Var CompareStream : String;
                         CapMouse          : Boolean = False) : Boolean;
Var
 I : Integer;
Begin
 Result        := False;
 CompareStream := '';
 If SecondStream = '' Then
  SecondStream := FirstStream;
 Try
  For I := 1 to Length(FirstStream) Do
   Begin
    If FirstStream[I] = SecondStream[I] Then
     CompareStream := CompareStream + '0'
    Else
     CompareStream := CompareStream + SecondStream[I];
   End;
  Result := True;
 Except
  CompareStream := '';
 End;
End;
}

// Compare Streams and separate when the Bitmap Pixels are equal.
procedure CompareStream(MyFirstStream,
                        MyCompareStream : TMemoryStream;
                        Width, Height   : Integer;
                        ImageViewQ      : TImageViewQ = tiv_Medium);
Var
 vCopy          : Boolean;
 I              : Integer;
 P1,
 P2,
 P3             : ^AnsiChar;
 MySecondStream : TMemoryStream;
begin
  MySecondStream := TMemoryStream.Create;
  Try
   GetScreenToBmp(frm_Main.MouseCapture, MySecondStream, Width, Height, ImageViewQ);
   P1 := MyFirstStream.Memory;
   P2 := MySecondStream.Memory;
   MyCompareStream.Clear;
   MyCompareStream.SetSize(0);
   MyCompareStream.SetSize(MyFirstStream.Size);
   P3 := MyCompareStream.Memory;
   vCopy := False;
   For I := 0 to MyFirstStream.Size - 1 do
    Begin
     If P1^ = P2^ Then
      P3^ := '0'
     Else
      Begin
       P3^ := P2^;
       vCopy := True;
      End;
     Inc(P1);
     Inc(P2);
     Inc(P3);
    End;
   If vCopy Then
    Begin
     MyFirstStream.Clear;
     MyFirstStream.SetSize(0);
     MySecondStream.Position := 0;
     MyFirstStream.CopyFrom(MySecondStream, MySecondStream.Size);
    End
   Else
    Begin
     MyCompareStream.Clear;
     MyCompareStream.SetSize(0);
    End;
  Finally
   MySecondStream.Clear;
   MySecondStream.SetSize(0);
   FreeAndNil(MySecondStream);
  End;
end;

Function MakePNGtoString(Imagem : TGraphic) : String;
Var
 PNG           : TPngImage;
 vMemoryStream : TMemoryStream;
Begin
 PNG := TPngImage.Create;
 vMemoryStream := TMemoryStream.Create;
 Try
  PNG.Assign(Imagem);
  PNG.CompressionLevel := 9;
  PNG.SaveToStream(vMemoryStream);
  Result := Base64FromImage(vMemoryStream);
 Finally
  FreeAndNil(vMemoryStream);
  FreeAndNil(PNG);
 End;
End;

Function Base64FromImage(Imagem : TMemoryStream) : String;
Var
 Input  : TBytesStream;
 Output : TStringStream;
Begin
 Input := TBytesStream.Create;
 Try
  Imagem.SaveToStream(Input);
  Input.Position := 0;
  Output := TStringStream.Create('', TEncoding.ASCII);
  Try
   Soap.EncdDecd.EncodeStream(Input, Output);
   Result := Output.DataString;
  Finally
   Output.Free;
  End;
 Finally
  Input.Free;
 End;
End;

Function Base64FromFileStream(FileStream : TFileStream) : String;
Var
 Input  : TBytesStream;
 Output : TStringStream;
Begin
 Input := TBytesStream.Create;
 Try
  Input.LoadFromStream(FileStream);
  Input.Position := 0;
  Output := TStringStream.Create('', TEncoding.ASCII);
  Try
   Soap.EncdDecd.EncodeStream(Input, Output);
   Result := Output.DataString;
  Finally
   Output.Free;
  End;
 Finally
  Input.Free;
 End;
End;

Procedure FileStreamFromBase64(Const Base64 : String; Var FileStream : TFileStream);
Var
 Input  : TStringStream;
 Output : TBytesStream;
Begin
 If Length(base64) > 0 Then
  Begin
   Input := TStringStream.Create(Base64, TEncoding.ASCII);
   Try
    Output := TBytesStream.Create;
    Try
     Soap.EncdDecd.DecodeStream(Input, Output);
     Output.Position := 0;
     Try
      FileStream.CopyFrom(Output, Output.Size);
     Except
      Raise;
     End;
    Finally
     Output.Free;
    End;
   Finally
    Input.Free;
   End;
  End;
End;

Function MemoryStreamFromBase64(Const Base64 : String) : TMemoryStream;
Var
 Input  : TStringStream;
 Output : TBytesStream;
Begin
 Result := TMemoryStream.Create;
 If Length(base64) > 0 Then
  Begin
   Input := TStringStream.Create(Base64, TEncoding.ASCII);
   Try
    Output := TBytesStream.Create;
    Try
     Soap.EncdDecd.DecodeStream(Input, Output);
     Output.Position := 0;
     Try
      Result.LoadFromStream(Output);
     Except
      Result.Free;
      Raise;
     End;
    Finally
     Output.Free;
    End;
   Finally
    Input.Free;
   End;
  End;
End;

Function ImageFromBase64(Const Base64 : String;
                                 Tipo : TGraphicClass) : TGraphic;
Var
 Input  : TStringStream;
 Output : TBytesStream;
Begin
 Result := Nil;
 If Length(base64) > 0 Then
  Begin
   Input := TStringStream.Create(Base64, TEncoding.ASCII);
   if Tipo = Nil then
    Result := TBitmap.Create
   Else
    Result := Tipo.Create;
   Try
    Output := TBytesStream.Create;
    Try
     Soap.EncdDecd.DecodeStream(Input, Output);
     Output.Position := 0;
     Try
      Result.LoadFromStream(Output);
     Except
      Result.Free;
      Raise;
     End;
    Finally
     Output.Free;
    End;
   Finally
    Input.Free;
   End;
  End;
End;

// Modifies Streams to set the Pixels of Bitmap
procedure ResumeStream(MyFirstStream, MySecondStream, MyCompareStream: TMemoryStream);
var
  I: integer;
  P1, P2, P3: ^AnsiChar;
begin
  P1 := MyFirstStream.Memory;
  MySecondStream.SetSize(MyFirstStream.Size);
  P2 := MySecondStream.Memory;
  P3 := MyCompareStream.Memory;

  for I := 0 to MyFirstStream.Size - 1 do
  begin
    if P3^ = '0' then
      P2^ := P1^
    else
      P2^ := P3^;
    Inc(P1);
    Inc(P2);
    Inc(P3);
  end;
  MyFirstStream.Clear;
  MyFirstStream.SetSize(0);
  MyFirstStream.CopyFrom(MySecondStream, 0);
  MySecondStream.Position := 0;
end;

end.

