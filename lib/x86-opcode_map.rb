# coding: utf-8
# This script is a part of DAsse(https://github.com/hisui/dasse)

require "../ext/rjquery"

##
## オペコードマップ - こちらから拝借: http://www.logix.cz/michal/doc/i386/app-a.htm
##
##   ** この表からHTMLのテーブルを生成します
##   ** 便利のためGrp#は改変してあり、オリジナルのものとは対応していないので注意！
##   ** 等幅フォントで見てください。タブ文字(\t)は禁止
##   ** ( ... ) はコメントとして扱われます
##   ** 同一の列中の、上セルと下セルは単純に結合されます(例: 00 "ADD Eb,Gb", 01 "ADD Ev,Gv")
##   ** オペランドは必ず "," 区切り
##

# One-Byte Opcode Map
ONE_BYTE_OPCODE_MAP = <<ONE_BYTE_OPCODE_MAP

  0         1         2         3         4         5         6        7        8         9         A         B         C         D         E        F
0 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                            ADD                            |  PUSH  |   POP  |                             OR                            |  PUSH  |(2-byte  |
  |---------+---------+---------+---------+---------+---------+        |        +---------+---------+---------+---------+---------+---------+        |         |
  |  Eb,Gb  |  Ev,Gv  |  Gb,Eb  |  Gv,Ev  |  AL,Ib  | eAX,Iv  |   ES   |   ES   |  Eb,Gb  |  Ev,Gv  |  Gb,Eb  |  Gv,Ev  |  AL,Ib  | eAX,Iv  |   CS   | escape) |
1 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                            ADC                            |  PUSH  |   POP  |                            SBB                            |  PUSH  |  POP    |
  |---------+---------+---------+---------+---------+---------+        |        +---------+---------+---------+---------+---------+---------+        |         |
  |  Eb,Gb  |  Ev,Gv  |  Gb,Eb  |  Gv,Ev  |  AL,Ib  | eAX,Iv  |   SS   |   SS   |  Eb,Gb  |  Ev,Gv  |  Gb,Eb  |  Gv,Ev  |  AL,Ib  | eAX,Iv  |   DS   |   DS    |
2 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                            AND                            | (SEG   |        |                            SUB                            | (SEG   |         |
  |---------+---------+---------+---------+---------+---------+        |   DAA  +---------+---------+---------+---------+---------+---------+        |   DAS   |
  |  Eb,Gb  |  Ev,Gv  |  Gb,Eb  |  Gv,Ev  |  AL,Ib  | eAX,Iv  |  =ES)  |        |  Eb,Gb  |  Ev,Gv  |  Gb,Eb  |  Gv,Ev  |  AL,Ib  | eAX,Iv  |  =CS)  |         |
3 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                            XOR                            | (SEG   |        |                            CMP                            | (SEG   |         |
  |---------+---------+---------+---------+---------+---------+        |   AAA  +---------+---------+---------+---------+---------+---------+        |   AAS   |
  |  Eb,Gb  |  Ev,Gv  |  Gb,Eb  |  Gv,Ev  |  AL,Ib  | eAX,Iv  |  =SS)  |        |  Eb,Gb  |  Ev,Gv  |  Gb,Eb  |  Gv,Ev  |  AL,Ib  | eAX,Iv  |  =CS)  |         |
4 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                                      INC                                    |                                      DEC                                     |
  |---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------|
  |   eAX   |   eCX   |   eDX   |   eBX   |   eSP   |   eBP   |  eSI   |  eDI   |   eAX   |   eCX   |   eDX   |   eBX   |   eSP   |   eBP   |   eSI  |   eDI   |
5 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                                     PUSH                                    |                                      POP                                     |
  |---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------|
  |   eAX   |   eCX   |   eDX   |   eBX   |   eSP   |   eBP   |  eSI   |  eDI   |   eAX   |   eCX   |   eDX   |   eBX   |   eSP   |   eBP   |  eSI   |   eDI   |
