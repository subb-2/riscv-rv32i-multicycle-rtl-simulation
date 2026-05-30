# RV32I Multi-Cycle SoC

> RV32I ISA 기반 Multi-Cycle CPU + APB Bus + Peripheral을 설계한 SoC 프로젝트  
> Xilinx Basys3 (Artix-7) FPGA에서 C 펌웨어 동작까지 검증 완료

---

## 📌 프로젝트 개요

본 프로젝트는 RV32I ISA의 모든 명령어 타입(R / I / S / B / U / J)을 지원하는 **Multi-Cycle CPU**를 설계하고,  
**APB Bus Master**를 통해 BRAM / GPIO / FND / UART 페리페럴을 연결한 완성형 SoC입니다.

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

## 🏗️ System Architecture

<p align="center">
<img width="700" alt="System Architecture" src="https://github.com/user-attachments/assets/7f56c930-f64b-4de5-a915-889cb11a2254" />
</p>

---

## 🗺️ Memory Map

| Peripheral | Base Address | End Address | Size | 설명 |
|------------|--------------|-------------|------|------|
| RAM (BRAM) | `0x1000_0000` | `0x1000_0FFF` | 4 KB | 데이터 저장용 내부 RAM |
| GPIO | `0x2000_0000` | `0x2000_0FFF` | 4 KB | 범용 입출력 제어 |
| FND | `0x2000_1000` | `0x2000_1FFF` | 4 KB | 7-Segment 디스플레이 제어 |
| UART | `0x2000_2000` | `0x2000_2FFF` | 4 KB | 직렬 통신 제어 레지스터 |

---

## ⚙️ Multi-Cycle CPU

### FSM 상태 구성

| 명령어 타입 | 실행 경로 | 사이클 수 |
|-------------|-----------|-----------|
| R / I / B / U / J-type | FETCH → DECODE → EXECUTE → FETCH | 3 |
| S-type | FETCH → DECODE → EXECUTE → MEM → FETCH | 4 |
| Load (IL-type) | FETCH → DECODE → EXECUTE → MEM → WB → FETCH | 5 |

### 타이밍 비교 (Vivado Implementation)

| 구분 | WNS | TNS | Failing Endpoints |
|------|-----|-----|-------------------|
| Single-Cycle | −2.874 ns | −459 ns | 225 |
| **Multi-Cycle** | **+0.333 ns** | **0 ns** | **0** |

---

## 🔌 APB Bus Master

ARM AMBA APB 프로토콜 기반의 3-state FSM으로 구현되었습니다.

```
IDLE ──(WREQ | RREQ)──► SETUP ──► ACCESS ──(PREADY=1)──► IDLE
     decode_en=0          decode_en=1    decode_en=1
     PENABLE=0            PENABLE=0      PENABLE=1
```

- **addr_decoder**: `PADDR[31:28]` 및 `PADDR[15:12]`로 PSEL0~PSEL3 자동 생성
- **apb_mux**: PADDR 기준으로 해당 슬레이브의 PRDATA / PREADY를 CPU로 라우팅
- Wait state 지원 — PREADY=0이면 ACCESS 상태 유지

### 시뮬레이션 시나리오

| 시나리오 | 타겟 | 주소 | Wait State | 검증 목적 |
|----------|------|------|-----------|----------|
| Case 1 | RAM (PSEL0) | `0x1000_0000` | 0 Cycle | 즉각 응답 검증 |
| Case 2 | GPIO (PSEL1) | `0x2000_0000` | 0 Cycle | 즉각 응답 검증 |
| Case 3 | FND (PSEL2) | `0x2000_1000` | 1 Cycle | Wait state 시 ACCESS 유지 검증 |
| Case 4 | UART (PSEL3) | `0x2000_2000` | 2 Cycle | 다중 Wait state 안정성 검증 |

---

## 🧩 Peripheral 레지스터 맵

### GPIO (`0x2000_0000`)

| Offset | 이름 | R/W | 설명 |
|--------|------|-----|------|
| `0x00` | GPIO_CTL | W | `[15:0]` 핀별 방향 (1=Output, 0=Input) |
| `0x04` | GPIO_ODATA | W | `[15:0]` 출력 데이터 |
| `0x08` | GPIO_IDATA | R | `[15:0]` 입력 데이터 |

### FND (`0x2000_1000`)

| Offset | 이름 | R/W | 설명 |
|--------|------|-----|------|
| `0x00` | FND_ODATA | W | `[13:0]` 표시 숫자 데이터 |
| `0x04` | FND_LOAD | W | 자릿수별 활성화 |

### UART (`0x2000_2000`)

| Offset | 이름 | R/W | 설명 |
|--------|------|-----|------|
| `0x00` | CNTL_REG | W | `[3:2]`=tx_n, `[1]`=rx_en, `[0]`=tx_en |
| `0x04` | BAUD_REG | W | `00`:9600 / `01`:19200 / `10`:115200bps |
| `0x08` | TX_DATA_REG | W | `[15:0]` 송신 데이터 |
| `0x0C` | RX_DATA_REG | R | `[7:0]` 수신 데이터 |

---

## 🖥️ 개발 환경

| 항목 | 내용 |
|------|------|
| HDL | SystemVerilog / Verilog |
| EDA Tool | Xilinx Vivado |
| 타겟 보드 | Digilent Basys3 (Xilinx Artix-7) |
| Cross Compiler | RISC-V GCC (`riscv32-unknown-elf-gcc`) |

---

## 🐛 Trouble Shooting

### 1. Single-Cycle 타이밍 위반
**문제**: 크리티컬 패스 지연으로 WNS −2.874 ns, 225개 endpoint 위반.  
**해결**: Multi-Cycle 구조로 전환하여 스테이지 간 레지스터 삽입 → WNS +0.333 ns 달성.

### 2. APB Master IDLE에서 PADDR/PWDATA 소실
**문제**: WREQ/RREQ가 1클럭만 유지될 경우 SETUP 진입 후 PADDR가 0으로 돌아가는 현상.  
**해결**: IDLE 상태 combinational 블록에서 `PADDR_next = Addr`로 미리 래치하여 SETUP/ACCESS 구간 동안 값 유지.

### 3. GPIO/GPI/GPO 분리 → 통합
**문제**: GPO/GPI를 별도 슬레이브로 분리하면 방향 제어 불가 및 슬레이브 수 증가.  
**해결**: CTL/ODATA/IDATA 레지스터를 가진 단일 `APB_GPIO` 슬레이브로 통합, `generate` 블록으로 핀별 tristate 버퍼 구현.

---

## 📄 향후 발전 방향 (Future Work)

- Multi-Cycle은 타이밍 위반을 해소하나 CPI 3~5의 구조적 한계가 존재하며, 파이프라인 구조 도입으로 개선 가능
- 인터럽트 및 CSR 레지스터 미구현
- UART RX 수신 데이터 인터럽트 미지원 (폴링 방식)
- BRAM 크기 1024 word(4 KB) — 대용량 펌웨어 탑재 시 조정 필요
