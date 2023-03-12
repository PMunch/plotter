# Package

version       = "0.1.0"
author        = "Peter Munch-Ellingsen"
description   = "Simple tool to plot input piped to it"
license       = "MIT"
srcDir        = "src"
bin           = @["plotter"]


# Dependencies

requires "nim >= 1.6.10"
requires "drawille"
requires "ansiparse"
