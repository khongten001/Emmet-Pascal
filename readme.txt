Post by Rickard Johansson » 30 May 2019 13:59
In RJ TextEd I wrote my own version of Emmet. It is not based on the original Emmet code, but written from scratch in Delphi (object pascal).

You are perfectly free to use it in your own code or applications. But if you're using it in a commercial product I would appreciate a donation.

The Emmet code only expand abbreviation or wrap text with abbreviation. All other editor stuff like handle tab points or multi cursors you will have to handle yourself in your own code. That's what I do in RJ TextEd.

------------------------------------
Unit Name: Emmet
Author:    Rickard Johansson  (https://www.rj-texted.se/Forum/index.php)
Date:      30-May-2019
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
