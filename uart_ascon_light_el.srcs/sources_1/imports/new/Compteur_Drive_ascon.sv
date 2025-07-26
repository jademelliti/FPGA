`timescale 1 ns / 1 ps

module Compteur_Drive_ascon
  import ascon_pack::*;
(
    input  logic         clock_i,
    input  logic         en_cpt_mux_i,
    input  logic         init_cpt_mux_i,
    output logic [4 : 0] data_o
);

  logic [4:0] cpt_s;

  always_ff @(posedge clock_i) begin
    if (init_cpt_mux_i == 1'b1) begin
      cpt_s <= 0;
    end else begin
      if (en_cpt_mux_i == 1'b1) begin
        cpt_s <= cpt_s + 1;
      end
    end
  end

  assign data_o = cpt_s;

endmodule : Compteur_Drive_ascon
