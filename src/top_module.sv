`include "CLK_driver"
`include "GPIO"
`include "UART"
`include "SPI"
`include "UART_receiver"
`include "UART_transmitter"
`include "SPI_clock_generate"
`include "SPI_Core"
module top_module#(
  parameter CLK_FREQ = 50000000
)(
  input  wire clk, rst, miso, rx,
  output wire tx, mosi, sclk, led_out,
  output wire[7:0] cs
);
  wire tick_1ms, tick_9600, tick_x16, tick_1MHz; //Строб сигналы
  
  //Инстанцирование драйвера тиков
  clk_divider #(
    .CLK_FREQ  (CLK_FREQ)
  )clk_driver(
    .clk       (clk),
    .rst       (rst),
    .tick_1ms  (tick_1ms),
    .tick_9600 (tick_9600),
    .tick_x16  (tick_x16),
    .tick_1MHz (tick_1MHz)
  );
  wire spi_busy; //Держим кнопку нажатой в течении всей работы SPI по выдаче
  
  //Инстанцирование GPIO
  GPIO_controller gpio(
    .clk        (clk),
    .rst        (rst),
    .button_in  (spi_busy),
    .tick_1ms   (tick_1ms),
    .led_out    (led_out)
  );
  
  //Соединения UART
  	reg        tx_start;        
	reg [7:0]  tx_data_UART;    
	wire       rx_ready;        
	wire       tx_busy;         
	wire [7:0] rx_data_UART;    

  //Инстанцирование UART
  UART uart_unit (
    .rst       (rst),           
    .clk       (clk),          
    .tick_x16  (tick_x16),      
    .tick_9600 (tick_9600),    
    .rx        (rx),   
    .tx        (tx),   
    .tx_start  (tx_start),      
    .tx_data   (tx_data_UART),  
    .rx_data   (rx_data_UART),  
    .rx_ready  (rx_ready),       
    .tx_busy   (tx_busy)         
	);
  
  //Соединения SPI
  wire[15:0] rx_data;
  reg[15:0] tx_data;
  reg start, start_par, set_par;
  wire done;
  reg LSB_FIRST, CPHA;
  reg CPOL = 0;
  reg[4:0] DIVIDER;
  reg[5:0] DATA_WIDTH;
  reg [2:0] cs_index_reg;
  //Инстанцирование SPI
  SPI spi(
    .clk        (clk),
    .rst        (rst),
    .tick_1MHz  (tick_1MHz),
    .start      (start),
    .miso       (miso),
    .start_par  (start_par),
    .LSB_FIRST  (LSB_FIRST),
    .CPOL       (CPOL),
    .CPHA       (CPHA),
    .set_par    (set_par),
    .tx_data    (tx_data),
    .DIVIDER    (DIVIDER),
    .DATA_WIDTH (DATA_WIDTH),
    .mosi       (mosi),
    .done       (done),
    .busy       (spi_busy),
    .cs         (cs),
    .sclk       (sclk),
    .rx_data    (rx_data)
  );
  
  //Буфферы команд и данных, указетели внутри них, код ошибки
  reg[7:0] buffer_data[0:63];
  reg[7:0] buffer_command[0:63];
  reg[7:0] error_code;
  reg[5:0] data_ptr_wr, command_ptr_wr; //Запись
  reg[5:0] data_ptr_r, command_ptr_r; //Чтение
  reg[4:0] length, save_length, save_length_dup; // Длина блок данных для исполняемой команды
  reg[4:0] count_dupl = 0;
  reg get_length; //Флаг получения длины
  reg spi_confiq; //Флаг завершения настройки SPI
  reg[7:0] buffer_dup[0:31]; reg[4:0] dup_ptr_r, dup_ptr_wr; //Буфер для полнодуплексного обмена и указатель внутри него
  reg[1:0] byte_step; //Смещение в байтах
  reg need_send; //Флаг необходимости отправки данных по UART
  reg spi_start_done; //Флаг старта модуля SPI для отправки
  reg need_dupl; //Флаг необходимости полнодуплексного обмена
  //Состояния
  typedef enum logic[2:0]{START, DATA, REALISE, EXECUTE_SPI, SEND, ASK, ERROR} state_t;
  state_t state, next_state;
  assign cs = (spi_busy) ? ~(8'b1 << cs_index_reg) : 8'hFF;
  //Конечный автомат
  always@(posedge clk or negedge rst) begin
    if(!rst) begin
      data_ptr_wr <= 0; command_ptr_wr <= 0; data_ptr_r <= 0; command_ptr_r <= 0; 
      length <= 0; get_length <= 0; error_code <= 0; state <= START; 
      byte_step <= 1; dup_ptr_r <= 0; dup_ptr_wr <= 0; spi_confiq <= 0; 
      need_send <= 0; save_length_dup <= 0; spi_start_done <= 0; 
      need_dupl <= 0; count_dupl <= 0; cs_index_reg <= 0;
    end else begin
      // Очистка импульсов старта каждый такт
      start <= 0; tx_start <= 0; set_par <= 0; start_par <= 0;
      // Обновление состояния
      state <= next_state;
      case(state)
        START: begin
          if(rx_ready) begin
            buffer_command[command_ptr_wr] <= rx_data_UART;
            command_ptr_wr <= command_ptr_wr + 1;
            next_state <= DATA;
          end
        end
        DATA: begin
          if (rx_ready) begin
            if (!get_length) begin
              length <= rx_data_UART;
              save_length <= rx_data_UART;
              get_length <= 1;
              if (rx_data_UART == 0) begin
                next_state <= REALISE;
                get_length <= 0;
              end
            end else begin
              buffer_data[data_ptr_wr] <= rx_data_UART;
              data_ptr_wr <= data_ptr_wr + 1;
              length <= length - 1;
              if (length == 1) begin
                next_state <= REALISE;
                get_length <= 0;
              end
            end
          end
        end
        REALISE: begin
          case(buffer_command[command_ptr_r])
            8'h01: begin // Делитель
              DIVIDER <= buffer_data[data_ptr_r];
              start_par <= 1;
              data_ptr_r <= data_ptr_r + 1;
              next_state <= ASK;
            end
            8'h02: begin // SPI Обмен
              if(spi_confiq) begin
                if(count_dupl < save_length) begin
                  if(!spi_busy) begin
                    tx_data <= (byte_step == 1) ? buffer_data[data_ptr_r] : {buffer_data[data_ptr_r], buffer_data[data_ptr_r+1]};
                    start <= 1;
                    next_state <= EXECUTE_SPI; // Ждем завершения такта SPI
                  end
                end else begin
                  next_state <= (need_send || need_dupl) ? SEND : ASK;
                end
              end else begin
                error_code <= 8'hA6;
                next_state <= ERROR;
              end
            end
            8'h03: begin // Параметры SPI
              DATA_WIDTH <= buffer_data[data_ptr_r];
              LSB_FIRST <= buffer_data[data_ptr_r+1];
              CPHA <= buffer_data[data_ptr_r+2];
              data_ptr_r <= data_ptr_r + 3;
              spi_confiq <= 1;
              set_par <= 1;
              next_state <= ASK;
            end
           //Настройка параметро SPI: CPOL
           8'h04: begin
             if(save_length != 1) begin
               error_code <= 8'hA1; //Код ошибки - отправка лишних данных
             end else begin
               CPOL <= buffer_data[data_ptr_r]; start_par <= 1;
             end
           end
           //Команда для получения параметров модуля
           8'h05: begin
             buffer_dup[dup_ptr_wr] <= DATA_WIDTH;
             buffer_dup[dup_ptr_wr+1] <= LSB_FIRST;
             buffer_dup[dup_ptr_wr+2] <= CPHA;
             buffer_dup[dup_ptr_wr+3] <= DIVIDER;
             count_dupl <= 4;
             dup_ptr_wr <= dup_ptr_wr + 4;
             need_send <= 1;
             next_state <= SEND;
           end
           //Команда для приведения модуля в состояние полнодуплексного обмена
           8'h06: begin
             need_dupl <= 1;
             count_dupl <= 0;
             next_state <= ASK;
           end
           //Выбор устройства
           8'h07: begin
             cs_index_reg <= buffer_data[data_ptr_r][2:0];
             data_ptr_r <= data_ptr_r + 1;
             next_state <= ASK;
           end
           //Ошибка - отправка неизвестной команды
           default: begin
          	 error_code <= 8'h00;
             next_state <= ERROR;
           end
          endcase
        end
      	EXECUTE_SPI: begin
          if(done) begin
            if(need_dupl) begin
              if(byte_step == 1) buffer_dup[dup_ptr_wr] <= rx_data[7:0];
              else begin
                buffer_dup[dup_ptr_wr] <= rx_data[15:8];
                buffer_dup[dup_ptr_wr + 1] <= rx_data[7:0];
              end
              dup_ptr_wr <= dup_ptr_wr + byte_step;
            end
            data_ptr_r <= data_ptr_r + byte_step;
            count_dupl <= count_dupl + byte_step;
            next_state <= REALISE; // Возвращаемся в цикл команды 02
          end
        end
        SEND: begin
          if(save_length_dup < count_dupl) begin
            if(!tx_busy && !tx_start) begin
              tx_start <= 1;
              tx_data_UART <= buffer_dup[dup_ptr_r];
              save_length_dup <= save_length_dup + 1;
              dup_ptr_r <= dup_ptr_r + 1;
            end
          end else begin
            next_state <= ASK;
          end
        end
        ASK: begin
          if(!tx_busy && !tx_start) begin
            tx_start <= 1;
            tx_data_UART <= (need_send || need_dupl) ? 8'h01 : 8'h02;
            // Сброс флагов после выполнения
            need_send <= 0; need_dupl <= 0; count_dupl <= 0;
            save_length_dup <= 0;
            command_ptr_r <= command_ptr_r + 1; // К следующей команде
            next_state <= START;
          end
        end

        ERROR: begin
          if(!tx_busy && !tx_start) begin
            tx_start <= 1;
            tx_data_UART <= error_code;
            error_code <= 0;
            next_state <= START;
          end
        end
      endcase
    end
  end
endmodule
