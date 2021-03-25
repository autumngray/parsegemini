# parsegemini
A simple parser for text/gemini content. Read the documentation at the [Gemini Project Website](https://gemini.circumlunar.space) for more information.

## Usage
```nim
  import streams

  const gemtext = """
# Hello, Gemini!
=> gemini://example.com Look, a link!

```alt text
some
  verbatim
     text
```
"""
var p: GeminiParser
open(p, newStringStream(gemtext))
while true:
  p.next()
  case p.kind
  of gmiEof: break
  of gmiLink: echo $p.kind & " " & p.uri & " " & p.text
  else: echo $p.kind & " " & p.text
close(p)
```
