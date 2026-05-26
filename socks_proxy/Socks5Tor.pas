unit Socks5Tor;
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, RawSocket, NtorCrypto;

const
  SOCKS_VERSION = 5;
  TOR_CELL_SIZE = 512;
  TOR_CMD_RELAY = 1;

type
  TSocks5Reply = packed record
    Ver, Rep: Byte;
    Rsv, AddrType: Byte;
    BndAddr: array[0..3] of Byte;
    BndPort: array[0..1] of Byte;
  end;

  TTorCell = packed record
    Cmd: Byte;
    CircuitId: Word;
    Length: Word;
    Payload: array[0..TOR_CELL_SIZE - 5] of Byte;
  end;

  TCircuitNode = class
    RelayId: TB;
    SessionKey: TB;
    Nonce: LongWord;
  end;

  TCircuit = class
    FCircuitId: Word;
    FTargetAddr: TSockAddrIn;
    FTargetSock: TSocket;
    FNodes: TList;
    FStreamID: Word;
    constructor Create(CircuitId: Word; Addr: TSockAddrIn);
    procedure AddNode(const RId: TB);
    procedure ConnectTarget;
    procedure HandleClientData(ClientSock: TSocket);
    destructor Destroy; override;
  end;

function ParseSocks5Hello(Sock: TSocket): Boolean;
function SendSocksReply(Sock: TSocket; Method: Byte): Boolean;
function ParseSocks5Connect(Sock: TSocket; out Addr: TSockAddrIn): Boolean;
function SendConnectReply(Sock: TSocket): Boolean;
function CreateCircuit(Sock: TSocket): TCircuit;

implementation

function ParseSocks5Hello(Sock: TSocket): Boolean;
var
  Ver, Methods, NMethods: Byte;
  i: Integer;
begin
  SocketRecvFull(Sock, @Ver, 1);
  SocketRecvFull(Sock, @NMethods, 1);
  Result := (Ver = SOCKS_VERSION);
  for i := 0 to NMethods - 1 do
    SocketRecvFull(Sock, @Methods, 1);
end;

function SendSocksReply(Sock: TSocket; Method: Byte): Boolean;
var
  R: array[0..1] of Byte;
begin
  R[0] := SOCKS_VERSION;
  R[1] := Method;
  SocketSend(Sock, @R[0], 2);
  Result := True;
end;

function NetToHost16(V: Word): Word;
var
  A: array[0..1] of Byte absolute V;
  T: Byte;
begin
  T := A[0]; A[0] := A[1]; A[1] := T;
  Result := V;
end;

function NetToHost32(V: LongWord): LongWord;
var
  A: array[0..3] of Byte absolute V;
  T1, T2: Byte;
begin
  T1 := A[0]; T2 := A[1];
  A[0] := A[3]; A[1] := A[2];
  A[2] := T2;   A[3] := T1;
  Result := V;
end;

function ParseSocks5Connect(Sock: TSocket; out Addr: TSockAddrIn): Boolean;
var
  Ver, Cmd, Rsv, AT: Byte;
  IPv4: LongWord;
  Port: Word;
  DNSLen: Byte;
  Buf: Byte;
  i: Integer;
begin
  FillChar(Addr, SizeOf(Addr), 0);
  SocketRecvFull(Sock, @Ver, 1);
  SocketRecvFull(Sock, @Cmd, 1);
  SocketRecvFull(Sock, @Rsv, 1);
  SocketRecvFull(Sock, @AT, 1);
  case AT of
    1: begin
      FillChar(IPv4, 4, 0);
      SocketRecvFull(Sock, @IPv4, 4);
      Addr.sin_family := AF_INET;
      Addr.sin_addr := NetToHost32(IPv4);
      FillChar(Port, 2, 0);
      SocketRecvFull(Sock, @Port, 2);
      Addr.sin_port := NetToHost16(Port);
    end;
    3: begin
      SocketRecvFull(Sock, @DNSLen, 1);
      for i := 0 to DNSLen - 1 do
        SocketRecvFull(Sock, @Buf, 1);
      FillChar(Port, 2, 0);
      SocketRecvFull(Sock, @Port, 2);
      Addr.sin_port := NetToHost16(Port);
    end;
  end;
  Result := True;
end;

function SendConnectReply(Sock: TSocket): Boolean;
var
  R: TSocks5Reply;
begin
  FillChar(R, SizeOf(R), 0);
  R.Ver := 5;
  R.Rep := 0;
  R.AddrType := 1;
  SocketSend(Sock, @R, SizeOf(R));
  Result := True;
end;

constructor TCircuit.Create(CircuitId: Word; Addr: TSockAddrIn);
begin
  FCircuitId := CircuitId;
  FTargetAddr := Addr;
  FTargetSock := -1;
  FNodes := TList.Create;
  FStreamID := 1;
end;

procedure TCircuit.AddNode(const RId: TB);
var
  Node: TCircuitNode;
begin
  Node := TCircuitNode.Create;
  Node.RelayId := Copy(RId);
  SetLength(Node.SessionKey, 32);
  FillChar(Node.SessionKey[0], 32, 0);
  Node.Nonce := 0;
  FNodes.Add(Node);
end;

procedure TCircuit.ConnectTarget;
begin
  FTargetSock := SocketCreate;
  SocketConnect(FTargetSock, FTargetAddr);
end;

procedure TCircuit.HandleClientData(ClientSock: TSocket);
var
  Cell: TTorCell;
  Data: TB;
  i: Integer;
  DataLen, Got: Integer;
  Node: TCircuitNode;
begin
  Got := SocketRecv(ClientSock, @Cell, SizeOf(Cell));
  if Got <= 0 then Exit;
  DataLen := Cell.Length;
  SetLength(Data, DataLen);
  Move(Cell.Payload[0], Data[0], DataLen);

  for i := FNodes.Count - 1 downto 0 do
  begin
    Node := TCircuitNode(FNodes[i]);
    Salsa20Encrypt(Data, Node.SessionKey, Node.Nonce);
    inc(Node.Nonce);
  end;

  if FTargetSock > 0 then
    SocketSend(FTargetSock, @Data[0], DataLen);
end;

destructor TCircuit.Destroy;
var
  i: Integer;
begin
  for i := FNodes.Count - 1 downto 0 do
    TCircuitNode(FNodes[i]).Free;
  FNodes.Free;
  if FTargetSock > 0 then SocketClose(FTargetSock);
  inherited;
end;

function CreateCircuit(Sock: TSocket): TCircuit;
var
  Addr: TSockAddrIn;
  EPub: TB;
begin
  ParseSocks5Hello(Sock);
  SendSocksReply(Sock, 0);
  ParseSocks5Connect(Sock, Addr);
  GenerateEphemeralKey(EPub);
  Result := TCircuit.Create(Random(32767) + 1, Addr);
  SendConnectReply(Sock);
end;

end.
