module predictor (
    input wire clk,
    input wire rst,
    input wire rdy,
    //IF
    input wire ask_predictor,
    input wire [31:0] now_ins_addr,
    input wire [31:0] jump_addr_from_if,
    input wire [31:0] next_addr_from_if,
    output reg jump,
    output reg predictor_sgn_rdy,
    output reg predictor_full,
    output reg if_flush,
    output reg [31:0] addr_to_if,
    //LSB
    output reg lsb_flush,
    //ROB
    output reg rob_flush,
    //RS
    output reg rs_flush,
    //Register
    output reg register_flush,
    //CDB
    output reg cdb_flush,
    input wire branch_commit,
    input wire branch_jump
);
  //最简单的二位分支预测器
  //其它元件的flush指令
  //不用完全hit,末几位对上就行
  parameter PREDICTOR_SIZE = 4;  //FIFO
  parameter PREDICTOR_MEMORY_SIZE = 64;  //普通的表,反正一个就2bit,可以设多一些
  integer
      i,
      ins_cnt,
      tail_less_than_head;
  reg [1:0] head, tail;
  reg [31:0] next_addr[PREDICTOR_SIZE-1:0];
  reg [31:0] jump_addr[PREDICTOR_SIZE-1:0];
  reg predict_jump[PREDICTOR_SIZE-1:0];
  reg [5:0] predict_ind[PREDICTOR_SIZE-1:0];
  reg [1:0] jump_judge[PREDICTOR_MEMORY_SIZE-1:0];
  reg other_flushing;  //为避免在送出flush的下一个周期接到提交或询问导致错误
  always @(*) begin
    if (tail_less_than_head) ins_cnt = tail + 4 - head;
    else ins_cnt = tail - head;
    if (ins_cnt == 4) predictor_full = 1;
    else predictor_full = 0;
  end
  always @(posedge clk) begin
    if (rst) begin
      head <= 0;
      tail <= 0;
      tail_less_than_head <= 0;
      other_flushing <= 0;
      for (i = 0; i < PREDICTOR_MEMORY_SIZE; i = i + 1) begin
        jump_judge[i] <= 1;
      end
      predictor_sgn_rdy <= 0;
    end else
    if (!rdy) begin

    end else begin
      if (other_flushing) begin
        if_flush <= 0;
        lsb_flush <= 0;
        rob_flush <= 0;
        rs_flush <= 0;
        cdb_flush <= 0;
        register_flush <= 0;
        other_flushing <= 0;
      end else begin
        if (ask_predictor) begin
            tail <= tail+1;
            next_addr[tail]   <= next_addr_from_if;
            jump_addr[tail]   <= jump_addr_from_if;
            predict_ind[tail] <= now_ins_addr[7:2];
            predictor_sgn_rdy <= 1;
            if (jump_judge[now_ins_addr[7:2]] >= 2) begin
              predict_jump[tail] <= 1;
              jump <= 1;
            end else begin
              predict_jump[tail] <= 0;
              jump <= 0;
            end
        end else begin
          predictor_sgn_rdy <= 0;
        end
        if (branch_commit) begin
          head <= head + 1;
          if (head == 3) tail_less_than_head <= 0;
          if (branch_jump) begin
            if (jump_judge[predict_ind[head]] < 3)
              jump_judge[predict_ind[head]] <= jump_judge[predict_ind[head]] + 1;
            if (!predict_jump[head]) begin
              if_flush <= 1;
              lsb_flush <= 1;
              rob_flush <= 1;
              rs_flush <= 1;
              cdb_flush <= 1;
              register_flush <= 1;
              addr_to_if <= jump_addr[head];
              other_flushing <= 1;
              head <= 0;
              tail <= 0;
              tail_less_than_head <= 0;
            end else begin
              if_flush <= 0;
              lsb_flush <= 0;
              rob_flush <= 0;
              rs_flush <= 0;
              cdb_flush <= 0;
              register_flush <= 0;
            end
          end else begin
            if (jump_judge[predict_ind[head]] > 0)
              jump_judge[predict_ind[head]] <= jump_judge[predict_ind[head]] - 1;
            if (predict_jump[head]) begin
              if_flush <= 1;
              lsb_flush <= 1;
              rob_flush <= 1;
              rs_flush <= 1;
              cdb_flush <= 1;
              register_flush <= 1;
              addr_to_if <= next_addr[head];
              other_flushing <= 1;
              head <= 0;
              tail <= 0;
              tail_less_than_head <= 0;
            end else begin
              if_flush <= 0;
              lsb_flush <= 0;
              rob_flush <= 0;
              rs_flush <= 0;
              cdb_flush <= 0;
              register_flush <= 0;
            end
          end
        end else begin
          if_flush <= 0;
          lsb_flush <= 0;
          rob_flush <= 0;
          rs_flush <= 0;
          cdb_flush <= 0;
          register_flush <= 0;
        end
      end

    end

  end
endmodule  //predictor
