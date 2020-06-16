---
title: "Linux Kernel Development"
date: 2020-06-16T16:10:46+05:30
draft: true
description: By Robert Love
---


# Notes

A process begins it life with fork

fork() [Create a copy of the current running process] -> exec() [Load a binary into memory] -> exit()
Metadata about each process is stored in a task struct. Info about all procs are maintained in a linkedlist called the tasklist.
thread_info struct is present at the bottom of the stack (for stacks that grow down)
fork is implemented through Copy-On-Write (COW) pages. Resources are duplicated only when they are modified. The gain comes through not duplicating the address space! 
Threads in linux are no different from processes. Each thread has it's own task_struct and is scheduled like any other task. Certain params in the task_struct have common values to indicate that resources are shared. This is different from Windows where threads are seen as lightweight processes, where the kernel has explicit support for dealing with threads.
Kernel threads are a special class of threads that run only in kernel space. Forked from kthreadd for performing special ops like flush, ksoftirqd.
