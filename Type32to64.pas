unit Type32to64;

interface

//clq 为跨 ios64 位定义的通用整型数据类型
//可以直接参考 ios 的 uint16_t 这样类型
//通讯协议和读取代码表文件时都要用到

//uses
//  System;

type
  //uint16_t opCode;//:WORD;   //请求类型//word 为一个字等于两个字节，所以是 16 位
  //uint8_t Version;//:Byte;     //协议版本//目前 pc 端设置为 0, mac 为 1 具体按文档 "3.0结构与协议.doc"
  uint8   = Byte;
  uint16  = Word;//system.UInt16;//LongWord; //是否跨 32 64 可以看 xe10 的帮助
  uint32  = Cardinal;//:Cardinal;      //数据长度//Cardinal 也可以跨
  //int64   = System.UInt64;//d7 下没有 int64 和 unit64 的对子,所以直接用 int64 就可以了
  int8    = ShortInt;//system.Int8;
  int16   = SmallInt;
  int32   = Integer; //迷惑性,这个居然是跨平台的

  bool8 = False..Boolean(255); //基本上就是 xe10 中的 ByteBool//xe 10 下的 rtti 也支持
  //ByteBool2 = False..Boolean(256); //这个的字节就会变成2


  //比较有迷惑性的是 longword 并不是跨平台的

  //64 位 arm cpu 中原始 Trunc 有异常
  function Trunc64(X: Double): Int64;

implementation

//clq test
//function Trunc64(X: Real): Int64;
//{$ELSEIF defined(CPUARM)}
//function _Trunc(Val: Extended): Int64;
//var
//  SavedRoundMode: Int32;
//type
//  TWords = Array[0..3] of Word;
//  PWords = ^TWords;
//begin
//  if (PWords(@Val)^[3] and $7FFF) >= $43E0 then
//    FRaiseExcept(feeINVALID);
//  SavedRoundMode := FSetRound(ferTOWARDZERO);
//  Result := llrint(Val);
//  FSetRound(SavedRoundMode);
//end;
//{$ELSE}
function Trunc64(X: Double): Int64;
var
  yi:Double;
begin
  //原 Trunc 在某些情况下会溢出
  Result := 0;

  yi := 10000*10000;

  if x < yi*10000 * 100 then //100万亿
    Result := Trunc(x)
  else
    Result := 111;//999999;
end;



end.
