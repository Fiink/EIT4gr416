
import os.path    #System paths and os version
import locale,time         #Encoding and timing
from PIL import Image      #PIP pillow library
import serial
import binascii
from picamera import PiCamera
import struct
import math
start = time.time()



camera = PiCamera()
camera.resolution=(512,512)
camera.rotation =0
camera.ISO = 100
camera.exposure_mode='auto'
camera.contrast=0
camera.sharpness=0

my_path = os.path.abspath(os.path.dirname(__file__)) # relative script path

camera.capture(my_path+"/input/t.jpeg")
print("capture time: {}".format(time.time()-start))
start=time.time()
##############COMPRESS##########

inpath = os.listdir(my_path+"/input") # returns list
uncompressedpath = os.path.join(my_path+"/input",inpath[0])
path = os.path.join(my_path+"/input", "W_Compressed.jpeg")


compress=99  #how many percent to compress (100 - compress

imag = Image.open(uncompressedpath) #original image open
imag = imag.convert("RGB")
imgs = imag.resize((imag.width, imag.height), Image.ANTIALIAS) #make a new image with same size
imgs.save(path, optimize=True,quality=100-compress)      #save a compressed version
print("Time to compress: {}".format(time.time()-start))
start=time.time()

###############PREPARE TO SEND###
fileRead = open(path,'r+b')
inputer = fileRead.read()
fileRead.close()
s=(math.ceil(len(inputer)/2))
rawdata = [b'\x00']*(len(inputer)+s)
for y in range(len(inputer)):
        rawdata[y] =bytes([int(inputer[y])])

########PUT CRC ON THE LIST######
def GenCCITT_CRC16(Buffer):
   numBytes = len(Buffer)
   numBits  = 8
   crcsum   = 0
   temp0    = 0
   temphigh = 0

   polynom = 0x1021

   for byte in range (numBytes):
      try:
              temp0  = ord(Buffer[byte])
      except:
              print("fail")
      temp0  <<= 8
      crcsum ^= temp0

      for bit in range (numBits):
         crcsum   <<= 1
         temphigh =   crcsum
         temphigh &=  0xFFFF0000

         if temphigh > 0:
            crcsum &= 0x0000FFFF
            crcsum ^= polynom
   return(crcsum)

buffer=[]
temp=0
if len(rawdata)%2:
        outputer = [b'\xF0']*int(len(rawdata)+10)
        print("Upper")
else:
        outputer = [b'\x00']*int(len(rawdata)+10)
        print("lower")
print(int((len(outputer))))
print(type(outputer))
#for x in range(int((len(rawdata)/2))):
d=0
f=0
while len(rawdata)>d:
       buffer=[]
       buffer.append(rawdata[f])
       buffer.append(rawdata[f+1])
       temp= '{:04x}'.format(GenCCITT_CRC16(buffer))
       outputer[d+2]=temp
       outputer[d]=rawdata[f]
       outputer[d+1]=rawdata[f+1]
       d+=3
       f+=2

print(outputer)
print("Loading, compressing and preparing to send takes: {}".format(time.time()-start))
start = time.time()

###############TRANSMITTER#######
ser = serial.Serial("/dev/ttyS0",
                    baudrate=115200,
                    bytesize=serial.EIGHTBITS,
                    stopbits=serial.STOPBITS_ONE,
                    timeout=0,
                    dsrdtr=False,
                    parity='N',
                    rtscts=False,
                    xonxoff=False)

a=0
'''
for x in range(len(outputer)):
    ser.write(outputer[x])
if( (len(outputer)%4)):
        for x in range(4-(len(outputer)%4)):
                ser.write(b'\XFF')
                a=x
'''
print("Time to transmit the image to the receiver: {}".format(time.time()-start))
ser.close()
print(len(outputer))
print(a)
print(len(outputer)%4)
print(outputer[len(outputer)-1])
print(outputer[len(outputer)-2])
print(outputer[len(outputer)-3])
print(outputer[len(outputer)-4])
