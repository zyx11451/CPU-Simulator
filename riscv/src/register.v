module register (
    input wire clk,
    input wire rst,
    input wire rdy,
    //cdb
    input wire register_update_flag,
    input wire [4:0] register_commit_dest,
    input wire [31:0] register_commit_value,
    input wire [3:0] rename_of_commit_ins,
    //predictor
    input wire register_flush,
    //rob
    output reg simple_ins_commit,
    output reg [3:0] simple_ins_rename,
    //rs
    output reg [3:0] rename_finish_id,
    output reg operand_1_busy,
    output reg operand_2_busy,
    output reg [3:0] operand_1_rename,
    output reg [3:0] operand_2_rename,
    output reg [31:0] operand_1_data_from_reg,
    output reg [31:0] operand_2_data_from_reg,
    output reg rename_finish,
    input wire rename_need,
    input wire rename_need_ins_is_simple,
    input wire rename_need_ins_is_branch_or_store,
    input wire [3:0] rename_need_id,
    input wire operand_1_flag,
    input wire operand_2_flag,
    input wire [4:0] operand_1_reg,
    input wire [4:0] operand_2_reg,
    input wire [3:0] new_ins_rd_rename,
    input wire [4:0] new_ins_rd
);
  //特判:询问的寄存器本周期恰好被CDB广播
  //0号寄存器不可更改
  reg [31:0] reg_value[31:0];
  reg reg_busy[31:0];
  reg [3:0] reg_rename[31:0];
  reg [3:0] debug;
  reg [31:0] debug1;
  reg [31:0] debug2;
  reg [31:0] a0;
  reg [31:0] a1;
  reg [31:0] a2;
  reg [31:0] a3;
  reg [31:0] a4;
  reg [31:0] a5;
  reg [31:0] s0;
  reg [31:0] s1;
  reg [31:0] s2;
  reg [31:0] s3;
  reg [31:0] s4;
  reg [31:0] sp;
  reg debug3;
  integer i;
  always @(posedge clk) begin
    debug <= reg_rename[13];
    debug1 <= reg_value[13];
    debug2 <= reg_value[0];
    debug3 <= reg_busy[9];
    a0 <= reg_value[10];
    a1 <= reg_value[11];
    a2 <= reg_value[12];
    a3 <= reg_value[13];
    a4 <= reg_value[14];
    a5 <= reg_value[15];
    s0 <= reg_value[8];
    s1 <= reg_value[9];
    sp <= reg_value[2];
    if (rst) begin
      rename_finish <= 0;
      simple_ins_commit <= 0;
      for (i = 0; i < 32; i=i+1) begin
        reg_busy[i]  <= 0;
        reg_value[i] <= 0;
      end
    end else
    if (!rdy) begin

    end else begin
      if (register_flush) begin
        rename_finish <= 0;
        for (i = 0; i < 32; i=i+1) begin
          reg_busy[i] <= 0;
        end
      end else begin
        if (register_update_flag) begin
          if (rename_of_commit_ins == reg_rename[register_commit_dest])
            reg_busy[register_commit_dest] <= 0;
          if (register_commit_dest != 0) reg_value[register_commit_dest] <= register_commit_value;
          else reg_value[0] <= 0;
        end
        if (rename_need) begin
          if (rename_need_ins_is_simple) begin
            rename_finish <= 0;
            simple_ins_commit <= 1;
            simple_ins_rename <= new_ins_rd_rename;
            reg_busy[new_ins_rd] <= 1;
            reg_rename[new_ins_rd] <= new_ins_rd_rename;
          end else begin
            simple_ins_commit <= 0;
            rename_finish <= 1;
            if (operand_1_flag) begin
              if (reg_busy[operand_1_reg]) begin
                if(register_update_flag && operand_1_reg == register_commit_dest && rename_of_commit_ins == reg_rename[register_commit_dest]) begin
                  operand_1_busy <= 0;
                  operand_1_data_from_reg <= register_commit_value;
                end else begin
                  operand_1_busy   <= 1;
                  operand_1_rename <= reg_rename[operand_1_reg];
                end
              end else begin
                operand_1_busy <= 0;
                operand_1_data_from_reg <= reg_value[operand_1_reg];
              end
            end
            if (operand_2_flag) begin
              if (reg_busy[operand_2_reg]) begin

                if(register_update_flag && operand_2_reg == register_commit_dest && rename_of_commit_ins == reg_rename[register_commit_dest]) begin
                  operand_2_busy <= 0;
                  operand_2_data_from_reg <= register_commit_value;
                end else begin
                  operand_2_busy   <= 1;
                  operand_2_rename <= reg_rename[operand_2_reg];
                end
              end else begin
                operand_2_busy <= 0;
                operand_2_data_from_reg <= reg_value[operand_2_reg];
              end
            end
            if (!rename_need_ins_is_branch_or_store) begin
              //分支指令那个位置不是rd,不需要重命名
              reg_busy[new_ins_rd] <= 1;
              reg_rename [new_ins_rd] <= new_ins_rd_rename;//理论上来讲后赋�?�会覆盖先赋�?,如果出问题可改成特判
            end
            rename_finish_id <= rename_need_id;
          end
        end else begin
          rename_finish <= 0;
          simple_ins_commit <= 0;
        end
      end

    end

  end

endmodule  //register

