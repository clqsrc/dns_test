program dns_test1;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  uBit in 'uBit.pas',
  Type32to64 in 'Type32to64.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.