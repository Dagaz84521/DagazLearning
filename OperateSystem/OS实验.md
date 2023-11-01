# OS实验

## Project 1

### 一、修改timer_sleep

#### 1.要求：

修改timer.c下的函数timer_sleep，使其不再忙等。

#### 2.实验思路：

##### 	①为什么会发生忙等？

```c
/*in timer.c*/ 
/* Sleeps for approximately TICKS timer ticks.  Interrupts must be turned on. */
 void
 timer_sleep (int64_t ticks)
{
	int64_t start = timer_ticks ();
	ASSERT (intr_get_level () == INTR_ON);
	while (timer_elapsed (start) < ticks)
	thread_yield();
}
```

这里的while循环，判断当前时间和开始时间start的差值（由timer_elapsed函数实现）是否小于休眠时间ticks，如果小于，就将该线程重新添加到就绪队列（thread_yield函数实现），这就导致这个线程不断地进入就绪队列，这就是忙等待。所以这里不能让这个线程进入就绪队列。通过助教给的提示，**需要调用thread_block这个函数，来将线程阻塞住**。在休眠时间过去后，再调用thread_unblock这个函数将线程恢复。

##### 	②如何确定某一blocked线程block了多久？

就需要知道这个线程blocked了多久，如果blocked时间等于ticks，那么就调用unblock，否则就继续等。每个线程需要休眠的时间不一定相同，而且开始休眠的时间也不一定相同，所以对于线程来说，这是一个专属的变量，所以需要在thread结构体中加一个休眠了多久的成员变量。采用从ticks递减到0的方法，既可以起到了记录block了多久的作用，又可以起到记录需要block多久的作用。所以需要在thread结构体中加入一个ticks_blocked成员变量。

```c
/*in thread.h*/
/*in struct thread*/
    int64_t ticks_blocked;              /* Remain sleep ticks*/
```

##### 	③如何判断一个blocked线程是否需要恢复？

由于我设置了一个ticks_blocked成员变量，当这个变量为0的时候，说明休眠结束，恢复该线程。否则就将ticks_blocked递减。

```c
/*in thread.h*/
void checkInvoke(struct thread *t, void* aux UNUSED);
```

##### 	④如何维护tick_blocked?

现在的思路是tick_blocked会随着内核的时间一起变动，也就是timer.h中的全局静态变量ticks变动而变动。纵观整个timer.c文件里，只有一个函数timer_interrupt会将ticks进行递增操作。所以到这里的时候，对所有线程进行检查，对所有在block中的线程，调用checkInvoke。

```c
static void
timer_interrupt (struct intr_frame *args UNUSED)
{
  ticks++;
  thread_tick ();
}
```

#### 3.实验过程:

##### ①初次尝试

上面的大体思路已经差不多了。接下来就是实现了。

首先，先对thread结构体进行修改:

```c
struct thread
  {
    /* Owned by thread.c. */
    tid_t tid;                          /* Thread identifier. */
    enum thread_status status;          /* Thread state. */
    char name[16];                      /* Name (for debugging purposes). */
    uint8_t *stack;                     /* Saved stack pointer. */
    int priority;                       /* Priority. */
    struct list_elem allelem;           /* List element for all threads list. */
    /* Shared between thread.c and synch.c. */
    struct list_elem elem;              /* List element. */
    int64_t ticks_blocked;              /* Remain sleep ticks*/
#ifdef USERPROG
    /* Owned by userprog/process.c. */
    uint32_t *pagedir;                  /* Page directory. */
#endif

    /* Owned by thread.c. */
    unsigned magic;                     /* Detects stack overflow. */
  };
```

就只是加了一个int64_t类型（因为那个全局静态变量ticks就是这个类型的）的ticks_blocked成员变量。

然后我们要取消在timer_sleep中的while-thread_yield循环，改成thread_block，将线程阻塞。