6 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |         |         |  BOUND  |  ARPL   |  (SEG   |  (SEG   |(Operand|(Address|  PUSH   |  IMUL   |  PUSH   |  IMUL   |  INSB   | INSW/D  | OUTSB  | OUTSW/D |
  |  PUSHA  |  POPA   |         |         |         |         |        |        |         |         |         |         |         |         |        |         |
  |         |         |  Gv,Ma  |  Ew,Rw  |   =FS)  |   =GS)  |  Size) |  Size) |   Iv    |Gv,Ev,Iv |   Ib    |Gv,Ev,Ib |  Yb,DX  |  Yb,DX  | DX,Xb  |  DX,Xv  |
7 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                     (Short-displacement jump of condition)                  |                    (Short-displacement jump on condition)                    |
  |---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------|
  |  JO Jb  | JNO Jb  |  JB Jb  | JNB Jb  |  JZ Jb  | JNZ Jb  | JBE Jb |JNBE Jb |  JS Jb  | JNS Jb  |  JP Jb  | JNP Jb  |  JL Jb  | JNL Jb  | JLE Jb | JNLE Jb |
8 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |    (Immediate)    |         |         |       TEST        |      XCHG       |                  MOV                  |   MOV   |   LEA   |  MOV   |   POP   |
  |---------+---------+         |  Grp#0  +---------+---------+--------+--------+---------+---------+---------+---------+         |         |        |         |
  |  Grp#0  |  Grp#1  |         |         |  Eb,Gb  |  Ev,Gv  |  Eb,Gb |  Ev,Gv |  Eb,Gb  |  Ev,Gv  |  Gb,Eb  |  Gv,Ev  |  Ew,Sw  |  Gv,Mv  |  Sw,Ew |   Ev    |
9 +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |         |              XCHG(word or double-word register with eAX)          |         |         |  CALL   |         |  PUSHF  |  POPF   |        |         |
  |   NOP   +---------+---------+---------+---------+---------+--------+--------+   CBW   |   CWD   |         |  WAIT   |         |         |  SAHF  |  LAHF   |
  |         | eCX,eAX | eDX,eAX | eBX,eAX | eSP,eAX | eBP,eAX |eSI,eAX |eDI,eAX |         |         |   Ap    |         |   Fv    |   Fv    |        |         |
A +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                  MOV                  |  MOVSB  | MOVSW/D | CMPSB  |CMPSW/D |       TEST        |  STOSB  | STOSW/D |  LODSB  | LODSW/D | SCASB  | SCASW/D |
  |---------+---------+---------+---------+         |         |        |        +---------+---------+         |         |         |         |        |         |
  |  AL,Ob  |  eAX,Ov |  Ob,AL  |  Ov,eAX |  Xb,Yb  |  Xv,Yv  |  Xb,Yb |  Xv,Yv |  AL,Ib  | eAX,Iv  |  Yb,AL  |  Yv,eAX |  AL,Xb  | eAX,Xv  |  AL,Xb | eAX,Xv  |
B +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                       MOV(immediate byte into byte register)                |        MOV(immediate word or double into word or double register)            |
  |---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------|
  |  AL,Ib  |  CL,Ib  |  DL,Ib  |  BL,Ib  |  AH,Ib  |  CH,Ib  |  DH,Ib |  BH,Ib | eAX,Iv  | eCX,Iv  | eDX,Iv  | eBX,Iv  | eSP,Iv  | eBP,Iv  | eSI,Iv | eDI,Iv  |
C +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |      (Shift)      |      RET(near)    |   LES   |   LDS   |       MOV       |  ENTER  |         |      RET(far)     |  INT    |  INT    |        |         |
  |---------+---------+---------+---------+         |         +--------+--------+         |  LEAVE  +---------+---------+         |         |  INTO  |  IRET   |
  |  Grp#2  |  Grp#3  |    Iw   |         |  Gv,Mp  |  Gv,Mp  |  Eb,Ib |  Ev,Iv |  Iw,Ib  |         |   Iw    |         |   3     |  Ib     |        |         |
D +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |                (Shift)                |         |         |        |        |                                                                              |
  |---------+---------+---------+---------+   AAM   |   AAD   |        |  XLAT  |                    (Escape to coprocessor instruction set)                   |
  |  Grp#4  |  Grp#5  |  Grp#6  |  Grp#7  |         |         |        |        |                                                                              |
