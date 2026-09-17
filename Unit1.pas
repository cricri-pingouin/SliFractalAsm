unit Unit1;

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, Graphics, Inifiles, Menus,
  ExtCtrls, Dialogs;

type
  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    mniDraw: TMenuItem;
    mniOptions: TMenuItem;
    mniPNG: TMenuItem;
    mniExit: TMenuItem;
    Image1: TImage;
    procedure DrawMandelbrot(X, Y, MinX, MinY: Single; SizeX, SizeY, MaxCount: Integer);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure mniDrawClick(Sender: TObject);
    procedure mniOptionsClick(Sender: TObject);
    procedure mniPNGClick(Sender: TObject);
    procedure mniExitClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    CanvasWidth, CanvasHeight, MaxIterations: Integer;
    Xmin, Xmax, Ymin, Ymax: Single;
    Colour: string;
  end;

var
  Form1: TForm1;

implementation

uses
  Unit2, pngimage;

{$R *.dfm}

procedure TForm1.DrawMandelbrot(X, Y, MinX, MinY: Single; SizeX, SizeY, MaxCount: Integer);
var
  c1, c2, z1, z2, Four: Double;
  i, j, Count, Four2: Integer;
  //Scanline stuff
  PicBuffer: TBitmap; //buffer
  BufferArray: array of array of Byte; // Multi-dimension array
  P: PRGBTriple; //Scanline pointer
  Palette: array[0..255] of TRGBTriple; //24bits RGB palettes
label
  _start, _end, _realend;
begin
//Count will always be from 1<= count <= MaxIterations
  //Initialise. otherwise unpredictable colours from whatever already in memory
  for i := 0 to 255 do
  begin
    Palette[i].rgbtRed := 0;
    Palette[i].rgbtGreen := 0;
    Palette[i].rgbtBlue := 0;
  end;
  //Set colour palette
  if Colour = 'Fire' then
  begin
    for i := 1 to (MaxIterations div 3) do
    begin
      Palette[i].rgbtRed := (i * 255) div (MaxIterations div 3);
      Palette[i].rgbtGreen := 0;
      Palette[i].rgbtBlue := 0;
    end;
    for i := (MaxIterations div 3 + 1) to (2 * MaxIterations div 3) do
    begin
      Palette[i].rgbtRed := 255;
      Palette[i].rgbtGreen := ((i - MaxIterations div 3) * 255) div (MaxIterations div 3);
      Palette[i].rgbtBlue := 0;
    end;
    for i := (2 * MaxIterations div 3 + 1) to MaxIterations do
    begin
      Palette[i].rgbtRed := 255;
      Palette[i].rgbtGreen := 255;
      Palette[i].rgbtBlue := ((i - 2 * MaxIterations div 3) * 255) div (MaxIterations div 3);
    end;
  end
  else
    for i := 0 to MaxIterations do
    begin
      Palette[i].rgbtRed := 0;
      Palette[i].rgbtGreen := 0;
      Palette[i].rgbtBlue := 0;
      if Colour = 'Blue' then
        Palette[i].rgbtBlue := (i * 255) div MaxIterations
      else if Colour = 'Green' then
        Palette[i].rgbtGreen := (i * 255) div MaxIterations
      else
        Palette[i].rgbtRed := (i * 255) div MaxIterations;
    end;
  //Size the buffer array according to previous variables, i.e. form size
  SetLength(BufferArray, SizeX, SizeY);
  //Initialise buffer
  PicBuffer := TBitmap.Create;
  PicBuffer.Width := SizeX;
  PicBuffer.Height := SizeY;
  PicBuffer.PixelFormat := pf24bit; //Use 24bits RGB, not TColor as we won't use alpha blending
  //Calculate Mandelbrot set
  Four := 4.0;
  c2 := MinY;
  for i := 0 to SizeY - 1 do
  begin
    c1 := MinX;
    for j := 0 to SizeX - 1 do    //Compute series iterations for this Z coordinate
    begin
      //z1 := 0;  //Can be done in asm
      //z2 := 0;
      Count := MaxIterations; //mov ecx, MaxIterations ... dec ecx ... mov Count, ecx <- in asm is slower?!
      //Count is depth of iteration of the mandelbrot set
      //If |z| >=2 then z is not a member of a Mandelbrot set
      asm
        //mov     ecx, MaxIterations
        // Next 4 lines not faster than z1 := 0; z2 := 0; but not slower either
        fldz
        fstp    z1
        fldz
        fstp    z2
        //while ((z1 * z1 + z2 * z2 < 4.0) and (Count < MaxIterations)) do
        _start  :
        fld     z1
        fmul    st, st
        fld     st    //dup z1^2 for next step
        fld     z2
        fmul    st, st
        fld     st    //dup z2^2 for next step
        fxch    st(2) //get back z1^2 in st(0) to calc z1^2+z2^2
        fadd
        fld     Four  //OR: could do fild Four where Four is an integer but the conversion makes it slower
