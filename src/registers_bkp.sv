`timescale 1ns / 1ps

module registers(
    input clk,
    input reset_n,
    input logic [2:0] state,
    input d_in_p,
    input d_in_w,
    output logic [783:0] pixels,
    output logic [71:0] weights1,
    output logic [287:0] weights2,
    output logic [1959:0] weights3,
    output logic load_done
);

    localparam s_IDLE = 3'b000, s_LOAD = 3'b001, s_LAYER_1 = 3'b010, s_LAYER_2 = 3'b011, s_LAYER_3 = 3'b100;

    // logic sync_out_pixel, sync_out_weight;

    // Pipeline stage commented out - inputs are synchronous in simulation
    // pipe u0 (
    //     .clk(clk),
    //     .reset_n(reset_n),
    //     .async_in_p(d_in_p),
    //     .async_in_w(d_in_w),
    //     .async_in_en(1'b1),
    //     .sync_out_p(sync_out_pixel),
    //     .sync_out_w(sync_out_weight),
    //     .sync_out_en()
    // );

    wire sync_out_pixel = d_in_p;
    wire sync_out_weight = d_in_w;

    logic [4:0] row = 'd0;
    logic [4:0] col = 'd0;
    logic pic_done = 'd0;
    
    always @ (posedge clk) begin
        if (!reset_n) begin 
            pixels <= 'd0;
            pic_done <= 1'b0;
            row <= 'd0;
            col <= 'd0;
        end else if (state == s_LOAD && ~pic_done) begin
           pixels[row*28 + col] <= sync_out_pixel;
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
    
    always @ (posedge clk) begin
        if (~reset_n) begin
            weights1 <= 'd0;
            w_done <= 'd0;
            bitt <= 'd0;
            trit <= 'd0;
            level <= 'd0;
        end else if (state == s_LOAD && ~w_done) begin
            weights1[trit*24 + bitt*8 + level] <= sync_out_weight;
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

    logic [1:0] bitt1 = 'd0;
    logic [1:0] trit1 = 'd0;
    logic [1:0] level1 = 'd0;  // 4 filters: 0-3
    logic [2:0] chan1  = 'd0;  // 8 channels: 0-7
    logic w_done1 = 'd0;

    always @ (posedge clk) begin
        if (~reset_n) begin
            weights2 <= 'd0;
            w_done1  <= 'd0;
            bitt1    <= 'd0;
            trit1    <= 'd0;
            level1   <= 'd0;
            chan1     <= 'd0;
        end else if (state == s_LOAD && w_done && ~w_done1) begin
            weights2[level1*72 + (trit1*3 + bitt1)*8 + chan1] <= sync_out_weight;
            if (chan1 < 7) begin
                // Next channel
                chan1 <= chan1 + 1;
            end else begin
                chan1 <= 0;
                if (bitt1 < 2) begin
                    // Next kernel col
                    bitt1 <= bitt1 + 1;
                end else begin
                    bitt1 <= 0;
                    if (trit1 < 2) begin
                        // Next kernel row
                        trit1 <= trit1 + 1;
                    end else begin
                        trit1 <= 0;
                        if (level1 < 3) begin
                            // Next filter
                            level1 <= level1 + 1;
                        end else begin
                            // Full
                            w_done1 <= 1;
                        end
                    end
                end
            end
        end
    end
    
    logic [3:0] neuron_w3 = 'd0;
    logic [7:0] bit_w3 = 'd0;
    logic w_done3 = 'd0;

    always @ (posedge clk) begin
        if (~reset_n) begin
            weights3   <= 'd0;
            w_done3    <= 'd0;
            neuron_w3  <= 'd0;
            bit_w3     <= 'd0;
        end else if (state == s_LOAD && w_done && w_done1 && ~w_done3) begin
            weights3[neuron_w3*196 + bit_w3] <= sync_out_weight;
            if (bit_w3 < 195) begin
                // Still in the same neuron row, move to next bit
                bit_w3 <= bit_w3 + 1;
            end else begin
                // Current neuron row done, move back to bit 0
                bit_w3 <= 0;
                if (neuron_w3 < 9) begin
                    // Next neuron
                    neuron_w3 <= neuron_w3 + 1;
                end else begin
                    // Full
                    w_done3 <= 1;
                end
            end
        end
    end

    assign load_done = (pic_done && w_done && w_done1 && w_done3) ? 1'b1 : 1'b0;

endmodule
