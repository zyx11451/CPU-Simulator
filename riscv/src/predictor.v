module predictor (
    input wire clk,
    input wire rst,
    input wire rdy,
    //IF
    input wire ask_predictor,
    input wire [31:0] jump_addr_from_if,
    input wire [31:0] next_addr_from_if,
    input wire now_ins_jalr,
    output reg jump,
    output reg predictor_sgn_rdy,
    output reg predictor_occupied,
    output reg if_flush,
    output reg [31:0] addr_to_if,
    //CDB
    input wire branch_commit,
    input wire branch_jump,
    input wire jalr_commit,
    input wire [31:0] jalr_addr
);
  //最简单的二位分支预测器
  //todo 其它元件的flush指令
  reg [31:0] next_addr;
  reg [31:0] jump_addr;
  reg predict_jump;
  reg [1:0] jump_judge;
  reg ins_is_jalr;
  always @(*) begin
    if (ask_predictor) begin
      predictor_occupied = 1;
      next_addr = next_addr_from_if;
      jump_addr = jump_addr_from_if;
      ins_is_jalr = now_ins_jalr;
      if (ins_is_jalr) begin
        predict_jump = 0;
        predictor_sgn_rdy = 1;
        jump = 0;
      end else begin
        if (jump_judge < 2) begin
          predict_jump = 0;
          predictor_sgn_rdy = 1;
          jump = 0;
        end else begin
          predict_jump = 1;
          predictor_sgn_rdy = 1;
          jump = 1;
        end
      end
    end
    if (branch_commit) begin
        if(branch_jump == predict_jump) predictor_occupied = 0;
        else begin
            if_flush = 1;
            if(branch_jump) begin
                if(jump_judge < 3) jump_judge = jump_judge + 1;
                addr_to_if = jump_addr;
            end else begin
                if(jump_judge > 0) jump_judge = jump_judge - 1;
                addr_to_if = next_addr;
            end
        end
        predictor_occupied = 0;
    end
    if (jalr_commit) begin
        if_flush = 1;
        addr_to_if = jalr_addr;
    end
  end
endmodule  //predictor
