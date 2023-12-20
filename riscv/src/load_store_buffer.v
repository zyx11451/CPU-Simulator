module load_store_buffer (
    input wire clk,
    input wire rst,
    input wire rdy,
    //rob
    input wire new_ls_ins_flag,
    input wire [31:0] new_ls_ins,
    input wire [3:0] ld_rename,
    input wire [4:0] ld_rename_reg,
    output reg ld_finish,
    output reg [3:0] ld_finish_rename,
    output reg [31:0] ld_data,
    //register
    input wire [3:0]ls_rename_finish_id,
    input wire ls_rs1_busy,
    input wire store_rs2_busy,
    input wire [3:0] ls_rs1_rename,
    input wire [3:0] store_rs2_rename,
    input wire [31:0] ls_rs1_data_from_reg,
    input wire [31:0] store_rs2_data_from_reg,
    input wire ls_rename_finish,
    output reg ls_rename_need,
    output reg [3:0] ls_rename_need_id,
    output reg load_not_store_to_register,
    output reg [4:0] rs1_reg,
    output reg [4:0] rs2_or_rd_reg,
    output reg [3:0] load_rd_rename,
    //CDB
    input wire lsb_update_flag,
    input wire [3:0] lsb_commit_rename,
    input wire [31:0] lsb_value,
    //MC
    output reg lsb_read_flag,
    output reg lsb_write_flag,
    output reg load_sign,  // (LB,LH:1,LBU,LHU:0)
    output reg [1:0] data_size_to_mc,
    output reg [31:0] data_addr,
    output reg [31:0] data_write,
    input wire [31:0] data_read,
    input wire lsb_enable,
    input wire data_rdy
);
  parameter LSBSIZE = 16;
  parameter LB = 11;
  parameter LH = 12;
  parameter LW = 13;
  parameter LBU = 14;
  parameter LHU = 15;
  parameter SB = 16;
  parameter SH = 17;
  parameter SW = 18;
  reg busy[LSBSIZE-1:0];
  reg [3:0] rob_rnm[LSBSIZE-1:0];
  reg load_not_store[LSBSIZE-1:0];
  reg [1:0] data_size[LSBSIZE-1:0];  //B:0;H:1;W:11
  reg signed_not_unsigned[LSBSIZE-1:0];
  reg [31:0] target_addr[LSBSIZE-1:0];
  reg [31:0] offset[LSBSIZE-1:0];
  reg [3:0] rs1_ins[LSBSIZE-1:0];
  reg target_addr_rdy[LSBSIZE-1:0];
  reg store_data_rdy[LSBSIZE-1:0];  //Load指令自动为1
  reg [3:0] rs2_ins[LSBSIZE-1:0];
  reg [31:0] data[LSBSIZE-1:0];
  reg [3:0] prev_store_num[LSBSIZE-1:0];  //当指令之前的store个数为0时就可以走了
  reg mc_data_req_sent;//为1时表明mc已被占用
  reg waiting_for_load_data;
  reg [3:0] waiting_load_id;
  integer i, empty_ins, ready_ins, ready_found, now_store_num,mc_ask_load_ins;
  //部分乱序
  //如果之前送进去的指令不为Sb,则要等待一个回合再尝试送S类指令。
  reg store_ins_recently_sent;
  always @(*) begin
    now_store_num = 0;
    ready_found   = 0;
    for (i = 0; i < LSBSIZE; i = i + 1) begin
      if (!busy[i]) begin
        empty_ins = i;
      end else begin
        if (!ready_found) begin
          if (target_addr_rdy[i] && store_data_rdy[i] && prev_store_num[i] == 0) begin
            ready_found = 1;
            ready_ins   = i;
          end
        end
        if (!load_not_store[i]) now_store_num = now_store_num + 1;
      end
    end
  end
  always @(posedge clk) begin
    if (ls_rename_finish) begin
      if (ls_rs1_busy) begin
        rs1_ins[ls_rename_finish_id] <= ls_rs1_rename;
        target_addr_rdy[ls_rename_finish_id] <= 0;
      end else begin
        target_addr_rdy[ls_rename_finish_id] <= 1;
        target_addr[ls_rename_finish_id] <= ls_rs1_data_from_reg + $signed(offset[ls_rename_finish_id]);
      end
      if (load_not_store[ls_rename_finish_id]) begin
        store_data_rdy[ls_rename_finish_id] <= 1;
      end else begin
        if (store_rs2_busy) begin
          rs2_ins[ls_rename_finish_id] <= store_rs2_rename;
          store_data_rdy[ls_rename_finish_id] <= 0;
        end else begin
          store_data_rdy[ls_rename_finish_id] <= 1;
          data[ls_rename_finish_id] <= store_rs2_data_from_reg;
        end
      end
    end
    if (new_ls_ins_flag) begin
      busy[empty_ins] <= 1;
      rob_rnm[empty_ins] <= ld_rename;
      prev_store_num[empty_ins] <= now_store_num;
      ls_rename_need <= 1;
      ls_rename_need_id <= empty_ins;
      rs1_reg <= new_ls_ins[19:15];
      load_rd_rename <= ld_rename;
      case (new_ls_ins[6:0])
        7'b0000011: begin
          //load 
          offset[empty_ins] <= {{20{new_ls_ins[31]}}, new_ls_ins[31:20]};
          load_not_store[empty_ins] <= 1;
          load_not_store_to_register <= 1;
          rs2_or_rd_reg <= new_ls_ins[11:7];
          case (new_ls_ins[14:12])
            3'b000: begin
              signed_not_unsigned[empty_ins] <= 1;
              data_size[empty_ins] <= 0;
            end
            3'b001: begin
              signed_not_unsigned[empty_ins] <= 1;
              data_size[empty_ins] <= 1;
            end
            3'b010: begin
              signed_not_unsigned[empty_ins] <= 1;
              data_size[empty_ins] <= 3;
            end
            3'b100: begin
              signed_not_unsigned[empty_ins] <= 0;
              data_size[empty_ins] <= 0;
            end
            3'b101: begin
              signed_not_unsigned[empty_ins] <= 0;
              data_size[empty_ins] <= 1;
            end
          endcase
        end
        7'b0100011: begin
          //store
          offset[empty_ins] <= {{20{new_ls_ins[31]}}, new_ls_ins[31:25], new_ls_ins[11:7]};
          load_not_store[empty_ins] <= 0;
          load_not_store_to_register <= 0;
          rs2_or_rd_reg <= new_ls_ins[24:20];
          case (new_ls_ins[14:12])
            3'b000: begin
              signed_not_unsigned[empty_ins] <= 1;
              data_size[empty_ins] <= 0;
            end
            3'b001: begin
              signed_not_unsigned[empty_ins] <= 1;
              data_size[empty_ins] <= 1;
            end
            3'b010: begin
              signed_not_unsigned[empty_ins] <= 1;
              data_size[empty_ins] <= 3;
            end
          endcase
        end
      endcase
    end else begin
      ls_rename_need <= 0;
    end
    if(lsb_update_flag) begin
      for(i=0;i<LSBSIZE;i=i+1) begin
        if (busy[i] && (!ls_rename_finish || i != ls_rename_finish_id)) begin
          if(!target_addr_rdy[i] && rs1_ins[i] == lsb_commit_rename) begin
            target_addr_rdy[i] <= 1;
            target_addr[i] <= lsb_value + $signed(offset[i]);
          end 
          if(!store_data_rdy[i] && rs2_ins[i] == lsb_commit_rename) begin
            store_data_rdy[i] <= 1;
            data[i] <= lsb_value; 
          end
        end
        if(ls_rename_finish) begin
          if(ls_rs1_busy && ls_rs1_rename == lsb_commit_rename) begin
            target_addr_rdy[ls_rename_finish_id] <= 1;
            target_addr[ls_rename_finish_id] <= lsb_value + $signed(offset[ls_rename_finish_id]);
          end
          if(store_rs2_busy && store_rs2_rename == lsb_commit_rename) begin
            store_data_rdy[ls_rename_finish_id] <= 1;
            data[ls_rename_finish_id] <= lsb_value;
          end
        end
      end
    end
    if(ready_found && !waiting_for_load_data) begin
      if(lsb_enable) begin
        if(store_ins_recently_sent) begin
          store_ins_recently_sent <= 0;
        end else begin
          if(load_not_store[ready_ins]) begin
            lsb_read_flag <= 1;
            lsb_write_flag <= 0;
            waiting_for_load_data <= 1;
            waiting_load_id <= ready_ins;
            data_size_to_mc <= data_size[ready_ins];
            data_addr <= target_addr[ready_ins];
            load_sign <= signed_not_unsigned[ready_ins];
          end else begin
            busy[ready_ins] <= 0;
            lsb_write_flag <= 1;
            lsb_read_flag <= 0;
            data_size_to_mc <= data_size[ready_ins];
            data_addr <= target_addr[ready_ins];
            data_write <= data[ready_ins];
            if(data_size[ready_ins] != 0) begin
              store_ins_recently_sent <= 1;
            end
            //调整其余指令的store数
            if(new_ls_ins_flag) begin
              for(i=0;i<LSBSIZE;i=i+1) begin
                if(busy[i] && i!=empty_ins && prev_store_num[i]!=0) begin
                  prev_store_num[i]<= prev_store_num[i]-1;
                end
              end
              prev_store_num[empty_ins] <= now_store_num-1;
            end else begin
              for(i=0;i<LSBSIZE;i=i+1) begin
                if(busy[i] && prev_store_num[i]!=0) begin
                  prev_store_num[i]<= prev_store_num[i]-1;
                end
              end
            end
          end
        end
      end
    end
    if(data_rdy) begin
      //将指令直接传给rob
      busy[waiting_load_id] <= 0;
      ld_finish <= 1;
      ld_finish_rename <= rob_rnm[waiting_load_id];
      ld_data <= data_read;
      waiting_for_load_data <= 0;
    end else begin
      ld_finish <= 0;
    end
  end
endmodule  //load_store_buffer
