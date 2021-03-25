import lexbase, streams

## This module implements a simple parser for `text/gemini` content
## of the `Gemini Project <https://gemini.circumlunar.space>`_.

runnableExamples:
  import streams

  const gemtext = """
# Hello, Gemini!
=> gemini://example.com Look, a link!
"""

  var p: GeminiParser
  open(p, newStringStream(gemtext))
  p.next()
  assert p.kind == gmiHeader1 and p.text == "Hello, Gemini!"
  p.next()
  assert p.kind == gmiLink and p.uri == "gemini://example.com" and p.text == "Look, a link!"
  close(p)

type
  GeminiLineEvent* = enum ## Enumeration of all events that may occur when parsing
    gmiEof                ## End of file reached
    gmiText               ## Normal text
    gmiHeader1            ## '#' Header level one
    gmiHeader2            ## '##' Header level two
    gmiHeader3            ## '###' Header level three
    gmiListItem           ## '* ' List item
    gmiLink               ## '=> [URI [TEXT]]' link
    gmiQuote              ## '>' Quoted text
    gmiVerbatimMarker     ## '```[ALT]' Start/end of preformatted texts, with optional alt-text
    gmiVerbatim           ## Preformatted text following a verbatim start marker

  GeminiParser* = object of BaseLexer ## The parser object.
    kind: GeminiLineEvent
    a: string
    b: string
    verbatim: bool

proc open*(p: var GeminiParser, input: Stream) =
  ## Initializes the parser with an input stream.
  lexbase.open(p, input)
  p.kind = gmiEof
  p.verbatim = false

proc close*(p: var GeminiParser) {.inline.} =
  ## Closes the parser `p` and its associated input stream.
  lexbase.close(p)

proc kind*(p: var GeminiParser): GeminiLineEvent {.inline.} =
  ## Returns the current line type for the Gemini parser.
  p.kind

template text*(p: GeminiParser): string =
  ## Returns the current line text excluding line markers.
  ## For the event `gmiLink`, the uri text is not included,
  ## use `uri <#uri.t,GeminiParser>`_.
  p.a

template uri*(p: GeminiParser): string =
  ## Returns the uri for the event: `gmiLink`.
  ## Raises an assertion in debug mode, if `p.kind` is not
  ## `gmiLink`. In release mode, this will not trigger an error
  ## but the value returned will not be valid.
  assert p.kind == gmiLink
  p.b

proc next*(p: var GeminiParser) =
  ## Retrieves the first/next event. This controls the parser.
  template skipWs =
    while p.buf[pos] in {' ', '\t'}:
      inc pos

  setLen(p.a, 0)
  setLen(p.b, 0)
  var pos = p.bufpos
  if p.buf[pos] == '\0':
    p.kind = gmiEof
    return

  if p.buf[pos] == '`' and p.buf[pos+1] == '`' and p.buf[pos+2] == '`':
    inc(pos, 3)
    p.verbatim = not p.verbatim
    p.kind = gmiVerbatimMarker
  elif p.verbatim:
    p.kind = gmiVerbatim
  else:
    p.kind = gmiText
    case p.buf[pos]
    of '=':
      if p.buf[pos+1] == '>':
        p.kind = gmiLink
        inc(pos, 2)
        skipWs
        let uriStart = pos
        while p.buf[pos] notin {'\0', ' ', '\t', '\r', '\n'}:
          inc pos
        for i in uriStart..<pos:
          p.b.add p.buf[i]
        skipWs
    of '*':
      if p.buf[pos+1] == ' ':
        inc(pos, 2)
        p.kind = gmiListItem
    of '>':
      p.kind = gmiQuote
      inc pos
      skipWs
    of '#':
      p.kind = gmiHeader1
      inc pos
      if p.buf[pos] == '#':
        p.kind = gmiHeader2
        inc pos
      if p.buf[pos] == '#':
        p.kind = gmiHeader3
        inc pos
      skipWs
    else: discard

  let textStart = pos
  while p.buf[pos] notin {'\0', '\r', '\n'}:
    inc pos
  for i in textStart..<pos:
    add(p.a, p.buf[i])
  if p.buf[pos] == '\r':
    pos = lexbase.handleCR(p, pos)
  elif p.buf[pos] == '\n':
    pos = lexbase.handleLF(p, pos)

  p.bufpos = pos
