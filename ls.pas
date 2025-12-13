program SimpleLS;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes;

type
  TLSOptions = record
    Recursive: Boolean;
    Reverse: Boolean;
    LongList: Boolean;
    ShowAll: Boolean;
    HumanReadable: Boolean;
    ShowHelp: Boolean;
  end;

procedure PrintHelp;
begin
  Writeln('Usage: ls [options] [directory]');
  Writeln('Options:');
  Writeln('  -r     Reverse order while sorting');
  Writeln('  -R     List subdirectories recursively');
  Writeln('  -l     Long listing format');
  Writeln('  -a     Include hidden files');
  Writeln('  -h     Human-readable sizes in long format');
  Writeln('  --help Show this help message');
end;

function HumanReadableSize(Size: Int64): string;
const
  Suffix: array[0..5] of string = ('B','K','M','G','T','P');
var
  Index: Integer;
  Value: Double;
begin
  Value := Size;
  Index := 0;
  while (Value >= 1024) and (Index < 5) do
  begin
    Value := Value / 1024;
    Inc(Index);
  end;
  Result := Format('%.1f%s', [Value, Suffix[Index]]);
end;

procedure ListDirectory(const Path: string; const Options: TLSOptions; Indent: string = '');
var
  Files: TStringList;
  Info: TSearchRec;
  I: Integer;
  FullPath: string;
begin
  if FindFirst(Path + PathDelim + '*', faAnyFile, Info) = 0 then
  begin
    Files := TStringList.Create;
    try
      repeat
        if not Options.ShowAll and (Info.Name[1] = '.') then
          Continue;
        Files.Add(Info.Name);
      until FindNext(Info) <> 0;
      FindClose(Info);

      // Sort files
      Files.Sort;
      if Options.Reverse then
        for I := 0 to Files.Count div 2 - 1 do
          Files.Exchange(I, Files.Count - 1 - I);

      // Print files
      for I := 0 to Files.Count - 1 do
      begin
        FullPath := Path + PathDelim + Files[I];

        if Options.LongList then
        begin
          if FindFirst(FullPath, faAnyFile, Info) = 0 then
          begin
            Write(Indent);
            if Options.HumanReadable then
              Write(Format('%10s ', [HumanReadableSize(Info.Size)]))
            else
              Write(Format('%10d ', [Info.Size]));
            Write(Format('%-20s ', [DateTimeToStr(FileDateToDateTime(Info.Time))]));
            Writeln(Files[I]);
            FindClose(Info);
          end;
        end
        else
          Writeln(Indent, Files[I]);
      end;

      // Recursive subdirectories
      if Options.Recursive then
      begin
        for I := 0 to Files.Count - 1 do
        begin
          FullPath := Path + PathDelim + Files[I];
          if DirectoryExists(FullPath) and (Files[I] <> '.') and (Files[I] <> '..') then
          begin
            Writeln;
            Writeln(Indent + FullPath + ':');
            ListDirectory(FullPath, Options, Indent + '  ');
          end;
        end;
      end;

    finally
      Files.Free;
    end;
  end;
end;

var
  Options: TLSOptions;
  I: Integer;
  Dir: string;
begin
  // Default options
  Options.Recursive := False;
  Options.Reverse := False;
  Options.LongList := False;
  Options.ShowAll := False;
  Options.HumanReadable := False;
  Options.ShowHelp := False;
  Dir := '.';

  // Parse command line arguments
  for I := 1 to ParamCount do
  begin
    if ParamStr(I) = '-r' then Options.Reverse := True
    else if ParamStr(I) = '-R' then Options.Recursive := True
    else if ParamStr(I) = '-l' then Options.LongList := True
    else if ParamStr(I) = '-a' then Options.ShowAll := True
    else if ParamStr(I) = '-h' then Options.HumanReadable := True
    else if ParamStr(I) = '--help' then Options.ShowHelp := True
    else if ParamStr(I)[1] <> '-' then
      Dir := ParamStr(I);
  end;

  if Options.ShowHelp then
  begin
    PrintHelp;
    Exit;
  end;

  if not DirectoryExists(Dir) then
  begin
    Writeln('Error: Directory "', Dir, '" does not exist.');
    Exit;
  end;

  ListDirectory(Dir, Options);
end.

