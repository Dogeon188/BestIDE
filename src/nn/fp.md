Fixed point format

For stored params:
  Tested result: in range -1.5574 to -0.8334
  16 bit fixed point format: SI.FFFFFF FFFFFFFF
     1 sign bit, 1 integer bit, 14 fractional bits
  Range: -2(-32768) to 1.999939(32767)
  Precision: 1/2^14 = 0.00006103515625
  Conversion: fp = int(x * 2^14 + 0.5)

For intermediate values:
  Tested result: in range -75 to 40
  22 bit fixed point format: SI IIIIII.FFFFFFFF FFFFFF
     1 sign bit, 7 integer bits, 14 fractional bits
  Range:      -128(-2097152) to 127.999939(2097151)
  Precision:  1/2^14 = 0.00006103515625
  Conversion: fp = int(x * 2^14 + 0.5)