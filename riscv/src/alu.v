module alu (
    input wire clk,
    input wire rst,
    input wire rdy,
    //rs
    input wire alu_mission,
    input wire [5:0] alu_op_type,
    input wire [31:0] alu_rs1,
    input wire [31:0] alu_rs2,
    input wire [3:0] alu_rob_dest,
    //rob
    output reg alu_finish,
    output reg [3:0] dest,
    output reg [31:0] alu_out
);
  //没有需要多个周期的指令,因此不用busy
  parameter LUI = 1;
  parameter AUIPC = 2;
  parameter JAL = 3;
  parameter JALR = 4;
  parameter BEQ = 5;
  parameter BNE = 6;
  parameter BLT = 7;
  parameter BGE = 8;
  parameter BLTU = 9;
  parameter BGEU = 10;
  parameter LB = 11;
  parameter LH = 12;
  parameter LW = 13;
  parameter LBU = 14;
  parameter LHU = 15;
  parameter SB = 16;
  parameter SH = 17;
  parameter SW = 18;
  parameter ADDI = 19;
  parameter SLTI = 20;
  parameter SLTIU = 21;
  parameter XORI = 22;
  parameter ORI = 23;
  parameter ANDI = 24;
  parameter SLLI = 25;
  parameter SRLI = 26;
  parameter SRAI = 27;
  parameter ADD = 28;
  parameter SUB = 29;
  parameter SLL = 30;
  parameter SLT = 31;
  parameter SLTU = 32;
  parameter XOR = 33;
  parameter SRL = 34;
  parameter SRA = 35;
  parameter OR = 36;
  parameter AND = 37;
  always @(*) begin
    dest = 0;
    alu_out = 0;
    if (alu_mission) begin
      case (alu_op_type)
        JALR: alu_out = ((alu_rs1 + alu_rs2) & 32'hFFFFFFFE);
        BEQ: alu_out = alu_rs1 == alu_rs2;
        BNE: alu_out = alu_rs1 != alu_rs2;
        BLT: alu_out = $signed(alu_rs1) < $signed(alu_rs2);
        BGE: alu_out = $signed(alu_rs1) >= $signed(alu_rs2);
        BLTU: alu_out = alu_rs1 < alu_rs2;
        BGEU: alu_out = alu_rs1 >= alu_rs2;
        ADDI: alu_out = alu_rs1 + alu_rs2;
        SLTI: alu_out = $signed(alu_rs1) < $signed(alu_rs2);
        SLTIU: alu_out = alu_rs1 < alu_rs2;
        XORI: alu_out = alu_rs1 ^ alu_rs2;
        ORI: alu_out = alu_rs1 | alu_rs2;
        ANDI: alu_out = alu_rs1 & alu_rs2;
        SLLI: alu_out = alu_rs1 << alu_rs2[4:0];
        SRLI: alu_out = alu_rs1 >> alu_rs2[4:0];
        SRAI: alu_out = $signed(alu_rs1) >>> alu_rs2[4:0];
        ADD: alu_out = alu_rs1 + alu_rs2;
        SUB: alu_out = alu_rs1 - alu_rs2;
        SLL: alu_out = alu_rs1 << alu_rs2[4:0];
        SLT: alu_out = $signed(alu_rs1) < $signed(alu_rs2);
        SLTU: alu_out = alu_rs1 < alu_rs2;
        XOR: alu_out = alu_rs1 ^ alu_rs2;
        SRL: alu_out = alu_rs1 >> alu_rs2[4:0];
        SRA: alu_out = $signed(alu_rs1) >>> alu_rs2[4:0];
        OR: alu_out = alu_rs1 | alu_rs2;
        AND: alu_out = alu_rs1 & alu_rs2;
      endcase
      alu_finish = 1;
      dest = alu_rob_dest;
    end else begin
      alu_finish = 0;
    end
  end
endmodule  //alu
