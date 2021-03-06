;   Copyright 2021 Jean-Baptiste M. "JBQ" "Djaybee" Queru
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

; ***********************************************************************
; ***********************************************************************
; ***                                                                 ***
; ***                SPHERE + MINI-CUBE WAVEFORM SCREEN               ***
; *** SPLIT CUBE IN 144 SMALLER CUBES, WITH A ROTATING SPHERE IN EACH ***
; ***                                                                 ***
; ***********************************************************************
; ***********************************************************************


; The screen starts with one face fo the cube visible, as a square 120*120
; The square splits into a 12*12 grid of 10*10 squares
; The individual squares drift to be aligned on 16 pixels

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Format of precomputed graphics for the waveform spheres
;
; heap offset 0
; 256 bitmaps, 16*12 pixels, 3 bitplanes.
; total 18432 bytes
;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Format of precomputed graphics for the surrounding cubes
;
; heap offset 18432
; 512 bitmaps, 16*16 pixels, 1 bitplane
; total 16384 bytes
;;;;;;;;




	.text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Setup
;;;;;;;;
wave_compute:
; Wait until precompute reaches phase 1 to draw wave
	move.b	#1,compute_wait_phase
; Set the draw routines to use once precompute is done
	move.l	#wave_update,update_wait_routine
	move.l	#wave_draw,draw_wait_routine

; Set the data to match the various screen draw states
	move.l	#wave_f1,front_drawn_data
	move.l	#wave_f2,front_to_draw_data
	move.l	#wave_f3,back_drawn_data
	move.l	#wave_f4,back_to_draw_data
	move.l	back_to_draw_data,most_recently_updated
	move.l	back_to_draw_data,next_to_update

; Start the pre-animation
	move.l	#wave_intro_update,update_routine
	move.l	#wave_intro_draw,draw_routine

	bra	wave_compute_core


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Draw intro animation
;;;;;;;;
wave_intro_update:
;;; Frame counter, as basic as it gets.
	move.l	most_recently_updated,a5
	move.l	next_to_update,a6
	move.w	2(a5),d0
	addq.w	#1,d0
	move.w	d0,2(a6)
; Stop after 350 frames. Animation is technically 336 frames long.
	cmp.w	#350,d0
	ble.s	.continue
	clr.l	update_routine
.continue:
	rts

wave_intro_draw:
	move.l	back_to_draw_data,a6
	move.l	back_drawn_data,a5

; Draw the square frame if it hasn't been drawn yet
	tst.w	2(a5)
	bne.s	.done_square

	move.l	back_buffer,a0
	adda.w	#6454,a0	; 40*160+48+6
	lea.l	19040(a0),a1	; 119*160
	move.w	#$0fff,d0
	move.w	d0,(a0)
	addq.l	#8,a0
	move.w	d0,(a1)
	addq.l	#8,a1
	moveq.l	#5,d7
	moveq.l	#$ffffffff,d0
.draw_square_horiz:
	move.w	d0,(a0)
	addq.l	#8,a0
	move.w	d0,(a1)
	addq.l	#8,a1
	dbra.w	d7,.draw_square_horiz
	move.w	#$fff0,d0
	move.w	d0,(a0)
	move.w	d0,(a1)
	lea.l	104(a0),a0
	lea.l	56(a0),a1
	move.w	#$0800,d0
	moveq.l	#$0010,d1
	move.w	#117,d7
.draw_square_vert:
	move.w	d0,(a0)
	adda.w	#160,a0
	move.w	d1,(a1)
	adda.w	#160,a1
	dbra.w	d7,.draw_square_vert

.done_square:

;;; Draw horizontal lines slicing through the square
	move.w	2(a5),d0
	move.w	2(a6),d1

	add.w	d0,d0
	add.w	d0,d0
	add.w	d1,d1
	add.w	d1,d1

	cmp.w	#40,d0
	bpl.s	.b1
	move.w	#40,d0
.b1:
	cmp.w	#158,d0
	bmi.s	.b2
	move.w	#158,d0
.b2:
	cmp.w	#40,d1
	bpl.s	.a1
	move.w	#40,d1
.a1:
	cmp.w	#158,d1
	bmi.s	.a2
	move.w	#158,d1
.a2:

	move.w	d0,d2
	addq.w	#1,d2

	move.l	back_buffer,a0
	mulu.w	#160,d2
	lea.l	6(a0,d2.w),a0

	sub.w	d0,d1
	bra.s	.draw_split_vert2
.draw_split_vert1:
	move.w	#$0806,48(a0)
	move.w	#$0180,56(a0)
	move.w	#$6018,64(a0)
	move.w	#$0601,72(a0)
	move.w	#$8060,80(a0)
	move.w	#$1806,88(a0)
	move.w	#$0180,96(a0)
	move.w	#$6010,104(a0)
	adda.w	#160,a0
.draw_split_vert2:
	dbra.w	d1,.draw_split_vert1


;;; Draw vertical lines slicing through the square
	move.w	2(a5),d0
	sub.w	#12,d0
	move.w	2(a6),d1
	sub.w	#12,d1

	add.w	d0,d0
	add.w	d0,d0
	add.w	d1,d1
	add.w	d1,d1

	cmp.w	#100,d0
	bpl.s	.d1
	move.w	#100,d0
