module memory_controller (
    input wire clk,
    input wire rst,
    input wire rdy,
    //RAM
    input wire [7:0] mem_in,
    output reg en_in,
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
    input wire lsb_flag,
    input wire lsb_r_nw,
    input wire load_sign,  // (LB,LH:1,LBU,LHU:0)
    input wire [1:0] data_size,
    input wire [31:0] data_addr,
    input wire [31:0] data_write,
    output reg [31:0] data_read,
    output reg lsb_enable,
    output reg data_rdy  //L或S操作完成
);
  //todo 也写成状态机
  parameter NOTBUSY = 0;
  parameter DATA_READING = 1;
  parameter DATA_WRITING = 2;
  parameter INS_READING = 3;
  reg [1:0] status;
  reg [2:0] ins_reading_stage ;  //下一个周期接收到的是第几节指令,5为接收完成
  reg [2:0] data_stage ;
  reg now_ins_waiting;  //当同时或隔一个周期接到lsb和ic的信号时,将ic的信号存至此处
  reg now_data_waiting;
  always @(posedge clk) begin
    if (rst) begin
      status <= NOTBUSY;
      ins_reading_stage <= 0;
      data_stage <= 0;
      now_data_waiting <= 0;
      now_data_waiting <= 0;
      //
      en_in <= 0;
      mem_write <= 0;
      addr <= 0;
      r_nw_out <= 1;
      ins_rdy <= 0;
      ic_enable <= 1;
      ins <= 0;
      ins_rdy <= 0;
      lsb_enable <= 1;
      data_rdy <= 0;
      data_read <= 0;
    end else if (!rdy) begin

    end else begin
      case (status)
        NOTBUSY: begin
          ins_rdy <= 0;
          if (lsb_flag || now_data_waiting) begin
            if (now_data_waiting) now_data_waiting <= 0;
            if (lsb_r_nw) begin
              data_rdy <= 0;
              ic_enable <= 0;
              lsb_enable <= 0;
              status <= DATA_READING;
              data_stage <= 0;
              en_in <= 1;
              r_nw_out <= 1;
              addr <= data_addr;
            end else begin
              data_stage <= 1;
              en_in <= 1;
              r_nw_out <= 0;
              mem_write <= data_write[7:0];
              if (data_size == 0) begin
                data_rdy <= 1;
                status   <= NOTBUSY;
                if (!now_ins_waiting && !ic_flag) begin
                  //本周期完成后无任务,下一个周期可以接新任务
                  lsb_enable <= 1;
                  ic_enable  <= 1;
                end else begin
                  ic_enable  <= 0;
                  lsb_enable <= 0;
                end
              end else begin
                status <= DATA_WRITING;
                data_rdy <= 0;
                ic_enable <= 0;
                lsb_enable <= 0;
              end
            end
            if (ic_flag) begin
              now_ins_waiting <= 1;
            end
          end else if (ic_flag || now_ins_waiting) begin
            if (now_ins_waiting) now_ins_waiting <= 0;
            data_rdy <= 0;
            ic_enable <= 0;
            lsb_enable <= 0;
            status <= INS_READING;
            ins_reading_stage <= 0;
            en_in <= 1;
            r_nw_out <= 1;
            addr <= ins_addr;
          end else begin
            data_rdy <= 0;
            ic_enable <= 1;
            lsb_enable <= 1;
            en_in <= 0;
          end
        end
        DATA_READING: begin
          r_nw_out <= 1;
          ins_rdy  <= 0;
          case (data_stage)
            0: begin
              data_read[7:0] <= mem_in;
            end
            1: begin
              data_read[15:8] <= mem_in;
            end
            2: begin
              data_read[23:16] <= mem_in;
            end
            3: begin
              data_read[31:24] <= mem_in;
            end
          endcase
          if (data_stage == data_size) begin
            data_rdy <= 1;
            if (load_sign) begin
              if (data_size == 0) data_read[31:8] <= {24{mem_in[7]}};
              else if (data_size == 1) data_read[31:16] <= {16{mem_in[7]}};
            end
            data_stage <= 0;
            if (now_ins_waiting || ic_flag) begin
              if (now_ins_waiting) now_ins_waiting <= 0;
              lsb_enable <= 0;
              ic_enable <= 0;
              status <= INS_READING;
              en_in <= 1;
              addr <= ins_addr;
              ins_reading_stage <= 0;
            end else begin
              lsb_enable <= 1;
              ic_enable <= 1;
              status <= NOTBUSY;
              en_in <= 0;
            end
          end else begin
            data_stage <= data_stage + 1;
            en_in <= 1;
            addr <= addr + 1;
            lsb_enable <= 0;
            ic_enable <= 0;
            if (ic_flag) now_ins_waiting <= 1;
          end
        end
        DATA_WRITING: begin
          r_nw_out <= 0;
          ins_rdy <= 0;
          en_in <= 1;
          lsb_enable <= 0;
          ic_enable <= 0;
          case (data_stage)
            1: begin
              mem_write <= data_write[15:8];
            end
            2: begin
              mem_write <= data_write[23:16];
            end
            3: begin
              mem_write <= data_write[31:24];
            end
          endcase
          if (data_stage == data_size) begin
            data_rdy <= 1;
            data_stage <= 0;
            status <= NOTBUSY;
          end else begin
            data_rdy <= 0;
            addr <= addr + 1;
            data_stage <= data_stage + 1;
          end
          if (ic_flag) begin
            now_ins_waiting <= 1;
          end
        end
        INS_READING: begin
          r_nw_out   <= 1;
          data_rdy   <= 0;
          lsb_enable <= 0;
          ic_enable  <= 0;
          case (ins_reading_stage)
            0: begin
              ins[7:0] <= mem_in;
            end
            1: begin
              ins[15:8] <= mem_in;
            end
            2: begin
              ins[23:16] <= mem_in;
            end
            3: begin
              ins[31:24] <= mem_in;
            end
          endcase
          if (ins_reading_stage == 3) begin
            ins_rdy <= 1;
            en_in <= 0;
            ins_reading_stage <= 0;
            status <= NOTBUSY;
          end else begin
            ins_rdy <= 0;
            addr <= addr + 1;
            ins_reading_stage <= ins_reading_stage + 1;
          end
          if (lsb_flag) begin
            now_data_waiting <= 1;
          end
        end
      endcase
    end
  end
endmodule  //memory_controller
