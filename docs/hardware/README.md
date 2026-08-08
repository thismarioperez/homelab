# Hardware

Physical devices in the lab.

## Firewall

|         |                               |
| ------- | ----------------------------- |
| Model   | N300 6-Port Network Appliance |
| CPU     | 8 cores                       |
| RAM     | 16 GB                         |
| Storage | 256 GB SSD                    |
| OS      | OPNsense 26.7                 |

## NAS

|         |                 |
| ------- | --------------- |
| Model   | Synology DS423+ |
| CPU     | 4 cores         |
| RAM     | 2 GB            |
| Storage | 4x 6 TB HDD     |
| OS      | Synology DSM 7  |

## Testlab host (ryujin)

|          |                                       |
| -------- | ------------------------------------- |
| Model    | Intel NUC6i5SYH                       |
| CPU      | 2 cores / 4 threads                   |
| Graphics | Integrated                            |
| RAM      | 32 GB                                 |
| Storage  | 256 GB SSD (boot), 1 TB SSD (storage) |
| OS       | Proxmox VE 9.2.4                      |

## Lab host (shenlong)

|          |                                       |
| -------- | ------------------------------------- |
| Model    | Beelink SER5 Pro 5600H                |
| CPU      | Ryzen 5 5600H (6 cores / 12 threads)  |
| Graphics | Integrated                            |
| RAM      | 32 GB DDR4                            |
| Storage  | 500 GB SSD (boot), 1 TB SSD (storage) |
| OS       | Proxmox VE 9.2.4                      |

## Lab host (tianlong)

|          |                                                     |
| -------- | --------------------------------------------------- |
| Model    | MINISFORUM MS-01 13900H                             |
| CPU      | Intel Core i9-13900H (14 cores: 8P/6E / 20 threads) |
| Graphics | Integrated                                          |
| RAM      | 32 GB DDR5                                          |
| Storage  | 500 GB SSD (boot), 1 TB SSD (storage)               |
| OS       | Proxmox VE 9.2.4                                    |

## Lab host (zhulong)

See [zhulong.md](zhulong.md) for the full build manifest
(motherboard, PSU, case, expansion cards, IOMMU/passthrough config).

|          |                                                               |
| -------- | ------------------------------------------------------------- |
| Model    | Custom PC/server                                              |
| CPU      | AMD Ryzen 7 5700G with Radeon Graphics (8 cores / 16 threads) |
| Graphics | Integrated / NVIDIA GeForce RTX 3070                          |
| RAM      | 64 GB DDR4                                                    |
| Storage  | 1 TB SSD (boot), 1 TB SSD (storage)                           |
| OS       | Proxmox VE 9.2.4                                              |
