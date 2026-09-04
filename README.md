# Dual-Core Cache-Coherent Memory Subsystem (RV32I)
This design consists of two single-core RV32I cores, sharing one memory bank and each with private L1 + L2 data caches kept coherent by an MSI snooping protocol over a 2-core bus. 

## Per-Core Cache Hierarchy 
* **L1:** 4 lines, direct-mapped
* **L2:** 16 sets, 1 way, checked on L1 Miss and Hit is promoted into L1
* **Miss in both:** word is fetched from shared memory and allocated into L2 and L1
* **Writes:** write-through and write-allocate, main memory is always updated

## MSI Cache Coherence
Each line caries one of the three states -- Invalid, Shared, Modified. Every controller drives bus_cmd/bus_addr and snoops the other core's data, filtered such that a core does not snoop itself. 
* **BUS_WR/BUS_UPDATE ->** invalidate matching local line in L1/L2, next miss reads fresh value from memory
* **BUS_RD ->** downgrade a local **MODIFIED** to **SHARED**

The cores are **stalled** on a cache miss, by a latch-based clock-gating cell and the controller triggers the **wait_req** signal. 
