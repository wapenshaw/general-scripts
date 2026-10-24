# Lenovo ThinkPad P15v Gen 1

Last inspected: **2026-10-24**. Times below use **Asia/Kolkata (IST, UTC+05:30)**.

## Device

| Item | Value |
| --- | --- |
| Manufacturer | Lenovo |
| Model | ThinkPad P15v Gen 1 |
| Machine type / model | **20TQ004YMX** (type **20TQ**) |
| Operating system at inspection | Fedora Linux 44 Workstation |
| Integrated graphics | Intel UHD Graphics (Comet Lake) |
| Discrete graphics | NVIDIA Quadro P620 |

## Battery replacement identifiers

**Use Lenovo FRU `5B10W13961` as the primary replacement part number.** The
installed battery reports this identifier directly through Linux. Lenovo's
[battery specification table, PDF page 3](https://static.lenovo.com/ww/docs/regulatory/msds/SDS_ATL_21-1.pdf#page=3)
maps it to the model and assembly number below.

| Item | Value |
| --- | --- |
| Battery model | **L19C6P72** |
| Lenovo FRU / replacement part number | **5B10W13961** |
| Lenovo assembly part number (ASM) | **SB10T83204** |
| Manufacturer | Celxpert |
| Design capacity | **68 Wh** |
| Nominal voltage | **11.52 V** |
| Type | Internal rechargeable lithium-polymer battery |

Suggested shopping search:

```text
Lenovo 5B10W13961 L19C6P72 P15v Gen 1 battery
```

[iFixit's genuine Lenovo part listing](https://www.ifixit.com/products/5b10w13961-lenovo-laptop-battery-genuine)
also lists compatibility with ThinkPad P15v Gen 1 types **20TQ / 20TR**. Use this
as a compatibility reference; stock and prices can change. Before ordering, match
the FRU and the laptop's machine type against the seller's listing.

## Charging and performance preferences

The laptop is **mostly used on AC power**. Keep the existing charge limit for
battery longevity, while preserving normal CPU performance.

| Setting | Confirmed value / preference |
| --- | --- |
| Start charging below | **75%** |
| Stop charging at | **80%** |
| Power profile | **Balanced** (`balanced-battery` in TuneD while unplugged) |
| CPU turbo | **Enabled — do not disable** |

Keep the 80% cap for this usage pattern. No charging or power-profile changes
were applied during this inspection.

Lenovo explains that time spent at full charge and high temperatures affect
longevity, and recommends lower charge thresholds for predominantly AC-powered
use. See [Lenovo's runtime versus lifespan guidance](https://support.lenovo.com/us/en/solutions/ht078208-how-can-i-increase-battery-life-thinkpad-and-lenovo-vbke-series-notebooks).

## Battery health snapshot — 2026-10-24

| Measurement | Reading |
| --- | --- |
| Original design capacity | 68 Wh |
| Reported full-charge capacity | **57.23 Wh** |
| Remaining capacity relative to design | **84.16%** |
| Capacity loss relative to design | **15.84%** |
| Reported charge cycles | **106** |
| Observed discharge power during inspection | Roughly **10–12 W** |

Capacity percentage is calculated as `57.23 / 68 × 100`; it is distinct from
the current charge percentage and from the configured 80% charging cap.

### Observed discharge cycle

| Event / measurement | Value |
| --- | --- |
| AC disconnected | **2026-10-24 14:17:52 IST** |
| Starting charge | Approximately **78%** |
| Check time | **2026-10-24 16:59:41 IST** |
| Elapsed time on battery | **2 hours 41 minutes 49 seconds** |
| Charge near check time | **22%** |
| Estimated average power over the cycle so far | Approximately **11.9 W** |
| Projected total runtime from the starting charge | Approximately **3¾–4 hours**, depending on subsequent workload |

The unplug time comes from UPower's AC update timestamp and the first
discharging entry in its rate history. The charge history showed a steady
decline. Total runtime is a projection: the cycle had **not** completed when
recorded.

### Graphics power observation

The Quadro P620 was idle at **0% utilization**, in **P8**, with no active display
on it. Intel graphics was the default GPU. The NVIDIA driver reported runtime
D3 power management disabled, and the PCI device had no recorded runtime
suspend time during this boot.

This older Pascal GPU is outside the Turing-or-newer support requirement for
NVIDIA's runtime D3 feature. See the [NVIDIA driver documentation](https://download.nvidia.com/XFree86/Linux-x86_64/580.76.05/README/dynamicpowermanagement.html).
The GPU may contribute to baseline power consumption, but its individual draw
was unavailable, so no wattage saving was established. No GPU configuration was
changed.

## Recheck on Linux

These commands read the current state without changing settings:

```bash
upower -i /org/freedesktop/UPower/devices/battery_BAT0
upower -i /org/freedesktop/UPower/devices/line_power_AC

for field in manufacturer model_name energy_full_design energy_full \
  voltage_min_design cycle_count charge_control_start_threshold \
  charge_control_end_threshold; do
  printf '%s: ' "$field"
  cat "/sys/class/power_supply/BAT0/$field"
done

tuned-adm active
cat /sys/firmware/acpi/platform_profile
cat /sys/devices/system/cpu/intel_pstate/no_turbo
```

The sysfs energy values are in micro-watt-hours: divide by **1,000,000** for Wh.
Voltage is in microvolts: divide by **1,000,000** for V. For `no_turbo`, **0 means
turbo is enabled**.
