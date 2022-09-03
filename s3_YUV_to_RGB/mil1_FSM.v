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

// This is the top module
// It connects the UART, SRAM and VGA together.
// It gives access to the SRAM for UART and VGA
module mil1_FSM (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_I,           // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs

		/////// VGA interface                     ////////////
		output logic VGA_CLOCK_O,                 // VGA clock
		output logic VGA_HSYNC_O,                 // VGA H_SYNC
		output logic VGA_VSYNC_O,                 // VGA V_SYNC
		output logic VGA_BLANK_O,                 // VGA BLANK
		output logic VGA_SYNC_O,                  // VGA SYNC
		output logic[9:0] VGA_RED_O,              // VGA red
		output logic[9:0] VGA_GREEN_O,            // VGA green
		output logic[9:0] VGA_BLUE_O,             // VGA blue
		
		/////// SRAM Interface                    ////////////
		inout wire[15:0] SRAM_DATA_IO,            // SRAM data bus 16 bits
		output logic[17:0] SRAM_ADDRESS_O,        // SRAM address bus 18 bits
		output logic SRAM_UB_N_O,                 // SRAM high-byte data mask 
		output logic SRAM_LB_N_O,                 // SRAM low-byte data mask 
		output logic SRAM_WE_N_O,                 // SRAM write enable
		output logic SRAM_CE_N_O,                 // SRAM chip enable
		output logic SRAM_OE_N_O,                 // SRAM output logic enable
		
		/////// UART                              ////////////
		input logic UART_RX_I,                    // UART receive signal
		output logic UART_TX_O                    // UART transmit signal

);
	
// Define the offset for Green and Blue data in the memory		
parameter Y_OFFSET = 18'd0,
			 U_EVEN_OFFSET = 18'd38400,
	       V_EVEN_OFFSET = 18'd57600,
	       RGB_OFFSET = 18'd146944;
	
logic resetn;

top_state_type top_state;

/////// FSM VARIABLES ////////////////////////////////////////////
logic start;
logic[18:0] Y_data_count, write_count, data_count;
logic[1:0] csc_even_val_select, csc_odd_val_select;


logic [15:0] Y;
// upSamp 'U
// UpSamp 'V

logic [17:0] ACC_U;
logic [7:0] Reg_u;
logic [7:0] Reg_u2;

logic [7:0] U_j5;
logic [7:0] U_j3;
logic [7:0] U_j1;
logic [7:0] U_jP1;
logic [7:0] U_jP3;
logic [7:0] U_jP5;

logic [17:0] ACC_V;
logic [7:0] Reg_v;
logic [7:0] Reg_v2;

logic [7:0] V_j5;
logic [7:0] V_j3;
logic [7:0] V_j1;
logic [7:0] V_jP1;
logic [7:0] V_jP3;
logic [7:0] V_jP5;


//Reg_y_even
logic [15:0] CSC_even_Y;
logic[15:0] CSC_even_U;
logic[15:0] CSC_even_V;

logic[7:0] R_even;
logic[7:0] G_even;
logic[7:0] B_even;

logic [17:0] output_csc_even_R;
logic [17:0] output_csc_even_G;
logic [17:0] output_csc_even_B;


//Reg_y_odd
logic[15:0] CSC_odd_Y;
logic[15:0] CSC_odd_U;
logic[15:0] CSC_odd_V;

logic[7:0] R_odd;
logic[7:0] G_odd;
logic[7:0] B_odd;

logic [17:0] output_csc_odd_R;
logic [17:0] output_csc_odd_G;
logic [17:0] output_csc_odd_B;


///////////////////////////////////////////////////////////////////////////////

// For Push button
logic [3:0] PB_pushed;

// For VGA SRAM interface
logic VGA_enable;
logic [17:0] VGA_base_address;
logic [17:0] VGA_SRAM_address;
logic VGA_adjust;

// For SRAM
logic [17:0] SRAM_address;
logic [15:0] SRAM_write_data;
logic SRAM_we_n;
logic [15:0] SRAM_read_data;
logic SRAM_ready;

// For UART SRAM interface
logic UART_rx_enable;
logic UART_rx_initialize;
logic [17:0] UART_SRAM_address;
logic [15:0] UART_SRAM_write_data;
logic UART_SRAM_we_n;
logic [25:0] UART_timer;

logic [6:0] value_7_segment [7:0];

// For error detection in UART
logic [3:0] Frame_error;

// For disabling UART transmit
assign UART_TX_O = 1'b1;

assign resetn = ~SWITCH_I[17] && SRAM_ready;

// Push Button unit
PB_Controller PB_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.PB_signal(PUSH_BUTTON_I),	
	.PB_pushed(PB_pushed)
);

// VGA SRAM interface
VGA_SRAM_interface VGA_unit (
	.Clock(CLOCK_50_I),
	.Resetn(resetn),
	.VGA_enable(VGA_enable),
	.VGA_adjust(VGA_adjust),
   
	// For accessing SRAM
	.SRAM_base_address(VGA_base_address),
	.SRAM_address(VGA_SRAM_address),
	.SRAM_read_data(SRAM_read_data),
   
	// To VGA pins
	.VGA_CLOCK_O(VGA_CLOCK_O),
	.VGA_HSYNC_O(VGA_HSYNC_O),
	.VGA_VSYNC_O(VGA_VSYNC_O),
	.VGA_BLANK_O(VGA_BLANK_O),
	.VGA_SYNC_O(VGA_SYNC_O),
	.VGA_RED_O(VGA_RED_O),
	.VGA_GREEN_O(VGA_GREEN_O),
	.VGA_BLUE_O(VGA_BLUE_O)
);

