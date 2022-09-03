# FPGA-Image-Decompressor
Hardware decompressor of an .mic5 -> .bmp uncompressed format. Language: SystemVerilog 

s1: Loss-less decoding and quantization. .mic5 -> .sram_d2
s2: The data is transformed using a inverse discrete cosine transform. .sram_d2 -> .sram_d1
s3: The resulting YUV data is upsampled using horizontal interpolation on even colums to 
odd columns of U and V. Each pixel is then transformed to RGB. 
