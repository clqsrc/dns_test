unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, IdBaseComponent, IdComponent, IdUDPBase, IdUDPClient, WinSock,
  Sockets, IdTCPConnection, IdTCPClient;

type
  TForm1 = class(TForm)
    Button1: TButton;
    UdpSocket1: TUdpSocket;
    IdUDPClient1: TIdUDPClient;
    IdTCPClient1: TIdTCPClient;
    Edit1: TEdit;
    Memo1: TMemo;
    Button2: TButton;
    txtDns: TComboBox;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
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

  //请求报文//其中的资源部分
  TDnsQuery = packed record
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


  TDnsRequest = packed record
    Head:TDnsHead;
    Query:TDnsQuery; //这里其实应该是 Queries 的数组,不过一般就查一个,所以简写好了
  end;

  (*
    域名(2字节或不定长)

    记录中资源数据对应的名字，它的格式和查询名字段格式相同。当报文中域名重复出现时，就需要使用2字节的偏移指针来替换。例如，在资源记录中，域名通常是查询问题部分的域名的重复，就需要用指针指向查询问题部分的域名。关于指针怎么用，TCP/IP详解里面有，即2字节的指针，最前面的两个高位是11，用于识别指针。其他14位从报文开始处计数(从0开始)，指出该报文中的相应字节数。注意，DNS报文的第一个字节是字节0，第二个报文是字节1。一般响应报文中，资源部分的域名都是指针C00C(1100000000001100，12正好是首部区域的长度)，刚好指向请求部分的域名[1]。
  *)


  //回应报文//其中的资源部分
  TDnsAnswer = packed record
    RNAME:string; //:回复查询的域名，不定长。
    //RNAME_P:uint16;//c0 0c 为域名指针//实际这里都为指针,不写实际的域名字符串//似乎是2字节//c0 似乎是固定的指针值, 0c 表示 12,刚好是头部后请求的域名,用来表示重复的域名部分,这个值并不是固定的,所以要另外计算
    RTYPE:uint16; //:回复的类型。2字节，与查询同义。指示RDATA中的资源记录类型。
    RCLASS:uint16; //:回复的类。2字节，与查询同义。指示RDATA中的资源记录类。
    RTTL:uint32; //:生存时间。4字节，指示RDATA中的资源记录在缓存的生存时间。
    RDLENGTH:uint16; //:长度。2字节，指示RDATA块的长度。
    RDATA:string; //:资源记录。不定义，依TYPE的不同，此记录的格示不同，通常一个MX记录是由一个2字节的指示该邮件交换器的优先级值及不定长的邮件交换器名组成的。


  end;



  //回应报文
  TDnsResponse = packed record
    Head:TDnsHead;
    Queries:array of TDnsQuery;  //响应中的内容,只要第一个也是可以的//响应中也有请求
    Answers:array of TDnsAnswer; //响应中的内容,只要第一个也是可以的
    IP:array of string; //从 TDnsAnswer 中计算出来的 ip
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
  i,k:Integer;
  ip:string;

  //从应答中读出一个域名,刚好它是 #0 结尾的,所以可以简化
  function ReadName:string;
  var
    j:Integer;
    c:AnsiChar;
    oldPos:Integer; //因为有两字节表示指针的部分,所以要记录当前的位置
    offset:uint16;
    tmp:string;
    _count:Integer;
  begin


    Result := '';
    _count := 0;

    while mem.Position < mem.Size do
    begin

      //--------------------------------------------------
      //要先看看是不是指针,指针的话是两个字节表示位置,同时在第一个字节的前两位为11 即  11000000 (0xC0)(192)
      oldPos := mem.Position;
      mem.Read(c, 1);
      if Byte(c)>=192 then
      begin
        mem.Position := oldPos; //这个读取只是试探性的,所以要恢复位置
        mem.Read(offset, 2);
        //offset := offset and
        offset := ntohs(offset);
        offset := offset - $C000; //0xC000 = 49152

        //OFFSET字段指定相对于消息开始处（就是域首部中ID字段的第一个字节）的偏移量。0 偏移量指的是 ID 字段的第一个字节，等等。
        //即原始完整数据 res 的起始位置

        tmp := Copy(res, offset+1, Length(res));
        tmp := PAnsiChar(tmp); //不能全部要,#0 后的要去掉 //其实这里面的数据也可能会有指针,不过要解析这种的话就要用递归了,所以算了
        Result := Result + tmp;

        //mem.Position := mem.Position + Length(tmp);

        Break; //指针的格式在域名时只会出现在末端,所以得跳出,因为这时就结束了,再读取一个 0 是不对的

        //Exit;
      end
      //--------------------------------------------------
      //正常的是一个字节的长度加字符串
      else
      begin
        if c = #0 then Break;

        SetLength(tmp, Byte(c));
        mem.Read(tmp[1], Byte(c));

        if Result<>'' then Result := Result + '.';

        Result := Result + tmp;
      end;

      if mem.Position>=mem.Size  //长度保护
      then Break;

      Inc(_count);
      if _count>1000 //次数保护
      then Break;

    end;//while


    Exit;

    //--------------------------------------------------
    for j := mem.Position to mem.Size-1 do
    begin
      mem.Read(c, 1);

      Result := Result + c;

      if c = #0 then Break;
    end;

    //mem.Position := oldPos;
  end;


  //从应答中读出一个域名,可递归的,读取后要回到当前位置//raw 是原始字符串 //level 是递归的层次,防止死循环
  function ReadName2(const raw:string; const level:Integer):string;
  var
    j:Integer;
    c:AnsiChar;
    oldPos:Integer; //因为有两字节表示指针的部分,所以要记录当前的位置
    offset:uint16;
    tmp:string;
    _count:Integer;
    fmem:TMemoryStream;
  begin
    Result := '';

    //if level > 1 then Exit; //递归层次保护
    if level > 9 then Exit; //递归层次保护

    fmem := TMemoryStream.Create;
    //fmem.WriteBuffer(res[1], Length(res));
    fmem.WriteBuffer(raw[1], Length(raw));
    fmem.Seek(0, soFromBeginning);

    //--------------------------------------------------

    Result := '';
    _count := 0;

    while fmem.Position < fmem.Size do
    begin

      //--------------------------------------------------
      //要先看看是不是指针,指针的话是两个字节表示位置,同时在第一个字节的前两位为11 即  11000000 (0xC0)(192)
      oldPos := fmem.Position;
      fmem.Read(c, 1);
      if Byte(c)>=192 then
      begin
        fmem.Position := oldPos; //这个读取只是试探性的,所以要恢复位置
        fmem.Read(offset, 2);

        offset := ntohs(offset);
        offset := offset - $C000; //0xC000 = 49152

        //OFFSET字段指定相对于消息开始处（就是域首部中ID字段的第一个字节）的偏移量。0 偏移量指的是 ID 字段的第一个字节，等等。
        //即原始完整数据 res 的起始位置

        tmp := Copy(res, offset+1, Length(res));
        ////tmp := PAnsiChar(tmp); //不能全部要,#0 后的要去掉 //其实这里面的数据也可能会有指针,不过要解析这种的话就要用递归了,所以算了

        tmp := ReadName2(tmp, level + 1);//真正的算法应该递归

        if Result<>'' then Result := Result + '.';
        
        Result := Result + tmp;

        //fmem.Position := fmem.Position + Length(tmp);

        Break; //指针的格式在域名时只会出现在末端,所以得跳出,因为这时就结束了,再读取一个 0 是不对的

        //Exit;
      end
      //--------------------------------------------------
      //正常的是一个字节的长度加字符串
      else
      begin
        if c = #0 then Break;

        SetLength(tmp, Byte(c));
        fmem.Read(tmp[1], Byte(c));

        if Result<>'' then Result := Result + '.';

        Result := Result + tmp;
      end;

      if fmem.Position>=fmem.Size  //长度保护
      then Break;

      Inc(_count);
      if _count>1000 //次数保护
      then Break;

    end;//while


    fmem.Free;

  end;

  //从应答中读出原始字符串
  function ReadName_raw:string;
  var
    j:Integer;
    c:AnsiChar;
    oldPos:Integer; //因为有两字节表示指针的部分,所以要记录当前的位置
    offset:uint16;
    tmp:string;
    _count:Integer;
  begin


    Result := '';
    _count := 0;

    while mem.Position < mem.Size do
    begin

      //--------------------------------------------------
      //要先看看是不是指针,指针的话是两个字节表示位置,同时在第一个字节的前两位为11 即  11000000 (0xC0)(192)
      oldPos := mem.Position;
      mem.Read(c, 1);
      if Byte(c)>=192 then
      begin
        mem.Position := oldPos; //这个读取只是试探性的,所以要恢复位置
        //mem.Read(offset, 2);
        SetLength(tmp, 2);
        mem.Read(tmp[1], 2);


        Result := Result + tmp;

        //mem.Position := mem.Position + Length(tmp);

        Break; //指针的格式在域名时只会出现在末端,所以得跳出,因为这时就结束了,再读取一个 0 是不对的

        //Exit;
      end
      //--------------------------------------------------
      //正常的是一个字节的长度加字符串
      else
      begin
        Result := Result + c;
        if c = #0 then Break;

        SetLength(tmp, Byte(c));
        mem.Read(tmp[1], Byte(c));

        //if Result<>'' then Result := Result + '.';

        Result := Result + tmp;
      end;

      if mem.Position>=mem.Size  //长度保护
      then Break;

      Inc(_count);
      if _count>1000 //次数保护
      then Break;

    end;//while

  end;


