`define JAL 7'b1101111
`define JALR 7'b1100111
`define BRANCH 7'b1100011
module instruction_fetcher (
    input wire clk,
    input wire rst,
    input wire rdy,
    //IC
    input wire ic_rdy,
    input wire [31:0] ins,
    output reg ins_asked,
    output reg [31:0] ins_addr,
    //Predictor
    output reg ask_predictor,
    output reg [31:0] jump_addr,
    output reg [31:0] next_addr,
    output reg now_ins_jalr,
    input wire jump,
    input wire predictor_sgn_rdy,
    input wire predictor_occupied,  //上一个分支指令没提交则卡住 
    //Rob
    input wire rob_full,
    output reg if_ins_launch_flag,
    output reg [31:0] if_ins,
    output reg [31:0] if_ins_pc
);
//todo 改
//todo Jalr时停下
  reg [31:0] now_instruction;
  reg instruction_waiting_for_launch;
  reg [31:0] now_pc = 0;
  reg instruction_already_asked = 0;  //已经向IC要求指令了
  reg [31:0] now_instruction_pc;  //当前要发射指令的地址
  reg now_predict_rdy;
  reg waiting_for_predictor;
  always @(posedge clk) begin
    if_ins_launch_flag<=0;//否则一旦其变成true就改不回来了,只有发射的那一个周期有把它变成true的可能。
    if (!instruction_waiting_for_launch) begin
      if (ic_rdy) begin
        now_instruction <= ins;
        instruction_waiting_for_launch <= 1;
        instruction_already_asked <= 0;
        now_predict_rdy <= 0;
        waiting_for_predictor <= 0;
      end else begin
        if (!instruction_already_asked) begin
          ins_asked <= 1;
          ins_addr  <= now_pc;
        end else begin
          ins_asked <= 0;
        end
      end
    end else begin
      ins_asked <= 0;
    end
    if (instruction_waiting_for_launch) begin
      if (!now_predict_rdy && !waiting_for_predictor) begin
        case (now_instruction[6:0])
          `BRANCH: begin
            if (!predictor_occupied) begin
              now_predict_rdy <= 0;
              waiting_for_predictor <= 1;
              ask_predictor <= 1;
              now_ins_jalr <= 0;
              now_instruction_pc <= now_pc;
              jump_addr<=now_pc+{{20{now_instruction[31]}},now_instruction[7],now_instruction[30:25],now_instruction[11:8]}<<1;
              next_addr <= now_pc + 4;
            end else begin
              now_predict_rdy <= 0;
            end
          end
          `JAL: begin
            waiting_for_predictor <= 0;
            ask_predictor <= 0;
            now_ins_jalr <= 0;
            now_instruction_pc <= now_pc;
            now_pc<=now_pc+{{12{now_instruction[31]}},now_instruction[19:12],now_instruction[20],now_instruction[30:21]}<<1;
            now_predict_rdy <= 1;
          end
          `JALR: begin
            if (!predictor_occupied) begin
              waiting_for_predictor <= 0;
              ask_predictor <= 1;
              now_ins_jalr <= 1;
              now_instruction_pc <= now_pc;
              now_pc <= now_pc + 4;
              now_predict_rdy <= 1;
            end else begin
              now_predict_rdy <= 0;
            end
          end
          default: begin
            ask_predictor <= 0;
            now_instruction_pc <= now_pc;
            now_pc <= now_pc + 4;
            waiting_for_predictor <= 0;
            now_predict_rdy <= 1;
          end
        endcase
      end
      if (predictor_sgn_rdy) begin
        //只有当前为Branch指令时才会进这里
        if (jump)
          now_pc <= now_pc+{{20{now_instruction[31]}},now_instruction[7],now_instruction[30:25],now_instruction[11:8]}<<1;
        else now_pc <= now_pc + 4;
        waiting_for_predictor <= 0;
        now_predict_rdy <= 1;
      end
      if (now_predict_rdy) begin
        //发射指令和指令地址到rob中,需判断rob是否已满,否则一直尝试
        if (!rob_full) begin
          //发射指令
          instruction_waiting_for_launch <= 0;
          if_ins_launch_flag <= 1;
          if_ins <= now_instruction;
          if_ins_pc <= now_instruction_pc;
          now_predict_rdy <= 0;
        end

      end
    end
  end

endmodule  //instruction_fetcher
