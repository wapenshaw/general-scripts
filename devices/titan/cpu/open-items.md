# Open items

- [x] [BIOS screenshots transcribed (defaults + XMP)](bios-settings.md).
- [x] VBS off confirmed after reboot; ThrottleStop 9.7 FIVR offsets apply (−25 mV verified 09:05: VID −27.5 mV at 5.3 GHz, −24.9 mV at 5.4 GHz). Launch ThrottleStop with `Start-Process -Verb RunAs`; inline `sudo` leaves it hung with no window.
- [x] Re-run the stock Cinebench baseline on defaults + XMP ([Run 1](runs.md): 27,938).
- [x] Cooler: **DeepCool AK620** (black), dual tower, 2× 120 mm, rated 260 W; fans already at max (~1,930 RPM) in Cinebench. Tom's Hardware: an unlimited 13700K throttles on even the best air coolers; the AK620 matches the NH-D15S. ~221 W at 98.5 °C ([Run 3](runs.md)) is a bit worse than an AK620 should manage, so the PTM/mount may cost a few °C; room ambient **~26 °C** during [Runs 1–4](runs.md) (a clock on the case read 31 °C, which is case air, not room). Reviews use ~22–23 °C, so ~3–4 °C penalty; [Run 3](runs.md) ≈ 95 °C at review ambient, a little warm for an AK620 at 221 W. Case air ~5 °C above room suggests case airflow is worth checking. Size the power limit with margin for hotter days. Plan: power limit to stop throttling, remount PTM later and compare.
- [ ] Offset sweep with CoreCycler, then translate to BIOS Lite Load / AC LL.
- [ ] Keep stock boost ratios; test single-core/gaming stability at the undervolt (CoreCycler per-core).
- [ ] Set a CPU VR voltage cap (no overvolting at single-core boost).
- [ ] Find the all-core power limit where Cinebench settles just under Tj,max (no thermal throttle flags). User rejected the MSI-forum mid-80s target: maximise clocks, the only constraint is zero throttle flags over 10 min (aim peak core ≤ ~96 °C for a few °C of ambient margin).
- [x] Re-enabled VBS, HVCI, Enhanced Sign-in Security and the hypervisor 2026-11-09 04:3x (revert command above; `vsmlaunchtype` removed). Takes effect after the next reboot; confirm with `msinfo32` (VBS Running) and Docker/WSL2 start. ThrottleStop voltage offsets stop working from then on — BIOS settings are unaffected.
