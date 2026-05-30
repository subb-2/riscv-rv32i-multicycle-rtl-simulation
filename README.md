# SystemVerilog Design — RV32I Multi-Cycle SoC

📅 프로젝트 정보

* 진행 기간: 2026.03 (3학년 2학기)
* 설계 대상: RV32I Multi-Cycle CPU + APB Bus Master + Peripheral (BRAM / GPIO / FND / UART)
* 기술 스택: `SystemVerilog`, `Vivado`, `Basys3 (Artix-7)`, `RISC-V GCC`

---

## 📝 프로젝트 개요

RV32I ISA의 모든 명령어 타입(R / I / S / B / U / J)을 지원하는 **Multi-Cycle CPU**를 설계하고,  
**APB Bus Master**를 통해 BRAM / GPIO / FND / UART 페리페럴을 연결한 완성형 SoC 프로젝트입니다.

C 코드를 RISC-V 어셈블리로 크로스 컴파일한 `.mem` 파일을 ROM에 탑재하여  
**스위치 입력 → FND 출력 → UART 전송**의 통합 시나리오를 FPGA에서 실제 동작 검증하였습니다.

Single-Cycle 대비 Multi-Cycle 전환 후 타이밍 위반(WNS −2.874 ns → +0.333 ns)이 해소되었습니다.

---

## 👥 팀 구성

| 이름 | 담당 |
|------|------|
| 조승아 | System Architecture 설계, Multi-Cycle CPU 구현 |
| 김수빈 | APB Bus Master 설계, BRAM 슬레이브 구현 및 시뮬레이션 |
| 장현동 | GPIO / FND 슬레이브 설계, 시뮬레이션, FPGA 동작 검증 |
| 문태성 | UART 슬레이브 설계, 시뮬레이션, FPGA 동작 검증 |

---

## 🏗️ 시스템 구조

<p align="center">
<img width="700" alt="System Architecture" src="https://github.com/user-attachments/assets/7f56c930-f64b-4de5-a915-889cb11a2254" />
</p>

### Memory Map

| Peripheral | Base Address | End Address | Size | 설명 |
|------------|--------------|-------------|------|------|
| RAM (BRAM) | `0x1000_0000` | `0x1000_0FFF` | 4 KB | 데이터 저장용 내부 RAM |
| GPIO | `0x2000_0000` | `0x2000_0FFF` | 4 KB | 범용 입출력 제어 |
| FND | `0x2000_1000` | `0x2000_1FFF` | 4 KB | 7-Segment 디스플레이 제어 |
| UART | `0x2000_2000` | `0x2000_2FFF` | 4 KB | 직렬 통신 제어 레지스터 |

---

## 🔑 주요 구현 내용

### 1. Multi-Cycle CPU FSM

명령어 타입별 필요한 스테이지만 실행하여 Single-Cycle 대비 크리티컬 패스를 단축하였습니다.

| 명령어 타입 | 실행 경로 | 사이클 수 |
|-------------|-----------|-----------|
| R / I / B / U / J-type | FETCH → DECODE → EXECUTE → FETCH | 3 |
| S-type | FETCH → DECODE → EXECUTE → MEM → FETCH | 4 |
| Load (IL-type) | FETCH → DECODE → EXECUTE → MEM → WB → FETCH | 5 |

**타이밍 비교 (Vivado Implementation)**

| 구분 | WNS | TNS | Failing Endpoints |
|------|-----|-----|-------------------|
| Single-Cycle | −2.874 ns | −459 ns | 225 |
| **Multi-Cycle** | **+0.333 ns** | **0 ns** | **0** |

### 2. APB Bus Master

ARM AMBA APB 프로토콜 기반의 3-state FSM으로 구현하였습니다.

```
IDLE ──(WREQ | RREQ)──► SETUP ──► ACCESS ──(PREADY=1)──► IDLE
```

- **addr_decoder**: `PADDR[31:28]` 및 `PADDR[15:12]`로 PSEL0~PSEL3 자동 생성
- **apb_mux**: PADDR 기준으로 해당 슬레이브의 PRDATA / PREADY를 CPU로 라우팅
- Wait state 지원 — PREADY=0이면 ACCESS 상태 유지

**시뮬레이션 시나리오**

| 시나리오 | 타겟 | 주소 | Wait State | 검증 목적 |
|----------|------|------|-----------|----------|
| Case 1 | RAM (PSEL0) | `0x1000_0000` | 0 Cycle | 즉각 응답 검증 |
| Case 2 | GPIO (PSEL1) | `0x2000_0000` | 0 Cycle | 즉각 응답 검증 |
| Case 3 | FND (PSEL2) | `0x2000_1000` | 1 Cycle | Wait state 시 ACCESS 유지 검증 |
| Case 4 | UART (PSEL3) | `0x2000_2000` | 2 Cycle | 다중 Wait state 안정성 검증 |

### 3. Peripheral 검증 시나리오

개별 모듈 시뮬레이션으로 각 페리페럴의 동작을 독립적으로 검증한 뒤 통합하였습니다.

* **Multi-Cycle CPU**: R / I / S / B / U / J 전 타입 명령어 waveform 검증
* **APB Master**: 0-wait(BRAM, GPIO), 1-wait(FND), 2-wait(UART) 시나리오 검증
* **BRAM**: C 펌웨어에서 0번지 값 읽기, 1번지에 `0x12345678` 저장 검증
* **GPIO**: switch → CTL 설정 → IDATA 읽기 → ODATA LED 출력 검증
* **FND**: ODATA write → fnd_controller digit split → 7-segment 출력 검증
* **UART**: `tx_n` 1~4회 반복, `baud_reg` 9600/19200/115200bps 전환, error 플래그 검증

