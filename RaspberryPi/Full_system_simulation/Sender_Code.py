
import os.path    #System paths and os version
import locale,time         #Encoding and timing
from PIL import Image      #PIP pillow library
import serial
import binascii
from picamera import PiCamera
import struct
import math

start = time.time()  #Log current time

camera = PiCamera()
camera.resolution=(512,512)
camera.rotation =0
camera.ISO = 100
camera.exposure_mode='beach'
camera.contrast=0
camera.sharpness=0
camera.brightness=30

my_path = os.path.abspath(os.path.dirname(__file__)) # relative script path

camera.capture(my_path+"/input/t.jpeg")
print("capture time: {}".format(time.time()-start))
start=time.time()
##############COMPRESS##########

inpath = os.listdir(my_path+"/input") # returns list
uncompressedpath = os.path.join(my_path+"/input",inpath[0])
path = os.path.join(my_path+"/input", "W_Compressed.jpeg")


compress=75
#how many percent to compress (100 - compress

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
rawdata = [b'\x00']*(len(inputer)+1)
for y in range(len(inputer)):
        rawdata[y] =bytes([int(inputer[y])])
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
for x in range(len(rawdata)):
    ser.write(rawdata[x])
ser.close()
print("The output consists of: {} bytes, transmitted via a: {} baud rate, taking: {} seconds".format(len(rawdata),ser.baudrate,time.time()-start))
