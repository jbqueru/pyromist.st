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

compute_thread_entry:
;;; Start customized code
	; Init: run the waveform's precompute code
	move.l	#wave_compute,compute_routine
.compute_thread_loop:
	move.l	compute_routine,a0
	cmpa.l	#0,a0
	beq.s	.wait_for_draw_code
	jsr	(a0)
	bra.s	.done_compute
.wait_for_draw_code:
	move.b	draw_wait_phase,d0
	tst.b	d0
	beq.s	.done_compute
	cmp.b	draw_phase,d0
	bhi.s	.done_compute
	addq.b	#1,compute_phase
	move.l	compute_wait_routine,compute_routine
.done_compute:
	bra.s	.compute_thread_loop
;;; End customized code
	bra.s	compute_thread_entry

update_thread_entry:
;;; Start customized code
	move.l	update_routine,a0
	cmpa.l	#0,a0
	beq.s	.wait_for_compute_code
	jsr	(a0)
	bra.s	.done_update
.wait_for_compute_code:
	move.b	compute_wait_phase,d0
	tst.b	d0
	beq.s	.done_update
	cmp.b	compute_phase,d0
	bhi.s	.done_update
	addq.b	#1,draw_phase
	move.l	draw_wait_routine,draw_routine
	move.l	update_wait_routine,update_routine
.done_update:
;;; End customized code

	; Unblock draw thread, block this thread until it's ready again
	move.w	#$2700,sr
	move.l	next_to_update,most_recently_updated
	move.b	#1,draw_thread_ready
	clr.b	update_thread_ready
	jsr	switch_threads
; Check for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
	cmp.b	#$39,$fffffc02.w
	bne.s	update_thread_entry
	rts

draw_thread_entry:
;;; Start customized code
	move.l	draw_routine,a0
	cmpa.l	#0,a0
	beq.s	.done_draw
	jsr	(a0)
.done_draw:
;;; End customized code

	; Block this thread until it's ready again
	move.w	#$2700,sr
	move.l	back_drawn_data,-(sp)
	move.l	back_to_draw_data,back_drawn_data
	move.l	(sp)+,back_to_draw_data
	move.l	back_to_draw_data,next_to_update
	clr.b	draw_thread_ready
	jsr	switch_threads
	bra.s	draw_thread_entry

;;; Start customized code
	.bss
	.even
update_routine:
	ds.l	1
update_wait_routine:
	ds.l	1
draw_routine:
	ds.l	1
draw_wait_routine:
	ds.l	1
compute_routine:
	ds.l	1
compute_wait_routine:
	ds.l	1
draw_phase:
	ds.b	1
compute_phase:
	ds.b	1
draw_wait_phase:
	ds.b	1
compute_wait_phase:
	ds.b	1

	.even
heap:
	ds.b	600000

; Heap layout:
; Waveform: spheres 18432 bytes at offset 0 (256 items @ 72 bytes)
; Wavefore: bitmaps 16384 bytes at offset 18432 (512 items @ 32 bytes)

;	.include "twistscr.s"
	.include "waveform.s"
;;; End customized code
