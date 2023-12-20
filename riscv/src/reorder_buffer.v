
module reorder_buffer (
    input wire clk,
    input wire rst,
    input wire rdy,
    //IF
    input wire if_ins_launch_flag,
    input wire [31:0] if_ins,
    input wire [31:0] if_ins_pc,
    output reg rob_full,
    //LSB
    output reg new_ls_ins_flag,
    output reg [31:0] new_ls_ins,
    output reg [3:0] ld_rename,
    output reg [4:0] ld_rename_reg,
    //LSB Load提交
    input wire ld_finish,
    input wire [3:0] ld_finish_rename,
    input wire [31:0] ld_data,
    //RS
    output reg new_ins_flag,
    output reg [31:0] new_ins,
    output reg [3:0] rename,
    output reg [4:0] rename_reg,
    //ALUs
    input wire alu1_finish,
    input wire [3:0] alu1_dest,
    input wire [31:0] alu1_out,
    input wire alu2_finish,
    input wire [3:0] alu2_dest,
    input wire [31:0] alu2_out,  
    //CDB
    output reg commit_flag,
    output reg [31:0] commit_value,
    output reg [3:0] commit_rename,
    output reg [4:0] commit_dest,
    output reg commit_is_jalr,
    output reg commit_is_branch
);
  parameter ROBSIZE = 16;
  parameter ISSUE = 2'b00;
  parameter EXEC = 2'b01;  //貌似不需要
  parameter WRITE = 2'b10;  //指令完成但尚未提交
  parameter COMMIT = 2'b11;
  parameter LOAD = 7'b0000011;
  parameter STORE = 7'b0100011;
  parameter LUI = 7'b0110111;
  parameter AUIPC = 7'b0010111;
  parameter JAL = 7'b1101111;
  parameter JALR = 7'b1100111;
  parameter BRANCH = 7'b1100011;
  reg [3:0] rob_id[ROBSIZE-1:0];
  reg [3:0] head = 1;
  reg [3:0] tail = 1;
  reg [1:0] state[ROBSIZE-1:0];
  reg [4:0] destination[ROBSIZE-1:0];
  reg [31:0] value[ROBSIZE-1:0];
  reg is_branch[ROBSIZE-1:0];
  reg is_jalr[ROBSIZE-1:0];
  integer ins_cnt = 0;  //记录指令个数,判断空或满
  integer before_ins_cnt = 0;
  always @(*) begin
    before_ins_cnt = ins_cnt;
    if(tail>head) ins_cnt = tail-head;
    else begin
      ins_cnt = tail+16-head;
    end
    if(ins_cnt == 16) begin
      if(before_ins_cnt>8) begin
        ins_cnt = 16;
      end else begin
        ins_cnt = 0;
      end
    end
    if(ins_cnt == 16) rob_full=1;
    else rob_full=0;
  end
  always @(posedge clk) begin
    //已有指令状态通讯
    if(alu1_finish) begin
      state[alu1_dest] <= WRITE;
      value[alu1_dest] <= alu1_out;
    end
    if(alu2_finish) begin
      state[alu2_dest] <= WRITE;
      value[alu2_dest] <= alu2_out;
    end
    if(ld_finish) begin
      state[ld_finish_rename] <= WRITE;
      value[ld_finish_rename] <= ld_data;
    end
    //指令提交
    if(state[head] == WRITE) begin
      head <= head+1;
      commit_flag <= 1;
      commit_rename <= head;
      commit_value <= value[head];
      commit_dest <= destination[head];
      commit_is_branch <= is_branch[head];
      commit_is_jalr <= is_jalr[head];
    end else if(state[head] == COMMIT) begin
      head <= head+1;
    end
    //新指令的处理
    if (if_ins_launch_flag) begin
      destination[tail] <= if_ins[11:7];
      if (if_ins[6:0] == LOAD || if_ins[6:0] == STORE) begin
        new_ls_ins_flag <= 1;
        new_ins_flag <= 0;
        if (if_ins[6:0] == LOAD) begin
          ld_rename_reg <= if_ins[11:7];
          ld_rename <= tail;
          state[tail] <= ISSUE;
        end else begin
          state[tail] <= COMMIT;
        end
        new_ls_ins  <= if_ins;

      end else if (if_ins[6:0] == LUI || if_ins[6:0] == JAL || if_ins[6:0] == AUIPC) begin
        //LUI、JAL、AUIPC直接算出来
        case (if_ins[6:0])
          LUI: value[tail] <= if_ins[31:12] << 12;
          JAL: value[tail] <= if_ins_pc + 4;
          default: value[tail] <= if_ins[31:12] << 12 + if_ins_pc;
        endcase
        state[tail] <= WRITE;
        new_ins_flag <= 0;
        new_ls_ins_flag <= 0;
      end else begin
        //剩下的送入RS中
        if (if_ins[6:0] == BRANCH) is_branch[tail] <= 1;
        else is_branch[tail] <= 0;
        if (if_ins[6:0] == JALR) is_jalr[tail] <= 1;
        else is_jalr[tail] <= 0;
        new_ins_flag <= 1;
        new_ins <= if_ins;
        new_ls_ins_flag <= 0;
        rename_reg <= if_ins[11:7];
        rename <= tail;
        state[tail] <= ISSUE;
      end
      tail <= tail + 1;
    end else begin
      new_ins_flag <= 0;
      new_ls_ins_flag <= 0;
    end
    //指令个数的计数

  end

endmodule  //reorder_buffer
