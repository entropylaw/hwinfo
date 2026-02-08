# hwinfo

A single-file bash script that displays a colorful, box-drawn summary of your Linux system hardware.

## Example Output

```
  ╔══════════════════════════════════════════════════════╗
  ║                 SYSTEM HARDWARE INFO                 ║
  ║       bsd-home / Linux 6.18.8-200.fc43.x86_64       ║
  ╚══════════════════════════════════════════════════════╝

  ┌─── CPU ──────────────────────────────────────────────┐
  │  Model:        AMD Ryzen 9 9950X3D 16-Core Processor │
  │  Cores:        16                                    │
  │  Threads:      32                                    │
  │  Max Clock:    5756 MHz                              │
  │  L3 Cache:     128 MiB (2 instances)                 │
  └──────────────────────────────────────────────────────┘

  ┌─── Memory ───────────────────────────────────────────┐
  │  Total:        60Gi                                  │
  │  Available:    49Gi                                  │
  │  Swap:         8.0Gi                                 │
  └──────────────────────────────────────────────────────┘

  ┌─── Storage ──────────────────────────────────────────┐
  │  nvme1n1      3.6T   NVMe SSD                       │
  │               Samsung SSD 990 PRO with Heatsink 4TB  │
  │  nvme0n1      3.6T   NVMe SSD                       │
  │               Samsung SSD 990 PRO with Heatsink 4TB  │
  └──────────────────────────────────────────────────────┘

  ┌─── Motherboard ──────────────────────────────────────┐
  │  Vendor:       ASUSTeK COMPUTER INC.                 │
  │  Model:        ROG STRIX X870E-E GAMING WIFI         │
  │  BIOS:         American Megatrends Inc. v1512        │
  └──────────────────────────────────────────────────────┘

  ┌─── GPU ──────────────────────────────────────────────┐
  │  AD102 [GeForce RTX 4090] (rev a1)                   │
  │  Granite Ridge [Radeon Graphics] (rev c9)            │
  └──────────────────────────────────────────────────────┘

  ┌─── Network ──────────────────────────────────────────┐
  │  enp10s0        UP    5 Gb/s   60:cf:84:60:a8:48    │
  │  virbr0         DOWN  --       52:54:00:80:fa:b9    │
  └──────────────────────────────────────────────────────┘
```

## Install

```bash
curl -LO https://raw.githubusercontent.com/entropylaw/hwinfo/main/hwinfo.sh
chmod +x hwinfo.sh
```

Or clone the repo:

```bash
git clone https://github.com/entropylaw/hwinfo.git
cd hwinfo
./hwinfo.sh
```

## Sections

| Section | Data Sources |
|---|---|
| **CPU** | `lscpu`, `/proc/cpuinfo` |
| **Memory** | `free`, `/proc/meminfo` |
| **Storage** | `lsblk` — classifies NVMe SSD / SATA SSD / HDD |
| **Motherboard** | `/sys/class/dmi/id/`, `dmidecode` |
| **GPU** | `lspci` |
| **Network** | `/sys/class/net/` sysfs |

Each section has fallback paths if the primary tool is unavailable.

## Color Control

Colors are automatically disabled when output is piped. You can also force plain output:

```bash
NO_COLOR=1 ./hwinfo.sh
```

## Requirements

- Bash 4+
- Linux (reads from `/proc`, `/sys`, and standard Linux utilities)
- No root required (falls back gracefully where needed)

## License

MIT
