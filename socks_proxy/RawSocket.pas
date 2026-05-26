unit RawSocket;
{$mode objfpc}{$H+}

interface

uses
  SysUtils, BaseUnix;

type
  TSocket = Integer;

  TSockAddrIn = packed record
    sin_family: Word;
    sin_port: Word;
    sin_addr: LongWord;
    sin_zero: array[0..7] of Byte;
  end;

const
  AF_INET     = 2;
  SOCK_STREAM = 1;
  IPPROTO_TCP = 6;
  SHUT_RDWR   = 2;

function fpSocket(Domain, Typ, Protocol: Integer): TSocket; cdecl; external 'c' name 'socket';
function fpConnect(Sock: TSocket; var Addr: TSockAddrIn; AddrLen: Integer): Integer; cdecl; external 'c' name 'connect';
function fpBind(Sock: TSocket; var Addr: TSockAddrIn; AddrLen: Integer): Integer; cdecl; external 'c' name 'bind';
function fpListen(Sock: TSocket; Backlog: Integer): Integer; cdecl; external 'c' name 'listen';
function fpAccept(Sock: TSocket; var Addr: TSockAddrIn; var AddrLen: Integer): TSocket; cdecl; external 'c' name 'accept';
function fpSend(Sock: TSocket; Buf: Pointer; Len: Integer; Flags: LongInt): Integer; cdecl; external 'c' name 'send';
function fpRecv(Sock: TSocket; Buf: Pointer; Len: Integer; Flags: LongInt): Integer; cdecl; external 'c' name 'recv';
function fpShutdown(Sock: TSocket; How: Integer): Integer; cdecl; external 'c' name 'shutdown';
function fpClose(Sock: TSocket): Integer; cdecl; external 'c' name 'close';

function SocketCreate: TSocket;
function SocketConnect(Sock: TSocket; Addr: TSockAddrIn): Boolean;
function SocketBindListen(Sock: TSocket; Addr: TSockAddrIn; Queue: Integer): Boolean;
function SocketAccept(Sock: TSocket; out Addr: TSockAddrIn): TSocket;
function SocketSend(Sock: TSocket; Buf: Pointer; Len: Integer): Integer;
function SocketRecv(Sock: TSocket; Buf: Pointer; Len: Integer): Integer;
procedure SocketClose(Sock: TSocket);
function SocketRecvFull(Sock: TSocket; Buf: Pointer; Len: Integer): Integer;

implementation

function SocketCreate: TSocket;
begin
  Result := fpSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if Result < 0 then raise Exception.CreateFmt('socket() errno=%d', [fpGetErrno]);
end;

function SocketConnect(Sock: TSocket; Addr: TSockAddrIn): Boolean;
begin
  Result := fpConnect(Sock, Addr, SizeOf(Addr)) = 0;
  if not Result then raise Exception.CreateFmt('connect() errno=%d', [fpGetErrno]);
end;

function SocketBindListen(Sock: TSocket; Addr: TSockAddrIn; Queue: Integer): Boolean;
begin
  if fpBind(Sock, Addr, SizeOf(Addr)) < 0 then
    raise Exception.CreateFmt('bind() errno=%d', [fpGetErrno]);
  if fpListen(Sock, Queue) < 0 then
    raise Exception.CreateFmt('listen() errno=%d', [fpGetErrno]);
  Result := True;
end;

function SocketAccept(Sock: TSocket; out Addr: TSockAddrIn): TSocket;
var
  ALen: Integer;
  A: TSockAddrIn;
begin
  ALen := SizeOf(A);
  FillChar(A, SizeOf(A), 0);
  Result := fpAccept(Sock, A, ALen);
  Addr := A;
  if Result < 0 then raise Exception.CreateFmt('accept() errno=%d', [fpGetErrno]);
end;

function SocketSend(Sock: TSocket; Buf: Pointer; Len: Integer): Integer;
begin
  Result := fpSend(Sock, Buf, Len, 0);
  if Result < 0 then raise Exception.CreateFmt('send() errno=%d', [fpGetErrno]);
end;

function SocketRecv(Sock: TSocket; Buf: Pointer; Len: Integer): Integer;
begin
  Result := fpRecv(Sock, Buf, Len, 0);
  if Result < 0 then raise Exception.CreateFmt('recv() errno=%d', [fpGetErrno]);
end;

procedure SocketClose(Sock: TSocket);
begin
  fpShutdown(Sock, SHUT_RDWR);
  fpClose(Sock);
end;

function SocketRecvFull(Sock: TSocket; Buf: Pointer; Len: Integer): Integer;
var
  Need, Got: Integer;
  P: PByte;
begin
  P := Buf;
  Need := Len;
  Result := 0;
  while Need > 0 do
  begin
    Got := fpRecv(Sock, P, Need, 0);
    if Got <= 0 then Break;
    inc(P, Got);
    dec(Need, Got);
    inc(Result, Got);
  end;
  if Need > 0 then raise Exception.CreateFmt('recv partial: got %d of %d', [Result, Len]);
end;

end.
