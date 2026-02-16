
module fsm(
    input logic clk, // Top level input
    input logic rst_n, // Top level input
    input logic mode, // Top level input
    input logic load_done,
    input logic layer_1_done,
    input logic layer_2_done,
    input logic layer_3_done,
    output logic [2:0] state
);

    // typedef enum logic [2:0] {
    //     s_IDLE    = 3'b000,
    //     s_LOAD    = 3'b001,
    //     s_LAYER_1 = 3'b010,
    //     s_LAYER_2 = 3'b011,
    //     s_LAYER_3 = 3'b100
    // } state_t;
	
	localparam s_IDLE = 3'b000, s_LOAD = 3'b001, s_LAYER_1 = 3'b010, s_LAYER_2 = 3'b011, s_LAYER_3 = 3'b100;
	
  	// Current state, Next state
    logic [2:0] cs, ns;
    
    always_comb begin
    	case (cs)
      	
        //when we're in idle
        //only load data when mode is load data and we are not processing 
      	s_IDLE: begin
        	if (mode) begin
          	ns = s_LOAD;
        	end else begin
          	ns = cs;
          end
        end
        
        s_LOAD: begin
        	if (load_done) begin
          	ns = s_LAYER_1;
          end else begin
          	ns = cs;
          end
        end
        
        s_LAYER_1: begin
        	if (layer_1_done) begin
          	ns = s_LAYER_2;
          end else begin
          	ns = cs;
          end
        end 
        
        s_LAYER_2: begin
        	if (layer_2_done) begin
          	ns = s_LAYER_3;
          end else begin
          	ns = cs;
          end
        end
        
        s_LAYER_3: begin
        	if (layer_3_done) begin
          	ns = s_IDLE;
          end else begin
          	ns = cs;
          end
        end
        
        default: begin 
            cs = s_IDLE;
        end
      endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
             cs <= s_IDLE;
        end else begin
             cs <= ns;
        end
    end

	// output state to tm
	assign state = cs;

endmodule