.d1:
	cmp.w	#218,d0
	bmi.s	.d2
	move.w	#218,d0
.d2:
	cmp.w	#100,d1
	bpl.s	.c1
	move.w	#100,d1
.c1:
	cmp.w	#218,d1
	bmi.s	.c2
	move.w	#218,d1
.c2:

	cmp.w	d0,d1
	beq	.done_horiz_split

	addq.w	#1,d0

	move.w	d0,d2
	andi.w	#$01f0,d2
	lsr.w	#1,d2
	move.w	#$ffff,d4
	andi.w	#$000f,d0
	lsr.w	d0,d4

	move.w	d1,d3
	andi.w	#$01f0,d3
	lsr.w	#1,d3
	move.w	#$8000,d5
	andi.w	#$000f,d1
	lsr.w	d1,d5
	subq.w	#1,d5
	not.w	d5

	move.l	back_buffer,a0
	lea.l	6(a0,d2.w),a0

	cmp.w	d2,d3
	bne.s	.two_blocks
	and.w	d5,d4
	or.w	d4,7840(a0)
	or.w	d4,8000(a0)
	or.w	d4,9440(a0)
	or.w	d4,9600(a0)
	or.w	d4,11040(a0)
	or.w	d4,11200(a0)
	or.w	d4,12640(a0)
	or.w	d4,12800(a0)
	or.w	d4,14240(a0)
	or.w	d4,14400(a0)
	or.w	d4,15840(a0)
	or.w	d4,16000(a0)
	or.w	d4,17440(a0)
	or.w	d4,17600(a0)
	or.w	d4,19040(a0)
	or.w	d4,19200(a0)
	or.w	d4,20640(a0)
	or.w	d4,20800(a0)
	or.w	d4,22240(a0)
	or.w	d4,22400(a0)
	or.w	d4,23840(a0)
	or.w	d4,24000(a0)

	bra	.done_horiz_split

.two_blocks:
	or.w	d4,7840(a0)
	or.w	d5,7848(a0)
	or.w	d4,8000(a0)
	or.w	d5,8008(a0)
	or.w	d4,9440(a0)
	or.w	d5,9448(a0)
	or.w	d4,9600(a0)
	or.w	d5,9608(a0)
	or.w	d4,11040(a0)
	or.w	d5,11048(a0)
	or.w	d4,11200(a0)
	or.w	d5,11208(a0)
	or.w	d4,12640(a0)
	or.w	d5,12648(a0)
	or.w	d4,12800(a0)
	or.w	d5,12808(a0)
	or.w	d4,14240(a0)
	or.w	d5,14248(a0)
	or.w	d4,14400(a0)
	or.w	d5,14408(a0)
	or.w	d4,15840(a0)
	or.w	d5,15848(a0)
	or.w	d4,16000(a0)
	or.w	d5,16008(a0)
	or.w	d4,17440(a0)
	or.w	d5,17448(a0)
	or.w	d4,17600(a0)
	or.w	d5,17608(a0)
	or.w	d4,19040(a0)
	or.w	d5,19048(a0)
	or.w	d4,19200(a0)
	or.w	d5,19208(a0)
	or.w	d4,20640(a0)
	or.w	d5,20648(a0)
	or.w	d4,20800(a0)
	or.w	d5,20808(a0)
	or.w	d4,22240(a0)
	or.w	d5,22248(a0)
	or.w	d4,22400(a0)
	or.w	d5,22408(a0)
	or.w	d4,23840(a0)
	or.w	d5,23848(a0)
	or.w	d4,24000(a0)
	or.w	d5,24008(a0)

.done_horiz_split:

;;; Spread the small squares into position
	moveq.l	#0,d0
	move.w	2(a6),d0

; delay the start until the square is drawn
	cmp.w	#72,d0
	bmi	.no_anim
	subi.w	#72,d0

; TODO; stop drawing when the animation is done
;   	currently wastes time by continuously drawing the last frame
;	still gotta be careful to draw the last frame on both screens
.growth_done:
	lsr.w	#3,d0		; slow down the animation by 8x

	cmpi.w	#33,d0		; 33 is 6*5.5 (6 pixels * 11 intervals / 2)
	bmi.s	.in_range
	moveq.l	#33,d0
.in_range:

; Compute pixel count between squares (including fractional pixels)
	swap.w	d0		; 16:16
	lsr.l	#4,d0		; 20:12
	divu.w	#11,d0		; junk:4:12
	andi.l	#$ffff,d0	; 20:12
	lsl.l	#4,d0		; 16:16

	move.l	back_buffer,a0
	adda.w	#16038,a0	; offset to left edge, mid-height, last plane
	move.l	a0,a1		; a0 moves down, a1 moves up

	move.l	#$00008000,d1	; running count of fractional pixels

	add.l	d0,d1		; accumulate fractional pixels
	swap.w	d1
	move.w	d1,d2		; extract increment of whole pixels
	clr.w	d1		; and clear it
	swap.w	d1

	moveq.l	#0,d3
	bra.s	.clear_loop1	; enter loop
.clear_between1:
	move.w	d3,(a0)		; clear bottom half
	move.w	d3,8(a0)
	move.w	d3,16(a0)
	move.w	d3,24(a0)
	move.w	d3,32(a0)
	move.w	d3,40(a0)
	move.w	d3,48(a0)
	move.w	d3,56(a0)
	move.w	d3,64(a0)
	move.w	d3,72(a0)
	move.w	d3,80(a0)
	move.w	d3,88(a0)
	adda.w	#160,a0		; 	and post-increment
	suba.w	#160,a1		; pre-decrement top half
	move.w	d3,(a1)		; 	and clear
	move.w	d3,8(a1)
	move.w	d3,16(a1)
	move.w	d3,24(a1)
	move.w	d3,32(a1)
	move.w	d3,40(a1)
	move.w	d3,48(a1)
	move.w	d3,56(a1)
	move.w	d3,64(a1)
	move.w	d3,72(a1)
	move.w	d3,80(a1)
	move.w	d3,88(a1)
.clear_loop1:
	dbra.w	d2,.clear_between1

	add.l	d0,d0		; double the increment between lines
				; (center has a half-increment on either side)

	moveq.l	#5,d7		; draw 6 rows of squares on each half

	lea.l	wave_spread_gfx,a2
	move.l	#$1ff81008,(a2)


.draw_square:
	suba.w	#1600,a1

	moveq.l	#11,d2

.draw_column:
	move.l	(a2),d3

	move.w	d3,160(a0)
	move.w	d3,320(a0)
	move.w	d3,480(a0)
	move.w	d3,640(a0)
	move.w	d3,800(a0)
	move.w	d3,960(a0)
	move.w	d3,1120(a0)
	move.w	d3,1280(a0)

	move.w	d3,160(a1)
	move.w	d3,320(a1)
	move.w	d3,480(a1)
	move.w	d3,640(a1)
	move.w	d3,800(a1)
	move.w	d3,960(a1)
	move.w	d3,1120(a1)
	move.w	d3,1280(a1)

	swap.w	d3

	move.w	d3,(a0)
	move.w	d3,1440(a0)
	move.w	d3,(a1)
	move.w	d3,1440(a1)

	addq.w	#8,a0
	addq.w	#8,a1

	dbra.w	d2,.draw_column

	suba.w	#96,a0
	suba.w	#96,a1

	adda.w	#1600,a0

	add.l	d0,d1		; accumulate fractional pixels
	swap.w	d1
	move.w	d1,d2		; extract increment of whole pixels
	clr.w	d1		; and clear it
	swap.w	d1

	moveq.l	#0,d3
	bra.s	.clear_loop2	; enter loop
.clear_between2:
	move.w	d3,(a0)		; clear bottom half
	move.w	d3,8(a0)
	move.w	d3,16(a0)
	move.w	d3,24(a0)
	move.w	d3,32(a0)
	move.w	d3,40(a0)
	move.w	d3,48(a0)
	move.w	d3,56(a0)
	move.w	d3,64(a0)
	move.w	d3,72(a0)
	move.w	d3,80(a0)
	move.w	d3,88(a0)
	adda.w	#160,a0		; 	and post-increment
	suba.w	#160,a1		; pre-decrement top half
	move.w	d3,(a1)		; 	and clear
	move.w	d3,8(a1)
	move.w	d3,16(a1)
	move.w	d3,24(a1)
	move.w	d3,32(a1)
	move.w	d3,40(a1)
	move.w	d3,48(a1)
	move.w	d3,56(a1)
	move.w	d3,64(a1)
	move.w	d3,72(a1)
	move.w	d3,80(a1)
	move.w	d3,88(a1)
.clear_loop2:
	dbra.w	d2,.clear_between2

	dbra.w	d7,.draw_square


.no_anim:

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Precompute the graphics for the waveform spheres
;;;;;;;;

wave_compute_core:
;;; Set palette for pre-animation
	move.w	#$102,$ffff8240.w
	move.w	#$fff,$ffff8250.w

;;; Precompute sphere graphics
; d0,d1,d2: bit planes
; d3: pixel color
; d5-d7: loops
; a0: destination for writes
; a1: data for sphere shape
	lea.l	heap,a0
	move.w	#255,d7		; generate 256 images
.generate_image:
	moveq.l	#11,d6		; 12 rows per image
	lea.l	wave_sphere,a1
.generate_row:
	moveq.l	#11,d5		; 12 active pixels per row
	moveq.l	#0,d0
	moveq.l	#0,d1
	moveq.l	#0,d2
.input_pixel:
	moveq.l	#0,d3
	move.b	(a1)+,d3
	tst.b	d3		; 0 in input = black/trasparent
	beq.s	.computed_pixel
	sub.b	d7,d3		; sub byte, wraparound, still 0-255


;	mulu.w	#1799,d3	; 0 to 456960 ($6FFF9) (1799 = 65536*7/255)
;	swap.w	d3		; 0 to 6
;	addq.w	#1,d3		; 1 to 7

	addi.b	#202,d3
	mulu.w	#3084,d3	; 0 to 786420 ($BFFF4) (3084 = 65536*12/255)
	swap.w	d3		; 0 to 11
	addq.w	#1,d3		; 1 to 12
	cmp.w	#7,d3
	ble.s	.computed_pixel
	neg.w	d3		; -8 to -12
	addi.w	#14,d3		; 6 to 2

