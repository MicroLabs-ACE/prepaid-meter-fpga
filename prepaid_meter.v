module prepaid_meter (
    input wire clk,                // Clock input
    input wire reset,              // Reset input (SW0)
    input wire sw1,                // Set 25 (SW1)
    input wire sw2,                // Set 50 (SW2)
    input wire sw3,                // Set usage to 100W (SW3)
    input wire sw4,                // Set usage to 1900W (SW4)
    input wire sw5,                // Pause usage (SW5)
    output wire [6:0] hex0,        // 7-segment display segments for digit 0
    output wire [6:0] hex1,        // 7-segment display segments for digit 1
    output wire [6:0] hex2,        // 7-segment display segments for digit 2
    output wire [6:0] hex3,        // 7-segment display segments for digit 3
    output wire low_balance,       // Low balance warning
    output wire green_led          // Green LED control
);

    // Define the constants
    parameter load_unit_25 = 25;
    parameter load_unit_50 = 50;
    parameter consumption_rate_light_bulb = (100 * 0.003 * 5); // 100W * 0.003 units/sec in milliwatts for 5 bulbs
    parameter consumption_rate_ac_unit = (1900 * 0.003);  // 1900W * 0.003 units/sec in milliwatts
    parameter low_balance_threshold = 40;

    // Define the balance register
    reg [15:0] balance = 0;

    // Define consumption counters and rates
    reg [31:0] consumption_counter = 0;
    reg [31:0] accumulated_reduction = 0;
    reg [31:0] consumption_rate = 0;
    parameter consumption_interval = 1000000; // Adjust based on clock frequency

    // Debounce the switches
    reg sw1_prev = 0;
    reg sw2_prev = 0;
    reg sw3_prev = 0;
    reg sw4_prev = 0;
    reg sw5_prev = 0;

    wire sw1_debounced;
    wire sw2_debounced;
    wire sw3_debounced;
    wire sw4_debounced;
    wire sw5_debounced;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sw1_prev <= 0;
            sw2_prev <= 0;
            sw3_prev <= 0;
            sw4_prev <= 0;
            sw5_prev <= 0;
        end else begin
            sw1_prev <= sw1;
            sw2_prev <= sw2;
            sw3_prev <= sw3;
            sw4_prev <= sw4;
            sw5_prev <= sw5;
        end
    end

    assign sw1_debounced = sw1 & ~sw1_prev;
    assign sw2_debounced = sw2 & ~sw2_prev;
    assign sw3_debounced = sw3 & ~sw3_prev;
    assign sw4_debounced = sw4 & ~sw4_prev;
    assign sw5_debounced = sw5 & ~sw5_prev;

    // Update balance on switch press and consumption
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            balance <= 0;
            consumption_counter <= 0;
            accumulated_reduction <= 0;
            consumption_rate <= 0;
        end else begin
            if (sw1_debounced) balance <= balance + load_unit_25;
            if (sw2_debounced) balance <= balance + load_unit_50;
            if (sw3_debounced) consumption_rate <= consumption_rate_light_bulb;
            if (sw4_debounced) consumption_rate <= consumption_rate_ac_unit;
            if (sw5_debounced) consumption_rate <= 0; // Pause usage

            // Simulate consumption
            if (consumption_counter < consumption_interval) begin
                consumption_counter <= consumption_counter + 1;
            end else begin
                consumption_counter <= 0;
                if (balance > 0 && consumption_rate > 0) begin
                    accumulated_reduction <= accumulated_reduction + consumption_rate;
                    if (accumulated_reduction >= 1000) begin
                        balance <= balance - (accumulated_reduction / 1000);
                        accumulated_reduction <= accumulated_reduction % 1000;
                    end
                end
            end
        end
    end

    // Low balance warning
    assign low_balance = (balance < low_balance_threshold) ? 1 : 0;

    // Green LED control
    assign green_led = (consumption_rate == 0) ? 1 : (clk & balance > 0);

    // 7-segment display driver
    function [6:0] seg_decoder;
        input [3:0] digit;
        case (digit)
            4'd0: seg_decoder = 7'b1000000;
            4'd1: seg_decoder = 7'b1111001;
            4'd2: seg_decoder = 7'b0100100;
            4'd3: seg_decoder = 7'b0110000;
            4'd4: seg_decoder = 7'b0011001;
            4'd5: seg_decoder = 7'b0010010;
            4'd6: seg_decoder = 7'b0000010;
            4'd7: seg_decoder = 7'b1111000;
            4'd8: seg_decoder = 7'b0000000;
            4'd9: seg_decoder = 7'b0010000;
            default: seg_decoder = 7'b1111111; // Display off
        endcase
    endfunction

    assign hex0 = seg_decoder(balance % 10);               // Units place
    assign hex1 = seg_decoder((balance / 10) % 10);        // Tens place
    assign hex2 = seg_decoder((balance / 100) % 10);       // Hundreds place
    assign hex3 = seg_decoder((balance / 1000) % 10);      // Thousands place

endmodule
