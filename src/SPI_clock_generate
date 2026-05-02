module SPI_clock_generate(
  input wire clk, rst, tick_1MHz, enable, cpol, start,
  input wire[4:0] divider, 
  output reg sclk_tick, sclk
);
  reg[4:0] DIVIDER = 4; reg CPOL; 
  reg[4:0] count_smp;
  always@(posedge clk or negedge rst) begin
    if(!rst) begin
      count_smp <= 0; sclk_tick <= 0; sclk <= 0;
      CPOL <= 0; DIVIDER <= 4;
    end else if(start) begin
      DIVIDER <= divider; CPOL <= cpol;
      sclk <= cpol; // Установка начального уровня при старте
      count_smp <= 0;
    end else if(enable && tick_1MHz) begin
      // Считаем до половины делителя (DIVIDER >> 1), чтобы получить 50%
      if(count_smp >= (DIVIDER >> 1) - 1) begin
        sclk_tick <= 1; 
        count_smp <= 0; 
        sclk <= ~sclk; // Инвертируем, только когда счетчик дошел до конца
      end else begin
        sclk_tick <= 0; 
        count_smp <= count_smp + 1; 
      end
    end else begin
      sclk_tick <= 0;
    end
  end
endmodule
