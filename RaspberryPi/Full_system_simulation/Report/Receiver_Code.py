
import os.path    #System paths and os version
import locale,time         #Encoding and timing
import serial
from PIL import Image



error_correct =[4129,
                8258,
                16516,
                33032,
                4657,
                9314,
                18628,
                37256,
                13105,
                26210,
                52420,
                35241,
                883,
                1766,
                3532,
                7064]

error_correct_crc =[1,
                    2,
                    4,
                    8,
                    16,
                    32,
                    64,
                    128,
                    256,
                    512,
                    1024,
                    2048,
                    4096,
                    8192,
                    16384,
                    32768]


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

def error_check(c, d):
    cal_crc=int(str(d[0]+d[1]+d[2]+d[3]).encode('charmap'),16)
    try:
       input_crc =int(str(c[2]+c[3]+c[4]+c[5]).encode('charmap'),16)
    except:
       return(False)
    in_crc=input_crc 
    in_crc ^=cal_crc
    for x in range(len(error_correct_crc)):
        if in_crc == error_correct[x]:
            return True
        if in_crc == error_correct_crc[x]:
            return True
    return (False)

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

outputer=[b'']*10000000
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
print("It took: {} seconds to read the image".format(time.time()-start))
start=time.time()
y=0
check =False
print("check crc")
CRC_COUNT=0
error_count=0
while True:
        if outputer[y]==b'\xff':
           if outputer[y+1]==b'\xd9':
              break
           if outputer[y+5]==b'\xd9':
              break
        if y==(x):
                break
        j = str(outputer[y+2]+outputer[y+3]+outputer[y+4]+outputer[y+5])
        check = check_CRC_sum(outputer[y],outputer[y+1],j)
        buff=[]
        buff.append(outputer[y])
        buff.append(outputer[y+1])       
        if error_check(j,'{:04x}'.format(GenCCITT_CRC16(buff))):
           error_count+=1
        elif not error_check(j,'{:04x}'.format(GenCCITT_CRC16(buff))):
           error_count=error_count
        if check:
                check=False
        elif not check:
                CRC_COUNT +=1
        y+=6
print("It took: {} seconds to check the CRC".format(time.time()-start))
start=time.time()
s=0
file = open(pathout,'w+b')
while s < x:
        file.write(chr(int.from_bytes(outputer[s],byteorder='big')).encode('charmap'))    
        file.write(chr(int.from_bytes(outputer[s+1],byteorder='big')).encode('charmap'))
        s+=6
file.close()
print("It took: {} seconds to save the image".format(time.time()-start))
print("Completed the cycle with: {}, CRC errors!".format(CRC_COUNT))
print("out of the CRC erros, {}, could be error corrected!".format(error_count))
