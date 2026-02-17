`timescale 1ns / 1ps

module registers(
    input clk,
    input reset_n,
    input en_wr,
    input d_in_p,
    input d_in_w,
    output logic [27:0] pixels [0:27],
    output logic [2:0][2:0] weights [0:7],
    output logic load_done,
    );
    
    logic sync_out_pixel, sync_out_weight;
    
    //add a pipeline stage before the filling up of registers
    pipe u0 (
        .clk(clk),
        .reset_n(reset_n),
        .async_in_p(d_in_p),
        .async_in_w(d_in_w),
        .sync_out_p(sync_out_pixel),
        .sync_out_w(sync_out_weight)
    );

    logic [9:0] count = 'd0;
    logic pic_done = 'd0;
    
    always_ff @ (posedge clk or negedge reset_n) begin
        if (!reset_n) begin 
            for (int i = 0; i < 28; i++) pixels[i] <= 'b0;
            pic_done <= 1'b0;
        end else if (reset_n && en_wr && ~pic_done) begin
           pixels[count/28][count % 28] <= sync_out_pixel ;
           if (count == 'b1100001111) begin
               pic_done <= 'b1;
               count <= 'd0;
           end else begin
               count <= count + 1;
           end
        end 
    end
        
    logic [1:0] bitt = 'd0;    
    logic [1:0] trit = 'd0;
    logic [2:0] level = 'd0;
    logic w_done = 'd0;
    
    always_ff @ (posedge clk or negedge reset_n) begin
        if (~reset_n) begin
            for (int i = 0; i < 8; i++)
                for (int j = 0; j < 3; j++)
                    weights[i][j] <= 'b0;
                    w_done <= 0;
                    bitt <= 'd0;    
                    trit <= 'd0;
                    level <= 'd0;
        end else if (~w_done && reset_n && en_wr) begin
            weights[level][trit][bitt] <= 'd1;
            if (bitt < 2) begin
            // Still in the same row, move to next bit
            bitt <= bitt + 1;
        end else begin
            // Current row is done, move back to bit 0
            bitt <= 0;
            if (trit < 2) begin
                // Move to next row
                trit <= trit + 1;
            end else begin
                // Next trit
                trit <= 0;
                if (level < 7) begin
                    // Next vector
                    level <= level + 1;
                end else begin
                    // Full
                    w_done <= 1;
                end
            end
        end
   end
end
    
    assign load_done = (pic_done && w_done) ? 1'b1 : 1'b0; 
   
endmodule
