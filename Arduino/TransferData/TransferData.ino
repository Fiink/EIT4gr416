/************************************
* Data Transfor
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

const uint64_t pipes[2] = { 0x544d52LL };

int dts = 4;    //size of data in byte for transfor
byte data[4];   //Storing place for the received data

void setup() {
  Serial.begin(115200);
  printf_begin();
  DDRD = DDRD | B01000000; // define digital bin 2 as output.

  radio.begin();      //Start the radio for programming
  radio.setChannel(100);      //Set the channel where the modules communicat  
  radio.setPALevel(RF24_PA_MAX);        //Set the power level, MAX=0 dB, HIGH=-6 dB, LOW=-12 dB and MIN=-18 dB
  radio.setDataRate(RF24_1MBPS);       //max 1Mbps if ACK ar disabled, setting 1MBPS or 250KBPS
  radio.setAutoAck(0);                 //dissable ACK if value = '0'
  radio.disableDynamicPayloads();       //Set tranmission size to dynamic
  radio.setPayloadSize(dts);           //chagnes the bytesize of the payload (from 1 to 32)

  radio.disableCRC();
  radio.openWritingPipe(pipes[0]);     //Open the writing pipe

  radio.stopListening();              //Set the radio to transmit

  radio.powerUp();                    //Power up the modules

  pauseTime = millis();
}

void loop() {
  if(Serial.available() > 3 ){        //Wait for the Arduino to receiv data
    for(int i = 0; i<dts; i++){
      data[i]= Serial.read();
    }
    radio.writeFast(&data , dts);     // Writes the data to the Wirelesse module
    delayMicroseconds(7);

  }

}
