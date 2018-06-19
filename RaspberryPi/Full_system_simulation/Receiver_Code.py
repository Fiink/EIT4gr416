
import os.path    #System paths and os version
import locale,time         #Encoding and timing
import serial
from PIL import Image

        
#######Code to run#######################
ser = serial.Serial("/dev/ttyS0",
                    baudrate=115200,
                    stopbits=serial.STOPBITS_ONE,
                    timeout=0,
                    parity='N')

outputer=[b'']*100000
my_path = os.path.abspath(os.path.dirname(__file__)) # relative script path
pathout = os.path.join(my_path+"/output", "output.jpg") # Output image
a=0
temp=b''

f=False
count = 0
x=0
checker = False

print("Read values")
temp=b''

while True:
        temp = ser.read()
        if not temp == b'':
           if (x==0):
              start=time.time()
           outputer[x]=temp
           if outputer[x]==b'\xd9':
                   if(outputer[x-1]==b'\xff'):
                           print("found ff d9")
                           outputer[x+1]=ser.read()
                           outputer[x+2]=ser.read()
                           outputer[x+3]=ser.read()
                           outputer[x+4]=ser.read()
                           break
           x+=1
s=0
file = open(pathout,'w+b')
while s < x+1:
        file.write(chr(int.from_bytes(outputer[s],byteorder='big')).encode('charmap'))    
        s+=1
file.close()
print("It took: {} seconds to read and save the image".format(time.time()-start))
print("The destination folder is as following: {}".format(pathout))
