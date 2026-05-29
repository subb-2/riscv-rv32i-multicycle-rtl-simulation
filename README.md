# RV32I Multi-Cycle SoC

> RISC-V RV32I ISA 기반 Multi-Cycle CPU + APB Bus + Peripheral을 설계한 SoC 프로젝트  
> Xilinx Basys3 (Artix-7) FPGA에서 C 펌웨어 동작까지 검증 완료

---

## 📌 프로젝트 개요

본 프로젝트는 RV32I ISA의 모든 명령어 타입(R / I / S / B / U / J)을 지원하는 **Multi-Cycle CPU**를 설계하고,  
**APB Bus Master**를 통해 BRAM / GPIO / FND / UART 페리페럴을 연결한 완성형 SoC입니다.

C 코드를 RISC-V 어셈블리로 크로스 컴파일한 `.mem` 파일을 ROM에 탑재하여,  
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

## 🏗️ System Architecture

```


                        ┌──────────────────────────────────────────────────┐
                         │                  rv32I_mcu (Top)                 │
                         │                                                  │
  clk ─────────────────► │  ┌──────────────┐   ┌──────────────────────────┐│
  rst ─────────────────► │  │instruction   │   │       APB Bus Master     ││
  GPIO[15:0] (inout) ──► │  │    _mem(ROM) │   │  IDLE → SETUP → ACCESS  ││
  uart_rx ─────────────► │  └──────┬───────┘   │  addr_decoder / apb_mux ││
  GPI[7:0] ────────────► │   instr │            └──────────┬───────────────┘│
                         │         ▼                       │ APB Bus         │
                         │  ┌──────────────┐    ┌─────────▼──────────────┐ │
                         │  │  RV32I_cpu   │    │  BRAM │ GPIO │ FND │   │ │
                         │  │(Multi-Cycle) │◄──►│       APB Slaves       │ │
                         │  └──────────────┘    └────────────────────────┘ │
                         └──────────────────────────────────────────────────┘
                                                        │
                              fnd_digit / fnd_data ─────┤
                              GPO / uart_tx ────────────┘
```

---

## 🗺️ Memory Map

| Peripheral | Base Address   | End Address    | Size  | 설명                      |
|------------|----------------|----------------|-------|---------------------------|
| RAM (BRAM) | `0x1000_0000`  | `0x1000_0FFF`  | 4 KB  | 데이터 저장용 내부 RAM    |
| Reserve    | `0x1000_1000`  | `0x1FFF_FFFF`  | —     | 향후 확장 예약 영역       |
| GPIO       | `0x2000_0000`  | `0x2000_0FFF`  | 4 KB  | 범용 입출력 제어          |
| FND        | `0x2000_1000`  | `0x2000_1FFF`  | 4 KB  | 7-Segment 디스플레이 제어 |
| UART       | `0x2000_2000`  | `0x2000_2FFF`  | 4 KB  | 직렬 통신 제어 레지스터   |

---

## 📁 파일 구성

```
├── RV32I_top.sv            # 최상위 모듈 (rv32I_mcu) — 전체 SoC 연결
├── RV32I_cpu.sv            # Multi-Cycle CPU 코어 (Control Unit FSM + Datapath)
├── rv32i_datapath.sv       # Datapath (레지스터파일, ALU, PC, 즉치 확장 등)
├── instruction_mem.sv      # 명령어 ROM ($readmemh 로드)
├── data_mem.sv             # 데이터 RAM (byte-addressable, 미사용 — BRAM으로 대체)
├── define.vh               # opcode · funct3 · ALU 연산 매크로 정의
│
├── APB_Master.sv           # APB Bus Master (IDLE/SETUP/ACCESS FSM, addr_decoder, apb_mux)
├── Slave.sv                # APB BRAM Slave
├── APB_GPIO.sv             # APB GPIO Slave (CTL / ODATA / IDATA 레지스터)
├── GPI_Slave.sv            # APB GPI Slave (미사용 — GPIO로 통합)
├── GPO_Slave.sv            # APB GPO Slave (미사용 — GPIO로 통합)
├── APB_FND.sv              # APB FND Slave (ODATA / LOAD 레지스터)
├── APB_UART.sv             # APB UART Slave (cntl / baud / tx_data / rx_data 레지스터)
│
├── fnd_controller.v        # FND digit split / scan / BCD 디코더
├── uart_top.v              # UART TX / RX / baud_tick_gen 통합 모듈
│
└── riscv_ru32i_rom_data.mem  # ROM 초기화 데이터 (hex, $readmemh 용)
```

