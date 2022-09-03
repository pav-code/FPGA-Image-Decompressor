/*
Copyright by Henry Ko and Nicola Nicolici
Developed for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

`include "define_state.h"

// Inv Discrite Cosine Transform
module mil2_FSM (
    /////// board clocks                      ////////////
    input logic CLOCK_50_I,                   // 50 MHz clock
    
    input logic start,//start attempt
    
    output logic finish,
    
    
    input logic Resetn,
    input logic[3:0] PB_pushed,
    
    //sram
    output logic   [17:0]   SRAM_address,
    input  logic   [15:0]   SRAM_read_data,
    output logic            SRAM_we_n,
    output logic   [15:0]   SRAM_write_data,
    
    //multipliers
    input logic signed [63:0] a,
    input logic signed [63:0] b,
    input logic signed [63:0] c,
    input logic signed [63:0] d,

    output logic signed [31:0] op1,
    output logic signed [31:0] op2,
    output logic signed [31:0] op3,
    output logic signed [31:0] op4,		
    
    output logic signed [31:0] op5,
    output logic signed [31:0] op6,
    output logic signed [31:0] op7,
    output logic signed [31:0] op8
    
    // for DP ram testing
    //output logic [31:0] ram1_write_data_A,
    //output logic [31:0] ram1_write_data_B,		
    //output logic [6:0] ram1_address_A,
    //output logic [6:0] ram1_address_B,
    //output logic [31:0] ram1_read_data_A,
    //output logic [31:0] ram1_read_data_B
    

);
//For Ram0 - CONSTANT MATRIX
logic signed [31:0] ram0_write_data_A;
logic signed [31:0] ram0_write_data_B;
logic [6:0] ram0_address_A;
logic [6:0] ram0_address_B;
logic signed [31:0] ram0_read_data_A;
logic signed [31:0] ram0_read_data_B;
logic ram0_wren_A;
logic ram0_wren_B;
// Instantiate RAM0
 dual_port_RAM0 dual_port_RAM_inst0 (
  .address_a ( ram0_address_A ),
  .address_b ( ram0_address_B ),
  .clock ( CLOCK_50_I ),
  .data_a ( ram0_write_data_A ),
  .data_b ( ram0_write_data_B ),
  .wren_a ( ram0_wren_A ),
  .wren_b ( ram0_wren_B ),
  .q_a ( ram0_read_data_A ),
  .q_b ( ram0_read_data_B )
  );



//For Ram1 S' AND S
logic signed [31:0] ram1_write_data_A;
logic signed [31:0] ram1_write_data_B;
logic [6:0] ram1_address_A;
logic [6:0] ram1_address_B;
logic signed [31:0] ram1_read_data_A;
logic signed [31:0] ram1_read_data_B;
logic ram1_wren_A;
logic ram1_wren_B;
// Instantiate RAM1
 dual_port_RAM1 dual_port_RAM_inst1 (
  .address_a ( ram1_address_A ),
  .address_b ( ram1_address_B ),
  .clock ( CLOCK_50_I ),
  .data_a ( ram1_write_data_A ),
  .data_b ( ram1_write_data_B ),
  .wren_a ( ram1_wren_A ),
  .wren_b ( ram1_wren_B ),
  .q_a ( ram1_read_data_A ),
  .q_b ( ram1_read_data_B )
  );

//For Ram2 TEMPORARYs
logic signed [31:0] ram2_write_data_A;
logic signed [31:0] ram2_write_data_B;
logic [6:0] ram2_address_A;
logic [6:0] ram2_address_B;
logic signed [31:0] ram2_read_data_A;
logic signed [31:0] ram2_read_data_B;
logic ram2_wren_A;
logic ram2_wren_B;
// Instantiate RAM2
 dual_port_RAM2 dual_port_RAM_inst2 (
  .address_a ( ram2_address_A ),
  .address_b ( ram2_address_B ),
  .clock ( CLOCK_50_I ),
  .data_a ( ram2_write_data_A ),
  .data_b ( ram2_write_data_B ),
  .wren_a ( ram2_wren_A ),
  .wren_b ( ram2_wren_B ),
  .q_a ( ram2_read_data_A ),
  .q_b ( ram2_read_data_B )
  );	

// Define the offset for Green and Blue data in the memory		
parameter  PRE_Y_OFFSET = 18'd76800,
     PRE_U_OFFSET = 18'd153600,
     PRE_V_OFFSET = 18'd192000,

           POST_Y_OFFSET = 18'd0,
     POST_U_OFFSET = 18'd38400,
     POST_V_OFFSET = 18'd56700;

FSM2_state_type m2_state;

//**
logic [17:0] dumb_count;
logic [17:0] random_count;

logic signed [15:0] Fetch_Buf;
logic signed [15:0] Fetch_Sprime_Buf;
logic multipli_select;
logic f_cycle_active;
logic f_CxS;
logic f_fetch_box;
logic f_write_box;
logic f_CtxT_done;


logic [6:0] fetch_count;
logic [6:0] fetch_Sprime_count;
logic [6:0] const_count;
logic [6:0] T_write_count;
logic [6:0] S_write_count;
logic [6:0] S_write_count_2;
logic [7:0] read_S_addr;

logic [11:0] addr_count;
logic [2:0] x_int;
logic [11:0]	y_int,y_int1;
logic [8:0] x_ext;
logic [16:0] y_ext,y_ext1;
logic [4:0] y_ext_count;

logic [10:0] write_addr_count;
logic [1:0] write_x_int;
logic [11:0]	write_y_int,write_y_int1;
logic [8:0] write_x_ext;
logic [16:0] write_y_ext,write_y_ext1;
logic [4:0] write_y_ext_count;

//for S' * C:
logic signed [31:0] ACC0,ACC1,ACC2,ACC3;
logic signed [31:0] T_Buf_ACC2,T_Buf_ACC3;
logic signed [31:0] Temp_Buf_ACC2,Temp_Buf_ACC3;
logic [7:0] S_ram1_Buffer_ACC2,S_ram1_Buffer_ACC3;

//assign resetn = ~SWITCH_I[17];

//some startbit for our FSM (interpol/CSC starter)
//assign start=1'b1;

always_ff @ (posedge CLOCK_50_I or negedge Resetn) begin
  if(Resetn == 1'b0)begin
      finish <= 1'b0;//
      addr_count <= 12'd0;
      
      /*x_ext <= 9'd0;
      y_int <= 12'd0;
      y_int1 <= 12'd0;
      x_int <= 3'd0;
      y_ext <= 9'd0;
      y_ext1 <= 9'd0;*/
      y_ext_count <= 5'd0;
      
      fetch_count <= 7'd0;
      m2_state <= S_FSM2_IDLE;
  end else begin
    
    case (m2_state)
     S_FSM2_IDLE:begin
      if(start)begin
         finish <= 1'b0;//
         addr_count <= 12'd0;
         y_ext_count <= 5'd0;
         write_y_ext_count <= 5'd0;
			T_write_count <= 7'd0;
			f_cycle_active <= 1'b0;
			//for writing results
			S_write_count <= 7'd64;
			S_write_count_2 <= 7'd72;
      
			random_count <= 0;
			
         fetch_count <= 7'd0;
        m2_state <= DP_RAM_LOAD_1;
      end
    end
	 
		DP_RAM_LOAD_1: begin
			//ram0_address_A <= ram0_address_A + 6'd1;
			ram0_address_A <= 6'd0;
			ram0_wren_A <= 1'b1;
			ram0_write_data_A [31:16] <= 16'd1448;
			ram0_write_data_A [15:0] <= 16'd1448;
			m2_state <= DP_RAM_LOAD_2;
		end
		DP_RAM_LOAD_2: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1448;
			ram0_write_data_A [15:0] <= 16'd1448;
			m2_state <= DP_RAM_LOAD_3;
		end
		DP_RAM_LOAD_3: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1448;
			ram0_write_data_A [15:0] <= 16'd1448;
			m2_state <= DP_RAM_LOAD_4;
		end
		DP_RAM_LOAD_4: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1448;
			ram0_write_data_A [15:0] <= 16'd1448;
			m2_state <= DP_RAM_LOAD_5;
		end
		DP_RAM_LOAD_5: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd2008;
			ram0_write_data_A [15:0] <= 16'd1702;
			m2_state <= DP_RAM_LOAD_6;
		end
		DP_RAM_LOAD_6: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1137;
			ram0_write_data_A [15:0] <= 16'd399;
			m2_state <= DP_RAM_LOAD_7;
		end
		DP_RAM_LOAD_7: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= (16'd0 -16'd399);
			//ram0_write_data_A [31:16] <= (16'd0 -16'd2);
			ram0_write_data_A [15:0] <= -16'd1137;
			m2_state <= DP_RAM_LOAD_8;
		end
		DP_RAM_LOAD_8: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= -16'd1702;
			ram0_write_data_A [15:0] <= -16'd2008;
			m2_state <= DP_RAM_LOAD_9;
		end
		DP_RAM_LOAD_9: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1892;
			ram0_write_data_A [15:0] <= 16'd783;
			m2_state <= DP_RAM_LOAD_10;
		end
		DP_RAM_LOAD_10: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= -16'd783;
			ram0_write_data_A [15:0] <= -16'd1892;
			m2_state <= DP_RAM_LOAD_11;
		end
		DP_RAM_LOAD_11: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= -16'd1892;
			ram0_write_data_A [15:0] <= -16'd783;
			m2_state <= DP_RAM_LOAD_12;
		end
		DP_RAM_LOAD_12: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd783;
			ram0_write_data_A [15:0] <= 16'd1892;
			m2_state <= DP_RAM_LOAD_13;
		end
		DP_RAM_LOAD_13: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1702;
			ram0_write_data_A [15:0] <= -16'd399;
			m2_state <= DP_RAM_LOAD_14;
		end
		DP_RAM_LOAD_14: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= -16'd2008;
			ram0_write_data_A [15:0] <= -16'd1137;
			m2_state <= DP_RAM_LOAD_15;
		end
		DP_RAM_LOAD_15: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1137;
			ram0_write_data_A [15:0] <= 16'd2008;
			m2_state <= DP_RAM_LOAD_16;
		end
		DP_RAM_LOAD_16: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd399;
			ram0_write_data_A [15:0] <= -16'd1702;
			m2_state <= DP_RAM_LOAD_17;
		end
		DP_RAM_LOAD_17: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1448;
			ram0_write_data_A [15:0] <= -16'd1448;
			m2_state <= DP_RAM_LOAD_18;
		end
		DP_RAM_LOAD_18: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= -16'd1448;
			ram0_write_data_A [15:0] <= 16'd1448;
			m2_state <= DP_RAM_LOAD_19;
		end
		DP_RAM_LOAD_19: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1448;
			ram0_write_data_A [15:0] <= -16'd1448;
			m2_state <= DP_RAM_LOAD_20;
		end
		DP_RAM_LOAD_20: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= -16'd1448;
			ram0_write_data_A [15:0] <= 16'd1448;
			m2_state <= DP_RAM_LOAD_21;
		end
		DP_RAM_LOAD_21: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1137;
			ram0_write_data_A [15:0] <= -16'd2008;
			m2_state <= DP_RAM_LOAD_22;
		end
		DP_RAM_LOAD_22: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd399;
			ram0_write_data_A [15:0] <= 16'd1702;
			m2_state <= DP_RAM_LOAD_23;
		end
		DP_RAM_LOAD_23: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= -16'd1702;
			ram0_write_data_A [15:0] <= -16'd399;
			m2_state <= DP_RAM_LOAD_24;
		end
		DP_RAM_LOAD_24: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd2008;
			ram0_write_data_A [15:0] <= -16'd1137;
			m2_state <= DP_RAM_LOAD_25;
		end
		DP_RAM_LOAD_25: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd783;
			ram0_write_data_A [15:0] <= -16'd1892;
			m2_state <= DP_RAM_LOAD_26;
		end
		DP_RAM_LOAD_26: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1892;
			ram0_write_data_A [15:0] <= -16'd783;
			m2_state <= DP_RAM_LOAD_27;
		end
		DP_RAM_LOAD_27: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= -16'd783;
			ram0_write_data_A [15:0] <= 16'd1892;
			m2_state <= DP_RAM_LOAD_28;
		end
		DP_RAM_LOAD_28: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= -16'd1892;
			ram0_write_data_A [15:0] <= 16'd783;
			m2_state <= DP_RAM_LOAD_29;
		end
		DP_RAM_LOAD_29: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd399;
			ram0_write_data_A [15:0] <= -16'd1137;
			m2_state <= DP_RAM_LOAD_30;
		end
		DP_RAM_LOAD_30: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1702;
			ram0_write_data_A [15:0] <= -16'd2008;
			m2_state <= DP_RAM_LOAD_31;
		end
		DP_RAM_LOAD_31: begin
			ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd2008;
			ram0_write_data_A [15:0] <= -16'd1702;
			m2_state <= DP_RAM_LOAD_32;
		end
		DP_RAM_LOAD_32: begin
		  ram0_address_A <= ram0_address_A + 6'd1;
			ram0_write_data_A [31:16] <= 16'd1137;
			ram0_write_data_A [15:0] <= -16'd399;
			ram0_wren_A <= 1'b1; // active low so we wanna read now for multiplying
			//m2_state <= S_INIT_ADDR_COUNT;
			
			m2_state <= S_INIT_ADDR_COUNT;
		end
    
    S_INIT_ADDR_COUNT: begin
      ram0_wren_A <= 1'b1; //from matei
    //address = x_int + y_int * 320 + x_ext * 8 + 2560 * y_ext			
      SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
      SRAM_we_n <= 1'b1;
      addr_count <= addr_count + 12'd1;
      m2_state <= S_INIT_ADDR_COUNT_2;
    end
    S_INIT_ADDR_COUNT_2:begin
      // SRAM address			
      SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
      addr_count <= addr_count + 12'd1;
      m2_state <= S_INIT_ADDR_COUNT_3;
    end
    S_INIT_ADDR_COUNT_3:begin
      // SRAM address			
      SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
      addr_count <= addr_count + 12'd1;
      m2_state <= S_INIT_CYC_ADDR_FETCH;
    end
    S_INIT_CYC_ADDR_FETCH:begin
      // SRAM address
      SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
      addr_count <= addr_count + 12'd1;
      // Out of SRAM
      Fetch_Buf <= SRAM_read_data[15:0]; //y0
      m2_state <= S_INIT_CYC_ADDR_FETCH_1;

