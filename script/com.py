import serial
import re
from time import sleep
from serial.tools import list_ports

start_byte = 0xCC
end_byte = 0xDD

available_ports = list_ports.comports()
print('Available ports:')
for p in available_ports:
    print("   ", p)

port = available_ports[0].name
if len(available_ports) > 1:
    port = input('Enter port name: ')
    if port not in available_ports:
        print('Invalid port name, using default: ', available_ports[0].name)
        port = available_ports[0].name
else:
    print('Using default port: ', port)

with serial.Serial(
        port=port,
        baudrate=230400,
        bytesize=serial.EIGHTBITS,
        stopbits=serial.STOPBITS_ONE,
        parity=serial.PARITY_NONE,
) as ser:
    read_bytes = bytes()
    try:
        while True:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                for b in data:
                    if b == start_byte:
                        read_bytes = bytes()
                    elif b == end_byte:
                        dec = read_bytes.decode('ascii').strip()
                        dec = re.sub('\\s+(?=([^"]*"[^"]*")*[^"]*$)', " ", dec)
                        print(f"Received: \"{dec}\"")
                        try:
                            exec(dec)
                        except Exception as e:
                            print('Error: ', e)
                        read_bytes = bytes()
                    else:
                        read_bytes += bytes([b])
            sleep(0.01)
    except KeyboardInterrupt:
        print('Exiting...')