.computed_pixel:

	lsr.w	d3		; extract bit 0
	roxl.w	d0		; insert
	lsr.w	d3		; bit 1
	roxl.w	d1
	lsr.w	d3		; bit 2
	roxl.w	d2
	dbra.w	d5,.input_pixel

	lsl.w	#2,d0		; shift by 2 pixels to center (12 in 16)
	lsl.w	#2,d1
	lsl.w	#2,d2
	move.w	d0,(a0)+	; store data
	move.w	d1,(a0)+
	move.w	d2,(a0)+
	dbra.w	d6,.generate_row
;	move.w	d7,$ffff8240.w
	dbra.w	d7,.generate_image

;;; Precompute cubes
; d7: angle
; a6: sine table
; a0: read xyz
; a1: output 3d xyz
; a2: output bitmaps
	lea.l	wave_sine,a6
	lea.l	heap+18432,a2
	moveq.l	#0,d7
	move.w	#511,d7
.cube_frame:
	lea.l	wave_cube_xyz,a0
	lea.l	wave_cube_3d_xyz,a1
.next_vertex:
; d0-d2: x0/y0/z0
; d3-d6: modified by subroutine
	move.w	(a0)+,d0
	tst.w	d0
	beq.s	.cube_rotate_done
	move.w	(a0)+,d1
	move.w	(a0)+,d2
	move.w	d7,d6		; XXX hack beta rotation
	lsr.w	#2,d6		; XXX hack beta rotation
	swap.w	d7		; XXX hack beta rotation
	move.w	d6,d7		; XXX hack beta rotation
	swap.w	d7		; XXX hack beta rotation
	bsr	wave_cube_rotate
	move.w	d0,(a1)+
	move.w	d1,(a1)+
	move.w	d2,(a1)+
	bra.s	.next_vertex
