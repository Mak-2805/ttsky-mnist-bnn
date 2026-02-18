module reset_pipe(
    input clk,
    input logic async_in_rst,
    output logic sync_out_rst
    );
    //////////////////////////////////////////////////
    //Reset Synchronizer
    /////////////////////////////////////////////////
  
    logic sync_intermediate_rst = 1'b0;

    // Assert asynchronously
    // De-assert synchronously
    always_ff @ (posedge clk or negedge async_in_rst) begin
        if (!async_in_rst) begin
            sync_intermediate_rst <= 'd0;
            sync_out_rst <= 'd0;
        end else begin
            sync_intermediate_rst <= 1'b1;
            sync_out_rst <= sync_intermediate_rst;
        end
    end
endmodule