통합 FPGA 동작 시나리오는 다음 순서로 검증하였습니다.

```
1. sys_init()        — RAM / GPIO / FND / UART 레지스터 초기화 및 검증
2. GPIO_CTL 설정     — GPIO[15:8]=LED output, GPIO[7:0]=SW input (0xFF00)
3. SW → FND          — SW 값 읽기 → FND 레지스터 write → FND 숫자 표시
4. FND → UART        — digit split 값 읽어 UART TX로 PC 전송 (4byte, 115200bps)
5. LED blink         — SW 값과 반전 값 2초 주기 교번 출력
```

---

## 🚀 문제 해결 (Troubleshooting)

### 1. Single-Cycle 타이밍 위반

* **문제**: 크리티컬 패스 지연으로 WNS −2.874 ns, 225개 endpoint 위반.
* **해결**: Multi-Cycle 구조로 전환하여 스테이지 간 레지스터 삽입 → WNS +0.333 ns 달성.

### 2. APB Master IDLE에서 PADDR/PWDATA 소실

* **문제**: WREQ/RREQ가 1클럭만 유지될 경우 SETUP 진입 후 PADDR가 0으로 돌아가는 현상.
* **해결**: IDLE 상태 combinational 블록에서 `PADDR_next = Addr`로 미리 래치하여 SETUP/ACCESS 구간 동안 값 유지.

### 3. GPIO/GPI/GPO 분리 → 통합

* **문제**: GPO/GPI를 별도 슬레이브로 분리하면 방향 제어 불가 및 슬레이브 수 증가.
* **해결**: CTL/ODATA/IDATA 레지스터를 가진 단일 `APB_GPIO` 슬레이브로 통합, `generate` 블록으로 핀별 tristate 버퍼 구현.

---

## 📚 배운 점

* **버스 프로토콜 설계**: APB의 SETUP/ACCESS 2-phase 핸드셰이크를 직접 구현하면서, 단순한 신호 연결이 아니라 마스터-슬레이브 간 타이밍 계약을 설계하는 것임을 이해. PADDR 소실 버그처럼 combinational/sequential 경계에서의 래치 타이밍이 프로토콜 안정성을 결정함을 체감.
* **Multi-Cycle 구조의 트레이드오프**: Single-Cycle의 타이밍 위반을 FSM 분할로 해소할 수 있지만, CPI 3~5라는 구조적 비용이 생긴다는 것을 수치로 직접 확인. 파이프라인이 왜 필요한지를 설계를 통해 이해.
* **SoC 통합 검증**: 모듈 단독 시뮬레이션이 통과해도 버스로 연결하면 새로운 문제가 생긴다는 것을 경험. 슬레이브 설계 단계부터 레지스터 맵과 Wait state 정책을 명확히 정의해야 통합 시 충돌이 없다는 것을 팀 프로젝트를 통해 체득.

---

## 📌 향후 개선 방향

* 인터럽트 및 CSR 레지스터 미구현
* UART RX 수신 데이터의 CPU 인터럽트 통지 미지원 (폴링 방식)
* BRAM 크기 1024 word(4 KB) 고정 — 대용량 펌웨어 탑재 시 조정 필요
* `data_mem.sv`는 현재 미사용 (BRAM Slave로 대체됨)

---

## 🖥️ 개발 환경

| 항목 | 내용 |
|------|------|
| HDL | SystemVerilog / Verilog |
| EDA Tool | Xilinx Vivado |
| 타겟 보드 | Digilent Basys3 (Xilinx Artix-7) |
| Cross Compiler | RISC-V GCC (`riscv32-unknown-elf-gcc`) |

---

## 📁 파일 구성

```text
├── RV32I_top.sv                 # 최상위 모듈 (rv32i_mcu) - 전체 SoC 연결
├── RV32I_cpu.sv                 # Multi-Cycle CPU 코어 (Control Unit FSM + Datapath)
├── rv32i_datapath.sv            # Datapath 전체 (레지스터파일, ALU, PC, 즉시값 확장 등)
├── instruction_mem.sv           # 명령어 ROM ($readmemh 로드)
├── data_mem.sv                  # 데이터 RAM (byte-addressable, 미사용 - BRAM으로 대체)
├── define.vh                    # opcode, funct3, ALU 연산 매크로 정의
│
├── APB_Master.sv                # APB Bus Master (IDLE/SETUP/ACCESS FSM, addr_decoder, apb_mux)
│
├── Slave.sv                     # APB BRAM Slave
├── APB_GPIO.sv                  # APB GPIO Slave (CTL / ODATA / IDATA 레지스터)
├── GPI_Slave.sv                 # APB GPI Slave (미사용 - GPIO로 통합)
├── GPO_Slave.sv                 # APB GPO Slave (미사용 - GPIO로 통합)
├── APB_FND.sv                   # APB FND Slave (ODATA / LOAD 레지스터)
├── APB_UART.sv                  # APB UART Slave (cntl / baud / tx_data / rx_data 레지스터)
│
├── fnd_controller.v             # FND digit split / scan / BCD 디코더
├── uart_top.v                   # UART TX / RX / baud_tick_gen 통합 모듈
│
└── riscv_rv32i_rom_data.mem     # ROM 초기화 데이터 (hex, $readmemh 용)
