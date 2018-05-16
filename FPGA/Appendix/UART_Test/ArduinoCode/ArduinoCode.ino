int incomming;
void setup() {
 Serial.begin(115200);
}

void loop() {
  while(Serial.available()){
    incomming = Serial.read();
    Serial.print(incomming); 
    Serial.print(" ");
  }
}
