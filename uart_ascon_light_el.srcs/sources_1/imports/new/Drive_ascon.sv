`timescale 1ns / 1ps

import ascon_pack::*;

module Drive_ascon (

    input  logic         clock_i,
    input  logic         reset_i,
    input  logic         start_i,
    input  logic         end_initialisation_i,
    input  logic         end_associate_i,
    input  logic         end_cipher_i,
    input  logic         end_tag_i,
    input  logic [4:0]   cpt_mux_i,
    input logic          cipher_valid_i,
    
    
    
    output logic         start_ascon_o,
    output logic         associate_data_o,
    output logic         finalisation_o,
    output logic         data_valid_o,
    output logic         init_cpt_mux_o,
    output logic         en_cpt_mux_o,
    output logic         en_reg_ascon_o
    
);

logic [4:0] reg_cpt_s = 5'b00001; 


typedef enum {
    idle,
    b_init,
    init,
    b_da,
    da,
    act_cpt_cipher,
    b_cipher,
    cipher,
    cipher_val_reg,
    round_cipher,
    b_finalisation,
    finalisation,
    a_finalisation,
    b_restart
  } State_t;
  
  State_t Etat_p, Etat_f;
  
  
  always_ff @(posedge clock_i, posedge reset_i) begin
    if (reset_i == 1'b1) begin
      Etat_p <= idle;
    end else begin
      Etat_p <= Etat_f;
    end
  end
    
    always_comb begin
        case (Etat_p)
            idle:
                if(start_i == 1'b1) Etat_f = b_init;
                else Etat_f = idle;
            b_init:
                Etat_f = init;
            init:
                if(end_initialisation_i == 1'b1) Etat_f = b_da;
                else Etat_f = init;
            b_da:
                Etat_f = da;
            da:
                if(end_associate_i == 1'b1) Etat_f = act_cpt_cipher;
                else Etat_f = da;
            act_cpt_cipher:
                if (cpt_mux_i == 5'b10110) begin
                    Etat_f = cipher;
                end else begin
                    Etat_f = b_cipher;
                end
            b_cipher:
                Etat_f = cipher;
            cipher:
                if (end_cipher_i == 1'b1) begin
                    Etat_f = b_finalisation;
                end else if (cipher_valid_i == 1'b1) begin
                    Etat_f = cipher_val_reg;
                end else begin
                    Etat_f = cipher;
                end
            cipher_val_reg:
                Etat_f = round_cipher;
            round_cipher:
                if(end_cipher_i == 1'b1) Etat_f = act_cpt_cipher;
                else Etat_f = round_cipher;
            b_finalisation:
                Etat_f = finalisation;
            finalisation:
                if (end_tag_i == 1'b1) begin
                    Etat_f = a_finalisation;
                end else begin
                    Etat_f = finalisation;
                end
            a_finalisation:
                Etat_f = b_restart;
            b_restart:
                if (start_i == 1'b1) begin
                    Etat_f = b_restart;
                end else begin
                    Etat_f = idle;
                end
            default: Etat_f = idle;
        endcase
    end

    always_comb begin
    case (Etat_p)
    
      idle: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      b_init: begin
        start_ascon_o     = 1'b1;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      init: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b1;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      b_da: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b1;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b1;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      da: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      act_cpt_cipher: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b1;
        en_reg_ascon_o    = 1'b0;
      end
      
      b_cipher: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b1;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      round_cipher: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      cipher: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      
      cipher_val_reg: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b1;
      end
      
       b_finalisation: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b1;
        data_valid_o      = 1'b1;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      finalisation: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      a_finalisation: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b1;
      end
      
      b_restart: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
      default: begin
        start_ascon_o     = 1'b0;
        associate_data_o  = 1'b0;
        finalisation_o    = 1'b0;
        data_valid_o      = 1'b0;
        init_cpt_mux_o    = 1'b0;
        en_cpt_mux_o      = 1'b0;
        en_reg_ascon_o    = 1'b0;
      end
      
    endcase
  end

endmodule : Drive_ascon