# Community tips (2026-11 research)

These are anecdotes, not author documentation. Every card behaves differently.

- **Core undervolt:** a 5080 test held about 3068 MHz at 965 mV (317 W,
  74 °C) and dropped clocks at 960 mV and below
  ([gamegpu](https://en.gamegpu.com/news/zhelezo/rezultaty-andervoltinga-videokarty-geforce-rtx-5080-pri-napryazhenii-965-mv)).
  Another guide reports 2700 MHz at 900 mV saves about 90 W for roughly 0.8 %
  lower scores, and some cards need 940 mV for 2900 MHz
  ([gaming-st](https://gaming-st.com/trouble-settings/gpu-undervolt-guide/)).
  The current 2880 MHz at 895 mV is aggressive by those numbers. Keep it only
  as long as it stays stable.
- **Core offset:** Reddit and Overclockers UK reports cluster around +240 to
  +350 MHz, and most 5080s reportedly reach +300
  ([Overclockers UK](https://forums.overclockers.co.uk/posts/38139126/)).
- **Memory:** +3000 MHz (Afterburner units) is common on 5080s. Tune memory
  separately, after the core is stable.
- **MSVDD undervolt:** results on 5090s conflict. One user cut about 60 W in
  Steel Nomad and another saw no effect
  ([Hardwareluxx](https://www.hardwareluxx.de/community/posts/31249041/)).
  There's no measured benefit for a 5080 yet, so test it on this card.
- **Testing:** change one setting at a time and keep memory at stock until the
  core is stable
  ([evezone](https://evezone.evetech.co.za/build-lab/rtx-5080-undervolting-guide-cooler-quieter-step-by)).
  Run OCCT or a long game session. Short benchmarks can pass while games still
  crash. A setting the driver accepts is not proof of stability.

## XBAR (crossbar) and Reddit findings (2026-11-04)

**What XBAR is:** the crossbar clock, which moves data between the shader
clusters (GPCs) and the L2 cache and memory controllers. It runs on the
**MSVDD** rail with SYS and Video. The core runs on NVVDD. A core offset
reaches XBAR through `msvdd_clock_ratio` (0.8999 by default on this card).
Under the Steel Nomad loop, XBAR measured 2210–2365 MHz while the core ran at
2790–2865 MHz. Afterburner can't adjust XBAR; mVolt+ can (`--xbar-offset`,
`--xbar-vdemand`, `--msvdd-clock-ratio`, `--vf-curve xbar`).

**Reddit (read in a browser; these are anecdotes):**

| Card | Settings | Result | Thread |
| --- | --- | --- | --- |
| RTX 5080 (Forza Horizon 6, 4K) | XBAR 0 → +400 in +50 steps, core fixed at about 3045 MHz | **75.7 → 80.5 FPS (+6.3 %) for +9 W**. Gains taper above +250 | [r/overclocking: RTX5080 XBAR OC +400](https://www.reddit.com/r/overclocking/comments/1wlcygd/rtx5080_xbar_oc_400mhz_mvolt_0461_61692/) |
| RTX 5080 Gainward Phantom GS (Cyberpunk PT) | +220 core, +3000 memory, 111 % power, XBAR +400 | Crashes at +450. **0.1 % lows get worse as XBAR rises** | same |
| RTX 5080 MSI Ventus (water) | +285 core capped at 3100 (about 0.98 V), XBAR +400 with **ratio 1.0**, +3000 memory, 111 % power, +200 SYS | Steel Nomad about **10,200**, about 330 W gaming | [r/overclocking: XBAR UV/OC results](https://www.reddit.com/r/overclocking/comments/1w609da/xbar_uvoc_please_share_your_results_here_for/) |
| RTX 5080 Asus Prime | 0.990 V, +450 core (about 3080 MHz), XBAR +550 (about 2900 MHz), +2500 memory, 100 % power (360 W) | Steel Nomad **9,650** | same |
| RTX 5080 | Default XBAR 2430 MHz at 1.025 V | Stable at 2630 MHz at 0.900 V | same |
| RTX 5080 Astral | Memory +3000 → **+4800** (needs BIOS override) | Steel Nomad 10,380 → 10,540 | [r/RTX5080: How to use mvolt+](https://www.reddit.com/r/RTX5080/comments/1xm3p00/how_to_use_mvolt_besides_xbar_clock/) |
| RTX 5070 Ti | XBAR +250 with −25 mV | Best Cyberpunk result. **Performance regressed** at +275 and above | XBAR UV/OC results |

**Takeaways:**

- **Capping the requested clock** (`--clock-range`) is reported to undervolt
  better than a flattened curve. The card doesn't drop 1–2 voltage steps below
  the target, so only temperature-driven clock drops remain. This is the method
  `Set-GpuUndervolt.ps1` uses.
- **XBAR instability is often silent.** It shows up as lower FPS or worse lows,
  grey screens, or crashes later in long sessions. Judge each step by FPS and
  1 % lows, not just by whether it passes.
- Typical 5080 XBAR offsets are +250 to +550 MHz. The suggested target is XBAR
  "as close to 3 GHz" as the card allows. Setting `msvdd_clock_ratio` to 1.0
  raises XBAR further, with core and XBAR moving 1:1.
- The core sweet spot is around **3.00–3.08 GHz**. Above that, users report
  lower performance from memory error correction kicking in.
- Memory beyond **+3000** needs mVolt+'s **BIOS override**
  (Settings → Advanced tuning → BIOS override). That override persists across
  reboots.
- The mVolt+ developer posts on the overclock.net RTX 5090 owners thread. An
  options explainer is at about post #40,378 (page 2019).