E +---------+---------+---------+---------+---------+---------+--------+--------+---------+-----------------------------+-------------------+------------------+
  | LOOPNE  |  LOOPE  |   LOOP  |  JCXZ   |        IN         |       OUT       |   CALL  |             JNP             |        IN         |       OUT        |
  |         |         |         |         +---------+---------+--------+--------+         +---------+---------+---------+---------+---------+--------+---------|
  |   Jb    |   Jb    |    Jb   |   Jb    |  AL,Ib  | eAX,Ib  |  Ib,AL | Ib,eAX |    Av   |   Jv    |   Ap    |   Jb    |  AL,DX  | eAX,DX  | DX,AL  | DX,eAX  |
F +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+
  |         |         |         |  (REP   |         |         |     (Unary)     |         |         |         |         |         |         |(INC    |(Indirct)|
  |  LOCK   |         | (REPNE) |         |   HLT   |   CMC   +--------+--------+   CLC   |   STC   |   CLI   |   STI   |   CLD   |   STD   |/DEC)   |         |
  |         |         |         |  REPE)  |         |         | Grp#8  | Grp#9  |         |         |         |         |         |         | Grp#A  | Grp#B   |
  +---------+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+---------+---------+---------+--------+---------+

ONE_BYTE_OPCODE_MAP
ONE_BYTE_OPCODE_MAP.strip!


# Two-Byte Opcode Map (first byte is 0FH)
TWO_BYTE_OPCODE_MAP = <<TWO_BYTE_OPCODE_MAP

  0         1         2         3         4         5         6        7         8         9         A         B         C         D         E        F
0 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |   LAR   |   LSL   |         |         |        |         |         |         |         |         |         |         |        |        |
  |  Grp#C  |  Grp#D  |         |         |         |         |  CLTS  |         |         |         |         |         |         |         |        |        |
  |         |         |  Gw,Ew  |  Gv,Ew  |         |         |        |         |         |         |         |         |         |         |        |        |
1 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
2 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |   MOV   |   MOV   |   MOV   |   MOV   |   MOV   |         |   MOV  |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |  Cd,Rd  |  Dd,Rd  |  Rd,Cd  |  Rd,Dd  |  Td,Rd  |         |  Rd,Td |         |         |         |         |         |         |         |        |        |
3 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
4 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
5 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
6 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |(MOVDQA)|
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
7 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |(MOVDQA)|
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
8 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |                      (Long-displacement jump on condition)                   |                    (Long-displacement jump on condition)                    |
  |---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------|
  |  JO Jv  | JNO Jv  |  JB Jv  | JNB Jv  |  JZ Jv  | JNZ Jv  | JBE Jv | JNBE Jv |  JS Jv  | JNS Jv  |  JP Jv  | JNP Jv  |  JL Jv  | JNL Jv  | JLE Jv |JNLE Jv |
9 +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |                               (Byte Set on condition)                        |         |         |         |         |         |         |        |        |
  |---------+---------+---------+---------+---------+---------+--------+---------+  SETS   |  SETNS  |  SETP   |  SETNP  |  SETL   |  SETNL  |  SETLE | SETNLE |
  | SETO Eb |SETNO Eb | SETB Eb |SETNB Eb | SETZ Eb |SETNZ Eb |SETBE Eb|SETNBE Eb|         |         |         |         |         |         |        |        |
A +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |  PUSH   |   POP   |         |   BT    |  SHLD   |  SHLD   |        |         |  PUSH   |   POP   |         |   BTS   |  SHRD   |  SHRD   |        |  IMUL  |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |   FS    |   FS    |         |  Ev,Gv  |Ev,Gv,Ib |Ev,Gv,CL |        |         |   GS    |   GS    |         |  Ev,Gv  |Ev,Gv,Ib |Ev,Gv,CL |        | Gv,Ev  |
B +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |   LSS   |   BTR   |   LFS   |   LGS   |      MOVZX       |         |         |         |   BTC   |   BSF   |   BSR   |      MOVSX      |
  |         |         |         |         |         |         +--------+---------+         |         |  Grp#E  |         |         |         +-----------------|
  |         |         |   Mp    |  Ev,Gv  |   Mp    |   Mp    | Gv,Eb  |  Gv,Ew  |         |         |         |  Ev,Gv  |  Gv,Ev  |  Gv,Ev  |  Gv,Eb | Gv,Ew  |
