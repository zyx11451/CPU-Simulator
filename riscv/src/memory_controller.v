module memory_controller (
    input wire clk,
    input wire rst,
    input wire rdy,
    //与RAM、IC、LSB连接
    //RAM
    input wire [7:0] mem_in,
    output reg [7:0] mem_write,
    output reg [31:0] addr,
    output reg r_nw_in,  // read/write select (read: 1, write: 0)
    //IC
    input wire ic_flag,
    input wire [31:0] ins_addr,
    output reg [31:0] ins,
    output reg ins_rdy,
    //LSB
    input wire read_flag,
    input wire write_flag,
    input wire load_sign,  // (LB,LH:1,LBU,LHU:0)
    input wire [1:0] data_size,
    input wire [31:0] data_addr,
    input wire [31:0] data_write,
    output reg [31:0] data_read,
    output reg data_rdy
);
  reg ins_flag;
  reg data_flag;
  reg [1:0] ins_reading_stage;
  reg [1:0] data_stage;
  reg [31:0] now_ins;
  always @(posedge clk) begin
    if (!data_flag && !ins_flag) begin
      if (read_flag || write_flag) begin
        data_flag <= 1;
        ins_flag  <= 0;
      end
      if (ic_flag && !data_flag) begin
        ins_flag <= 1;
      end
    end
    if (data_flag) begin
      if (read_flag) begin
        r_nw_in=1;
        

      end
    end
  end
endmodule  //memory_controller
