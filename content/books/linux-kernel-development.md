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

## Scheduling

O(1) scheduler, followed by the Completely Fair Scheduler

Sticking to conventional ideas of an absolute time slice ensures constant switching rate but variable fairness and can lead to a slew of problems. CFS does away with this by ditching timeslices and allocating a portion of the processor to each process. This results in variable switching rate but constant fairness.

CFS works by assuming that there is an ideal processor that is capable of multitasking. If we have n processes, each would run in parallel, consuming 1/n of the processor. Reality deviates from this ideal dream in the fact that perfect multitasking is not possible, and that there is an overhead involved in switching processes. Nevertheless, CFS is designed with the idea of giving a portion of the processor to each running process. This portion assigned is a function of the total number of processes waiting to be run. Nice values are used here to weight the processor portion that each process receives - a lower niceness value would result in a relatively higher portion of the processor. Thus when we take an infinitely small time window, each process would've been scheduled for a time slice proportional to their processor portion.

This infinitely small window is usually approximated to a duration called `targeted latency`. Smaller value results in higher interactivity since it approximates the ideal case, but it results in lower throughput because of switching overhead. `targeted latency` is floored at a value called `minimum granularity` by the kernel.

All the scheduling info is carried in `sched_entity` which is embedded in each `task_struct`.

The most interesting thing here is the `vruntime`, the virtual run time, which is what the scheduler uses to pick the next process. There is a concept of physical time and virtual time. Physical run time is the actual time that the process ran and virtual run time is normalized physical time computed using the number of runnable processes and the niceness value of the process. Approximately, it is computed as `physcial_time * (NICE_0_LOAD / proc_load)` where `NICE_0_LOAD` represents the weight of a process who's niceness value is 0 and `proc_load` represents the weight of the process calculated using its niceness value. Thus for processes with lower niceness value (higher priority), the virtual time would be less than physical time and vice versa. Thus they'd get a bigger portion of the processor in turn. This [SO](https://stackoverflow.com/questions/19181834/what-is-the-concept-of-vruntime-in-cfs/19193619) answer goes into some more depth.

CFS maintains runnable procs in a red-black tree where the key is the `vruntime`. It continuously picks and schedules the process with the lowest `vruntime`. It does a neat optimization where it caches the left-most node during insertion / deletion of each new node.

When a task goes to sleep, it marks itself as sleeping, puts itself on a wait Q, removes itself from the red-black tree of runnables and calls `schedule()` to select the new process to execute. To wake up the task, it is marked as runnable, removed from the wait Q, and put back in the runnable tree.

## System Calls

System calls provide an interface between the applications in user space and the kernel. They provide a mechanism through which applications can safely interact with the underlying hardware, create new processes, communicate with each other, as well as the capability to request other operating system resources. Provide mechanism, not policy. The kernel system calls provide a specific fn. The manner in which it is used does not matter to the kernel.

User space applications cannot directly invoke a kernel function. The whole communications happens through register values and interrupts. Each syscall has a particular value associated with it. This value is loaded into the `eax` register and then an interrupt is invoked `int 0x80` which invokes the interrupt handler which hands over control to the kernel, which then executes the appropriate system call on behalf of the user space application.

Most of the system calls are defined with the funky `SYSCALL_DEFINE` macro. This [answer](https://www.quora.com/Linux-Kernel/Linux-Kernel-What-does-asmlinkage-mean-in-the-definition-of-system-calls) explains the curious `asmlinkage` that gets prefixed to these functions. Syscall `bar` is referred to as `syscall_bar` within the kernel.

## Kernel Data Structures

The ubiquitous linked list implementation is a circular doubly linked list... with some quirks. Unlike usual linked lists, the data is not embedded within the linked list struct but rather the linked list struct `struct list_head` is embedded within the data struct. The kernel uses some C macro magic with `container_of` to get a pointer to the embedding struct from the `list_head` pointer. This [post](https://radek.io/2012/11/10/magical-container_of-macro/) demystifies the magic behind the macro.

In addition the kernel code also contains implementations for a queue (with the usual ops) and a map. The map is implemented as a balanced binary search tree with a rather confusing name - idr. It provides mapping between UIDs to pointers. 

## Interrupts & Interrupt Handlers
Interrupts generated by H/W are handled by specific Interrupt Handlers or Interrupt Service Routines (ISR). Generally the ISR for a device is part of the device driver code in the kernel. ISR in the kernel are nothing but C functions that run in the interrupt context (atomic context). The work associated with handling an interrupt is divided into two parts - 
1. Acknowledging the H/W and performing operations that will enable the H/W will proceed further (stuff like copying all the received packets from a NIC's buffer) - This is handled by the 'Top Half'.
2. Further work on the data associated with the kernel, which is not critical and can be performed at a future point in time - This is handled by the 'Bottom Half'.

An interrupt handler is registerd for an IRQ line using `request_irq()` which takes in information about the IRQ number, handler fn, flags pertaining to the nature of the interrupt and handler, and some extra stuff. The registration happens when the driver is loaded. Similary, when the driver is unloaded the handler needs to be freed using `free_irq()`.

Interrupt handlers in linux need to be reentrant i.e the handler will not be invoked concurrently. When an interrupt is being service, the interrupt line is disabled (masked) which prevents further interrupts from coming on that line. Thus it is guaranteed that the ISR won't be invoked in parallel. 

Interrupt lines may be shared among multiple handlers. For a line to be shared, each handler on that line must be registered as a shared handler. The handler returns a value denoting whether the interrupt was handled or not. When an interrupt is received on a shared line, the kernel invokes each of the handlers one by one. It uses the return value to ascertain whether the interrupt was handled.

Interrupt handlers run in the interrupt context. Since it is not backed by a process, ISR are not allowed to sleep (who will wake it up and how?), which restricts the activities that can be done from ISR. Earlier ISR was forced to use the stack of the process it interrupted. Now, there is an interrupt stack associated with the kernel which is of size equivalent to one page which the ISR can use. 
