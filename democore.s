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

	.text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Userland code. Entry point when invoked from the OS.
;
; 1. Invoke the actual demo code as a supervisor subroutine.
; 2. Exit back to the OS when the supervisor subroutine returns.
;;;;;;;;
user_main:
	; Invoke XBIOS(38) = Supexec
	pea	super_main	; address of subroutine
	move.w	#38,-(sp)	; 38 = Supexec
	trap	#14		; 14 = XBIOS
	addq.l	#6,sp		; pop parameters from the stack

	; Invoke GEMDOS(0) = Pterm0
	move.w	#0,-(sp)	; 0 = Pterm0
	trap	#1		; 1 = GEMDOS
	; Pterm0 returns to the calling process

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Start of supervisor code.
;
; 1. Check that we're in supervisor mode.
; 2. Check that we're on a color monitor.
; 3. Invoke real code if everything is fine.
;;;;;;;;
super_main:
	move.w	sr,d0
	btst.l	#13,d0		; bit #13 of SR is supervisor ($2000)
	beq.s	.exit		; bit not set = we're not in supervisor, exit
	btst.b	#1,$ffff8260.w	; bit #1 of $8260.w is monochrome mode ($02)
	bne.s	.exit		; bit set = we're in monochrome, exit
	bsr.s	super_main2	; invoke inner code.
.exit:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This is the actual start of the demo
;;;;;;;;
super_main2:

; Clear BSS
	lea.l	start_bss,a0
	lea.l	end_bss,a1
.clear_bss:
	clr.b	(a0)+
	cmp.l	a0,a1
	bne.s	.clear_bss

; Save status register, disable all interrupts
	move.w	sr,save_sr
	move.w	#$2700,sr
; Save stack
	move.l	sp,save_stack
	lea.l	main_thread_stack_top,sp

; Save MFP
; Save enable status
	move.b	$fffffa07.w,save_mfp_enable_a
	move.b	$fffffa09.w,save_mfp_enable_b
	move.b	$fffffa17.w,save_mfp_vector
; Save timer B
	move.b	$fffffa13.w,save_mfp_mask_a
	move.b	$fffffa1b.w,save_mfp_timer_b_control
	move.b	$fffffa21.w,save_mfp_timer_b_data	; ???

; Save interrupt vectors
	move.l	$70.w,save_vbl
	move.l	$120.w,save_hbl

; Disable all MFP interrupts, set auto-clear
	clr.b	$fffffa07.w
	clr.b	$fffffa09.w
	move.b	#$40,$fffffa17.w

; Set up MFP timer B
; Unmask timer b (this masks other unused ones as a side effect)
	move.b	#1,$fffffa13.w
; Set the timer b to count events, to fire on every event
	clr.b	$fffffa1b.w
	move.b	#1,$fffffa21.w

; Set our interrupt vectors
	move.l	#empty_interrupt,$70.w
	move.l	#empty_interrupt,$120.w

; Save palette
	lea.l	$ffff8240.w,a0
	lea.l	save_palette,a1
	moveq.l	#15,d0
.copy_palette:
	move.w	(a0)+,(a1)+
	dbra.w	d0,.copy_palette

; Save graphics state.
	move.b	$ffff8260.w,save_fb_res
	move.b	$ffff820a.w,save_fb_sync
	move.b	$ffff8201.w,save_fb_high_addr
	move.b	$ffff8203.w,save_fb_low_addr

; Clear palette
	lea.l	$ffff8240.w,a0
	moveq.l	#15,d0
.clear_palette:
	clr.w	(a0)+
	dbra.w	d0,.clear_palette

; Set graphics state It's a European demo, 50Hz FTW
	move.b	#0,$ffff8260.w
	move.b	#2,$ffff820a.w

; Set up our framebuffers
	move.l	#raw_buffer+255,d0
	clr.b	d0
	move.l	d0,back_buffer
	add.l	#32000,d0
	move.l	d0,front_buffer
	move.b	front_buffer+1,$ffff8201.w
	move.b	front_buffer+2,$ffff8203.w

; Set up threading system


	lea.l	update_thread_stack_top,a0
	move.l	#update_thread_entry,-(a0)	; PC
	move.w	#$2500,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,update_thread_current_stack

	lea.l	draw_thread_stack_top,a0
	move.l	#draw_thread_entry,-(a0)	; PC
	move.w	#$2500,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,draw_thread_current_stack

	move.l	#main_thread_current_stack,current_thread

