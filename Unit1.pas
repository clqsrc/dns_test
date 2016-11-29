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
  //dns 的请求和响应都是同一格式
  TDnsReq = packed record


  end;

  //Tag:uint16; //这个用一个虚拟的结构计算后转换出来
  VDnsHead_tag = packed record
    QR :uint8; //(1比特)：查询/响应的标志位，1为响应，0为查询。
    opcode :uint32; //(4比特)：定义查询或响应的类型(若为0则表示是标准的，若为1则是反向的，若为2则是服务器状态请求)。
    AA :uint8; //(1比特)：授权回答的标志位。该位在响应报文中有效，1表示名字服务器是权限服务器(关于权限服务器以后再讨论)
    TC :uint8; //(1比特)：截断标志位。1表示响应已超过512字节并已被截断(依稀好像记得哪里提过这个截断和UDP有关，先记着)
    RD :uint8; //(1比特)：该位为1表示客户端希望得到递归回答(递归以后再讨论) //请求中基本只需要改这个,其余都为 0
    RA :uint8; //(1比特)：只能在响应报文中置为1，表示可以得到递归响应。
    zero :array[0..2] of uint8; //(3比特)：不说也知道都是0了，保留字段。
    rcode :uint32; //(4比特)：返回码，表示响应的差错状态，通常为0和3

  end;


  //dns 的头部固定为 12 字节(12x8=96位)
  TDnsHead = packed record
    ID:uint16;  //随机的对话 id 而已,用于确定响应是否是自己请求得到的
    //Tag:uint16; //这个用一个虚拟的结构计算后转换出来
    Flags:uint16; //这个用一个虚拟的结构计算后转换出来 //请求一般是 0x100

    QDCOUNT:uint16; //占16位，2字节。查询记录的个数 //问题数    //请求中一般为 1
    ANCOUNT:uint16; //占16位，2字节。回复记录的个数 //回答RR数  //请求中一般为 0
    NSCOUNT:uint16; //占16位，2字节。权威记录的个数 //权威RR数  //请求中一般为 0
    ARCOUNT:uint16; //占16位，2字节。格外记录的个数 //附加RR数  //请求中一般为 0

  end;

  TDnsRequest = packed record
    Head:TDnsHead;
    QNAME:string; //要查询的域名,但格式特殊,域名中的 . 要变成字数 //bbs.zzsy.com=>3bbs4zzsy3com0　以.分开bbs、zzsy、com三个部分。每个部分的长度为3、4、3
    QTYPE:uint16;  //查询类型,一般是指 A 记录还是 MX 记录//
    //***//A=0x01, //指定计算机 IP 地址。
    //NS=0x02, //指定用于命名区域的 DNS 名称服务器。
    //MD=0x03, //指定邮件接收站（此类型已经过时了，使用MX代替）
    //MF=0x04, //指定邮件中转站（此类型已经过时了，使用MX代替）
    //CNAME=0x05, //指定用于别名的规范名称。
    //SOA=0x06, //指定用于 DNS 区域的“起始授权机构”。
    //MB=0x07, //指定邮箱域名。
    //MG=0x08, //指定邮件组成员。
    //MR=0x09, //指定邮件重命名域名。
    //NULL=0x0A, //指定空的资源记录
    //WKS=0x0B, //描述已知服务。
    //PTR=0x0C, //如果查询是 IP 地址，则指定计算机名；否则指定指向其它信息的指针。
    //HINFO=0x0D, //指定计算机 CPU 以及操作系统类型。
    //MINFO=0x0E, //指定邮箱或邮件列表信息。
    //***//MX=0x0F, //指定邮件交换器。
    //TXT=0x10, //指定文本信息。
    //AAAA=0x1c,//IPV6资源记录。
    //UINFO=0x64, //指定用户信息。
    //UID=0x65, //指定用户标识符。
    //GID=0x66, //指定组名的组标识符。
    //ANY=0xFF //指定所有数据类型。

    QCLASS:uint16; //请求的网络类型,一般都是 internet
    //***///IN=0x01, //指定 Internet 类别。
    //CSNET=0x02, //指定 CSNET 类别。（已过时）
    //CHAOS=0x03, //指定 Chaos 类别。
    //HESIOD=0x04,//指定 MIT Athena Hesiod 类别。
    //ANY=0xFF //指定任何以前列出的通配符。
  end;

  //回应报文
  TDnsResponse = packed record
    Head:TDnsHead;
    QNAME:string; //要查询的域名,但格式特殊,域名中的 . 要变成字数 //bbs.zzsy.com=>3bbs4zzsy3com0　以.分开bbs、zzsy、com三个部分。每个部分的长度为3、4、3
    QTYPE:uint16;  //查询类型,一般是指 A 记录还是 MX 记录//

  end;


//域名转为报文格式
//bbs.zzsy.com=>3bbs4zzsy3com0　以.分开bbs、zzsy、com三个部分。每个部分的长度为3、4、3
function GetHostPack(host:string):string;
var
  i:Integer;
  c:AnsiChar;
  count:Integer;
begin
  //因为数字在前,所以逆循环比较好

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

  Result := AnsiChar(count) + Result; //最后再来一次

  Result := Result +#0; //好象还要加结束符号


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
  tres:TDnsResponse; //回应报文

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
  treq.Head.QDCOUNT := htons(1);//1;  //一个请求

  //treq.Head.Tag;

  //--------------------------------------------------
  FillChar(reqTag, SizeOf(reqTag), 0);
  reqTag.QR := 0; //1为响应，0为查询。
  reqTag.RD := 1; //希望得到递归回答//只有才可能为 1,所以实际上 tag 对请求来说可以是固定是,晃需要位操作的

  ////
  treq.Head.Flags := htons($100);//0;
  //treq.Head.Flags := 0; //好象没影响
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
  //解析结果
  mem.Clear;

  mem.WriteBuffer(res[1], Length(res));
  mem.Seek(0, soFromBeginning);

  FillChar(tres.Head, SizeOf(tres.Head), 0);
  mem.ReadBuffer(tres.Head, SizeOf(tres.Head));

  tres.Head.ANCOUNT := ntohs(tres.Head.ANCOUNT);
  if tres.Head.ANCOUNT > 0 then
  begin //如果有答复内容
    //
  end;  


  mem.Free;
end;

end.