begin

  req := '';
  res := '';

  host := 'www.baidu.com';
  //host := 'lib.csdn.net';
  host := Edit1.Text;

  host := GetHostPack(host);

  treq.Query.QNAME := host;
  treq.Query.QTYPE := htons(1);//$f; // A=0x01, MX=0x0F,
  ////treq.QTYPE := htons($f);//$f; // A=0x01, MX=0x0F,
  treq.Query.QCLASS := htons(1); // internet

  FillChar(treq.Head, SizeOf(treq.Head), 0);
  Randomize();
  treq.Head.ID := Trunc((Now - Trunc(Now)) * 100000) + Random(10000);
  treq.Head.QDCOUNT := htons(1);//1;  //一个请求

  //treq.Head.Tag;

  //--------------------------------------------------
  FillChar(reqTag, SizeOf(reqTag), 0);
  reqTag.QR := 0; //1为响应，0为查询。
  reqTag.RD := 1; //希望得到递归回答//只有它才可能为 1,所以实际上 Flags 对请求来说可以是固定是,不需要位操作的

  ////
  treq.Head.Flags := htons($100);//0;
  //treq.Head.Flags := 0; //好象没影响 //实际上 Flags 对请求来说可以是固定是,不需要位操作的//见上面
  //--------------------------------------------------

  mem := TMemoryStream.Create;

  //mem.WriteBuffer('aaa'[1], 3);
  mem.WriteBuffer(treq.Head, SizeOf(treq.Head));
  //ShowMessage(IntToStr(Length(treq.QNAME)));
  mem.WriteBuffer(treq.Query.QNAME[1], Length(treq.Query.QNAME));
  mem.WriteBuffer(treq.Query.QTYPE, SizeOf(treq.Query.QTYPE));
  mem.WriteBuffer(treq.Query.QCLASS, SizeOf(treq.Query.QCLASS));

  SetLength(req, mem.size);
  mem.Seek(0, soFromBeginning);
  mem.ReadBuffer(req[1], mem.size);

  //--------------------------------------------------

  //IdUDPClient1.Send('114.114.114.114', 53, req);
  IdUDPClient1.Send(txtDns.Text, 53, req);

  res := IdUDPClient1.ReceiveString();


  //--------------------------------------------------
  //解析结果
  mem.Clear;

  mem.WriteBuffer(res[1], Length(res));
  mem.Seek(0, soFromBeginning);

  FillChar(tres.Head, SizeOf(tres.Head), 0);
  mem.ReadBuffer(tres.Head, SizeOf(tres.Head));

  tres.Head.QDCOUNT := ntohs(tres.Head.QDCOUNT);
  tres.Head.ANCOUNT := ntohs(tres.Head.ANCOUNT);

  //实际上要先读出请求
  if tres.Head.QDCOUNT > 0 then
  begin
    //
    SetLength(tres.Queries, tres.Head.QDCOUNT);

    for i := 0 to tres.Head.QDCOUNT-1 do
    begin
      tres.Queries[i].QNAME := ReadName();
      mem.ReadBuffer(tres.Queries[i].QTYPE, SizeOf(tres.Queries[i].QTYPE));
      mem.ReadBuffer(tres.Queries[i].QCLASS, SizeOf(tres.Queries[i].QCLASS));


      tres.Queries[i].QTYPE := htons(tres.Queries[i].QTYPE);
      tres.Queries[i].QCLASS := htons(tres.Queries[i].QCLASS);

    end;

  end;



  if tres.Head.ANCOUNT > 0 then
  begin //如果有答复内容
    //
    SetLength(tres.Answers, tres.Head.ANCOUNT);
    SetLength(tres.IP, tres.Head.ANCOUNT);

    for i := 0 to tres.Head.ANCOUNT-1 do
    begin
      //tres.Answers[i].RNAME := ReadName();
      //mem.ReadBuffer(tres.Answers[i].RNAME_P, SizeOf(tres.Answers[i].RNAME_P));
      //tres.Answers[i].RNAME := ReadName();
      tres.Answers[i].RNAME := ReadName_raw();

      tres.Answers[i].RNAME := ReadName2(tres.Answers[i].RNAME, 1); //test 只是验证算法,因为有递归,实际应用中不要用

      mem.ReadBuffer(tres.Answers[i].RTYPE, SizeOf(tres.Answers[i].RTYPE));
      mem.ReadBuffer(tres.Answers[i].RCLASS, SizeOf(tres.Answers[i].RCLASS));
      mem.ReadBuffer(tres.Answers[i].RTTL, SizeOf(tres.Answers[i].RTTL));
      mem.ReadBuffer(tres.Answers[i].RDLENGTH, SizeOf(tres.Answers[i].RDLENGTH));

      tres.Answers[i].RTTL := ntohl(tres.Answers[i].RTTL);
      tres.Answers[i].RDLENGTH := htons(tres.Answers[i].RDLENGTH);

      SetLength(tres.Answers[i].RDATA, tres.Answers[i].RDLENGTH);
      FillChar(tres.Answers[i].RDATA[1], tres.Answers[i].RDLENGTH, 0);
      mem.ReadBuffer(tres.Answers[i].RDATA[1], tres.Answers[i].RDLENGTH); //这个有点特殊,要小心 //对于 A 和 MX 请求这里应该就是 4 字节或者 6 字节(ipv6的情况下) ip ////AAAA=0x1c,//IPV6资源记录。

      ip := '';
      tres.Answers[i].RTYPE := ntohs(tres.Answers[i].RTYPE);

      if tres.Answers[i].RTYPE = 5 then //5 是 CNAME
      begin
        for k := 1 to Length(tres.Answers[i].RDATA) do
        begin
          ip := ip + tres.Answers[i].RDATA[k]; //cname 的时候就是域名的别名,不用算点分结构//实际上这里面还含有指针,例如 www.baidu.com 的第一个
        end;

        ip := ReadName2(tres.Answers[i].RDATA, 1); //test 只是验证算法,因为有递归,实际应用中不要用


      end
      else
      //if tres.Answers[i].RTYPE = 1 then //1 是 A 记录,但是有可能是 mx 记录,所以直接解析成 ip 好了
      begin

        for k := 1 to Length(tres.Answers[i].RDATA) do
        begin
          ip := ip + IntToStr(Byte(tres.Answers[i].RDATA[k]));

          if k < Length(tres.Answers[i].RDATA) then
            ip := ip + '.';
        end;


      end;

      tres.IP[i] := ip;

    end;

  end;


  mem.Free;

  //--------------------------------------------------
  for i := 0 to Length(tres.IP)-1 do
  begin
    Memo1.Lines.Add(tres.ip[i]);
  end;