.cube_rotate_done:

	moveq.l	#0,d0
	.rept	8
	move.l	d0,(a2)+
	.endr

	suba.w	#48,a1

	move.w	(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	2(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	6(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	8(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line

	move.w	6(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	8(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	12(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	14(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line

	move.w	12(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	14(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	18(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	20(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line

	move.w	18(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	20(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	2(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line


	move.w	24(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	26(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	30(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	32(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line

	move.w	30(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	32(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	36(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	38(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line

	move.w	36(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	38(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	42(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	44(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line

	move.w	42(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	44(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	24(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	26(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line


	move.w	(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	2(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	42(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	44(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line

	move.w	6(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	8(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	36(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	38(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line

	move.w	12(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	14(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	30(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	32(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line

	move.w	18(a1),d0
	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	move.w	20(a1),d1
	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1
	move.w	24(a1),d2
	addi.w	#2048,d2	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d2
	move.w	26(a1),d3
	addi.w	#2048,d3	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d3
	lea.l	-32(a2),a3
	bsr	wave_draw_line



;;; TODO: remove this whole code. It just shows how to do z removal
	moveq.l	#7,d6
.draw_pixel:
	move.w	(a1)+,d0
	move.w	(a1)+,d1
	move.w	(a1)+,d2

	addi.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	moveq.l	#1,d5
	ror.w	d5
	lsr.w	d0,d5

	addi.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1

	tst.w	d2
	bpl.s	.visible_pixel

	move.w	d1,d2
	lsl.w	#4,d2
	add.w	d0,d2
	lea.l	wave_sphere_mask,a3
	tst.b	(a3,d2.w)
	bne.s	.pixel_done

.visible_pixel:
	add.w	d1,d1
;	or.w	d5,-32(a2,d1.w)

.pixel_done:
	dbra.w	d6,.draw_pixel


;	move.w	d7,$ffff8240.w
	dbra.w	d7,.cube_frame

;;; Set palette
; green-cyan
;	lea.l	$ffff8242.w,a0

;	move.w	#$070,(a0)+
;	move.l	#$0720073,(a0)+
;	move.l	#$0740075,(a0)+
;	move.l	#$0760077,(a0)+

;	move.l	#$5550573,(a0)+
;	move.l	#$5740575,(a0)+
;	move.l	#$5760577,(a0)+
;	move.l	#$5770577,(a0)+

; blue-cyan
;	lea.l	$ffff8242.w,a0

;	move.w	#$007,(a0)+
;	move.l	#$0270037,(a0)+
;	move.l	#$0470057,(a0)+
;	move.l	#$0670077,(a0)+

;	move.l	#$5550557,(a0)+
;	move.l	#$5570567,(a0)+
;	move.l	#$5670567,(a0)+
;	move.l	#$5770577,(a0)+

; greg #1
	lea.l	$ffff8240.w,a0

	move.l	#$1020016,(a0)+
	move.l	#$0360046,(a0)+
	move.l	#$2560266,(a0)+
	move.l	#$4660476,(a0)+

; greg #2
	lea.l	$ffff8240.w,a0

	move.l	#$1020374,(a0)+
	move.l	#$0720062,(a0)+
	move.l	#$0520142,(a0)+
	move.l	#$2310221,(a0)+

; greg #3
	lea.l	$ffff8240.w,a0

	move.l	#$1020321,(a0)+
	move.l	#$4210411,(a0)+
	move.l	#$4130513,(a0)+
	move.l	#$6130714,(a0)+

; greg #4
	lea.l	$ffff8240.w,a0

	move.l	#$1020736,(a0)+
	move.l	#$7160617,(a0)+
	move.l	#$5170417,(a0)+
	move.l	#$3170017,(a0)+

	move.l	#$3060306,d0
	move.l	#$fff0fff,d0
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+

; rainbow
;	lea.l	$ffff8242.w,a0
;	move.w	#$711,(a0)+
;	move.l	#$7400660,(a0)+
;	move.l	#$0700166,(a0)+
;	move.l	#$2270717,(a0)+
;	move.l	#$5550755,(a0)+
;	move.l	#$7650775,(a0)+
;	move.l	#$5750577,(a0)+
;	move.l	#$5570757,(a0)+

; Done, let the drawing begin
	move.b	#1,compute_phase
	clr.l	compute_routine
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Subroutine to compute the rotations
; d0-d2: x/y/z input/output
; d3-d6: modified
; d7: angles (alpha in low word, beta in high word) (!!!) (unmodified)
; a0-a5: unused
; a6: trig table (unmodified)
;;;;;;;;
wave_cube_rotate:
; rotate by alpha around z - d5 is trig scratch

; x = x0 * cos(alpha) - y0 * sin(alpha)
	move.w	d0,d3		; x0
	move.l	d7,d6		; alpha
	addi.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d3	; x0 * cos(alpha) * 32k

	move.w	d1,d5		; y0
	move.l	d7,d6		; alpha
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d5	; y0 * sin(alpha) * 32k

	sub.l	d5,d3		; new x * 32k
	add.l	d3,d3		; new x * 64k
	swap.w	d3		; new x

; y = y0 * cos(alpha) + x0 * sin(alpha)
	move.w	d1,d4		; y0
	move.l	d7,d6		; alpha
	addi.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d4	; y0 * cos(alpha) * 32k

	move.w	d0,d5		; x0
	move.l	d7,d6		; alpha
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d5	; x0 * sin(alpha) * 32k

	add.l	d5,d4		; new y * 32k
	add.l	d4,d4		; new y * 64k
	swap.w	d4		; new y

	move.w	d3,d0		; update x0
	move.w	d4,d1		; update y0

; rotate by beta around x - d3 is trig scratch

; y = y0 * cos(beta) - z0 * sin(beta)
	move.w	d1,d4		; y0
	move.l	d7,d6
	swap.w	d6		; beta
	addi.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d4	; y0 * cos(beta) * 32k

	move.w	d2,d3		; z0
	move.l	d7,d6
	swap.w	d6		; beta
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d3	; z0 * sin(beta) * 32k

	sub.l	d3,d4		; new y * 32k
	add.l	d4,d4		; new y * 64k
	swap.w	d4		; new y

; z = z0 * cos(beta) + y0 * sin(beta)
	move.w	d2,d5		; z0
	move.l	d7,d6
	swap.w	d6		; beta
	addi.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d5	; z0 * cos(beta) * 32k

	move.w	d1,d3		; y0
	move.l	d7,d6
	swap.w	d6		; beta
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d3	; y0 * sin(beta) * 32k

	add.l	d3,d5		; new z * 32k
	add.l	d5,d5		; new z * 64k
	swap.w	d5		; new z

	move.w	d4,d1		; update y0
	move.w	d5,d2		; update z0

; rotate by alpha around y - d4 is trig scratch

; z = z0 * cos(alpha) - x0 * sin(alpha)
	move.w	d2,d5		; z0
	move.l	d7,d6		; alpha
	lsr.w	d6		; XXX remove me, test
	addi.w	#79,d6		; XXX remove me, test
	addi.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d5	; z0 * cos(alpha) * 32k

	move.w	d0,d4		; x0
	move.l	d7,d6		; alpha
	lsr.w	d6		; XXX remove me, test
	addi.w	#79,d6		; XXX remove me, test
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d4	; x0 * sin(alpha) * 32k

	sub.l	d4,d5		; new z * 32k
	add.l	d5,d5		; new z * 64k
	swap.w	d5		; new z

; x = x0 * cos(alpha) + z0 * sin(alpha)
	move.w	d0,d3		; x0
	move.l	d7,d6		; alpha
	lsr.w	d6		; XXX remove me, test
	addi.w	#79,d6		; XXX remove me, test
	addi.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d3	; x0 * cos(alpha) * 32k

	move.w	d2,d4		; z0
	move.l	d7,d6		; alpha
	lsr.w	d6		; XXX remove me, test
	addi.w	#79,d6		; XXX remove me, test
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d4	; z0 * sin(alpha) * 32k

	add.l	d4,d3		; new x * 32k
	add.l	d3,d3		; new x * 64k
	swap.w	d3		; new x

	move.w	d5,d2		; update z0
	move.w	d3,d0		; update x0

; rotate by beta around z - d5 is trig scratch

; x = x0 * cos(beta) - y0 * sin(beta)
	move.w	d0,d3		; x0
	move.l	d7,d6
	swap.w	d6		; beta
	addi.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d3	; x0 * cos(beta) * 32k

	move.w	d1,d5		; y0
	move.l	d7,d6
	swap.w	d6		; beta
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d5	; y0 * sin(beta) * 32k

	sub.l	d5,d3		; new x * 32k
	add.l	d3,d3		; new x * 64k
	swap.w	d3		; new x

; y = y0 * cos(alpha) + x0 * sin(alpha)
	move.w	d1,d4		; y0
	move.l	d7,d6
	swap.w	d6		; beta
	addi.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d4	; y0 * cos(beta) * 32k

	move.w	d0,d5		; x0
	move.l	d7,d6
	swap.w	d6		; beta
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d5	; x0 * sin(beta) * 32k

	add.l	d5,d4		; new y * 32k
	add.l	d4,d4		; new y * 64k
	swap.w	d4		; new y

	move.w	d3,d0		; update x0
	move.w	d4,d1		; update y0

	rts

;;; Subroutine to draw lines

wave_draw_line:
; d0,d1: x0,y0
; d2,d3: x1,y1
; a3: destination bitmap

; ensure d0 >= d2
	cmp.w	d0,d2
	ble.s	.lines_ordered ; d2 >= d0
	exg	d0,d2
	exg	d1,d3
.lines_ordered:

; Compute end of line relative to start
	moveq.l	#2,d4	; addr_offset
	sub.w	d0,d2	; dx
	neg.w	d2

	sub.w	d1,d3	; dy
; Adjust delta-y to be positive, adjust line offset accordingly
	bge.s	.adjusted_dy ; d3 >= d1
	neg.w	d3
	neg.w	d4
.adjusted_dy:

; Compute start address and start pixel pattern
	add.w	d1,d1
	adda.w	d1,a3

	move.w	d0,d1
	move.w	#$8000,d5 ; pixel pattern
	andi.w	#15,d1
	lsr.w	d1,d5

; Check which type of line we're drawing
	cmp.w	d2,d3
	blt.s	.wave_draw_h_line ; d3 < d2
	beq.s	.wave_draw_d_line ; d3 = d2 - includes single-pixel lines

; Draw a vertical-ish line
.wave_draw_v_line:
	swap.w	d2
	clr.w	d2
	divu	d3,d2
	move.w	#$7fff,d6

.draw_v_pixel:
	or.w	d5,(a3)
	add.w	d2,d6
	bcc.s	.done_v_adjust
	add.w	d5,d5
;	bne.s	.done_v_adjust
;	subq.l	#8,a0
;	moveq.l	#1,d5
.done_v_adjust:
	add.w	d4,a3
	dbra	d3,.draw_v_pixel
	rts

.wave_draw_h_line:
;	rts
; Draw a horizontal-ish line
.setup_h_slope:
	swap.w	d3
	clr.w	d3
	divu	d2,d3
	move.w	#$7fff,d6

.draw_h_pixel:
	or.w	d5,(a3)
	add.w	d3,d6
	bcc.s	.done_h_adjust1
	add.w	d4,a3
.done_h_adjust1:
	add.w	d5,d5
;	bne.s	.done_h_adjust2
;	subq.l	#8,a0
;	moveq.l	#1,d5
;.done_h_adjust2:
	dbra	d2,.draw_h_pixel
	rts

.wave_draw_d_line:
.draw_d_pixel:
	or.w	d5,(a3)
	add.w	d5,d5
;	bne.s	.done_d_adjust
;	subq.l	#8,a0
;	moveq.l	#1,d5
;.done_d_adjust:
	add.w	d4,a3
	dbra	d3,.draw_d_pixel
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Update the coordinates for the waveform spheres
;;;;;;;;
wave_update:
	move.l	most_recently_updated,a5
	move.l	next_to_update,a6

	move.w	(a5),d0
	addq.w	#1,d0
	move.w	d0,(a6)
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Draw the waveform spheres
;;;;;;;;
; MORE: investigate whether drawing diagonally is faster
;	advantage is that each cell type gets read once (36 -> 11)
;	drawback is the complexity of updating pointers at end of row
;	maybe just precompute and store the offsets?
; MORE: investigate whether code-generation is faster
;	drawbacks are complexity and maybe more code
; d0: increment (between columns on 1st row / between rows on 1st column)
; d1: row start
; d2: current cell
; d3: scratch
; d4: data 1
; d5: data 2
; d6: loop x
; d7; loop y
; a0: write 1 (top left)
; a1: write 2 (top right)
; a2: write 3 (bottom left)
; a3: write 4 (bottom right)
; a4: read graphics
; a5: graphics start
; a6: free
wave_draw:
	.rept	16
;	move.w	#$700,$ffff8240.w
;	move.w	#$000,$ffff8240.w
	.endr

	move.l	back_to_draw_data,a6
	move.w	(a6),d0
	lea.l	heap,a5

; Point to the top row of the centermost spheres
	move.l	back_buffer,a0
	move.l	a0,a1
	move.l	a0,a2
	move.l	a0,a3
	adda.w	#13832,a0
	adda.w	#13840,a1
	adda.w	#16392,a2
	adda.w	#16400,a3

	move.w	#5,d7		; elements in a column (x2)
	move.w	d0,d1
.copy_row:
	move.w	#5,d6		; elements in a row (x2)
	move.w	d1,d2

.copy_element:
; Compute address of graphics to read (heap + frame % 256 * 72)
	moveq.l	#0,d3
	move.b	d2,d3
	lsl.w	#3,d3		; x8
	move.w	d3,d4
	lsl.w	#3,d4		; x64
	add.w	d4,d3		; x72
	move.l	a5,a4
	adda.w	d3,a4

; Draw 4 spheres
	move.l	(a4)+,d4	; read gfx 1 (2 planes)
	move.w	(a4)+,d5	; read gfx 2 (1 plane)
	move.l	d4,(a0)		; write planes 0-1
	move.w	d5,4(a0)	; write plane 2
	move.l	d4,(a1)		; repeat for other 3 quadrants
	move.w	d5,4(a1)
	move.l	d4,(a2)
	move.w	d5,4(a2)
	move.l	d4,(a3)
	move.w	d5,4(a3)

	move.l	(a4)+,d4	; unrolled 12 times
	move.w	(a4)+,d5
	move.l	d4,160(a0)
	move.w	d5,164(a0)
	move.l	d4,160(a1)
	move.w	d5,164(a1)
	move.l	d4,160(a2)
	move.w	d5,164(a2)
	move.l	d4,160(a3)
	move.w	d5,164(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,320(a0)
	move.w	d5,324(a0)
	move.l	d4,320(a1)
	move.w	d5,324(a1)
	move.l	d4,320(a2)
	move.w	d5,324(a2)
	move.l	d4,320(a3)
	move.w	d5,324(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,480(a0)
	move.w	d5,484(a0)
	move.l	d4,480(a1)
	move.w	d5,484(a1)
	move.l	d4,480(a2)
	move.w	d5,484(a2)
	move.l	d4,480(a3)
	move.w	d5,484(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,640(a0)
	move.w	d5,644(a0)
	move.l	d4,640(a1)
	move.w	d5,644(a1)
	move.l	d4,640(a2)
	move.w	d5,644(a2)
	move.l	d4,640(a3)
	move.w	d5,644(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,800(a0)
	move.w	d5,804(a0)
	move.l	d4,800(a1)
	move.w	d5,804(a1)
	move.l	d4,800(a2)
	move.w	d5,804(a2)
	move.l	d4,800(a3)
	move.w	d5,804(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,960(a0)
	move.w	d5,964(a0)
	move.l	d4,960(a1)
	move.w	d5,964(a1)
	move.l	d4,960(a2)
	move.w	d5,964(a2)
	move.l	d4,960(a3)
	move.w	d5,964(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1120(a0)
	move.w	d5,1124(a0)
	move.l	d4,1120(a1)
	move.w	d5,1124(a1)
	move.l	d4,1120(a2)
	move.w	d5,1124(a2)
	move.l	d4,1120(a3)
	move.w	d5,1124(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1280(a0)
	move.w	d5,1284(a0)
	move.l	d4,1280(a1)
	move.w	d5,1284(a1)
	move.l	d4,1280(a2)
	move.w	d5,1284(a2)
	move.l	d4,1280(a3)
	move.w	d5,1284(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1440(a0)
	move.w	d5,1444(a0)
	move.l	d4,1440(a1)
	move.w	d5,1444(a1)
	move.l	d4,1440(a2)
	move.w	d5,1444(a2)
	move.l	d4,1440(a3)
	move.w	d5,1444(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1600(a0)
	move.w	d5,1604(a0)
	move.l	d4,1600(a1)
	move.w	d5,1604(a1)
	move.l	d4,1600(a2)
	move.w	d5,1604(a2)
	move.l	d4,1600(a3)
	move.w	d5,1604(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1760(a0)
	move.w	d5,1764(a0)
	move.l	d4,1760(a1)
	move.w	d5,1764(a1)
	move.l	d4,1760(a2)
	move.w	d5,1764(a2)
	move.l	d4,1760(a3)
	move.w	d5,1764(a3)

	subq.l	#8,a0		; point to next item horizontally
	addq.l	#8,a1
	subq.l	#8,a2
	addq.l	#8,a3
	add.w	d0,d2		; update ball rotation on the row
	dbra.w	d6,.copy_element
	sub.w	#2512,a0	; point to start of next row
	sub.w	#2608,a1
	add.w	#2608,a2
	add.w	#2512,a3
	add.w	d0,d1		; update ball rotation on start of next row
	dbra.w	d7,.copy_row


	move.l	back_buffer,a0
	adda.w	#678,a0
	moveq.l	#11,d7
.cube_row:
	moveq.l	#11,d6
.cube_column:
	lea.l	heap+18432,a1

	move.l	back_to_draw_data,a6
	move.w	(a6),d0
	add.w	d6,d0
	add.w	d6,d0
	add.w	d7,d0
	add.w	d7,d0
	add.w	d7,d0
	andi.w	#511,d0
	lsl.w	#5,d0
	adda.w	d0,a1

	move.w	(a1)+,(a0)
	move.w	(a1)+,160(a0)
	move.w	(a1)+,320(a0)
	move.w	(a1)+,480(a0)
	move.w	(a1)+,640(a0)
	move.w	(a1)+,800(a0)
	move.w	(a1)+,960(a0)
	move.w	(a1)+,1120(a0)
	move.w	(a1)+,1280(a0)
	move.w	(a1)+,1440(a0)
	move.w	(a1)+,1600(a0)
	move.w	(a1)+,1760(a0)
	move.w	(a1)+,1920(a0)
	move.w	(a1)+,2080(a0)
	move.w	(a1)+,2240(a0)
	move.w	(a1)+,2400(a0)
	addq.l	#8,a0
	dbra.w	d6,.cube_column
	adda.w	#2464,a0
	dbra.w	d7,.cube_row

	.rept	16
;	move.w	#$070,$ffff8240.w
;	move.w	#$000,$ffff8240.w
	.endr

	rts

	.data

; Sphere rotation data
; computed in Google Sheets
; =ROUND(ACOS((13-2*$A2)/12/SQRT(1-((13-2*B$1)/12)^2))*128/PI())
wave_sphere:
;	dc.b	0,0,0,0,0,0,0,0,0,0,0,0
;	dc.b	0,0,0,0,0,0,0,0,0,0,0,0
;	dc.b	0,0,0,0,38,39,39,38,0,0,0,0
;	dc.b	0,0,0,45,46,46,46,46,45,0,0,0
;	dc.b	0,0,51,53,53,54,54,53,53,51,0,0
;	dc.b	0,0,60,60,60,61,61,60,60,60,0,0
;	dc.b	0,0,68,68,68,67,67,68,68,68,0,0
;	dc.b	0,0,77,75,75,74,74,75,75,77,0,0
;	dc.b	0,0,0,83,82,82,82,82,83,0,0,0
;	dc.b	0,0,0,0,90,89,89,90,0,0,0,0
;	dc.b	0,0,0,0,0,0,0,0,0,0,0,0
;	dc.b	0,0,0,0,0,0,0,0,0,0,0,0


	dc.b	0,0,0,0,13,16,16,13,0,0,0,0
	dc.b	0,0,16,24,28,29,29,28,24,16,0,0
	dc.b	0,20,31,36,38,39,39,38,36,31,20,0
	dc.b	0,36,42,45,46,46,46,46,45,42,36,0
	dc.b	36,48,51,53,53,54,54,53,53,51,48,36
	dc.b	55,59,60,60,60,61,61,60,60,60,59,55
	dc.b	73,69,68,68,68,67,67,68,68,68,69,73
	dc.b	92,80,77,75,75,74,74,75,75,77,80,92
	dc.b	0,92,86,83,82,82,82,82,83,86,92,0
	dc.b	0,108,97,92,90,89,89,90,92,97,108,0
	dc.b	0,0,112,104,100,99,99,100,104,112,0,0
	dc.b	0,0,0,0,115,112,112,115,0,0,0,0

; TODO: put on the heap
wave_sphere_mask:
	dcb.b	16,0
	dcb.b	16,0
	dc.b	0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0
	dc.b	0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
	dc.b	0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
	dc.b	0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
	dc.b	0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0
	dc.b	0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0
	dc.b	0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0
	dc.b	0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0
	dc.b	0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
	dc.b	0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
	dc.b	0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
	dc.b	0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0
	dcb.b	16,0
	dcb.b	16,0

	.even
; Sine curve, 128 steps, scaled by 32767
; computed in Google Sheets
; =ROUND(SIN(2*PI()*$A24/128)*32767)
; MORE: easy to unfold, especially if offset a tiny bit.
wave_sine:
	dc.w	0,1608,3212,4808,6393,7962,9512,11039
	dc.w	12539,14010,15446,16846,18204,19519,20787,22005
	dc.w	23170,24279,25329,26319,27245,28105,28898,29621
	dc.w	30273,30852,31356,31785,32137,32412,32609,32728
	dc.w	32767,32728,32609,32412,32137,31785,31356,30852
	dc.w	30273,29621,28898,28105,27245,26319,25329,24279
	dc.w	23170,22005,20787,19519,18204,16846,15446,14010
	dc.w	12539,11039,9512,7962,6393,4808,3212,1608
	dc.w	0,-1608,-3212,-4808,-6393,-7962,-9512,-11039
	dc.w	-12539,-14010,-15446,-16846,-18204,-19519,-20787,-22005
	dc.w	-23170,-24279,-25329,-26319,-27245,-28105,-28898,-29621
	dc.w	-30273,-30852,-31356,-31785,-32137,-32412,-32609,-32728
	dc.w	-32767,-32728,-32609,-32412,-32137,-31785,-31356,-30852
	dc.w	-30273,-29621,-28898,-28105,-27245,-26319,-25329,-24279
	dc.w	-23170,-22005,-20787,-19519,-18204,-16846,-15446,-14010
	dc.w	-12539,-11039,-9512,-7962,-6393,-4808,-3212,-1608

wave_cube_xyz:
; largest cube that can be drawn in 16*16
; =8/SQRT(3)*256
	dc.w	1182,1182,1182
	dc.w	1182,1182,-1182
	dc.w	1182,-1182,-1182
	dc.w	1182,-1182,1182
	dc.w	-1182,-1182,1182
	dc.w	-1182,-1182,-1182
	dc.w	-1182,1182,-1182
	dc.w	-1182,1182,1182
	dc.w	0

	.bss
	.even
wave_f1:
	ds.w	2
wave_f2:
	ds.w	2
wave_f3:
	ds.w	2
wave_f4:
	ds.w	2

wave_spread_gfx:
	ds.l	12
wave_cube_3d_xyz:
	ds.w	24
