# ocurves demo

A 40 second showcase of ocurves, music included: 1920x1080, 60 fps,
downtempo at 96 BPM. It is an [onimite](https://github.com/defnotmid/onimite)
script (Odin + Lua video framework, which draws with
[ovg](https://github.com/defnotmid/ovg), which fills with ocurves), not part
of ocurves' build. The render, `demo.mp4`, is not in the repository: make
it with onimite's release binary (`onimite update` keeps it current), from
ocurves' root:

```sh
onimite render demo/video.lua -o demo/demo.mp4 --qp 22   # the render
onimite preview demo/video.lua                           # play, hot reload on save
```

Everything it shows is data baked by `bake/main.odin` into
`media/bake.json`, against the ocurves and ovg checkouts beside this one
(ocurves v0.0.6, ovg v0.0.52), which prints every number the video shows:

```sh
sh demo/fetch.sh                                                   # once: Adwaita Sans, SHA-256 checked
odin run demo/bake -collection:deps=.. -o:speed -- demo/media/bake.json
```

The bake draws on a GPU (SDL_GPU, headless) for the GPU twin scene.

| bars | scene | what |
| --- | --- | --- |
| 1-2 | Title | a cubic draws itself on with its handles, Bez slides in, the wordmark lands |
| 3-5 | Shapes | an '&' (Instrument Serif Italic, 620 px) drawn on, its monotone quadratic pieces arriving in order, the grid of cells with their backdrops and piece counts |
| 6-8 | Coverage | the '&' at 22 px, zoomed: 4x MSAA, ocurves' exact coverage and a 128 x 128-sample reference, then each one's error against the reference |
| 9-11 | Booleans | a circle and an S: union, difference, intersection, xor, each segment coloured by the operand it is a range of, its cubic's handles shown; then bool_divide's faces |
| 12-13 | GPU twin | the 22 px '&' drawn by ovg's software rasterizer (ocurves' coverage) and its SDL_GPU backend (curves.slang), and their difference |
| 14-16 | Outro | Bez, the wordmark, the facts |

## Facts on screen

Every number is in `facts.lua`, read from `media/bake.json` with its
command, except the two from elsewhere: ovg's `tools/bool_suite` (seeds 1
and 7, 2,000 cases each: 0 wrong in 32,000 results) and ocurves' test count
(`odin test . -vet -strict-style`).

## Files

- `video.lua`, `beat.lua`, `timeline.lua`, `ui.lua`, `scenes/`: the video,
  its clock and springs on the song's beat, where everything happens (read
  from the song), the shared drawing and Bez, a file per scene.
- `data.lua` reads `media/bake.json`; `facts.lua` names its numbers.
- `bake/main.odin`: the bake.
- `track.lua`: the soundtrack, an odawg `song{}`, downtempo after Bonobo's
  "Kiara" (Black Sands, 2010) in D minor at 96 BPM: a harp's sixteenths
  climbing a chord and coming back down every bar (an arch, the picture's
  curve), a jazz kit's cross-stick groove with the shapes and its snare
  backbeat with the booleans, a fingered bass and a soft grand, string
  sections from the coverage on, the drums dropping to hats under the GPU
  twin. Its glockenspiel notes are the picture's pops, the timpani its
  impacts, the kick its pulse.
- `media/`: the fonts (SIL OFL 1.1, `media/OFL.txt`), `bez.svg` (the
  mascot), the baked data, the instrument pins, and `.gitignore` for what
  `fetch.sh` downloads.

## Credits

- Instruments, CC0: VS Chamber Orchestra 2: Community Edition (harp,
  glockenspiel, timpani; Versilian Studios) at a pinned commit, checked
  against `media/pins/vsco.pins`; odawg's sets: the Osiris soft grand,
  Karoryfer's fingered bass (growlybass), the Virtuosity jazz kit and VSCO
  2's string sections.
- Fonts: Bebas Neue, Space Grotesk, JetBrains Mono and Instrument Serif
  (SIL OFL 1.1), copied from onimite's examples; Adwaita Sans (GNOME, from
  Inter; SIL OFL 1.1), fetched for the bake's budget measure; Bitstream
  Vera, which ovg carries.
- Bez: drawn for this demo (CC0), a snake whose body is a cubic Bézier.

Made with onimite; music by odawg.
