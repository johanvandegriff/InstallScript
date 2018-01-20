# Instructions
1. Clone or download the script
2. If you want to install the Arduino IDE, download the latest archive from https://www.arduino.cc/en/Main/Software and place it in the same folder as install.sh
3. If you want to install nethack 3.6.0, download the sources at https://nethack.org/v360/download-src.html and place it in the same folder as install.sh
4. Mark the script as executable: `chmod u+x install.sh`
5. Run the script as root: `sudo ./install.sh`
6. It will go through different "modules" and ask you if you want to install them. then it will install all of the requested modules, requiring no additional input unless there are errors.

# Modules
The script lets you choose which modules you want to install, and if you want only part of a module, you could modify the script before running it and remove what you don't want.
* basic list of packages I always end up installing
* i3 and related packages
* programs to clear extraneous files
* supertux and supertuxkart
* night sky simulation and chemistry applications
* blender, freecad, and eagle
* pdf manipulation
* database of different Bible translations
* emacs
* Linux Mint Backgrounds
* retro terminal emulator
* oh-my-zsh
* eclipse
* video, audio, and image editing
* Ti calculator emulators
* virtualbox
* QEMU, wine, and other emulators or not-an-emulators, as the case may be
* nethack 3.6.0
* arduino IDE
* android studio
* google chrome

# Tested Distros
* Linux Mint
* Linux Lite

Feel free to test it on other system and let me know if it works!

# Guides Followed
* To install nethack 3.6.0, I followed http://jes.st/2015/compiling-playing-nethack-360-on-ubuntu/ and automated the entire process.
