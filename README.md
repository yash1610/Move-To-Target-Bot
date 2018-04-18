# Move To Target Bot

Built on top of the MIRTO Platform, with an added Raspberry Pi v2 Camera for target/obstacle detection.

It requires `Open-Asip` (https://github.com/mdxmase/asip) and `2HTDP/images` for functioning.

While the computer vision parts could have been done in a language better suited to it I chose to use racket regardless. My professor did suggest using the openCV library to do the detection part, while that would have been a miles better solution than my hacky one, I decided to go ahead with my hacky-one to learn more about the basics of computer vision.

The program is split into multiple functions for easier upgrades and extensions, and while the functions do basic tasks. Their uses could be many. 

For example the Distance to Target/Obstacle function could be extractred and used with a database of lens specifications for latest phones and a coin to find out the distance from the camera to the coin (the coin being a placeholder for the postion you want the distance for) without relying on a depth sensor or a second camera to do so.

Another function, the Finder can be used to locate a certain color in an image, while this is all it does in the current iteration of the program, combined with another function that finds the in-image height of the object (distance_helper) this function can further be extended to detect shapes comprised of a single color. I have a working prototype of this sape deteciton function although I chose not to use it as the project end-date drew near. Although I do hope to add it in the coming months.

## Program Flow

1. `open-asip` (provided by AsipMain.rkt in Open-asip): is called to open connection with the arduino layer of the MIRTO Bot
2. `click_and_process`: uses a system call to raspistill to take an image and save it. The saved image is then loaded into the program using bitmap/file (provided by 2htdp/image), the image is then processed into a list of pixels with their color values [eg (color 255 255 255 255)]
3. `Finder`: Uses get_pixel, which queries color values from the processed list generated in the click_and_process function. When the queried pixel is equal to a certain color it is saved into a variable and used as a base point. This function is also responsible for searching for the obstacle (if one exists). For now, it only works with 0 or 1 obstacle. This limitation exists because of the way, the program searches for the target or the obstacle.
If the target is not found the function rotates the bot by an angle equal to the field of view of the camera in a clockwise direction, and then goes back to "2." `click_and_process` to start the process again until it either finds the target or the robot has done a full 360 degree rotation
4. `obstacle_blocking?`: This function is only called if an obstacle is present. It checks if the obstacle is blocking the patch to the target, if it is then it raises a flag.
5.  `rotate_to_face`: is called to roate the MIRTO Bot to face the target regardless if the path is blocked or not
6. Depending on if a flag was raised by `obstacle_blocking?` one of two things happen either the `evade` function is called or the bot moves in a straight line to the target
