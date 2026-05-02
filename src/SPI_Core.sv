module SPI_Core(
  input wire clk, rst, start, miso, lsb_first, cpha, set_par, sclk_tick,
  input wire [15:0] tx_data,
  input wire [5:0] data_width,
  output reg mosi, done, busy, cs, enable,
  output reg [15:0] rx_data
);
  // Состояния
  typedef enum logic [1:0] {IDLE, TRANSFER, STOP} state_t;
  state_t state;
  reg [15:0] shift_reg;
  reg [5:0] count_bit;
  reg [5:0] DATA_WIDTH_REG;
  reg LSB_FIRST_REG, CPHA_REG;
  reg phase; 
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      state <= IDLE;
      busy <= 0; done <= 0; cs <= 1; enable <= 0;
      mosi <= 0; rx_data <= 0;
      {DATA_WIDTH_REG, LSB_FIRST_REG, CPHA_REG} <= 0;
    end else begin
      // Защелкивание параметров
      if (set_par) begin
        DATA_WIDTH_REG <= data_width;
        LSB_FIRST_REG  <= lsb_first;
        CPHA_REG       <= cpha;
      end
      case (state)
        IDLE: begin
          done <= 0;
          if (start && !busy) begin
            busy <= 1;
            cs <= 0;
            enable <= 1;
            count_bit <= 0;
            phase <= 0;
            shift_reg <= tx_data;
            state <= TRANSFER;
            // Выставляем самый первый бит сразу
            mosi <= lsb_first ? tx_data[0] : tx_data[data_width-1];
          end
        end
        TRANSFER: begin
          if (sclk_tick) begin
            phase <= ~phase; // Переключаем полупериод SCLK
            // Условие захвата данных
            if (phase == CPHA_REG) begin
              if (LSB_FIRST_REG)
                shift_reg <= {miso, shift_reg[15:1]};
              else
                shift_reg <= {shift_reg[14:0], miso};
              // Проверка завершения
              if (count_bit == DATA_WIDTH_REG - 1)
                state <= STOP;
              else
                count_bit <= count_bit + 1;
            end 
            // Условие выставления данных
            else begin
              // Выставляем следующий бит из сдвигового регистра
              if (LSB_FIRST_REG)
                mosi <= shift_reg[1]; 
              else
                mosi <= shift_reg[DATA_WIDTH_REG-2];
            end
          end
        end
        STOP: begin
          if (sclk_tick) begin
            done <= 1;
            busy <= 0;
            enable <= 0;
            cs <= 1;
            rx_data <= shift_reg;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule
