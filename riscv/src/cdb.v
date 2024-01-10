module cdb (
    input wire clk,
    input wire rst,
    input wire rdy,
    //rob
    input wire commit_flag,
    input wire [31:0] commit_value,
    input wire [3:0] commit_rename,
    input wire [4:0] commit_dest,
    input wire commit_is_jalr,
    input wire [31:0] jalr_next_pc,
    input wire commit_is_branch,
    input wire commit_is_store,
    //rs
    output reg rs_update_flag,
    output reg [3:0] rs_commit_rename,
    output reg [31:0] rs_value,
    //register
    output reg register_update_flag,
    output reg [4:0] register_commit_dest,
    output reg [31:0] register_value,
    output reg [3:0] rename_sent_to_register,
    //predictor
    input wire cdb_flush,
    output reg branch_commit,
    output reg branch_jump,
    //IF
    output reg jalr_commit,
    output reg [31:0] jalr_addr,
    //LSB
    output reg lsb_update_flag,
    output reg [3:0] lsb_commit_rename
);

  always @(*) begin
    if (cdb_flush) begin
      rs_update_flag = 0;
      register_update_flag = 0;
      branch_commit = 0;
      jalr_commit = 0;
      lsb_update_flag = 0;
    end else begin
      if (commit_flag) begin
        if (!commit_is_branch && !commit_is_jalr) begin
          if (!commit_is_store) begin
            rs_update_flag = 1;
            rs_commit_rename = commit_rename;
            rs_value = commit_value;
            register_update_flag = 1;
            register_commit_dest = commit_dest;
            register_value = commit_value;
            rename_sent_to_register = commit_rename;
          end
          branch_commit = 0;
          jalr_commit = 0;
          lsb_update_flag = 1;
          lsb_commit_rename = commit_rename;
        end else begin
          if (commit_is_branch) begin
            branch_commit = 1;
            branch_jump = commit_value[0];
            rs_update_flag = 0;
            register_update_flag = 0;
            lsb_update_flag = 0;
          end else begin
            jalr_commit = 1;
            jalr_addr = commit_value;
            rs_update_flag = 0;
            register_update_flag = 1;
            register_commit_dest = commit_dest;
            register_value = jalr_next_pc;
            rename_sent_to_register = commit_rename;
            lsb_update_flag = 0;
          end
        end
      end else begin
        rs_update_flag = 0;
        register_update_flag = 0;
        lsb_update_flag = 0;
        branch_commit = 0;
        jalr_commit = 0;
      end
    end

  end

endmodule  //cdb
