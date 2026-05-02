`timescale 1ns / 100ps
module tb_top;
  localparam CLK_FREQ = 50000000;
  localparam BAUD = 9600;
  localparam BIT_TICKS = CLK_FREQ / BAUD;
  logic clk = 0;
  logic rst = 1;
  logic rx;
  wire  tx, mosi, sclk, led_out;
  wire  [7:0] cs;
  logic [7:0] expected_spi[$]; // Очередь для проверки MOSI
  logic [7:0] expected_uart[$]; // Очередь для проверки ASK
  wire miso_wire;
  assign miso_wire = miso_logic;
  logic miso_logic = 1'bz;
  top_module #(.CLK_FREQ(CLK_FREQ)) dut (
    .clk(clk), .rst(rst), .rx(rx), .miso(miso_wire),
    .tx(tx), .mosi(mosi), .sclk(sclk), .led_out(led_out), .cs(cs)
  );
  always #10 clk = ~clk;
  class Command;
    rand byte cmd;
    rand byte len;
    rand byte data[];
    constraint valid_cmd {cmd inside {1,2,3};} 
    constraint len_c {len inside {[1:10]};}
    constraint data_size {data.size() == len;}
    function new(); data = new[0]; endfunction
  endclass
  //UART
  //Отправка
  task send_byte(input logic[7:0] data);
    begin
      rx = 1'b0; repeat(BIT_TICKS) @(posedge clk);
      for(int i = 0; i < 8; i++) begin
        rx = data[i]; repeat(BIT_TICKS)@(posedge clk);
      end
      rx = 1; repeat(BIT_TICKS) @(posedge clk);
    end
  endtask
  //Получение
  task recv_byte(output logic [7:0] data);
    begin
      @(negedge tx);
      repeat(BIT_TICKS/2) @(posedge clk);
      for (int i = 0; i < 8; i++) begin
        repeat(BIT_TICKS) @(posedge clk);
      data[i] = tx;
      end
      repeat(BIT_TICKS/2) @(posedge clk);
  end
  endtask
  //Класс
  //Отправка команд по UART
  class UART_driver;
  	virtual task send_command(Command c);
    	//Отправляем команду, длину и данные
     	send_byte(c.cmd);
     	send_byte(c.len);
     	case(c.cmd)
      	8'h02: begin
        	foreach(c.data[i]) begin
            expected_spi.push_back(c.data[i]);
          	send_byte(c.data[i]);
          	end
          	expected_uart.push_back(8'h01);
       	end
       	default: begin
         	foreach(c.data[i]) begin
            expected_spi.push_back(c.data[i]);
          	send_byte(c.data[i]);
          	end
          	expected_uart.push_back(8'h02);
       	end
    	endcase
  	endtask
  endclass
  //SPI
  task automatic spi_slave_model(input int cs_idx, input logic[7:0] slave_tx_data);
    logic[7:0] captured_mosi;
    forever begin
      // Ждем активации CS
      wait(cs[cs_idx] == 1'b0);
      $display("[SPI_SLAVE_%0d] Active", cs_idx);
      for(int i = 0; i < 8; i++) begin
        miso_logic = slave_tx_data[7-i];
        @(posedge sclk);
        captured_mosi[7-i] = mosi;
      end
      if(expected_spi.size() > 0) begin
      	logic [7:0] exp = expected_spi.pop_front();
        if(captured_mosi !== exp) begin
        	$error("[SPI_CHECK] [%0t] Slave %0d Mismatch! Got: %h, Exp: %h", $time, cs_idx, captured_mosi, exp);
        end else begin
            $display("[SPI_CHECK] [%0t] Slave %0d PASS: %h", $time, cs_idx, captured_mosi);
        end
      end
      wait(cs[cs_idx] == 1'b1);
      miso_logic = 1'bz;
      $display("[SPI_SLAVE_%0d] Deactivated", cs_idx);
    end
  endtask
  initial begin
    // 1. Инициализация
    UART_driver drv;
    Command cmd;
    clk = 0; rst = 1; rx = 1;
    drv = new();
    cmd = new();
    #200 rst = 0;
    // 2. Запуск устройств
    fork
      spi_slave_model(0, 8'hA5);
      spi_slave_model(1, 8'h5A);
    join_none
    // 3. Основной цикл тестов
    $display("--- STARTING AUTOMATED TEST ---");
    repeat(10) begin
      if (!cmd.randomize()) $fatal("Randomization failed!");
      $display("[TEST_RUN] Sending CMD:%h LEN:%d", cmd.cmd, cmd.len);
      drv.send_command(cmd);
      repeat(BIT_TICKS * (cmd.len + 15)) @(posedge clk);
      #5000; 
    end
    $display("--- ALL TESTS FINISHED ---");
    $finish;
  end
  logic [127:0] FSM_STATE_STR;
  always_comb begin
    case (dut.state)
      3'd0: FSM_STATE_STR = "START/IDLE";
      3'd1: FSM_STATE_STR = "DATA_RCV";
      3'd2: FSM_STATE_STR = "REALISE";
      3'd3: FSM_STATE_STR = "EXEC_SPI";
      3'd4: FSM_STATE_STR = "SEND_UART";
      3'd5: FSM_STATE_STR = "ASK_RET";
      3'd6: FSM_STATE_STR = "ERROR";
      default: FSM_STATE_STR = "UNKNOWN";
    endcase
  end
endmodule
