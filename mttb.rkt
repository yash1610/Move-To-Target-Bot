#lang racket
;REQUIRES=============================================================================================
(require "AsipMain.rkt")
(require 2htdp/image)
;REAL CONSTANTS=======================================================================================
(define seconds_per_degree 0.00277777778); seconds it takes for the bot to move 1 degree
(define camera_hori_center 320)
(define camera_vert_center 240)
(define hori_ppd 10.2893890675) ;ppd=pixels per degree
(define vert_ppd 9.83606557377)
(define hori_dpp 0.0971875) ;dpp=degrees per pixel
(define vert_dpp 0.10166666666)
(define focal_length 3.04) ;in mm
(define sensor_height 3.68) ;in mm
(define vertical_resolution 640)
(define distance_covered_per_second 423) ;in mm
(define target_height 50) ;in mm
(define obstacle_height 50) ;in mm

;Image Capture and processing=========================================================================
(define image_counter 0)
(define call_string null)
(define img null)
(define processed_img null)
(define (click_and_process)
  (set! call_string
        (string-append "raspistill -t 1 -vf -hf -sa 100 -w 640 -h 480 -q 75 -o cam"(number->string image_counter)".jpg"))
  (system call_string)
  (set! img (bitmap/file (string-append "cam"(number->string image_counter)".jpg")))
  (set! processed_img (image->color-list img))
  (set! image_counter (+ image_counter 1)))
;Functions that are used later========================================================================
;Get Pixel Details
(define (get_pixel x y image)
  (list-ref processed_img (+ x (* (image-width image) y))))
;(get-pixel test-image 1785 539)
;Angle of target with respect to camera
(define (hori_angle x)
  (* (- x camera_hori_center) hori_dpp))
