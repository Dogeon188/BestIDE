import serial
from time import sleep
from serial.tools import list_ports

from termcolor import colored
from pygments import highlight as _highlight
from pygments import lexers, formatters

start_byte = 0xCC
end_byte = 0xDD

lexer = lexers.get_lexer_by_name("python")
formatter = formatters.get_formatter_by_name("terminal")
def highlight(code):
    return _highlight(code, lexer, formatter)

scope = {"P": print, "R": range} # pre-defined aliases
def run_code(code):
    try:
        print(highlight(repr(eval(code, scope))), end='')
    except:
        try:
            exec(code, scope)
        except Exception as e:
            raise e
available_ports = list_ports.comports()

# exit if no ports are available
if len(available_ports) == 0:
    print(colored('No available ports. Exiting...', "magenta"))
    exit(1)

print(colored('Available ports:', "cyan"))
for p in available_ports:
    print(colored("  - " + p.name, "yellow"))

port = available_ports[0].name
if len(available_ports) > 1:
    port = input('Enter port name: ')
    if port not in available_ports:
        print('Invalid port name, using default: ', available_ports[0].name)
        port = available_ports[0].name
else:
    print(colored('Using default port:', "cyan"), colored(port, "yellow"))

with serial.Serial(
        port=port,
        baudrate=230400,
        bytesize=serial.EIGHTBITS,
        stopbits=serial.STOPBITS_ONE,
        parity=serial.PARITY_NONE,
) as ser:
    read_bytes = bytes()
    try:
        print(colored(">>> ", "dark_grey"), end='', flush=True)
        while True:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                for b in data:
                    if b == start_byte:
                        read_bytes = bytes()
                    elif b == end_byte:
                        dec = read_bytes.decode('ascii')
                        dec_lines = list(map(lambda x: x.rstrip(), [dec[i:i+20] for i in range(0, 300, 20)]))
                        dec_lines = list(filter(lambda x: x != '', dec_lines))
                        dec_print = list(map(highlight, dec_lines))
                        dec_print = (colored("... ", "dark_grey")).join(dec_print) # multi-line indent
                        print(dec_print == '' and "\n" or dec_print, end='') # handle empty input
                        try:
                            run_code('\n'.join(dec_lines))
                        except Exception as e:
                            print(colored('Error:', "light_red"), colored(e, "light_red"))
                        read_bytes = bytes()
                        print(colored(">>> ", "dark_grey"), end='', flush=True) # prompt
                    else:
                        read_bytes += bytes([b])
            sleep(0.01)
    except KeyboardInterrupt:
        print(colored('\nInterrupted by user. Exiting...', "cyan"))
    except Exception as e:  # assume port closed and exit
        print(colored('\nPort closed. Exiting...', "cyan"))
    finally:
        ser.close()
