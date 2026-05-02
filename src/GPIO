module GPIO_controller(
  input wire clk, rst, button_in, //Тактовый сигнал, сигнал сброса и сигнал от кнопки
  input wire tick_1ms, //Провод для обеспечения опроса
  output reg led_out //Светодиод
);
  reg trig_1, trig_2; //Стабилизация состояния
  reg button_stable, button_stable_prev; //Текущей и предыдущее состояния кнопок
  reg[3:0] count;
  always@(posedge clk or negedge rst) begin
    if(!rst) begin
      led_out <= 0; trig_1 <= 0; trig_2 <= 0; button_stable <= 0;
      button_stable_prev <= 0; count <= 0;
    end else begin
      trig_1 <= button_in; //Сигнал от кнопки
      trig_2 <= trig_1;
      if(tick_1ms) begin
        if(trig_2 != button_stable) begin
          count <= count + 1;
          if(count == 4'd10) begin
            button_stable <= trig_2;
            count <= 0;
          end
        end else begin
          count <= 0;
        end
      end
      //Обработка нажатия кнопки
      button_stable_prev <= button_stable; //Меняем "предыдущее" состояние в конце текущего такта
      if(button_stable != button_stable_prev) begin
        led_out <= ~led_out; //Инверсия состояния в случае, если подаваемый сигнал на кнопку изменился
      end
    end
  end
endmodule
