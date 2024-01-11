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
    output reg [31:0] ask_ins_addr,
    output reg [31:0] jump_addr,
    output reg [31:0] next_addr,
    input wire jump,
    input wire predictor_sgn_rdy,
    input wire predictor_full,  //已经有四个分支指令没提交则卡住 
    input wire if_flush,
    input wire [31:0] addr_from_predictor,
    //CDB
    input wire jalr_commit,
    input wire [31:0] jalr_addr,
    //LSB
    input wire lsb_full,
    //Rob
    input wire rob_full,
    output reg if_ins_launch_flag,
    output reg [31:0] if_ins,
    output reg [31:0] if_ins_pc
);
  //Jalr时停下
  parameter EMPTY = 0;
  parameter WAITING_FOR_INS = 1;  //已经向IC要求指令了
  parameter NEED_PREDICT = 2;  //等待分支预测器进行预测
  parameter WAITING_FOR_PREDICTOR = 3;
  parameter READY_FOR_LAUNCH = 4;
  parameter JALR_READY_FOR_LAUNCH = 5;
  parameter FREEZE_JALR = 6;
  parameter WAITING_INS_AFTER_FLUSH=7;//已经问的错误指令没用了,不过要等它传回来再问正确的指令
  reg [ 2:0] status;
  reg [31:0] now_instruction;
  reg [31:0] now_pc ;
  reg [31:0] now_instruction_pc;  //当前要发射指令的地址
  always @(posedge clk) begin
    if (rst) begin
      ins_asked <= 0;
      ask_predictor <= 0;
      if_ins_launch_flag <= 0;
      status <= EMPTY;
      now_pc <= 0;
    end else if (!rdy) begin

    end else begin
      if (if_flush) begin
        ins_asked <= 0;
        ask_predictor <= 0;
        if_ins_launch_flag <= 0;
        case (status)
          WAITING_FOR_INS: begin
            now_pc <= addr_from_predictor;
            if(!ic_rdy) status <= WAITING_INS_AFTER_FLUSH;
            else status <= EMPTY;
          end
          default: begin
            now_pc <= addr_from_predictor;
            status <= EMPTY;
          end
        endcase
      end else begin
        case (status)
          EMPTY: begin
            ins_asked <= 1;
            ask_predictor <= 0;
            if_ins_launch_flag <= 0;
            ins_addr <= now_pc;
            status <= WAITING_FOR_INS;
          end
          WAITING_FOR_INS: begin
            ins_asked <= 0;
            ask_predictor <= 0;
            if_ins_launch_flag <= 0;
            if (ic_rdy) begin
              now_instruction <= ins;
              now_instruction_pc <= now_pc;
              case (ins[6:0])
                `BRANCH: begin
                  status <= NEED_PREDICT;
                end
                `JAL: begin
                  status <= READY_FOR_LAUNCH;
                  now_pc<= now_pc+ ({{12{ins[31]}},ins[19:12],ins[20],ins[30:21]}<<1);//此时now_instruction还没更新
                end
                `JALR: begin
                  status <= JALR_READY_FOR_LAUNCH;
                end
                default: begin
                  status <= READY_FOR_LAUNCH;
                  now_pc <= now_pc + 4;
                end
              endcase
            end
          end
          NEED_PREDICT: begin
            ins_asked <= 0;
            if_ins_launch_flag <= 0;
            if (!predictor_full) begin
              status <= WAITING_FOR_PREDICTOR;
              ask_predictor <= 1;
              ask_ins_addr <= now_pc;
              jump_addr <= now_pc+({{20{now_instruction[31]}},now_instruction[7],now_instruction[30:25],now_instruction[11:8]}<<1);
              next_addr <= now_pc + 4;
            end else begin
              ask_predictor <= 0;
            end
          end
          WAITING_FOR_PREDICTOR: begin
            ins_asked <= 0;
            ask_predictor <= 0;
            if_ins_launch_flag <= 0;
            if (predictor_sgn_rdy) begin
              status <= READY_FOR_LAUNCH;
              if (jump) begin
                now_pc <= jump_addr;
              end else begin
                now_pc <= now_pc + 4;
              end
            end
          end
          READY_FOR_LAUNCH: begin
            ins_asked <= 0;
            ask_predictor <= 0;
            if (!rob_full && !lsb_full) begin
              if_ins_launch_flag <= 1;
              if_ins <= now_instruction;
              if_ins_pc <= now_instruction_pc;
              status <= EMPTY;
            end else begin
              if_ins_launch_flag <= 0;
            end
          end
          JALR_READY_FOR_LAUNCH: begin
            ins_asked <= 0;
            ask_predictor <= 0;
            if (!rob_full && !lsb_full) begin
              if_ins_launch_flag <= 1;
              if_ins <= now_instruction;
              if_ins_pc <= now_instruction_pc;
              status <= FREEZE_JALR;
            end else begin
              if_ins_launch_flag <= 0;
            end
          end
          FREEZE_JALR: begin
            ins_asked <= 0;
            ask_predictor <= 0;
            if_ins_launch_flag <= 0;
            if (jalr_commit) begin
              now_pc <= jalr_addr;
              status <= EMPTY;
            end
          end
          WAITING_INS_AFTER_FLUSH: begin
            ins_asked <= 0;
            ask_predictor <= 0;
            if_ins_launch_flag <= 0;
            if (ic_rdy) status <= EMPTY;
          end
        endcase
      end
    end

  end

endmodule  //instruction_fetcher
