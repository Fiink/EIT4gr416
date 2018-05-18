/************************************
* Data Recieve
* 
*************** PIN setup************
* 
* | PIN | NRF24L01 | Arduino UNO |
* |-----|----------|-------------|
* |  1  |   GND    |   GND       | 
* |  2  |   VCC    |   3.3V      | 
* |  3  |   CE     |   digIO 7   | 
* |  4  |   CSN    |   digIO 8   | 
* |  5  |   SCK    |   digIO 13  | 
* |  6  |   MOSI   |   digIO 11  |  
* |  7  |   MISO   |   digIO 12  |  
* |  8  |   IRQ    |      -      |  
*
*************************************/

#include <SPI.h>
#include <printf.h>
#include "RF24.h"

/************* USER CONFIG ****************/

RF24 radio(7,8);  //set up nRF24L01 radio on spi bus pins 7 & 8

/******************************************/

const uint64_t pipes[1] = { 0x544d52LL };

int dts = 4;    //size of data in byte for transfor
byte data[4];

void setup() {
  Serial.begin(115200);
  printf_begin();

  radio.begin();
  radio.setChannel(100);
  radio.setPALevel(RF24_PA_MAX);
  radio.setDataRate(RF24_1MBPS);       //max 1Mbps if ACK ar disabled
  radio.setAutoAck(0);                 //dissable ACK if value = '0'
  radio.disableDynamicPayloads();
  radio.setPayloadSize(dts);           //chagnes the bytesize of the payload (from 1 to 32)
  radio.disableCRC();
  radio.openReadingPipe(1,pipes[0]);   
  radio.startListening();
  radio.powerUp();
}


void loop() {
  if(radio.available()){
    radio.read(&data, dts);
    for(int i = 0; i<dts; i++){
      Serial.write(data[i]);
  }
}
