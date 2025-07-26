`timescale 1 ns / 1 ps

module Mux(
    input  logic         clock_i,
    input  logic  [4:0]  select_data_i,
    input logic   [63:0] wave_reg_i [0:23],
    input logic   [63:0] ad_reg_i,
    output logic [63 : 0] data_o
);

  logic [63:0] wire_s;



  always_ff @(posedge clock_i) begin
    if (select_data_i == 5'b00000) begin
        wire_s = ad_reg_i;
    end 
    else begin
    wire_s = wave_reg_i[select_data_i];
    end 
  end
  assign data_o = wire_s;

endmodule : Mux
