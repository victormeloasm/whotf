# whotf

**A Ridiculously Tiny Assembly Alternative for Those Who Hate Rust.**

`whotf` is a 297-byte `whoami` alternative for Linux x86-64, written in **x86-64 Assembly using FASM**. It uses direct Linux syscalls, a handcrafted ELF header, and no libc.

## Size comparison

| Implementation | Binary size |
| --- | ---: |
| Rust Coreutils (shared multicall executable) | 11,807,104 bytes |
| GNU `whoami` | 35,424 bytes |
| **whotf (FASM)** | **297 bytes** |

`whotf` is approximately **119 times smaller** than GNU `whoami` (99.16% smaller). The Rust Coreutils figure refers to a shared executable, not standalone `whoami` code.

## Install

```bash
git clone https://github.com/victormeloasm/whotf.git
cd whotf
sudo install -m 755 whotf /usr/local/bin/whotf
whotf
```

### Build from source (optional)

```bash
sudo apt install fasm
fasm whotf.asm whotf
sudo install -m 755 whotf /usr/local/bin/whotf
```

**Note:** `whotf` looks up the effective UID in `/etc/passwd`; unlike GNU `whoami`, it does not support NSS/LDAP. Its size-optimized ELF header is intentionally nonstandard.

## License

MIT
