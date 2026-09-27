/*
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <RTClib.h>

// ---------------- PINOS ----------------
#define LEDAZUL_PIN 14   // aceso enquanto a bomba está irrigando (bomba > 0)
#define LEDVERDE_PIN 26   // boia OK (água suficiente)
#define LEDALTO_PIN 33   // boia baixa / alerta (controlado pelo app)
#define SENSOR_PIN 34   // sensor de umidade resistivo (analógico)
#define FLOAT_SWITCH 27   // chave boia
#define BOMBA_PIN 19   // saída PWM para o módulo driver da bomba
#define LEDDESC_PIN 17 // temperatura a ser utilizada
#define SDA_PIN 21
#define SCL_PIN 22
RTC_DS3231 rtc;
bool rtcDisponivel = false;

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

// false = temperatura da API
// true  = temperatura do DS3231
volatile bool ledDescOn = false;

// ---------------- CALLBACKS ----------------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Dispositivo conectado");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Dispositivo desconectado");

    // Por segurança, desliga a bomba se o app cair
    bombaValor = 0;
    analogWrite(BOMBA_PIN, 0);
    digitalWrite(LEDAZUL_PIN, LOW);
    ledDescOn = false;
    digitalWrite(LEDDESC_PIN, LOW);

    // Reinicia a propaganda
    BLEDevice::startAdvertising();
  }
};

// Comando esperado, enviado pelo app: "L:<0|1>;B:<0-255>"
// Ex.: 
// L:0;B:60
// -> LED de contingência desligado
// -> bomba PWM 60
//
// L:1;B:60
// -> LED de contingência ligado
// -> bomba PWM 60
//
// IMPORTANTE:
// O ESP32 NÃO sabe se existe Internet.
// O significado de L:1 é definido pelo Flutter.
class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    Serial.println("Recebi comando BLE");
    String cmd = String(pCharacteristic->getValue().c_str()); 
    cmd.trim();
    Serial.print("Comando recebido: ");
    Serial.println(cmd);
    int idxL = cmd.indexOf("L:");
    if (idxL != -1){
      int fimL = cmd.indexOf(';', idxL);
      String ledText;
      if (fimL != -1) {
        ledText = cmd.substring(idxL + 2, fimL);
      } else {
        ledText = cmd.substring(idxL + 2);
      }
      int ledValor = ledText.toInt();
      // L:1 = liga LED
      // L:0 = desliga LED
      if (ledValor == 1) {
        ledDescOn = true;
        digitalWrite(LEDDESC_PIN, HIGH);
        Serial.println("LED de contingencia: LIGADO");
      } else {
        ledDescOn = false;
        digitalWrite(LEDDESC_PIN, LOW);
        Serial.println("LED de contingencia: DESLIGADO");
      }
    }
    int idxB = cmd.indexOf("B:");
    if (idxB == -1) {
      // Se não encontrou comando da bomba,
      // encerra aqui.
      return;
    }
    // --------------------------------------------------------
    // Extrai valor da bomba
    // --------------------------------------------------------
    int fimB = cmd.indexOf(';', idxB);
    String bombaTexto;
    if (fimB != -1) {
      bombaTexto = cmd.substring(idxB + 2, fimB);
    } else {
      bombaTexto = cmd.substring(idxB + 2);
    }
    int bomba = bombaTexto.toInt();
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
  pinMode(LEDDESC_PIN, OUTPUT);
  pinMode(FLOAT_SWITCH, INPUT_PULLUP);
  pinMode(BOMBA_PIN, OUTPUT);
  digitalWrite(LEDAZUL_PIN, LOW);
  digitalWrite(LEDVERDE_PIN, LOW);
  digitalWrite(LEDALTO_PIN, LOW);
  digitalWrite(LEDDESC_PIN, LOW);
  analogWrite(BOMBA_PIN, 0);

  Wire.begin(SDA_PIN, SCL_PIN);
  Serial.println("Inicializando DS3231...");

  if (!rtc.begin()) {
    Serial.println("ERRO: DS3231 nao encontrado!");
    rtcDisponivel = false;
  }
  else {
    Serial.println("DS3231 encontrado.");
    rtcDisponivel = true;
    // VERIFICA SE O RTC PERDEU A ALIMENTAÇÃO
    if (rtc.lostPower()) {
      Serial.println("AVISO: DS3231 perdeu a alimentacao.");
      Serial.println("Ajustando horario para data/hora da compilacao.");
      rtc.adjust(DateTime(F(__DATE__),F(__TIME__)));
    }
    else {
      Serial.println("DS3231 mantendo horario.");
    }
  }

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
    float temperature = 0.0;

    DateTime agora;

    if (rtcDisponivel) {
      // Data e hora
      agora = rtc.now();

      // Temperatura interna do DS3231
      temperature =rtc.getTemperature();
      Serial.print("Temperatura DS3231: ");
      Serial.print(temperature,1);
      Serial.println(" C");

      // Exibe data e hora
      Serial.print("Data/Hora: ");
      Serial.print(agora.year());
      Serial.print("-");
      if (agora.month() < 10)
        Serial.print("0");
      Serial.print(agora.month());
      Serial.print("-");
      if (agora.day() < 10)
        Serial.print("0");
      Serial.print(agora.day());
      Serial.print(" ");
      if (agora.hour() < 10)
        Serial.print("0");
      Serial.print(agora.hour());
      Serial.print(":");
      if (agora.minute() < 10)
        Serial.print("0");
      Serial.print(agora.minute());
      Serial.print(":");
      if (agora.second() < 10)
        Serial.print("0");
      Serial.println(agora.second());
    }

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
      String timestamp = "";
      if (rtcDisponivel) {
        timestamp =
          String(agora.year()) + "-" +
          (agora.month() < 10? "0": "") +String(agora.month()) + "-" +
          (agora.day() < 10? "0": "") +String(agora.day()) +"T" +
          (agora.hour() < 10? "0": "") +String(agora.hour()) +":" +
          (agora.minute() < 10? "0": "") +String(agora.minute()) +":" +
          (agora.second() < 10? "0": "") +String(agora.second());
      }
      String payload = "{\"humidity\":" + String(humidity, 1) +
                      ",\"temperature\":" +String(temperature,1) +
                      ",\"water\":\"" + String(floatState == HIGH ? "HIGH" : "LOW") +
                      "\",\"timestamp\":\"" +timestamp +"\"}";

      sensorCharacteristic->setValue(payload.c_str());
      sensorCharacteristic->notify();

      Serial.print("Enviado: ");
      Serial.println(payload);
    }
  }

}
*/