`timescale 1ns/1ps

module aes128_top_test;

    // Signals
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    reg [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg ena;
    reg clk;
    reg rst_n;

    // Parameters
    localparam CLK_PERIOD = 10; // 10 ns

    // File handles
    integer data_in_file, key_file, expected_out_file;
    integer scan_result;
    reg sim_done;

    // Instantiate the module under test
    tt_um_AES128 uut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock generation
    always begin
        if (sim_done) begin
            clk = 1'b0;
            #(CLK_PERIOD/2);
        end else begin
            clk = 1'b0;
            #(CLK_PERIOD/2);
            clk = 1'b1;
            #(CLK_PERIOD/2);
        end
    end

    // Main test process
    initial begin
        integer i, vec_count;
        integer data_in_val, key_val, expected_out_val;
        reg [127:0] data_in_vec, key_vec, expected_out_vec;
        reg [7:0] expected_byte, actual_byte;
        integer scan_data, scan_key, scan_exp;

        sim_done = 1'b0;
        vec_count = 0;

        // Initialize
        uio_in = 8'b0;
        ui_in = 8'b0;
        ena = 1'b1;
        rst_n = 1'b0;

        // Reset pulse
        #(CLK_PERIOD * 2);
        rst_n = 1'b1;
        #(CLK_PERIOD);

        // Open files
        data_in_file     = $fopen("data_in.txt", "r");
        key_file         = $fopen("key_in.txt",  "r");
        expected_out_file = $fopen("data_out.txt", "r");

        if (data_in_file == 0 || key_file == 0 || expected_out_file == 0) begin
            $display("ERROR: Could not open test vector files");
            $finish;
        end

        // Seed scan vars so while condition is valid on first evaluation
        scan_data = 1; scan_key = 1; scan_exp = 1;

        // Read and process each test vector
        while (!$feof(data_in_file) && !$feof(key_file) && !$feof(expected_out_file)
               && scan_data == 1 && scan_key == 1 && scan_exp == 1) begin

            // Read hex values from files
            scan_data = $fscanf(data_in_file,      "%h", data_in_vec);
            scan_key  = $fscanf(key_file,           "%h", key_vec);
            scan_exp  = $fscanf(expected_out_file,  "%h", expected_out_vec);

            if (scan_data == 1 && scan_key == 1 && scan_exp == 1) begin

                // Load key bytes
                for (i = 0; i < 16; i = i + 1) begin
                    uio_in = 8'b0;
                    uio_in[5] = 1'b1;
                    uio_in[4:0] = i;
                    ui_in = key_vec[127 - i*8 -: 8];
                    #(CLK_PERIOD);
                end
                uio_in = 8'b0;
                #(CLK_PERIOD);

                // Load plaintext bytes
                for (i = 0; i < 16; i = i + 1) begin
                    uio_in = 8'b0;
                    uio_in[5] = 1'b1;
                    uio_in[4:0] = 16 + i;
                    ui_in = data_in_vec[127 - i*8 -: 8];
                    #(CLK_PERIOD);
                end
                uio_in = 8'b0;
                #(CLK_PERIOD);

                // Pulse start
                uio_in[6] = 1'b1;
                #(CLK_PERIOD);
                uio_in[6] = 1'b0;
                #(CLK_PERIOD);

                // Wait for done flag (uo_out[0] = done bit)
                wait(uo_out[0] == 1'b1);
                #(CLK_PERIOD);

                // Read and verify cipher bytes (MSB first)
                for (i = 0; i < 16; i = i + 1) begin
                    uio_in = 8'b0;
                    uio_in[7] = 1'b1;
                    uio_in[4:0] = i;
                    #(CLK_PERIOD);

                    expected_byte = expected_out_vec[127 - i*8 -: 8];
                    actual_byte   = uo_out;

                    if (actual_byte != expected_byte) begin
                        $display("MISMATCH byte %0d: expected %h, got %h", i, expected_byte, actual_byte);
                    end else begin
                        $display("MATCHED  byte %0d: expected %h, got %h", i, expected_byte, actual_byte);
                    end
                end

                // Prepare for next vector
                uio_in = 8'b0;
                #(CLK_PERIOD);

                vec_count = vec_count + 1;

            end // if scan
        end // while

        // Close files
        $fclose(data_in_file);
        $fclose(key_file);
        $fclose(expected_out_file);

        $display("Done: %0d vectors tested", vec_count);
        sim_done = 1'b1;
        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
