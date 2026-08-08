# zhulong

Fine-grained build manifest for the `zhulong` Lab host. See
[README.md](README.md) for the summary entry.

## Motherboard

Gigabyte B550I AORUS PRO AX Mini ITX AM4

## Power supply

Corsair SF850L 850 W 80+ Gold Certified Fully Modular SFX

## Case

Cooler Master MasterBox NR200 Mini ITX Desktop Case

## Expansion cards

| Slot | Card                                           |
| ---- | ---------------------------------------------- |
| PCIe | Asus ROG STRIX GAMING OC GeForce RTX 3070 8 GB |

## Storage

| Device | Model                                              | Role    |
| ------ | -------------------------------------------------- | ------- |
| nvme0  | TEAMGROUP MP34 1 TB M.2-2280 PCIe 3.0 X4 NVMe SSD  | Boot    |
| nvme1  | PNY XLR8 CS3030 1 TB M.2-2280 PCIe 3.0 X4 NVMe SSD | Storage |

## Memory

Mushkin Enhanced Redline Stiletto 64 GB (2 x 32 GB) DDR4-3600 CL18

## BIOS / firmware

IOMMU enabled for GPU passthrough. Kernel params:

```
amd_iommu=on iommu.passthrough=1
```

Verification:

```
root@zhulong:~# dmesg | grep -e DMAR -e IOMMU -e AMD-Vi
[    0.169380] AMD-Vi: Using global IVHD EFR:0x206d73ef22254ade, EFR2:0x0
[    0.455491] pci 0000:00:00.2: AMD-Vi: IOMMU performance counters supported
[    0.457990] AMD-Vi: Extended features (0x206d73ef22254ade, 0x0): PPR X2APIC NX GT IA GA PC GA_vAPIC
[    0.458001] AMD-Vi: Interrupt remapping enabled
[    0.458002] AMD-Vi: X2APIC enabled
[    0.504614] AMD-Vi: Virtual APIC enabled
[    0.507556] perf/amd_iommu: Detected AMD IOMMU #0 (2 banks, 4 counters/bank).
```
