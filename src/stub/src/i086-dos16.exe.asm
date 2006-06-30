/*
;  l_exe.asm -- loader & decompressor for the dos/exe format
;
;  This file is part of the UPX executable compressor.
;
;  Copyright (C) 1996-2006 Markus Franz Xaver Johannes Oberhumer
;  Copyright (C) 1996-2006 Laszlo Molnar
;  All Rights Reserved.
;
;  UPX and the UCL library are free software; you can redistribute them
;  and/or modify them under the terms of the GNU General Public License as
;  published by the Free Software Foundation; either version 2 of
;  the License, or (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program; see the file COPYING.
;  If not, write to the Free Software Foundation, Inc.,
;  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
;
;  Markus F.X.J. Oberhumer              Laszlo Molnar
;  <mfx@users.sourceforge.net>          <ml1050@users.sourceforge.net>
;
*/

#define         EXE
#include        "arch/i086/macros.ash"

                CPU     8086

section         DEVICEENTRY

                .long   -1
                .short  attribute
                .short  strategy        /* .sys header */
                .short  interrupt       /* opendos wants this field untouched */
original_strategy:
                .short  orig_strategy
strategy:
                push    cs
                push    [cs:original_strategy]
                push    ax
                push    bx
                push    cx
                push    dx
                mov     ax, cs
                add     ax, offset exe_stack_ss
                mov     bx, offset exe_stack_sp
                mov     cx, ss
                mov     dx, sp
                mov     ss, ax          /* switch to stack EXE normally has */
                mov     sp, bx
                push    cx              /* save device stack on EXE stack */
                push    dx
                push    si
                push    di
                push    bp
                push    ds
                push    es
                .byte   0x72            /* "jc 0xf9" but flag C is 0 => nop */
exe_as_device_entry:
                stc                     /* flag C is 1 */
                pushf

/* ============= */

section         EXEENTRY
exe_entry:
                mov     cx, offset words_to_copy
                mov     si, offset copy_offset
                mov     di, si
                push    ds
                .byte   0xa9
do_copy:
                mov     ch, 0x80        /* 64 kbyte */
                mov     ax, cs
addaxds:
                add     ax, offset source_segment /* MSB is referenced by the "sub" below */
                mov     ds, ax
                add     ax, offset destination_segment
                mov     es, ax

                std
                rep
                movsw
                cld
section         DEVICESUB
                /* subb    [cs:si + addaxds + 4], 0x10 */
                .byte   0x2e, 0x80, 0x6c, addaxds + 4, 0x10
section         EXESUB
                subb    [cs:si + addaxds - exe_entry + 4], 0x10
section         JNCDOCOPY
                jncs    do_copy
                xchg    ax, dx
                scasw
                lodsw
section         EXERELPU
                push    cs
section         EXEMAIN4
                push    cs
                push    cs
                push    es
                pop     ds
                pop     es
                push    ss
                mov     bp, offset decompressor_entry
                mov     bx, offset bx_magic     /* 0x800F + 0x10*bp - 0x10 */
                push    bp
                lret

#include        "include/header2.ash"

section         EXECUTPO

#include        "arch/i086/nrv2b_d8.ash"
#include        "arch/i086/nrv2d_d8.ash"
#include        "arch/i086/nrv2e_d8.ash"

section         EXEMAIN5
                pop     bp

/* RELOCATION */

section         EXEADJUS
                mov     ax, es
                sub     ah, 0x6        /* MAXRELOCS >> 12 */
                mov     ds, ax
section         EXENOADJ
                push    es
                pop     ds
section         EXERELO1
                lea     si, [di + reloc_size]
                lodsw

                pop     bx

                xchg    ax, cx          /* number of 0x01 bytes (not exactly) */
                lodsw
                xchg    ax, dx          /* seg_hi */
reloc_0:
                lodsw
                xchg    ax, di
                lodsw
                add     bx, ax
                mov     es, bx
                xor     ax, ax
reloc_1:
                add     di, ax
                add     [es:di], bp
reloc_2:
                lodsb
                dec     ax
                jzs     reloc_5
                inc     ax
                jnz     reloc_1
section         EXEREL9A
                inc     di
reloc_4:
                inc     di
                cmpb    [es:di], 0x9a
                jne     reloc_4
                cmp     [es:di+3], dx
                ja      reloc_4
                mov     al, 3
                jmps    reloc_1
section         EXERELO2
reloc_5:
                add     di, 0xfe
section         EXEREBIG
                jcs     reloc_0
section         EXERELO3
                loop    reloc_2

/* POSTPROCESSING */

section         EXEMAIN8
                pop     es
                push    es
                pop     ds

section         DEVICEEND
                popf
                jc      loaded_as_exe
                pop     es
                pop     ds
                pop     bp
                pop     di
                pop     si
                pop     bx              /* get original device SS:SP */
                pop     ax
                mov     ss, ax          /* switch to device driver stack */
                mov     sp, bx
                pop     dx
                pop     cx
                pop     bx
                pop     ax
                lret                    /* return to original strategy */
loaded_as_exe:

section         EXESTACK
                lea     ax, [original_ss + bp]
                mov     ss, ax
section         EXESTASP
                mov     sp, offset original_sp

section         EXEJUMPF
                .byte   0xea            /* jmpf cs:ip */
                .word   original_ip, original_cs

section         EXERCSPO
                add     bp, offset original_cs
section         EXERETIP
                push    bp
                mov     ax, offset original_ip
                push    ax
                lret

/* vi:ts=8:et:nowrap */