// UART SRAM interface
UART_SRAM_interface UART_unit(
	.Clock(CLOCK_50_I),
	.Resetn(resetn), 
   
	.UART_RX_I(UART_RX_I),
	.Initialize(UART_rx_initialize),
	.Enable(UART_rx_enable),
   
	// For accessing SRAM
	.SRAM_address(UART_SRAM_address),
	.SRAM_write_data(UART_SRAM_write_data),
	.SRAM_we_n(UART_SRAM_we_n),
	.Frame_error(Frame_error)
);

// SRAM unit
SRAM_Controller SRAM_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_address),
	.SRAM_write_data(SRAM_write_data),
	.SRAM_we_n(SRAM_we_n),
	.SRAM_read_data(SRAM_read_data),		
	.SRAM_ready(SRAM_ready),
		
	// To the SRAM pins
	.SRAM_DATA_IO(SRAM_DATA_IO),
	.SRAM_ADDRESS_O(SRAM_ADDRESS_O),
	.SRAM_UB_N_O(SRAM_UB_N_O),
	.SRAM_LB_N_O(SRAM_LB_N_O),
	.SRAM_WE_N_O(SRAM_WE_N_O),
	.SRAM_CE_N_O(SRAM_CE_N_O),
	.SRAM_OE_N_O(SRAM_OE_N_O)
);