```c
void
timer_sleep (int64_t ticks) //根据就近原则，这个是局部变量ticks，表达的意思是休眠时间长度，而非前面全局静态变量ticks
{
  int64_t start = timer_ticks ();

  ASSERT (intr_get_level () == INTR_ON);
  // while (timer_elapsed (start) < ticks) 
  //   thread_yield ();
  //阻塞线程
  thread_block();
  //将当前线程的剩余等待时间改成ticks
  thread_current()->ticks_blocked = ticks;
}
```

这个函数修改完了，我们需要一个判断函数，使他ticks_blocked能够递减，同时还能在ticks_blocked==0的时候，调用thread_unblock来解出阻塞。

```c
void checkInvoke(struct thread *t, void* aux UNUSED){
  if(t->status == THREAD_BLOCKED && t->ticks_blocked > 0)
    t->ticks_blocked--;
  if(t->ticks_blocked == 0)
    thread_unblock(t);
}
```

当这个线程的状态是THREAD_BLOCKED的时候而且还有剩余时间的时候，剩余时间减少。如果剩余时间为零，说明休眠结束，调用thread_unblock解除休眠。

这些都完成了，就需要在timer_interrupt函数中对整个thread list进行遍历。刚开始的想法是使用thread.c中的全局静态变量all_list来遍历的，但在timer.c这个文件里使用all_list，VScode告诉我dentifier "all_list" is undefined。看了一下前面的include

```c
/*in timer.h*/
#include "devices/timer.h"
#include <debug.h>
#include <inttypes.h>
#include <round.h>
#include <stdio.h>
#include "devices/pit.h"
#include "threads/interrupt.h"
#include "threads/synch.h"
#include "threads/thread.h"
```

是因为include thread.c吗？

这个时候感谢同组的王力同学指出thread.h这个头文件里面有一个函数tread_foreach()就是一个能够对所有线程进行同一操作的函数。

```c
/* Performs some operation on thread t, given auxiliary data AUX. */
typedef void thread_action_func (struct thread *t, void *aux);
void thread_foreach (thread_action_func *, void *);
```

这样便可以对timer_interrupt进行修改了：

```c
static void
timer_interrupt (struct intr_frame *args UNUSED)
{
  ticks++;
  thread_tick ();
  thread_foreach(checkInvoke,NULL);
}
```

这样几个重要的函数都在逻辑上实现了需要的功能。在thread这个文件夹下启动terminal输入如下指令，开始测试：

```
make clean
make
cd build
pintos -- run alarm-multiple
```

这个时候，如果不出意外的话，应该是要出意外了。

![image-20231030223418539](图片/image-20231030223418539.png)

直接就没办法跑起来。那没办法了，试着用下GDB吧。

##### ②GDB调试

但我发现这个和之前用的GDB不大一样，之前计算机系统使用GDB的时候一般直接对单个可执行文件就可以了，但这次pintos好像有点不一样。在查阅PKU的PintosBook的Debugging相关章节之后，我大概会了一些。主要使用如下命令：

```
pintos --gdb -- run alarm-multiple 
```

这一步先启动pintos，让terminal和QEMU处于这样的状态,此时操作系统暂停

![image-20231031091631057](图片/image-20231031091631057.png)

然后再在另一个terminal中,输入以下指令

```
pintos-gdb
```

![image-20231031091814701](图片/image-20231031091814701.png)

然后再使用**debugpintos**的指令,开始连接GDB和之前开启的pintos.

##### ③灵光一现

在我正准备进行GDB调试的时候，我注意了一下pintos的输出：

![image-202310302234185391](图片/image-202310302234185391.png)

在thread_unblock()这个函数中assertion判断当前线程状态是否为阻塞状态失败了。扒了一下该函数的代码

```c
void
thread_unblock (struct thread *t) 
{
  enum intr_level old_level;

  ASSERT (is_thread (t));

  old_level = intr_disable ();
  ASSERT (t->status == THREAD_BLOCKED);
  list_push_back (&ready_list, &t->elem);
  t->status = THREAD_READY;
  intr_set_level (old_level);
}
```

