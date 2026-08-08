#  Single-Cycle RISC-V (RV32I) Processor in Verilog

A fully synthesizable, single-cycle 32-bit RISC-V core written in Verilog HDL. This processor implements a functional subset of the **RV32I Base Integer Instruction Set** along with hardware support for custom execution control (`HALT`).

---

##  Architecture Overview

The core employs a single-cycle unpipelined datapath with separated instruction and data memories (Harvard Architecture model). Control signals are generated combinationally based on opcode, `funct3`, and `funct7` instruction fields.
```text
+---------------------------------------------------------+
|                    RISC-V TOP LEVEL                     |
|                                                         |
|  +-------+     +-----------+     +-------------------+  |
|  |  PC   | --> |    IMEM   | --> | Decode & Register |  |
|  |       |     | (Inst Mem)|     |   File (x0-x31)   |  |
|  +-------+     +-----------+     +-------------------+  |
|      ^                                     |            |
|      |         +-------------+             v            |
|      +-------- | Branch/Jump | <---- +-----------+      |
|                |    Logic    |       | ALU Unit  |      |
|                +-------------+       +-----------+      |
|                                            |            |
|                +-------------+             v            |
|                |  Data Mem   | <-----------+            |
|                |   (DMEM)    |                          |
|                +-------------+                          |
+---------------------------------------------------------+
```


### Key Hardware Features
* **Registers:** 32 general-purpose 32-bit registers ($x0$ is hardwired to zero).
* **Reset Behavior:** Synchronous register file clearing and deterministic PC reset to `0x00000000`.
* **Execution Control:** Custom hardware `HALT` mechanism to freeze PC updates upon program completion.
* **Control Transfer:** Combinational branch ($PC + \text{offset}$) and jump target calculation.

---

##  Supported Instruction Set Architecture (ISA)

| Instruction Type | Instructions | Opcode (`inst[6:0]`) | Description |
| :--- | :--- | :--- | :--- |
| **R-Type** | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` | `0110011` | Register-Register ALU Operations |
| **I-Type** | `ADDI`, `LW` | `0010011`, `0000011` | Immediate Arithmetic & Load Word |
| **S-Type** | `SW` | `0100011` | Store Word to Memory |
| **B-Type** | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` | `1100011` | Conditional Branching |
| **J-Type** | `JAL` | `1101111` | Jump and Link |
| **Custom** | `HALT` | `1111111` | Custom Opcode (`0x0000007F`) to freeze PC |
