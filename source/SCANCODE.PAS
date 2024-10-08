{ this file contains constants for scan code conversion to ASCII
  for an XT keyboard. This is so my keyboard code doesn't need to use the BIOS
  keyboard interrupt. I'm forced to do this for XT systems as reading from the
  port more than once causes the code to miss some events, which causes keys to
  'stick' }

const
   scantable : array[0..127] of byte = ($00, $1B, $31, $32, $33, $34, $35, $36, $37, $38, $39, 
					$30, $2D, $3D, $08, $09, $71, $77, $65, $72, $74, 
					$79, $75, $69, $6F, $70, $5B, $5D, $0D, $00, $61, 
					$73, $64, $66, $67, $68, $6A, $6B, $6C, $3B, $27, 
					$60, $00, $5C, $7A, $78, $63, $76, $62, $6E, $6D, 
					$2C, $2E, $2F, $00, $00, $00, $20, $00, $00, $00, 
					$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 
					$00, $00, $00, $2D, $00, $00, $00, $2B, $00, $00, 
					$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 
					$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 
					$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 
					$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 
					$00, $00, $00, $00, $00, $00, $00);
   shiftscantable : array[0..127] of byte = ($00, $1B, $21, $40, $23, $24, $25, $5E, $26, $2A, $28, 
					     $29, $5F, $2B, $08, $00, $51, $57, $45, $52, $54, 
					     $59, $55, $49, $4F, $50, $7B, $7D, $0D, $00, $41, 
					     $53, $44, $46, $47, $48, $4A, $4B, $4C, $3A, $22, 
					     $7E, $00, $7C, $5A, $58, $43, $56, $42, $4E, $4D, 
					     $3C, $3E, $3F, $00, $00, $00, $20, $00, $54, $55, 
					     $56, $00, $00, $00, $00, $00, $00, $00, $00, $00, 
					     $37, $38, $39, $2D, $34, $35, $36, $2B, $31, $32, 
					     $33, $30, $2E, $00, $00, $00, $00, $00, $00, $00, 
					     $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 
					     $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 
					     $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, 
					     $00, $00, $00, $00, $00, $00, $00);
   
