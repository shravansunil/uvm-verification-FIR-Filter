`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 08:19:57 AM
// Design Name: 
// Module Name: FIR_Filter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// Code your design here
//================================================================
// File: design.sv
// Contains: Interface and DUT (FIR Filter)
//================================================================

interface fir_if(input logic clk, input logic reset_n);
    logic valid_in;
    logic signed [15:0] data_in;
    logic valid_out;
    logic signed [31:0] data_out;
endinterface

module FIR_Filter #(parameter N = 4) (
    input  logic clk,
    input  logic reset_n,
    input  logic valid_in,
    input  logic signed [15:0] data_in,
    output logic valid_out,
    output logic signed [31:0] data_out
);
    // Fixed coefficients (Example: Low-pass)
    logic signed [15:0] coeff [0:N-1] = '{16'h0800, 16'h1000, 16'h1000, 16'h0800};
    
    // Delay line and pipeline registers
    logic signed [15:0] delay_line [0:N-1];
    logic signed [31:0] mult_res [0:N-1];
    
    // Valid signal delay line to match the 3-cycle math latency
    logic valid_d1, valid_d2; 
    
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_d1  <= 0;
            valid_d2  <= 0;
            valid_out <= 0;
            data_out  <= 0;
            for (int i=0; i<N; i++) begin
                delay_line[i] <= 0;
                mult_res[i]   <= 0;
            end
        end else begin
            // Shift the valid signal through the pipeline
            valid_d1  <= valid_in;
            valid_d2  <= valid_d1;
            valid_out <= valid_d2; 

            // STAGE 1: Shift register (Only shift if incoming data is valid)
            if (valid_in) begin
                delay_line[0] <= data_in;
                for (int i=1; i<N; i++) delay_line[i] <= delay_line[i-1];
            end
            
            // STAGE 2: Multipliers (Only compute if Stage 1 had valid data)
            if (valid_d1) begin
                for (int i=0; i<N; i++) mult_res[i] <= delay_line[i] * coeff[i];
            end
            
            // STAGE 3: Adder tree (Only compute if Stage 2 had valid data)
            if (valid_d2) begin
                data_out <= mult_res[0] + mult_res[1] + mult_res[2] + mult_res[3];
            end
        end
    end
endmodule