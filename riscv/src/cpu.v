// RISCV32I CPU top module
// port modification allowed for debugging purposes
//`include "memory_controller.v"
//`include "i_cache.v"
//`include "instruction_fetcher.v"
//`include "predictor.v"
//`include "reorder_buffer.v"
//`include "reservation_station.v"
//`include "load_store_buffer.v"
//`include "register.v"
//`include "cdb.v"
//`include "alu.v"

module cpu (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,   // data input bus
    output wire [ 7:0] mem_dout,  // data output bus
    output wire [31:0] mem_a,     // address bus (only 17:0 is used)
    output wire        mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    output wire [31:0] dbgreg_dout  // cpu register output (debugging demo)
);

  // implementation goes here

  // Specifications:
  // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
  // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
  // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
  // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
  // - 0x30000 read: read a byte from input
  // - 0x30000 write: write a byte to output (write 0x00 is ignored)
  // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
  // - 0x30004 write: indicates program stop (will output '\0' through uart tx)
  wire ic_mc_ic_flag;
  wire [31:0] ic_mc_ins_addr;
  wire mc_ic_ic_enable;
  wire [31:0] mc_ic_ins;
  wire mc_ic_ins_rdy;

  wire lsb_mc_lsb_flag;
  wire lsb_mc_lsb_r_nw;
  wire lsb_mc_load_sign;
  wire [1:0] lsb_mc_data_size;
  wire [31:0] lsb_mc_data_addr;
  wire [31:0] lsb_mc_data_write;
  wire [31:0] mc_lsb_data_read;
  wire mc_lsb_lsb_enable;
  wire mc_lsb_data_rdy;

  wire [31:0] if_ic_if_ins_addr;
  wire if_ic_if_ins_asked;
  wire ic_if_if_ins_rdy;
  wire [31:0] ic_if_if_ins;

  wire if_pre_ask_predictor;
  wire [31:0] if_pre_ask_ins_addr;
  wire [31:0] if_pre_jump_addr;
  wire [31:0] if_pre_next_addr;
  wire pre_if_jump;
  wire pre_if_predictor_sgn_rdy;
  wire pre_if_predictor_full;
  wire pre_if_if_flush;
  wire [31:0] pre_if_addr_from_predictor;

  wire cdb_if_jalr_commit;
  wire [31:0] cdb_if_jalr_addr;

  wire rob_if_rob_full;
  wire if_rob_if_ins_launch_flag;
  wire [31:0] if_rob_if_ins;
  wire [31:0] if_rob_if_ins_pc;

  wire pre_lsb_lsb_flush;

  wire pre_rob_rob_flush;

  wire pre_rs_rs_flush;

  wire pre_reg_register_flush;

  wire pre_cdb_cdb_flush;
  wire cdb_pre_branch_commit;
  wire cdb_pre_branch_jump;

  wire rob_lsb_new_ls_ins_flag;
  wire [3:0] rob_lsb_new_ls_ins_rnm;
  wire lsb_rob_load_finish;
  wire [3:0] lsb_rob_load_finish_rename;
  wire [31:0] lsb_rob_ld_data;
  wire lsb_rob_store_finish;
  wire [3:0] lsb_rob_store_finish_rename;

  wire lsb_rs_new_ins_flag;
  wire [31:0] lsb_rs_new_ins;
  wire [3:0] lsb_rs_rename;
  wire [4:0] lsb_rs_rename_reg;

  wire alu1_rob_alu1_finish;
  wire [3:0] alu1_rob_alu1_dest;
  wire [31:0] alu1_rob_alu1_out;

  wire alu2_rob_alu2_finish;
  wire [3:0] alu2_rob_alu2_dest;
  wire [31:0] alu2_rob_alu2_out;

  wire rob_cdb_commit_flag;
  wire [31:0] rob_cdb_commit_value;
  wire [3:0] rob_cdb_commit_rename;
  wire [4:0] rob_cdb_commit_dest;
  wire rob_cdb_commit_is_jalr;
  wire [31:0] rob_cdb_jalr_next_pc;
  wire rob_cdb_commit_is_branch;
  wire rob_cdb_commit_is_store;

  wire reg_rs_rename_finish;
  wire [3:0] reg_rs_rename_finish_id;
  wire reg_rs_operand_1_busy;
  wire reg_rs_operand_2_busy;
  wire [3:0] reg_rs_operand_1_rename;
  wire [3:0] reg_rs_operand_2_rename;
  wire [31:0] reg_rs_operand_1_data_from_reg;
  wire [31:0] reg_rs_operand_2_data_from_reg;
  wire rs_reg_rename_need;
  wire [3:0] rs_reg_rename_need_id;
  wire rs_reg_operand_1_flag;
  wire rs_reg_operand_2_flag;
  wire [4:0] rs_reg_operand_1_reg;
  wire [4:0] rs_reg_operand_2_reg;
  wire [3:0] rs_reg_new_ins_rd_rename;
  wire [4:0] rs_reg_new_ins_rd;
  wire rs_reg_rename_need_ins_is_simple;
  wire rs_reg_rename_need_ins_is_branch_or_store;

  wire cdb_rs_rs_update_flag;
  wire [3:0] cdb_rs_rs_commit_rename;
  wire [31:0] cdb_rs_rs_value;

  wire rs_lsb_ls_mission;
  wire [3:0] rs_lsb_ls_ins_rnm;
  wire [5:0] rs_lsb_ls_op_type;
  wire [31:0] rs_lsb_ls_addr_offset;
  wire [31:0] rs_lsb_ls_ins_rs1;
  wire [31:0] rs_lsb_store_ins_rs2;

  wire rs_alu1_alu1_mission;
  wire [5:0] rs_alu1_alu1_op_type;
  wire [31:0] rs_alu1_alu1_rs1;
  wire [31:0] rs_alu1_alu1_rs2;
  wire [3:0] rs_alu1_alu1_rob_dest;
  wire rs_alu2_alu2_mission;
  wire [5:0] rs_alu2_alu2_op_type;
  wire [31:0] rs_alu2_alu2_rs1;
  wire [31:0] rs_alu2_alu2_rs2;
  wire [3:0] rs_alu2_alu2_rob_dest;

  wire cdb_lsb_lsb_update_flag;
  wire [3:0] cdb_lsb_lsb_commit_rename;

  wire cdb_reg_register_update_flag;
  wire [4:0] cdb_reg_register_commit_dest;
  wire [31:0] cdb_reg_register_commit_value;
  wire [3:0] cdb_reg_rename_of_commit_ins;

  wire lsb_if_lsb_full;

  wire reg_rob_simple_ins_commit;
  wire [3:0] reg_rob_simple_ins_rename;

  memory_controller MC (
      .clk(clk_in),
      .rst(rst_in),
      .rdy(rdy_in),
      .mem_in(mem_din),
      .mem_write(mem_dout),
      .addr(mem_a),
      .w_nr_out(mem_wr),
      .io_buffer_full(io_buffer_full),
      .ic_flag(ic_mc_ic_flag),
      .ins_addr(ic_mc_ins_addr),
      .ic_enable(mc_ic_ic_enable),
      .ins(mc_ic_ins),
      .ins_rdy(mc_ic_ins_rdy),
      .lsb_flag(lsb_mc_lsb_flag),
      .lsb_r_nw(lsb_mc_lsb_r_nw),
      .load_sign(lsb_mc_load_sign),
      .data_size(lsb_mc_data_size),
      .data_addr(lsb_mc_data_addr),
      .data_write(lsb_mc_data_write),
      .data_read(mc_lsb_data_read),
      .lsb_enable(mc_lsb_lsb_enable),
      .data_rdy(mc_lsb_data_rdy)
  );

  i_cache IC (
      .clk(clk_in),
      .rst(rst_in),
      .rdy(rdy_in),
      .mc_ins_asked(ic_mc_ic_flag),
      .mc_ins_addr(ic_mc_ins_addr),
      .mc_ins_rdy(mc_ic_ins_rdy),
      .mc_ins(mc_ic_ins),
      .ic_enable(mc_ic_ic_enable),
      .if_ins_addr(if_ic_if_ins_addr),
      .if_ins_asked(if_ic_if_ins_asked),
      .if_ins_rdy(ic_if_if_ins_rdy),
      .if_ins(ic_if_if_ins)
  );

  instruction_fetcher IF (
      .clk(clk_in),
      .rst(rst_in),
      .rdy(rdy_in),
      .ic_rdy(ic_if_if_ins_rdy),
      .ins(ic_if_if_ins),
      .ins_asked(if_ic_if_ins_asked),
      .ins_addr(if_ic_if_ins_addr),
      //pre
      .ask_predictor(if_pre_ask_predictor),
      .ask_ins_addr(if_pre_ask_ins_addr),
      .jump_addr(if_pre_jump_addr),
      .next_addr(if_pre_next_addr),
      .jump(pre_if_jump),
      .predictor_sgn_rdy(pre_if_predictor_sgn_rdy),
      .predictor_full(pre_if_predictor_full),
      .if_flush(pre_if_if_flush),
      .addr_from_predictor(pre_if_addr_from_predictor),
      //cdb
      .jalr_commit(cdb_if_jalr_commit),
      .jalr_addr(cdb_if_jalr_addr),
      //lsb
      .lsb_full(lsb_if_lsb_full),
      //rob
      .rob_full(rob_if_rob_full),
      .if_ins_launch_flag(if_rob_if_ins_launch_flag),
      .if_ins(if_rob_if_ins),
      .if_ins_pc(if_rob_if_ins_pc)
  );

  predictor Predictor (
      .clk(clk_in),
      .rst(rst_in),
      .rdy(rdy_in),
      //if
      .ask_predictor(if_pre_ask_predictor),
      .now_ins_addr(if_pre_ask_ins_addr),
      .jump_addr_from_if(if_pre_jump_addr),
      .next_addr_from_if(if_pre_next_addr),
      .jump(pre_if_jump),
      .predictor_sgn_rdy(pre_if_predictor_sgn_rdy),
      .predictor_full(pre_if_predictor_full),
      .if_flush(pre_if_if_flush),
      .addr_to_if(pre_if_addr_from_predictor),
      //lsb
      .lsb_flush(pre_lsb_lsb_flush),
      //rob
      .rob_flush(pre_rob_rob_flush),
      //rs
      .rs_flush(pre_rs_rs_flush),
      //register
      .register_flush(pre_reg_register_flush),
      //cdb
      .cdb_flush(pre_cdb_cdb_flush),
      .branch_commit(cdb_pre_branch_commit),
      .branch_jump(cdb_pre_branch_jump)
  );

  reorder_buffer ROB (
      .clk(clk_in),
      .rst(rst_in),
      .rdy(rdy_in),
      //if
      .if_ins_launch_flag(if_rob_if_ins_launch_flag),
      .if_ins(if_rob_if_ins),
      .if_ins_pc(if_rob_if_ins_pc),
      .rob_full(rob_if_rob_full),
      //lsb
      .new_ls_ins_flag(rob_lsb_new_ls_ins_flag),
      .new_ls_ins_rnm(rob_lsb_new_ls_ins_rnm),
      .load_finish(lsb_rob_load_finish),
      .load_finish_rename(lsb_rob_load_finish_rename),
      .ld_data(lsb_rob_ld_data),
      .store_finish(lsb_rob_store_finish),
      .store_finish_rename(lsb_rob_store_finish_rename),
      //rs
      .new_ins_flag(lsb_rs_new_ins_flag),
      .new_ins(lsb_rs_new_ins),
      .rename(lsb_rs_rename),
      .rename_reg(lsb_rs_rename_reg),
      //reg
      .simple_ins_commit(reg_rob_simple_ins_commit),
      .simple_ins_commit_rename(reg_rob_simple_ins_rename),
      //alu1
      .alu1_finish(alu1_rob_alu1_finish),
      .alu1_dest(alu1_rob_alu1_dest),
      .alu1_out(alu1_rob_alu1_out),
      //alu2
      .alu2_finish(alu2_rob_alu2_finish),
      .alu2_dest(alu2_rob_alu2_dest),
      .alu2_out(alu2_rob_alu2_out),
      //pre
      .rob_flush(pre_rob_rob_flush),
      //cdb
      .commit_flag(rob_cdb_commit_flag),
      .commit_value(rob_cdb_commit_value),
      .commit_rename(rob_cdb_commit_rename),
      .commit_dest(rob_cdb_commit_dest),
      .commit_is_jalr(rob_cdb_commit_is_jalr),
      .jalr_next_pc(rob_cdb_jalr_next_pc),
      .commit_is_branch(rob_cdb_commit_is_branch),
      .commit_is_store(rob_cdb_commit_is_store)
  );
  reservation_station RS (
      .clk(clk_in),
      .rst(rst_in),
      .rdy(rdy_in),
      //rob
      .new_ins_flag(lsb_rs_new_ins_flag),
      .new_ins(lsb_rs_new_ins),
      .rename(lsb_rs_rename),
      .rename_reg(lsb_rs_rename_reg),
      //register
      .rename_finish(reg_rs_rename_finish),
      .rename_finish_id(reg_rs_rename_finish_id),
      .operand_1_busy(reg_rs_operand_1_busy),
      .operand_2_busy(reg_rs_operand_2_busy),
      .operand_1_rename(reg_rs_operand_1_rename),
      .operand_2_rename(reg_rs_operand_2_rename),
      .operand_1_data_from_reg(reg_rs_operand_1_data_from_reg),
      .operand_2_data_from_reg(reg_rs_operand_2_data_from_reg),
      .rename_need(rs_reg_rename_need),
      .rename_need_ins_is_simple(rs_reg_rename_need_ins_is_simple),
      .rename_need_ins_is_branch_or_store(rs_reg_rename_need_ins_is_branch_or_store),
      .rename_need_id(rs_reg_rename_need_id),
      .operand_1_flag(rs_reg_operand_1_flag),
      .operand_2_flag(rs_reg_operand_2_flag),
      .operand_1_reg(rs_reg_operand_1_reg),
      .operand_2_reg(rs_reg_operand_2_reg),
      .new_ins_rd_rename(rs_reg_new_ins_rd_rename),
      .new_ins_rd(rs_reg_new_ins_rd),
      //cdb
      .rs_update_flag(cdb_rs_rs_update_flag),
      .rs_commit_rename(cdb_rs_rs_commit_rename),
      .rs_value(cdb_rs_rs_value),
      //pre
      .rs_flush(pre_rs_rs_flush),
      //lsb
      .ls_mission(rs_lsb_ls_mission),
      .ls_ins_rnm(rs_lsb_ls_ins_rnm),
      .ls_op_type(rs_lsb_ls_op_type),
      .ls_addr_offset(rs_lsb_ls_addr_offset),
      .ls_ins_rs1(rs_lsb_ls_ins_rs1),
      .store_ins_rs2(rs_lsb_store_ins_rs2),
      //alu1
      .alu1_mission(rs_alu1_alu1_mission),
      .alu1_op_type(rs_alu1_alu1_op_type),
      .alu1_rs1(rs_alu1_alu1_rs1),
      .alu1_rs2(rs_alu1_alu1_rs2),
      .alu1_rob_dest(rs_alu1_alu1_rob_dest),
      //alu2
      .alu2_mission(rs_alu2_alu2_mission),
      .alu2_op_type(rs_alu2_alu2_op_type),
      .alu2_rs1(rs_alu2_alu2_rs1),
      .alu2_rs2(rs_alu2_alu2_rs2),
      .alu2_rob_dest(rs_alu2_alu2_rob_dest)
  );
  load_store_buffer LSB (
      .clk(clk_in),
      .rst(rst_in),
      .rdy(rdy_in),
      //rob
      .new_ls_ins_flag(rob_lsb_new_ls_ins_flag),
      .new_ls_ins_rnm(rob_lsb_new_ls_ins_rnm),
      .load_finish(lsb_rob_load_finish),
      .load_finish_rename(lsb_rob_load_finish_rename),
      .ld_data(lsb_rob_ld_data),
      .store_finish(lsb_rob_store_finish),
      .store_finish_rename(lsb_rob_store_finish_rename),
      //rs
      .ls_mission(rs_lsb_ls_mission),
      .ls_ins_rnm(rs_lsb_ls_ins_rnm),
      .ls_op_type(rs_lsb_ls_op_type),
      .ls_addr_offset(rs_lsb_ls_addr_offset),
      .ls_ins_rs1(rs_lsb_ls_ins_rs1),
      .store_ins_rs2(rs_lsb_store_ins_rs2),
      //cdb
      .lsb_update_flag(cdb_lsb_lsb_update_flag),
      .lsb_commit_rename(cdb_lsb_lsb_commit_rename),
      //pre
      .lsb_flush(pre_lsb_lsb_flush),
      //if
      .lsb_full(lsb_if_lsb_full),
      //MC
      .lsb_flag(lsb_mc_lsb_flag),
      .lsb_r_nw(lsb_mc_lsb_r_nw),
      .load_sign(lsb_mc_load_sign),
      .data_size_to_mc(lsb_mc_data_size),
      .data_addr(lsb_mc_data_addr),
      .data_write(lsb_mc_data_write),
      .data_read(mc_lsb_data_read),
      .lsb_enable(mc_lsb_lsb_enable),
      .data_rdy(mc_lsb_data_rdy)
  );
  register REG (
      .clk(clk_in),
      .rst(rst_in),
      .rdy(rdy_in),
      //cdb
      .register_update_flag(cdb_reg_register_update_flag),
      .register_commit_dest(cdb_reg_register_commit_dest),
      .register_commit_value(cdb_reg_register_commit_value),
      .rename_of_commit_ins(cdb_reg_rename_of_commit_ins),
      //pre
      .register_flush(pre_reg_register_flush),
      //rob
      .simple_ins_commit(reg_rob_simple_ins_commit),
      .simple_ins_rename(reg_rob_simple_ins_rename),
      //rs
      .rename_finish_id(reg_rs_rename_finish_id),
      .operand_1_busy(reg_rs_operand_1_busy),
      .operand_2_busy(reg_rs_operand_2_busy),
      .operand_1_rename(reg_rs_operand_1_rename),
      .operand_2_rename(reg_rs_operand_2_rename),
      .operand_1_data_from_reg(reg_rs_operand_1_data_from_reg),
      .operand_2_data_from_reg(reg_rs_operand_2_data_from_reg),
      .rename_finish(reg_rs_rename_finish),
      .rename_need(rs_reg_rename_need),
      .rename_need_ins_is_simple(rs_reg_rename_need_ins_is_simple),
      .rename_need_ins_is_branch_or_store(rs_reg_rename_need_ins_is_branch_or_store),
      .rename_need_id(rs_reg_rename_need_id),
      .operand_1_flag(rs_reg_operand_1_flag),
      .operand_2_flag(rs_reg_operand_2_flag),
      .operand_1_reg(rs_reg_operand_1_reg),
      .operand_2_reg(rs_reg_operand_2_reg),
      .new_ins_rd_rename(rs_reg_new_ins_rd_rename),
      .new_ins_rd(rs_reg_new_ins_rd)
  );
  cdb CDB (
      .clk(clk_in),
      .rst(rst_in),
      .rdy(rdy_in),
      //rob
      .commit_flag(rob_cdb_commit_flag),
      .commit_value(rob_cdb_commit_value),
      .commit_rename(rob_cdb_commit_rename),
      .commit_dest(rob_cdb_commit_dest),
      .commit_is_jalr(rob_cdb_commit_is_jalr),
      .jalr_next_pc(rob_cdb_jalr_next_pc),
      .commit_is_branch(rob_cdb_commit_is_branch),
      .commit_is_store(rob_cdb_commit_is_store),
      //rs
      .rs_update_flag(cdb_rs_rs_update_flag),
      .rs_commit_rename(cdb_rs_rs_commit_rename),
      .rs_value(cdb_rs_rs_value),
      //register
      .register_update_flag(cdb_reg_register_update_flag),
      .register_commit_dest(cdb_reg_register_commit_dest),
      .register_value(cdb_reg_register_commit_value),
      .rename_sent_to_register(cdb_reg_rename_of_commit_ins),
      //predictor
      .cdb_flush(pre_cdb_cdb_flush),
      .branch_commit(cdb_pre_branch_commit),
      .branch_jump(cdb_pre_branch_jump),
      //if
      .jalr_commit(cdb_if_jalr_commit),
      .jalr_addr(cdb_if_jalr_addr),
      //lsb
      .lsb_update_flag(cdb_lsb_lsb_update_flag),
      .lsb_commit_rename(cdb_lsb_lsb_commit_rename)
  );

  alu ALU1(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    //rs
    .alu_mission(rs_alu1_alu1_mission),
    .alu_op_type(rs_alu1_alu1_op_type),
    .alu_rs1(rs_alu1_alu1_rs1),
    .alu_rs2(rs_alu1_alu1_rs2),
    .alu_rob_dest(rs_alu1_alu1_rob_dest),
    //rob
    .alu_finish(alu1_rob_alu1_finish),
    .dest(alu1_rob_alu1_dest),
    .alu_out(alu1_rob_alu1_out)
  );
  alu ALU2(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    //rs
    .alu_mission(rs_alu2_alu2_mission),
    .alu_op_type(rs_alu2_alu2_op_type),
    .alu_rs1(rs_alu2_alu2_rs1),
    .alu_rs2(rs_alu2_alu2_rs2),
    .alu_rob_dest(rs_alu2_alu2_rob_dest),
    //rob
    .alu_finish(alu2_rob_alu2_finish),
    .dest(alu2_rob_alu2_dest),
    .alu_out(alu2_rob_alu2_out)
  );

endmodule
