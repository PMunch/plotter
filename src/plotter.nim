import std / [terminal, math, strutils, locks, enumerate, sequtils, atomics]
import unicode except align
import drawille, ansiparse
import xresources

type
  RollingWindow[T] = object
    window: seq[T]
    index: int
  Frame* = object
    highest*, lowest*: float
    frame*: string

proc initRollingWindow[T](size: int, default = default(T)): RollingWindow[T] =
  result.window = newSeqWith[T](size, default)

proc add[T](x: var RollingWindow[T], y: T) =
  x.window[x.index] = y
  x.index = (x.index + 1) mod x.window.len

proc len(x: RollingWindow): int = x.window.len

proc min[T](x: RollingWindow[T]): T =
  result = T.high
  for i in 0..x.window.high:
    result = min(result, x.window[i])

proc max[T](x: RollingWindow[T]): T =
  for i in 0..x.window.high:
    result = max(result, x.window[i])

proc `[]`[T](x: RollingWindow[T], index: int): T =
  x.window[(x.index + index) mod x.window.len]

proc ansiSubStr(x: string, strip: int): string =
  let ansiData = x.parseAnsi()
  var
    toStrip = strip
    res: seq[AnsiData]
  for dat in ansiData:
    if dat.kind == String:
      if dat.str.runeLen <= toStrip:
        toStrip -= dat.str.runeLen
      elif toStrip <= 0:
        res.add dat
      else:
        res.add AnsiData(kind: String, str: dat.str.runeSubStr(toStrip))
        toStrip = 0
    else:
      res.add dat
  res.add AnsiData(kind: CSI, parameters: "0", intermediate: "", final: 'm')
  res.toString

let colours = loadColours().colours

var
  shouldQuit: Atomic[bool]
  datas: seq[RollingWindow[float]]
  frameLock: Lock
  latestFrame {.guard: frameLock.}: Frame
  (width, height) = terminalSize()

initLock(frameLock)
height -= 2
var c = newColourCanvas(width, height)
echo c

proc drawer() {.thread.} =
  while not shouldQuit.load:
    stdout.hideCursor()
    var msg: Frame
    withLock(frameLock):
      {.cast(gcsafe).}:
        msg = deepCopy(latestFrame)
    let
      lowest = msg.lowest
      highest = msg.highest
      graph = msg.frame
    echo "\e[A\e[K".repeat(height + 2)
    let
      lowlabel = lowest.formatFloat(precision = -1)
      highlabel = highest.formatFloat(precision = -1)
      columnWidth = max(lowlabel.len, highlabel.len) + 1
    var i = 0
    for line in graph.splitLines:
      if i == 0:
        stdout.write (highLabel & "|").align(columnWidth), line.ansiSubStr(columnWidth)
      elif i == height - 1:
        stdout.write (lowLabel & "|").align(columnWidth), line.ansiSubStr(columnWidth)
      elif highest > 0 and lowest < 0 and i == ((highest / (highest - lowest)) * height.float).int:
        stdout.write "0|".align(columnWidth), line.ansiSubStr(columnWidth)
      else:
        stdout.write "|".align(columnWidth), line.ansiSubStr(columnWidth)
      inc i
    stdout.flushFile()
    stdout.showCursor()

var drawerThread: Thread[void]
createThread(drawerThread, drawer)

proc ctrlc() {.noconv.} =
  shouldQuit.store true
  drawerThread.joinThread
  deinitLock(frameLock)
  quit()

setControlCHook(ctrlc)

while true:
  var
    lowest = float.high
    highest = 0.0
  for data in datas:
    lowest = min(lowest, data.min)
    highest = max(highest, data.max)
  let range = highest - lowest
  for i in 0..<(width*2):
    if range != 0:
      for j, data in datas:
        if data[i] != data[i]: continue # data[i] is NaN
        c.set(i, (height - 1)*4 - (((data[i] - lowest) / range) * (height - 1).float * 4).int, colours[j mod colours.len])

  withLock(frameLock):
    {.cast(gcsafe).}:
      latestFrame = Frame(lowest: lowest, highest: highest, frame: $c)

  c.clear()
  let input = try: stdin.readLine except EOFError: break
  for i, data in enumerate input.split(Whitespace + {','}):
    while datas.high < i:
      datas.add initRollingWindow[float](width*2, NaN)
    datas[i].add(try: data.parseFloat() except: NaN)

ctrlc()