---

## ⚙️ Multi-Cycle CPU

### FSM 상태 구성

명령어 타입별로 필요한 사이클 수가 다르게 설계되었습니다.

| 명령어 타입 | 실행 경로                        | 사이클 수 |
|-------------|----------------------------------|-----------|
| R-type      | FETCH → DECODE → EXECUTE → FETCH | 3         |
| I-type      | FETCH → DECODE → EXECUTE → FETCH | 3         |
| B-type      | FETCH → DECODE → EXECUTE → FETCH | 3         |
| U-type (LUI/AUIPC) | FETCH → DECODE → EXECUTE → FETCH | 3   |
| J-type (JAL/JALR)  | FETCH → DECODE → EXECUTE → FETCH | 3   |
| S-type      | FETCH → DECODE → EXECUTE → MEM → FETCH | 4  |
| IL-type (Load) | FETCH → DECODE → EXECUTE → MEM → WB → FETCH | 5 |

### 지원 명령어

| 타입 | 명령어 |
|------|--------|
| R-Type | ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND |
| I-Type | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI |
| Load   | LB, LH, LW, LBU, LHU |
| S-Type | SB, SH, SW |
| B-Type | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| U-Type | LUI, AUIPC |
| J-Type | JAL, JALR |

### 타이밍 비교 (Vivado Implementation)

| 구분 | WNS | TNS | Failing Endpoints |
|------|-----|-----|-------------------|
| Single-Cycle | −2.874 ns | −459 ns | 225 |
| **Multi-Cycle** | **+0.333 ns** | **0 ns** | **0** |

---

## 🔌 APB Bus Master

ARM AMBA APB 프로토콜 기반의 3-state FSM으로 구현되었습니다.

```
IDLE ──(WREQ | RREQ)──► SETUP ──► ACCESS ──(PREADY)──► IDLE
         decode_en=0       decode_en=1   decode_en=1
         PENABLE=0         PENABLE=0     PENABLE=1
```

- **addr_decoder**: `PADDR[31:28]` 및 `PADDR[15:12]`로 PSEL0~PSEL3 자동 생성
- **apb_mux**: PADDR 기준으로 해당 슬레이브의 PRDATA / PREADY를 CPU로 라우팅
- Wait state 지원 — PREADY=0이면 ACCESS 상태 유지

---

## 🧩 Peripheral 레지스터 맵

### GPIO (`0x2000_0000`)

| Offset | 이름            | R/W | 설명                            |
|--------|-----------------|-----|---------------------------------|
| `0x00` | GPIO_CTL        | W   | `[15:0]` 핀별 방향 (1=Output, 0=Input) |
| `0x04` | GPIO_ODATA      | W   | `[15:0]` 출력 데이터            |
| `0x08` | GPIO_IDATA      | R   | `[15:0]` 입력 데이터            |

### FND (`0x2000_1000`)

| Offset | 이름            | R/W | 설명                                           |
|--------|-----------------|-----|------------------------------------------------|
| `0x00` | FND_ODATA       | W   | `[13:0]` 표시 숫자 데이터                      |
| `0x04` | FND_LOAD        | W   | `[15:12]`=1000자리, `[11:8]`=100자리, `[7:4]`=10자리, `[3:0]`=1자리 활성화 |

### UART (`0x2000_2000`)

