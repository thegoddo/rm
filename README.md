# rm
let's implement rm in pure assembly

# compile with nasm
```bash
nasm -f elf64 main.asm -o main
```

- o: output flag

# link with gcc(gnu c compiler)

*We are linking libc library strcmp*
```bash
gcc -no-pi -nostartfiles main.o -o main
```
- `no-pie`: Don't change the architecture
- `nostartfiles`: don't create start flag, gcc automatically create one, and we want our start file
