
import os.path    #System paths and os version
import locale,time         #Encoding and timing
import serial
from PIL import Image

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
              print("fail to make CRC correctly")
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



def check_CRC_sum(in1,in2,in3):
        buff=[]
        buff.append(in1)
        buff.append(in2)
        tempo = '{:04x}'.format(GenCCITT_CRC16(buff))
        if (in3.decode('charmap')).upper() ==(tempo).upper():
                return(True)
        else:
                return(False)
        
########Test code for crc################
'''
outputer=[b'']*9

outputer[0] = b'\xff'
outputer[1] = b'\xd8'
outputer[2] = b'498a'
outputer[3] = b'\xff'
outputer[4] = b'\xff'
outputer[5] = b'1d0f'
outputer[6] = b'\xd9'
outputer[7] = b'\x00'
outputer[8] = b'afbf'
'''
#######Code to run#######################
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


f=False
count = 0
x=0
checker = False
while x <len(outputer):
        outputer[x]=ser.read()
        if outputer[x]==b'\xd9':
                if(outputer[x-1]==b'\xff'):
                        outputer[x+1]=ser.read()
                        break
                elif(outputer[x-2]==b'\xff'):
                        outputer[x+1]=ser.read()
                        outputer[x+2]=ser.read()
                        x+=2
                        break
        x+=1
y=0
check =False
while True:
        if y==(len(outputer)-((len(outputer))%3)):
                break
        check = check_CRC_sum(outputer[y],outputer[y+1],outputer[y+2])
        if check:
                check=False
        elif not check:
                print("WE HAVE A CRC FAIL! STOPPED PROGRAM AT runthrough#: {}".format(1+int(y/3)))
                exit()
        y+=3

file = open(pathout,'w+b')
while s < x:
        file.write(chr(int.from_bytes(outputer[s],byteorder='big')).encode('charmap'))
        file.write(chr(int.from_bytes(outputer[s+1],byteorder='big')).encode('charmap'))
        s+=3
file.close()
print("Done checking the stirngs for failures")




