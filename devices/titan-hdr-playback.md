# TITAN: HDR movie playback in MPC-HC

Investigated: **2026-11-07**. Applies to TITAN (RTX 5080, driver 621.14) with
the Gigabyte AORUS FO32U2P (QD-OLED, 3840×2160 @ 240 Hz, Windows HDR on,
Windows reports max luminance **800 nits**).

Player stack: MPC-HC with internal LAV Splitter/Video/Audio, **MPC Video
Renderer (MPCVR) 0.10.10.2618** and MPC Audio Renderer.

## Symptom

HDR / Dolby Vision movies looked **very dull**: flat, grey and low in contrast.
MPCVR's stats (Ctrl+J) showed **RTX Video HDR** active on them, although it
should only apply to SDR video. SDR files also used RTX Video HDR, which is
correct for SDR.

Test file: `G:\Movies\Battleship (2012)\Battleship (2012).mkv`, HEVC Main 10,
3840×1600, 60 fps, 10-bit, BT.2020 / SMPTE ST 2084 (PQ), Dolby Vision
**profile 8.1** (HDR10-compatible base layer, RPU present, no enhancement
layer). It turned up as a duplicate of an SDR 1080p H.264 `.mp4` in the
`dupedelete` scan.

## Diagnosis

1. `ffprobe` confirmed the file is HDR and Dolby Vision, so the source was fine:

   ```powershell
   ffprobe -v error -select_streams v:0 `
     -show_entries stream=codec_name,profile,pix_fmt,color_transfer,color_primaries:stream_side_data `
     -of default=nw=1 'G:\Movies\Battleship (2012)\Battleship (2012).mkv'
   ```

2. MPCVR stats while playing the MKV showed the HDR signal was lost **before**
   reaching the renderer:

   ```text
   Input format  : NV12 3840x1600
     Range: 16-235*, Matrix: BT.709*
     Primaries: BT.709*, Function: BT.709*
   VideoProcessor: D3D11 VP, output to R10G10B10A2_UNORM
   HDR processing: Passthrough, RTX Video HDR*
   ```

   `NV12` is 8-bit, and `*` means MPCVR guessed the colorimetry because none
   arrived. PQ-encoded data read as BT.709 gamma looks washed out, and MPCVR
   took it for SDR video, so it applied RTX Video HDR.

3. The LAV Video settings were not the cause. MPC-HC's internal LAV Video
   (`HKCU\Software\MPC-HC\MPC-HC\Internal Filters\LAVVideo`) had P010/P016
   output enabled, and D3D11 hardware decoding (`HWAccel=5`) with `hevc10=1`.

4. **Play → Filters** showed the filter chain: LAV Splitter → LAV Video
   Decoder → **DirectVobSub (auto-loading version)** → MPC Video Renderer.

## Root cause

**Options → Playback → Output → Subtitle Renderer** was set to
**VSFilter/DirectVobSub** (registry `Settings\SubtitleRenderer = 1` in this
build; this value does **not** mean "internal"). DirectVobSub sits between the
decoder and the renderer and burns subtitles into the frames. It only accepts
8-bit YUV, so LAV fell back to NV12 output and dropped the HDR and Dolby Vision
metadata.

DirectVobSub did not appear under External Filters, because MPC-HC loads it
through the subtitle renderer setting.

## Fix

Set **Options → Playback → Output → Subtitle Renderer** to **Internal Subtitle
Renderer**, then reopen the file. Subtitles still appear; MPCVR now draws them
as an overlay.

MPCVR stats after the fix:

```text
Input format  : D3D11_P010 3840x1600
  DolbyVision Profile 8
VideoProcessor: Shaders, Chroma scaling: Bilinear
HDR processing: Passthrough, 1000 nits
```

The full 10-bit signal now reaches MPCVR. The Dolby Vision RPU is applied in
shaders (`Prefer Dolby Vision over PQ and HLG`), RTX Video HDR no longer
applies, and the picture shows its proper contrast.

## MPCVR settings (recommended)

| Setting | Value | Reason |
| --- | --- | --- |
| Prefer Dolby Vision over PQ and HLG | on | Applies DV per-scene metadata instead of the static HDR10 base |
| HDR10/DV | **Passthrough** | The FO32U2P tone-maps HDR itself. The nits box is unused (greyed out) in this mode |
| HDR10/DV, if highlights clip | BT2390/ST 2094-10 at the panel's peak nits (~1000 Peak 1000 mode, ~400 True Black 400) | ITU reference curve that uses DV metadata. Avoid ACES/Reinhard/Hable/Mobius, which change the grade |
| Request Super Resolution | **for ≤ 1080p** (was ≤ 720p) | Lets RTX VSR upscale 1080p SDR to 4K |
| RTX Video HDR | on | Now applies only to SDR sources |
| Use for resizing (D3D11 VP) | on | Needed for VSR on SDR |
| Chroma upsampling / Upscaling / Downscaling | Catmull-Rom / Lanczos3 / Hamming | Fine; shader path only (HDR/DV content) |
| Dithering | on | |
| Texture format | 16-bit Floating Point (optional) | More precision for the DV shader math, at almost no cost on the 5080 |
| Subtitle and OSD brightness | lower if white subtitles are too bright | Subtitle brightness in HDR |

## Checking that HDR is working

Press **Ctrl+J** during playback. For HDR content, expect `P010` input, a
`DolbyVision` line or BT.2020/ST 2084 without `*`, and **no** `RTX Video HDR`
on the HDR processing line. If `NV12` with `BT.709*` comes back, check
**Play → Filters** for a filter between LAV Video Decoder and MPC Video
Renderer.
