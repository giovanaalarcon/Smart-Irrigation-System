# Sistema Autônomo de Irrigação Inteligente com Gestão Energética Adaptativa

## 📌 Sobre o projeto

Este projeto consiste no desenvolvimento de um **sistema autônomo de irrigação inteligente**, desenvolvido como Trabalho de Conclusão de Curso (TCC), com o objetivo de automatizar o processo de irrigação de plantas a partir da análise das condições do solo, da disponibilidade de água no reservatório e das condições meteorológicas.

A solução integra um **ESP32**, sensores, atuadores, comunicação **Bluetooth Low Energy (BLE)** e um aplicativo desenvolvido em **Flutter**. O aplicativo é responsável por receber os dados do sistema, consultar informações meteorológicas e determinar a necessidade de irrigação. A decisão é então enviada ao ESP32, que realiza o acionamento e controle da bomba d'água.

O sistema busca reduzir o desperdício de água e energia, evitando a irrigação em condições inadequadas e permitindo um controle mais eficiente do volume de água utilizado.

---

## 🎯 Objetivo

O objetivo principal do projeto é desenvolver um sistema capaz de **automatizar a irrigação de plantas de forma inteligente**, utilizando dados provenientes de sensores e informações meteorológicas para determinar quando e como realizar a irrigação.

### Objetivos específicos

* Monitorar a umidade do solo;
* Monitorar o nível de água disponível no reservatório;
* Consultar condições meteorológicas;
* Avaliar as condições necessárias para realização da irrigação;
* Controlar a velocidade da bomba por meio de PWM;
* Evitar o acionamento da bomba quando o reservatório estiver vazio;
* Permitir a comunicação entre o aplicativo e o sistema embarcado por BLE;
* Disponibilizar ao usuário informações sobre as condições atuais do sistema;
* Reduzir o desperdício de água e energia durante o processo de irrigação.

---

## 🏗️ Arquitetura do sistema

O sistema é dividido em três componentes principais:

```text
┌─────────────────────────────┐
│        Aplicativo Flutter   │
│                             │
│ • Interface do usuário      │
│ • Dados dos sensores        │
│ • Dados meteorológicos      │
│ • Tomada de decisão         │
└──────────────┬──────────────┘
               │
               │ Bluetooth Low Energy
               ▼
┌─────────────────────────────┐
│            ESP32            │
│                             │
│ • Leitura dos sensores      │
│ • Controle dos atuadores    │
│ • Comunicação BLE           │
│ • Controle PWM da bomba     │
└───────┬───────────┬─────────┘
        │           │
        ▼           ▼
┌─────────────┐ ┌─────────────┐
│  Sensores   │ │  Atuadores  │
│             │ │             │
│ • Umidade   │ │ • Bomba     │
│ • Boia      │ │ • LEDs      │
└─────────────┘ └─────────────┘
```

O ESP32 realiza a aquisição dos dados provenientes dos sensores e os disponibiliza ao aplicativo por meio de comunicação BLE.

O aplicativo processa essas informações juntamente com os dados meteorológicos e determina a necessidade e a intensidade da irrigação. A decisão é enviada novamente ao ESP32, que controla a bomba e os indicadores luminosos.

---

## ⚙️ Funcionamento

O funcionamento do sistema ocorre de forma integrada entre o aplicativo e o dispositivo embarcado.

### 1. Monitoramento

O ESP32 realiza a leitura periódica dos sensores:

* **Sensor de umidade do solo:** fornece informações sobre a umidade do solo;
* **Sensor de nível (boia):** identifica a disponibilidade de água no reservatório.

Esses dados são enviados ao aplicativo utilizando Bluetooth Low Energy.

### 2. Análise das condições meteorológicas

O aplicativo consulta uma API meteorológica para obter informações sobre as condições climáticas da região.

Entre as informações utilizadas estão:

* Temperatura;
* Previsão de chuva;
* Índice UV;
* Condições meteorológicas futuras.

A localização utilizada para a consulta é determinada por **latitude e longitude**.

### 3. Tomada de decisão

Com base nos dados recebidos, o aplicativo avalia se a irrigação deve ser realizada.

A decisão considera principalmente:

* Umidade do solo;
* Disponibilidade de água;
* Temperatura;
* Previsão de chuva;
* Índice UV;
* Características da cultura selecionada;
* Fase de desenvolvimento da planta.

Quando as condições são inadequadas para irrigação, a bomba permanece desligada.

### 4. Controle da bomba

Quando a irrigação é autorizada, o aplicativo envia ao ESP32 o valor correspondente à intensidade da bomba.

O controle é realizado utilizando **PWM**, permitindo variar a velocidade da bomba de acordo com a necessidade de irrigação.

O comando enviado ao ESP32 segue o formato:

```text
B:<valor>
```

onde `<valor>` representa o nível de PWM utilizado para controlar a bomba.

Por exemplo:

```text
B:60
```

representa um determinado nível de acionamento da bomba.

---

## 💧 Segurança do sistema

Uma das regras fundamentais do projeto é impedir que a bomba seja acionada quando não houver água suficiente no reservatório.

O estado da boia é utilizado para identificar essa condição.

### Reservatório com água

* LED verde ligado;
* Sistema pode realizar irrigação;
* Bomba pode ser acionada quando autorizada pelo aplicativo.

### Reservatório sem água

* LED de alerta ligado;
* Bomba permanece desligada;
* Irrigação é interrompida ou impedida.

