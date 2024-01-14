
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
  parameter ICSIZE = 256;
  parameter NOTBUSY = 0;
  parameter WAITING_MC_ENABLE = 1;
  parameter WAITING_MC_INS = 2;
  //ic_enable 为0时的等待
  //改成直接映射
  reg valid [ICSIZE-1:0];
  reg [7:0] tag[ICSIZE-1:0];
  reg [31:0] instruction[ICSIZE-1:0];
  wire hit = valid[if_ins_addr[9:2]] && (tag[if_ins_addr[9:2]]==if_ins_addr[17:10]);
  reg [1:0] status;
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < ICSIZE; i = i + 1) begin
        valid[i] <= 0;
      end
      status <= NOTBUSY;
    end else if (!rdy) begin

    end else begin
      case (status)
        NOTBUSY: begin
          if (if_ins_asked) begin
            if (~hit) begin
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
              if_ins_rdy <= 1;
              mc_ins_asked <= 0;
              if_ins <= instruction[if_ins_addr[9:2]];
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
            valid[if_ins_addr[9:2]] <= 1;
            tag[if_ins_addr[9:2]] <= if_ins_addr[17:10];
            instruction[if_ins_addr[9:2]] <= mc_ins;
          end else begin
            if_ins_rdy <= 0;
          end
        end
      endcase
    end

  end


endmodule  //i_cache