| Offset | 이름            | R/W | 설명                                                 |
|--------|-----------------|-----|------------------------------------------------------|
| `0x00` | CNTL_REG        | W   | `[3:2]`=tx_n (반복 횟수), `[1]`=rx_en, `[0]`=tx_en |
| `0x04` | BAUD_REG        | W   | `[1:0]` — `00`:9600bps, `01`:19200bps, `10`:115200bps |
| `0x08` | TX_DATA_REG     | W   | `[15:0]` 송신 데이터 (BCD 4자리 packed)              |
| `0x0C` | RX_DATA_REG     | R   | `[7:0]` 수신 데이터                                  |

---

## 🖥️ 개발 환경

| 항목 | 내용 |
|------|------|
| HDL | SystemVerilog / Verilog |
| EDA Tool | Xilinx Vivado |
| 타겟 보드 | Digilent Basys3 (Xilinx Artix-7) |
| 시뮬레이터 | Vivado Simulator (XSim) |
| Cross Compiler | RISC-V GCC (`riscv32-unknown-elf-gcc`) |

---

## ✅ 검증 시나리오

### 개별 모듈 시뮬레이션

- **Multi-Cycle CPU**: R / I / S / B / U / J 전 타입 명령어 waveform 검증
- **APB Master**: 0-wait(BRAM, GPIO), 1-wait(FND), 2-wait(UART) 시나리오 검증
- **BRAM**: C 펌웨어에서 0번지 값 읽기, 1번지에 `0x12345678` 저장 검증
- **GPIO**: switch → CTL 설정 → IDATA 읽기 → ODATA LED 출력 검증
- **FND**: ODATA write → fnd_controller digit split → 7-segment 출력 검증
- **UART**: `tx_n` 1~4회 반복, `baud_reg` 9600/19200/115200bps 전환, error 플래그 검증

### 통합 FPGA 동작 시나리오

```
1. sys_init() — RAM / GPIO / FND / UART 레지스터 초기화 및 검증
2. GPIO_CTL = 0xFF00 설정 (GPIO[15:8]=LED output, GPIO[7:0]=SW input)
3. SW 값 읽기 → FND 레지스터 write → FND 숫자 표시
4. FND에서 digit split 값 읽어 UART TX로 PC 전송 (4byte, 115200bps)
5. LED blink — SW 값과 반전 값 2초 주기 교번 출력
```

---

## 🐛 Trouble Shooting

### 1. Single-Cycle 타이밍 위반

**문제**: 단일 사이클에서 크리티컬 패스 지연으로 WNS −2.874 ns 발생, 225개 endpoint 위반.

**해결**: Multi-Cycle 구조로 전환하여 각 파이프라인 스테이지 사이에 레지스터를 삽입.  
WNS +0.333 ns로 모든 타이밍 제약 통과.

### 2. APB Master IDLE에서 PADDR/PWDATA 소실

**문제**: WREQ/RREQ가 1클럭만 유지될 경우 SETUP 진입 후 PADDR가 0으로 돌아가는 현상.

**해결**: IDLE 상태의 combinational 블록에서 `PADDR_next = Addr`으로 미리 래치.  
등록된 레지스터 값이 SETUP/ACCESS 구간 동안 유지되도록 수정.

### 3. GPIO/GPI/GPO 분리 → 통합

**문제**: 초기 설계에서 GPO/GPI를 별도 슬레이브로 분리했으나, 방향 제어가 불가하고 슬레이브 수가 증가.

**해결**: CTL/ODATA/IDATA 레지스터를 가진 단일 `APB_GPIO` 슬레이브로 통합.  
`generate` 블록으로 핀별 tristate 버퍼 구현.

---

## 📄 알려진 제한 사항

- 인터럽트 및 CSR 레지스터 미구현
- UART RX 수신 데이터의 CPU 인터럽트 통지 미지원 (폴링 방식)
- BRAM 크기는 1024 word(4 KB)로 고정 — 대용량 펌웨어 탑재 시 조정 필요
- `data_mem.sv`는 현재 미사용 (BRAM Slave로 대체됨)