C +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
D +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
E +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        | (PXOR) |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
F +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  |         |         |         |         |         |         |        |         |         |         |         |         |         |         |        |        |
  +---------+---------+---------+---------+---------+---------+--------+---------+---------+---------+---------+---------+---------+---------+--------+--------+

TWO_BYTE_OPCODE_MAP
TWO_BYTE_OPCODE_MAP.strip!


# Opcodes determined by bits 5,4,3 of modR/M byte
GROUP_TABLE = <<GROUP_TABLE

  000     001     010     011     100     101     110     111
0 +-------+-------+-------+-------+-------+-------+-------+-------+
  |  ADD  |  OR   |  ADC  |  SBB  |  AND  |  SUB  |  XOR  |  CMP  |
  | Eb,Ib | Eb,Ib | Eb,Ib | Eb,Ib | Eb,Ib | Eb,Ib | Eb,Ib | Eb,Ib |
1 +-------+-------+-------+-------+-------+-------+-------+-------+
  |  ADD  |  OR   |  ADC  |  SBB  |  AND  |  SUB  |  XOR  |  CMP  |
  | Ev,Iv | Ev,Iv | Ev,Iv | Ev,Iv | Ev,Iv | Ev,Iv | Ev,Iv | Ev,Iv |
2 +-------+-------+-------+-------+-------+-------+-------+-------+
  |  ROL  |  ROR  |  RCL  |  RCR  |  SHL  |  SHR  |       |  SAR  |
  | Eb,Ib | Eb,Ib | Eb,Ib | Eb,Ib | Eb,Ib | Eb,Ib |       | Eb,Ib |
3 +-------+-------+-------+-------+-------+-------+-------+-------+
  |  ROL  |  ROR  |  RCL  |  RCR  |  SHL  |  SHR  |       |  SAR  |
  | Ev,Iv | Ev,Iv | Ev,Iv | Ev,Iv | Ev,Ib | Ev,Ib |       | Ev,Ib |
4 +-------+-------+-------+-------+-------+-------+-------+-------+
  |  ROL  |  ROR  |  RCL  |  RCR  |  SHL  |  SHR  |       |  SAR  |
  | Eb,1  | Eb,1  | Eb,1  | Eb,1  | Eb,1  | Eb,1  |       | Eb,1  |
5 +-------+-------+-------+-------+-------+-------+-------+-------+
  |  ROL  |  ROR  |  RCL  |  RCR  |  SHL  |  SHR  |       |  SAR  |
  | Ev,1  | Ev,1  | Ev,1  | Ev,1  | Ev,1  | Ev,1  |       | Ev,1  |
6 +-------+-------+-------+-------+-------+-------+-------+-------+
  |  ROL  |  ROR  |  RCL  |  RCR  |  SHL  |  SHR  |       |  SAR  |
  | Eb,CL | Eb,CL | Eb,CL | Eb,CL | Eb,CL | Eb,CL |       | Eb,CL |
7 +-------+-------+-------+-------+-------+-------+-------+-------+
  |  ROL  |  ROR  |  RCL  |  RCR  |  SHL  |  SHR  |       |  SAR  |
  | Ev,CL | Ev,CL | Ev,CL | Ev,CL | Ev,CL | Ev,CL |       | Ev,CL |
8 +-------+-------+-------+-------+-------+-------+-------+-------+
  | TEST  |       |  NOT  |  NEG  |  MUL  | IMUL  |  DIV  | IDIV  |
  | Eb,Ib |       |  Eb   |  Eb   | Eb,AL | Eb,AL | Eb,AL | Eb,AL |
9 +-------+-------+-------+-------+-------+-------+-------+-------+
  | TEST  |       |  NOT  |  NEG  |  MUL  | IMUL  |  DIV  | IDIV  |
  | Ev,Iv |       |  Ev   |  Ev   | Ev,AL | Ev,AL | Ev,AL | Ev,AL |
A +-------+-------+-------+-------+-------+-------+-------+-------+
  |  INC  |  DEC  |       |       |       |       |       |       |
  |  Eb   |  Eb   |       |       |       |       |       |       |
B +-------+-------+-------+-------+-------+-------+-------+-------+
  |  INC  |  DEC  | CALL  | CALL  |  JMP  |  JMP  | PUSH  |       |
  |  Ev   |  Ev   |  Ev   |  Ep   |  Ev   |  Ep   |  Ev   |       |
