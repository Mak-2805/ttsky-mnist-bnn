module reset_pipe(
    input  wire clk,
    input  wire async_in_rst,
    output reg  sync_out_rst
);
    //////////////////////////////////////////////////
    // Reset Synchronizer: asynchronous assert, synchronous deassert
    //////////////////////////////////////////////////

    reg sync_intermediate_rst;

    always @(posedge clk or negedge async_in_rst) begin
        if (!async_in_rst) begin
            sync_intermediate_rst <= 1'b0;
            sync_out_rst          <= 1'b0;
        end else begin
            sync_intermediate_rst <= 1'b1;
            sync_out_rst          <= sync_intermediate_rst;
        end
    end
endmodule