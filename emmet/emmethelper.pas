unit EmmetHelper;

interface

uses
  Math;

procedure EmmetFindAbbrev(const S: string; CurOffset: integer;
  out StartOffset: integer; out Abbrev: string);

implementation

function IsCharWord(ch: char): boolean;
begin
  case ch of
    'a'..'z',
    'A'..'Z',
    '0'..'9',
    '_':
      Result:= true;
    else
      Result:= false;
  end;
end;

function EmmetOffsetIsTagEnd(const S: string; N: integer): boolean;
begin
  Result:= false;
  if N<=1 then exit;
  if N>Length(S) then exit;
  if S[N]<>'>' then exit;

  Dec(N);
  if N<=1 then exit;
  if not IsCharWord(S[N]) then exit;
  while (N>0) and IsCharWord(S[N]) do Dec(N);

  if N<1 then exit;
  if S[N]='/' then
  begin
    Dec(N);
    if N<1 then exit;
  end;

  if S[N]<>'<' then exit;
  Result:= true;
end;

procedure EmmetFindAbbrev(const S: string; CurOffset: integer;
  out StartOffset: integer; out Abbrev: string);
var
  N: integer;
begin
  StartOffset:= 0;
  Abbrev:= '';

  CurOffset:= Min(CurOffset, Length(S));
  N:= CurOffset;

  repeat
    if N=0 then
    begin
      StartOffset:= 0;
      Abbrev:= Copy(S, StartOffset+1, CurOffset-StartOffset);
      Exit;
    end;
    if S[N]='>' then
      if EmmetOffsetIsTagEnd(S, N) then
      begin
        StartOffset:= N;
        Abbrev:= Copy(S, StartOffset+1, CurOffset-StartOffset);
        Exit;
      end;
    Dec(N);
  until false;
end;

end.
