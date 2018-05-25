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
byte data[4];   //Storing place for the received data
unsigned long startTime, StopTime;  //Timer for the printing result
unsigned long counter = 0; //Counter of packet errors
unsigned long count = 0;   //Counter for byte errors
byte myVar[4];             //Checking the results for errors
unsigned long packetcount = 0;  //Counts the received packets

void setup() {
  Serial.begin(115200);
  printf_begin();
  Serial.flush();   //Empty the buffer
  radio.begin();    //Starts the radio to programming
  radio.setChannel(100);    //Set the channel
  radio.setPALevel(RF24_PA_MAX);    //Set the power level, MAX=0 dB, HIGH=-6 dB, LOW=-12 dB and MIN=-18 dB
  radio.setDataRate(RF24_1MBPS);     //max 1MBPS if ACK ar disabled, settings 1MBPS or 250KBPS
  radio.setAutoAck(0);               //dissable ACK if value = '0'
  radio.disableDynamicPayloads();    //Disable dynamic byte size
  radio.setPayloadSize(dts);         //chagnes the bytesize of the payload (from 1 to 32)

  radio.disableCRC(); 
  radio.openReadingPipe(1, pipes[1]);  //Opening the reading pipes

  radio.startListening();   //Set the module to receiving 
  radio.powerUp();          // Power up the module
  startTime = millis();
}


void loop() {
  if (radio.available()) { //Wait for data to be transmitted
    packetcount++;
    radio.read(&data, dts);
    for (int j = 0; j < dts; j++) {
      myVar[j] = data[j];
        if (myVar[j] != j + 1) { //Check the byte for errors
          count++;
      }
    }

    if (  //Check the packet for errors
      myVar[0] + myVar[1] + myVar[2] + myVar[3]/* + myVar[4] +
      myVar[5] + myVar[6] + myVar[7] + myVar[8] + myVar[9] +
      myVar[10] + myVar[11] + myVar[12] + myVar[13] + myVar[14] +
      myVar[15] + myVar[16] + myVar[17] + myVar[18] + myVar[19] +
      myVar[20] + myVar[21] + myVar[22] + myVar[23] + myVar[24] +
      myVar[25] + myVar[26] + myVar[27] + myVar[28] + myVar[29] +
      myVar[30] + myVar[31]*/ != 10) {
      counter++;
    }
    /*1-1, 2-3, 3-6, 4-10, 5-15, 6-21, 7-28, 8-36, 9-45, 10-55, 11-66, 
    12-78, 13-91,14-105, 15-120, 16-136, 17-153, 18-171, 19-190, 20-210,
    21-231,22-253, 23-276, 24-300, 25-325, 26-351, 27-378, 28-406, 29-435,
    30-465, 31-496, 32-528*/
    for (int k = 0; k < dts; k++) {
      myVar[k] = 0;
    }
  }
 StopTime = millis();
  if (StopTime-startTime >= 45000){   //Print out the result from received data, each 45 secund
    Serial.print("Packet received ");
    Serial.println(packetcount);
    Serial.print("Packet errors: ");
    Serial.println(counter);
    Serial.print("Byte errors: ");
    Serial.println(count);
    counter = 0;
    count = 0;
    packetcount = 0;
    startTime = millis();
  }
}

