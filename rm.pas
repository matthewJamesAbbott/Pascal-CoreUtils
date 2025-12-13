program rm;

uses
  SysUtils;

var
  Recursive: Boolean = False;
  Force: Boolean = False;
  DirOnly: Boolean = False;

procedure ShowHelp;
begin
  Writeln('Usage: rm [OPTION]... FILE...');
  Writeln;
  Writeln('Remove (unlink) the FILE(s).');
  Writeln;
  Writeln('  -r        remove directories and their contents recursively');
  Writeln('  -d        remove empty directories');
  Writeln('  -f        ignore nonexistent files, never prompt');
  Writeln('  --help    display this help and exit');
  Writeln;
  Halt(0);
end;

procedure Error(const Msg: string);
begin
  if not Force then
    Writeln('rm: ', Msg);
end;

procedure RemovePath(const Path: string);

  procedure RemoveDirRecursive(const Dir: string);
  var
    SR: TSearchRec;
    Res: Integer;
    Item: string;
  begin
    Res := FindFirst(Dir + '/*', faAnyFile, SR);
    while Res = 0 do
    begin
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        Item := Dir + '/' + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
          RemoveDirRecursive(Item)
        else if not DeleteFile(Item) then
          Error('cannot remove "' + Item + '"');
      end;
      Res := FindNext(SR);
    end;
    FindClose(SR);

    if not RemoveDir(Dir) then
      Error('cannot remove directory "' + Dir + '"');
  end;

begin
  if DirectoryExists(Path) then
  begin
    if DirOnly then
    begin
      if not RemoveDir(Path) then
        Error('cannot remove "' + Path + '": directory not empty');
    end
    else if Recursive then
      RemoveDirRecursive(Path)
    else
      Error('cannot remove "' + Path + '": is a directory');
  end
  else if FileExists(Path) then
  begin
    if not DeleteFile(Path) then
      Error('cannot remove "' + Path + '"');
  end
  else if not Force then
    Error('cannot remove "' + Path + '": no such file or directory');
end;

var
  I: Integer;
  Arg: string;

begin
  if ParamCount = 0 then
  begin
    Writeln('usage: rm [-r] [-f] [-d] file...');
    Halt(1);
  end;

  for I := 1 to ParamCount do
  begin
    Arg := ParamStr(I);

    if Arg = '--help' then
      ShowHelp;

    if (Length(Arg) > 1) and (Arg[1] = '-') then
    begin
      if Pos('r', Arg) > 0 then Recursive := True;
      if Pos('f', Arg) > 0 then Force := True;
      if Pos('d', Arg) > 0 then DirOnly := True;
    end;
  end;

  for I := 1 to ParamCount do
  begin
    Arg := ParamStr(I);
    if (Arg[1] <> '-') then
      RemovePath(Arg);
  end;
end.

