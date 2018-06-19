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
#include "RF24.h"

/************* USER CONFIG ****************/

RF24 radio(7,8);  //set up nRF24L01 radio on spi bus pins 7 & 8

/******************************************/

const uint64_t pipes[1] = { 0x544d52LL };

int dts = 4;    //Size of data in byte for transfor
byte data[4];   //Storing place for received data

void setup() {
  Serial.begin(115200); 

  radio.begin();
  radio.setChannel(83);                 //Set the channel the modules communicat at
  radio.setPALevel(RF24_PA_MAX);        //Set the power level in dB, MAX=0 dB, HIGH=-6 dB, LOW=-12 dB, MIN=-18 dB
  radio.setDataRate(RF24_1MBPS);       //max 1Mbps if ACK ar disabled, Settings 1MBPS or 250KBPS
  radio.setAutoAck(0);                 //dissable ACK if value = '0'
  radio.disableDynamicPayloads();     //Set the transmission size to dynamic
  radio.setPayloadSize(dts);           //chagnes the bytesize of the payload (from 1 to 32)
  radio.disableCRC();
  radio.openReadingPipe(1,pipes[0]);    //Open the reading pipes   
  radio.startListening();               //Set the module to receiverig
  radio.powerUp();                      //Power up the modules
}


void loop() {
  if(radio.available()){      //Wait on received data
    radio.read(&data, dts);   
    for(int i = 0; i<dts; i++){
      Serial.write(data[i]);
  }
}
