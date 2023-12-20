module reservation_station (
    input wire clk,
    input wire rst,
    input wire rdy,
    //Rob
    input wire new_ins_flag,
    input wire [31:0] new_ins,
    input wire [3:0] rename,
    input wire [4:0] rename_reg,
    //register
    input wire rename_finish_id,
    input wire operand_1_busy,
    input wire operand_2_busy,
    input wire [3:0] operand_1_rename,
    input wire [3:0] operand_2_rename,
    input wire [31:0] operand_1_data_from_reg,
    input wire [31:0] operand_2_data_from_reg,
    input wire rename_finish,
    output reg rename_need,
    output reg [3:0] rename_need_id,
    output reg operand_1_flag,
    output reg operand_2_flag,
    output reg [4:0] operand_1_reg,
    output reg [4:0] operand_2_reg,
    output reg [3:0] new_ins_rd_rename,
    output reg [4:0] new_ins_rd,
    //CDB
    input wire rs_update_flag,
    input wire [3:0] rs_commit_rename,
    input wire [31:0] rs_value,
    //ALUs
    input wire alu1_busy,
    output reg alu1_mission,  //是否向alu1传递新指令
    output reg [5:0] alu1_op_type,
    output reg [31:0] alu1_rs1,
    output reg [31:0] alu1_rs2,
    output reg [3:0] alu1_rob_dest,  //向rob中哪条指令更新value
    input wire alu2_busy,
    output reg alu2_mission,
    output reg [5:0] alu2_op_type,
    output reg [31:0] alu2_rs1,
    output reg [31:0] alu2_rs2,
    output reg [3:0] alu2_rob_dest
);
  parameter RSSIZE = 16;
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
  reg busy[RSSIZE-1:0];
  reg [5:0] op_type[RSSIZE-1:0];
  reg [31:0] operand_1[RSSIZE-1:0];
  reg [31:0] operand_2[RSSIZE-1:0];
  reg [3:0] operand_1_ins[RSSIZE-1:0];
  reg [3:0] operand_2_ins[RSSIZE-1:0];
  reg operand_1_rdy[RSSIZE-1:0];
  reg operand_2_rdy[RSSIZE-1:0];
  reg [3:0] rob_rnm[RSSIZE-1:0];  //记录的是来自Rob中哪条指令
  integer i, ready1_found, ready2_found, empty_ins, ready1, ready1_ins, ready2, ready2_ins;
  //特判:CDB广播的指令恰巧被查询register信息刚送回来的指令所需要
  always @(*) begin
    for (i = 0; i < RSSIZE; i = i + 1) begin
      ready1_found = 0;
      ready2_found = 0;
      if (!busy[i]) empty_ins = i;
      else if (operand_1_rdy[i] && operand_2_rdy[i]) begin
        if (!ready1_found) begin
          ready1_ins   = i;
          ready1_found = 1;
        end else if (!ready2_found) begin
          ready2_ins   = i;
          ready2_found = 1;
        end
      end
    end
  end
  always @(posedge clk) begin
    if (rename_finish) begin
      //上周期询问指令被送回来
      if (operand_1_busy) begin
        operand_1_ins[rename_finish_id] <= operand_1_rename;
      end else begin
        operand_1[rename_finish_id] <= operand_1_data_from_reg;
        operand_1_rdy[rename_finish_id] <= 1;
      end
      if (!operand_2_rdy[rename_finish_id]) begin
        if (operand_2_busy) begin
          operand_2_ins[rename_finish_id] <= operand_2_rename;
        end else begin
          operand_2[rename_finish_id] <= operand_2_data_from_reg;
          operand_2_rdy[rename_finish_id] <= 1;
        end
      end
    end
    if (new_ins_flag) begin
      busy[empty_ins] <= 1;
      rename_need <= 1;
      rename_need_id <= empty_ins;
      new_ins_rd_rename <= rename;
      new_ins_rd <= rename_reg;
      rob_rnm[empty_ins] <= rename;

      //下一步是分case对指令进行具体解析，更新其信息，并向register同时传达重命名信息和询问所需寄存器
      //LUI、JAL、AUIPC已处理完,Load/Store类指令不会被送到这里,只需处理剩下的
      case (new_ins[6:0])
        7'b1100111: begin
          //JALR
          op_type[empty_ins] <= JALR;
          operand_1_rdy[empty_ins] <= 0;
          operand_2_rdy[empty_ins] <= 1;
          operand_2[empty_ins] <= {{20{new_ins[31]}}, new_ins[31:20]};
          operand_1_flag <= 1;
          operand_2_flag <= 0;
          operand_1_reg <= new_ins[19:15];
        end
        7'b1100011: begin
          //Branch
          case (new_ins[14:12])
            3'b000: op_type[empty_ins] <= BEQ;
            3'b001: op_type[empty_ins] <= BNE;
            3'b100: op_type[empty_ins] <= BLT;
            3'b101: op_type[empty_ins] <= BGE;
            3'b110: op_type[empty_ins] <= BLTU;
            3'b111: op_type[empty_ins] <= BGEU;
          endcase
          operand_1_rdy[empty_ins] <= 0;
          operand_2_rdy[empty_ins] <= 0;
          operand_1_flag <= 1;
          operand_2_flag <= 1;
          operand_1_reg <= new_ins[19:15];
          operand_2_reg <= new_ins[24:20];
        end
        7'b0010011: begin
          //I
          case (new_ins[14:12])
            3'b000: op_type[empty_ins] <= ADDI;
            3'b010: op_type[empty_ins] <= SLTI;
            3'b011: op_type[empty_ins] <= SLTIU;
            3'b100: op_type[empty_ins] <= XORI;
            3'b110: op_type[empty_ins] <= ORI;
            3'b111: op_type[empty_ins] <= ANDI;
            3'b001: op_type[empty_ins] <= SLLI;
            3'b101: begin
              case (new_ins[31:25])
                7'b0000000: op_type[empty_ins] <= SRLI;
                7'b0100000: op_type[empty_ins] <= SRAI;
              endcase
            end
          endcase
          operand_1_rdy[empty_ins] <= 0;
          operand_2_rdy[empty_ins] <= 1;
          operand_1_flag <= 1;
          operand_2_flag <= 0;
          operand_1_reg <= new_ins[19:15];
          if (new_ins[14:12] == 3'b001 || new_ins[14:12] == 3'b101) begin
            operand_2[empty_ins] <= new_ins[24:20];
          end else begin
            operand_2[empty_ins] <= {{20{new_ins[31]}}, new_ins[31:20]};
          end
        end
        7'b0110011: begin
          //R
          case (new_ins[14:12])
            3'b000: begin
              case (new_ins[31:25])
                7'b0000000: op_type[empty_ins] <= ADD;
                7'b0100000: op_type[empty_ins] <= SUB;
              endcase
            end
            3'b001: op_type[empty_ins] <= SLL;
            3'b010: op_type[empty_ins] <= SLT;
            3'b011: op_type[empty_ins] <= SLTU;
            3'b100: op_type[empty_ins] <= XOR;
            3'b101: begin
              case (new_ins[31:25])
                7'b0000000: op_type[empty_ins] <= SRL;
                7'b0100000: op_type[empty_ins] <= SRA;
              endcase
            end
            3'b110: op_type[empty_ins] <= OR;
            3'b111: op_type[empty_ins] <= AND;
          endcase
          operand_1_rdy[empty_ins] <= 0;
          operand_2_rdy[empty_ins] <= 0;
          operand_1_flag <= 1;
          operand_2_flag <= 1;
          operand_1_reg <= new_ins[19:15];
          operand_2_reg <= new_ins[24:20];
        end
      endcase
    end else begin
      rename_need <= 0;
    end
    //之后是根据CDB广播完成更新
    if (rs_update_flag) begin
      for (i = 0; i < RSSIZE; i = i + 1) begin
        if (busy[i] && (!rename_finish || i != rename_finish_id)) begin
          if (!operand_1_rdy[i] && operand_1_ins[i] == rs_commit_rename) begin
            operand_1_rdy[i] <= 1;
            operand_1[i] <= rs_value;
          end
          if (!operand_2_rdy[i] && operand_2_ins[i] == rs_commit_rename) begin
            operand_2_rdy[i] <= 1;
            operand_2[i] <= rs_value;
          end
        end
      end
      if (rename_finish) begin
        if (operand_1_busy && operand_1_rename == rs_commit_rename) begin
          operand_1_rdy[rename_finish_id] <= 1;
          operand_1[rename_finish_id] <= rs_value;
        end
        if (operand_2_busy && operand_2_rename == rs_commit_rename) begin
          operand_2_rdy[rename_finish_id] <= 1;
          operand_2[rename_finish_id] <= rs_value;
        end
      end

    end
    //将可执行的语句送入ALU
    if (ready1_found) begin
      alu1_mission <= 1;
      alu1_op_type <= op_type[ready1_ins];
      alu1_rs1 <= operand_1[ready1_ins];
      alu1_rs2 <= operand_2[ready1_ins];
      alu1_rob_dest <= rob_rnm[ready1_ins];
      busy[ready1_ins] <= 0;
    end
    if (ready2_found) begin
      alu2_mission <= 1;
      alu2_op_type <= op_type[ready2_ins];
      alu2_rs1 <= operand_1[ready2_ins];
      alu2_rs2 <= operand_2[ready2_ins];
      alu2_rob_dest <= rob_rnm[ready2_ins];
      busy[ready2_ins] <= 0;
    end
  end

endmodule  //reservation_station
