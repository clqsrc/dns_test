object Form1: TForm1
  Left = 451
  Top = 265
  Width = 907
  Height = 493
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = ANSI_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #23435#20307
  Font.Style = []
  OldCreateOrder = False
  Scaled = False
  PixelsPerInch = 96
  TextHeight = 12
  object Button1: TButton
    Left = 144
    Top = 136
    Width = 75
    Height = 25
    Caption = 'Button1'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Edit1: TEdit
    Left = 24
    Top = 112
    Width = 121
    Height = 20
    TabOrder = 1
    Text = 'www.google.com'
  end
  object Memo1: TMemo
    Left = 248
    Top = 80
    Width = 585
    Height = 345
    ScrollBars = ssBoth
    TabOrder = 2
  end
  object Button2: TButton
    Left = 144
    Top = 168
    Width = 75
    Height = 25
    Caption = 'Button2 tcp'
    TabOrder = 3
    OnClick = Button2Click
  end
  object txtDns: TComboBox
    Left = 24
    Top = 88
    Width = 121
    Height = 20
    ItemHeight = 12
    TabOrder = 4
    Text = '8.8.8.8'
    Items.Strings = (
      '8.8.8.8'
      '114.114.114.114'
      '84.200.69.80'
      '84.200.69.40')
  end
  object UdpSocket1: TUdpSocket
    Left = 136
    Top = 32
  end
  object IdUDPClient1: TIdUDPClient
    Port = 0
    Left = 176
    Top = 32
  end
  object IdTCPClient1: TIdTCPClient
    MaxLineAction = maException
    ReadTimeout = 0
    Port = 0
    Left = 216
    Top = 32
  end
end
