/*
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ---------------- PINOS ----------------
#define LEDAZUL_PIN 14   // aceso enquanto a bomba está irrigando (bomba > 0)
#define LEDVERDE_PIN 26   // boia OK (água suficiente)
#define LEDALTO_PIN 33   // boia baixa / alerta (controlado pelo app)
#define SENSOR_PIN 34   // sensor de umidade resistivo (analógico)
#define FLOAT_SWITCH 27   // chave boia
#define BOMBA_PIN 19   // saída PWM para o módulo driver da bomba
#define LEDDESC_PIN 17

// ---------------- PWM ----------------
#define PWM_CHANNEL 0
#define PWM_FREQ 5000
#define PWM_RES_BITS 8      // resolução de 8 bits -> valores de 0 a 255

// ---------------- UUIDs BLE ----------------
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define SENSOR_CHAR_UUID       "beb5483e-36e1-4688-b7f5-ea07361b26a8" // Notify (ESP32 -> App)
#define COMMAND_CHAR_UUID      "0a3f7f28-6b8e-4f60-9e3a-6f9a2d8c1a11" // Write  (App -> ESP32)

// Calibração do sensor de umidade
const int ADC_SECO = 4095;
const int ADC_MOLHADO = 981;

// ---------------- BLE ----------------
BLECharacteristic *sensorCharacteristic;
BLECharacteristic *commandCharacteristic;
bool deviceConnected = false;

// ---------------- ESTADO ATUAL DOS ATUADORES ----------------
// Definidos pelo app (Flutter), a partir da leitura de umidade/boia.
volatile int  bombaValor  = 0;      // 0-255 (PWM). Vem do app.
volatile bool ledAltoOn   = false;  // vem do app.
const unsigned long SEND_INTERVAL = 17000;

// ---------------- CALLBACKS ----------------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Dispositivo conectado");
    digitalWrite(LEDDESC_PIN, HIGH);
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Dispositivo desconectado");

    // Por segurança, desliga a bomba se o app cair
    bombaValor = 0;
    analogWrite(BOMBA_PIN, 0);
    digitalWrite(LEDAZUL_PIN, LOW);
    digitalWrite(LEDDESC_PIN, LOW);

    // Reinicia a propaganda
    BLEDevice::startAdvertising();
  }
};

// Comando esperado, enviado pelo app: "L:<0|1>;B:<0-255>"
// Ex.: "L:0;B:60"  -> LEDALTO_PIN=off, bomba com PWM 60
//      "L:1;B:0"   -> LEDALTO_PIN=on,  bomba desligada
class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    Serial.println("Recebi comando BLE");
    String cmd = String(pCharacteristic->getValue().c_str()); cmd.trim();
    int idxB = cmd.indexOf("B:");
    if (idxB == -1)
        return;

    int bomba = cmd.substring(idxB + 2).toInt();
    bool boiaOk = digitalRead(FLOAT_SWITCH) == LOW;
    //Serial.println("bomba: ");
    //Serial.print(bomba);
    if (!boiaOk) {
      bombaValor = 0;
      digitalWrite(LEDAZUL_PIN, LOW);
      digitalWrite(LEDVERDE_PIN, LOW);
      digitalWrite(LEDALTO_PIN, HIGH);
    }
    else {
      bombaValor = constrain(bomba,0,255);
      analogWrite(BOMBA_PIN,bombaValor);
      if (bomba > 0){
        digitalWrite(LEDAZUL_PIN, HIGH);
      } else{
        digitalWrite(LEDAZUL_PIN, LOW);
      }
      digitalWrite(LEDVERDE_PIN, HIGH);
      digitalWrite(LEDALTO_PIN, LOW);
    }
  }
};

// ---------------- SETUP ----------------
void setup() {
  Serial.begin(115200);

  pinMode(LEDAZUL_PIN, OUTPUT);
  pinMode(LEDVERDE_PIN, OUTPUT);
  pinMode(LEDALTO_PIN, OUTPUT);
  pinMode(FLOAT_SWITCH, INPUT_PULLUP);
  pinMode(BOMBA_PIN, OUTPUT);
  digitalWrite(LEDAZUL_PIN, LOW);
  digitalWrite(LEDVERDE_PIN, LOW);
  digitalWrite(LEDALTO_PIN, LOW);

  analogWrite(BOMBA_PIN, 0);

  // BLE
  BLEDevice::init("ESP32_Irrigacao");

  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);

  // Characteristic para enviar sensores
  sensorCharacteristic = service->createCharacteristic(
      SENSOR_CHAR_UUID,
      BLECharacteristic::PROPERTY_NOTIFY
  );
  sensorCharacteristic->addDescriptor(new BLE2902());

  // Characteristic para receber comandos (LEDALTO + BOMBA)
  commandCharacteristic = service->createCharacteristic(
      COMMAND_CHAR_UUID,
      BLECharacteristic::PROPERTY_WRITE
  );
  commandCharacteristic->setCallbacks(new CommandCallbacks());

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->start();

  Serial.println("ESP32 BLE iniciado");
}

// ---------------- LOOP ----------------
void loop() {
  static unsigned long ultimoEnvio = 0;

  if (millis() - ultimoEnvio >= SEND_INTERVAL) {
    ultimoEnvio = millis();
    int sensorValue = analogRead(SENSOR_PIN);
    Serial.print("ADC: ");
    Serial.println(sensorValue);
    // Converte para porcentagem (0-100%) - ajuste a formula conforme sua calibracao
    float humidity = map(sensorValue, ADC_SECO, ADC_MOLHADO, 0, 100);

    // Limita entre 0 e 100%
    humidity = constrain(humidity, 0, 100);

    bool floatState = digitalRead(FLOAT_SWITCH);
    bool boiaOk = digitalRead(FLOAT_SWITCH) == LOW;

    Serial.print("Float: ");
    Serial.print(digitalRead(FLOAT_SWITCH));

    Serial.print("  boiaOk: ");
    Serial.print(boiaOk);

    Serial.print("  Verde: ");
    Serial.print(digitalRead(LEDVERDE_PIN));

    Serial.print("  Alto: ");
    Serial.println(digitalRead(LEDALTO_PIN));
    // LEDs do reservatorio (independem do LEDALTO_PIN, que e comandado pelo app)

    if (boiaOk == LOW) {
      digitalWrite(LEDVERDE_PIN, LOW);
      digitalWrite(LEDALTO_PIN, HIGH);
    }
    else {
      digitalWrite(LEDVERDE_PIN, HIGH);
      digitalWrite(LEDALTO_PIN, LOW);
    }

    if ((!boiaOk) && (bombaValor != 0)) {
        bombaValor = 0;
        analogWrite(BOMBA_PIN, 0);
        digitalWrite(LEDAZUL_PIN, LOW);
    }

    // Envia dados via BLE para o app decidir o proximo comando
    if (deviceConnected) {
      String payload = "{\"humidity\":" + String(humidity, 1) +
                      ",\"water\":\"" + String(floatState == HIGH ? "HIGH" : "LOW") + "\"}";

      sensorCharacteristic->setValue(payload.c_str());
      sensorCharacteristic->notify();

      Serial.print("Enviado: ");
      Serial.println(payload);
    }
  }

}

*/