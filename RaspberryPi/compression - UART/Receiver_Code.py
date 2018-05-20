
import os.path    #System paths and os version
import locale,time         #Encoding and timing
from PIL import Image      #PIP pillow library
import serial

############DECOMPRESS##########
ser = serial.Serial("/dev/ttyS0",
                    baudrate=115200,
                    stopbits=serial.STOPBITS_ONE,
                    timeout=0,
                    parity='N')

outputer=[b'']*1000000
my_path = os.path.abspath(os.path.dirname(__file__)) # relative script path
pathout = os.path.join(my_path+"/output", "output.jpg") # Output image
a=0
temp=b''
type(outputer)
while True:
        temp=ser.read()
        if not temp==b'':
                outputer[a]=temp
                a+=1
        temp=b''
        if(outputer[a-1]==b'\xd9'):
                if (outputer[a-2]==b'\xff'):
                        print("found ff d9")
                        print(type(outputer[0]))
                        file = open(pathout,'w+b')        
                        for s in range(a):
                            file.write(chr(int.from_bytes(outputer[s],byteorder='big')).encode('charmap'))
                        file.close()
                        break