ASSERT这个指令的作用是判断内容是否为true，非true则返回报错信息，也就是这一句输出了上面的图片的内容。那就说明在调用unblock的时候出问题了。那么什么时候调用了这个函数呢？在我的checkInvoke这个判断函数里，所以我立马翻出了这个函数的代码，看看是否存在问题。

```c
void checkInvoke(struct thread *t, void* aux UNUSED){
  if(t->status == THREAD_BLOCKED && t->ticks_blocked > 0)
    t->ticks_blocked--;
  if(t->ticks_blocked == 0)
    thread_unblock(t);
}
```

检查后，好像也没什么问题。进入这个函数，如果状态是阻塞的而且剩余阻塞时间大于0，那么说明需要继续阻塞（t->ticks_blocked--;）这个判断完后，判断如果剩余阻塞时间为0，那么就接触阻塞。乍一眼看上去逻辑上没问题。但我意识到这个里面存在一个很严重的问题：第二个if语句应该是被第一个if语句包含的，现在变成两个独立的if语句后，如果一个非blocked的线程执行checkInvoke，就会执行thread_unblock。这下就明白为什么在thread_unblock中ASSERT那句指令就会报错了。所以要么在第二个if语句增加状态判断：

```c
void checkInvoke(struct thread *t, void* aux UNUSED){
  if(t->status == THREAD_BLOCKED && t->ticks_blocked > 0)
    t->ticks_blocked--;
  if(t->status == THREAD_BLOCKED && t->ticks_blocked == 0)
    thread_unblock(t);
}
```

或者简单点：

```c
void checkInvoke(struct thread *t, void* aux UNUSED){
  if(t->status == THREAD_BLOCKED && t->ticks_blocked > 0){
    t->ticks_blocked--;
  	if(t->ticks_blocked == 0)
    	thread_unblock(t);
  }  
}
```

然后看一下结果：

![image-20231031172802932](图片/image-20231031172802932.png)

##### ④渐入佳境

呃，好像还是差不多。但出问题的地方变了，而且我可以确定之前那个地方有问题，所以前面的修改确实解决了一个问题。还是看报错的那一句，在thread_block函数中intr_get_level() == INTR_OFF失败。这就说明在thread_block之前，需要使intr_get_level()==INTR_OFF.

那么就得要知道Intr_get_level这个函数是什么作用，要怎么让其返回值INTR_OFF。

在interrupt.c文件中，可以找到这个函数的定义：

```c
/* Returns the current interrupt status. */
enum intr_level
intr_get_level (void) 
{
  uint32_t flags;

  /* Push the flags register on the processor stack, then pop the
     value off the stack into `flags'.  See [IA32-v2b] "PUSHF"
     and "POP" and [IA32-v3a] 5.8.1 "Masking Maskable Hardware
     Interrupts". */
  asm volatile ("pushfl; popl %0" : "=g" (flags));

  return flags & FLAG_IF ? INTR_ON : INTR_OFF;
}
```

说实话，没看懂。但上面的注释告诉我，这个函数返回了一个当前interrupt状态。所以说，在进入thread_block之前，需要将interrupt status改成INTR_OFF。再看了看interrupt.c这个文件，有一对互逆操作intr_disable和intr_enable做到了将interrupt status改成off和on。那么只需要在进入之前，调用一下intr_disable应该就行了。

```c
void
timer_sleep (int64_t ticks) 
{
   if(ticks <= 0)
     return;
   ASSERT (intr_get_level () == INTR_ON);
  // while (timer_elapsed (start) < ticks) 
  //   thread_yield ();
  intr_disable ();
  thread_current()->ticks_blocked = ticks;
  thread_block();
 }
```

![image-20231031181759175](图片/image-20231031181759175.png)

又在timer_sleep里ASSERT报错了，这里就很清楚了，因为我写的timer_sleep只有一个地方有ASSERT，我只将interrupt status改成INTR_OFF，并没有恢复。所以下一次再访问timer_sleep后，还是在INTR_OFF，所以会报错。秉持着遇到问题就解决提出问题的人，我们只需要把那一句，ASSERT (intr_get_level () == INTR_ON);直接删掉不久好了吗？

![image-20231031183059601](图片/image-20231031183059601.png)

你别说，你还真别说还真可以。XD

不耍宝了，为了其他功能的正常进行，我们还是要把interrupt status进行复原。用intr_enable();就行了。最终的timer_sleep如下：

```c
/* Sleeps for approximately TICKS timer ticks.  Interrupts must
   be turned on. */