//			$write("value of SRAM_address : %d \n", SRAM_address);
//			$write("value of y  : %h \n", SRAM_read_data[15:0]);
    end
    S_INIT_CYC_ADDR_FETCH_1:begin
      // SRAM address
      SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
      addr_count <= addr_count + 12'd1;

      ram1_address_A <= fetch_count;
      fetch_count <= fetch_count + 7'd1;
      ram1_write_data_A[31:16] <= Fetch_Buf;		  //y0
      ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
      ram1_wren_A <= 1'b1;

//			$write("value of SRAM_address : %d \n", SRAM_address);
//			$write("value of y  : %h \n", SRAM_read_data[15:0]);
      if (fetch_count == 7'd30)begin
         m2_state <= S_INIT_CYC_FETCH_LEAD_OUT;
       end else begin
           m2_state <= S_INIT_CYC_ADDR_FETCH;
       end
    end
    //to write final 2 values
    S_INIT_CYC_FETCH_LEAD_OUT:begin
		//to readjust addr for next box
		addr_count <= addr_count - 12'd1;
      Fetch_Buf <= SRAM_read_data[15:0];
      m2_state <= S_INIT_CYC_FETCH_LEAD_OUT_1;
    end
    S_INIT_CYC_FETCH_LEAD_OUT_1:begin
      ram1_write_data_A[31:16] <= Fetch_Buf;		  //y2246
      ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y2247 
      
//			$write("value of SRAM_address : %d \n", SRAM_address);
//			$write("value of y2247 : %h \n", SRAM_read_data[15:0]);
//			$write("value of y2246 : %h \n", Fetch_Buf);
      fetch_count <= 0;
      const_count <= 0;
     	f_CxS <= 1'b1; 
     	
      m2_state <= S_INIT_SC;
    end
    
    S_INIT_SC:begin
    //ram1_address_B <= 0;
    //ram1_wren_B <= 1'b0;
	fetch_count <= fetch_count + 1;
	const_count <= const_count + 4;
	
	//constants - c0 c1 / c2 c3
    	ram0_address_A <= const_count;
	   ram0_address_B <= const_count + 1;
    	ram0_wren_A <= 1'b0;
    	ram0_wren_B <= 1'b0;

	//S' - s'0 s'1
	ram1_address_A <= fetch_count;
	ram1_wren_A <= 1'b0;

    	//m2_state <= S_dummy;
	m2_state <= S_INTI_SC_1;
    end
    
    
    S_INTI_SC_1:begin
		const_count <= const_count + 4;
	
		//constants - c8 c9 / c10 c11
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;
	
		multipli_select <= 1'b0;
		ACC0 <= 32'd0;
		ACC1 <= 32'd0;
		ACC2 <= 32'd0;
		ACC3 <= 32'd0;
	    	//m2_state <= S_dummy;
		m2_state <= S_CYC_INTI_SC;
    end
    
    
    S_CYC_INTI_SC: begin
  		/*$write("ram1_read_data_A[31:16]: %d\n",$signed(ram1_read_data_A[31:16]));
		$write("Fetch_Buf : %d\n",Fetch_Buf);
		$write("ram0_read_data_A[31:16]c12; : %d\n",$signed(ram0_read_data_A[31:16]));
		$write("ram0_read_data_A[15:0] c13; : %d\n",$signed(ram0_read_data_A[15:0]));
		$write("ram0_read_data_B[31:16]c14; : %d\n",$signed(ram0_read_data_B[31:16]));
		$write("ram0_read_data_B[15:0]c15; : %d\n",$signed(ram0_read_data_B[15:0]));
		$write("AAAAAA : %d\n",$signed(a));
	  $write("B : %d\n",$signed(b));
	  $write("C : %d\n",$signed(c));
	  */
		fetch_count <= fetch_count + 1;
		const_count <= const_count + 4;

		//constants - c16 c17 / c18 c19
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		//S' - s'2 s'3
		ram1_address_A <= fetch_count;
		ram1_wren_A <= 1'b0;
	
		// store s1
		Fetch_Buf <= ram1_read_data_A[15:0];
		
		multipli_select <= 1'b1;
		ACC0 <= a;
		ACC1 <= b;
		ACC2 <= c;
		ACC3 <= d;
		

		//write only if we are in second cycle.
		if(f_cycle_active == 1'b1)begin
			//ACCs results are ready to be written to temp ram
			ram2_address_A <= T_write_count;
			ram2_wren_A <= 1'b1;
			ram2_write_data_A <= (ACC0) >>> 8;
			ram2_address_B <= T_write_count + 7'd1;
			ram2_wren_B <= 1'b1;
			ram2_write_data_B <= (ACC1) >>> 8;
			T_Buf_ACC2 <= ACC2 >>> 8;
			T_Buf_ACC3 <= ACC3 >>> 8;	
			
		//$write("acc0 : %d\n",ACC0);
		//$write("acc1 : %d\n",ACC1);
		//$write("acc2 : %d\n",ACC2);
		//$write("acc3 : %d\n",ACC3);
		
			T_write_count <= T_write_count + 7'd2;
		end

	m2_state <= S_CYC_INTI_SC_1;
    end
    
    
	S_CYC_INTI_SC_1:begin
		const_count <= const_count + 4;
		//constants - c24...
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;
 
		if(f_cycle_active == 1'b1)begin
			//ACCs results are ready to be written to temp ram
			ram2_address_A <= T_write_count;
			ram2_wren_A <= 1'b1;
			ram2_write_data_A <= T_Buf_ACC2;
			ram2_address_B <= T_write_count + 7'd1;
			ram2_wren_B <= 1'b1;
			ram2_write_data_B <= T_Buf_ACC3;

			T_write_count <= T_write_count + 7'd2;
		end
		m2_state <= S_CYC_INTI_SC_2;
	end
	S_CYC_INTI_SC_2:begin
		fetch_count <= fetch_count + 1;
		const_count <= const_count + 4;
		//constants - c32...
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;
		//S' - s'4 s'5
		ram1_address_A <= fetch_count;
		ram1_wren_A <= 1'b0;
	
		multipli_select <= 1'b1;
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;
		// store
		Fetch_Buf <= ram1_read_data_A[15:0];
		
		m2_state <= S_CYC_INTI_SC_3;
	end
	S_CYC_INTI_SC_3:begin
		const_count <= const_count + 4;
		//constants - c40...
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_CYC_INTI_SC_4;
	end
	S_CYC_INTI_SC_4:begin
		fetch_count <= fetch_count + 1;
		const_count <= const_count + 4;
		//constants - c48...
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;
		//S' - s'6 s'7
		ram1_address_A <= fetch_count;
		ram1_wren_A <= 1'b0;
	
		multipli_select <= 1'b1;
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;
		// store
		Fetch_Buf <= ram1_read_data_A[15:0];

		m2_state <= S_CYC_INTI_SC_5;
	end
	S_CYC_INTI_SC_5:begin
///** GOTTA MODIFY THE CONST COUNT TO SWITCH SIDES OF THE DP RAM
// for the next c.c
//** ALSO GOTTA MODIFY FETCH COUNT TO SELECT THE RIGHT S'
		const_count <= const_count - 7'd26;//c4...
		fetch_count <= fetch_count - 7'd4; //s'0..
		//constants - c56...
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_CYC_INTI_SC_6;
	end
	S_CYC_INTI_SC_6:begin
		fetch_count <= fetch_count + 1;
		const_count <= const_count + 4;
		//constants - c4 c5/ c6 c7!!!
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;
		//S' - s'0 s'1!!!
		ram1_address_A <= fetch_count;
		ram1_wren_A <= 1'b0;

		multipli_select <= 1'b1;	
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;
		// store
		Fetch_Buf <= ram1_read_data_A[15:0];
		//$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		m2_state <= S_CYC_INTI_SC_7;
	end
	S_CYC_INTI_SC_7:begin
		const_count <= const_count + 4;
		//constants c13 c14...
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_CYC_TWO_INTI_SC;
	end
	S_CYC_TWO_INTI_SC:begin
		//here we have s0 s1 from the RAM1
		fetch_count <= fetch_count + 1;
		const_count <= const_count + 4;

		//constants - 2nd 1/2 2nd row
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		//S' - s'2 s'3
		ram1_address_A <= fetch_count;
		ram1_wren_A <= 1'b0;
	
		// store s'1!!
		Fetch_Buf <= ram1_read_data_A[15:0];
				//$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		multipli_select <= 1'b1;
		//new 2nd 1/2 of R values...
		ACC0 <= a;
		ACC1 <= b;
		ACC2 <= c;
		ACC3 <= d;

//$write("constant C4 C5 %h\n",ram0_read_data_A);
//$write("constant C6 C7 %h\n",ram0_read_data_B);
//$write("constant S0 S1 %h\n",ram1_read_data_A);

		//ACCs results are ready to be written to temp ram
		ram2_address_A <= T_write_count;
		ram2_wren_A <= 1'b1;
		ram2_write_data_A <= (ACC0) >>> 8;
		ram2_address_B <= T_write_count + 7'd1;
		ram2_wren_B <= 1'b1;
		ram2_write_data_B <= (ACC1) >>> 8;
		T_Buf_ACC2 <= ACC2 >>> 8;
		T_Buf_ACC3 <= ACC3 >>> 8;	

		T_write_count <= T_write_count + 7'd2;

		m2_state <= S_CYC_TWO_INTI_SC_1;

	end

	S_CYC_TWO_INTI_SC_1:begin
		const_count <= const_count + 4;
		//constants - 2nd 1/2 3rd row
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		//here(in this state) we multiply s'1 times the constants c12 c13 c14 and c15

		multipli_select <= 1'b0;
		//start the 2nd 1/2 4 Ts
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;

		//ACCs results are ready to be written to temp ram
		ram2_address_A <= T_write_count;
		ram2_wren_A <= 1'b1;
		ram2_write_data_A <= T_Buf_ACC2;
		ram2_address_B <= T_write_count + 7'd1;
		ram2_wren_B <= 1'b1;
		ram2_write_data_B <= T_Buf_ACC3;

		T_write_count <= T_write_count + 7'd2;

		m2_state <= S_CYC_TWO_INTI_SC_2;
	end
	S_CYC_TWO_INTI_SC_2:begin

//here we have s2 s3 from the RAM1
		fetch_count <= fetch_count + 1;
		const_count <= const_count + 4;

		//constants - 2nd half 4th row
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		//S' - s'4 s'5
		ram1_address_A <= fetch_count;
		ram1_wren_A <= 1'b0;
	
		multipli_select <= 1'b1;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;
		//$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		// store s1
		Fetch_Buf <= ram1_read_data_A[15:0];
		
		m2_state <= S_CYC_TWO_INTI_SC_3;
	end
	S_CYC_TWO_INTI_SC_3:begin
		const_count <= const_count + 4;
		//constants - 2nd 1/2 5rd row
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_CYC_TWO_INTI_SC_4;
	end
	S_CYC_TWO_INTI_SC_4:begin
//here we have s4 s5 from the RAM1
		fetch_count <= fetch_count + 1;
		const_count <= const_count + 4;

		//constants - 2nd half 6th row
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		//S' - s'6 s'7
		ram1_address_A <= fetch_count;
		ram1_wren_A <= 1'b0;
	
		multipli_select <= 1'b1;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		// store s1
		Fetch_Buf <= ram1_read_data_A[15:0];
		//$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		m2_state <= S_CYC_TWO_INTI_SC_5;
	end
	S_CYC_TWO_INTI_SC_5:begin
//modidy constant cound for the next cc
//send the constant to ram postion 0, from 30(which selects 1/2 half row 7 (61 62 63 64)
		const_count <= const_count - 7'd30;
//also dont mod fetch_count because it should go from 7 to 8.... the s' matrix coefficients
//$write("fetch_count before cycle, should be = to 8...4?: %d\n",fetch_count);

		//const_count <= const_count + 4;
		//constants - 2nd 1/2 7rd row
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_CYC_TWO_INTI_SC_6;
	end
	S_CYC_TWO_INTI_SC_6:begin
//here we have s6 s7 from the RAM1
		fetch_count <= fetch_count + 1;
		const_count <= const_count + 4;
//** constat MODIFY AS WELL?
		//constants - 2nd half 7th row
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;
//** MODIFIT STATE??
		//S' - s'6 s'7
		ram1_address_A <= fetch_count;
		ram1_wren_A <= 1'b0;
	
		multipli_select <= 1'b1;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		// store s1
		Fetch_Buf <= ram1_read_data_A[15:0];
//		$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		m2_state <= S_CYC_TWO_INTI_SC_7;
	end
	S_CYC_TWO_INTI_SC_7:begin
		const_count <= const_count + 4;
		//constants - 2nd 1/2 6rd row
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;
		
		//here we shouldve finished a 8 by 8 block
		//fetch count is 2 head it seems
		//$write("FETCH COUNT IS: %d",fetch_count);
		//$write("value of T_write_count : %d \n",T_write_count);

  		if(fetch_count == 33)begin
			 f_cycle_active <= 1'b0;
			 
			 m2_state <= S_SC_LEAD_OUT;
		 end else begin
			 m2_state <= S_CYC_INTI_SC;
			 f_cycle_active <= 1'b1;
		 end
	end
	S_SC_LEAD_OUT:begin


		//ACCs results are ready to be written to temp ram
		ram2_address_A <= T_write_count;
		ram2_wren_A <= 1'b1;
		ram2_write_data_A <= (ACC0) >>> 8;
		ram2_address_B <= T_write_count + 7'd1;
		ram2_wren_B <= 1'b1;
		ram2_write_data_B <= (ACC1) >>> 8;
		T_Buf_ACC2 <= ACC2 >>> 8;
		T_Buf_ACC3 <= ACC3 >>> 8;
		
		T_write_count <= T_write_count + 7'd2;		

    m2_state <= S_SC_LEAD_OUT_1;
	end
	S_SC_LEAD_OUT_1:begin
		//Fs+1 begins!
		//address = x_int + y_int * 320 + x_ext * 8 + 2560 * y_ext			
		SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
		SRAM_we_n <= 1'b1;
		addr_count <= addr_count + 12'd1;
		

		//ACCs results are ready to be written to temp ram
		ram2_address_A <= T_write_count;
		ram2_wren_A <= 1'b1;
		ram2_write_data_A <= T_Buf_ACC2;
		ram2_address_B <= T_write_count + 7'd1;
		ram2_wren_B <= 1'b1;
		ram2_write_data_B <= T_Buf_ACC3;

		T_write_count <= T_write_count + 7'd2;
		
		//$write("value of T_write_count : %d \n",T_write_count);
		//variables to be set up
		fetch_count <= 0;
		const_count <= 0;
		S_write_count <= 7'd64; //we write to second 1/2 of ram1 (first half has S')
		S_write_count_2 <= 7'd72;
		fetch_Sprime_count <= 0;
		f_cycle_active <= 1'b0;
		f_CtxT_done <= 1'b0;
		//for writing into SRAM
		read_S_addr <= 8'd64;
		
		//For S' x C
		T_write_count <= 7'd0;
		
		write_addr_count <= 0;
		
		//FIRST TIME AFTER S' x C, WE GO INTO Ct x T
		//Also we gotta fetch the new box, and we dont write
		f_CxS <= 1'b0;
		f_fetch_box <= 1'b0;
		f_write_box <= 1'b1;
		
		m2_state <= S_FULL_CYC;
	end
	
	S_FULL_CYC:begin
//////////
//////////////
/// i think Fs and Ws do not need to get started UNTIL S_START_CYC!!!!!!
//...........................
		// CxSi dont overlap
		//Fs+1 section
	   SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
      addr_count <= addr_count + 12'd1;	
		
		// T x Ct overlaps Fs+1
		/*if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 section, addr is 3 ahead, we get data 64 here and we are requesting addrs @ 67
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			// Out of SRAM
			Fetch_Buf <= SRAM_read_data[15:0]; //y0
		end*/
		/*
		//write back to SRAM cycle
		if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			write_addr_count <= write_addr_count + 11'd1;		
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= ram1_read_data_B[31:16];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
		end*/
	//////////////////////////////////////////////////////////////////////////
	
	//if we are doing C times S' then we need to address S' in the row
	//if we are doing Ctrans times T we need to go down T as a colomn
	//Constant selection stays the same in both cases...
		if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end
		const_count <= const_count + 4;
	
	//constants - c0 c1 / c2 c3
    	ram0_address_A <= const_count;
	   ram0_address_B <= const_count + 1;
    	ram0_wren_A <= 1'b0;
    	ram0_wren_B <= 1'b0;
	
		if(f_CxS == 1'b1)begin
			//S' - s'0 s'1
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			//T - T0
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end

		m2_state <= S_FULL_CYC_1;
   end
    
    S_FULL_CYC_1:begin
//////////
//////////////
/// i think Fs and Ws do not need to get started UNTIL S_START_CYC!!!!!!
//...........................
		// CxSi dont overlap
		//Fs+1 section
		SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
      addr_count <= addr_count + 12'd1;
		/*if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 part
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			
			ram1_address_A <= fetch_count;
			fetch_count <= fetch_count + 7'd1;
			ram1_write_data_A[31:16] <= Fetch_Buf;		  //y0
			ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
			ram1_wren_A <= 1'b1;
		end*/
		
		//write back to SRAM cycle
		/*if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			ram1_address_B <= read_S_addr;
			ram1_wren_B <= 1'b0;
			read_S_addr <= read_S_addr + 8'd1;
		
			write_addr_count <= write_addr_count + 11'd1;		
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= ram1_read_data_B[15:0];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
		end*/
		
	//////////////////////////////////////////////////////////////////////////////////	
		if(f_CxS == 1'b1)begin
			//no increment needed here
		end else begin
			fetch_count <= fetch_count + 8;
		end
		const_count <= const_count + 4;
		if(f_CxS == 1'b1)begin
			//do nothing we fetch onces every 2c.c. for this
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
		//constants - c8 c9 / c10 c11
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;
	
		multipli_select <= 1'b0;
		ACC0 <= 32'd0;
		ACC1 <= 32'd0;
		ACC2 <= 32'd0;
		ACC3 <= 32'd0;
	    	//m2_state <= S_dummy;
		m2_state <= S_START_CYC;
    end
	 
    S_START_CYC: begin
	 	if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 section we are recieving Element 64 but requesting element 67!
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			// Out of SRAM
			Fetch_Sprime_Buf <= SRAM_read_data[15:0]; //y0
		end
		
	 	if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end
		
		const_count <= const_count + 4;

		//constants - c16 c17 / c18 c19
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		if(f_CxS == 1'b1)begin
			//S' - s'2 s'3
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
	
		// store s1
		Fetch_Buf <= ram1_read_data_A[15:0];
		
		multipli_select <= 1'b1;
		ACC0 <= a;
		ACC1 <= b;
		ACC2 <= c;
		ACC3 <= d;
		

		//write only if we are in second cycle.
		if(f_CxS == 1'b1)begin
			if(f_cycle_active == 1'b1)begin
				//ACCs results are ready to be written to temp ram
				ram2_address_A <= T_write_count;
				ram2_wren_A <= 1'b1;
				ram2_write_data_A <= (ACC0) >>> 8;
				ram2_address_B <= T_write_count + 7'd1;
				ram2_wren_B <= 1'b1;
				ram2_write_data_B <= (ACC1) >>> 8;
				T_Buf_ACC2 <= ACC2 >>> 8;
				T_Buf_ACC3 <= ACC3 >>> 8;	
				
				T_write_count <= T_write_count + 7'd2;
			end
		end else begin
			if(f_cycle_active == 1'b1)begin
				//ACCs results are ready to be written to the S'/S ram
				//*******		//all results can be written in 1 c.c.?
				ram1_address_A <= S_write_count;
				ram1_wren_A <= 1'b1;
				ram1_write_data_A <= ((ACC0) >> 16); //r32
				S_write_count <= S_write_count + 7'd16;
				
				ram1_address_B <= S_write_count_2;
				ram1_wren_B <= 1'b1;
				ram1_write_data_B <= ((ACC1) >> 16);  //r40
				S_write_count_2 <= S_write_count_2 + 7'd16;
				
				S_ram1_Buffer_ACC2 <= ((ACC2) >> 16); //r48
				S_ram1_Buffer_ACC3 <= ((ACC3) >> 16);  //r56

			end
		end
		
		m2_state <= S_START_CYC_1;
    end
    
    
	S_START_CYC_1:begin

		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 part
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			
			ram1_address_A <= fetch_Sprime_count;
			fetch_Sprime_count <= fetch_Sprime_count + 7'd1;
			ram1_write_data_A[31:16] <= Fetch_Sprime_Buf;		  //y0
			ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
			ram1_wren_A <= 1'b1;
		end
	
		//write back to SRAM cycle
		if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			//assuming it comes in 0 on the first c.c and not incremented during at the last c.c before this(in cycle state)
			read_S_addr <= read_S_addr + 8'd2; //address for getting data out of DP ram 1 (S storage)
			ram1_address_A <= read_S_addr;
			ram1_wren_A <= 1'b0;
	
			ram1_address_B <= read_S_addr + 8'd1;
			ram1_wren_B <= 1'b0;
		
			SRAM_we_n <= 1'b0;
			SRAM_write_data[15:8] <= ram1_read_data_A[7:0];
			SRAM_write_data[7:0] <= ram1_read_data_B[7:0];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
			write_addr_count <= write_addr_count + 11'd1;

		end
	
		if(f_CxS == 1'b1)begin
			//no increment needed here
		end else begin
			fetch_count <= fetch_count + 8;
		end
		const_count <= const_count + 4;
		if(f_CxS == 1'b1)begin
			//do nothing we fetch onces every 2c.c. for this
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
		//constants - c24...
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	  	ram0_wren_A <= 1'b0;
   	ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;
 
		if(f_CxS == 1'b1)begin
			if(f_cycle_active == 1'b1)begin
				//ACCs results are ready to be written to temp ram
				ram2_address_A <= T_write_count;
				ram2_wren_A <= 1'b1;
				ram2_write_data_A <= T_Buf_ACC2;
				ram2_address_B <= T_write_count + 7'd1;
				ram2_wren_B <= 1'b1;
				ram2_write_data_B <= T_Buf_ACC3;

				T_write_count <= T_write_count + 7'd2;
			end
		end
		
		m2_state <= S_START_CYC_2;
	end
	S_START_CYC_2:begin

		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 section
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			// Out of SRAM
			Fetch_Sprime_Buf <= SRAM_read_data[15:0]; //y0
		end
	
	 	if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end
		
		const_count <= const_count + 4;
		//constants - c32...
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;
		
		if(f_CxS == 1'b1)begin
			//S' - s'4 s'5
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
	
		multipli_select <= 1'b1;
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;
		// store
		Fetch_Buf <= ram1_read_data_A[15:0];
		
				//wrtiting the remaining S values
		if(f_CxS == 1'b1)begin
		end else begin
			//ACCs results are ready to be written to the S'/S ram
	//*******		//all results can be written in 1 c.c.?
			if(f_cycle_active == 1'b1)begin
				ram1_address_A <= S_write_count;
				ram1_wren_A <= 1'b1;
				ram1_write_data_A <= S_ram1_Buffer_ACC2; //r48
				S_write_count <= S_write_count - 7'd47;
				
				ram1_address_B <= S_write_count_2;
				ram1_wren_B <= 1'b1;
				ram1_write_data_B <= S_ram1_Buffer_ACC3;  //r56
				S_write_count_2 <= S_write_count_2 - 7'd47;
				
				//we finished Ct x T
				if(S_write_count_2 == 7'd127)begin
				    f_CtxT_done <= 1'b1;
				    S_write_count <= 7'd64;
				    S_write_count_2 <= 7'd72;
				end
			end		
		end
		  
		
		  m2_state <= S_START_CYC_3;
	end
	S_START_CYC_3:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 part
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			
			ram1_address_A <= fetch_Sprime_count;
			fetch_Sprime_count <= fetch_Sprime_count + 7'd1;
			ram1_write_data_A[31:16] <= Fetch_Sprime_Buf;		  //y0
			ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
			ram1_wren_A <= 1'b1;
		end
	
		//write back to SRAM cycle
		if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			//assuming it comes in 0 on the first c.c and not incremented during at the last c.c before this(in cycle state)
			read_S_addr <= read_S_addr + 8'd2; //address for getting data out of DP ram 1 (S storage)
			ram1_address_A <= read_S_addr;
			ram1_wren_A <= 1'b0;
	
			ram1_address_B <= read_S_addr + 8'd1;
			ram1_wren_B <= 1'b0;
		
			SRAM_we_n <= 1'b0;
			SRAM_write_data[15:8] <= ram1_read_data_A[7:0];
			SRAM_write_data[7:0] <= ram1_read_data_B[7:0];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
			write_addr_count <= write_addr_count + 11'd1;
		end
	
		if(f_CxS == 1'b1)begin
			//no increment needed here
		end else begin
			fetch_count <= fetch_count + 8;
		end
		if(f_CxS == 1'b1)begin
			//do nothing we fetch onces every 2c.c. for this
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
		
		const_count <= const_count + 4;
		//constants - c40...
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_START_CYC_4;
	end
	S_START_CYC_4:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 section
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			// Out of SRAM
			Fetch_Sprime_Buf <= SRAM_read_data[15:0]; //y0
		end
	
		if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end
		const_count <= const_count + 4;
		//constants - c48...
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;
		
		if(f_CxS == 1'b1)begin
			//S' - s'6 s'7
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
	
		multipli_select <= 1'b1;
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;
		// store
		Fetch_Buf <= ram1_read_data_A[15:0];

		m2_state <= S_START_CYC_5;
	end
	S_START_CYC_5:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 part
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			
			ram1_address_A <= fetch_Sprime_count;
			fetch_Sprime_count <= fetch_Sprime_count + 7'd1;
			ram1_write_data_A[31:16] <= Fetch_Sprime_Buf;		  //y0
			ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
			ram1_wren_A <= 1'b1;
		end
		
		//write back to SRAM cycle
		if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			//assuming it comes in 0 on the first c.c and not incremented during at the last c.c before this(in cycle state)
			read_S_addr <= read_S_addr + 8'd2; //address for getting data out of DP ram 1 (S storage)
			ram1_address_A <= read_S_addr;
			ram1_wren_A <= 1'b0;
	
			ram1_address_B <= read_S_addr + 8'd1;
			ram1_wren_B <= 1'b0;
		
			SRAM_we_n <= 1'b0;
			SRAM_write_data[15:8] <= ram1_read_data_A[7:0];
			SRAM_write_data[7:0] <= ram1_read_data_B[7:0];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
			write_addr_count <= write_addr_count + 11'd1;
		end
		
///** GOTTA MODIFY THE CONST COUNT TO SWITCH SIDES OF THE DP RAM
// for the next c.c
//** ALSO GOTTA MODIFY FETCH COUNT TO SELECT THE RIGHT S'
		if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count - 7'd4; //s'0..
		end else begin
			fetch_count <= fetch_count - 7'd56; //t0..
		end
		
		
		const_count <= const_count - 7'd26;//c4...
		//constants - c56...
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_START_CYC_6;
	end
	S_START_CYC_6:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 section
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			// Out of SRAM
			Fetch_Sprime_Buf <= SRAM_read_data[15:0]; //y0
		end
	
		if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end
		const_count <= const_count + 4;
		//constants - c4 c5/ c6 c7!!!
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;
		
		if(f_CxS == 1'b1)begin
			//S' - s'0 s'1!!!
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
		
		multipli_select <= 1'b1;	
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;
		// store
		Fetch_Buf <= ram1_read_data_A[15:0];
		//$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		m2_state <= S_START_CYC_7;
	end
	S_START_CYC_7:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 part
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			
			ram1_address_A <= fetch_Sprime_count;
			fetch_Sprime_count <= fetch_Sprime_count + 7'd1;
			ram1_write_data_A[31:16] <= Fetch_Sprime_Buf;		  //y0
			ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
			ram1_wren_A <= 1'b1;
		end
		
		//write back to SRAM cycle
		if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			//assuming it comes in 0 on the first c.c and not incremented during at the last c.c before this(in cycle state)
			read_S_addr <= read_S_addr + 8'd2; //address for getting data out of DP ram 1 (S storage)
			ram1_address_A <= read_S_addr;
			ram1_wren_A <= 1'b0;
	
			ram1_address_B <= read_S_addr + 8'd1;
			ram1_wren_B <= 1'b0;
		
			SRAM_we_n <= 1'b0;
			SRAM_write_data[15:8] <= ram1_read_data_A[7:0];
			SRAM_write_data[7:0] <= ram1_read_data_B[7:0];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
			write_addr_count <= write_addr_count + 11'd1;

		end
	
		if(f_CxS == 1'b1)begin
			//no increment needed here
		end else begin
			fetch_count <= fetch_count + 8;
		end
		if(f_CxS == 1'b1)begin
			//do nothing we fetch onces every 2c.c. for this
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
		
		const_count <= const_count + 4;
		//constants c13 c14...
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_START_TWO_CYC;
	end
	S_START_TWO_CYC:begin

	
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 section
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			// Out of SRAM
			Fetch_Sprime_Buf <= SRAM_read_data[15:0]; //y0
		end
		
	//FOR TEMP x Ct: here we do the same thing as above with different constant selection (same as for the CxS cycle)
		//here we have s0 s1 from the RAM1
		if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end
		const_count <= const_count + 4;

		//constants - 2nd 1/2 2nd row
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		if(f_CxS == 1'b1)begin
			//S' - s'2 s'3
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end

		// store s'1!!
		Fetch_Buf <= ram1_read_data_A[15:0];
				//$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		multipli_select <= 1'b1;
		//new 2nd 1/2 of R values...
		ACC0 <= a;
		ACC1 <= b;
		ACC2 <= c;
		ACC3 <= d;

		if(f_CxS == 1'b1)begin
			//ACCs results are ready to be written to temp ram
			ram2_address_A <= T_write_count;
			ram2_wren_A <= 1'b1;
			ram2_write_data_A <= (ACC0) >>> 8;
			
			ram2_address_B <= T_write_count + 7'd1;
			ram2_wren_B <= 1'b1;
			ram2_write_data_B <= (ACC1) >>> 8;
			T_Buf_ACC2 <= ACC2 >>> 8;
			T_Buf_ACC3 <= ACC3 >>> 8;	

			T_write_count <= T_write_count + 7'd2;

			//$write("acc0 : %d\n",ACC0);
			//$write("acc1 : %d\n",ACC1);
			//$write("acc2 : %d\n",ACC2);
			//$write("acc3 : %d\n",ACC3);
		end else begin
			//ACCs results are ready to be written to the S'/S ram
	//*******		//all results can be written in 1 c.c.?
	    if(f_CtxT_done == 1'b0)begin
    			ram1_address_A <= S_write_count;
			 ram1_wren_A <= 1'b1;
			 ram1_write_data_A <= ((ACC0) >> 16); //r0
			 S_write_count <= S_write_count + 7'd16;
			
			 ram1_address_B <= S_write_count_2;
		  	ram1_wren_B <= 1'b1;
			 ram1_write_data_B <= ((ACC1) >> 16);  //r8
			 S_write_count_2 <= S_write_count_2 + 7'd16;
			
		  	S_ram1_Buffer_ACC2 <= ((ACC2) >> 16); //r16
			 S_ram1_Buffer_ACC3 <= ((ACC3) >> 16);  //r24
			
			
	//		 $write("acc0 : %d\n",ACC0>>16);
	//		 $write("acc1 : %d\n",ACC1>>16);
	//	  	$write("acc2 : %d\n",ACC2>>16);
	//		 $write("acc3 : %d\n",ACC3>>16);
			end
		end
		
		m2_state <= S_START_TWO_CYC_1;
	end

	S_START_TWO_CYC_1:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 part
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			
			ram1_address_A <= fetch_Sprime_count;
			fetch_Sprime_count <= fetch_Sprime_count + 7'd1;
			ram1_write_data_A[31:16] <= Fetch_Sprime_Buf;		  //y0
			ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
			ram1_wren_A <= 1'b1;
		end
		
		//write back to SRAM cycle
		if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			//assuming it comes in 0 on the first c.c and not incremented during at the last c.c before this(in cycle state)
			read_S_addr <= read_S_addr + 8'd2; //address for getting data out of DP ram 1 (S storage)
			ram1_address_A <= read_S_addr;
			ram1_wren_A <= 1'b0;
	
			ram1_address_B <= read_S_addr + 8'd1;
			ram1_wren_B <= 1'b0;
		
			SRAM_we_n <= 1'b0;
			SRAM_write_data[15:8] <= ram1_read_data_A[7:0];
			SRAM_write_data[7:0] <= ram1_read_data_B[7:0];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
			write_addr_count <= write_addr_count + 11'd1;
		end
		
		if(f_CxS == 1'b1)begin
			//no increment needed here
		end else begin
			fetch_count <= fetch_count + 8;
		end
		if(f_CxS == 1'b1)begin
			//do nothing we fetch onces every 2c.c. for this
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
		
		const_count <= const_count + 4;
		//constants - 2nd 1/2 3rd row
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	  	ram0_wren_A <= 1'b0;
   	ram0_wren_B <= 1'b0;

		//here(in this state) we multiply s'1 times the constants c12 c13 c14 and c15

		multipli_select <= 1'b0;
		//start the 2nd 1/2 4 Ts
		ACC0 <= ACC0 + a;
		ACC1 <= ACC1 + b;
		ACC2 <= ACC2 + c;
		ACC3 <= ACC3 + d;
		
		if(f_CxS == 1'b1)begin
			//ACCs results are ready to be written to temp ram
			ram2_address_A <= T_write_count;
			ram2_wren_A <= 1'b1;
			ram2_write_data_A <= T_Buf_ACC2;
			ram2_address_B <= T_write_count + 7'd1;
			ram2_wren_B <= 1'b1;
			ram2_write_data_B <= T_Buf_ACC3;

			T_write_count <= T_write_count + 7'd2;
		end

		m2_state <= S_START_TWO_CYC_2;
	end
	S_START_TWO_CYC_2:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 section
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			// Out of SRAM
			Fetch_Sprime_Buf <= SRAM_read_data[15:0]; //y0
		end
		
		if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end
		
//here we have s2 s3 from the RAM1
		const_count <= const_count + 4;

		//constants - 2nd half 4th row
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	  	ram0_wren_B <= 1'b0;
		
		if(f_CxS == 1'b1)begin
			//S' - s'4 s'5
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
	
		multipli_select <= 1'b1;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;
		//$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		// store s1
		Fetch_Buf <= ram1_read_data_A[15:0];
		
		//wrtiting the remaining S values
		if(f_CxS == 1'b1)begin
		end else begin
		  if(f_CtxT_done == 1'b0)begin
			 ram1_address_A <= S_write_count;
		  	ram1_wren_A <= 1'b1;
			 ram1_write_data_A <= S_ram1_Buffer_ACC2; //r16
			 S_write_count <= S_write_count + 7'd16;
			
		  	ram1_address_B <= S_write_count_2;
			 ram1_wren_B <= 1'b1;
	   		ram1_write_data_B <= S_ram1_Buffer_ACC3;  //r24	
	   	 S_write_count_2 <= S_write_count_2 +	7'd16;
			end
		end
		
		m2_state <= S_START_TWO_CYC_3;
	end
	S_START_TWO_CYC_3:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 part
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			
			ram1_address_A <= fetch_Sprime_count;
			fetch_Sprime_count <= fetch_Sprime_count + 7'd1;
			ram1_write_data_A[31:16] <= Fetch_Sprime_Buf;		  //y0
			ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
			ram1_wren_A <= 1'b1;
		end
		
		//write back to SRAM cycle
		if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			//assuming it comes in 0 on the first c.c and not incremented during at the last c.c before this(in cycle state)
			read_S_addr <= read_S_addr + 8'd2; //address for getting data out of DP ram 1 (S storage)
			ram1_address_A <= read_S_addr;
			ram1_wren_A <= 1'b0;
	
			ram1_address_B <= read_S_addr + 8'd1;
			ram1_wren_B <= 1'b0;
		
			SRAM_we_n <= 1'b0;
			SRAM_write_data[15:8] <= ram1_read_data_A[7:0];
			SRAM_write_data[7:0] <= ram1_read_data_B[7:0];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
			write_addr_count <= write_addr_count + 11'd1;
		end
		
		if(f_CxS == 1'b1)begin
			//no increment needed here
		end else begin
			fetch_count <= fetch_count + 8;
		end
		if(f_CxS == 1'b1)begin
			//do nothing we fetch onces every 2c.c. for this
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
		
		const_count <= const_count + 4;
		//constants - 2nd 1/2 5rd row
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_START_TWO_CYC_4;
	end
	S_START_TWO_CYC_4:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 section
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			// Out of SRAM
			Fetch_Sprime_Buf <= SRAM_read_data[15:0]; //y0
		end
		
		if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end
//here we have s4 s5 from the RAM1
		const_count <= const_count + 4;

		//constants - 2nd half 6th row
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		if(f_CxS == 1'b1)begin
			//S' - s'6 s'7
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
	
		multipli_select <= 1'b1;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		// store s1
		Fetch_Buf <= ram1_read_data_A[15:0];
		//$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		m2_state <= S_START_TWO_CYC_5;
	end
	S_START_TWO_CYC_5:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 part
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			
			ram1_address_A <= fetch_Sprime_count;
			fetch_Sprime_count <= fetch_Sprime_count + 7'd1;
			ram1_write_data_A[31:16] <= Fetch_Sprime_Buf;		  //y0
			ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
			ram1_wren_A <= 1'b1;
		end
		
		//write back to SRAM cycle
		if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			//assuming it comes in 0 on the first c.c and not incremented during at the last c.c before this(in cycle state)
			read_S_addr <= read_S_addr + 8'd2; //address for getting data out of DP ram 1 (S storage)
			ram1_address_A <= read_S_addr;
			ram1_wren_A <= 1'b0;
	
			ram1_address_B <= read_S_addr + 8'd1;
			ram1_wren_B <= 1'b0;
		
			SRAM_we_n <= 1'b0;
			SRAM_write_data[15:8] <= ram1_read_data_A[7:0];
			SRAM_write_data[7:0] <= ram1_read_data_B[7:0];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
			write_addr_count <= write_addr_count + 11'd1;
		end
//modidy constant cound for the next cc
//send the constant to ram postion 0, from 30(which selects 1/2 half row 7 (61 62 63 64)
//we dont touch constant select
		const_count <= const_count - 7'd30;

//also dont mod fetch_count because it should go from 7 to 8.... the s' matrix coefficients
//$write("fetch_count before cycle, should be = to 8...4?: %d\n",fetch_count);
		if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count; //will go to S8/S9 for the new row of results...
		end else begin
			fetch_count <= fetch_count - 7'd55; //T1 for the new col of results...
		end
		
		//const_count <= const_count + 4;
		//constants - 2nd 1/2 7rd row
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		if(f_CxS == 1'b1)begin
			//do nothing we fetch onces every 2c.c. for this
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
		
		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		m2_state <= S_START_TWO_CYC_6;
	end
	S_START_TWO_CYC_6:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 section
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			// Out of SRAM
			Fetch_Sprime_Buf <= SRAM_read_data[15:0]; //y0
		end
		
		if(f_CxS == 1'b1)begin
			//here we have s6 s7 from the RAM1
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end

		const_count <= const_count + 4;
//** constat MODIFY AS WELL?
		//constants - 2nd half 7th row
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;
//** MODIFIT STATE??
		if(f_CxS == 1'b1)begin
			//S' - s'0 s'1!!! or is it 		//S' - s'6 s'7
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
	
		multipli_select <= 1'b1;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		// store s1
		Fetch_Buf <= ram1_read_data_A[15:0];
//		$write("Fetch_Buf: %h\n",ram1_read_data_A[15:0]);

		m2_state <= S_START_TWO_CYC_7;
	end
	S_START_TWO_CYC_7:begin
		if(f_CxS == 1'b0 && f_fetch_box == 1'b0)begin
			//Fs+1 part
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			addr_count <= addr_count + 12'd1;
			
			ram1_address_A <= fetch_Sprime_count;
			fetch_Sprime_count <= fetch_Sprime_count + 7'd1;
			ram1_write_data_A[31:16] <= Fetch_Sprime_Buf;		  //y0
			ram1_write_data_A[15:0] <= SRAM_read_data[15:0]; //y1
			ram1_wren_A <= 1'b1;
		end
		
		//write back to SRAM cycle
		if(f_CxS == 1'b1 && f_write_box == 1'b0)begin
			//assuming it comes in 0 on the first c.c and not incremented during at the last c.c before this(in cycle state)
			read_S_addr <= read_S_addr + 8'd2; //address for getting data out of DP ram 1 (S storage)
			ram1_address_A <= read_S_addr;
			ram1_wren_A <= 1'b0;
	
			ram1_address_B <= read_S_addr + 8'd1;
			ram1_wren_B <= 1'b0;
		
			SRAM_we_n <= 1'b0;
			SRAM_write_data[15:8] <= ram1_read_data_A[7:0];
			SRAM_write_data[7:0] <= ram1_read_data_B[7:0];
			SRAM_address <= POST_Y_OFFSET + write_x_int + (write_y_int + write_y_int1) + write_x_ext + (write_y_ext + write_y_ext1);
			write_addr_count <= write_addr_count + 11'd1;
		end
		
		//finished the b0x FETCHING
		// reset addr_count for the next time we need to fetch
		// check for end of the row of boxes
		// x_ext >= 40?? 
		if(fetch_Sprime_count == 7'd31)begin
			f_fetch_box <= 1'b1;
			fetch_Sprime_count <= 7'd0;
			addr_count <= addr_count - 7'd2;
			//questionable addr_count!!			
			if(addr_count[11:6] >= (6'b101000))begin
				addr_count <= 12'd0;
				y_ext_count <= y_ext_count + 5'd1;
			end	
		end
								
		//finished the box WRITING
		if(f_CxS == 1'b1)begin
		  if(read_S_addr == 8'd128)begin
			   f_write_box <= 1'b1;
			   read_S_addr <= 8'd64;
				write_addr_count <= write_addr_count + 11'd1; //don't increment the write_addr_count for next cycle write
				//end of row for WRITING
				if(write_addr_count[10:5] >= (6'b101000 - 6'b1))begin
					write_y_ext_count <= write_y_ext_count + 5'd1;
					write_addr_count <= 11'd0;
				end
		  end
		end

		if(f_CxS == 1'b1)begin
			//no increment needed here
		end else begin
			fetch_count <= fetch_count + 8;
		end
		if(f_CxS == 1'b1)begin
			//do nothing we fetch onces every 2c.c. for this
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
		end
		
		const_count <= const_count + 4;
		//constants - 2nd 1/2 6rd row
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		multipli_select <= 1'b0;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;
		
		//here we shouldve finished a 8 by 8 block
		//fetch count is 2 head it seems
		//$write("FETCH COUNT IS: %d",fetch_count);
		if(f_CxS == 1'b1)begin
			if(fetch_count == 33)begin
				m2_state <= S_CYC_LEAD_IN;
			end else begin
				m2_state <= S_START_CYC;
				f_cycle_active <= 1'b1;
			end
		end else begin
			if(f_CtxT_done == 1'b1)begin
				m2_state <= S_CYC_LEAD_IN;
			end else begin
				m2_state <= S_START_CYC;
				f_cycle_active <= 1'b1;
			end
		end
	end
	//3 lead in states to begin cycling and set up DP and SRAM
	//takes control of the switch between S' x C/Write S -> Ct x T / Fetch S'
	S_CYC_LEAD_IN:begin
		if(f_CxS == 1'b0)begin //we were in Ct * T mode
			f_CxS <= 1'b1;      //go into Si * C
			multipli_select <= 1'b0;
			//for going into write S cycle, start the write 8x8 to sram
			f_write_box <= 1'b0;	
			//for wrting S'xC into the Temp RAm
			T_write_count <= 1'b0;
		end else begin
			f_CxS <= 1'b0;			//go into Ct * T
			f_CtxT_done <= 1'b0;
			//for going into fetch S' cycle, start the read 8x8 from sram
			f_fetch_box <= 1'b0;
			//Fs+1 begins!
			//address = x_int + y_int * 320 + x_ext * 8 + 2560 * y_ext			
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			SRAM_we_n <= 1'b1;
			addr_count <= addr_count + 12'd1;
		end
		//turn off cycle mode
		f_cycle_active <= 1'b0;
		
		//variables to be set up
		fetch_count <= 0;
		const_count <= 0;
		S_write_count <= 7'd64; //we write to second 1/2 of ram1 (first half has S')
		S_write_count_2 <= 7'd72;
		fetch_Sprime_count <= 0;
		//for writing into SRAM
		read_S_addr <= 8'd64;
		
		m2_state <= S_CYC_LEAD_IN_1;
		
		random_count <= random_count + 1;
	end
					
					
	S_CYC_LEAD_IN_1:begin 
		if(f_CxS == 1'b1)begin
			fetch_count <= fetch_count + 1;
		end else begin
			fetch_count <= fetch_count + 8;
		end
		const_count <= const_count + 4;
	
	//constants - c0 c1 / c2 c3
    	ram0_address_A <= const_count;
	   ram0_address_B <= const_count + 1;
    	ram0_wren_A <= 1'b0;
    	ram0_wren_B <= 1'b0;
	
		if(f_CxS == 1'b1)begin
			//S' - s'0 s'1
			ram1_address_A <= fetch_count;
			ram1_wren_A <= 1'b0;
		end else begin
			//T - T0
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
			
			//Fetch S', Sram warm up
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			SRAM_we_n <= 1'b1;
			addr_count <= addr_count + 12'd1;
		end
	
		m2_state <= S_CYC_LEAD_IN_2;
		
		if(random_count==2400)begin
			dumb_count <= 18'd25000;
			m2_state <= S_dummy;
		end
	end
	
	S_CYC_LEAD_IN_2: begin
		if(f_CxS == 1'b1)begin
			//S!! -R0 R1
			read_S_addr <= read_S_addr + 8'd2; //address for getting data out of DP ram 1 (S storage)
			ram1_address_A <= read_S_addr;
			ram1_wren_A <= 1'b0;
	
			ram1_address_B <= read_S_addr + 8'd1;
			ram1_wren_B <= 1'b0;
		end
	
		if(f_CxS == 1'b1)begin
			//no increment needed here
		end else begin
			fetch_count <= fetch_count + 8;
		end
		const_count <= const_count + 4;
		if(f_CxS == 1'b1)begin
			//do nothing we fetch onces every 2c.c. for this
		end else begin
			ram2_address_A <= fetch_count;
			ram2_wren_A <= 1'b0;
			
			SRAM_address <= PRE_Y_OFFSET + x_int + (y_int+y_int1) + x_ext + (y_ext+y_ext1);
			SRAM_we_n <= 1'b1;
			addr_count <= addr_count + 12'd1;
		end
		//constants - c8 c9 / c10 c11
	   ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	   ram0_wren_A <= 1'b0;
	   ram0_wren_B <= 1'b0;

		m2_state <= S_START_CYC;
	end
	
	S_SC_LEAD_OUT_1:begin
	  //ACCs results are ready to be written to temp ram
		ram2_address_A <= T_write_count;
		ram2_wren_A <= 1'b1;
		ram2_write_data_A <= T_Buf_ACC2;
		ram2_address_B <= T_write_count + 7'd1;
		ram2_wren_B <= 1'b1;
		ram2_write_data_B <= T_Buf_ACC3;

		T_write_count <= T_write_count + 7'd2;
		
		m2_state <= S_FULL_CYC;
	end



	S_CYC_TWO_INTI_CS_8:begin
//here we should have [s8 s9]  from the RAM1

//here we are ready to write...
//on the next cycle...constants get selected the same way, S must be selected from the new row
//final acc results for 2nd 1/2 of the 0th row.
		fetch_count <= fetch_count + 1;
		const_count <= const_count + 4;

		//constants - 2nd half 7th row
	    	ram0_address_A <= const_count;
		ram0_address_B <= const_count + 1;
	    	ram0_wren_A <= 1'b0;
	    	ram0_wren_B <= 1'b0;

		//S' - s'6 s'7
		ram1_address_A <= fetch_count;
		ram1_wren_A <= 1'b0;
	
		multipli_select <= 1'b1;
		ACC0 <= a + ACC0;
		ACC1 <= b + ACC1;
		ACC2 <= c + ACC2;
		ACC3 <= d + ACC3;

		// store s1
		Fetch_Buf <= ram1_read_data_A[15:0];

		m2_state <= S_CYC_TWO_INTI_SC_5;
	end

/*    
S_dummy:begin
  //ram1_address_B <= 1;
      ram2_address_A <= fetch_count;
      fetch_count <= fetch_count + 1;
      ram2_wren_A <= 1'b1;
      if (ram2_address_A[0] == 1'b1)begin
       ram2_write_data_A <= 32'h00000000 ;
      end else begin
        ram2_write_data_A <= 32'hFFFFFFFF;
      end

      if(fetch_count == 126)begin
       fetch_count <= 0;
        m2_state <= S_dummy1;
      end
end*/

	S_dummy1:begin
      ram1_address_A <= dumb_count;
      dumb_count <= dumb_count + 1;
      ram1_wren_A <= 1'b0;
      $write("value of read data : %h \n", $signed(ram1_read_data_A));
      //$write("value of read data least sig : %h \n", ram0_read_data_A[15:0]);
      if(dumb_count == 130)begin
		//$write("+3,addr_count : %d",addr_count);
      $stop;
      end
	end
	
	S_dummy:begin
      SRAM_address <= dumb_count;
      SRAM_we_n  <= 1'b1;
      dumb_count <= dumb_count + 1;

      $write("value of SRAM read data @ dumb_count-3 %d: val : %h \n",(dumb_count-3), (SRAM_read_data));
      //$write("value of read data least sig : %h \n", ram0_read_data_A[15:0]);
      if(dumb_count == 18'd30000)begin
		//$write("+3,addr_count : %d",addr_count);
      $stop;
      end
	end


    default: m2_state <= S_FSM2_IDLE;
    endcase
  end
end

//the 16 bit values need to be sign extented when they are negative
logic signed [31:0] BUF_ram1_read_data_A_31t16,BUF_ram0_read_data_A_31t16,BUF_ram0_read_data_A_15t0;
logic signed [31:0] BUF_ram0_read_data_B_31t16,BUF_ram0_read_data_B_15t0;
assign BUF_ram1_read_data_A_31t16 = ram1_read_data_A[31] ? ({16'hFFFF,ram1_read_data_A[31:16]}): ({16'd0,ram1_read_data_A[31:16]});
assign BUF_ram0_read_data_A_31t16 = ram0_read_data_A[31] ? ({16'hFFFF,ram0_read_data_A[31:16]}):({16'd0,ram0_read_data_A[31:16]});
assign BUF_ram0_read_data_A_15t0 = ram0_read_data_A[15] ?  ({16'hFFFF,ram0_read_data_A[15:0]}):({16'd0,ram0_read_data_A[15:0]});
assign BUF_ram0_read_data_B_31t16 = ram0_read_data_B[31] ? ({16'hFFFF,ram0_read_data_B[31:16]}):({16'd0,ram0_read_data_B[31:16]});
assign BUF_ram0_read_data_B_15t0 = ram0_read_data_B[15] ? ({16'hFFFF,ram0_read_data_B[15:0]}):({16'd0,ram0_read_data_B[15:0]});

logic signed [31:0] BUF_Fetch_Buf;
assign BUF_Fetch_Buf = Fetch_Buf[15] ? ({16'hFFFF,Fetch_Buf[15:0]}):({16'h0000,Fetch_Buf[15:0]});

logic signed [31:0] BUF_T;
assign BUF_T = ram2_read_data_A[31:0];

always_comb begin

	op1=0;op2=0;op3=0;op4=0;op5=0;op6=0;op7=0;op8=0;
	if(f_CxS==1'b1)begin
		if(multipli_select == 1'b0)begin
			op1 = BUF_ram1_read_data_A_31t16; //s'6
			op2 = BUF_ram0_read_data_A_31t16; //s'6 
			op3 = BUF_ram1_read_data_A_31t16; //s'6
			op4 = BUF_ram0_read_data_A_15t0; //s'6 
			op5 = BUF_ram1_read_data_A_31t16; //s'6
			op6 = BUF_ram0_read_data_B_31t16; //s'6
			op7 = BUF_ram1_read_data_A_31t16; //s'6
			op8 = BUF_ram0_read_data_B_15t0; //s'6 * c
		end else if(multipli_select == 1'b1)begin
			op1 = BUF_Fetch_Buf; //s'1
			op2 = BUF_ram0_read_data_A_31t16;
			op3 = BUF_Fetch_Buf; //s'1
			op4 = BUF_ram0_read_data_A_15t0; 
			op5 = BUF_Fetch_Buf; //s'1
			op6 = BUF_ram0_read_data_B_31t16; 
			op7 = BUF_Fetch_Buf; //s'1
			op8 = BUF_ram0_read_data_B_15t0; 
		end
	end else begin
	//for Ct x T
		op1 = BUF_T;
		op2 = BUF_ram0_read_data_A_31t16;
		op3 = BUF_T;
		op4 = BUF_ram0_read_data_A_15t0;
		op5 = BUF_T;	
		op6 = BUF_ram0_read_data_B_31t16;
		op7 = BUF_T;
		op8 = BUF_ram0_read_data_B_15t0;
	end
end
// SRAM address
//address = x_int + y_int * 320 + x_ext * 8 + 2560 * y_ext
assign	x_int = addr_count[2:0];
assign	y_int = (addr_count[5:3] << 8);
assign	y_int1 = (addr_count[5:3]<<6);
assign	x_ext = (addr_count[11:6]<<3);
assign	y_ext = (y_ext_count << 11);
assign	y_ext1 = (y_ext_count << 9);
//end

//address = x_int + y_int * 160 + x_ext * 4 + 1280 * y_ext
assign	write_x_int = write_addr_count[1:0];
assign	write_y_int = (write_addr_count[4:2] << 7);
assign	write_y_int1 = (write_addr_count[4:2] << 5);
assign	write_x_ext = (write_addr_count[10:5] << 2);
assign	write_y_ext = (write_y_ext_count << 10);
assign	write_y_ext1 = (write_y_ext_count << 8);

//for DP ram testing
//assign ram1_write_data_A = ram1_write_data_A;
//assign ram1_write_data_B = ram1_write_data_B;		
//assign ram1_address_A = ram1_address_A;
//assign ram1_address_B = ram1_address_B;
//assign ram1_read_data_A = ram1_read_data_A;
//assign ram1_read_data_B = ram1_read_data_B;

endmodule