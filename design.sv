// Code your design here
// instruction memory
module instruction_memory(input reset,
                          input [31:0]address,
                          output [31:0]instruction);

  reg [31:0]mem[1023:0];  //instruction memory
  assign instruction = reset ? 32'h0000000 : mem[address[31:2]];

endmodule

// data memory

module datamemory(input [31:0]address,
                  input [31:0]write_data,
                  input mem_read,clk,mem_write,
                  output [31:0]read_data);

  reg [31:0]memory[1023:0];  //data memory
  assign read_data = mem_read ? memory[address[31:2]] : 32'h0000000;

  always@(posedge clk)
    begin
      if(mem_write)
        memory[address[31:2]] <= write_data;
    end

endmodule

// program counter

module program_counter(input [31:0]pc_next,
                       input clk,reset,halt,
                       output reg [31:0]pc);

  always@(posedge clk)
    begin
      if(reset)
        pc <= 32'h0000000;
      else if(!halt)
        pc <= pc_next;
    end

endmodule

//pc adder

module pc_adder(input [31:0]pc_address,
                output [31:0]pc_plus_4);

  assign pc_plus_4 = pc_address + 32'd4;

endmodule



// register file

module register_file (
    input [4:0] register_read_1,
    input [4:0] register_read_2,
    input [4:0] write_register,
    input [31:0] write_data,
    input reg_write,
    input clk,
    input reset,
    output [31:0] read_data_1,
    output [31:0] read_data_2
);

    // Array of 32 registers, each 32 bits wide
    reg [31:0] registers [31:0];

    
    assign read_data_1 = reset ? 32'h00000000 :
                          (register_read_1 == 5'b00000) ? 32'h00000000 :
                          registers[register_read_1];
    assign read_data_2 = reset ? 32'h00000000 :
                          (register_read_2 == 5'b00000) ? 32'h00000000 :
                          registers[register_read_2];

    
    always @(posedge clk) begin
      if (reg_write && (write_register != 5'b0)) begin
            registers[write_register] <= write_data;
        end
    end

endmodule

// ALU

module alu_unit(input [31:0]A,
                input [31:0]B,
                input [3:0]ALU_operation,
                output reg zero,
                output reg LT,
                output reg LTU,
                output reg[31:0]result);

  always@(*)
    begin
     
      if(A-B==0)
        zero=1;
      else
        zero=0;
      if($signed(A)<$signed(B))
        LT=1;
      else
        LT=0;
      if(A < B)
        LTU=1;
      else
        LTU=0;

      case(ALU_operation)
        4'b0000 : result = A + B;// add
        4'b0001 : result = A - B;//sub
        4'b0010 : result = A << B[4:0];// SLL;
        4'b0011 : result =  ($signed(A) < $signed(B)) ? 32'b1 : 32'b0;//SLTS
        4'b0100 : result = (A < B) ? 32'b1 : 32'b0;// SLT
        4'b0101 : result = A ^ B;// xor
        4'b0110 : result = A >> B[4:0];// SRL
        4'b0111 : result = $signed(A) >>> B[4:0];// SRA
        4'b1000 : result = A | B; // or
        4'b1001 : result = A & B;//and
        default: begin
                result = 0; 
            end
      endcase

    end
endmodule



module sign_extension(
    input [31:0] instruction,
    output reg [31:0] output32
);

always @(*) begin
    case (instruction[6:0])
        // S-type (store)

        7'b0100011: begin
            output32 = {{20{instruction[31]}},
                         instruction[31:25],
                         instruction[11:7]};
        end


        // I-type (load, ALU immediates)

        7'b0000011,
        7'b0010011: begin
            output32 = {{20{instruction[31]}},
                         instruction[31:20]};
        end


        // B-type (branch)

        7'b1100011: begin
            output32 = {{19{instruction[31]}},
                         instruction[31],
                         instruction[7],
                         instruction[30:25],
                         instruction[11:8],
                         1'b0};
        end


        // J-type (JAL)

        7'b1101111: begin
            output32 = {{11{instruction[31]}},
                         instruction[31],
                         instruction[19:12],
                         instruction[20],
                         instruction[30:21],
                         1'b0};
        end

        default: begin
            output32 = 32'h00000000;
        end

    endcase
end

endmodule


// instruction fetch with control transfer datapath
module instruction_fetch_with_control_transfer(
    input clk,
    input reset,
    input branch,
    input halt,
    input jump,
    input flag,
    input [31:0] offset,

    output [31:0] instruction,
    output [31:0] PC_plus_4
);

    wire [31:0] PC_address;
    wire [31:0] Actual_PC_address;
    wire [31:0] BTA, JTA;
    wire branch_taken;

    // Program Counter
    program_counter PC (
        .pc_next(Actual_PC_address),
        .clk(clk),
      .halt(halt),
        .reset(reset),
        .pc(PC_address)
    );

    // PC + 4
    pc_adder ADD (
        .pc_address(PC_address),
        .pc_plus_4(PC_plus_4)
    );

    // Instruction Memory
    instruction_memory IMEM (
        .reset(reset),
        .address(PC_address),
        .instruction(instruction)
    );

    // Branch / Jump Targets (simplified: same offset)
    assign BTA = PC_address + offset;
    assign JTA = PC_address + offset;

    // RISC-V branch decision
    assign branch_taken = branch & flag;

    // Next PC logic (priority: jump > branch > pc+4)
    assign Actual_PC_address =
            jump         ? JTA :
            branch_taken ? BTA :
                           PC_plus_4;

endmodule


// single cycle datapath without control unit
module SCDP_without_control_unit(
  input clk, reset, RegWrite, ALUsrc, memRead, memWrite,halt,
  input MemToReg,branch, jump,
  input [3:0]ALUoperation,
  output func7,
  output [6:0]opcode,
  output [2:0]func
);

  reg flag;
  wire zero,LT,LTU;
  wire [31:0] instruction, read_data_1, read_data_2, ALU_operand2;
  wire [31:0] operand_32, Mem_or_ALU, AluData, MemData, PC_plus_4;

  // instantiate instruction fetch
  instruction_fetch_with_control_transfer IFCT(
    .reset(reset),
    .clk(clk),
    .halt(halt),
    .flag(flag),
    .branch(branch),
    .jump(jump),
    .offset(operand_32),
    .instruction(instruction),
    .PC_plus_4(PC_plus_4)
  );

  assign opcode = instruction[6:0];
  assign func = instruction[14:12];
  assign func7 = instruction[30];

  register_file RF(
    .register_read_1(instruction[19:15]),
    .register_read_2(instruction[24:20]),
    .write_register(instruction[11:7]),
    .write_data(Mem_or_ALU),
    .reg_write(RegWrite),
    .clk(clk),
    .reset(reset),
    .read_data_1(read_data_1),
    .read_data_2(read_data_2)
  );

  sign_extension SE(.instruction(instruction),
                    .output32(operand_32));

  assign ALU_operand2 = ALUsrc ? operand_32 : read_data_2;

  alu_unit AU(
    .A(read_data_1),
    .B(ALU_operand2),
    .ALU_operation(ALUoperation),
    .zero(zero),
    .LT(LT),
    .LTU(LTU),
    .result(AluData));


  always@(*)begin

        case(func)
      3'b000:begin
        if(zero)
          flag = 1;
        else
          flag = 0;
      end
      3'b001:begin
        if(!zero)
          flag = 1;
        else
          flag = 0;
      end
      3'b100:begin
        if(LT)
          flag = 1;
        else
          flag = 0;
      end
      3'b101:begin
        if(!LT)
          flag = 1;
        else
          flag = 0;
      end
      3'b110:begin
        if(LTU)
          flag = 1;
        else
          flag = 0;
      end
      3'b111:begin
        if(!LTU)
          flag = 1;
        else
          flag = 0;
      end
      default:flag = 0;
    endcase
  end



  datamemory DM(
    .address(AluData),
    .write_data(read_data_2),
    .mem_read(memRead),
    .clk(clk),
    .mem_write(memWrite),
    .read_data(MemData));

  assign Mem_or_ALU = jump?PC_plus_4:MemToReg? MemData : AluData;
endmodule


// module control unit
module control_unit_datapath(
     input [6:0] opcode,
     output reg RegWrite,
     output reg MemToReg,
     output reg ALUsrc,
     output reg branch,
     output reg jump,
     output reg memWrite,
     output reg memRead,
     output reg halt,
     output reg [1:0] ALUop
);

always @(*) begin

    // SAFE DEFAULTS
    RegWrite = 1'b0;
    MemToReg = 1'b0;
    ALUsrc   = 1'b0;
    branch   = 1'b0;
    jump     = 1'b0;
    memWrite = 1'b0;
    memRead  = 1'b0;
    ALUop    = 2'b00;
    halt     = 0;

    case(opcode)

        // ---------------- R-type ----------------
        7'b0110011: begin
            RegWrite = 1'b1;
            ALUsrc   = 1'b0;
            ALUop    = 2'b10;
        end

        // ---------------- I-type (ADDI etc.) ----------------
        7'b0010011: begin
            RegWrite = 1'b1;
            ALUsrc   = 1'b1;
            ALUop    = 2'b10;
        end

        // ---------------- LOAD (LW) ----------------
        7'b0000011: begin
            RegWrite = 1'b1;
            MemToReg = 1'b1;
            ALUsrc   = 1'b1;
            memRead  = 1'b1;
            ALUop    = 2'b00;
        end

        // ---------------- STORE (SW) ----------------
        7'b0100011: begin
            ALUsrc   = 1'b1;
            memWrite = 1'b1;
            ALUop    = 2'b00;
        end

        // ---------------- BRANCH (BEQ) ----------------
        7'b1100011: begin
            branch = 1'b1;
            ALUop  = 2'b01;
        end

        // ---------------- JAL ----------------
        7'b1101111: begin
            RegWrite = 1'b1;
            jump     = 1'b1;
        end
      7'b1111111 : halt = 1'b1;

    endcase
end

endmodule

module alu_control_datapath(
  input [1:0] ALUop,
  input [2:0] func3,
  input func7,
  input [6:0] opcode,          
  output reg [3:0] ALUoperation
);

  
  wire is_rtype = (opcode == 7'b0110011);

  always @(*) begin
    case(ALUop)
      
      2'b00 : ALUoperation = 4'b0000; // ADD (load/store address calc)
      2'b01 : ALUoperation = 4'b0001; // SUB (branch comparison, result unused)

      2'b10 : begin
        case(func3)
                    3'b000  : ALUoperation = (func7 && is_rtype) ? 4'b0001 : 4'b0000; // SUB : ADD
          3'b001  : ALUoperation = 4'b0010;                           // SLL
          3'b010  : ALUoperation = 4'b0011;                           // SLT
          3'b011  : ALUoperation = 4'b0100;                           // SLTU
          3'b100  : ALUoperation = 4'b0101;                           // XOR
          3'b101  : ALUoperation = (func7) ? 4'b0111 : 4'b0110;       // SRA 
          3'b110  : ALUoperation = 4'b1000;                           // OR
          3'b111  : ALUoperation = 4'b1001;                           // AND
          default : ALUoperation = 4'b1111;
        endcase
      end

      default : ALUoperation = 4'b1111;
    endcase
  end
endmodule

// RISC V DATAPATH
module risc_v_datapath(input clk,
                       input reset);
  wire RegWrite,ALUsrc,memRead,memWrite,MemToReg,branch,jump,func7,halt;
  wire [3:0]ALUoperation;
  wire [6:0]opcode;
  wire [2:0]func;
  wire [1:0]ALUop;

  // main control unit
  control_unit_datapath CUD(
    .opcode(opcode),
    .RegWrite(RegWrite),
    .halt(halt),
    .MemToReg(MemToReg),
    .ALUsrc(ALUsrc),
    .branch(branch),
    .jump(jump),
    .memWrite(memWrite),
    .memRead(memRead),
    .ALUop(ALUop)
  );

  // alu control datapath
  // FIX: now also passes opcode through, required by the updated
  // alu_control_datapath signature (see fix above).
  alu_control_datapath ACD(
    .ALUop(ALUop),
    .func3(func),
    .func7(func7),
    .opcode(opcode),           // FIX: new connection
    .ALUoperation(ALUoperation)
  );
    // single cycle datapath
  SCDP_without_control_unit SCDP(
    .clk(clk),
    .reset(reset),
    .halt(halt),
    .RegWrite(RegWrite),
    .ALUsrc(ALUsrc),
    .memRead(memRead),
    .memWrite(memWrite),
    .MemToReg(MemToReg),
    .branch(branch),
    .jump(jump),
    .func7(func7),
    .ALUoperation(ALUoperation),
    .opcode(opcode),
    .func(func)
  );

endmodule