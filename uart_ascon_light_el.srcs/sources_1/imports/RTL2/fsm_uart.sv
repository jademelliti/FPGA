`timescale 1ns / 1ps

module fsm_uart
  import uart_pkg::*;
(
    input  logic          clock_i,
    input  logic          resetb_i,
    input  logic          RXErr_i,
    input  logic          RXRdy_i,
    input  logic          TxBusy_i,
    input  logic [   7:0] RxData_i,       //byte received by uart
    input  logic [ 127:0] Tag_i,          //tag to send
    input  logic [1471:0] Cipher_i,       //cipher to send
    input  logic          CipherRdy_i,    //end ascon computation
    output logic [   7:0] TxByte_o,       //byte to send by uart
    output logic [ 127:0] Key_o,
    output logic [ 127:0] Nonce_o,
    output logic [  63:0] Ad_o,
    output logic [1471:0] Wave_o,
    output logic          Start_ascon_o,
    output logic          Load_o          //load signal for byte transmission
);

  //internal signals for key_reg
  logic [7:0] key_reg_s;
  logic init_key_s;
  logic en_key_s;

  //internal signals for nonce_reg
  logic [7:0] nonce_reg_s;
  logic init_nonce_s;
  logic en_nonce_s;

  //internal signals for ad_reg
  logic [7:0] ad_reg_s;
  logic init_ad_s;
  logic en_ad_s;

  //internal signals for wave_reg
  logic [7:0] wave_reg_s;
  logic init_wave_s;
  logic en_wave_s;

  //internal signals for cipher_reg
  logic [7:0] cipher_reg_o_s;
  logic init_cipher_s;
  logic en_cipher_s;

  //internal signals for tag_reg
  logic [7:0] tag_reg_o_s;
  logic init_tag_s;
  logic en_tag_s;

  //internal signals for fsm_dcounter
  logic [8:0] cpt_s;
  logic en_cpt_s;
  logic init_c8_s;
  logic init_c17_s;
  logic init_c16_s;
  logic init_c185_s;
  logic init_c184_s;

  //internal signals for trans_receive
  logic [7:0] data_converted_s;
  logic en_trans_s;

  typedef enum {
    init,
    idle_cmd,
    get_cmd,
    init_key,  //key
    idle_key0,
    idle_key1,
    get_key0,
    get_key1,
    flush_key,
    init_nonce,  //nonce
    idle_nonce0,
    idle_nonce1,
    get_nonce0,
    get_nonce1,
    flush_nonce,
    //add states to parse associate data 
    //ajout de la commande A: A + 8 octets
    
    init_da,  //da
    idle_da0,
    idle_da1,
    get_da0,
    get_da1,
    flush_da,
    //add states to parse ecg wave
    init_w,  //w
    idle_w0,
    idle_w1,
    get_w0,
    get_w1,
    flush_w,
    
    init_tag,
    send_tag0,
    send_tag1, 
    update_tag,
    flush_tag,
    
    init_cipher,
    send_cipher0,
    send_cipher1, 
    update_cipher,
    flush_cipher,
    
    
    
    //start ascon cipher GO 
    start_ascon,
    wait_end_ascon,
    
    starto,  //letter O
    sendo,
    startk,  //letter K
    sendk,
    startlf,  //Line Field
    sendlf
  } state_t;

  state_t etat_p;
  state_t etat_f;

  key_reg key_reg_0 (
      .clock_i(clock_i),
      .resetb_i(resetb_i),
      .data_i(key_reg_s),
      .en_i(en_key_s),
      .init_i(init_key_s),
      .key_o(Key_o)
  );

  nonce_reg nonce_reg_0 (
      .clock_i(clock_i),
      .resetb_i(resetb_i),
      .data_i(nonce_reg_s),
      .en_i(en_nonce_s),
      .init_i(init_nonce_s),
      .nonce_o(Nonce_o)
  );

//add register to store associated data 
   ad_reg ad_reg_a_0 (
      .clock_i(clock_i),   //main clock
      .resetb_i(resetb_i),  //asynchronous reset active low
      .data_i(ad_reg_s),
      .en_i(en_ad_s),
      .init_i(init_ad_s),
      .ad_o(Ad_o) 
   );
//add register to stare the plain ECG wave

    wave_reg wave_reg_0 (
        .clock_i(clock_i),   //main clock
        .resetb_i(resetb_i),  //asynchronous reset active low
        .data_i(wave_reg_s),
        .en_i(en_wave_s),
        .init_i(init_wave_s),
        .wave_o(Wave_o)
    
    ) ;
    
  cipher_reg cipher_reg_0 (
      .clock_i(clock_i),
      .resetb_i(resetb_i),
      .cipher_i(Cipher_i),
      .en_i(en_cipher_s),
      .init_i(init_cipher_s),
      .data_o(cipher_reg_o_s)
  );

//add the register that send the tag
  
  tag_reg tag_reg_0 (
      .clock_i(clock_i),   //main clock
      .resetb_i(resetb_i),  //asynchronous reset active low
      .tag_i(Tag_i),
      .en_i(en_tag_s),
      .init_i(init_tag_s),
      .data_o (tag_reg_o_s)
   );


  fsm_dcounter fsm_dcounter_0 (
      .clock_i(clock_i),
      .resetb_i(resetb_i),
      .en_i(en_cpt_s),
      .init_c8_i(init_c8_s),
      .init_c17_i(init_c17_s),
      .init_c16_i(init_c16_s),
      .init_c185_i(init_c185_s),
      .init_c184_i(init_c184_s),
      .cpt_o(cpt_s)
  );

  trans_receive trans_receive_0 (
      .clock_i(clock_i),
      .resetb_i(resetb_i),
      .RxData_i(RxData_i),
      .en_i(en_trans_s),
      .data_converted_o(data_converted_s)
  );

  always_ff @(posedge clock_i, negedge resetb_i) begin : seq_0
    if (resetb_i == 1'b0) begin
      etat_p <= init;
    end else begin
      etat_p <= etat_f;
    end
  end : seq_0

  always_comb begin : comb_0
    case (etat_p)
      init: etat_f = idle_cmd;
      idle_cmd:
      if (RXRdy_i == 1'b1) begin
        etat_f = get_cmd;
      end else begin
        etat_f = idle_cmd;
      end
      get_cmd:
      if (TxBusy_i == 1'b0) begin
        case (RxData_i)
          8'h4B:   etat_f = init_key;  //K
          8'h6B:   etat_f = init_key;  //k
          //ascii code for associate data command
          8'h41:   etat_f = init_da;
          8'h61:   etat_f = init_da;
          //ascii code for ecg wave command
          8'h57:   etat_f = init_w;
          8'h77:   etat_f = init_w;
          // T
          8'h54:   etat_f = init_tag;
          8'h74:   etat_f = init_tag;
          //// C
          8'h43:   etat_f = init_cipher;
          8'h63:   etat_f = init_cipher;
          8'h4E:   etat_f = init_nonce;  //N
          8'h6E:   etat_f = init_nonce;  //n
          8'h47:   etat_f = start_ascon;  //G
          8'h67:   etat_f = start_ascon;  //g

          default: etat_f = idle_cmd;
        endcase
      end else begin
        etat_f = idle_cmd;
      end
      // Write key
      init_key: etat_f = idle_key0;
      idle_key0:
      if (RXRdy_i == 1'b1) begin
        etat_f = idle_key1;
      end else begin
        etat_f = idle_key0;
      end
      idle_key1: etat_f = get_key0;
      get_key0: etat_f = get_key1;
      get_key1:
      if (TxBusy_i == 1'b0) begin
        if (cpt_s == 9'h1) begin
          etat_f = flush_key;
        end else begin
          etat_f = idle_key0;
        end
      end else begin
        etat_f = idle_cmd;
      end
      flush_key: etat_f = starto;
      // Write nonce
      init_nonce: etat_f = idle_nonce0;
      idle_nonce0:
      if (RXRdy_i == 1'b1) begin
        etat_f = idle_nonce1;
      end else begin
        etat_f = idle_nonce0;
      end
      idle_nonce1: etat_f = get_nonce0;
      get_nonce0: etat_f = get_nonce1;
      get_nonce1:
      if (TxBusy_i == 1'b0) begin
        if (cpt_s == 9'h1) begin
          etat_f = flush_nonce;
        end else begin
          etat_f = idle_nonce0;
        end
      end else begin
        etat_f = idle_cmd;
      end
      flush_nonce: etat_f = starto;
      
      // Write ad
      init_da: etat_f = idle_da0; 
      idle_da0:
      if (RXRdy_i == 1'b1) begin
        etat_f = idle_da1;
      end else begin
        etat_f = idle_da0;
      end
      idle_da1: etat_f = get_da0;
      get_da0: etat_f = get_da1;
      get_da1:
      if (TxBusy_i == 1'b0) begin
        if (cpt_s == 9'h1) begin
          etat_f = flush_da;
        end else begin
          etat_f = idle_da0;
        end
      end else begin
        etat_f = idle_cmd;
      end
      flush_da: etat_f = starto; 
      
      // Write wave
    init_w: etat_f = idle_w0; 
      idle_w0:
      if (RXRdy_i == 1'b1) begin
        etat_f = idle_w1;
      end else begin
        etat_f = idle_w0;
      end
      idle_w1: etat_f = get_w0;
      get_w0: etat_f = get_w1;
      get_w1:
      if (TxBusy_i == 1'b0) begin
        if (cpt_s == 9'h1) begin
          etat_f = flush_w;
        end else begin
          etat_f = idle_w0;
        end
      end else begin
        etat_f = idle_cmd;
      end
      flush_w: etat_f = starto; 
      
      //init Ascon
      start_ascon: etat_f = wait_end_ascon;
      wait_end_ascon:
      if (CipherRdy_i == 1'b1) begin
        etat_f = starto;
      end else begin
        etat_f = wait_end_ascon;
      end
      
      
      // Send tag
    init_tag: etat_f = send_tag0;  
    send_tag0: etat_f = send_tag1;     
    send_tag1:
      if (TxBusy_i == 1'b0) begin
        if (cpt_s == 9'h1) begin
          etat_f = flush_tag;
        end else begin
          etat_f = update_tag;
        end
      end else begin
        etat_f = send_tag0;
      end
      update_tag: etat_f = send_tag0;
      flush_tag: etat_f = starto;
      
      
           // Send cipher
    init_cipher: etat_f = send_cipher0;   
    send_cipher0: etat_f = send_cipher1;   
      send_cipher1:
      if (TxBusy_i == 1'b0) begin
        if (cpt_s == 9'h1) begin
          etat_f = flush_cipher;
        end else begin
          etat_f = update_cipher;
        end
      end else begin
        etat_f = send_cipher1;
      end
      update_cipher: etat_f = send_cipher0;
      flush_cipher: etat_f = starto;
      
      
      //Respond to commands
      starto: etat_f = sendo;
      sendo:
      if (TxBusy_i == 1'b0) begin
        etat_f = startk;
      end else begin
        etat_f = sendo;
      end
      startk: etat_f = sendk;
      sendk:
      if (TxBusy_i == 1'b0) begin
        etat_f = startlf;
      end else begin
        etat_f = sendk;
      end
      startlf: etat_f = sendlf;
      sendlf:
      if (TxBusy_i == 1'b0) begin
        etat_f = idle_cmd;
      end else begin
        etat_f = sendlf;
      end
      default: etat_f = init;
    endcase
  end : comb_0

  always_comb begin : comb_1
    case (etat_p)
      init: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      idle_cmd: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      get_cmd: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      //write key
      init_key: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b1;  //
        en_key_s      = 1'b1;  //
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b1;  //
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b1;  //
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      idle_key0: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b1;  //
      end
      idle_key1: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      get_key0: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = data_converted_s;  //
        init_key_s    = 1'b0;
        en_key_s      = 1'b1;  //
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      get_key1: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b1;  //
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      flush_key: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      init_nonce: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b1;  //
        en_nonce_s    = 1'b1;  //
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b1;  //
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b1;  //
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      idle_nonce0: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b1;  //
      end
      idle_nonce1: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      get_nonce0: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = data_converted_s;  //
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b1;  //
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      get_nonce1: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b1;  //
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      flush_nonce: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      //write DA
      init_da : begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b1; //
        en_ad_s       = 1'b1; //
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b1; //
        init_c8_s    = 1'b1; //
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      idle_da0 : begin 
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b1; //
      end
      idle_da1 : begin 
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0; 
      end
      get_da0 : begin 
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = data_converted_s;
        init_ad_s     = 1'b0; 
        en_ad_s       = 1'b1; //
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      get_da1 : begin 
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0; 
        en_cpt_s      = 1'b1;//
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      flush_da : begin 
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      //write wave
      init_w: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b1; //
        en_wave_s     = 1'b1; //
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b1; //
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b1; //
        en_trans_s    = 1'b0;
      end
      idle_w0: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b1; //
      end
      idle_w1 : begin 
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      get_w0 : begin 
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = data_converted_s;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b1;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      get_w1 : begin 
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b1; //
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      flush_w : begin 
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      //go
      start_ascon: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b1;  //
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      wait_end_ascon: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      //send tag
      
      init_tag: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;  
        en_key_s      = 1'b0;  
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b1; //
        en_tag_s      = 1'b1; //
        en_cpt_s      = 1'b1;  //
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b1; //
        init_c16_s    = 1'b0;  
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      send_tag0: begin
        TxByte_o      = '0;  //
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;  //
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0; //
        en_cpt_s      = 1'b0; 
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;  
      end
      send_tag1: begin
        TxByte_o      = tag_reg_o_s; //
        Start_ascon_o = 1'b0;
        Load_o        = 1'b1; 
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0; //
        en_cpt_s      = 1'b0; //
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      update_tag: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;  
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;  
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b1; //
        en_cpt_s      = 1'b1;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      flush_tag: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end


    init_cipher: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;  
        en_key_s      = 1'b0;  
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b1; //
        en_cipher_s   = 1'b1; //
        init_tag_s    = 1'b0; 
        en_tag_s      = 1'b0; 
        en_cpt_s      = 1'b1;  //
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;  
        init_c185_s   = 1'b1; //
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      send_cipher0: begin
        TxByte_o      = '0; //
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0; //
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;  
      end
      send_cipher1: begin
        TxByte_o      = cipher_reg_o_s;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b1;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      update_cipher: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;  
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;  
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b1; //
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0; 
        en_cpt_s      = 1'b1;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      flush_cipher: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end












































      //respond to commands
      starto: begin
        TxByte_o      = 8'h4F;  //
        Start_ascon_o = 1'b0;
        Load_o        = 1'b1;  //
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      sendo: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      startk: begin
        TxByte_o      = 8'h4B;  //
        Start_ascon_o = 1'b0;
        Load_o        = 1'b1;  //
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      sendk: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      startlf: begin
        TxByte_o      = 8'h0A;  //
        Start_ascon_o = 1'b0;
        Load_o        = 1'b1;  //
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      sendlf: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
      default: begin
        TxByte_o      = '0;
        Start_ascon_o = 1'b0;
        Load_o        = 1'b0;
        key_reg_s     = '0;
        init_key_s    = 1'b0;
        en_key_s      = 1'b0;
        nonce_reg_s   = '0;
        init_nonce_s  = 1'b0;
        en_nonce_s    = 1'b0;
        ad_reg_s      = '0;
        init_ad_s     = 1'b0;
        en_ad_s       = 1'b0;
        wave_reg_s    = '0;
        init_wave_s   = 1'b0;
        en_wave_s     = 1'b0;
        init_cipher_s = 1'b0;
        en_cipher_s   = 1'b0;
        init_tag_s    = 1'b0;
        en_tag_s      = 1'b0;
        en_cpt_s      = 1'b0;
        init_c8_s    = 1'b0;
        init_c17_s    = 1'b0;
        init_c16_s    = 1'b0;
        init_c185_s   = 1'b0;
        init_c184_s   = 1'b0;
        en_trans_s    = 1'b0;
      end
    endcase
  end : comb_1
  
  
endmodule : fsm_uart

