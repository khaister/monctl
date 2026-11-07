# References

External material relevant to monctl.

## M4/M5 HiDPI limitation on 4K external displays

- Source: [New Apple Silicon M4 & M5 HiDPI Limitation on 4K External Displays](https://smcleod.net/2026/03/new-apple-silicon-m4-m5-hidpi-limitation-on-4k-external-displays/) by Sam McLeod, published 2026-03-29.
- Retrieved 2026-11-06 through a summarizing fetch tool, not the raw page. The cause analysis below is the author's own claim, and Apple has not confirmed it.

Findings from the article:

- On M4 and M5 Macs, the highest HiDPI mode on a 3840x2160 external display is 3360x1890. The author says M2/M3 machines do not have this limit (an M2 Max offered 3840x2160 at scale 2.0).
- The author's analysis is that the display coprocessor (DCP) firmware has a hardcoded sub-pipe 0 width cap of 6720 px, versus 7680 px on M2. A 3840x2160 HiDPI mode needs a 7680 px wide backing store. The author suggests Apple change the constant from 0x1A40 to 0x1E00 and filed Apple Feedback FB22365722.
- EDID patching and plist overrides reportedly had no effect on an M5 Max.
- Workaround from the author: the force-hidpi menu bar app mirrors the panel from a 7680x4320 virtual display. It is a hack, the app must keep running, and text rendering is not identical to native HiDPI. BetterDisplay is mentioned as a related tool.
