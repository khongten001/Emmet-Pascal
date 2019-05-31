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

function IsCharSpace(ch: char): boolean;
begin
  Result:= (ch=' ') or (ch=#9);
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
  Found: boolean;
  N: integer;
  bBrackets, bQuotes: boolean;
begin
  StartOffset:= CurOffset;
  Abbrev:= '';
  Found:= false;

  CurOffset:= Min(CurOffset, Length(S));
  N:= CurOffset+1;
  bBrackets:= false;
  bQuotes:= false;

  repeat
    Dec(N);

    if N=0 then
    begin
      StartOffset:= 0;
      Abbrev:= Copy(S, StartOffset+1, CurOffset-StartOffset);
      Found:= true;
      Break;
    end;

    if S[N]='}' then
    begin
      bBrackets:= true;
      Continue;
    end;

    if S[N]='{' then
    begin
      bBrackets:= false;
      Continue;
    end;

    if S[N]='"' then
    begin
      bQuotes:= not bQuotes;
      Continue;
    end;

    if IsCharSpace(S[N]) then
      if not bBrackets and not bQuotes then
      begin
        StartOffset:= N;
        Abbrev:= Copy(S, StartOffset+1, CurOffset-StartOffset);
        Found:= true;
        Break;
      end;

    if S[N]='>' then
      if EmmetOffsetIsTagEnd(S, N) then
      begin
        StartOffset:= N;
        Abbrev:= Copy(S, StartOffset+1, CurOffset-StartOffset);
        Found:= true;
        Break;
      end;
  until false;

  if Found then
    while (StartOffset<Length(S)) and IsCharSpace(S[StartOffset+1]) do
    begin
      Inc(StartOffset);
      Delete(Abbrev, 1, 1);
    end;
end;

end.
