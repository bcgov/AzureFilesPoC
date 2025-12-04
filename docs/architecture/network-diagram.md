# IP Address Range Diagram for VNet Spoke

## Flowchart Diagram
```mermaid
graph TD
    A[VNet: d5007d-dev-vwan-spoke<br/>Address Space: 10.46.73.0/24<br/>Total: 256 IPs] --> B[Subnet: snet-ag-pssg-azure-files-vm<br/>10.46.73.0 - 10.46.73.15<br/>16 IPs /28]
    A --> C[Subnet: AzureBastionSubnet<br/>10.46.73.16 - 10.46.73.79<br/>64 IPs /26]
    A --> D[Subnet: snet-ag-pssg-azure-files-pe<br/>10.46.73.80 - 10.46.73.111<br/>32 IPs /27]
    A --> E[Unused<br/>10.46.73.112 - 10.46.73.255<br/>144 IPs]
```

## Block Diagram (Hierarchical View)
This uses a Mermaid block diagram to show the VNet encompassing the subnets and unused space.

```mermaid
---
config:
  layout: elk
  look: classic
---
flowchart TB
  subgraph Subnets["Subnets"]
    direction LR
    VM("Subnet: snet-ag-pssg-azure-files-vm<br>**10.46.73.0/28**<br>16 IPs")
    Bastion("Subnet: AzureBastionSubnet<br>**10.46.73.64/26**<br>64 IPs")
    PE("Subnet: snet-ag-pssg-azure-files-pe<br>**10.46.73.128/27**<br>32 IPs")
    Unused("**Unused**<br>10.46.73.160 - 10.46.73.255<br>96 IPs")
  end
  
  subgraph VNet_Container["VNet: d5007d-dev-vwan-spoke<br>Address Space: 10.46.73.0/24<br>Total: 256 IPs"]
    direction LR
    Subnets
  end

  style VNet_Container fill:#f0f0ff,stroke:#666,stroke-width:2px,rx:10px
```