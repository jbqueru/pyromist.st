;   Copyright 2020 Jean-Baptiste M. "JBQ" "Djaybee" Queru
;
;   Licensed under the Apache License, Version 2.0 (the "License");
;   you may not use this file except in compliance with the License.
;   You may obtain a copy of the License at
;
;       http://www.apache.org/licenses/LICENSE-2.0
;
;   Unless required by applicable law or agreed to in writing, software
;   distributed under the License is distributed on an "AS IS" BASIS,
;   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;   See the License for the specific language governing permissions and
;   limitations under the License.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                       ;;;
;;; This is the kernel of the demo                                        ;;;
;;; This includes:                                                        ;;;
;;;   * Machine setup                                                     ;;;
;;;   * Interrupts                                                        ;;;
;;;   * Threading                                                         ;;;
;;;   * Inputs                                                            ;;;
;;;   * Page flipping                                                     ;;;
;;;                                                                       ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.include "coregfx.s"
	.include "coreint.s"

	.text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Start of supervisor code.
;
; 1. Check that we're in supervisor mode.
; 2. Check that we're on a color monitor.
; 3. Invoke real code if everything is fine.
;
; This routine doesn't change any state. Therefore, if we trust everything
; to be set up correctly, it can be skipped in theory.
;
; TODO: investigate whether to check the MFP pin for monochrome monitor.
;;;;;;;;
core_main_super:
	; Check for supervisor mode
	move.w	sr,d0
	btst.l	#13,d0		; bit #13 of SR is supervisor ($2000)
	beq.s	.exit		; bit = 0 : we're not in supervisor, exit

	; Check for color monitor
	btst.b	#1,$ffff8260.w	; bit #1 of $8260.w is monochrome mode ($02)
	bne.s	.exit		; bit != 0 : we're in monochrome, exit

	bsr.s	core_main	; invoke inner code.
.exit:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; True entry point of the demo code.
; This is the first active code that is used in all environments.
;
; 1. Clear BSS.
; 2. Set up stack.
; 3. Invoke inner code.
; 4. Restore stack.
;
; The stack setup is difficult to separate in subroutines.
; Note: this routine assumes that there's already enough stack set up to
; invoke a subroutine.
;;;;;;;;
core_main:
	; This has to come first, before anything gets saved to BSS
	bsr.s	core_bss_clear

	; Save stack
	move.l	sp,save_stack

	; Set up our stack
	lea.l	main_thread_stack_top,sp

	; Invoke real code
	bsr.s	core_main_inner

	; Restore stack
	move.l	save_stack,sp

	; Exit
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This is the actual start of the demo.
;;;;;;;;
core_main_inner:
	bsr	core_int_save_setup
	bsr	core_gfx_save_setup
	bsr.s	core_thr_setup
	bsr	core_int_activate

	bsr	main_thread_entry

	bsr	core_int_deactivate
	bsr	core_gfx_restore
	bsr	core_int_restore
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Clear the BSS
;
; Caution: this makes assumptions about the way source files are organized,
;	all included source files must be between start_bss and end_bss
;;;;;;;;
core_bss_clear:
	lea.l	start_bss,a0
	lea.l	end_bss,a1
.clear_bss:
	clr.b	(a0)+
	cmp.l	a0,a1
	bne.s	.clear_bss
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Set up thread
;;;;;;;;
core_thr_setup:
; Set up threading system
	lea.l	music_thread_stack_top,a0
	move.l	#music_thread_entry,-(a0)	; PC
	move.w	#$2300,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,music_thread_current_stack

	lea.l	update_thread_stack_top,a0
	move.l	#update_thread_entry,-(a0)	; PC
	move.w	#$2300,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,update_thread_current_stack

	lea.l	draw_thread_stack_top,a0
	move.l	#draw_thread_entry,-(a0)	; PC
	move.w	#$2300,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,draw_thread_current_stack

	move.l	#main_thread_current_stack,current_thread

	rts

switch_from_int:
	movem.l	d0-a6,-(sp)
	move.l	usp,a0
	move.l	a0,-(sp)
	bra.s	switch_and_return

switch_threads:
	move.w	#$2300,-(sp)
	movem.l	d0-a6,-(sp)
	move.l	usp,a0
	move.l	a0,-(sp)

switch_and_return:
	move.l	current_thread,a0
	move.l	sp,(a0)
.try_music_thread:
	tst.b	music_thread_ready
	beq.s	.try_update_thread
	lea.l	music_thread_current_stack,a0
	bra.s	.thread_selected
.try_update_thread:
	tst.b	update_thread_ready
	beq.s	.try_draw_thread
	lea.l	update_thread_current_stack,a0
	bra.s	.thread_selected
.try_draw_thread:
	tst.b	draw_thread_ready
	beq.s	.use_main_thread
	lea.l	draw_thread_current_stack,a0
	bra.s	.thread_selected
.use_main_thread:
	lea.l	main_thread_current_stack,a0
.thread_selected:
	move.l	(a0),sp
	move.l	a0,current_thread
	move.l	(sp)+,a0
	move.l	a0,usp
	movem.l	(sp)+,d0-a6
	rte

music_thread_entry:
	.rept	1000
	move.w	#$770,$ffff8240.w
	clr.w	$ffff8240.w
	.endr
	move.w	#$2700,sr
	clr.b	music_thread_ready
	jsr	switch_threads
	bra	music_thread_entry

update_thread_entry:
	.rept	1000
	move.w	#$070,$ffff8240.w
	clr.w	$ffff8240.w
	.endr
	move.w	#$2700,sr
	move.b	#1,draw_thread_ready
	clr.b	update_thread_ready
	jsr	switch_threads
	bra	update_thread_entry

draw_thread_entry:
	.rept	1000
	move.w	#$700,$ffff8240.w
	clr.w	$ffff8240.w
	.endr
	move.w	#$2700,sr
	clr.b	draw_thread_ready
	jsr	switch_threads
	bra	draw_thread_entry

main_thread_entry:
main_loop:
	move.w	#$007,$ffff8240.w
	clr.w	$ffff8240.w

; Check for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
	cmp.b	#$39,$fffffc02.w
	bne.s	main_loop
	rts

; Uninitialized memory

	.bss
	.even
save_stack:
	ds.l	1
save_sr:
	ds.w	1

	.even
music_thread_current_stack:
	ds.l	1
music_thread_stack_bottom:
	ds.b	1024
music_thread_stack_top:
music_thread_ready:
	ds.b	1

	.even
update_thread_current_stack:
	ds.l	1
update_thread_stack_bottom:
	ds.b	1024
update_thread_stack_top:
update_thread_ready:
	ds.b	1

	.even
draw_thread_current_stack:
	ds.l	1
draw_thread_stack_bottom:
	ds.b	1024
draw_thread_stack_top:
draw_thread_ready:
	ds.b	1

	.even
main_thread_current_stack:
	ds.l	1
main_thread_stack_bottom:
	ds.b	1024
main_thread_stack_top:

	.even
current_thread:
	ds.l	1