Essa lógica evita o funcionamento da bomba sem água, reduzindo o risco de danos ao equipamento.

---

## 💡 Indicadores luminosos

O sistema utiliza LEDs para informar visualmente o estado do dispositivo.

| LED         | Estado                                     |
| ----------- | ------------------------------------------ |
| 🟢 Verde    | Reservatório possui água                   |
| 🔵 Azul     | Bomba em funcionamento                     |
| 🔴 Vermelho | Reservatório sem água / condição de alerta |

---

## 🌱 Seleção da cultura

O sistema permite considerar características específicas da cultura selecionada para auxiliar na tomada de decisão.

Entre os parâmetros utilizados estão:

* Duração do ciclo;
* Fases de desenvolvimento;
* Coeficiente de cultura (Kc);
* Profundidade das raízes;
* Consumo hídrico;
* Fase crítica da cultura;
* Fator de depleção de água disponível no solo (MAD).

Esses parâmetros permitem adaptar o comportamento do sistema às necessidades hídricas da cultura cultivada.

---

## 📱 Aplicativo

O aplicativo foi desenvolvido utilizando **Flutter** e atua como interface de comunicação e gerenciamento do sistema.

Entre suas principais funções estão:

* Conectar-se ao ESP32 por BLE;
* Receber dados dos sensores;
* Exibir a umidade do solo;
* Exibir o estado do reservatório;
* Consultar dados meteorológicos;
* Exibir as condições climáticas atuais;
* Apresentar previsões meteorológicas;
* Permitir a seleção da cultura;
* Considerar a fase de desenvolvimento da cultura;
* Determinar a necessidade de irrigação;
* Enviar o comando de controle da bomba ao ESP32.

---

## 🔗 Comunicação BLE

A comunicação entre o aplicativo e o ESP32 utiliza **Bluetooth Low Energy (BLE)**.

O ESP32 atua como servidor BLE, disponibilizando características para:

* Notificação dos dados dos sensores;
* Recebimento dos comandos enviados pelo aplicativo.

Os dados dos sensores são enviados em formato **JSON**.

Exemplo:

```json
{
  "humidity": 44.0,
  "water": "LOW"
}
```

O aplicativo interpreta essas informações e utiliza os valores para realizar a tomada de decisão.

---

## 🔌 Hardware

Os principais componentes utilizados no protótipo são:

* ESP32;
* Sensor analógico de umidade do solo;
* Sensor de nível tipo boia;
* Bomba d'água 12 V;
* Válvula solenoide 12 V normalmente fechada;
* Módulo de controle da bomba;
* LEDs indicadores;
* Bateria de 12 V;
* Painel solar;
* Componentes eletrônicos auxiliares.

---

## 💻 Tecnologias utilizadas

### Firmware

* C/C++;
* ESP32;
* Arduino Framework;
* Bluetooth Low Energy;
* PWM;
* Comunicação BLE/GATT.

### Aplicativo

* Flutter;
* Dart;
* BLE;
* Comunicação HTTP/REST;
* JSON.

### Serviços

* API meteorológica;
* Sistema de posicionamento por latitude e longitude.

---

## 📂 Estrutura do projeto

```text
/
├── esp32/
│   ├── ...
│   └── firmware do ESP32
│
├── flutter/
│   ├── lib/
│   ├── assets/
│   └── ...
│
├── docs/
│   ├── imagens/
│   ├── diagramas/
│   └── documentação
│
└── README.md
```

> A estrutura acima pode ser ajustada de acordo com a organização final do repositório.

---

## 🔄 Fluxo de operação

```text
Início
  │
  ▼
ESP32 realiza leitura dos sensores
  │
  ▼
Dados enviados via BLE
  │
  ▼
Aplicativo recebe os dados
  │
  ├───────────────┐
  ▼               ▼
Umidade        Reservatório
  │               │
  └───────┬───────┘
          ▼
Consulta condições meteorológicas
          │
          ▼
Análise das condições de irrigação
          │
     ┌────┴────┐
     │         │
     ▼         ▼
 Irrigar?    Não irrigar
     │         │
     ▼         ▼
Determinar   Bomba = 0
PWM
     │
     ▼
Enviar comando BLE
     │
     ▼
ESP32 controla a bomba
     │
     ▼
Atualização dos indicadores
```

---

## 📊 Resultados esperados

Espera-se que o sistema seja capaz de:

* Automatizar o processo de irrigação;
* Reduzir o consumo desnecessário de água;
* Evitar irrigação em condições meteorológicas desfavoráveis;
* Reduzir o consumo energético associado ao acionamento da bomba;
* Adaptar a irrigação às necessidades da cultura;
* Impedir o funcionamento da bomba sem disponibilidade de água;
* Permitir o acompanhamento das condições do sistema por meio do aplicativo.

Os resultados experimentais obtidos durante a validação do protótipo serão apresentados posteriormente nesta seção.

---

## 👩‍💻 Autoria

**Giovana Salazar Alarcon**

Engenharia de Computação
PUC-Campinas

### Trabalho de Conclusão de Curso

**Título:** Sistema Autônomo de Irrigação Inteligente Alimentado por Energia Solar com Gestão Energética Adaptativa

**Instituição:** Pontifícia Universidade Católica de Campinas – PUC-Campinas

**Ano:** 2026

**Orientador:** Ademar Takeo Akabane*

---

Este projeto foi desenvolvido para fins acadêmicos como parte do Trabalho de Conclusão de Curso em Engenharia de Computação.
