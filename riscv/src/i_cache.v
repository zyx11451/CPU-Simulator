
module i_cache (
    input wire clk,
    input wire rst,
    input wire rdy,
    //memory_controller
    output reg mc_ins_asked,
    output reg [31:0] mc_ins_addr,
    input wire mc_ins_rdy,
    input wire [31:0] mc_ins,
    //instruction_fetcher
    input wire [31:0] if_ins_addr,
    input wire if_ins_asked,
    output reg if_ins_rdy,
    output reg [31:0] if_ins
);
  parameter ICSIZE = 32;
  //todo ic_enable 为0时的等待
  reg [31:0] pc = 0;
  reg [31:0] instruction[ICSIZE-1:0];
  reg [31:0] instruction_pc[ICSIZE-1:0];
  reg [15:0] instruction_age[ICSIZE-1:0];  //0为未占用,指令年龄最小为1
  reg cache_miss = 0;
  reg [31:0] now_instruction;
  integer i, ins_to_be_replaced, max_age, has_empty;
  always @(*) begin
    if (if_ins_asked) begin
      cache_miss = 1;
      for (i = 0; i < ICSIZE; i = i + 1) begin
        if (instruction_pc[i] == if_ins_addr) begin
          cache_miss = 0;
          now_instruction = instruction[i];
          instruction_age[i] = 1;
          instruction_pc[i] = if_ins_addr;
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
    if (if_ins_asked) begin
      if (cache_miss) begin
        //向MC要求指令
        mc_ins_asked <= 1;
        mc_ins_addr  <= if_ins_addr;
      end else begin
        //把命中的指令输出
        if_ins_rdy <= 1;
        if_ins <= now_instruction;
      end
    end
    if (mc_ins_rdy) begin
      //把指令送入if
      if_ins_rdy <= 1;
      if_ins <= mc_ins;
      //填充空位或把最老的换下去
      instruction[ins_to_be_replaced] <= mc_ins;
      instruction_pc[ins_to_be_replaced] <= if_ins_addr;
      instruction_age[ins_to_be_replaced] <= 1;
    end
  end


endmodule  //i_cache
