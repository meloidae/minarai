# minarai

WIP: gameboy emulator

Nothing works yet


## TODO
- [x] bg rendering
- [ ] obj rendering
- [ ] window rendering
- [ ] oam dma transfer
- [ ] start from commandline (not iex)


## Notes
Only hram is accessible by cpu during oam dma transfer & hram can't be the source of dma transfer
-> The source region of dma transfer cannot be written to during the transfer
-> Should be okay to get all source region at once, then write them to the destination region onde by one

RLCA, RLA, RRCA, and RRA are different from RLC, RL, RRC and RR
- the z flag is always reset after RLCA, RLA RRCA or RRA regardless of the computed value
- the z flag is set accordingly after RLC, RL, RRC or RR

Lower nibble of F register is always zero
- Make sure to mask with 0xf0 when putting a value into F


## blargg tests
### cpu_instrs
- [x] 01-special.gb
- [ ] 02-interrupts.gb
- [ ] 03-op sp,hl.gb"
- [x] 04-op r,imm.gb"
- [x] 05-op rp.gb"
- [x] 06-ld r,r.gb"
- [ ] 07-jr,jp,call,ret,rst.gb"
- [x] 08-misc instrs.gb"
- [x] 09-op r,r.gb"
- [x] 10-bit ops.gb"
- [x] 11-op a,(hl).gb"


