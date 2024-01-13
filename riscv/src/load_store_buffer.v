module load_store_buffer (
    input wire clk,
    input wire rst,
    input wire rdy,
    //rob 发射
    input wire new_ls_ins_flag,
    input wire [3:0] new_ls_ins_rnm,
    //rob Load提交或STORE整理完
    output reg load_finish,
    output reg [3:0] load_finish_rename,
    output reg [31:0] ld_data,
    output reg store_finish,  //被送到LSB就算"finish"
    output reg [3:0] store_finish_rename,
    //RS
    input wire ls_mission,
    input wire [3:0] ls_ins_rnm,
    input wire [5:0] ls_op_type,
    input wire [31:0] ls_addr_offset,
    input wire [31:0] ls_ins_rs1,
    input wire [31:0] store_ins_rs2,
    //CDB
    input wire lsb_update_flag,
    input wire [3:0] lsb_commit_rename,
    //Predictor
    input wire lsb_flush,
    //IF
    output reg lsb_full,  //满时停止指令发射
    //MC
    output reg lsb_flag,
    output reg lsb_r_nw,
    output reg load_sign,  // (LB,LH:1,LBU,LHU:0)
    output reg [1:0] data_size_to_mc,
    output reg [31:0] data_addr,
    output reg [31:0] data_write,
    input wire [31:0] data_read,
    input wire lsb_enable,
    input wire data_rdy  //读或写完成
);
  parameter LSBSIZE = 16;  //大于12即为满
  parameter LB = 11;
  parameter LH = 12;
  parameter LW = 13;
  parameter LBU = 14;
  parameter LHU = 15;
  parameter SB = 16;
  parameter SH = 17;
  parameter SW = 18;
  parameter NOTRDY = 0;  //没准备好
  parameter WAITING = 1;  //准备好了,在等待
  parameter EXEC = 2;  //指令正在进行中
  parameter FINISH = 3;  //完成,但未提交
  parameter WRONG = 4;  //Load指令因分支预测错误被标记为无效
  reg [3:0] rob_rnm[LSBSIZE-1:0];
  reg load_not_store[LSBSIZE-1:0];
  reg [1:0] data_size[LSBSIZE-1:0];  //B:0;H:1;W:11
  reg signed_not_unsigned[LSBSIZE-1:0];
  reg [31:0] target_addr[LSBSIZE-1:0];
  reg [31:0] data[LSBSIZE-1:0];
  reg [2:0] status[LSBSIZE-1:0];//在Rob提交后，Store才可被真正执行，这是为了防止分支预测出问题时后面指令对内存造成影响
  reg [3:0] head, tail;
  reg [2:0] debug;
  reg [3:0] debug1;
  integer i, rs_inf_update_ins, ins_cnt;
  //完全顺序
  //如果之前送进去的指令不为Sb,则要等待一个回合再尝试送S类指令。
  always @(*) begin
    if (ls_mission) begin
      if (tail >= head) begin
        for (i = 0; i < LSBSIZE; i = i + 1) begin
          if (i >= head && i < tail) begin
            if (rob_rnm[i] == ls_ins_rnm) rs_inf_update_ins = i;
          end
        end
      end else begin
        for (i = 0; i < LSBSIZE; i = i + 1) begin
          if (i >= head || i < tail) begin
            if (rob_rnm[i] == ls_ins_rnm) rs_inf_update_ins = i;
          end
        end
      end
    end
    if (tail >= head) ins_cnt = tail - head;
    else ins_cnt = tail + 16 - head;
    if (ins_cnt > 12) lsb_full = 1;
    else lsb_full = 0;
  end
  always @(posedge clk) begin
    debug  <= status[head];
    debug1 <= rob_rnm[head];
    if (rst) begin
      head <= 0;
      tail <= 0;
      load_finish <= 0;
      store_finish <= 0;
      lsb_flag <= 0;
    end else
    if (!rdy) begin

    end else begin
      //todo 由于和RoB中顺序一致,因此找到第一个未执行的即可,不过就这么写影响应该比较小
      if (lsb_flush) begin
        if (tail >= head) begin
          for (i = 0; i < LSBSIZE; i = i + 1) begin
            if (i >= head && i < tail) begin
              if (load_not_store[i]) status[i] <= WRONG;  //未执行的Load在Branch后面
              else begin
                if (status[i] == NOTRDY) status[i] <= WRONG;  //未被提交的Store在Branch后面
              end
            end
          end
        end else begin
          for (i = 0; i < LSBSIZE; i = i + 1) begin
            if (i < tail || i >= head) begin
              if (load_not_store[i]) status[i] <= WRONG;  //未执行的Load在Branch后面
              else begin
                if (status[i] == NOTRDY) status[i] <= WRONG;  //未被提交的Store在Branch后面
              end
            end
          end
        end
        load_finish <= 0;
        store_finish <= 0;
        lsb_flag <= 0;
        if (data_rdy && status[head] == EXEC) begin
          //store data_rdy和flush同时的情况,此时应及时处理store
          status[head] <= FINISH;
          head <= (head + 1) % LSBSIZE;
        end
      end else begin
        if (new_ls_ins_flag) begin
          rob_rnm[tail] <= new_ls_ins_rnm;
          tail <= (tail + 1) % LSBSIZE;
          status[tail] <= NOTRDY;
        end
        if (ls_mission) begin
          //一定比rob传过来要慢
          case (ls_op_type)
            LB: begin
              load_not_store[rs_inf_update_ins] <= 1;
              data_size[rs_inf_update_ins] <= 0;
              signed_not_unsigned[rs_inf_update_ins] <= 1;
              if (status[rs_inf_update_ins] != WRONG) status[rs_inf_update_ins] <= WAITING;
              store_finish <= 0;
            end
            LH: begin
              load_not_store[rs_inf_update_ins] <= 1;
              data_size[rs_inf_update_ins] <= 1;
              signed_not_unsigned[rs_inf_update_ins] <= 1;
              if (status[rs_inf_update_ins] != WRONG) status[rs_inf_update_ins] <= WAITING;
              store_finish <= 0;
            end
            LW: begin
              load_not_store[rs_inf_update_ins] <= 1;
              data_size[rs_inf_update_ins] <= 3;
              signed_not_unsigned[rs_inf_update_ins] <= 1;
              if (status[rs_inf_update_ins] != WRONG) status[rs_inf_update_ins] <= WAITING;
              store_finish <= 0;
            end
            LBU: begin
              load_not_store[rs_inf_update_ins] <= 1;
              data_size[rs_inf_update_ins] <= 0;
              signed_not_unsigned[rs_inf_update_ins] <= 0;
              if (status[rs_inf_update_ins] != WRONG) status[rs_inf_update_ins] <= WAITING;
              store_finish <= 0;
            end
            LHU: begin
              load_not_store[rs_inf_update_ins] <= 1;
              data_size[rs_inf_update_ins] <= 1;
              signed_not_unsigned[rs_inf_update_ins] <= 0;
              if (status[rs_inf_update_ins] != WRONG) status[rs_inf_update_ins] <= WAITING;
              store_finish <= 0;
            end
            SB: begin
              load_not_store[rs_inf_update_ins] <= 0;
              data_size[rs_inf_update_ins] <= 0;
              signed_not_unsigned[rs_inf_update_ins] <= 1;
              store_finish <= 1;
              store_finish_rename <= rob_rnm[rs_inf_update_ins];
            end
            SH: begin
              load_not_store[rs_inf_update_ins] <= 0;
              data_size[rs_inf_update_ins] <= 1;
              signed_not_unsigned[rs_inf_update_ins] <= 1;
              store_finish <= 1;
              store_finish_rename <= rob_rnm[rs_inf_update_ins];
            end
            SW: begin
              load_not_store[rs_inf_update_ins] <= 0;
              data_size[rs_inf_update_ins] <= 3;
              signed_not_unsigned[rs_inf_update_ins] <= 1;
              store_finish <= 1;
              store_finish_rename <= rob_rnm[rs_inf_update_ins];
            end
          endcase
          target_addr[rs_inf_update_ins] <= ls_ins_rs1 + ls_addr_offset;
          data[rs_inf_update_ins] <= store_ins_rs2;
        end else begin
          store_finish <= 0;
        end
        if (lsb_update_flag) begin
          if (tail >= head) begin
            for (i = 0; i < LSBSIZE; i = i + 1) begin
              if (i >= head && i < tail) begin
                if (rob_rnm[i] == lsb_commit_rename && !load_not_store[i])
                  status[i] <= WAITING;  //Store指令被提交
              end
            end
          end else begin
            for (i = 0; i < LSBSIZE; i = i + 1) begin
              if (i >= head || i < tail) begin
                if (rob_rnm[i] == lsb_commit_rename && !load_not_store[i])
                  status[i] <= WAITING;  //Store指令被提交
              end
            end
          end
        end
        if (head != tail && status[head] == WAITING) begin
          if (lsb_enable) begin
            status[head] <= EXEC;
            if (load_not_store[head]) begin
              lsb_flag <= 1;
              lsb_r_nw <= 1;
              data_size_to_mc <= data_size[head];
              data_addr <= target_addr[head];
              load_sign <= signed_not_unsigned[head];
            end else begin
              lsb_flag <= 1;
              lsb_r_nw <= 0;
              data_size_to_mc <= data_size[head];
              data_addr <= target_addr[head];
              data_write <= data[head];
            end
          end
        end else begin
          lsb_flag <= 0;
        end
        if (data_rdy && status[head] == EXEC) begin
          status[head] <= FINISH;
          head <= (head + 1) % LSBSIZE;
          if (load_not_store[head]) begin
            load_finish <= 1;
            load_finish_rename <= rob_rnm[head];
            ld_data <= data_read;
          end else begin
            load_finish <= 0;
          end
        end else begin
          load_finish <= 0;
        end
        if (head != tail && status[head] == WRONG) begin
          head <= (head + 1) % LSBSIZE;
        end
      end
    end
  end


endmodule  //load_store_buffer