C +-------+-------+-------+-------+-------+-------+-------+-------+
  | SLDT  |  STR  | LLDT  |  LTR  | VERR  | VERW  |       |       |
  |  Ew   |  Ew   |  Ew   |  Ew   |  Ew   |  Ew   |       |       |
D +-------+-------+-------+-------+-------+-------+-------+-------+
  | SGDT  | SIDT  | LGDT  | LIDT  | SMSW  |       | LMSW  |       |
  |  Ms   |  Ms   |  Ms   |   Ms  |  Ew   |       |  Ew   |       |
E +-------+-------+-------+-------+-------+-------+-------+-------+
  |       |       |       |       |  BT   |  BTS  |  BTR  |  BTC  |
  |       |       |       |       | Ev,Ib | Ev,Ib | Ev,Ib | Ev,Ib |
  +-------+-------+-------+-------+-------+-------+-------+-------+

GROUP_TABLE
GROUP_TABLE.strip!


# 表を解析して行列データ化
def parse_text_grid(source)
	lines = source.gsub(/^[\dA-F]?\s+/, "").each_line.map(&:strip)
	lines.shift
	
	col_offsets = []
	i = 0
	while off = lines[0].index("+-", i)
		col_offsets << off
		i = off + 2
	end

	rows = [[]]
	lines[1..-1].each {|line|
		line[0] == "+" ? rows << []: rows[-1] << line
	}
	
	grid = []
	rows.each {|row|
		break unless row[0]
		cols = []
		i = 1
		while i+1 < row[0].size
			k = row[0].index "|", i
			j = 0
			data  =      row[0][i...k].strip
			data += " "+ row[j][i...k].strip while (j+=1) < row.size && row[j][i] != "-"
			data.strip!
			if (j+=1) < row.size
				a = i
				while (b = row[j].index("|", a) || row[j].size) <= k
					cols << data + row[j][a...b]
					a = b + 1
				end
			else
				col_offsets.count {|e| i-1 <= e && e < k }.times { cols << data }
			end
			i = k + 1
		end
		grid << cols
	}
	# コメントの削除
	grid.each {|cols| cols.map! {|e| e.gsub(/\(.*?\)/, "") }}
	grid
end


# テンプレからHTMLを生成
doc = RjQuery <<HTML
<html>
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>x86 Opcode Map</title>
		<link rel="STYLESHEET" href="x86-opcode_map.css" type="text/css">
	</head>
	<body>
		<h1>x86 Opcode Map</h1>
		<p>
			このファイルは<a href="x86-opcode_map.rb">x86-opcode_map.rb</a>によって自動生成され、
			<a href="x86.rb">x86.rb</a>の動作に必要です。
		</p>
		<div>
			<h3>Opcode Map (1-byte)</h3>
			<table id="opcode_map1" />
		</div>
		<div>
			<h3>Opcode Map (2-byte)</h3>
			<table id="opcode_map2" />
		</div>
		<div>
			<h3>Group</h3>
			<table id="group_table" />
		</div>
	</body>
</html>
HTML

def build_table(table, opcode_map)
	thead = RjNode.new "thead"
	   tr = RjNode.new "tr"
	thead << tr
	   tr << RjNode.new("th")
	opcode_map[0].size.times {|i|
		th = RjNode.new "th"
		tr << th
		th << "%X" % i
	}
	tbody = RjNode.new "tbody"
	opcode_map.each_with_index {|row, i|
		tbody << ( tr = RjNode.new("tr") )
		   tr << ( th = RjNode.new("th") )
		   th << "%X" % i
		   row.each_with_index {|e, j|
			tr << ( td = RjNode.new("td", {title: "%x%x" % [i, j]}) )
			td << e
		}
	}
	table << thead
	table << tbody
end

build_table doc.find("#opcode_map1"), parse_text_grid(ONE_BYTE_OPCODE_MAP)
build_table doc.find("#opcode_map2"), parse_text_grid(TWO_BYTE_OPCODE_MAP)
build_table doc.find("#group_table"), parse_text_grid(GROUP_TABLE)

File.open("x86-opcode_map.html", "wb") {|io| io.print doc.to_s }

puts "done."

