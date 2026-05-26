program socks5_tor_client;
{$mode objfpc}{$H+}

uses
  SysUtils, RawSocket, NtorCrypto, Socks5Tor;

var
  ListenSock, ClientSock: TSocket;
  Addr: TSockAddrIn;
  Circuit: TCircuit;

procedure Log(const Msg: string);
begin
  WriteLn(Format('[%s] %s', [DateTimeToStr(Now), Msg]));
  Flush(Output);
end;

var
  Port: Word;
  PortNet: Word;

begin
  Port := 9050;
  PortNet := Swap(Port);

  Log('SOCKS5+Tor Proxy v1.0');
  Log('Salsa20 cipher loaded');

  ListenSock := SocketCreate;
  Log('Socket created: fd=' + IntToStr(ListenSock));
  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_addr := 0;
  Addr.sin_port := PortNet;

  SocketBindListen(ListenSock, Addr, 5);
  Log('Listening on 0.0.0.0:' + IntToStr(Port));

  try
    while True do
    begin
      try
        ClientSock := SocketAccept(ListenSock, Addr);
        Log('Client connected [fd:' + IntToStr(ClientSock) + ']');

        Circuit := CreateCircuit(ClientSock);
        Log('Circuit established [id:' + IntToStr(Circuit.FCircuitId) + '] target ' +
            Format('%d.%d.%d.%d', [
            Byte(Circuit.FTargetAddr.sin_addr),
            Byte(Circuit.FTargetAddr.sin_addr shr 8),
            Byte(Circuit.FTargetAddr.sin_addr shr 16),
            Byte(Circuit.FTargetAddr.sin_addr shr 24)]) +
            ':' + IntToStr(Circuit.FTargetAddr.sin_port));

        Circuit.ConnectTarget;
        Log('Target connected via circuit, proxying ' + IntToStr(ClientSock));

        Circuit.HandleClientData(ClientSock);
        Log('Stream completed [id: ' + IntToStr(Circuit.FCircuitId) + ']');

        SocketClose(ClientSock);
        Circuit.Free;
      except
        on E: Exception do
        begin
          Log('Error: ' + E.Message);
          try SocketClose(ClientSock) except end;
        end;
      end;
    end;
  finally
    SocketClose(ListenSock);
  end;
end.
