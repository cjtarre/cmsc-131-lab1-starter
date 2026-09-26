<!--no-pdf-->
# CMSC 131 Lab 1 Starter

Decode, encode, and checksum 20-byte IPv4 packet headers under a C driver.
The manual is the assignment. This file is the repository's own notes.

## Layout

```text
Makefile            platform preamble and build rules
driver.c            provided: argument parsing and file I/O
cdecl.h             provided: the calling-convention macros
decode.asm          yours
encode.asm          yours
checksum.asm        yours
run_tests.sh        provided: the correctness gate
contract_test.c     provided: the second pass, in C
contract_regs.asm   provided: register discipline checks for contract_test
tests/              provided: the header fixtures, their expected output,
                    and manifest.txt, the list both passes read
LICENSE             CC BY-NC-SA 4.0, inherited from the pcasm material
```

## What to Run

```bash
make
make check
```

`make` builds `renpkt` and `contract_test`. `make check` builds both, then
runs `./run_tests.sh`, which reports each test and exits nonzero when any
of them differ.

The gate has two passes. The first decodes every header listed in
`tests/manifest.txt` and compares the output with `tests/expected/`. The
second is `contract_test`. It decodes and re-encodes every header the
manifest marks valid. It checks a checksum vector that needs the carry
folded twice. It checks that all three routines keep `ebx`, `esi`, `edi`,
and `ebp`, and return with `esp` where the call left it. A program can pass
the first pass and fail the second. That failure is the usual encoder bug.

## Reading a First Run

The assembly files ship as stubs that assemble and link as-is, so the build
works before you write any code. Right now they do nothing useful, which
makes every check fail: `7 of 7 checks differ`. That red run is the correct
starting state for a starter. The badge stays red until you implement the
routines.

## Adding a Header

Put the header in `tests/NAME.bin`. Write the output `renpkt --decode`
must print for it in `tests/expected/NAME.out`. Then add one line to
`tests/manifest.txt`:

```text
NAME valid
```

Use `invalid` for a header with a wrong checksum. A valid header joins the
round trip in `contract_test` as well as the decode pass. The gate fails
and names the file when a `.bin` is not in the manifest, and when a listed
header has no expected file.

## The Driver's Argument Checks

`renpkt --encode` refuses a value its field cannot hold, and two values the
standard forbids. `--len` takes 20 through 65535, because the total length
counts the header. It defaults to 20. `--flags` takes 0 through 3, because
the top bit of the field is reserved and must be zero. `--df` sets 2 and
`--mf` sets 1. A refused option exits with status 2 and writes no file.

## Documentation

The three sections at the end of this file are yours. Complete Design Notes
and Subsystem Ownership before the Week 1 progress report. Complete Quirks
and Issues before the Week 3 progress report. Each section says what it
needs. Leave the rest of this file as it is.

## Fixtures

The provided files are fixtures. The grader compares your fork against the
starter. An edit to `driver.c`, `Makefile`, `run_tests.sh`,
`contract_test.c`, `contract_regs.asm`, or a provided `tests/` file appears
as a diff in the open. Your own headers and manifest lines are additions,
not edits.

---

## Design Notes

Complete this section before the Week 1 progress report. The syllabus asks
for problem analysis, a solution architecture, and an estimated timeline.
Keep each part short. Update it when the plan changes.

### Problem analysis

The tool works with the 20-byte base IPv4 header. The decode path reads the header in network byte order and extracts its 13 fields into the C structure, while the encode path builds the 20-byte header from the structure values.

The main challenges are handling multi-byte fields in big-endian order, extracting the Version and IHL fields that share the first byte, and separating the Flags and Fragment Offset fields that share bytes 6 and 7. The Internet checksum also requires processing the header as 16-bit big-endian words and folding carries before taking the one's complement.

### Header layout

The header is always exactly 20 bytes, with each byte (or part of a byte) holding a specific field. Byte 0 splits into Version (top 4 bits, always 4) and IHL (bottom 4 bits, always 5, meaning 20 bytes). Byte 1 splits into DSCP (top 6 bits) and ECN (bottom 2 bits). Bytes 2-3 hold Total Length as a 16-bit big-endian value. Bytes 4-5 hold Identification, also 16-bit big-endian. Bytes 6-7 hold Flags (top 3 bits of byte 6) and Fragment Offset (the remaining 13 bits, spilling across both bytes). Byte 8 is TTL, byte 9 is Protocol, bytes 10-11 hold the Header Checksum, bytes 12-15 hold the Source Address, and bytes 16-19 hold the Destination Address.

### Solution architecture

The project is divided into three assembly subsystems. `decode.asm` reads the 20-byte IPv4 header and stores its 13 fields in the `ipv4_fields` structure. `encode.asm` performs the reverse operation by reading the structure and constructing the 20-byte header in network byte order. `checksum.asm` computes the IPv4 one's complement checksum and is used by the decode and encode paths.

The routines follow the cdecl calling convention. For `decode_header`, the header pointer is at `[ebp+8]` and the output structure pointer is at `[ebp+12]`. For `encode_header`, the input structure pointer is at `[ebp+8]` and the header pointer is at `[ebp+12]`. For `ip_checksum`, the header pointer is at `[ebp+8]` and the length is at `[ebp+12]`.

The `ipv4_fields` structure stores its integer fields at offsets 0 through 40, the source address at offsets 44 through 47, and the destination address at offsets 48 through 51. The implementation must preserve `ebx`, `esi`, `edi`, and `ebp` according to the cdecl calling convention. Multi-byte IPv4 fields will be read and written byte-by-byte so that they remain in network byte order.


### Timeline

One line per week. Name the subsystem each week finishes and the member
who owns it.

| Week | Goal | Owner |
|---|---|---|
| 1 | Repository setup, complete design notes, assign subsystem ownership, and implement the Version/IHL prototype |  |
| 2 | Complete the decode path, checksum routine, and encoder; integrate the core features |  |
| 3 | Complete testing, resolve quirks and issues, and finalize the implementation |  |
| 4 | Defense | All Members |

## Subsystem Ownership

Complete this section before the Week 1 progress report. The manual lists
the three subsystems. Each member owns one. In a group of four, two members
share one. The commit history must agree with this table.

| Subsystem | Owner |
|---|---|
| Decode path (`decode.asm`) | Trisha Mae A. Hechenagocia |
| Encode path (`encode.asm`) | Aleighia Keith L. Reyes |
| Checksum and tests (`checksum.asm`, `tests/`) | Ma. Christie Jude L. Tarre |

## Quirks and Issues

Complete this section before the Week 3 progress report. The syllabus asks
for documentation of quirks and issues with the complete implementation.
One entry per item. State what happens, what causes it, and what the group
did about it.

### Known issues

- 

### Quirks

- 