; Sync interrupts
	stop	#$2300
	stop	#$2300
	move.l	#vbl_setup,$70.w
	stop	#$2300
	stop	#$2500
	stop	#$2500

	jsr	main_thread_entry

; Disable interrupts
	move.w	#$2700,sr
	clr.b	$fffffa07.w
	clr.b	$fffffa09.w
	move.l	#empty_interrupt,$70.w

; Clear palette
	lea.l	$ffff8240.w,a0
	moveq.l	#15,d0
.clear_palette2:
	clr.w	(a0)+
	dbra.w	d0,.clear_palette2

	stop	#$2300
	stop	#$2300
; Restore graphics status
	move.b	save_fb_sync,$ffff820a.w
	move.b	save_fb_res,$ffff8260.w
	move.b	save_fb_high_addr,$ffff8201.w
	move.b	save_fb_low_addr,$ffff8203.w
	stop	#$2300
	move.w	#$2700,sr
; Restore palette
	lea.l	$ffff8240.w,a0
	lea.l	save_palette,a1
	moveq.l	#15,d0
.restore_palette:
	move.w	(a1)+,(a0)+
	dbra.w	d0,.restore_palette




; Restore interrupt vectors
	move.l	save_vbl,$70.w
	move.l	save_hbl,$120.w

; Restore MFP status
	move.b	save_mfp_timer_b_control,$fffffa1b.w
	move.b	save_mfp_timer_b_data,$fffffa21.w
	move.b	save_mfp_mask_a,$fffffa13.w
	move.b	save_mfp_vector,$fffffa17.w
	move.b	save_mfp_enable_a,$fffffa07.w
	move.b	save_mfp_enable_b,$fffffa09.w

; Restore stack
	move.l	save_stack,sp
; Restore status register, exit
	move.w	save_sr,sr
	rts

empty_interrupt:
	rte

vbl_setup:
	move.b	#1,$fffffa07.w
	move.b	#8,$fffffa1b.w
	move.b	#1,$fffffa21.w
	move.l	#hbl_setup,$120.w
	move.l	#empty_interrupt,$70.w
	rte

hbl_setup:
	move.b	#198,$fffffa21.w
	move.l	#hbl_setup2,$120.w
	rte

hbl_setup2:
	move.b	#200,$fffffa21.w
	move.l	#hbl,$120.w
	rte

hbl:
	movem.l	d0-a6,-(sp)
	move.l	usp,a0
	move.l	a0,-(sp)
	move.b	#1,update_thread_ready
	bra.s	switch_and_return

switch_threads:
	move.w	#$2500,-(sp)
	movem.l	d0-a6,-(sp)
	move.l	usp,a0
	move.l	a0,-(sp)
switch_and_return:
	move.l	current_thread,a0
	move.l	sp,(a0)
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

update_thread_entry:
	.rept	1000
	move.w	#$070,$ffff8240.w
	clr.w	$ffff8240.w
	.endr
	move.w	#$2700,sr
	move.b	#1,draw_thread_ready
	clr.b	update_thread_ready
	jsr	switch_threads
	jmp	update_thread_entry

draw_thread_entry:
	.rept	1000
	move.w	#$700,$ffff8240.w
	clr.w	$ffff8240.w
	.endr
	move.w	#$2700,sr
	clr.b	draw_thread_ready
	jsr	switch_threads
	jmp	draw_thread_entry

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
start_bss:

save_stack:
	ds.l	1
save_hbl:
	ds.l	1
save_vbl:
	ds.l	1

save_sr:
	ds.w	1
save_palette:
	ds.w	16

save_mfp_enable_a:
	ds.b	1
save_mfp_enable_b:
	ds.b	1
save_mfp_mask_a:
	ds.b	1
save_mfp_vector:
	ds.b	1
save_mfp_timer_b_control:
	ds.b	1
save_mfp_timer_b_data:
	ds.b	1
save_fb_low_addr:
	ds.b	1
save_fb_high_addr:
	ds.b	1
save_fb_res:
	ds.b	1
save_fb_sync:
	ds.b	1

	.even
front_buffer:
	ds.l	1
back_buffer:
	ds.l	1

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

	.even
raw_buffer:
	ds.b	32000*2+254

end_bss: