unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, IdBaseComponent, IdComponent, IdUDPBase, IdUDPClient, WinSock,
  Sockets;

type
  TForm1 = class(TForm)
    Button1: TButton;
    UdpSocket1: TUdpSocket;
    IdUDPClient1: TIdUDPClient;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses Type32to64;

{$R *.dfm}

type
  //dns ���������Ӧ����ͬһ��ʽ
  TDnsReq = packed record


  end;

  //Tag:uint16; //�����һ������Ľṹ�����ת������
  VDnsHead_tag = packed record
    QR :uint8; //(1����)����ѯ/��Ӧ�ı�־λ��1Ϊ��Ӧ��0Ϊ��ѯ��
    opcode :uint32; //(4����)�������ѯ����Ӧ������(��Ϊ0���ʾ�Ǳ�׼�ģ���Ϊ1���Ƿ���ģ���Ϊ2���Ƿ�����״̬����)��
    AA :uint8; //(1����)����Ȩ�ش�ı�־λ����λ����Ӧ��������Ч��1��ʾ���ַ�������Ȩ�޷�����(����Ȩ�޷������Ժ�������)
    TC :uint8; //(1����)���ضϱ�־λ��1��ʾ��Ӧ�ѳ���512�ֽڲ��ѱ��ض�(��ϡ����ǵ������������ضϺ�UDP�йأ��ȼ���)
    RD :uint8; //(1����)����λΪ1��ʾ�ͻ���ϣ���õ��ݹ�ش�(�ݹ��Ժ�������) //�����л���ֻ��Ҫ�����,���඼Ϊ 0
    RA :uint8; //(1����)��ֻ������Ӧ��������Ϊ1����ʾ���Եõ��ݹ���Ӧ��
    zero :array[0..2] of uint8; //(3����)����˵Ҳ֪������0�ˣ������ֶΡ�
    rcode :uint32; //(4����)�������룬��ʾ��Ӧ�Ĳ��״̬��ͨ��Ϊ0��3

  end;


  //dns ��ͷ���̶�Ϊ 12 �ֽ�(12x8=96λ)
  TDnsHead = packed record
    ID:uint16;  //����ĶԻ� id ����,����ȷ����Ӧ�Ƿ����Լ�����õ���
    //Tag:uint16; //�����һ������Ľṹ�����ת������
    Flags:uint16; //�����һ������Ľṹ�����ת������ //����һ���� 0x100

    QDCOUNT:uint16; //ռ16λ��2�ֽڡ���ѯ��¼�ĸ��� //������    //������һ��Ϊ 1
    ANCOUNT:uint16; //ռ16λ��2�ֽڡ��ظ���¼�ĸ��� //�ش�RR��  //������һ��Ϊ 0
    NSCOUNT:uint16; //ռ16λ��2�ֽڡ�Ȩ����¼�ĸ��� //Ȩ��RR��  //������һ��Ϊ 0
    ARCOUNT:uint16; //ռ16λ��2�ֽڡ������¼�ĸ��� //����RR��  //������һ��Ϊ 0

  end;

  TDnsRequest = packed record
    Head:TDnsHead;
    QNAME:string; //Ҫ��ѯ������,����ʽ����,�����е� . Ҫ������� //bbs.zzsy.com=>3bbs4zzsy3com0����.�ֿ�bbs��zzsy��com�������֡�ÿ�����ֵĳ���Ϊ3��4��3
    QTYPE:uint16;  //��ѯ����,һ����ָ A ��¼���� MX ��¼//
    //***//A=0x01, //ָ������� IP ��ַ��
    //NS=0x02, //ָ��������������� DNS ���Ʒ�������
    //MD=0x03, //ָ���ʼ�����վ���������Ѿ���ʱ�ˣ�ʹ��MX���棩
    //MF=0x04, //ָ���ʼ���תվ���������Ѿ���ʱ�ˣ�ʹ��MX���棩
    //CNAME=0x05, //ָ�����ڱ����Ĺ淶���ơ�
    //SOA=0x06, //ָ������ DNS ����ġ���ʼ��Ȩ��������
    //MB=0x07, //ָ������������
    //MG=0x08, //ָ���ʼ����Ա��
    //MR=0x09, //ָ���ʼ�������������
    //NULL=0x0A, //ָ���յ���Դ��¼
    //WKS=0x0B, //������֪����
    //PTR=0x0C, //�����ѯ�� IP ��ַ����ָ���������������ָ��ָ��������Ϣ��ָ�롣
    //HINFO=0x0D, //ָ������� CPU �Լ�����ϵͳ���͡�
    //MINFO=0x0E, //ָ��������ʼ��б���Ϣ��
    //***//MX=0x0F, //ָ���ʼ���������
    //TXT=0x10, //ָ���ı���Ϣ��
    //AAAA=0x1c,//IPV6��Դ��¼��
    //UINFO=0x64, //ָ���û���Ϣ��
    //UID=0x65, //ָ���û���ʶ����
    //GID=0x66, //ָ�����������ʶ����
    //ANY=0xFF //ָ�������������͡�

    QCLASS:uint16; //�������������,һ�㶼�� internet
    //***///IN=0x01, //ָ�� Internet ���
    //CSNET=0x02, //ָ�� CSNET ��𡣣��ѹ�ʱ��
    //CHAOS=0x03, //ָ�� Chaos ���
    //HESIOD=0x04,//ָ�� MIT Athena Hesiod ���
    //ANY=0xFF //ָ���κ���ǰ�г���ͨ�����
  end;

  //��Ӧ����
  TDnsResponse = packed record
    Head:TDnsHead;
    QNAME:string; //Ҫ��ѯ������,����ʽ����,�����е� . Ҫ������� //bbs.zzsy.com=>3bbs4zzsy3com0����.�ֿ�bbs��zzsy��com�������֡�ÿ�����ֵĳ���Ϊ3��4��3
    QTYPE:uint16;  //��ѯ����,һ����ָ A ��¼���� MX ��¼//

  end;


//����תΪ���ĸ�ʽ
//bbs.zzsy.com=>3bbs4zzsy3com0����.�ֿ�bbs��zzsy��com�������֡�ÿ�����ֵĳ���Ϊ3��4��3
function GetHostPack(host:string):string;
var
  i:Integer;
  c:AnsiChar;
  count:Integer;
begin
  //��Ϊ������ǰ,������ѭ���ȽϺ�

  Result := host;

  count := 0;
  for i := Length(host) downto 1 do
  begin
    c := host[i];

    if c = '.' then
    begin
      Result[i] := AnsiChar(count);
      count := 0;
      Continue;
    end;
    
    count := count + 1;
  end;

  Result := AnsiChar(count) + Result; //�������һ��

  Result := Result +#0; //����Ҫ�ӽ�������


end;

procedure TForm1.Button1Click(Sender: TObject);
var
  req:string;
  res:string;
  b1:TBits;
  host:string;
  treq:TDnsRequest;
  reqTag:VDnsHead_tag;
  mem:TMemoryStream;
  tres:TDnsResponse; //��Ӧ����

begin

  req := '';
  res := '';

  //host := 'www.baidu.com';
  host := 'lib.csdn.net';
  host := GetHostPack(host);

  treq.QNAME := host;
  treq.QTYPE := htons(1);//$f; // A=0x01, MX=0x0F,
  ////treq.QTYPE := htons($f);//$f; // A=0x01, MX=0x0F,
  treq.QCLASS := htons(1); // internet

  FillChar(treq.Head, SizeOf(treq.Head), 0);
  Randomize();
  treq.Head.ID := Trunc((Now - Trunc(Now)) * 100000) + Random(10000);
  treq.Head.QDCOUNT := htons(1);//1;  //һ������

  //treq.Head.Tag;

  //--------------------------------------------------
  FillChar(reqTag, SizeOf(reqTag), 0);
  reqTag.QR := 0; //1Ϊ��Ӧ��0Ϊ��ѯ��
  reqTag.RD := 1; //ϣ���õ��ݹ�ش�//ֻ�вſ���Ϊ 1,����ʵ���� tag ��������˵�����ǹ̶���,����Ҫλ������

  ////
  treq.Head.Flags := htons($100);//0;
  //treq.Head.Flags := 0; //����ûӰ��
  //--------------------------------------------------

  mem := TMemoryStream.Create;

  //mem.WriteBuffer('aaa'[1], 3);
  mem.WriteBuffer(treq.Head, SizeOf(treq.Head));
  //ShowMessage(IntToStr(Length(treq.QNAME)));
  mem.WriteBuffer(treq.QNAME[1], Length(treq.QNAME));
  mem.WriteBuffer(treq.QTYPE, SizeOf(treq.QTYPE));
  mem.WriteBuffer(treq.QCLASS, SizeOf(treq.QCLASS));

  SetLength(req, mem.size);
  mem.Seek(0, soFromBeginning);
  mem.ReadBuffer(req[1], mem.size);

  //--------------------------------------------------

  IdUDPClient1.Send('114.114.114.114', 53, req);

  res := IdUDPClient1.ReceiveString();


  //--------------------------------------------------
  //�������
  mem.Clear;

  mem.WriteBuffer(res[1], Length(res));
  mem.Seek(0, soFromBeginning);

  FillChar(tres.Head, SizeOf(tres.Head), 0);
  mem.ReadBuffer(tres.Head, SizeOf(tres.Head));

  tres.Head.ANCOUNT := ntohs(tres.Head.ANCOUNT);
  if tres.Head.ANCOUNT > 0 then
  begin //����д�����
    //
  end;  


  mem.Free;
end;

end.