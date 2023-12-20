module register (
    input wire clk,
    input wire rst,
    input wire rdy,
    //cdb
    input wire register_update_flag,
    input wire [4:0] register_commit_dest,
    input wire [31:0] register_commit_value,
    input wire [3:0] rename_of_commit_ins,
    //LSB
    output reg [3:0] ls_rename_finish_id,
    output reg ls_rs1_busy,
    output reg store_rs2_busy,
    output reg [3:0] ls_rs1_rename,
    output reg [3:0] store_rs2_rename,
    output reg [31:0] ls_rs1_data_from_reg,
    output reg [31:0] store_rs2_data_from_reg,
    output reg ls_rename_finish,
    input wire ls_rename_need,
    input wire [3:0] ls_rename_need_id,
    input wire load_not_store,
    input wire [4:0] rs1_reg,
    input wire [4:0] rs2_or_rd_reg,
    input wire [3:0] load_rd_rename,
    //rs
    output reg rename_finish_id,
    output reg operand_1_busy,
    output reg operand_2_busy,
    output reg [3:0] operand_1_rename,
    output reg [3:0] operand_2_rename,
    output reg [31:0] operand_1_data_from_reg,
    output reg [31:0] operand_2_data_from_reg,
    output reg rename_finish,
    input wire rename_need,
    input wire [3:0] rename_need_id,
    input wire operand_1_flag,
    input wire operand_2_flag,
    input wire [4:0] operand_1_reg,
    input wire [4:0] operand_2_reg,
    input wire [3:0] new_ins_rd_rename,
    input wire [4:0] new_ins_rd
);
  //特判:询问的寄存器本周期恰好被CDB广播
  reg [31:0] reg_value[31:0];
  reg reg_busy[31:0];
  reg [3:0] reg_rename[31:0];
  always @(posedge clk) begin
    if (register_update_flag) begin
      if (rename_of_commit_ins == reg_rename[register_commit_dest])
        reg_busy[register_commit_dest] <= 0;
      reg_value[register_commit_dest] <= register_commit_value;
    end
    if (rename_need) begin
      rename_finish <= 1;
      if (!register_update_flag) begin
        if (operand_1_flag) begin
          if (reg_busy[operand_1_reg]) begin
            operand_1_busy   <= 1;
            operand_1_rename <= reg_rename[operand_1_reg];
            if(register_update_flag && operand_1_reg == register_commit_dest && rename_of_commit_ins == reg_rename[register_commit_dest]) begin
              operand_1_busy <= 0;
              operand_1_data_from_reg <= register_commit_value;
            end
          end else begin
            operand_1_busy <= 0;
            operand_1_data_from_reg <= reg_value[operand_1_reg];
          end
        end
        if (operand_2_flag) begin
          if (reg_busy[operand_2_reg]) begin
            operand_2_busy   <= 1;
            operand_2_rename <= reg_rename[operand_2_reg];
            if(register_update_flag && operand_2_reg == register_commit_dest && rename_of_commit_ins == reg_rename[register_commit_dest]) begin
              operand_2_busy <= 0;
              operand_2_data_from_reg <= register_commit_value;
            end
          end else begin
            operand_2_busy <= 0;
            operand_2_data_from_reg <= reg_value[operand_2_reg];
          end
        end
      end
      reg_busy[new_ins_rd] <= 1;
      reg_rename [new_ins_rd] <= new_ins_rd_rename;//理论上来讲后赋值会覆盖先赋值,如果出问题可改成特判
      rename_finish_id <= rename_need_id;
    end else begin
      rename_finish <= 0;
    end
    if (ls_rename_need) begin
      ls_rename_finish <= 1;
      if (reg_busy[rs1_reg]) begin
        ls_rs1_busy   <= 1;
        ls_rs1_rename <= reg_rename[rs1_reg];
        if(register_update_flag && rs1_reg == register_commit_dest && rename_of_commit_ins == reg_rename[rs1_reg]) begin
          ls_rs1_busy <= 0;
          ls_rs1_data_from_reg <= register_commit_value;
        end
      end else begin
        ls_rs1_busy <= 0;
        ls_rs1_data_from_reg <= reg_value[rs1_reg];
      end
      if (load_not_store) begin
        reg_busy[rs2_or_rd_reg]   <= 1;
        reg_rename[rs2_or_rd_reg] <= load_rd_rename;
        store_rs2_busy <= 0;
      end else begin
        if (reg_busy[rs2_or_rd_reg]) begin
          store_rs2_busy   <= 1;
          store_rs2_rename <= reg_rename[rs2_or_rd_reg];
          if(register_update_flag && rs2_or_rd_reg == register_commit_dest && rename_of_commit_ins == reg_rename[rs2_or_rd_reg]) begin
            store_rs2_busy <= 0;
            store_rs2_data_from_reg <= register_commit_value;
          end
        end else begin
          store_rs2_busy <= 0;
          store_rs2_data_from_reg <= reg_value[rs1_reg];
        end
      end
      ls_rename_finish_id <= ls_rename_need_id;
    end
  end

endmodule  //register

