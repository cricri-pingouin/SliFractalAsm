# SliFractalAsm
Draw a Mandelbrot set fractal, written in Turbo Delphi (using scanline).

Same as SliFractal:

https://github.com/cricri-pingouin/SliFractal

Except the Mandelbrot set test routine is written in FPU assembly language.

On my PC, for a graph 900x900 pixels, the running times are as follow:
- Original SliFractal, 100% Pascal: 1172ms
- This version, with asm routine for testing if a point belongs to the set (everything else unchanged): 1031ms

Your mileage may vary.

Note that the difference is not great, making you wonder if the difference is worth the extra work given that the Turbo Delphi compiler seems pretty darn optimised! My first few attemps were actually SLOWER than compiled Pascal, and I really had to think about optimising the FPU stack before I would start being better off!
