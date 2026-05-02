module clk_divider #(
  parameter CLK_FREQ = 50000000
)(
  input wire clk, input wire rst, //Сигнал для сброса
  output reg tick_1ms, tick_9600, tick_x16, tick_1MHz //Строб сигналы
);
  //Соответсвующие тикам сигналы
  localparam MAX_1ms = CLK_FREQ / 1000;
  localparam MAX_9600 = CLK_FREQ / 9600; //UART-передатчик
  localparam MAX_1MHz = CLK_FREQ / 1000000;
  localparam MAX_x16 = CLK_FREQ / 153600;//UART-приемник
  reg[31:0] count_1ms, count_9600, count_1MHz, count_x16;
  //Обработка тактового сигнала либо сигнала сброса
  always@(posedge clk or negedge rst) begin
    if(!rst) begin
      tick_1ms <= 0; tick_9600 <= 0; tick_1MHz <= 0; count_1ms <= 0;
      count_9600 <= 0; count_1MHz <= 0; count_x16 <= 0; tick_x16 <= 0;
    end else begin
      //Если счетчик достиг нужного значения - генерируем строб-сигнал
      tick_1ms <= (count_1ms == MAX_1ms - 1);
      tick_9600<= (count_9600 == MAX_9600 - 1);
      tick_1MHz <= (count_1MHz == MAX_1MHz - 1);
      tick_x16 <= (count_x16 == MAX_x16 - 1);
      //Либо сбрасываем счетчик, либо увеличиваем
      count_1ms <= tick_1ms ? 0 : count_1ms + 1;
      count_9600 <= tick_9600 ? 0 : count_9600 + 1;
      count_1MHz <= tick_1MHz ? 0 : count_1MHz + 1;
      count_x16 <= tick_x16 ? 0 : count_x16 + 1;
    end
  end
endmodule
