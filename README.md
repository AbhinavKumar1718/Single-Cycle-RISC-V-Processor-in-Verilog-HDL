# Single-Cycle-RISC-V-Processor-in-Verilog-HDL
32-bit Single-Cycle RISC-V Processor (RV32I) implemented in Verilog HDL.
Single-Cycle RISC-V (RV32I) Processor — Verilog

A single-cycle RISC-V processor implementing a core subset of the RV32I integer instruction set, built from scratch in Verilog.

Overview

This project implements the classic single-cycle datapath — one instruction fetched, decoded, executed, and written back every clock cycle — as a set of modular Verilog blocks connected into a top-level datapath (risc_v_datapath).

Supported Instructions
R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
I-type (ALU immediate): ADDI, SLLI, SLTI, SLTIU, XORI, SRLI, SRAI, ORI, ANDI
Load: LW
Store: SW
Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
Jump: JAL
Custom halt instruction (opcode 1111111) to freeze the PC — not part of the RV32I spec, added for simulation/testbench control


