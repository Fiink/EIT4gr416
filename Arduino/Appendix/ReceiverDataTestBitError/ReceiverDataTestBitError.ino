/************************************
  Data Transfor og Recieve

*************** PIN setup************

  | PIN | NRF24L01 | Arduino UNO |
  |-----|----------|-------------|
  |  1  |   GND    |   GND       |
  |  2  |   VCC    |   3.3V      |
  |  3  |   CE     |   digIO 7   |
  |  4  |   CSN    |   digIO 8   |
  |  5  |   SCK    |   digIO 13  |
  |  6  |   MOSI   |   digIO 11  |
  |  7  |   MISO   |   digIO 12  |
  |  8  |   IRQ    |      -      |

*************************************/

#include <SPI.h>
#include <printf.h>
#include "RF24.h"

/************* USER CONFIG ****************/

RF24 radio(7, 8); //set up nRF24L01 radio on spi bus pins 7 & 8

/******************************************/

const uint64_t pipes[2] = { 0xABCDABLL, 0x544d52LL };
/*0xABCDABCD71LL  544d52687CLL*/
int dts = 4;    //size of data in byte for transfor
byte data[4];
unsigned long startTime, StopTime;
unsigned long counter = 0;
unsigned long BitError = 0;
unsigned long packetError = 0;
unsigned long byteError = 0;
byte myVar[4];
byte value[4];
unsigned long packetcount = 0;

void setup() {
  myVar[0] = 0xAA;
  myVar[1] = 0xAA;
  myVar[2] = 0xE6;
  myVar[3] = 0x15;
  //data[0] = 0xAA;
  //data[1] = 0xAA;
  //data[2] = 0xE6;
  //data[3] = 0x15;
  
  Serial.begin(115200);
  printf_begin();
  //DDRD = DDRD | B01000000;
  Serial.flush();

  radio.begin();
  radio.setChannel(100);
  radio.setPALevel(RF24_PA_MAX);
  radio.setDataRate(RF24_1MBPS);     //max 1Mbps if ACK ar disabled
  radio.setAutoAck(0);               //dissable ACK if value = '0'
  radio.disableDynamicPayloads();
  radio.setPayloadSize(dts);         //chagnes the bytesize of the payload (from 1 to 32)

  radio.disableCRC();
  radio.openWritingPipe(pipes[0]);     //
  radio.openReadingPipe(1, pipes[1]);  //

  radio.startListening();
  radio.powerUp();
  startTime = millis();
}


void loop() {
  if (radio.available()) {
    packetcount++;
    radio.read(&data, dts);
    for(int i = 0; i<dts; i++){
      value[i] = myVar[i] ^ data[i];
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
        byteError++;
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
  if (StopTime-startTime >= 10000){
    Serial.print("Packets with 1 Error: ");
    Serial.println(BitError);
    Serial.print("packet with 2 or more errors: ");
    Serial.println(packetError);
    Serial.print("Packet received ");
    Serial.println(packetcount);

    counter = 0;
    BitError = 0;
    packetError = 0;
    packetcount = 0;
    startTime = millis();
  }
}