void
timer_sleep (int64_t ticks) 
{
   if(ticks <= 0)
     return;

  ASSERT (intr_get_level () == INTR_ON);
  // while (timer_elapsed (start) < ticks) 
  //   thread_yield ();
  intr_disable ();
  thread_current()->ticks_blocked = ticks;
  thread_block();
  intr_enable();
}
```

最后终于可以实现运作了。

#### 4.实验结果：

##### ①代码：

###### thread结构体

```c
struct thread
  {
    /* Owned by thread.c. */
    tid_t tid;                          /* Thread identifier. */
    enum thread_status status;          /* Thread state. */
    char name[16];                      /* Name (for debugging purposes). */
    uint8_t *stack;                     /* Saved stack pointer. */
    int priority;                       /* Priority. */
    struct list_elem allelem;           /* List element for all threads list. */
    /* Shared between thread.c and synch.c. */
    struct list_elem elem;              /* List element. */
    int64_t ticks_blocked;              /* Remain sleep ticks*/
#ifdef USERPROG
    /* Owned by userprog/process.c. */
    uint32_t *pagedir;                  /* Page directory. */
#endif

    /* Owned by thread.c. */
    unsigned magic;                     /* Detects stack overflow. */
  };
```

###### timer_sleep

```c
/* Sleeps for approximately TICKS timer ticks.  Interrupts must
   be turned on. */
void
timer_sleep (int64_t ticks) 
{
   if(ticks <= 0)
     return;

  ASSERT (intr_get_level () == INTR_ON);
  // while (timer_elapsed (start) < ticks) 
  //   thread_yield ();
  intr_disable ();
  thread_current()->ticks_blocked = ticks;
  thread_block();
  intr_enable();
}
```

###### timer_interrupt

```c
static void
timer_interrupt (struct intr_frame *args UNUSED)
{
  ticks++;
  thread_tick ();
  thread_foreach(checkInvoke,NULL);
}
```

###### checkInvoke

```
void checkInvoke(struct thread *t, void* aux UNUSED){
  if(t->status == THREAD_BLOCKED && t->ticks_blocked > 0){
    t->ticks_blocked--;
  	if(t->ticks_blocked == 0)
    	thread_unblock(t);
  }  
}
```

##### ②实验结果：

![image-20231031183953614](图片/image-20231031183953614.png)

可以看到，实验要求的结果应该是对于相同的product的组，其线程号应该是递增的。我做出来的结果确实也符合这一结果。

##### ③小结和反思：

1. 首先是最关键的问题，这个实验自己写的成分有多少。说实话，一开始没什么思路，什么时候有思路的呢？看着老师发群里的PPT后面几页，看完豁然开朗，直接就有动力开写了。所以说思路确实不完全是我自己想的，但内部的代码实现，都是我自己一步一步试过来的。
2. 关于Block_list实现的可能性，有，而且很大，但不好实现，因为需要改的东西有点多，至少需要多改两个函数thread_block(需要把线程从ready_list中删掉，并把线程加入到block_list)和thread_unblock(需要把线程从block_list中删去，加入到ready_block里)，别的应该和对all_list进行操作没有区别。通过维护一个block_list，并不是一定是效率的提升，我觉得这个里面还是有trade-off的，因为需要不断地对两个链表进行增加和删减的操作，但可以少判断一些不在block的线程。
3. 关于那个timer_sleep中interrupt status改变，我是通过程序的报错来发现的。但是，现在我有一个新的解释，因为我发现这个进入前intr_disable，退出后intr_enable，很像防止临界区冲突的一个解决方案。我要将这个线程block，此时就不应该发生中断。等我将这个线程block完成后，释放了这个锁，就可以发生中断。