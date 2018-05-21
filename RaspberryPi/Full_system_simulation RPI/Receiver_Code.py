
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
             l=1
            #              print("fail to make CRC correctly")
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
        tempo = str('{:04x}'.format(GenCCITT_CRC16(buff)))
        
        if (str(in3)).upper() == str(tempo.encode('charmap')).upper():
                return(True)
        else:
                return(False)
        
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
#           print(temp)
           outputer[x]=temp
           if outputer[x]==b'\xd9':
                   if(outputer[x-1]==b'\xff'):
                           print("found ff d9")
                           outputer[x+1]=ser.read()
                           outputer[x+2]=ser.read()
                           outputer[x+3]=ser.read()
                           outputer[x+4]=ser.read()
                           break
                   elif(outputer[x-5]==b'\xff'):
                           print("found ff d9")
                           outputer[x+1]=ser.read()
                           outputer[x+2]=ser.read()
                           outputer[x+3]=ser.read()
                           outputer[x+4]=ser.read()
                           outputer[x+5]=ser.read()
                           x+=3
                           break
           x+=1
y=0
check =False
print("check crc")
CRC_COUNT=0
while True:
        if outputer[y]==b'\xff':
           if outputer[y+1]==b'\xd9':
              break
           if outputer[y+5]==b'\xd9':
              break
        if y==(len(outputer)-((len(outputer))%6)):
                break
        j = str(outputer[y+2]+outputer[y+3]+outputer[y+4]+outputer[y+5])
        check = check_CRC_sum(outputer[y],outputer[y+1],j)
        if check:
                check=False
        elif not check:
                CRC_COUNT +=1
        y+=6
s=0
file = open(pathout,'w+b')
while s < x:
        file.write(chr(int.from_bytes(outputer[s],byteorder='big')).encode('charmap'))    
        file.write(chr(int.from_bytes(outputer[s+1],byteorder='big')).encode('charmap'))
        s+=6
file.close()
print("Completed the cycle with: {}, CRC errors!".format(CRC_COUNT))




