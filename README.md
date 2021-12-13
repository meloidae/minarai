# minarai

WIP: gameboy emulator written in Elixir

To try it out, clone this repository and run the following command in the root directory of the cloned repository.  
```bash
mix minarai -b <path_to_bootrom> -c <path_to_cart>
```
Should work on Windows and Linux as long as Elixir and Erlang are set up with wxWidgets support. 

Controls are:
- A = z key
- B = x key
- Start = c key
- Select = v key
- Directions = arrow keys

## Current state
- Functional graphics
- Functiona keyboard controls
- Supports mbc1 & mbc3 (no RTC functionality)
- No frame throttling (runs much faster than 59.7fps on my laptop)
- No sound
- (Pokemon Yellow is playable)
- FPS is well above 60 on average, but drops below 60 once in every 15 frames or so
  - Something to do with GC?

## GIFs
![intro](README/intro.gif)
![stopped_by_prof](README/stopped_by_prof.gif)

## TODO
- [x] bg rendering
- [x] obj rendering
- [x] window rendering
- [ ] oam dma transfer (transfer is instantaneous atm)
- [x] joypad
- [ ] commandline options
- [ ] throttling (if it ever becomes fast enough)
- [ ] sound (if possible)

## Notes
Only hram is accessible by cpu during oam dma transfer & hram can't be the source of dma transfer  
- The source region of dma transfer cannot be written to during the transfer  
- Should be okay to get all source region at once, then write them to the destination region onde by one  

RLCA, RLA, RRCA and RRA are different from RLC, RL, RRC and RR
- RLCA, RLA, RRCA, and RRA: the z flag is always reset regardless of the computed value
- RLC, RL, RRC an RR: the z flag is assigned normally (set if the computed value is zero, reset otherwise)

Lower nibble of F register is always zero
- Make sure to mask with 0xf0 when putting a value into F

"add SP n" and "ldhl sp n"
- Uses the sum of SP and the SIGNED immediate value
- Carries are calculated using the UNSIGNED immediate value

halt bug
- Occurs on the halt instruction when ime=false and IE & IF != 0

Always do wrapping add when adding the scroll value
- e.g. `(ly + scy) &&& 0xff`
- Results of blargg's tests weren't showing up because ly + scy became greater than 0xff

## blargg tests
- [x] cpu_instrs

