module fsm(
    input  wire        clk,          // Top level input
    input  wire        rst_n,        // Top level input
    input  wire        mode,         // Top level input
    input  wire        load_done,
    input  wire        layer_1_done,
    input  wire        layer_2_done,
    input  wire        layer_3_done,
    output reg  [2:0]  state
);

    // FSM states
    localparam s_IDLE     = 3'b000,
               s_LOAD     = 3'b001,
               s_LAYER_1  = 3'b010,
               s_LAYER_2  = 3'b011,
               s_LAYER_3  = 3'b100;

    reg [2:0] cs, ns;  // current state, next state

    // -------------------------------
    // Next state logic (combinational)
    // -------------------------------
    always @(*) begin
        ns = cs; // default to hold current state

        case (cs)
            s_IDLE: begin
                if (mode)
                    ns = s_LOAD;
            end

            s_LOAD: begin
                if (load_done)
                    ns = s_LAYER_1;
            end

            s_LAYER_1: begin
                if (layer_1_done)
                    ns = s_LAYER_2;
            end

            s_LAYER_2: begin
                if (layer_2_done)
                    ns = s_LAYER_3;
            end

            s_LAYER_3: begin
                if (layer_3_done)
                    ns = s_IDLE;
            end

            default: ns = s_IDLE;
        endcase
    end

    // -------------------------------
    // State register (sequential)
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cs <= s_IDLE;
        else
            cs <= ns;
    end

    // Output
    always @(*) begin
        state = cs;
    end

endmodule