//Is it <4?
//Method 1: fcompp fstsw ax sahf jb
//     FCOMP                 C3   C2   C0
//     If ST(0) > source      0    0    0
//     If ST(0) < source      0    0    1
//     If ST(0) = source      1    0    0
//     If ST(0) ? source      1    1    1
    //fcompp         //Make sure we pop both st(0) and st(1)!
        //fstsw/fnstsw copy to ax:  C3 - - - C2 C1 C0 - - - - - - - -
        //fnstsw  ax     //Store FPU status word in AX register, no checking
    //fstsw   ax     //Store FPU status word in AX register after checking for pending unmasked floating-point exceptions
        //fwait          //ensure the previous instruction is completed; not required on new CPUs?
    //sahf           //transfer the condition codes to the CPU's flag register
        //ja      criteria_greater //criteria was ST(0) for comparison
        //jb      criteria_lower
        //jz      criteria_equal
    //jb      _end   //z1 * z1 + z2 * z2 > 4.0
        //jz      _end   //need that too? Not sure! Maybe not as we skip the dec count
//Method 2: same as method 1 but test ax bit instead of sahf (not faster)
        //fcompp
        //fstsw   ax
        //and ax,256
        //jnz _end
//Method 3: fcomip fstp jbe (Google: FCOMIP is the modern, faster instruction because it directly modifies the CPU's main FLAGS register, eliminating extra steps)
//| FCOMIP results | Z | P | C |
//+--------------------+---+---+---+
//| ST0 > ST(i)    | 0 | 0 | 0 |
//| ST0 < ST(i)    | 0 | 0 | 1 |
//| ST0 = ST(i)    | 1 | 0 | 0 |
//| unordered      | 1 | 1 | 1 |  one or both operands were NaN.
//+--------------+---+---+-----+------------------------------------+
//| Test         | Z | C | Jcc | Notes                              |
//+--------------+---+---+-----+------------------------------------+
//| ST0 < ST(i)  | X | 1 | JB  | ZF will never be set when CF = 1   |
//| ST0 <= ST(i) | 1 | 1 | JBE | Either ZF or CF is ok              |
//| ST0 == ST(i) | 1 | X | JE  | CF will never be set in this case  |
//| ST0 != ST(i) | 0 | X | JNE |                                    |
//| ST0 >= ST(i) | X | 0 | JAE | As long as CF is clear we are good |
//| ST0 > ST(i)  | 0 | 0 | JA  | Both CF and ZF must be clear       |
//+--------------+---+---+-----+------------------------------------+
//Legend: X: don't care, 0: clear, 1: set
        fcomip  st(0), st(1)
        fstp    st //Unlike fcompp, fcomip pops the stack once not twice, so need to pop again
        jbe     _end
        //z1 = z1 * z1 - z2 * z2 + c1
        //If we didn't duplicates z^2 values in previous step, we'd need to calc them again!
        //fld     st
        //fmul    st, st
        //fld     z2
        //fmul    st, st
        //But we did so we have st(0)=z2^2 and st(1)=z1^2 copies from previous step
        fsub
        fld     c1
        fadd          //result = st(0) = z1 * z1 - z2 * z2 + c1
        fld     z1    //keep a backup of z1 for next step
        fxch    st(1) //Get back our result in st(0), backup in st(1)
        fstp    z1    //z1 = st(0) = result, hence why we needed a backup
        //z2 = 2 * z1 * z2 + c2
        fld     z2
        fmul          //fmul to old z1 value copy in st(1)
        fadd    st, st //*2; OR: fld st fadd, OR: fld1 fld1 fadd fmul, OR: fld Two fmul (where Two := 2.0; slower)
        fld     c2
        fadd
        fstp    z2 //z2 = st(0)
        //Dec Count
        dec     Count  //dec ecx ////See comment before asm section
        //while ... (Count < MaxIterations), here changed to Count>0 so can do jnz and save cmp
        jnz     _start
        jmp     _realend
        _end    :
        //Due to duplicating the z^2 values, downside is if we get here they are still in stack, need pop twice to empty
        //OR: fucompp (comp and pops twice same speed, same speed but less compatible?), OR: emms (slower)
        fstp    st
        fstp    st
        _realend :
        //mov     Count, ecx //See comment before asm section
      end;
      //Colour pixel at Z coordinates
      //Colour from palette with index = number of iterations
      BufferArray[j, i] := Count; //Asm algorithm makes this Count the colour index rather than the iterations count
      c1 := c1 + X;
    end;
    c2 := c2 + Y;
  end;
  //Populate buffer using scanline
  for j := 0 to SizeY - 1 do //Height-1 or pointer will fall out=crash!
  begin
    //Loop through Y, then X. This way we process the whole scanline in one go
    P := PicBuffer.ScanLine[j];
    for i := 0 to SizeX - 1 do //Width-1 or pointer will fall out=crash!
    begin
      //Set pixel colour according to index value in palettes
      P^ := Palette[BufferArray[i, j]]; //Asm version: BufferArray now contains the colour index
      //Increment pointer AFTER, otherwise we fail to process leftmost column
      Inc(P);
    end;
  end;
    //Copy buffer to form canvas
