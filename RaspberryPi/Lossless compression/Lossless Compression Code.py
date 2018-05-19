
from PIL import Image
import time
import os.path

start = time.time()   #start logging time at 0
my_path = os.path.abspath(os.path.dirname(__file__)) # relative script path
path = os.path.join(my_path, "uncompressed.jpg") # input image
pathbuffer = os.path.join(my_path, "compressed.jpeg") # compressed image
pathoutput = os.path.join(my_path, "output.txt") # output text

compress=99  #how many percent to compress (100 - compress)

imag = Image.open(path) #original image open
imgs = imag.resize((imag.width, imag.height), Image.ANTIALIAS) #make a new image with same size
imgs.save(pathbuffer, optimize=True,quality=100-compress)  #save a compressed version
img = Image.open(pathbuffer)   #reload compressed image into buffer
imgsize = img.width*img.height  #define image size
squares = int(imgsize / 64)   #number of compression squares 

img_pix_data=[0]*(imgsize*2)  #set initial size of matrix for sequential pixel data
pix_val = list(img.getdata())  #get RGB values for img
pix_val_flat = [x for sets in pix_val for x in sets]  #split the RGB values into values instead of lists

for x in range(0,imgsize):
    img_pix_data[x]= format(pix_val_flat[(x*3)],'08b')  #Put R values of image (x*3) every third value RGBRGB
     #and convert to binary with 8 digits ('08b')
zigzag_data = [0]*(imgsize*2) #Zigzag buffer with double image size
output_data =[0]*(imgsize*2) #Output buffer with double image size

def zigzag(xcoor,ycoor):# Define zigzag pattern with x and y coordinates
    def move(i, j): # Define move to shift x and y to zigzag
        if j < (8 - 1):
            return max(0, i-1), j+1
        else:
            return i+1, j
    counter = -1+xcoor*8+ycoor*img.width   # set as relative path to the current pixel being
     # read from the sequential list of pixel
    x=0 # Relative x coordinate for this exact square
    y=0 # Relative y coordinate for this exact square
    for v in range(8 * 8):  # loop 64 times to get the entire square of 8*8 pix 
        counter +=1 # take the next element
        zigzag_data[counter]=img_pix_data[x+xcoor+(ycoor+y)*img.width] # put the next zigzag value from sequential
        if (x + y) & 1: #shift x and y coordinates
            x, y = move(x, y)
        else:
            y, x = move(y, x)
    

for y in range(int(img.height/8)): # Run all the squares in sequential order and store
     for x in range(int(img.width/8)):
         zigzag(x*8,y*8)
    
location = 0   # where are we in the image?
count = 1  # how many times is this number represented? huffman
iterator = 0   # how many have we skipped? or compressed?

for s in range(0,imgsize):  # Run size of image times
    if count == 1:
        if (zigzag_data[s] == zigzag_data[s+1]):   # if data = next datapoint do something
            done = False# Still working
            while (done==False):
                count += 1  # now we have one more match. so plus 1
                if count >250:  # Restriction for 0 bit (stop start bit)
                    done = True
                    iterator+=count-1  # we have skipped how many?
                if zigzag_data[s+count-1]!= zigzag_data[s+count] and done==False: #aslong as data is equal continue
                    done = True
                    iterator+=count-1
        output_data[location] = format(count,'08b')# put the count into output as binary 8 bit
        output_data[location+1]=zigzag_data[s] # put the next place with its colour value
        location +=2# go on after the value we put in and count
        if count==1:
            count==2
    else:   # use iterations to minus the counter
        count -=1   # Python can't use s+1 for some reason

print("Antal linjer Originalt: {}".format(imgsize))#Debug
print("Antal linjer: {}".format(2*imgsize-iterator*2)) #Debug

with open(pathoutput, "w") as text_file:   # Open a file to output the values
    for y in range(0,((2*imgsize-iterator*2))):# the maximum image size- number of skipped values
        print("{}".format(output_data[y]),file=text_file)
text_file.close()   #Close text file
print(time.time() - start)  #print the runtime period
