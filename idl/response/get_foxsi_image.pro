;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;FUNCTION:      "get_foxsi_image"
;;;
;;;HISTORY:       Initial Commit - 08/19/15 - Samuel Badman
;;;
;;;DESCRIPTION:   Function which accepts a map of a source as an input, obtained through
;;;               calling source_map = get_source_map(). This map is the
;;;               convolved with a point spread function obtained through calling the
;;;               function get_psf_array with arguments specifying the
;;;               solar coordinates of the image sensor. After
;;;               convolution, the new image is rebinned according to
;;;               the keyword px = pix_size (default = 3) to reflect the
;;;               loss of resolution due to the finite strip size in the detectors.
;;; 
;;;
;;;CALL SEQUENCE: rebinned_convolved_map = get_foxsi_image()
;;;
;;;
;;;KEYWORDS:      source_map = "source_map". User inputted source, if
;;;               blank, default generated from get_source_map
;;;               function
;;;
;;;               px = "pixel size of detector" in arcseconds, default is 3''
;;;
;;;
;;;COMMENTS:      -Runtime scales badly with FOV size
;;;               -The default source array is 
;;;               set to [150,150] ~2.5' X 2.5' FOV at 1 arcsec per
;;;               pixel, this takes a few seconds to run.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FUNCTION get_foxsi_image,source_map = source_map, px = pix_size

IF N_ELEMENTS(SOURCE_MAP) EQ 0 THEN PRINT, 'No user input detected, using default source image'

;;;;; Check for updates to peripheral functions for the purposes of testing
RESOLVE_ROUTINE, 'get_psf_array', /IS_FUNCTION
RESOLVE_ROUTINE, 'get_source_map', /IS_FUNCTION

;;;; Define default source_map input in case of no user input
DEFAULT, source_map, get_source_map()

;;;;; Define default detector resolution to 3 arcsecs per pixel
DEFAULT, pix_size, 3




;;Below, we call the point spread function assuming it is constant
;;across the field of view for a given pointing and only depends on
;;the pointing itself. 
;;To change this and introduce dependence of the psf on position in
;;the FOV being convolved, comment out the line marked below and
;;uncomment the copy of it inside the FOR loop (Note this will slow down runtime a lot)

x=0 ;; Redundant FOV coordinates required as arguments for get_psf_array
y=0


x_size = N_ELEMENTS(REFORM(source_map.data[*,0]))*1.0  ;;; Get dimensions of FOV in pixels
y_size = N_ELEMENTS(REFORM(source_map.data[0,*]))*1.0 

print, strcompress('Source_Array_is_'+string(N_ELEMENTS(REFORM(source_map.data[*,0]))) $
+'x'+string(N_ELEMENTS(REFORM(source_map.data[0,*])))+'_Pixels', /REMOVE_AL)

;; If psf is large and has non zero intensity far from the psf centre
;; then the psf array must be larger than the source array or some
;; point spread emission will be lost due to array cutoffs. For
;; perfect reconstruction in all cases, scale factor should be 2


psf_scale_factor = 2

;;;Comment out the line below::::
psf_array = get_psf_array(source_map.xc,source_map.yc,source_map.dx                  $
,source_map.dy,x,y, psf_scale_factor,x_size,y_size) 

psf_x_size = n_elements(reform(psf_array[*,0]))*1.0
psf_y_size = n_elements(reform(psf_array[0,*]))*1.0


convolved_array = DBLARR(x_size,y_size)

FOR i = 0.0, N_ELEMENTS(source_map.data)-1 DO BEGIN

        x = (i MOD x_size)*1.0   ;;;Calculate FOV x,y coordinates from FOR loop variable
        y = (i - x)/x_size*1.0


        ;;;Below: Progress Monitor ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	IF i/(N_ELEMENTS(source_map.data)) EQ 0.1 THEN PRINT, '10% Complete'
	IF i/(N_ELEMENTS(source_map.data)) EQ 0.2 THEN PRINT, '20% Complete'
	IF i/(N_ELEMENTS(source_map.data)) EQ 0.3 THEN PRINT, '30% Complete'
	IF i/(N_ELEMENTS(source_map.data)) EQ 0.4 THEN PRINT, '40% Complete'
	IF i/(N_ELEMENTS(source_map.data)) EQ 0.5 THEN PRINT, '50% Complete'	
	IF i/(N_ELEMENTS(source_map.data)) EQ 0.6 THEN PRINT, '60% Complete'
	IF i/(N_ELEMENTS(source_map.data)) EQ 0.7 THEN PRINT, '70% Complete'
	IF i/(N_ELEMENTS(source_map.data)) EQ 0.8 THEN PRINT, '80% Complete'
        IF i/(N_ELEMENTS(source_map.data)) EQ 0.9 THEN PRINT, '90% Complete'
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

      ; Uncomment line below to introduce FOV coord dependence to get_psf_array      
      ; psf_array=get_psf_array(source_map.xc,source_map.yc,source_map.dx,source_map,dy,x,y)
       


        ;; Do convolution and correct for wrapping due to SHIFT
        ;; function for each pixel.
	convolved_pixel = psf_array * source_map.data[x,y]
	shifted_convolved_pixel = SHIFT(convolved_pixel,-1*(x_size/2 - x),-1*(y_size/2 - y))
      
        IF x_size/2 - x GT 0 THEN BEGIN
           shifted_convolved_pixel[psf_x_size-(x_size/2 - x):*,0:*] = 0
        ENDIF ELSE BEGIN
           shifted_convolved_pixel[0:x-x_size/2-1,0:*] = 0
        ENDELSE

        IF y_size/2 - y GT 0 THEN BEGIN
           shifted_convolved_pixel[0:*,psf_y_size-(y_size/2 - y):*] = 0
        ENDIF ELSE BEGIN
           shifted_convolved_pixel[0:*,0:y-y_size/2-1] = 0
        ENDELSE

       shifted_convolved_pixel = shifted_convolved_pixel[(psf_x_size-x_size)/2:(psf_x_size+x_size)/2-1, (psf_x_size-x_size)/2:(psf_y_size+y_size)/2-1]
 
       convolved_array = convolved_array + shifted_convolved_pixel

ENDFOR

PRINT, '100% Complete'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; Do rebinning due to detector pixelation;;;
rebinned_convolved_array = FREBIN(convolved_array,x_size*source_map.dx/pix_size,y_size*source_map.dy/pix_size, /TOTAL)


;; Detect if FREBIN causes unacceptable loss of counts (e.g for non
;; integer pixelation ratio. If detected, total counts are
;; renormalised to correct (ideal) value.

IF ABS(TOTAL(rebinned_convolved_array) - TOTAL(convolved_array)) GT 0.0001  THEN BEGIN
   rebinned_convolved_array =TOTAL(convolved_array)* (rebinned_convolved_array)/TOTAL(rebinned_convolved_array) ;;;; Renormalise counts to assume lossless between optics and detector
   print, 'Rebinning loss detected, renormalising...'
ENDIF


;;; Makes and outputs map of convolved and rebinned array with pixel size 
;;; equal to the value of the px keyword (default = 3'' per pixel)
;;; The centre of the map is preserved as the centre of the source image

rebinned_convolved_map = make_map(rebinned_convolved_array, dx = pix_size, dy = pix_size, xc = source_map.xc, yc = source_map.yc, id = STRCOMPRESS('Rebinned_Convolved_Map_Pixel_Size:'+string(pix_size),/REMOVE_AL))

print,  'rebinned_convolved_map returned'

RETURN, rebinned_convolved_map

END