end;

procedure TForm1.Button2Click(Sender: TObject);
var
  req:string;
  res:string;
  b1:TBits;
  host:string;
  treq:TDnsRequest;
  reqTag:VDnsHead_tag;
  mem:TMemoryStream;
  tres:TDnsResponse; //回应报文
  i,k:Integer;
  ip:string;
  resLen:Integer;
  reqLen:Integer;
  tcpLen:int16;


  //从应答中读出一个域名,刚好它是 #0 结尾的,所以可以简化
  function ReadName:string;
  var
    j:Integer;
    c:AnsiChar;
    oldPos:Integer; //因为有两字节表示指针的部分,所以要记录当前的位置
    offset:uint16;
    tmp:string;
    _count:Integer;
  begin


    Result := '';
    _count := 0;

    while mem.Position < mem.Size do
    begin

      //--------------------------------------------------
      //要先看看是不是指针,指针的话是两个字节表示位置,同时在第一个字节的前两位为11 即  11000000 (0xC0)(192)
      oldPos := mem.Position;
      mem.Read(c, 1);
      if Byte(c)>=192 then
      begin
        mem.Position := oldPos; //这个读取只是试探性的,所以要恢复位置
        mem.Read(offset, 2);
        //offset := offset and
        offset := ntohs(offset);
        offset := offset - $C000; //0xC000 = 49152

        //OFFSET字段指定相对于消息开始处（就是域首部中ID字段的第一个字节）的偏移量。0 偏移量指的是 ID 字段的第一个字节，等等。
        //即原始完整数据 res 的起始位置

        tmp := Copy(res, offset+1, Length(res));
        tmp := PAnsiChar(tmp); //不能全部要,#0 后的要去掉 //其实这里面的数据也可能会有指针,不过要解析这种的话就要用递归了,所以算了
        Result := Result + tmp;

        //mem.Position := mem.Position + Length(tmp);

        Break; //指针的格式在域名时只会出现在末端,所以得跳出,因为这时就结束了,再读取一个 0 是不对的

        //Exit;
      end
      //--------------------------------------------------
      //正常的是一个字节的长度加字符串
      else
      begin
        if c = #0 then Break;

        SetLength(tmp, Byte(c));
        mem.Read(tmp[1], Byte(c));

        if Result<>'' then Result := Result + '.';

        Result := Result + tmp;
      end;

      if mem.Position>=mem.Size  //长度保护
      then Break;

      Inc(_count);
      if _count>1000 //次数保护
      then Break;

    end;//while


    Exit;

    //--------------------------------------------------
    for j := mem.Position to mem.Size-1 do
    begin
      mem.Read(c, 1);

      Result := Result + c;

      if c = #0 then Break;
    end;

    //mem.Position := oldPos;
  end;


  //从应答中读出一个域名,可递归的,读取后要回到当前位置//raw 是原始字符串 //level 是递归的层次,防止死循环
  function ReadName2(const raw:string; const level:Integer):string;
  var
    j:Integer;
    c:AnsiChar;
    oldPos:Integer; //因为有两字节表示指针的部分,所以要记录当前的位置
    offset:uint16;
    tmp:string;
    _count:Integer;
    fmem:TMemoryStream;
  begin
    Result := '';

    //if level > 1 then Exit; //递归层次保护
    if level > 9 then Exit; //递归层次保护

    fmem := TMemoryStream.Create;
    //fmem.WriteBuffer(res[1], Length(res));
    fmem.WriteBuffer(raw[1], Length(raw));
    fmem.Seek(0, soFromBeginning);

    //--------------------------------------------------

    Result := '';
    _count := 0;

    while fmem.Position < fmem.Size do
    begin

      //--------------------------------------------------
      //要先看看是不是指针,指针的话是两个字节表示位置,同时在第一个字节的前两位为11 即  11000000 (0xC0)(192)
      oldPos := fmem.Position;
      fmem.Read(c, 1);
      if Byte(c)>=192 then
      begin
        fmem.Position := oldPos; //这个读取只是试探性的,所以要恢复位置
        fmem.Read(offset, 2);

        offset := ntohs(offset);
        offset := offset - $C000; //0xC000 = 49152

        //OFFSET字段指定相对于消息开始处（就是域首部中ID字段的第一个字节）的偏移量。0 偏移量指的是 ID 字段的第一个字节，等等。
        //即原始完整数据 res 的起始位置

        tmp := Copy(res, offset+1, Length(res));
        ////tmp := PAnsiChar(tmp); //不能全部要,#0 后的要去掉 //其实这里面的数据也可能会有指针,不过要解析这种的话就要用递归了,所以算了

        tmp := ReadName2(tmp, level + 1);//真正的算法应该递归

        if Result<>'' then Result := Result + '.';

        Result := Result + tmp;

        //fmem.Position := fmem.Position + Length(tmp);

        Break; //指针的格式在域名时只会出现在末端,所以得跳出,因为这时就结束了,再读取一个 0 是不对的

        //Exit;
      end
      //--------------------------------------------------
      //正常的是一个字节的长度加字符串
      else
      begin
        if c = #0 then Break;

        SetLength(tmp, Byte(c));
        fmem.Read(tmp[1], Byte(c));

        if Result<>'' then Result := Result + '.';

        Result := Result + tmp;
      end;

      if fmem.Position>=fmem.Size  //长度保护
      then Break;

      Inc(_count);
      if _count>1000 //次数保护
      then Break;

    end;//while


    fmem.Free;

  end;

  //从应答中读出原始字符串
  function ReadName_raw:string;
  var
    j:Integer;
    c:AnsiChar;
    oldPos:Integer; //因为有两字节表示指针的部分,所以要记录当前的位置
    offset:uint16;
    tmp:string;
    _count:Integer;
  begin


    Result := '';
    _count := 0;

    while mem.Position < mem.Size do
    begin

      //--------------------------------------------------
      //要先看看是不是指针,指针的话是两个字节表示位置,同时在第一个字节的前两位为11 即  11000000 (0xC0)(192)
      oldPos := mem.Position;
      mem.Read(c, 1);
      if Byte(c)>=192 then
      begin
        mem.Position := oldPos; //这个读取只是试探性的,所以要恢复位置
        //mem.Read(offset, 2);
        SetLength(tmp, 2);
        mem.Read(tmp[1], 2);


        Result := Result + tmp;

        //mem.Position := mem.Position + Length(tmp);

        Break; //指针的格式在域名时只会出现在末端,所以得跳出,因为这时就结束了,再读取一个 0 是不对的

        //Exit;
      end
      //--------------------------------------------------
      //正常的是一个字节的长度加字符串
      else
      begin
        Result := Result + c;
        if c = #0 then Break;

        SetLength(tmp, Byte(c));
        mem.Read(tmp[1], Byte(c));

        //if Result<>'' then Result := Result + '.';

        Result := Result + tmp;
      end;

      if mem.Position>=mem.Size  //长度保护
      then Break;

      Inc(_count);
      if _count>1000 //次数保护
      then Break;

    end;//while

  end;