;Seconds to rotate to face target or obstacle depending on argument
(define (seconds_to_rotate x) ;where x=target_degrees_to_rotate/ obstacle_degrees_to_rotate
  (cond
    ((> x 0) (sleep (* x seconds_per_degree)))
    ((< x 0) (sleep (* -1 x seconds_per_degree)))
    ((equal? x 0) #t)))
;Rotation function to face the target
(define (rotate_to_face x) ;where x=target_degrees_to_rotate/ obstacle_degrees_to_rotate
  (cond
    ((> x 0)
     (setMotors 150 -150)
     (seconds_to_rotate x)
     (setMotors 0 0))
    ((< x 0)
     (setMotors -150 150)
     (seconds_to_rotate x)
     (setMotors 0 0))
    ((equal? x 0) #t)))
;Check if there is obstacle in path of target
(define is_obstacle_blocking? 0)
(define (obstacle_blocking?)
  (printf "~a\n~a\n~a\n~a" target_degrees_to_rotate obstacle_degrees_to_rotate distance_to_obstacle distance_to_target)
  (cond
    ((and (negative? target_degrees_to_rotate)
          (< (+ target_degrees_to_rotate -10) obstacle_degrees_to_rotate (- target_degrees_to_rotate -10))
          (< distance_to_obstacle distance_to_target))
     (set! is_obstacle_blocking? 1))
    ((and (positive? target_degrees_to_rotate)
          (< (- target_degrees_to_rotate 10) obstacle_degrees_to_rotate (+ target_degrees_to_rotate 10))
          (< distance_to_obstacle distance_to_target))
     (set! is_obstacle_blocking? 1))))
;Evasion for obstacle
(define (evade)
  (cond
    ((negative? obstacle_degrees_to_rotate)
     (set! obstacle_degrees_to_rotate (+ obstacle_degrees_to_rotate 5))
     (rotate_to_face obstacle_degrees_to_rotate)
     (setMotors -145 -150)
     (sleep (time_to_cover_distance_to_obstacle))
     (setMotors 0 0)
     (post_evade))
    (else
     (set! obstacle_degrees_to_rotate (- obstacle_degrees_to_rotate 5))
     (rotate_to_face obstacle_degrees_to_rotate)
     (setMotors -145 -150)
     (sleep (time_to_cover_distance_to_obstacle))
     (setMotors 0 0)
     (post_evade))))
;After Evade
(define post_evade_angle_to_target 0)
(define post_evade_distance_to_target 0)
(define (post_evade)
  (set! post_evade_distance_to_target
        (sqrt (-
               (+ (* distance_to_target distance_to_target) (* distance_to_obstacle distance_to_obstacle))
               (* 2 distance_to_target distance_to_obstacle (cos(degrees->radians obstacle_degrees_to_rotate))))))
  (set! post_evade_angle_to_target
        (- 180 (radians->degrees
                (acos (/
                       (- (+ (* distance_to_obstacle distance_to_obstacle)
                             (* post_evade_distance_to_target post_evade_distance_to_target))
                          (* distance_to_target distance_to_target))
                       (* 2 distance_to_obstacle post_evade_distance_to_target))))))
  (rotate_to_face post_evade_angle_to_target)
  (setMotors -145 -150)
  (sleep (/ post_evade_distance_to_target distance_covered_per_second))
  (setMotors 0 0)
  )
;Rotate 62.2 degrees
(define (rotate_62.2)
  (setMotors 150 -150)
  (sleep 0.17277777791)
  (setMotors 0 0))
;finder===============================================================================================
;(define(the_loop)
;  (for* ([i (in-range 640)]
;         [j (in-range 480)])
;   (cond
;      ((equal? (color-red (get_pixel i j)) 255)
;       (set! target_xcord i)
;      (set! target_ycord j))
(define target_xcord 0)
(define target_ycord 0)
(define obstacle_xcord 0)
(define obstacle_ycord 0)
(define target_locator null)
(define obstacle_locator null)
(define target_degrees_to_rotate 0)
(define obstacle_degrees_to_rotate 0)
(define rotate_counter 0)
(define obstacle_present 0)
(define (finder)
  (set! target_locator (index-of (map (lambda (x) (and (> (color-red x) 200)
                                                       (< (color-blue x) 50)
                                                       (< (color-green x) 50))) processed_img) #t))
  (set! obstacle_locator (index-of (map (lambda (x) (and (> (color-green x) 150)
                                                         (< (color-blue x) 50)
                                                         (< (color-red x) 50))) processed_img) #t))
  (cond
    ((number? target_locator) (set! rotate_counter 0))
    (else
     (cond
       ((> rotate_counter 6) (setLCDMessage "Objective Absent" 1)))
     (rotate_62.2)
     (set! rotate_counter (+ rotate_counter 1))
     (click_and_process)
     (finder)))
  (set! target_ycord (floor (/ target_locator 640)))
  (set! target_xcord (- 1 (- (* target_ycord 640) target_locator)))
  (set! target_degrees_to_rotate (hori_angle target_xcord))
  (cond
    ((number? obstacle_locator)
     (set! obstacle_ycord (floor (/ obstacle_locator 640)))
     (set! obstacle_xcord (- 1 (- (* obstacle_ycord 640) obstacle_locator)))
     (set! obstacle_degrees_to_rotate (hori_angle obstacle_xcord))
     (set! obstacle_present 1))))
;distance between camera and object===================================================================
;distance to something
(define (distance_to_something x y)
  (/ (* focal_length x vertical_resolution) (* y sensor_height)));where x=real height of object
;and y=height of object inside the image, measured in number of pixels it occupies
;seconds to rotate to face the target
(define target_ycord_end null)
(define target_in_image_height 1)
(define distance_to_target 0)
;set to something that doesnt interfere with program
(define (target_distance_helper x y z) ;where x/y/z= color-green/color-red/color-blue
  (for ([i (in-range (+ target_ycord 1) 480)]
        #:break (< (color-red (get_pixel target_xcord i img)) 200))
    (cond
      ((and
        (> (x (get_pixel target_xcord i img)) 180)
        (< (y (get_pixel target_xcord i img)) 100)
        (< (z (get_pixel target_xcord i img)) 100))
       (set! target_ycord_end i))
      ))
  (printf "~a" target_ycord)
  (printf "~a" target_ycord_end)
  (set! target_in_image_height (- target_ycord_end target_ycord))
  (set! distance_to_target (distance_to_something target_height target_in_image_height)))
;time taken to cover distance to target
(define (time_to_cover_distance_to_target)
  (target_distance_helper color-red color-green color-blue)
  (/ distance_to_target distance_covered_per_second))
;Obstacle distance helper
(define obstacle_ycord_end null)
(define obstacle_in_image_height 1)
(define distance_to_obstacle 0)
;set to something that doesnt interfere with program
(define (obstacle_distance_helper x y z) ;where x/y/z= color-green/color-red/color-blue
  (for ([i (in-range (+ obstacle_ycord 1) 480)]
        #:break (< (x (get_pixel obstacle_xcord i img)) 200))
    (cond
      ((and
        (> (x (get_pixel obstacle_xcord i img)) 180)
        (< (y (get_pixel obstacle_xcord i img)) 100)
        (< (z (get_pixel obstacle_xcord i img)) 100))
       (set! obstacle_ycord_end i))
      ))
  (set! obstacle_in_image_height (- obstacle_ycord_end obstacle_ycord))
  (set! distance_to_obstacle (distance_to_something target_height target_in_image_height)))
;time taken to cover distance to obstacle
(define (time_to_cover_distance_to_obstacle)
  (obstacle_distance_helper color-green color-blue color-red)
  (/ distance_to_obstacle distance_covered_per_second))

  
;MAIN=================================================================================================
(define (main)
  (displayln "open-asip")
  (open-asip)
  (displayln "click and process")
  (click_and_process)
  (displayln "finder")
  (finder)
  (displayln "obstacle present/blocking?")
  (cond
    ((equal? obstacle_present 1)
     (obstacle_blocking?)
     (printf "~a\n" is_obstacle_blocking?)))
  (displayln "rotate to face target")
  (rotate_to_face target_degrees_to_rotate)
  (displayln "COND")
  (cond
    ((equal? is_obstacle_blocking? 1)
     (displayln "OBSTACLE IS BLOCKING")
     (set! obstacle_degrees_to_rotate (- obstacle_degrees_to_rotate target_degrees_to_rotate))
     (evade))
    (else
     (displayln "OBSTACLE IS NOT BLOCKING")
     (setMotors -145 -150)
     (printf "~a/n" (time_to_cover_distance_to_target))
     (sleep (time_to_cover_distance_to_target))
     (setMotors 0 0)))
  (close-asip)
  )
