
import os.path          #System paths
from PIL import Image   #PIP pillow library
import serial              #Enable serial communication

###########COMPRESSION##########################
my_path = os.path.abspath(os.path.dirname(__file__)) # relative script path
inpath = os.listdir(my_path+"/input") # returns list of available images
uncompressedpath = os.path.join(my_path+"/input",inpath[0])
path = os.path.join(my_path+"/input", "W_Compressed.jpeg")

compress=80  #how many percent to compress (100 - compress)

imag = Image.open(uncompressedpath) #original image open
imag = imag.convert("RGB") # Ensures the image is RGB
imgs = imag.resize((imag.width, imag.height), Image.ANTIALIAS) # Copy imag
imgs.save(path, optimize=True,quality=100-compress) #save compressed


########OPEN FILE###############################
fileRead = open(path,'r+b') # open the compressed image as binary
inputer = fileRead.read()   # read the image into array
fileRead.close()            # close the image again
outputer = [0]*len(inputer) # make another array with same lenght as file
for y in range(len(inputer)): # loop lenght of image file
        outputer[y] =format(inputer[y]) # put img into array as integer

#######UART#####################################
baud=115200                #baud rate for communication

ser = serial.Serial("/dev/ttyS0",                 #Port to communicate (I2C UART)
                    baudrate=baud,                #Baud rate
                    bytesize=serial.EIGHTBITS,    #Number of bits / byte
                    stopbits=serial.STOPBITS_ONE, #Number of stop bits
                    dsrdtr=False,                 #Disable handshaking
                    parity='N',                   #No parity bits
                    rtscts=False,                 #Disable handshaking
                    xonxoff=False)                #Disable handshaking

for x in range(len(outputer)):            #Send Length of array
    ser.write(bytes([int(outputer[x])]))  #Send Each byte one at a time
ser.close()                       #Close serial port





