import osproc, strutils
import drawille

type
  XResources* = object
    background*: Colour
    colours*: array[16, Colour]
    cursorColour*: Colour
    foreground*: Colour

proc parseColour(hex: string): Colour =
  result.red = parseHexInt(hex[1..2]).uint8
  result.green = parseHexInt(hex[3..4]).uint8
  result.blue = parseHexInt(hex[5..6]).uint8

proc loadColours*(): XResources =
  # TODO: Create a nicer fallback for Windows machines and machines without xrdb
  for line in execProcess("xrdb -query").splitLines:
    let pair = line.split ":\t"
    if pair.len != 2: continue
    let
      key = pair[0]
      value = pair[1]
    case key:
    of "*.background": result.background = parseColour(value)
    of "*.color0": result.colours[0] = parseColour(value)
    of "*.color1": result.colours[1] = parseColour(value)
    of "*.color10": result.colours[10] = parseColour(value)
    of "*.color11": result.colours[11] = parseColour(value)
    of "*.color12": result.colours[12] = parseColour(value)
    of "*.color13": result.colours[13] = parseColour(value)
    of "*.color14": result.colours[14] = parseColour(value)
    of "*.color15": result.colours[15] = parseColour(value)
    of "*.color2": result.colours[2] = parseColour(value)
    of "*.color3": result.colours[3] = parseColour(value)
    of "*.color4": result.colours[4] = parseColour(value)
    of "*.color5": result.colours[5] = parseColour(value)
    of "*.color6": result.colours[6] = parseColour(value)
    of "*.color7": result.colours[7] = parseColour(value)
    of "*.color8": result.colours[8] = parseColour(value)
    of "*.color9": result.colours[9] = parseColour(value)
    of "*.cursorColor": result.cursorColour = parseColour(value)
    of "*.foreground": result.foreground = parseColour(value)
    else: discard

when isMainModule:
  echo loadColours()

