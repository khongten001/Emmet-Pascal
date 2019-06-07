# Emmet engine for Delphi and Free Pascal

Emmet is mostly used by web-developers to simplify and speed up editing. Emmet can take
an abbreviation and expand it into a structured code block. Standard Emmet is written in
JavaScript and available in many text editors or web development tools. Emmet for Delphi
and Free Pascal is written from scratch in Delphi and is used in RJ TextEd (
https://www.rj-texted.se).

## Getting Started

Download the files and include the Pascal files in your project.

### Usage

First you need to create an Emmet object.

```
FEmmet := TEmmet.Create(snippetsPath, loremPath);
```

* snippetsFile      = The file path to snippets.ini e.g. "c:\foo\Snipptes.ini"
* loremFile         = The file path to Lorem.txt e.g. "c:\foo\Lorem.txt"

To expand an abbreviation use

```
sExpanded := FEmmet.ExpandAbbreviation(sAbbr, sSyntax, sSelText, sSection, bMultiCursorTabs);
```

#### Parameters

* **sAbbr**: Abbreviation e.g. "ul>li*5"

* **sSyntax**: Code language in lowercase e.g. "html". Available values are: html, css, xsl, svg, xml, jsx, less, sass, scss.

* **sSelText**: Text is used to wrap with abbreviation

* **sSection**: Gets the section used in snippets.ini e.g. "html"

* **bMultiCursorTabs**: Gets True if cursor positions in expanded string should be handled as multi cursor positions

#### Result
sExpanded is the resulting expanded code. It may contain cursor | positions or selected tab ${1:charset} positions.

## Cheat sheets
* **Emmet-Pascal** - [Cheat sheet](https://www.rj-texted.se/Help/Emmetcheatsheet.html)
* **Standard Emmet** - [Cheat sheet](https://docs.emmet.io/cheat-sheet/)

## Authors

* **Rickard Johansson** - *TEmmet.pas* - [RJ TextEd forum](https://www.rj-texted.se/Forum/index.php)
* **Alexey Torgashin** - *Misc files and demos* - [GitHub](https://github.com/Alexey-T)
