
module i_cache (
    input wire clk,
    input wire rst,
    input wire rdy,
    //memory_controller
    output reg mc_ins_asked,
    output reg [31:0] mc_ins_addr,
    input wire mc_ins_rdy,
    input wire [31:0] mc_ins,
    input wire ic_enable,
    //instruction_fetcher
    input wire [31:0] if_ins_addr,
    input wire if_ins_asked,
    output reg if_ins_rdy,
    output reg [31:0] if_ins
);
  parameter ICSIZE = 32;
  parameter NOTBUSY = 0;
  parameter WAITING_MC_ENABLE = 1;
  parameter WAITING_MC_INS = 2;
  //ic_enable 为0时的等待
  reg [31:0] instruction[ICSIZE-1:0];
  reg [31:0] instruction_pc[ICSIZE-1:0];
  reg [15:0] instruction_age[ICSIZE-1:0];  //0为未占用,指令年龄最小为1
  reg cache_miss;
  reg [1:0] status;
  integer i, ins_to_be_replaced, max_age, has_empty;
  always @(*) begin
    if (if_ins_asked) begin
      cache_miss = 1;
      for (i = 0; i < ICSIZE; i = i + 1) begin
        if (instruction_pc[i] == if_ins_addr && instruction_age[i] != 0) begin
          cache_miss = 0;
          if_ins = instruction[i];
          instruction_age[i] = 1;
          instruction_pc[i] = if_ins_addr;
        end else if (instruction_age[i] != 0) begin
          instruction_age[i] = instruction_age[i] + 1;
        end
      end
    end
    max_age   = 0;
    has_empty = 0;
    for (i = 0; i < ICSIZE; i = i + 1) begin
      if (instruction_age[i] == 0) begin
        ins_to_be_replaced = i;
        has_empty = 1;
      end
      if (instruction_age[i] > max_age && !has_empty) begin
        ins_to_be_replaced = i;
        max_age = instruction_age[i];
      end
    end
  end
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < ICSIZE; i = i + 1) begin
        instruction[i] <= 0;
        instruction_pc[i] <= 0;
        instruction_age[i] <= 0;
      end
      status <= NOTBUSY;
    end else
    if (!rdy) begin

    end else begin
      case (status)
        NOTBUSY: begin
          if (if_ins_asked) begin
            if (cache_miss) begin
              if_ins_rdy <= 0;
              if (ic_enable) begin
                status <= WAITING_MC_INS;
                mc_ins_asked <= 1;
                mc_ins_addr <= if_ins_addr;
              end else begin
                status <= WAITING_MC_ENABLE;
                mc_ins_asked <= 0;
              end
            end else begin
              if_ins_rdy   <= 1;
              mc_ins_asked <= 0;
            end
          end else begin
            if_ins_rdy   <= 0;
            mc_ins_asked <= 0;
          end
        end
        WAITING_MC_ENABLE: begin
          if_ins_rdy <= 0;
          if (ic_enable) begin
            mc_ins_asked <= 1;
            mc_ins_addr <= if_ins_addr;
            status <= WAITING_MC_INS;
          end else begin
            mc_ins_asked <= 0;
          end
        end
        WAITING_MC_INS: begin
          mc_ins_asked <= 0;
          if (mc_ins_rdy) begin
            status <= NOTBUSY;
            if_ins_rdy <= 1;
            if_ins <= mc_ins;
            instruction[ins_to_be_replaced] <= mc_ins;
            instruction_pc[ins_to_be_replaced] <= if_ins_addr;
            instruction_age[ins_to_be_replaced] <= 1;
          end else begin
            if_ins_rdy <= 0;
          end
        end
      endcase
    end

  end


endmodule  //i_cache
