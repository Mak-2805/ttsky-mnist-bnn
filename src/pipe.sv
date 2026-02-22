module pipe(
    input  wire clk,
    input  wire reset_n,
    input  wire async_in_p,
    input  wire async_in_w,
    input  wire async_in_en,
    output reg  sync_out_p,
    output reg  sync_out_w,
    output reg  sync_out_en
);

    // 3-stage single-bit synchronizer
    reg sync_intermediate_p, sync_intermediate1_p;
    reg sync_intermediate_w, sync_intermediate1_w;
    reg sync_intermediate_en, sync_intermediate1_en;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sync_intermediate_p  <= 1'b0;
            sync_intermediate1_p <= 1'b0;
            sync_out_p           <= 1'b0;

            sync_intermediate_w  <= 1'b0;
            sync_intermediate1_w <= 1'b0;
            sync_out_w           <= 1'b0;

            sync_intermediate_en  <= 1'b0;
            sync_intermediate1_en <= 1'b0;
            sync_out_en           <= 1'b0;
        end else begin
            sync_intermediate_p  <= async_in_p;
            sync_intermediate1_p <= sync_intermediate_p;
            sync_out_p           <= sync_intermediate1_p;

            sync_intermediate_w  <= async_in_w;
            sync_intermediate1_w <= sync_intermediate_w;
            sync_out_w           <= sync_intermediate1_w;

            sync_intermediate_en  <= async_in_en;
            sync_intermediate1_en <= sync_intermediate_en;
            sync_out_en           <= sync_intermediate1_en;
        end
    end

endmodule