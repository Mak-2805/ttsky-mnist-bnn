`timescale 1ns / 1ps

module registers(
    input clk,
    input reset_n,
    input en_wr,
    input d_in_p,
    input d_in_w,
    output logic [27:0][27:0] pixels,
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

    logic [4:0] row = 'd0;
    logic [4:0] col = 'd0;
    logic pic_done = 'd0;
    
    always_ff @ (posedge clk) begin
        if (!reset_n) begin 
            pixels <= '{default:'0};
            pic_done <= 1'b0;
        end else if (reset_n && en_wr && ~pic_done) begin
           pixels[row][col] <= sync_out_pixel;
           if (col < 'd27) begin
                col <= col + 1;
           end else begin
                col <= 'd0;
                if (row < 'd27) begin
                    row <= row + 1;
                end else begin
                    pic_done <= 1;
                end
           end
        end 
    end
        
    logic [1:0] bitt = 'd0;    
    logic [1:0] trit = 'd0;
    logic [2:0] level = 'd0;
    logic w_done = 'd0;
    
    always_ff @ (posedge clk) begin
        if (~reset_n) begin
            weights <= '{default:'0};
            w_done <= 'd0;
            bitt <= 'd0;    
            trit <= 'd0;
            level <= 'd0;
        end else if (~w_done && reset_n && en_wr) begin
            weights[level][trit][bitt] <= sync_out_weight;
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