//Size image in Draw menu event, it seems to fail if doing it here if size > ca. 800 pixels
//  Image1.Width := SizeX;
//  Image1.Height := SizeY;
  Image1.Canvas.Draw(0, 0, PicBuffer);
  //Canvas.Draw(0, 0, PicBuffer);
  //Free PicBuffer to avoid memory leak
  PicBuffer.Free;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
var
  myINI: TINIFile;
begin
  //Save settings to INI file
  myINI := TINIFile.Create(ExtractFilePath(Application.EXEName) + 'fractal.ini');
  myINI.WriteInteger('Settings', 'CanvasWidth', CanvasWidth);
  myINI.WriteInteger('Settings', 'CanvasHeight', CanvasHeight);
  myINI.WriteFloat('Settings', 'Xmin', Xmin);
  myINI.WriteFloat('Settings', 'Xmax', Xmax);
  myINI.WriteFloat('Settings', 'Ymin', Ymin);
  myINI.WriteFloat('Settings', 'Ymax', Ymax);
  myINI.WriteInteger('Settings', 'MaxIterations', MaxIterations);
  myINI.WriteString('Settings', 'Colour', Colour);
  myINI.Free;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  myINI: TINIFile;
begin
  //Initialise options from INI file
  myINI := TINIFile.Create(ExtractFilePath(Application.EXEName) + 'fractal.ini');
  //Read settings from INI file
  CanvasWidth := myINI.ReadInteger('Settings', 'CanvasWidth', 800);
  CanvasHeight := myINI.ReadInteger('Settings', 'CanvasHeight', 800);
  Xmin := myINI.ReadFloat('Settings', 'Xmin', -2);
  Xmax := myINI.ReadFloat('Settings', 'Xmax', 1);
  Ymin := myINI.ReadFloat('Settings', 'Ymin', -1.5);
  Ymax := myINI.ReadFloat('Settings', 'Ymax', 1.5);
  MaxIterations := myINI.ReadInteger('Settings', 'MaxIterations', 255);
  Colour := myINI.ReadString('Settings', 'Colour', 'Red');
  myINI.Free;
end;

procedure TForm1.mniDrawClick(Sender: TObject);
var
  dX, dY: Single;
  Start, Finish: Int64;
begin
  mniDraw.Enabled := False;
  mniOptions.Enabled := False;
  mniPNG.Enabled := False;
  //Size window
  ClientWidth := CanvasWidth;
  ClientHeight := CanvasHeight;
  //Size image, it seems to fail if doing it in Fractal drawing routine if size > ca. 800 pixels
  Image1.Width := CanvasWidth;
  Image1.Height := CanvasHeight;
  //Calculate steps size to make one pixel
  dX := (Xmax - Xmin) / CanvasWidth;
  dY := (Ymax - Ymin) / CanvasHeight;
  //Draw fractal
  Caption := 'Wait...';
  Start := GetTickCount;
  DrawMandelbrot(dX, dY, Xmin, Ymin, CanvasWidth, CanvasHeight, MaxIterations);
  Finish := GetTickCount;
  Caption := 'Time: ' + IntToStr(Finish - Start) + 'ms';
  mniDraw.Enabled := True;
  mniOptions.Enabled := True;
  mniPNG.Enabled := True;
end;

procedure TForm1.mniOptionsClick(Sender: TObject);
begin
  if Form2.Visible = False then
    Form2.Show
  else
    Form2.Hide;
end;

procedure TForm1.mniPNGClick(Sender: TObject);
var
  i: Integer;
  FileName: string;
  PNG: TPNGObject;
begin
  FileName := 'fractal.png';
  if fileexists(FileName) then
  begin
    i := 0;
    repeat
      Inc(i);
      FileName := 'fractal' + inttostr(i) + '.png';
    until not fileexists(FileName);
  end;
  PNG := TPNGObject.Create;
  try
    PNG.Assign(Image1.Picture.Bitmap);
    PNG.SaveToFile(FileName);
    ShowMessage('Saved file ' + FileName);
  finally
    PNG.Free;
  end
end;

procedure TForm1.mniExitClick(Sender: TObject);
begin
  Close;
end;

end.

