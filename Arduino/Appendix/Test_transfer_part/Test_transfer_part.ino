/************************************
* Test of data transfer
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

const uint64_t pipes[2] = { 0xABCDABLL, 0x544d52LL }; //CD71            687C

int dts = 4;    //size of data in byte for transfor
byte data[4];   //Storing place for received data
unsigned long startTime, stopTime, pauseTime;  //For calculating transmission time
unsigned long counter = 0;    //Counter for transmitted packets
unsigned long NrPacket = 100000;    //Set the number of send packets
char x = 0;

void setup() {
  for(int i = 0; i < dts; i++){   //Makes the data for transmission
    data[i]= i+1;
  }

  Serial.begin(115200);
  
  radio.begin();
  radio.setChannel(100);            //Set the channel for communication
  radio.setPALevel(RF24_PA_HIGH);   //Set the power level, MAX=0 dB, HIGH=-6 dB, LOW=-12 dB and MIN=-18 dB
  radio.setDataRate(RF24_250KBPS);       //max 1Mbps if ACK ar disabled, setting 1MBPS and 250KBPS
  radio.setAutoAck(0);                 //dissable ACK if value = '0'
  radio.disableDynamicPayloads();
  radio.setPayloadSize(dts);           //chagnes the bytesize of the payload (from 1 to 32)

  radio.disableCRC();
  radio.openWritingPipe(pipes[1]);     //Open the writing pipe
  radio.stopListening();              //Set the modules to transmit
  radio.powerUp();                    //Power up the modules
  pauseTime = millis();
  startTime = millis();
}

void loop() {
  
  while(counter < NrPacket){   //Transmit data until the wanted number of packets are transmitted
    radio.writeFast(&data, dts);
    delayMicroseconds(300);       //Set a dalay to make sure the received can follow  
    counter++;
    stopTime = micros();
  }
  while(Serial.available()){   //Wait for a charector send in the serial
    counter = 0;
    startTime = micros();
    x = Serial.read();
  }
  
  while(counter == NrPacket){  //Print out the time used for transmit
    Serial.println("Done");
    Serial.println(stopTime - startTime);
    counter++;
  }

}
