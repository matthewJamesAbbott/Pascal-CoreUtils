unit NtorCrypto;
{$mode objfpc}

interface

type
  TB = array of Byte;
  TSalsaState = array[0..15] of LongWord;

procedure Salsa20Encrypt(var Data: TB; const Key: TB; Nonce: Cardinal);
function KDFDerive(SharedSecret: TB; IdA, IdB: TB): TB;
function GenerateEphemeralKey(var PubKey: TB): TB;

implementation

uses
  SysUtils, Math;

procedure Salsa20Core(var State: TSalsaState);
var
  x: TSalsaState;
  j, k: LongWord;
  i: Integer;

function ROL32(V, Shift: LongWord): LongWord;
begin
  Result := (V shl (Shift mod 32)) or (V shr (32 - (Shift mod 32)));
end;

begin
  for i := 0 to 15 do x[i] := State[i];
  for j := 0 to 7 do
    for k := 0 to 1 do
    begin
      x[ 4] := x[ 4] xor ROL32(x[12] xor x[ 0], 7);
      x[ 8] := x[ 8] xor ROL32(x[ 4] xor x[12], 9);
      x[12] := x[12] xor ROL32(x[ 8] xor x[ 4], 13);
      x[ 0] := x[ 0] xor ROL32(x[12] xor x[ 8], 18);
      x[10] := x[10] xor ROL32(x[ 0] xor x[ 8], 7);
      x[14] := x[14] xor ROL32(x[10] xor x[ 0], 9);
      x[ 2] := x[ 2] xor ROL32(x[14] xor x[10], 13);
      x[ 6] := x[ 6] xor ROL32(x[ 2] xor x[14], 18);
      x[ 6] := x[ 6] xor ROL32(x[ 2] xor x[ 0], 7);
      x[ 4] := x[ 4] xor ROL32(x[ 6] xor x[ 2], 9);
      x[10] := x[10] xor ROL32(x[ 4] xor x[ 6], 13);
      x[14] := x[14] xor ROL32(x[10] xor x[ 4], 18);
      x[ 8] := x[ 8] xor ROL32(x[14] xor x[10], 7);
      x[ 0] := x[ 0] xor ROL32(x[ 8] xor x[14], 9);
      x[ 2] := x[ 2] xor ROL32(x[ 0] xor x[ 8], 13);
      x[12] := x[12] xor ROL32(x[ 2] xor x[ 0], 18);
    end;
  for i := 0 to 15 do State[i] := State[i] + x[i];
end;

procedure Salsa20Encrypt(var Data: TB; const Key: TB; Nonce: Cardinal);
var
  State: TSalsaState;
  KeyStream: TB;
  Offset, i: Integer;
begin
  Move(Key[0], State[1], 16);
  Move(Key[16], State[13], 8);
  Move(Nonce, State[14], 4);
  State[0] := $61707865;
  State[2] := 0;
  State[3] := 0;
  State[15] := $36264000;

  SetLength(KeyStream, Length(Data));
  Offset := 0;

  while Offset < Length(Data) do
  begin
    Salsa20Core(State);
    for i := 0 to 15 do
    begin
      Move(State[i], KeyStream[Offset], 4);
      inc(Offset, 4);
      if Offset >= Length(Data) then Break;
    end;
    inc(State[2]);
    if State[2] = 0 then inc(State[3]);
  end;

  for i := 0 to Length(Data) - 1 do
    Data[i] := Data[i] xor KeyStream[i];
end;

function KDFDerive(SharedSecret: TB; IdA, IdB: TB): TB;
var
  Combined: TB;
  i: Integer;
begin
  Result := nil;
  SetLength(Combined, Length(SharedSecret) + Length(IdA) + Length(IdB));
  Move(SharedSecret[0], Combined[0], Length(SharedSecret));
  Move(IdA[0], Combined[Length(SharedSecret)], Length(IdA));
  Move(IdB[0], Combined[Length(SharedSecret) + Length(IdA)], Length(IdB));
  SetLength(Result, 32);
  for i := 0 to 31 do
    Result[i] := Combined[i] xor Combined[Length(Combined) - 1 - i];
end;

function GenerateEphemeralKey(var PubKey: TB): TB;
var
  i: Integer;
begin
  Result := nil;
  SetLength(Result, 32);
  SetLength(PubKey, 32);
  for i := 0 to 31 do
  begin
    Result[i] := Random(256);
    if i = 31 then
      PubKey[i] := (Result[i] and 248) or 64
    else
      PubKey[i] := Result[i] and 252;
  end;
end;

end.
