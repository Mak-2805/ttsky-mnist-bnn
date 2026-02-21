module pipe(
    input clk,
    input reset_n,
    input logic async_in_p,
    input logic async_in_w,
    input logic async_in_en,
    output logic sync_out_p,
    output logic sync_out_w,
    output logic sync_out_en
    );
    //////////////////////////////////////////////////
    //dumbed down 3-stage single bit synchronizer
    /////////////////////////////////////////////////
  
    logic sync_intermediate_p, sync_intermediate1_p;
    logic sync_intermediate_w, sync_intermediate1_w;
    logic sync_intermediate_en, sync_intermediate1_en;

    //uses an asynchronous reset as usual, but can conflict with FSM reset
    //possible fix, create a synchronized reset with this module (instantiate in top, then pass the synchronized reset to the FSM)
    always @ (posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sync_intermediate_p <= 'b0;
            sync_intermediate1_p <= 'b0;
            sync_out_p <= 'b0;
            
            sync_intermediate_w <= 'b0;
            sync_intermediate1_w <= 'b0;
            sync_out_w <= 'b0;

            sync_intermediate_en <= 'b0;
            sync_intermediate1_en <= 'b0;
            sync_out_en <= 'b0;
        end else begin
            sync_intermediate_p <= async_in_p;
            sync_intermediate1_p <= sync_intermediate_p;
            sync_out_p <= sync_intermediate1_p;
            
            sync_intermediate_w <= async_in_w;
            sync_intermediate1_w <= sync_intermediate_w;
            sync_out_w <= sync_intermediate1_w;

            sync_intermediate_en <= async_in_en;
            sync_intermediate1_en <= sync_intermediate_en;
            sync_out_en <= sync_intermediate1_en;
        end
    end
endmodule
