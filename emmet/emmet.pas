(*--------------------------------------------------------------------------------------------
Unit Name: Emmet
Author:    Rickard Johansson  (https://www.rj-texted.se/Forum/index.php)
Date:      31-May-2019
Version:   1.02
Purpose:   Expand Emmet abbreviations

Usage:
Create an Emmet object

    FEmmet := TEmmet.Create(sDataPath);

    sDataPath         = The path to snippets.ini and Lorem.txt files e.g. "c:\foo"

and call

    sExpanded := FEmmet.ExpandAbbreviation(sAbbr, sSyntax, sSelText, sSection, bMultiCursorTabs);

    sAbbr             = Abbreviation                               e.g. "ul>li*5"
    sSyntax           = Code language in lowercase                 e.g. "html"
    sSelText          = Text is used to wrap with abbreviation
    sSection          = Get the section used in snippets.ini       e.g. "html"
    bMultiCursorTabs  = True if cursor positions in expanded string should be
                    handled as multi cursor positions

    sExpanded is the resulting expanded code. It may contain cursor | positions or
    selected tab ${1:charset} positions.
--------------------------------------------------------------------------------------------*)
(*------------------------------------------------------------------------------------------
Version updates and changes

Version 1.02
    * Addressed some warnings in Lazarus
Version 1.01
    * Fixed a multiply issue in ProcessTagMultiplication(...)
--------------------------------------------------------------------------------------------*)

unit Emmet;

interface

uses
  {$ifndef fpc}
  System.IniFiles,
  System.Classes;
  {$else}
  Classes, IniFiles;
  {$endif}

type
  TEmmet = class(TObject)
  private
    FTagList: TStringList;
    FAbbreviations: TMemIniFile;
    FDataPath: string;
    FExtendedSyntax: Boolean;
    FExtends: string;
    FExtendsKey: string;
    FExtendsSnippetKey: string;
    FFilters: TStringList;
    FLorem: TStringList;
    FRecursiveIndex: Integer;
    FSelection: string;
    FSyntax: string;
    FSyntaxKey: string;
    FSyntaxSnippetKey: string;
    FTagInlineLevel: TStringList;
    function AddTag(s: string; const sAttribute, sId, sClass, sText: string; const
        nIndent: Integer): string;
    procedure AddToTagList(const s, sText: string);
    function CountLines(const s: string): Integer;
    function CreateLoremString(const nr: Integer): string;
    function ExpandCSSAbbrev(const AString: string; out bMultiCursorTabs: Boolean):
        string;
    function ExpandTagAbbrev(sAbbrev: string; const nIndent: Integer = 0): string;
    function InsertUserAttribute(const s, sAttribute, sId, sClass: string): string;
    function IsTagInline(const s: string; var bText: Boolean): Boolean;
    function CreateTagAndClass(var s: string; const sClass: string): string;
    function ExtractUserAttributes(const sAttribute: string): string;
    function FormatSelection(const s: string; const ind: Integer): string;
    function InsertSelection(s: string; const bOneLine: Boolean = False): string;
    function ProcessTagAbbrev(const AString: string; const index, len, indent:
        Integer): string;
    function ProcessTagGroup(const AString: string; const index: Integer; out ipos:
        Integer; const indent: Integer): string;
    function ProcessTagMultiplication(const AString: string; const index, len,
        indent: Integer): string;
  public
    constructor Create(const ADataPath: string);
    destructor Destroy; override;
    function ExpandAbbreviation(const AString, ASyntax, ASelText: string; out
        ASection: string; out bMultiCursorTabs: Boolean): string;
    function GetAbbreviationNames(const ASyntax: string; var AList: TStringList):
        Boolean;
    function GetSnippetNames(const ASyntax: string; var AList: TStringList):
        Boolean;
  end;

implementation

uses
  {$ifndef fpc}
  System.SysUtils, Vcl.Dialogs, System.Math;
  {$else}
  SysUtils, Dialogs, Math;
  {$endif}

{$ifndef fpc}
const
  DirectorySeparator = System.SysUtils.PathDelim;
{$endif}

const
  cInlineLevel = 'a,abbr,acronym,applet,b,basefont,bdo,big,br,button,cite,code,del,dfn,em,font,i,iframe,img,input,ins,kbd,label,map,object,q,s,samp,select,small,span,strike,strong,sub,sup,textarea,tt,u,var';

constructor TEmmet.Create(const ADataPath: string);
begin
  inherited Create;
  FAbbreviations := TMemIniFile.Create(ADataPath + DirectorySeparator + 'Snippets.ini');

  FFilters := TStringList.Create;
  FFilters.Delimiter := '|';

  FTagList := TStringList.Create;
  FTagInlineLevel := TStringList.Create;
  FTagInlineLevel.Delimiter := ',';
  FTagInlineLevel.DelimitedText := cInlineLevel;

  FLorem := TStringList.Create;

  FDataPath := ADataPath;
end;

destructor TEmmet.Destroy;
begin
  inherited;
  FAbbreviations.Free;
  FFilters.Free;
  FTagList.Free;
  FTagInlineLevel.Free;
  FLorem.Free;
end;

function TEmmet.AddTag(s: string; const sAttribute, sId, sClass, sText: string;
    const nIndent: Integer): string;
var
  w,st: string;
begin
  if (s <> '') or (sId <> '') or (sClass <> '') or (sAttribute <> '') then
  begin
    w := '<' + s + '>';
    st := StringOfChar(#9,nIndent);
    if sId <> '' then
    begin
      if (s = '') then s := 'div';
      w := '<' + s + #32 + sId + '>';
    end;
    if sClass <> '' then
    begin
      w := CreateTagAndClass(s,sClass);
    end;
    if sAttribute <> '' then
    begin
      if (s = '') then s := 'div';
      w := '<' + s + ExtractUserAttributes(sAttribute) + '>';
    end;

    FTagList.Add('</'+s+'>');
    Result := st + w + sText;
  end
  else
  begin
    Result := sText;
  end;
end;

procedure TEmmet.AddToTagList(const s, sText: string);
var
  n: Integer;
  w: string;
begin
  if Pos('/>', s) = 0 then
  begin
    n := Pos(#32, s);
    if n = 0 then n := Pos('>', s);
    if n > 0 then
      w := Copy(s, 2, n - 2)
    else
      w := Copy(s, 2, Length(s) - 2);
    FTagList.Add(sText+'</'+w+'>');
  end;
end;

function TEmmet.CountLines(const s: string): Integer;
var
  n,m: Integer;
begin
  Result := 1;
  n := Pos(#13#10, s);
  m := n + 2;
  if n > 0 then
  begin
    if n = 1 then Dec(Result);
    while n > 0 do
    begin
      n := Pos(#13#10, s, m);
      if n > 0 then m := n + 2;
      Inc(Result);
    end;
    if m > Length(s) then Dec(Result);
  end;
end;

function TEmmet.CreateLoremString(const nr: Integer): string;
var
  s,sz: string;
  x,z,ln: Integer;
  bFirst: Boolean;
begin
  Result := 'Lorem Ipsum ';
  if FLorem.Count <= 0 then
  begin
    sz := FDataPath + DirectorySeparator + 'Lorem.txt';
    if FileExists(sz) then
      FLorem.LoadFromFile(sz);
  end;
  bFirst := False;
  sz := ',.;!?';
  ln := Length(Result);
  for x := 2 to nr - 1 do
  begin
    s := FLorem[Random(FLorem.Count - 1)];
    if bFirst and (Ord(S[1]) > 90) then
    begin
      s[1] := Char(Ord(s[1]) - 32);
      bFirst := False;
    end;

    if (Random(32767) mod 60 < 8) and (x < nr -1) then
    begin
      z := Random(5) + 1;
      s := s + sz[z];
      bFirst := z > 1;
    end;
    Result := Result + s + ' ';
    ln := ln + Length(s) + 1;
  end;
  Result := Trim(Result) + '.';
end;

function TEmmet.ExpandCSSAbbrev(const AString: string; out bMultiCursorTabs:
    Boolean): string;
var
  sVendor,sAbbrev: string;

  function ExtractVendor(const s: string; var sv: string): string;
  var
    n: Integer;
  begin
    Result := s;
    sv := '';
    if s[1] <> '-' then Exit;

    n := Pos('-',s,2);
    if n = 0 then Exit;
    sv := Copy(s,1,n);
    Result := Copy(Result,n+1,Length(Result));
  end;

  function ProcessVendor(const sv, s: string): string;
  var
    ws: string;
  begin
    Result := s;

    if sv = '-v-' then
    begin
      bMultiCursorTabs := True;
      Result := '-webkit-' + s + #13#10;
      Result := Result + '-moz-' + s + #13#10;
      Result := Result + s;
    end
    else if sv = '-w-' then
    begin
      bMultiCursorTabs := True;
      Result := '-webkit-' + s + #13#10;
      Result := Result + s;
    end
    else if sv = '-m-' then
    begin
      bMultiCursorTabs := True;
      Result := '-moz-' + s + #13#10;
      Result := Result + s;
    end;
  end;

begin
  Result := '';
  bMultiCursorTabs := False;
  if AString = '' then Exit;

  sAbbrev := ExtractVendor(AString, SVendor);

  if FAbbreviations.ValueExists(FSyntaxSnippetKey,sAbbrev) then
  begin
    Result := FAbbreviations.ReadString(FSyntaxSnippetKey,sAbbrev,'');
    FExtendedSyntax := False;
  end
  else if FAbbreviations.ValueExists(FExtendsSnippetKey,sAbbrev) then
  begin
    Result := FAbbreviations.ReadString(FExtendsSnippetKey,sAbbrev,'');
    FExtendedSyntax := True;
  end;

  if Result = '' then Exit;

  if sVendor <> '' then
  begin
    Result := ProcessVendor(sVendor, Result);
    Result := StringReplace(Result, ':', ': ', [rfReplaceAll]);
  end
  else
  begin
    Result := StringReplace(Result, ':', ': ', []);
  end;

  Result := StringReplace(Result, '\n', #13#10, [rfReplaceAll]);
  Result := StringReplace(Result, '\t', #9, [rfReplaceAll]);
end;

function TEmmet.ExpandTagAbbrev(sAbbrev: string; const nIndent: Integer = 0):
    string;
var
  indx,npos,ind: Integer;
  ch: Char;
  indent: Integer;
  tagListCount: Integer;
  s,sw,w: string;
  bInline,bText: Boolean;

  function InsertTabPoint(const s: string): string;
  var
    i: Integer;
  begin
    Result := '';
    i := Length(s);
    if i = 0 then Exit;
    if s[i] <> '>' then Exit;

    while (i > 0) and (s[i] <> '<') do Dec(i);
    Inc(i);

    if s[i] = '/' then Exit;

    Result := '|';
  end;

  function AddChild(const s, sw: string): string;
  var
    w: string;
    bText: Boolean;
  begin
    Result := '';
    w := ExpandTagAbbrev(s,indent);
    if IsTagInline(w,bText) then
    begin
      if bText then
        Result := Result + sw + w
      else
        Result := Result + sw + Trim(w);
      bInline := True;
    end
    else
    begin
      Result := Result + sw + #13#10;
      Result := Result + w;
    end;
    if (Length(Result) > 0) and (Result[Length(Result)] <> #10) and not IsTagInline(w,bText) then
      Result := Result + #13#10;
  end;

  function AddSibling(const s: string): string;
  var
    w: string;
  begin
    Result := '';
    if FTagList.Count > tagListCount then
    begin
      w := FTagList[FTagList.Count-1];
      if bInline then
        Result := Result + InsertTabPoint(s) + w
      else
        Result := Result + InsertTabPoint(s) + w + #13#10;
      FTagList.Delete(FTagList.Count-1);
    end
    else if indx <> npos then
    begin
      if (w = '') and not bInline then
        Result := Result + #13#10;
    end;
  end;

  function ClimbUpOneLevel(const s: string): string;
  var
    w: string;
    bText: Boolean;
  begin
    Result := s;
    while (FTagList.Count > 0) and (FTagList.Count >= tagListCount) do
    begin
      w := FTagList[FTagList.Count-1];
      if IsTagInline(w,bText) then
        Result := Result + InsertTabPoint(s) + w
      else
        Result := Result + InsertTabPoint(s) + w + #13#10;
      FTagList.Delete(FTagList.Count-1);
      Dec(indent);
    end;
  end;

  function AddExpanded(const s: string): string;
  var
    w: string;
    bText: Boolean;
  begin
    Result := ProcessTagAbbrev(s,npos,indx-npos,indent);
    if FTagList.Count > tagListCount then
    begin
      w := FTagList[FTagList.Count-1];
      FTagList.Delete(FTagList.Count-1);
      if bInline or IsTagInline(w,bText) then
        Result := Result + InsertTabPoint(Result) + w
      else
        Result := Result + InsertTabPoint(Result) + w + #13#10;
    end;
  end;

  function AddEndTags: string;
  var
    w,st: string;
    bText: Boolean;
  begin
    Result := '';
    while (FTagList.Count > 0) and (FTagList.Count > tagListCount) do
    begin
      st := StringOfChar(#9,indent);
      w := FTagList[FTagList.Count-1];
      if bInline then
      begin
        Result := Result + w;
        if not IsTagInline(w,bText) then
          Result := Result + #13#10;
        bInline := False;
      end
      else
      begin
        if not IsTagInline(w,bText) then
          w := st + w;
        if (Length(Result) > 0) and (Result[Length(Result)] <> #10) and not IsTagInline(w,bText) then
          Result := Result + #13#10 + w
        else
          Result := Result + w;
      end;
      FTagList.Delete(FTagList.Count-1);
      Dec(indent);
    end;
  end;

  function IsFilter(const sa: string; const index: Integer): Integer;
  var
    i: Integer;
    w: string;
  begin
    Result := 0;
    i := 0;
    while (i < FFilters.Count) and (Result = 0) do
    begin
      w := FFilters[i];
      Result := Pos(w,sa,index);
      Inc(i);
    end;
  end;

begin
  Result := '';
  Inc(FRecursiveIndex);
  sAbbrev := StringReplace(sAbbrev, '\n', #13#10, [rfReplaceAll]);
  sAbbrev := StringReplace(sAbbrev, '\t', #9, [rfReplaceAll]);
  indent := nIndent;
  bInline := False;
  tagListCount := FTagList.Count;
  npos := 1;
  indx := 1;
  while indx <= Length(sAbbrev) do
  begin
    ch := sAbbrev[indx];
    case ch of
      '(': // group
      begin
        if indx > npos then
        begin
          s := s + ProcessTagAbbrev(sAbbrev,npos,indx-npos,indent);
          npos := indx;
        end;
        s := s + ProcessTagGroup(sAbbrev,npos,indx,indent);
        npos := indx + 1;
      end;

      '>': // child operator
      begin
        ind := indent;
        if indx > npos then
        begin
          w := ProcessTagAbbrev(sAbbrev,npos,indx-npos,indent);
        end;
        if IsFilter(sAbbrev,npos) <> npos then
          Inc(indent);
        npos := indx + 1;

        Inc(indx);
        s := s + AddChild(Copy(sAbbrev,indx,Length(sAbbrev)), w);
        npos := Length(sAbbrev) + 1;
        indx := npos;
        indent := ind;
      end;

      '+': // sibling operator
      begin
        if indx = Length(sAbbrev) then Inc(indx);
        if indx > npos then
        begin
          sw := ProcessTagAbbrev(sAbbrev,npos,indx-npos,indent);
          bInline := IsTagInline(sw,bText);
          if bInline and not bText then
            s := s + Trim(sw)
          else
            s := s + sw;
        end;
        s := s + AddSibling(s);
        npos := indx + 1;
      end;

      '^': // climb up operator
      begin
        if indx > npos then
        begin
          sw := ProcessTagAbbrev(sAbbrev,npos,indx-npos,indent);
          if IsTagInline(sw,bText) and not bText then
            s := s + Trim(sw)
          else
            s := s + sw
        end;
        s := ClimbUpOneLevel(s);
        while (indx + 1 < Length(sAbbrev)) and (sAbbrev[indx+1] = '^') do
        begin
          Dec(tagListCount);
          s := ClimbUpOneLevel(s);
          Inc(indx);
        end;
        Inc(indent);
        npos := indx + 1;
      end;

      '*': // multiplication operator
      begin
        Inc(indx);
        while (indx <= Length(sAbbrev)) and CharInSet(sAbbrev[indx], ['0'..'9']) do Inc(indx);
        if (indx <= Length(sAbbrev)) and (sAbbrev[indx] = '>') then
        begin
          Inc(indx);
          while (indx <= Length(sAbbrev)) and not CharInSet(sAbbrev[indx], ['>','+','^']) do Inc(indx);
        end;
        s := s + ProcessTagMultiplication(sAbbrev,npos,indx-npos,indent);
        npos := indx;
        Dec(indx);
      end;
    end;
    Inc(indx);
    if (npos < indx) and (npos <= Length(sAbbrev)) and (indx > Length(sAbbrev)) then
    begin
      s := s + AddExpanded(sAbbrev);
      Dec(indent);
    end;
  end;
  s := s + AddEndTags;
  Dec(FRecursiveIndex);
  if (FRecursiveIndex = 0) and (FSelection <> '') then
    Result := InsertSelection(s)
  else
    Result := s;
  if FTagList.Count = 0 then
    Result := Trim(Result);
end;

function TEmmet.ExpandAbbreviation(const AString, ASyntax, ASelText: string;
    out ASection: string; out bMultiCursorTabs: Boolean): string;
var
  typ: string;
begin
  FTagList.Clear;
  FRecursiveIndex := 0;
  FSelection := ASelText;
  bMultiCursorTabs := False;

  FSyntax := ASyntax;
  if (ASyntax = 'xslt') then FSyntax := 'xsl';

  FExtends := FAbbreviations.ReadString(FSyntax,'extends','');
  FFilters.DelimitedText := FAbbreviations.ReadString(FSyntax,'filters','');
  typ := FAbbreviations.ReadString(FSyntax,'type','');

  FSyntaxKey := 'abbreviations-' + FSyntax;
  FExtendsKey := 'abbreviations-' + FExtends;
  FSyntaxSnippetKey := 'snippets-' + FSyntax;
  FExtendsSnippetKey := 'snippets-' + FExtends;

  if (typ = 'xml') then
    Result := ExpandTagAbbrev(AString)
  else if (typ = 'css') then
    Result := ExpandCSSAbbrev(AString,bMultiCursorTabs)
  else
    Result := AString;

  if FExtendedSyntax then
    ASection := FExtends
  else
    ASection := FSyntax;
end;

function TEmmet.InsertUserAttribute(const s, sAttribute, sId, sClass: string):
    string;
var
  i: Integer;
  sa: string;
  ch: Char;

  procedure InsertAttribute(const sa: string; var s: string; index: Integer);
  var
    sn: string;
    n,m: Integer;
  begin
    n := Pos('=',sa);
    if n > 0 then
    begin
      sn := Copy(sa,1,n) + '"';
      m := Pos(sn,s);
      if m > 0 then
      begin
        n := Pos('"',s,m+Length(sn));
        if n > m then
        begin
          index := m;
          Delete(s,m,n-m+1);
        end;
      end;
    end;
    Insert(sa,s,index);
  end;

begin
  Result := s;
  if (sAttribute = '') and (sId = '') and (sClass = '') then Exit;
  i := 1;
  while i <= Length(s) do
  begin
    ch := s[i];
    if CharInSet(ch, ['/','>','+','^','(']) then
    begin
      sa := ExtractUserAttributes(sAttribute);
      if (sa <> '') then
        InsertAttribute(sa,Result,i);
      if (sId <> '') then
        Insert(#32 + sId,Result,i);
      if (sClass <> '') then
        Insert(#32 + sClass,Result,i);
      Exit;
    end;
    Inc(i);
  end;
end;

function TEmmet.IsTagInline(const s: string; var bText: Boolean): Boolean;
var
  w: string;
  m,n,k: Integer;
begin
  Result := True;
  if Length(s) = 0 then Exit;

  bText := True;
  m := Pos('<',s,1);
  if m = 0 then Exit;
  bText := False;

  if (Length(s) > m) and (s[m+1] = '/') then Inc(m);

  n := Pos(#32,s,m+1);
  k := Pos('>',s,m+1);
  if (n > 0) and (k > 0) and (k < n) then n := k;
  if (n = 0) and (k > 0) then n := k;
  k := Pos('/>',s,m+1);
  if (n > 0) and (k > 0) and (k < n) then n := k;
  if (n = 0) and (k > 0) then n := k;

  if n = 0 then n := Length(s) + 1;
  w := Copy(s,m+1,n-m-1);

  Result := FTagInlineLevel.IndexOf(w) >= 0;
end;

function TEmmet.ProcessTagAbbrev(const AString: string; const index, len,
    indent: Integer): string;
var
  s,sn,st: string;
  sValue: string;
  sText,sId,sClass,sAttr: string;
  ls: TStringList;
  bDone: Boolean;

  function InsertLoremString(const s: string): string;
  var
    w,wn: string;
    n,m,nr: Integer;
  begin
    Result := s;
    nr := 30;
    m := Pos('@lorem',s);

    if m = 0 then Exit;

    n := m + 6;
    while (n <= Length(s)) and CharInSet(s[n], ['0'..'9']) do Inc(n);
    if n > m + 6 then
    begin
      wn := Copy(s,m+6,n-m-6);
      nr := StrToIntDef(wn, 30);
    end;
    w := CreateLoremString(nr);
    Result := StringReplace(s,'@lorem'+wn,w,[]);
  end;

  function ExtractText(const s: string; out sText: string): string;
  var
    n,np,i: Integer;
  begin
    Result := s;
    n := Pos('{', Result);
    if (n > 0) then
    begin
      while (n > 1) and (Result[n-1] = '$') do
        n := Pos('{', Result, n + 1);

      if n = 0 then Exit;

      np := 1;
      i := n + 1;
      while (i <= Length(Result)) and (np > 0) do
      begin
        if Result[i] = '{' then
          Inc(np)
        else if Result[i] = '}' then
          Dec(np);
        Inc(i);
      end;

      if (i > n) and (np = 0) then
      begin
        sText := Copy(Result,n+1,i-n-2);
        Delete(Result,n,i-n);
      end;
    end;
    if Pos('@lorem',sText) > 0 then
      sText := InsertLoremString(sText);
  end;

  function ExtractAttribute(const s: string; out sa: string): string;
  var
    n,m: Integer;
  begin
    n := Pos('[', s);
    if (n > 0) then
    begin
      Result := Copy(s,1,n-1);
      m := Pos(']', s);
      if m > 0 then
        sa := Copy(s,n+1,m-n-1);
    end
    else
    begin
      Result := s;
      sa := '';
    end;
  end;

  function ExtractIdAndClass(const s: string; var sd, sc: string): string;
  var
    n,m: Integer;
    w,ws: string;
  begin
    Result := s;
    n := Pos('#', s);
    m := Pos('.', s);
    if (n > 0) or (m > 0) then
    begin
      if (n > 0) and (m > 0) then
        n := Min(n,m)
      else
        n := Max(n,m);

      m := n;
      while (n <= Length(s)) and not CharInSet(s[n], [#9,#32,'^','>','+','*','{','[','(']) do Inc(n);
      w := Copy(s,m,n-m);
      Delete(Result,m,n-m);

      // Extract id
      n := Pos('#',w);
      if n > 0 then
      begin
        sd := 'id="';
        while n > 0 do
        begin
          m := n;
          Inc(n);
          while (n <= Length(w)) and not CharInSet(w[n], ['#','.']) do Inc(n);
          ws := Copy(w,m+1,n-m-1);
          sd := sd + ws + #32;
          Delete(w,m,n-m);
          n := Pos('#',w);
        end;
        sd := Trim(sd) + '"';
      end;

      // Extract class
      n := Pos('.',w);
      if n > 0 then
      begin
        sc := 'class="';
        while n > 0 do
        begin
          m := n;
          Inc(n);
          while (n <= Length(w)) and not CharInSet(w[n], ['#','.']) do Inc(n);
          ws := Copy(w,m+1,n-m-1);
          sc := sc + ws + #32;
          Delete(w,m,n-m);
          n := Pos('.',w);
        end;
        sc := Trim(sc) + '"';
      end;
    end
    else
    begin
      sd := '';
      sc := '';
    end;
  end;

  function GetSnippet(const sn: string): string;
  begin
    Result := '';
    if FAbbreviations.ValueExists(FSyntaxSnippetKey,sn) then
    begin
      Result := FAbbreviations.ReadString(FSyntaxSnippetKey,sn,'');
      FExtendedSyntax := False;
    end;

    if Result <> '' then Exit;

    if FAbbreviations.ValueExists(FExtendsSnippetKey,sn) then
    begin
      Result := FAbbreviations.ReadString(FExtendsSnippetKey,sn,'');
      FExtendedSyntax := True;
    end;
  end;

  function ExistsAbbreviation(const sn: string): Boolean;
  begin
    Result := FAbbreviations.ValueExists(FSyntaxKey, sn);
    if not Result then
      Result := FAbbreviations.ValueExists(FExtendsKey, sn)
  end;

  function GetAbbreviation(const sn: string): string;
  begin
    Result := '';
    FExtendedSyntax := False;
    Result := FAbbreviations.ReadString(FSyntaxKey, sn, '');
    if Result = '' then
    begin
      Result := FAbbreviations.ReadString(FExtendsKey, sn, '');
      FExtendedSyntax := True;
    end;
  end;

begin
  Result := '';
  bDone := False;
  s := Trim(Copy(AString,index,len));

  // Snippet?
  sValue := GetSnippet(s);
  if sValue <> '' then
  begin
    Result := sValue;
    Result := StringReplace(Result, '\n', #13#10, [rfReplaceAll]);
    Result := StringReplace(Result, '\t', #9, [rfReplaceAll]);
    Exit;
  end;

  // Get text
  s := ExtractText(s, sText);

  // Get attribute
  sn := ExtractAttribute(s, sAttr);

  // Get id and class
  sn := ExtractIdAndClass(sn, sId, sClass);

  if ExistsAbbreviation(sn) then
  begin
    st := StringOfChar(#9,indent);
    ls := TStringList.Create;
    try
      sn := GetAbbreviation(sn);
      if (Length(sn) > 0) and (sn[1] <> '<') then
      begin
        sn := ExpandTagAbbrev(sn, indent);
        st := '';
        bDone := True;
      end;
    finally
      ls.Free;
    end;
    if (Length(sn) > 0) and (sn[1] = '<') then
    begin
      Result := st + InsertUserAttribute(sn,sAttr,sId,sClass) + sText;
      Result := StringReplace(Result, '\n', #13#10, [rfReplaceAll]);
      Result := StringReplace(Result, '\t', #9, [rfReplaceAll]);
      if not bDone then AddToTagList(sn,'');
      Exit;
    end;
    Result := st + sn + sText;
    Result := StringReplace(Result, '\n', #13#10, [rfReplaceAll]);
    Result := StringReplace(Result, '\t', #9, [rfReplaceAll]);
    if not bDone then AddToTagList(sn,'');
    Exit;
  end;

  if (sAttr <> '') or (sId <> '') or (sClass <> '') then
  begin
    Result := AddTag(sn,sAttr,sId,sClass,sText,indent);
    Result := StringReplace(Result, '\n', #13#10, [rfReplaceAll]);
    Result := StringReplace(Result, '\t', #9, [rfReplaceAll]);
    Exit;
  end;

  // Tag?
  if (Length(s) > 0) and (s[1] = '<') then
  begin
    Result := s;
    AddToTagList(s,sText);
    Exit;
  end;

  Result := AddTag(s,'','','',sText,indent);
  Result := StringReplace(Result, '\n', #13#10, [rfReplaceAll]);
  Result := StringReplace(Result, '\t', #9, [rfReplaceAll]);
end;

function TEmmet.CreateTagAndClass(var s: string; const sClass: string): string;
var
  w: string;
begin
  Result := '';
  if s = '' then
  begin
    if FTagList.Count > 0 then
    begin
      w := FTagList[FTagList.Count-1];
      if w <> '' then
        w := Copy(w,3,Length(w)-3);
    end;
    if FAbbreviations.ValueExists('elementmap', w) then
    begin
      s := FAbbreviations.ReadString('elementmap', w, '');
      Result := '<' + s + #32 + sClass + '>';
    end
    else if FTagInlineLevel.IndexOf(w) >= 0 then
    begin
      s := 'span';
      Result := '<span ' + sClass + '>'
    end
    else
    begin
      s := 'div';
      Result := '<div ' + sClass + '>';
    end;
  end
  else
  begin
    if FTagInlineLevel.IndexOf(s) >= 0 then
      Result := '<' + s + '>' + '<span ' + sClass + '></span>'
    else
      Result := '<' + s + #32 + sClass + '>';
  end;
end;

function TEmmet.ExtractUserAttributes(const sAttribute: string): string;
var
  i,n: Integer;
  sn,sa: string;
  ls: TStringList;
begin
  Result := '';
  ls := TStringList.Create;
  try
    i := Pos(#32,sAttribute);
    if i > 0 then
    begin
      n := 1;
      i := 1;
      while (i <= Length(sAttribute)) do
      begin
        if sAttribute[i] = '"' then
        begin
          i := Pos('"',sAttribute,i+1);
          if i > 0 then
          begin
            ls.Add(Copy(sAttribute,n,i-n+1));
            Inc(i);
            n := i;
          end;
        end
        else if sAttribute[i] = #32 then
        begin
          ls.Add(Copy(sAttribute,n,i-n));
          n := i+1;
        end
        else if i = Length(sAttribute) then
        begin
          ls.Add(Copy(sAttribute,n,i-n+1));
          n := i+1;
        end;
        Inc(i);
      end;
    end
    else
    begin
      ls.Add(sAttribute);
    end;

    for i := 0 to ls.Count - 1 do
    begin
      sa := ls.ValueFromIndex[i];
      if (sa <> '') and (sa[1] = #39) then
        sa := StringReplace(sa, #39, '"', [rfReplaceAll])
      else if (sa = '') then
        sa := '""'
      else if (sa <> '') and (sa[1] <> '"') then
        sa := '"' + sa + '"';

      sn := ls.Names[i];
      if sn = '' then sn := ls[i];
      Result := Result + #32 + sn + '=' + sa;
    end;
  finally
    ls.Free;
  end;
end;

function TEmmet.FormatSelection(const s: string; const ind: Integer): string;
var
  n,m: Integer;
  w,wt: string;
begin
  Result := '';
  m := 1;
  wt := StringOfChar(#9, ind);
  n := Pos(#13#10, s);
  while m > 0 do
  begin
    if n > 0 then
    begin
      w := Trim(Copy(s,m,n-m+1));
      if w <> '' then
        Result := Result + wt + w + #13#10;
      m := n + 2;
    end
    else
    begin
      w := Trim(Copy(s,m,Length(s)));
      if w <> '' then
        Result := Result + wt + w + #13#10;
      Exit;
    end;
    n := Pos(#13#10, s, m);
  end;
end;

function TEmmet.GetAbbreviationNames(const ASyntax: string; var AList:
    TStringList): Boolean;
var
  sa,se: string;
  ls: TStringList;
begin
  ls := TStringList.Create;
  try
    sa := 'abbreviations-' + ASyntax;
    se := FAbbreviations.ReadString(ASyntax,'extends','');
    FAbbreviations.ReadSection(sa,ls);
    AList.AddStrings(ls);
    if se <> '' then
    begin
      se := 'abbreviations-' + se;
      FAbbreviations.ReadSection(se,ls);
      AList.AddStrings(ls);
    end;
  finally
    ls.Free;
  end;
  Result := AList.Count > 0;
end;

function TEmmet.GetSnippetNames(const ASyntax: string; var AList: TStringList):
    Boolean;
var
  sc,se: string;
  ls: TStringList;
begin
  ls := TStringList.Create;
  try
    sc := 'snippets-' + ASyntax;
    se := FAbbreviations.ReadString(ASyntax,'extends','');
    FAbbreviations.ReadSection(sc,ls);
    AList.AddStrings(ls);
    if se <> '' then
    begin
      se := 'snippets-' + se;
      FAbbreviations.ReadSection(se,ls);
      AList.AddStrings(ls);
    end;
  finally
    ls.Free;
  end;
  Result := AList.Count > 0;
end;

function TEmmet.InsertSelection(s: string; const bOneLine: Boolean = False):
    string;
var
  i,n,ind: Integer;
  ws,wt: string;
  wsel: string;

  function GetFirstLine: string;
  var
    n: Integer;
  begin
    n := Pos(#13#10, FSelection);
    if n = 0 then
    begin
      Result := Trim(FSelection);
      FSelection := '';
      Exit;
    end;
    Result := Trim(Copy(FSelection, 1, n-1));
    Delete(FSelection, 1, n+1);
    while (Result = '') and (FSelection <> '') do
    begin
      n := Pos(#13#10, FSelection);
      if n > 0 then
      begin
        Result := Trim(Copy(FSelection, 1, n-1));
        Delete(FSelection, 1, n+1);
      end
      else
      begin
        Result := Trim(FSelection);
        FSelection := '';
      end;
    end;
  end;
begin
  s := StringReplace(s,'|','',[rfReplaceAll]);
  Result := s;
  if bOneLine then
    wsel := GetFirstLine
  else
    wsel := FSelection;
  n := 0;
  ind := 1;
  i := Length(s);
  while i > 0 do
  begin
    if (s[i] = '>') then n := i;
    if (s[i] = '<') and (s[i+1] = '/') then
    begin
      ind := 1;
      n := 0;
    end
    else if (s[i] = '<') and (s[i+1] <> '/') then
    begin
      ind := 1;
      while (i > 1) and (s[i-1] = #9) do
      begin
        Inc(ind);
        Dec(i);
      end;
      Break;
    end;
    Dec(i);
  end;
  if n > 0 then
  begin
    if bOneLine then
      Result := Copy(s,1,n) + wsel + Copy(s,n+1,Length(s))
    else
    begin
      wt := StringOfChar(#9, ind-1);
      ws := #13#10 + FormatSelection(wsel, ind);
      Result := Copy(s,1,n) + ws + wt + Copy(s,n+1,Length(s));
    end;
  end;
end;

function TEmmet.ProcessTagGroup(const AString: string; const index: Integer;
    out ipos: Integer; const indent: Integer): string;
var
  np: Integer;
  TagListCount: Integer;
begin
  Result := '';
  TagListCount := FTagList.Count;
  ipos := index + 1;
  np := 1;
  while (ipos <= Length(AString)) and (np > 0) do
  begin
    if AString[ipos] = '(' then
      Inc(np)
    else if AString[ipos] = ')' then
      Dec(np);
    Inc(ipos);
  end;


  if (ipos <= Length(AString)) and (AString[ipos] = '*') then
  begin
    // multiply group
    Inc(ipos);
    while (ipos <= Length(AString)) and CharInSet(AString[ipos], ['0'..'9']) do Inc(ipos);
    Result := Result + ProcessTagMultiplication(AString,index,ipos-index,indent);
  end
  else
  begin
    Result := Result + ExpandTagAbbrev(Copy(AString,index+1,ipos-index-2),indent);
  end;

  if (FTagList.Count > 0) and (FTagList.Count > TagListCount) then
  begin
    Result := Result + FTagList[FTagList.Count-1];
    FTagList.Delete(FTagList.Count-1);
  end;

  if (Length(Result) > 0) and (Result[Length(Result)] <> #10) then
    Result := Result + #13#10;

  Dec(ipos);
end;

function TEmmet.ProcessTagMultiplication(const AString: string; const index,
    len, indent: Integer): string;
var
  i,n,num,numlen: Integer;
  nStart,nIndex,nInc: Integer;
  s,w: string;
  bAddSelection: Boolean;

  function GetExpression(const ws: string; n, i: Integer): string;
  var
    np: Integer;
  begin
    np := 0;
    if (i > 0) and (ws[i] = ')') then
    begin
      Dec(i);
      np := -1;
      while (i >= index) and (np < 0) do
      begin
        if ws[i] = '(' then
          Inc(np)
        else if ws[i] = ')' then
          Dec(np);
        Dec(i);
      end;
      Result := Copy(ws,i+1,n-i-1);
    end
    else
    begin
      while (i > 0) do
      begin
        if CharInSet(ws[i], ['{']) then Inc(np);
        if CharInSet(ws[i], ['}']) then Dec(np);
        if (np = 0) and CharInSet(ws[i], ['@']) then n := i;
        if CharInSet(ws[i], ['>','^']) then Break;
        Dec(i);
      end;
      Result := Copy(ws,i+1,n-i-1);
    end;
  end;

  function GetNumber(const ws: string; n, i: Integer; var nrlen: Integer; out astart, ainc: Integer): Integer;
  var
    sn: string;
  begin
    Result := 0;

    // Multiplier
    while (i <= Length(ws)) and CharInSet(ws[i], ['0'..'9']) do Inc(i);
    sn := Copy(ws,n+1,i-n-1);
    if sn <> '' then
      Result := StrToInt(sn);

    nrlen := Length(sn);

    if (Result = 0) and (FSelection <> '') then
    begin
      Result := CountLines(FSelection);
      bAddSelection := True;
    end;

    // Start and direction
    i := n - 1;
    while (i > 0) and CharInSet(ws[i], ['0'..'9']) do Dec(i);
    if ws[i] = '-' then
    begin
      astart := Result;
      ainc := -1;
    end;
    sn := Copy(ws,i+1,n-i-1);
    if sn <> '' then
      astart := StrToInt(sn);
  end;

  function ReplaceVariables(const s: string; const nr: Integer): string;
  var
    sn,w: string;
    i,n: Integer;
  begin
    Result := s;
    n := Pos('$',Result);
    while n > 0 do
    begin
      i := n + 1;
      while (i <= Length(Result)) and (Result[i] = '$') do Inc(i);
      w := StringOfChar('$',i-n);
      if i-n > 1 then
        sn := Format('%.*d',[i-n, nr])
      else
        sn := IntToStr(nr);
      Result := StringReplace(Result,w,sn,[]);
      n := Pos('$',Result);
    end;
  end;

begin
  Result := '';
  bAddSelection := False;
  n := Pos('*',AString);
  nInc := 1;
  nStart := 1;

  // Get expression
  i := n - 1;
  s := GetExpression(AString,n,i);

  // Get number
  i := n + 1;
  num := GetNumber(AString,n,i,numlen,nStart,nInc);
  Inc(i,numlen);

  // handle '>' after number
  if (i <= Length(AString)) and (AString[i] = '>') then
  begin
    n := i;
    Inc(i);
    while (i <= Length(AString)) and not CharInSet(AString[i], ['>','+','^']) do Inc(i);
    s := s + Copy(AString,n,i-n);
  end;

  if num > 0 then
  begin
    nIndex := nStart;
    while num > 0 do
    begin
      w := ExpandTagAbbrev(s,indent);
      if bAddSelection then
        w := InsertSelection(w, True);
      w := ReplaceVariables(w, nIndex);
      Result := Result + w;
      Dec(num);
      Inc(nIndex,nInc);
    end;
  end;
end;

end.
