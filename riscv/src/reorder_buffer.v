
module reorder_buffer (
    input wire clk,
    input wire rst,
    input wire rdy,
    //IF
    input wire if_ins_launch_flag,
    input wire [31:0] if_ins,
    input wire [31:0] if_ins_pc,
    output reg rob_full,
    //LSB 指令发射
    output reg new_ls_ins_flag,
    output reg [3:0] new_ls_ins_rnm,
    //LSB Load提交或STORE整理完
    input wire load_finish,
    input wire [3:0] load_finish_rename,
    input wire [31:0] ld_data,
    input wire store_finish,
    input wire [3:0] store_finish_rename,
    //RS
    output reg new_ins_flag,
    output reg [31:0] new_ins,
    output reg [3:0] rename,
    output reg [4:0] rename_reg,
    //reg
    input wire simple_ins_commit,
    input wire [3:0] simple_ins_commit_rename,
    //ALUs
    input wire alu1_finish,
    input wire [3:0] alu1_dest,
    input wire [31:0] alu1_out,
    input wire alu2_finish,
    input wire [3:0] alu2_dest,
    input wire [31:0] alu2_out,
    //predictor
    input wire rob_flush,
    //CDB
    output reg commit_flag,
    output reg [31:0] commit_value,
    output reg [3:0] commit_rename,
    output reg [4:0] commit_dest,
    output reg commit_is_jalr,
    output reg [31:0] jalr_next_pc,
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
  reg [3:0] head;
  reg [3:0] tail;
  reg [1:0] status[ROBSIZE-1:0];
  reg [4:0] destination[ROBSIZE-1:0];
  reg [31:0] value[ROBSIZE-1:0];
  reg is_branch[ROBSIZE-1:0];
  reg is_jalr[ROBSIZE-1:0];
  reg tail_less_than_head;
  integer ins_cnt;  //记录指令个数,判断空或满
  always @(*) begin
    if (!tail_less_than_head) ins_cnt = tail - head;
    else begin
      ins_cnt = tail + 16 - head;
    end
    if (ins_cnt == 16) rob_full = 1;
    else rob_full = 0;
  end
  always @(posedge clk) begin
    if (rst) begin
      head <= 0;
      tail <= 0;
      tail_less_than_head <= 0;
      new_ls_ins_flag <= 0;
      new_ins_flag <= 0;
      commit_flag <= 0;
    end else
    if (!rdy) begin

    end else begin
      if (rob_flush) begin
        head <= 0;
        tail <= 0;
        tail_less_than_head <= 0;
        new_ls_ins_flag <= 0;
        new_ins_flag <= 0;
        commit_flag <= 0;
      end else begin
        //已有指令状态通讯
        if (alu1_finish) begin
          status[alu1_dest] <= WRITE;
          value[alu1_dest]  <= alu1_out;
        end
        if (alu2_finish) begin
          status[alu2_dest] <= WRITE;
          value[alu2_dest]  <= alu2_out;
        end
        if (store_finish) begin
          status[store_finish_rename] <= WRITE;
          value[store_finish_rename]  <= 0;
        end
        if (load_finish) begin
          status[load_finish_rename] <= WRITE;
          value[load_finish_rename]  <= ld_data;
        end
        if(simple_ins_commit) begin
          status[simple_ins_commit_rename] <= WRITE;
        end
        //指令提交
        if (ins_cnt != 0 && status[head] == WRITE) begin
          head <= head + 1;
          if (head == ROBSIZE - 1) tail_less_than_head <= 0;
          commit_flag <= 1;
          commit_rename <= head;
          commit_value <= value[head];
          commit_dest <= destination[head];
          commit_is_branch <= is_branch[head];
          commit_is_jalr <= is_jalr[head];
        end else begin
          commit_flag <= 0;
        end
        //新指令的处理
        if (if_ins_launch_flag) begin
          destination[tail] <= if_ins[11:7];
          if (if_ins[6:0] == LUI || if_ins[6:0] == JAL || if_ins[6:0] == AUIPC) begin
            //LUI、JAL、AUIPC直接算出来
            case (if_ins[6:0])
              LUI: value[tail] <= if_ins[31:12] << 12;
              JAL: value[tail] <= if_ins_pc + 4;
              default: value[tail] <= if_ins[31:12] << 12 + if_ins_pc;
            endcase
          end
          //送入RS中
          if (if_ins[6:0] == BRANCH) is_branch[tail] <= 1;
          else is_branch[tail] <= 0;
          if (if_ins[6:0] == JALR) begin
            //所有元件中最多只存在一个jalr
            jalr_next_pc  <= if_ins_pc + 4;
            is_jalr[tail] <= 1;
          end else is_jalr[tail] <= 0;
          if (if_ins[6:0] == LOAD || if_ins[6:0] == STORE) begin
            //L或S要保顺序,因此在ISSUE时通知LSB
            new_ls_ins_flag <= 1;
            new_ls_ins_rnm  <= tail;
          end else new_ls_ins_flag <= 0;
          new_ins_flag <= 1;
          new_ins <= if_ins;
          rename_reg <= if_ins[11:7];
          rename <= tail;
          status[tail] <= ISSUE;
          tail <= tail + 1;
          if (tail == ROBSIZE - 1) tail_less_than_head <= 1;
        end else begin
          new_ins_flag <= 0;
          new_ls_ins_flag <= 0;
        end
      end
    end

  end

endmodule  //reorder_buffer