begin

  req := '';
  res := '';

  host := 'www.baidu.com';
  //host := 'lib.csdn.net';
  host := Edit1.Text;

  host := GetHostPack(host);

  treq.Query.QNAME := host;
  treq.Query.QTYPE := htons(1);//$f; // A=0x01, MX=0x0F,
  ////treq.QTYPE := htons($f);//$f; // A=0x01, MX=0x0F,
  treq.Query.QCLASS := htons(1); // internet

  FillChar(treq.Head, SizeOf(treq.Head), 0);
  Randomize();
  treq.Head.ID := Trunc((Now - Trunc(Now)) * 100000) + Random(10000);
  treq.Head.QDCOUNT := htons(1);//1;  //一个请求

  //treq.Head.Tag;

  //--------------------------------------------------
  FillChar(reqTag, SizeOf(reqTag), 0);
  reqTag.QR := 0; //1为响应，0为查询。
  reqTag.RD := 1; //希望得到递归回答//只有它才可能为 1,所以实际上 Flags 对请求来说可以是固定是,不需要位操作的

  ////
  treq.Head.Flags := htons($100);//0;
  //treq.Head.Flags := 0; //好象没影响 //实际上 Flags 对请求来说可以是固定是,不需要位操作的//见上面
  //--------------------------------------------------

  mem := TMemoryStream.Create;

  //mem.WriteBuffer('aaa'[1], 3);
  mem.WriteBuffer(tcpLen, SizeOf(tcpLen)); //tcp 要先写两字节的长度
  mem.WriteBuffer(treq.Head, SizeOf(treq.Head));
  //ShowMessage(IntToStr(Length(treq.QNAME)));
  mem.WriteBuffer(treq.Query.QNAME[1], Length(treq.Query.QNAME));
  mem.WriteBuffer(treq.Query.QTYPE, SizeOf(treq.Query.QTYPE));
  mem.WriteBuffer(treq.Query.QCLASS, SizeOf(treq.Query.QCLASS));

  tcpLen := mem.Size - 2;              //tcp 要先写两字节的长度
  tcpLen := htons(tcpLen);             //tcp 要先写两字节的长度
  mem.Seek(0, soFromBeginning);     //tcp 要先写两字节的长度
  mem.WriteBuffer(tcpLen, SizeOf(tcpLen)); //tcp 要先写两字节的长度

  SetLength(req, mem.size);
  mem.Seek(0, soFromBeginning);
  mem.ReadBuffer(req[1], mem.size);

  //--------------------------------------------------

  ////IdUDPClient1.Send('114.114.114.114', 53, req);
  ////res := IdUDPClient1.ReceiveString();

  //reqLen := IdUDPClient1.Send(txtDns.Text, 53, req);
  IdTCPClient1.Host := txtDns.Text;
  IdTCPClient1.Port := 53;
  IdTCPClient1.Disconnect;
  IdTCPClient1.Connect(10*1000);
  reqLen := IdTCPClient1.Socket.Send(req[1], Length(req));
  Memo1.Lines.Add(IntToStr(reqLen));
  res := ''; SetLength(res, 4096);
  //Sleep(5*1000);
  if IdTCPClient1.Socket.Readable(5*1000) = False then
  begin
    Memo1.Lines.Add('read error');
    Exit;
  end;  
  resLen := IdTCPClient1.Socket.Recv(res[1], Length(res));
  SetLength(res, resLen);
  Memo1.Lines.Add(IntToStr(resLen));




  //--------------------------------------------------
  //解析结果
  mem.Clear;

  res := Copy(res, 1+2, Length(res));  //mem.WriteBuffer(tcpLen, SizeOf(tcpLen)); //tcp 要先写两字节的长度//这样不行,因为还要算域名指针偏移量,所以应该直接减少原始字符串的


  mem.WriteBuffer(res[1], Length(res));
  mem.Seek(0, soFromBeginning);

  //mem.WriteBuffer(tcpLen, SizeOf(tcpLen)); //tcp 要先写两字节的长度//这样不行,因为还要算域名指针偏移量,所以应该直接减少原始字符串的

  FillChar(tres.Head, SizeOf(tres.Head), 0);
  mem.ReadBuffer(tres.Head, SizeOf(tres.Head));

  tres.Head.QDCOUNT := ntohs(tres.Head.QDCOUNT);
  tres.Head.ANCOUNT := ntohs(tres.Head.ANCOUNT);

  //实际上要先读出请求
  if tres.Head.QDCOUNT > 0 then
  begin
    //
    SetLength(tres.Queries, tres.Head.QDCOUNT);

    for i := 0 to tres.Head.QDCOUNT-1 do
    begin
      tres.Queries[i].QNAME := ReadName();
      mem.ReadBuffer(tres.Queries[i].QTYPE, SizeOf(tres.Queries[i].QTYPE));
      mem.ReadBuffer(tres.Queries[i].QCLASS, SizeOf(tres.Queries[i].QCLASS));


      tres.Queries[i].QTYPE := htons(tres.Queries[i].QTYPE);
      tres.Queries[i].QCLASS := htons(tres.Queries[i].QCLASS);

    end;

  end;



  if tres.Head.ANCOUNT > 0 then
  begin //如果有答复内容
    //
    SetLength(tres.Answers, tres.Head.ANCOUNT);
    SetLength(tres.IP, tres.Head.ANCOUNT);

    for i := 0 to tres.Head.ANCOUNT-1 do
    begin
      //tres.Answers[i].RNAME := ReadName();
      //mem.ReadBuffer(tres.Answers[i].RNAME_P, SizeOf(tres.Answers[i].RNAME_P));
      //tres.Answers[i].RNAME := ReadName();
      tres.Answers[i].RNAME := ReadName_raw();

      tres.Answers[i].RNAME := ReadName2(tres.Answers[i].RNAME, 1); //test 只是验证算法,因为有递归,实际应用中不要用

      mem.ReadBuffer(tres.Answers[i].RTYPE, SizeOf(tres.Answers[i].RTYPE));
      mem.ReadBuffer(tres.Answers[i].RCLASS, SizeOf(tres.Answers[i].RCLASS));
      mem.ReadBuffer(tres.Answers[i].RTTL, SizeOf(tres.Answers[i].RTTL));
      mem.ReadBuffer(tres.Answers[i].RDLENGTH, SizeOf(tres.Answers[i].RDLENGTH));

      tres.Answers[i].RTTL := ntohl(tres.Answers[i].RTTL);
      tres.Answers[i].RDLENGTH := htons(tres.Answers[i].RDLENGTH);

      SetLength(tres.Answers[i].RDATA, tres.Answers[i].RDLENGTH);
      FillChar(tres.Answers[i].RDATA[1], tres.Answers[i].RDLENGTH, 0);
      mem.ReadBuffer(tres.Answers[i].RDATA[1], tres.Answers[i].RDLENGTH); //这个有点特殊,要小心 //对于 A 和 MX 请求这里应该就是 4 字节或者 6 字节(ipv6的情况下) ip ////AAAA=0x1c,//IPV6资源记录。

      ip := '';
      tres.Answers[i].RTYPE := ntohs(tres.Answers[i].RTYPE);

      if tres.Answers[i].RTYPE = 5 then //5 是 CNAME
      begin
        for k := 1 to Length(tres.Answers[i].RDATA) do
        begin
          ip := ip + tres.Answers[i].RDATA[k]; //cname 的时候就是域名的别名,不用算点分结构//实际上这里面还含有指针,例如 www.baidu.com 的第一个
        end;

        ip := ReadName2(tres.Answers[i].RDATA, 1); //test 只是验证算法,因为有递归,实际应用中不要用


      end
      else
      //if tres.Answers[i].RTYPE = 1 then //1 是 A 记录,但是有可能是 mx 记录,所以直接解析成 ip 好了
      begin

        for k := 1 to Length(tres.Answers[i].RDATA) do
        begin
          ip := ip + IntToStr(Byte(tres.Answers[i].RDATA[k]));

          if k < Length(tres.Answers[i].RDATA) then
            ip := ip + '.';
        end;


      end;

      tres.IP[i] := ip;

    end;

  end;


  mem.Free;

  //--------------------------------------------------
  for i := 0 to Length(tres.IP)-1 do
  begin
    Memo1.Lines.Add(tres.ip[i]);
  end;


end;

end.