//some startbit for our FSM (interpol/CSC starter)
assign start=1'b1;

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		//OUR RESET VARIABLES
	end else begin
			case (top_state)
		S_IDLE: begin
			if (start)begin
				//retrieve u0 u1
				SRAM_address <= U_EVEN_OFFSET;
				SRAM_we_n <= 1'b1;
				top_state <= S_INTI_FSM;
			end else begin
				top_state <= S_IDLE;
			end
		end
		
		S_INTI_FSM:begin
			//retrieve u2 u3
			SRAM_address <= U_EVEN_OFFSET + 18'd1;
			SRAM_we_n <= 1'b1;
			top_state <= S_INTI_FSM_1;			
		end

		S_INTI_FSM_1:begin
			SRAM_address <= V_EVEN_OFFSET;//v0 v1
			SRAM_we_n <= 1'b1;
			top_state <= S_INTI_INT_U;
		end

		S_INTI_INT_U:begin
			SRAM_address <= V_EVEN_OFFSET + 18'd1; //v2 v3

			U_j5 <= SRAM_read_data[15:8];//u0
			U_j3 <= SRAM_read_data[15:8];
			U_j1 <= SRAM_read_data[15:8];
			U_jP1 <= SRAM_read_data[7:0];//u1

			CSC_even_U <= SRAM_read_data;//u0 u1

			top_state <= S_INTI_INT_U_1;
		end

		S_INTI_INT_U_1:begin
			SRAM_address <= U_EVEN_OFFSET + 18'd2; //u4 u5
			
			U_jP3 <= SRAM_read_data[15:8]; //u2
			U_jP5 <= SRAM_read_data[7:0]; //u3 most sign locations
			
			top_state <= S_INTI_INT_V;
		end
		
		S_INTI_INT_V:begin
			SRAM_address <= V_EVEN_OFFSET + 18'd2; //v4 v5 u5			

			V_j5 <= SRAM_read_data[15:8];//v0
			V_j3 <= SRAM_read_data[15:8];
			V_j1 <= SRAM_read_data[15:8];
			V_jP1 <= SRAM_read_data[7:0];//v1

			CSC_even_V <= SRAM_read_data;//v0 v1


			top_state <= S_INTI_INT_V_1;
		end
		
		S_INTI_INT_V_1:begin
			SRAM_address <= Y_OFFSET; //y0 y1
			Y_data_count <= Y_data_count + 18'd1;

			V_jP3 <= SRAM_read_data[15:8];//v2
			V_jP5 <= SRAM_read_data[7:0];//v3
			
			top_state <= S_INTI_INTERPOLATION;			
		end
		
		S_INTI_INTERPOLATION:begin
			//interpolation begins with adding 128
			ACC_U <= 18'd128;
			ACC_V <= 18'd128;

			//U4 U5 have arrived
			Reg_u <= SRAM_read_data[15:8];//u4
			Reg_u2 <= SRAM_read_data[7:0];//u5

			//set up u_const_select,V_const_select 
			// 21 for next c.c.
			const_select <= 2'b00;
			
			top_state <= S_INTI_INTERPOLATION_1;
		end

		S_INTI_INTERPOLATION_1:begin
			//V4 V5 have arrived
			Reg_v <= SRAM_read_data[15:8];//v4
			Reg_v2 <= SRAM_read_data[7:0];//v5

			//set up u_const_select,V_const_select 
			// 52 for next c.c.
			const_select <= 2'b01;			

			//u BRANCH
			U_j5 <= U_j3;//U0
			U_j3 <= U_j1;//U0
			U_j1 <= U_jP1;//U1
			U_jP1 <= U_jP3;//U2
			U_jP3 <= U_jP5;//U3
			U_jP5 <= Reg_u; //U4
			ACC_U <= U_output;// ACC_U + 21*U_j5; //acc+u0

			//v BRANCH
			V_j5 <= V_j3;//V0
			V_j3 <= V_j1;//V0
			V_j1 <= V_jP1;//V1
			V_jP1 <= V_jP3;//V2
			V_jP3 <= V_jP5;//V3
			V_jP5 <= SRAM_read_data[7:0]; //V4
			ACC_V <= V_output;//ACC_V + 21*V_j5; //acc+V0
			
			top_state <= S_INTI_INTERPOLATION_2;	
		end

		S_INTI_INTERPOLATION_2: begin
			//set up u_const_select,V_const_select 
			// 159 for next c.c
			const_select <= 2'b10;	
			
			//u BRANCH
			U_j5 <= U_j3;//U0
			U_j3 <= U_j1;//U0
			U_j1 <= U_jP1;//U1
			U_jP1 <= U_jP3;//U2
			U_jP3 <= U_jP5;//U3
			U_jP5 <= U_j5; //U4
			ACC_U <= U_output;// ACC_U - 52*U_j5; //acc+u0

			//v BRANCH
			V_j5 <= V_j3;//V0
			V_j3 <= V_j1;//V0
			V_j1 <= V_jP1;//V1
			V_jP1 <= V_jP3;//V2
			V_jP3 <= V_jP5;//V3
			V_jP5 <= V_j5; //V4
			ACC_V <= V_output;// ACC_V + V_j5; //acc+V0

			CSC_even_Y <= SRAM_read_data[15:8]-8'd16;
			CSC_odd_Y <= SRAM_read_data[7:0]-8'd16;
			
			top_state <= S_INTI_INTERPOLATION_3;
		end

		S_INTI_INTERPOLATION_3: begin
			//set up u_const_select,V_const_select 
			// 159 for next c.c
			const_select <= 2'b10;

			//u BRANCH
			U_j5 <= U_j3;//U0
			U_j3 <= U_j1;//U1
			U_j1 <= U_jP1;//U2
			U_jP1 <= U_jP3;//U3
			U_jP3 <= U_jP5;//U4
			U_jP5 <= U_j5; //U0
			ACC_U <= U_output;// ACC_U + 159*U_j5; //acc+u0

			//v BRANCH
			V_j5 <= V_j3;//V0
			V_j3 <= V_j1;//V0
			V_j1 <= V_jP1;//V1
			V_jP1 <= V_jP3;//V2
			V_jP3 <= V_jP5;//V3
			V_jP5 <= V_j5; //V4
			ACC_V <= V_output;// ACC_V + V_j5; //acc+V0
			
			top_state <= S_INTI_INTERPOLATION_4;
		end

		S_INTI_INTERPOLATION_4:begin
			//set up u_const_select,V_const_select 
			// 52 for next c.c
			const_select <= 2'b01;

			//u BRANCH
			U_j5 <= U_j3;//U1
			U_j3 <= U_j1;//U2
			U_j1 <= U_jP1;//U3
			U_jP1 <= U_jP3;//U4
			U_jP3 <= U_jP5;//U0
			U_jP5 <= U_j5; //U0
			ACC_U <= U_output;// ACC_U + 159*U_j5; //acc+u0

			//v BRANCH
			V_j5 <= V_j3;//V0
			V_j3 <= V_j1;//V0
			V_j1 <= V_jP1;//V1
			V_jP1 <= V_jP3;//V2
			V_jP3 <= V_jP5;//V3
			V_jP5 <= V_j5; //V4
			ACC_V <= V_output;//ACC_V - 59*V_j5; //acc+V0
			
			top_state <= S_INTI_INTERPOLATION_5;
		end

		S_INTI_INTERPOLATION_5:begin
			//set up u_const_select,V_const_select 
			// 21 for next c.c
			const_select <= 2'b00;

			//u BRANCH
			U_j5 <= U_j3;//U2
			U_j3 <= U_j1;//U3
			U_j1 <= U_jP1;//U4
			U_jP1 <= U_jP3;//U0
			U_jP3 <= U_jP5;//U0
			U_jP5 <= U_j5; //U1
			ACC_U <= U_output;// ACC_U + 21*U_j5; //acc+u0

			//v BRANCH
			V_j5 <= V_j3;//V0
			V_j3 <= V_j1;//V0
			V_j1 <= V_jP1;//V1
			V_jP1 <= V_jP3;//V2
			V_jP3 <= V_jP5;//V3
			V_jP5 <= V_j5; //V4
			ACC_V <= V_output;//ACC_V + V_j5; //acc+V0
			
			top_state <= S_INTI_INTERPOLATION_6;
		end

		S_INTI_INTERPOLATION_6:begin

			write_count <= 18'd0;
			data_count <= 18'd3;
			csc_const_select <= 3'b000; //pick 76284
			csc_even_val_select <= 2'b00; //pick even Y with -16 already
			csc_odd_val_select <= 2'b00; //pick odd Y with -16 already
			// const_select doest matter since we arent accumulating

			//u BRANCH
			U_j5 <= U_j3;//U3
			U_j3 <= U_j1;//U4
			U_j1 <= U_jP1;//U0
			U_jP1 <= U_jP3;//U0
			U_jP3 <= U_jP5;//U1
			U_jP5 <= U_j5; //U2
			ACC_U <= U_output; //acc+u0

			//v BRANCH
			V_j5 <= V_j3;//V0
			V_j3 <= V_j1;//V0
			V_j1 <= V_jP1;//V1
			V_jP1 <= V_jP3;//V2
			V_jP3 <= V_jP5;//V3
			V_jP5 <= V_j5; //V4
			ACC_V <=V_output;// ACC_V + V_j5; //acc+V0

			R_even<=0;//reset values to 0 for new csc
			G_even<=0;
			B_even<=0;
			
			top_state <= S_CYC_CSC_INT;
		end
		// first cycle state out of the 14...
		S_CYC_CSC_INT:begin
			SRAM_address <= U_EVEN_OFFSET + data_count;//u6 u7
			
			//mux select lines:
			csc_const_select <= 3'b100; //pick 104595
			csc_even_val_select <= 2'b10; //pick V (minus 128 from it)
			csc_odd_val_select <= 2'b10; //pick interpolated V with -128 already 
			const_select <= 2'b00;//pick 21
			

			//u BRANCH
			U_j5 <= U_j3;//U4
			U_j3 <= U_j1;//U0
			U_j1 <= U_jP1;//U0
			U_jP1 <= U_jP3;//U1
			U_jP3 <= U_jP5;//U2
			U_jP5 <= U_j5; //U3
			ACC_U <= 18'd128; //128

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= 18'd128;

			// the interpolated odd pixel thats used in the input of the 				// CSC
			CSC_odd_U <= (ACC_U - 18'd128);
			CSC_odd_V <= (ACC_V - 18'd128);

			// CSC even branch
			R_even <= output_csc_even_R;
			G_even <= output_csc_even_G;
			B_even <= output_csc_even_B;

			//CSC odd branch
			R_odd <= output_csc_odd_R;
			G_odd <= output_csc_odd_G;
			B_odd <= output_csc_odd_B;

			top_state <= S_CYC_CSC_INT_1;
		end
		
		S_CYC_CSC_INT_1:begin
			SRAM_address <= V_EVEN_OFFSET + data_count;//v6 v7
			
			//mux select lines:
			csc_const_select <= 3'b010; //pick 25624
			csc_even_val_select <= 2'b01; //pick U (minus 128 from it)
			csc_odd_val_select <= 2'b01; //pick interpolated U
			const_select <= 2'b01;//pick 52

			//u BRANCH -loading state
			U_j5 <= U_j3;//U0
			U_j3 <= U_j1;//U0
			U_j1 <= U_jP1;//U1
			U_jP1 <= U_jP3;//U2
			U_jP3 <= U_jP5;//U3
			U_jP5 <= Reg_u2; //U4
			ACC_U <= U_output; //128 + 21*U_j5

			//v BRANCH -loading state
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= Reg_v2; 
			ACC_V <= V_output;

			// CSC even branch
			R_even <= output_csc_even_R;
			G_even <= output_csc_even_G;
			B_even <= output_csc_even_B;

			//CSC odd branch
			R_odd <= output_csc_odd_R;
			G_odd <= output_csc_odd_G;
			B_odd <= output_csc_odd_B;

			top_state <= S_CYC_CSC_INT_2;
		end

		S_CYC_CSC_INT_2:begin
			SRAM_address <= Y_OFFSET + Y_data_count;//y2 y3
			Y_data_count <= Y_data_count + 18'd1;
			
			//mux select lines:
			csc_const_select <= 3'b100; //pick 53281
			csc_even_val_select <= 2'b10; //pick V (minus 128 from it)
			csc_odd_val_select <= 2'b10; //pick interpolated V
			const_select <= 2'b10;//pick 159

			//u BRANCH
			U_j5 <= U_j3;//U0
			U_j3 <= U_j1;//U1
			U_j1 <= U_jP1;//U2
			U_jP1 <= U_jP3;//U3
			U_jP3 <= U_jP5;//U4
			U_jP5 <= U_j5; //U5
			ACC_U <= U_output; //128+U_j5*21 - U_j5*52

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			// CSC even branch
			R_even <= output_csc_even_R;
			G_even <= output_csc_even_G;
			B_even <= output_csc_even_B;

			//CSC odd branch
			R_odd <= output_csc_odd_R;
			G_odd <= output_csc_odd_G;
			B_odd <= output_csc_odd_B;

			top_state <= S_CYC_CSC_INT_3;
		end

		S_CYC_CSC_INT_3:begin
			//mux select lines:
			csc_const_select <= 3'b010; //pick 132251
			csc_even_val_select <= 2'b01; //pick U (minus 128 from it)
			csc_odd_val_select <= 2'b01; //pick interpolated U
			const_select <= 2'b10;//pick 159

			//the new Even U values have arrived 
			//(for interpolation)
			Reg_u <= SRAM_read_data[15:8];
			Reg_u2 <= SRAM_read_data[7:0];
		
			//u BRANCH
			U_j5 <= U_j3;//U1
			U_j3 <= U_j1;//U2
			U_j1 <= U_jP1;//U3
			U_jP1 <= U_jP3;//U4
			U_jP3 <= U_jP5;//U5
			U_jP5 <= U_j5; //U0
			ACC_U <= U_output; //128+U_j5*21-U_j5*52 + 159*U_j5

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			// CSC even branch
			R_even <= output_csc_even_R;
			G_even <= output_csc_even_G;
			B_even <= output_csc_even_B;

			//CSC odd branch
			R_odd <= output_csc_odd_R;
			G_odd <= output_csc_odd_G;
			B_odd <= output_csc_odd_B;

			top_state <= S_CYC_CSC_INT_4;
		end
		
		S_CYC_CSC_INT_4:begin
			//first write cycle:
			//DATA IS divided by 65536, after matric multiplication
			//right before data output
			write_count <= write_count + 18'd1;
			SRAM_address <= RGB_OFFSET + write_count;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {R_even>>16,G_even>>16};
			

			//mux select lines:
			//csc_const_select we arent going to use next c.c.
			//csc_even_val_select we arent going to use next c.c.
			//csc_odd_val_select we arent going to use next c.c.
			const_select <= 2'b01;//pick 52

			//the new Even V values have arrived 
			//(for interpolation)
			Reg_v <= SRAM_read_data[15:8];
			Reg_v2 <= SRAM_read_data[7:0];

			//u BRANCH
			U_j5 <= U_j3;//U2
			U_j3 <= U_j1;//U3
			U_j1 <= U_jP1;//U4
			U_jP1 <= U_jP3;//U5
			U_jP3 <= U_jP5;//U0
			U_jP5 <= U_j5; //U1
			ACC_U <= U_output; //128+U_j5*21-U_j5*52+U_j5*159+U_j5*159

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			top_state <= S_CYC_CSC_INT_5;
		end
		
		S_CYC_CSC_INT_5:begin
			write_count <= write_count + 18'd1;
			SRAM_address <= RGB_OFFSET + write_count;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {B_even>>16,R_odd>>16};

			//Y arrives
			//for CSC
			CSC_even_Y <= SRAM_read_data[15:8]-8'd16;
			CSC_odd_Y <= SRAM_read_data[7:0]-8'd16;
			

			//mux select lines:
			//csc_const_select we arent going to use next c.c.
			//csc_even_val_select we arent going to use next c.c.
			//csc_odd_val_select we arent going to use next c.c.
			const_select <= 2'b00;//pick 21

			//u BRANCH
			U_j5 <= U_j3;//U3
			U_j3 <= U_j1;//U4
			U_j1 <= U_jP1;//U5
			U_jP1 <= U_jP3;//U0
			U_jP3 <= U_jP5;//U1
			U_jP5 <= U_j5; //U2
			ACC_U <= U_output; //128+U_j5*21-U_j5*52+U_j5*159+U_j5*159 - U_j5*52

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			top_state <= S_CYC_CSC_INT_6;
		end

		S_CYC_CSC_INT_6:begin
			write_count <= write_count + 18'd1;
			SRAM_address <= RGB_OFFSET + write_count;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {G_odd>>16,B_odd>>16};
			

			csc_const_select <= 3'b000; //pick 76284
			csc_even_val_select <= 2'b00; //pick even Y with -16 already
			csc_odd_val_select <= 2'b00; //pick odd Y with -16 already
			// const_select doest matter since we arent accumulating

			//u BRANCH
			U_j5 <= U_j3;//U3
			U_j3 <= U_j1;//U4
			U_j1 <= U_jP1;//U5
			U_jP1 <= U_jP3;//U0
			U_jP3 <= U_jP5;//U1
			U_jP5 <= U_j5; //U2
			ACC_U <= U_output; //128+U_j5*21-U_j5*52+U_j5*159+U_j5*159-U_j5*52 + 21*U_j5

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			// CSC even branch
			R_even <= 8'd0;
			G_even <= 8'd0;
			B_even <= 8'd0;

			//CSC odd branch
			R_odd <= 8'd0;
			G_odd <= 8'd0;
			B_odd <= 8'd0;
			
			top_state <= S_CYC_TWO_CSC_INT;
		end

		S_CYC_TWO_CSC_INT:begin
			//first state of cycle 2, 7/14...
			SRAM_address <= Y_OFFSET + Y_data_count;
			Y_data_count <= Y_data_count + 18'd1;
			SRAM_we_n <= 1'b1;
			
			//mux select lines:
			csc_const_select <= 3'b100; //pick 104595
			csc_even_val_select <= 2'b10; //pick V (minus 128 from it)
			csc_odd_val_select <= 2'b10; //pick interpolated V with -128 already 
			const_select <= 2'b00;//pick 21
			

			//u BRANCH
			U_j5 <= U_j3;//U4
			U_j3 <= U_j1;//U0
			U_j1 <= U_jP1;//U0
			U_jP1 <= U_jP3;//U1
			U_jP3 <= U_jP5;//U2
			U_jP5 <= U_j5; //U3
			ACC_U <= 18'd128; //128

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= 18'd128;

			// the interpolated odd pixel thats used in the input of the 				// CSC
			CSC_odd_U <= (ACC_U - 18'd128);
			CSC_odd_V <= (ACC_V - 18'd128);

			// CSC even branch
			R_even <= output_csc_even_R;
			G_even <= output_csc_even_G;
			B_even <= output_csc_even_B;

			//CSC odd branch
			R_odd <= output_csc_odd_R;
			G_odd <= output_csc_odd_G;
			B_odd <= output_csc_odd_B;

			top_state <= S_CYC_TWO_CSC_INT_1;

		end

		S_CYC_TWO_CSC_INT_1:begin
			//retriving old non-buffered values for even CSC pixel output
			SRAM_address <= U_EVEN_OFFSET + (data_count-18'd2);
			
			//mux select lines:
			csc_const_select <= 3'b010; //pick 25624
			csc_even_val_select <= 2'b01; //pick U (minus 128 from it)
			csc_odd_val_select <= 2'b01; //pick interpolated U
			const_select <= 2'b01;//pick 52

			//u BRANCH -loading state
			U_j5 <= U_j3;//U0
			U_j3 <= U_j1;//U0
			U_j1 <= U_jP1;//U1
			U_jP1 <= U_jP3;//U2
			U_jP3 <= U_jP5;//U3
			U_jP5 <= Reg_u; //U4
			ACC_U <= U_output; //128

			//v BRANCH - loading state
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= Reg_v; 
			ACC_V <= V_output;

			// CSC even branch
			R_even <= output_csc_even_R;
			G_even <= output_csc_even_G;
			B_even <= output_csc_even_B;

			//CSC odd branch
			R_odd <= output_csc_odd_R;
			G_odd <= output_csc_odd_G;
			B_odd <= output_csc_odd_B;

			top_state <= S_CYC_TWO_CSC_INT_2;
		end
		
		S_CYC_TWO_CSC_INT_2:begin
			//retriving old non-buffered values for even CSC pixel output
			SRAM_address <= V_EVEN_OFFSET + data_count - 18'd2;
			
			//mux select lines:
			csc_const_select <= 3'b100; //pick 53281
			csc_even_val_select <= 2'b10; //pick V (minus 128 from it)
			csc_odd_val_select <= 2'b10; //pick interpolated V
			const_select <= 2'b10;//pick 159

			//u BRANCH
			U_j5 <= U_j3;//U0
			U_j3 <= U_j1;//U1
			U_j1 <= U_jP1;//U2
			U_jP1 <= U_jP3;//U3
			U_jP3 <= U_jP5;//U4
			U_jP5 <= U_j5; //U5
			ACC_U <= U_output; //128+U_j5*21

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			// CSC even branch
			R_even <= output_csc_even_R;
			G_even <= output_csc_even_G;
			B_even <= output_csc_even_B;

			//CSC odd branch
			R_odd <= output_csc_odd_R;
			G_odd <= output_csc_odd_G;
			B_odd <= output_csc_odd_B;

			top_state <= S_CYC_TWO_CSC_INT_3;
		end

		S_CYC_TWO_CSC_INT_3:begin

			//y arrives
			CSC_even_Y <= SRAM_read_data[15:8]-8'd16;
			CSC_odd_Y <= SRAM_read_data[7:0]-8'd16;

			//mux select lines:
			csc_const_select <= 3'b010; //pick 132251
			csc_even_val_select <= 2'b01; //pick U (minus 128 from it)
			csc_odd_val_select <= 2'b01; //pick interpolated U
			const_select <= 2'b10;//pick 159

			//u BRANCH
			U_j5 <= U_j3;//U1
			U_j3 <= U_j1;//U2
			U_j1 <= U_jP1;//U3
			U_jP1 <= U_jP3;//U4
			U_jP3 <= U_jP5;//U5
			U_jP5 <= U_j5; //U0
			ACC_U <= U_output; //128+U_j5*21-U_j5*52

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			// CSC even branch
			R_even <= output_csc_even_R;
			G_even <= output_csc_even_G;
			B_even <= output_csc_even_B;

			//CSC odd branch
			R_odd <= output_csc_odd_R;
			G_odd <= output_csc_odd_G;
			B_odd <= output_csc_odd_B;

			top_state <= S_CYC_TWO_CSC_INT_4;
		end

		S_CYC_TWO_CSC_INT_4:begin
			//first write cycle:
			SRAM_address <= RGB_OFFSET + write_count;
			write_count <= write_count + 18'd1;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {R_even>>16,G_even>>16};
			
			//CSC even for U values arrive
			CSC_even_U <= SRAM_read_data;

			//mux select lines:
			//csc_const_select we arent going to use next c.c.
			//csc_even_val_select we arent going to use next c.c.
			//csc_odd_val_select we arent going to use next c.c.
			const_select <= 2'b01;//pick 52

			//u BRANCH
			U_j5 <= U_j3;//U2
			U_j3 <= U_j1;//U3
			U_j1 <= U_jP1;//U4
			U_jP1 <= U_jP3;//U5
			U_jP3 <= U_jP5;//U0
			U_jP5 <= U_j5; //U1
			ACC_U <= U_output; //128+U_j5*21-U_j5*52+U_j5*159

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			top_state <= S_CYC_TWO_CSC_INT_5;
		end

		S_CYC_TWO_CSC_INT_5:begin
			SRAM_address <= RGB_OFFSET + write_count;
			write_count <= write_count + 18'd1;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {B_even>>16,R_odd>>16};			

			//CSC even for U values arrive
			CSC_even_V <= SRAM_read_data;

			//mux select lines:
			//csc_const_select we arent going to use next c.c.
			//csc_even_val_select we arent going to use next c.c.
			//csc_odd_val_select we arent going to use next c.c.
			const_select <= 2'b00;//pick 21

			//u BRANCH
			U_j5 <= U_j3;//U3
			U_j3 <= U_j1;//U4
			U_j1 <= U_jP1;//U5
			U_jP1 <= U_jP3;//U0
			U_jP3 <= U_jP5;//U1
			U_jP5 <= U_j5; //U2
			ACC_U <= U_output; //128+U_j5*21-U_j5*52+U_j5*159+U_j5*159

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			top_state <= S_CYC_TWO_CSC_INT_6;
		end

		S_CYC_TWO_CSC_INT_6:begin
			SRAM_address <= RGB_OFFSET + write_count;
			write_count <= write_count + 18'd1;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {G_odd>>16,B_odd>>16};
			

			csc_const_select <= 3'b000; //pick 76284
			csc_even_val_select <= 2'b00; //pick even Y with -16 already
			csc_odd_val_select <= 2'b00; //pick odd Y with -16 already
			// const_select doest matter since we arent accumulating

			//u BRANCH
			U_j5 <= U_j3;//U3
			U_j3 <= U_j1;//U4
			U_j1 <= U_jP1;//U5
			U_jP1 <= U_jP3;//U0
			U_jP3 <= U_jP5;//U1
			U_jP5 <= U_j5; //U2
			ACC_U <= U_output; //128+U_j5*21-U_j5*52+U_j5*159+U_j5*159-U_j5*52

			//v BRANCH
			V_j5 <= V_j3;
			V_j3 <= V_j1;
			V_j1 <= V_jP1;
			V_jP1 <= V_jP3;
			V_jP3 <= V_jP5;
			V_jP5 <= V_j5; 
			ACC_V <= V_output;

			// CSC even branch
			R_even <= 8'd0;
			G_even <= 8'd0;
			B_even <= 8'd0;

			//CSC odd branch
			R_odd <= 8'd0;
			G_odd <= 8'd0;
			B_odd <= 8'd0;

			data_count <= data_count + 18'd1;
			
			//cycling condition
			//if the memory of RGB is almost full (we finished the whole memory)
			// RGB is ready for output...
			// if not keep cycling 1/14
			if(write_count > 18'd115198)begin
				top_state <= S_IDLE;
			end else begin
				top_state <= S_CYC_CSC_INT;
			end
		end
		default: top_state <= S_IDLE;
		endcase
	end
end

logic [1:0] const_select;
logic [31:0] op1,op2,op3,op4;
logic [31:0] U_output, V_output;
logic [63:0] a,b;

//MULTIPLIERS
//u AND v constant selection mux
always_comb begin
	if (const_select == 2'b00)begin
		op1 = 32'd21;
		op3 = 32'd21;
		op2 = U_j5;
		op4 = V_j5;
	
	end else if (const_select == 2'b01)begin
		op1 = 32'd52;
		op3 = 32'd52;
		op2 = U_j5;
		op4 = V_j5;
		
	end else if (const_select == 2'b10)begin
		op1 = 32'd159;
		op3 = 32'd159;
		op2 = U_j5;
		op4 = V_j5;		
		
	end else begin
		op1 = 32'd0;
		op3 = 32'd0;
		op2 = 32'd0;
		op4 = 32'd0;
	end
end

logic[2:0] csc_const_select;
logic [31:0] op5,op6,op7,op8;
logic [31:0] output_csc_even,output_csc_odd;
logic [63:0] c,d;

// CSC constant definitions under csc_const_select
always_comb begin
	if (csc_const_select == 3'b000)begin
		op5 = 32'd76284;
		op7 = 32'd76284;
	end else if (csc_const_select == 3'b001)begin
		op5 = 32'd132251;
		op7 = 32'd132251;	
	end else if (csc_const_select == 3'b010)begin
		op5 = 32'd25624;
		op7 = 32'd25624;
	end else if (csc_const_select == 3'b011)begin
		op5 = 32'd53281;
		op7 = 32'd53281;
	end else if (csc_const_select == 3'b100)begin
		op5 = 32'd104595;
		op7 = 32'd104595;
	end else begin
		op5 = 32'd0;
		op7 = 32'd0;
	end
end

// EVEN ->CSC selection between Y, U, or V
always_comb begin
	if (csc_even_val_select == 2'b00)begin
		op6 = CSC_even_Y;
	end else if (csc_even_val_select == 2'b01)begin
		op6 = (CSC_even_U[15:8]-8'd128);
	end else if (csc_even_val_select == 2'b10)begin
		op6 = (CSC_even_V[15:8]-8'd128);
	end else begin
		op6 = 32'd0;
	end
end

//general multiplier C
assign c = op5*op6;
//MAC unit seperate values for multiplier outputs of even R G B
assign output_csc_even_R = R_even + c;
// constant select [1] gives negative for 25624 53821 in green
assign output_csc_even_G = csc_const_select[1] ? (G_even - c):(G_even + c);
assign output_csc_even_B = B_even + c;

// ODD -> CSC selection between Y, U, or V
always_comb begin
	if (csc_odd_val_select == 2'b00)begin
		op8 = CSC_odd_Y;
	end else if (csc_odd_val_select == 2'b01)begin
		op8 = CSC_odd_U;
	end else if (csc_odd_val_select == 2'b10)begin
		op8 = CSC_odd_V;
	end else begin
		op8 = 32'd0;
	end
end

//general multiplier D
assign d = op7*op8;
//MAC unit seperate values for multiplier outputs of even R G B
assign output_csc_odd_R = R_odd + d;
assign output_csc_odd_G = csc_const_select[1] ? (G_odd - d):(G_odd + d);
assign output_csc_odd_B = B_odd + d;

//general multiplier A
assign a = op1*op2;
//U adder/subtracter depending on: + for 21-00/159-10 (const_select[0]=0)
// - for 52-01 (const_select[0] = 1)
assign U_output = const_select[0] ? (ACC_U - a[31:0]) : (ACC_U + a[31:0]);


//general multiplier B
assign b = op3*op4;
//V multiplier
assign V_output = const_select[0] ? (ACC_V - b[31:0]) : (ACC_V + b[31:0]);

/*
always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		top_state <= S_IDLE;
		
		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;
		UART_timer <= 26'd0;
		
		VGA_enable <= 1'b1;
	end else begin
		UART_rx_initialize <= 1'b0; 
		UART_rx_enable <= 1'b0; 
		
		// Timer for timeout on UART
		// This counter reset itself every time a new data is received on UART
		if (UART_rx_initialize | ~UART_SRAM_we_n) UART_timer <= 26'd0;
		else UART_timer <= UART_timer + 26'd1;

		case (top_state)
		S_IDLE: begin
			VGA_enable <= 1'b1;   
			if (~UART_RX_I | PB_pushed[0]) begin
				// UART detected a signal, or PB0 is pressed
				UART_rx_initialize <= 1'b1;
				
				VGA_enable <= 1'b0;
								
				top_state <= S_ENABLE_UART_RX;
			end
		end
		S_ENABLE_UART_RX: begin
			// Enable the UART receiver
			UART_rx_enable <= 1'b1;
			top_state <= S_WAIT_UART_RX;
		end
		S_WAIT_UART_RX: begin
			if ((UART_timer == 26'd49999999) && (UART_SRAM_address != 18'h00000)) begin
				// Timeout on UART
				UART_rx_initialize <= 1'b1;
				 				
				VGA_enable <= 1'b1;
				top_state <= S_IDLE;
			end
		end
		default: top_state <= S_IDLE;
		endcase
	end
end*/

assign VGA_adjust = SWITCH_I[0];

assign VGA_base_address = 18'd0;

// Give access to SRAM for UART and VGA at appropriate time
//assign SRAM_address = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) 
//						? UART_SRAM_address 
//						: VGA_SRAM_address;

//assign SRAM_write_data = UART_SRAM_write_data;

//assign SRAM_we_n = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) 
//						? UART_SRAM_we_n 
//						: 1'b1;

// 7 segment displays
convert_hex_to_seven_segment unit7 (
	.hex_value(SRAM_read_data[15:12]), 
	.converted_value(value_7_segment[7])
);

convert_hex_to_seven_segment unit6 (
	.hex_value(SRAM_read_data[11:8]), 
	.converted_value(value_7_segment[6])
);

convert_hex_to_seven_segment unit5 (
	.hex_value(SRAM_read_data[7:4]), 
	.converted_value(value_7_segment[5])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(SRAM_read_data[3:0]), 
	.converted_value(value_7_segment[4])
);

convert_hex_to_seven_segment unit3 (
	.hex_value({2'b00, SRAM_address[17:16]}), 
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value(SRAM_address[15:12]), 
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(SRAM_address[11:8]), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(SRAM_address[7:4]), 
	.converted_value(value_7_segment[0])
);

assign   
   SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
   SEVEN_SEGMENT_N_O[1] = value_7_segment[1],
   SEVEN_SEGMENT_N_O[2] = value_7_segment[2],
   SEVEN_SEGMENT_N_O[3] = value_7_segment[3],
   SEVEN_SEGMENT_N_O[4] = value_7_segment[4],
   SEVEN_SEGMENT_N_O[5] = value_7_segment[5],
   SEVEN_SEGMENT_N_O[6] = value_7_segment[6],
   SEVEN_SEGMENT_N_O[7] = value_7_segment[7];

assign LED_GREEN_O = {resetn, VGA_enable, ~SRAM_we_n, Frame_error, top_state};

endmodule
