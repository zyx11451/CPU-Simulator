module memory_controller (
    input wire clk,
    input wire rst,
    input wire rdy,
    //RAM
    input wire [7:0] mem_in,
    output reg [7:0] mem_write,
    output reg [31:0] addr,
    output reg r_nw_out,  // read/write select (read: 1, write: 0)
    //IC
    input wire ic_flag,
    input wire [31:0] ins_addr,
    output reg ic_enable,
    output reg [31:0] ins,
    output reg ins_rdy,
    //LSB
    input wire lsb_read_flag,
    input wire lsb_write_flag,
    input wire load_sign,  // (LB,LH:1,LBU,LHU:0)
    input wire [1:0] data_size,
    input wire [31:0] data_addr,
    input wire [31:0] data_write,
    output reg [31:0] data_read,
    output reg lsb_enable,
    output reg data_rdy
);
  reg ins_flag = 0;
  reg data_flag = 0;
  reg data_r_nw_flag;
  reg [2:0] ins_reading_stage = 0;  //下一个周期接收到的是第几节指令,5为接收完成
  reg [2:0] data_stage = 0;
  reg [31:0] now_ins;
  reg now_ins_waiting;  //当同时或隔一个周期接到lsb和ic的信号时,将ic的信号存至此处
  reg now_data_waiting;
  reg now_waiting_data_r_nw;
  always @(posedge clk) begin
    if (data_flag) begin
      addr <= addr + 1;
      if (data_r_nw_flag) begin
        //Load
        r_nw_out <= 1;
        addr <= addr + 1;
        case (data_stage)
        //todo load_sign 尚未处理
          3'b000: begin
            data_read[7:0] <= mem_in;
          end
          3'b001: begin
            data_read[15:8] <= mem_in;
          end
          3'b010: begin
            data_read[23:16] <= mem_in;
          end
          3'b011: begin
            data_read[31:24] <= mem_in;
          end
        endcase
        if (data_stage == data_size) begin
          data_rdy   <= 1;
          data_stage <= 0;
          data_flag  <= 0;
        end else begin
          data_stage <= data_stage + 1;
        end
      end else begin
        r_nw_out <= 0;
        addr <= addr + 1;
        case (data_stage)
          3'b001: begin
            mem_write <= data_write[15:8];
          end
          3'b010: begin
            mem_write <= data_write[23:16];
          end
          3'b011: begin
            mem_write <= data_write[31:24];
          end
        endcase
        if (data_stage == data_size) begin
          data_stage <= 0;
          data_flag  <= 0;
        end else begin
          data_stage <= data_stage + 1;
        end
      end
    end else if (ins_flag) begin
      addr <= addr + 1;
      r_nw_out <= 1;
      case (ins_reading_stage)
        3'b000: begin
          ins[7:0] <= mem_in;
          ins_reading_stage <= 1;
        end
        3'b001: begin
          ins[15:8] <= mem_in;
          ins_reading_stage <= 2;
        end
        3'b010: begin
          ins[23:16] <= mem_in;
          ins_reading_stage <= 3;
        end
        3'b011: begin
          ins[31:24] <= mem_in;
          ins_flag <= 0;
          ins_rdy <= 1;
          ins_reading_stage <= 0;
        end
      endcase
    end else begin
      ins_rdy <= 0;
      if (lsb_read_flag || lsb_write_flag) begin
        if (data_flag || ins_flag) begin
          now_data_waiting <= 1;
          now_waiting_data_r_nw <= lsb_read_flag;
        end else begin
          addr <= data_addr;
          ic_enable <= 0;
          lsb_enable <= 0;
          if (lsb_read_flag) begin
            data_flag  <= 1;
            r_nw_out   <= 1;
            data_stage <= 0;
          end
          if (lsb_write_flag) begin
            r_nw_out   <= 0;
            data_stage <= 1;
            mem_write  <= data_write[7:0];
            if (data_size == 0) begin
              data_flag <= 0;
            end else begin
              data_flag <= 1;
            end
          end
        end
      end
      if (ic_flag) begin
        if (!lsb_read_flag && !lsb_write_flag && !data_flag && !ins_flag) begin
          ins_flag <= 1;
          addr <= ins_addr;
          r_nw_out <= 1;
          ins_reading_stage <= 1;
          ic_enable <= 0;
          lsb_enable <= 0;
        end else begin
          now_ins_waiting <= 1;
        end
      end
      if(!data_flag && !ins_flag && !lsb_read_flag && !lsb_write_flag && !ic_flag) begin
        if(now_data_waiting) begin
          addr <= data_addr;
          if (now_waiting_data_r_nw) begin
            data_flag  <= 1;
            r_nw_out   <= 1;
            data_stage <= 0;
          end else begin
            r_nw_out   <= 0;
            data_stage <= 1;
            mem_write  <= data_write[7:0];
            if (data_size == 0) begin
              data_flag <= 0;
            end else begin
              data_flag <= 1;
            end
          end
        end else if(now_ins_waiting) begin
          ins_flag <= 1;
          addr <= ins_addr;
          r_nw_out <= 1;
          ins_reading_stage <= 1;
        end else begin
          ic_enable <= 1;
          lsb_enable <= 1;
        end
      end
    end
  end
endmodule  //memory_controller
