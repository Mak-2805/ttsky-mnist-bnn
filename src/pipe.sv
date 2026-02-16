module pipe(
    input clk,
    input reset_n,
    input logic async_in_p,
    input logic async_in_w,
    output logic sync_out_p,
    output logic sync_out_w
    );
    //////////////////////////////////////////////////
    //dumbed down 3-stage single bit synchronizer
    /////////////////////////////////////////////////
  
    logic sync_intermediate_p, sync_intermediate1_p;
    logic sync_intermediate_w, sync_intermediate1_w;

    //uses an asynchronous reset as usual, but can conflict with FSM reset
    //possible fix, create a synchronized reset with this module (instantiate in top, then pass the synchronized reset to the FSM)
    always_ff @ (posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sync_intermediate_p <= 'b0;
            sync_intermediate1_p <= 'b0;
            sync_out_p <= 'b0;
            
            sync_intermediate_w <= 'b0;
            sync_intermediate1_w <= 'b0;
            sync_out_w <= 'b0;
        end else begin
            sync_intermediate_p <= async_in_p;
            sync_intermediate1_p <= sync_intermediate_p;
            sync_out_p <= sync_intermediate1_p;
            
            sync_intermediate_w <= async_in_w;
            sync_intermediate1_w <= sync_intermediate_w;
            sync_out_w <= sync_intermediate1_w;
        end
    end
endmodule
