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
  parameter PREDICTOR_SIZE = 4;  //FIFO
  parameter PREDICTOR_MEMORY_SIZE = 8;  //普通的表
  integer
      i,
      ins_cnt,
      hit_ins,
      replace_ins,
      now_oldest_ins,
      now_oldest_age,
      head_ins_ind,
      tail_less_than_head;
  reg [1:0] head, tail;
  reg [31:0] next_addr[PREDICTOR_SIZE-1:0];
  reg [31:0] jump_addr[PREDICTOR_SIZE-1:0];
  reg predict_jump[PREDICTOR_SIZE-1:0];
  reg [3:0] predict_ind[PREDICTOR_SIZE-1:0];
  reg [31:0] ins_pc[PREDICTOR_MEMORY_SIZE-1:0];
  reg [1:0] jump_judge[PREDICTOR_MEMORY_SIZE-1:0];
  reg [7:0] age[PREDICTOR_MEMORY_SIZE-1:0];
  reg busy[PREDICTOR_MEMORY_SIZE-1:0];
  reg miss, replace_found;
  always @(*) begin
    if (ask_predictor) begin
      miss = 1;
      replace_found = 0;
      now_oldest_age = 0;
      for (i = 0; i < PREDICTOR_MEMORY_SIZE; i = i + 1) begin
        if (busy[i]) begin
          if (ins_pc[i] == now_ins_addr) begin
            age[i] = 0;
            miss = 0;
            hit_ins = i;
          end else begin
            age[i] = age[i] + 1;
            if (age[i] >= now_oldest_age) begin
              now_oldest_age = age[i];
              now_oldest_ins = i;
            end
          end
        end else begin
          if (!replace_found) begin
            replace_found = 1;
            replace_ins   = i;
          end
        end
      end
      if (!replace_found) begin
        replace_ins = now_oldest_ins;
      end
    end
    head_ins_ind = predict_ind[head];
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
      for (i = 0; i < PREDICTOR_MEMORY_SIZE; i = i + 1) begin
        busy[i] <= 0;
      end
      predictor_sgn_rdy <= 0;
    end else if (!rdy) begin

    end else begin
      if (ask_predictor) begin
        if (miss) begin
          busy[replace_ins] <= 1;
          ins_pc[replace_ins] <= now_ins_addr;
          jump_judge[replace_ins] <= 1;
          age[replace_ins] <= 0;
          next_addr[tail] <= next_addr_from_if;
          jump_addr[tail] <= jump_addr_from_if;
          predict_jump[tail] <= 0;
          predict_ind[tail] <= replace_ins;
          predictor_sgn_rdy <= 1;
          jump <= 0;
          tail <= tail + 1;
          if (tail == 3) tail_less_than_head <= 1;
        end else begin
          next_addr[tail]   <= next_addr_from_if;
          jump_addr[tail]   <= jump_addr_from_if;
          predict_ind[tail] <= hit_ins;
          predictor_sgn_rdy <= 1;
          if (jump_judge[hit_ins] >= 2) begin
            predict_jump[tail] <= 1;
            jump <= 1;
          end else begin
            predict_jump[tail] <= 0;
            jump <= 0;
          end
          tail <= tail + 1;
        end
      end else begin
        predictor_sgn_rdy <= 0;
      end
      if (branch_commit) begin
        head <= head + 1;
        if (head == 3) tail_less_than_head <= 0;
        if (branch_jump) begin
          if (jump_judge[head_ins_ind] < 3)
            jump_judge[head_ins_ind] <= jump_judge[head_ins_ind] + 1;
          if (!predict_jump[head]) begin
            if_flush <= 1;
            lsb_flush <= 1;
            rob_flush <= 1;
            rs_flush <= 1;
            cdb_flush <= 1;
            register_flush <= 1;
            addr_to_if <= jump_addr[head];
            head <= 0;
            tail <= 0;
            tail_less_than_head <= 0;
          end else begin
            if_flush  <= 0;
            lsb_flush <= 0;
            rob_flush <= 0;
            rs_flush  <= 0;
            cdb_flush <= 0;
            register_flush <= 0;
          end
        end else begin
          if (jump_judge[head_ins_ind] > 0)
            jump_judge[head_ins_ind] <= jump_judge[head_ins_ind] - 1;
          if (predict_jump[head]) begin
            if_flush <= 1;
            lsb_flush <= 1;
            rob_flush <= 1;
            rs_flush <= 1;
            cdb_flush <= 1;
            register_flush <= 1;
            addr_to_if <= next_addr[head];
            head <= 0;
            tail <= 0;
            tail_less_than_head <= 0;
          end else begin
            if_flush  <= 0;
            lsb_flush <= 0;
            rob_flush <= 0;
            rs_flush  <= 0;
            cdb_flush <= 0;
            register_flush <= 0;
          end
        end
      end else begin
        if_flush  <= 0;
        lsb_flush <= 0;
        rob_flush <= 0;
        rs_flush  <= 0;
        cdb_flush <= 0;
        register_flush <= 0;
      end
    end

  end
endmodule  //predictor
