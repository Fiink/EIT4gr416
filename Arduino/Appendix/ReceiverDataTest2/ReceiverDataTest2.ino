#include <SPI.h>
#include <printf.h>
#include "RF24.h"

RF24 radio(7, 8);   //set up nRF24L01 radio on spi bus pins 7 & 8
const uint64_t pipes[2] = { 0xABCDABLL, 0x544d52LL };
int dts = 4;        //Size of data in byte for transfer
byte data[4];     //Storing place for the received data
unsigned long startTime, StopTime;  //The timer for the printing out results
unsigned long counter = 0;    //Total bit error counter for each packet
unsigned long BitError = 0;   //Counts the packets with only one bit error
unsigned long packetError = 0;  //Counts the packets with more than one bit error
unsigned long byteError = 0;    //Counts the errors in each byte
byte myVar[4];  //The right received bytes to check the received bytes
byte value[4];    //The array where the different between the received bytes and check bytes
unsigned long packetcount = 0;  //Counts the packets received

void setup() {
  myVar[0] = 0xAA;  //The check byte
  myVar[1] = 0xAA;  //The check byte
  myVar[2] = 0xE6;  //The check byte
  myVar[3] = 0x15;  //The check byte
  
  Serial.begin(115200);
  Serial.flush();   //Flush the buffer each time the Arduino starts up again
  radio.begin();    //Starts the radio programming
  radio.setChannel(100);  //Set the channel the modules communicate at 
  radio.setPALevel(RF24_PA_MAX);  //Set the power level
  radio.setDataRate(RF24_1MBPS);     //Max 1Mbps if ACK is disabled
  radio.setAutoAck(0);               //Disable ACK if value = '0'
  radio.disableDynamicPayloads(); //Set the transmission size to dynamic
  radio.setPayloadSize(dts);         //Changes the byte size of the payload (from 1 to 32)
  radio.disableCRC();
  radio.openWritingPipe(pipes[0]);     //Opening the writing pipe
  radio.openReadingPipe(1, pipes[1]);  //Opening the reading pipes
  radio.startListening(); //Set the module to receiving
  radio.powerUp();  //Start up the modules
  startTime = millis();
}

void loop() {
  if (radio.available()) {
    packetcount++;
    radio.read(&data, dts);   //Receiving data and save it in to the storage array
    for(int i = 0; i<dts; i++){
      value[i] = myVar[i] ^ data[i];  //Check for different in the received data and checking byte
      if(value[i] == 0x01){
        counter++;
      }
      if(value[i] == 0x02){
        counter++;
      }
      if(value[i] == 0x04){
        counter++;
      }
      if(value[i] == 0x08){
        counter++;
      }
      if(value[i] == 0x10){
        counter++;
      }
      if(value[i] == 0x20){
        counter++;
      }
      if(value[i] == 0x40){
        counter++;
      }
      if(value[i] == 0x80){
        counter++;
      }
      if(value[i] != 0x00 && value[i] !=0x01 && value[i] !=0x02 && value[i] !=0x04 && value[i] !=0x08 && value[i] !=0x10 && value[i] !=0x20 && value[i] !=0x40 && value[i] !=0x80 ){
        byteError++;  //Checks for more bit errors in the bytes
      }
    }
    if(counter == 1 && byteError == 0){
      BitError++;
      counter = 0;
    }
    if(counter >= 2 || byteError > 0){
      packetError++;
      counter = 0;
    }
 }
 StopTime = millis();
  if (StopTime-startTime >= 10000){   //Set the time to print out results
    Serial.print("Packets with 1 Error: ");
    Serial.println(BitError);
    Serial.print("packet with 2 or more errors: ");
    Serial.println(packetError);
    Serial.print("Packet received ");
    Serial.println(packetcount);
    BitError = 0;
    packetError = 0;
    packetcount = 0;
    startTime = millis();
  }
}

