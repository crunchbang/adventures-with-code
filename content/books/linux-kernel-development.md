---
title: "Linux Kernel Development"
date: 2020-06-16T16:10:46+05:30
draft: false
---

This book had been on my TO-READ list for a long time. It came up again while I was perusing [Dan Luu's Programming book list](https://danluu.com/programming-books/). I've always wanted to look behind the curtains and see how the magic worked, so I finally bought it. 

I used [bootlin](https://elixir.bootlin.com/linux/v5.7.2/C/ident/task_struct) to read through Linux 5.7.2 source. They provide a really good search system and linked definitions. The book describes kernel version 2.6. You might want to keep this site open to see how things have changed since then.

# Notes

## Process & Threads
A process begins it life with `fork()`

`fork()` [Create a copy of the current running process] -> `exec()` [Load a binary into memory] -> `exit()`

Metadata about each process is stored in a `task_struct`. Info about all processes are maintained in a linked-list called the tasklist. They're often referred to as process descriptors.

`thread_info` struct is present at the bottom of the stack (for stacks that grow down). This allows for a lot of neat optimizations whereby the `thread_info` of the current process can be computed and found pretty quickly(review).

`fork()` is implemented through Copy-On-Write (COW) pages. Resources are duplicated only when they are modified. The gain comes through not duplicating the address space! 

Threads in linux are no different from processes. Each thread has it's own `task_struct` and is scheduled like any other task. Certain params in the `task_struct` have common values to indicate that resources are shared. This is different from Windows where threads are seen as lightweight processes, where the kernel has explicit support for dealing with threads.

Kernel threads are a special class of threads that run only in kernel space. Forked from `kthreadd` for performing special ops like flush, ksoftirqd.
