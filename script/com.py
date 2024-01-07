import serial

port = 'COM4'

with serial.Serial(
        port=port,
        baudrate=230400,
        bytesize=serial.EIGHTBITS,
        stopbits=serial.STOPBITS_ONE,
        parity=serial.PARITY_NONE,
) as ser:
    try:
        while True:
            s = input('Input: ')
            ser.write(s.encode("ascii"))
            print(ser.read(1))
    except KeyboardInterrupt:
        ser.close()