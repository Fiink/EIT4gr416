import os.path    #System paths and os version
import locale,time         #Encoding and timing
import serial
import binascii

baud=115200

ser = serial.Serial("/dev/ttyS0",
                    baudrate=baud,
                    bytesize=serial.EIGHTBITS,
                    stopbits=serial.STOPBITS_ONE,
                    dsrdtr=False,
                    parity='N',
                    rtscts=False,
                    xonxoff=False)
for x in range(5):
    ser.write(b'\x41')
    ser.write(b'\x42')
    ser.write(b'\x00')
    ser.write(b'\x44')
    ser.write(b'\x45')
    ser.write(b'\x46')
    ser.write(b'\x47')
    ser.write(b'\x48')
    ser.write(b'\x49')
    ser.write(b'\x4A')
ser.write(b'\x41')
ser.close()
print(ser)
print("Done")


