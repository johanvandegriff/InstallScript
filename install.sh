#!/bin/bash

VERSION="1.1"

CHROME_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
ANDROID_STUDIO_URL="https://dl.google.com/dl/android/studio/ide-zips/3.0.1.0/android-studio-ide-171.4443003-linux.zip"
ARDUINO_URL="https://www.arduino.cc/download_handler.php?f=/arduino-1.8.5-linux64.tar.xz"
VIRTUALBOX_URL="https://download.virtualbox.org/virtualbox/5.2.6/virtualbox-5.2_5.2.6-120293~Ubuntu~xenial_amd64.deb"
NETHACK_FILE="nethack-360-src.tgz"
NETHACK_DIR="nethack-3.6.0"

#UTILITIES
#function for terminal colors that supports color names and nested colors
color() {
  color="$1"
  shift
  text="$@"
  case "$color" in
    # text attributes
#    end) num=0;;
    bold) num=1;;
    special) num=2;;
    italic) num=3;;
    underline|uline) num=4;;
    reverse|rev|reversed) num=7;;
    concealed) num=8;;
    strike|strikethrough) num=9;;
    # foreground colors
    black) num=30;;
    D_red) num=31;;
    D_green) num=32;;
    D_yellow) num=33;;
    D_orange) num=33;;
    D_blue) num=34;;
    D_magenta) num=35;;
    D_cyan) num=36;;
    gray) num=37;;
    D_gray) num=30;;
    red) num=31;;
    green) num=32;;
    yellow) num=33;;
    orange) num=33;;
    blue) num=34;;
    magenta) num=35;;
    cyan) num=36;;
    # background colors
    B_black) num=40;;
    BD_red) num=41;;
    BD_green) num=42;;
    BD_yellow) num=43;;
    BD_orange) num=43;;
    BD_blue) num=44;;
    BD_magenta) num=45;;
    BD_cyan) num=46;;
    BL_gray) num=47;;
    B_gray) num=5;;
    B_red) num=41;;
    B_green) num=42;;
    B_yellow) num=43;;
    B_orange) num=43;;
    B_blue) num=44;;
    B_magenta) num=45;;
    B_cyan) num=46;;
    B_white) num=47;;
#    +([0-9])) num="$color";;
#    [0-9]+) num="$color";;
    *) num="$color";;
#    *) echo "$text"
#       return;;
  esac


  mycode='\033['"$num"'m'
  text=$(echo "$text" | sed -e 's,\[0m,\[0m\\033\['"$num"'m,g')
  echo -e "$mycode$text\033[0m"
}

#display a message to stderr in bold red and exit with error status
error(){
  #bold red
  color bold `color red "$@"` 1>&2
  exit 1
}

#display a message to stderr in bold yellow
warning(){
  #bold yellow
  color bold `color yellow "$@"` 1>&2
}

#a yes or no prompt
yes_or_no(){
  prompt="$@ [y/n]"
  answer=
  while [[ -z "$answer" ]] #repeat until a valid answer is given
  do
    read -p "$prompt" -n 1 response #read 1 char
    case "$response" in
      y|Y)answer=y;;
      n|N)answer=n;;
      *)color yellow "
Enter y or n.";;
    esac
  done
  echo
}

#settings for apt-get to automatically answer yes
my_apt-get(){
  #DEBIAN_FRONTEND disables interactive mode
  DEBIAN_FRONTEND=noninteractive apt-get --yes --force-yes $@
}

#manage the errors of apt-get install
my_install(){
  my_apt-get install $@ || error "Error installing $@"
}

#manage the errors of cp
my_cp(){
  destination="$1"
  source=`basename "$1"`
  cp "$source" "$destination" || error "Error writing to $destination"
}

#manage the errors of mkdir
my_mkdir(){
  dir="$1"
  if [[ -d "$dir" ]]
  then
    warning "$dir already exists!"
  else
    mkdir "$dir" || error "Error creating $dir"
  fi
}

#display a message before rebooting
my_reboot(){
  if [[ -f auto_rerun ]]
  then
    enable_auto_rerun
  else
    echo "Press ENTER to reboot. When the computer boots up, log in and run this script again."
  fi
  color magenta "Rebooting..."
  reboot
}

#Write text to a file. Exit with an error if it fails.
write_text_to_file(){
  content="$1"
  file="$2"
  color magenta "Overwriting $file"
  echo "$content" > "$file" || error "Error writing to $file"
}

#Append to a file. Exit with an error if it fails.
append_text_to_file(){
  content="$1"
  file="$2"
  color magenta "Modifying $file"
  echo "$content" >> "$file" || error "Error writing to $file"
}

#mark an item in file
mark(){
  filename="$1"
  shift
  item="$@"
  if ! check "$filename" "$item"
  then
    append_text_to_file "$item" "$filename"
  fi
}

#find out if an item is in the file
check(){
  filename="$1"
  shift
  grep "^$@$" "$filename" > /dev/null
}

mark_as_done(){
  item="$@"
  if ! is_done "$item"
  then
    append_text_to_file "$item" "$DONE"
    num_done=`cat "$DONE" | sort -u | wc -l`
    num_skipped=`cat "$SKIP" | sort -u | wc -l`
    total=$((NUM_MODULES - num_skipped))
    color green "Step $num_done/$total ($item) done!"
  fi
}

is_done(){
  check "$DONE" "$@"
}

mark_as_skipped(){
  mark "$SKIP" "$@"
}

is_skipped(){
  check "$SKIP" "$@"
}

declare -A desc
declare -A depend

MODULES=
ASK=
NUM_MODULES=0

register_module(){
  module="$1"
  description="$2"
  MODULES="$MODULES $module"
  desc["$module"]="$description"
  if echo "$module" | grep '[[:space:]]' > /dev/null
  then
    warning "Warning: whitespace in module \"$module\" may cause installation to fail."
  fi

  while [[ ! -z "$3" ]]
  do
    case "$3" in
         -a|--ask)ASK="$ASK $module";;
      -d|--depend)depend["$module"]="${depend[$module]} $4"
                  shift;;
                *)warning "register_module: unrecognised option \"$3\"";;
    esac
    shift
  done
  NUM_MODULES=$((NUM_MODULES + 1))
}

SKIP=skip.txt
install_modules(){
  if [[ ! -f "$SKIP" ]]
  then
    > "$SKIP"
    for module in $ASK
    do
      yes_or_no "Install module \"$module\" (${desc[$module]})?"
      [[ "$answer" == n ]] && mark_as_skipped "$module"
    done

    for module in $MODULES
    do
      if ! is_skipped "$module"
      then
        missing=
        for dependency in ${depend[$module]}
        do
          if is_skipped "$dependency"
          then
            missing="$missing $dependency"
          fi
        done
        if [[ ! -z "$missing" ]]
        then
          warning "Dependencies missing for module $module:$missing"
          warning "Disabling $module"
          mark_as_skipped "$module"
        fi
      fi
    done
  fi

  for module in $MODULES
  do
    if is_done "$module"
    then
      color green "$module is done."
    elif is_skipped "$module"
    then
      color yellow "$module has been disabled."
    else
      color yellow "$module is NOT done."
      REBOOT=no
      "$module" && mark_as_done "$module" #run the module
      [[ "$REBOOT" == "yes" ]] && my_reboot
    fi
  done
  color bold `color green "All steps complete!"`
}

register_module basic "basic packages" --ask
basic() {
    color green "Installing basic packages.."
    my_install vlc git xautomation devede sqliteman python-pip python3-pip winff mencoder alien checkinstall gpaco meld gparted testdisk smartmontools gsmartcontrol gnome-multi-writer clonezilla conky htop deluge w3m keepassx wipe pwgen pv tmux zsh ncdu powertop powerstat wcalc hardinfo xclip fortune-mod gtkhash i7z 
}

register_module i3 "tiling window manger" --ask
i3() {
    color green "Installing i3..."
    my_install i3 i3status feh dmenu rofi compton i3lock
}

register_module spotify "music streaming" --ask
spotify() {
    color green "Installing spotify..."
    my_install spotify
}

VIRTUALIZATION_PACKAGES="qemu wine playonlinux dosbox mednafen stella"
register_module virtualization "$VIRTUALIZATION_PACKAGES" --ask
virtualization() {
    color green "Installing $VIRTUALIZATION..."
    my_install $VIRTUALIZATION_PACKAGES
}

register_module clear_bloat "programs to find extraneous files" --ask
clear_bloat() {
    color green "Installing ..."
    my_install gtkorphan bleachbit fslint fdupes packagesearch
}

register_module games "supertux (platformer) and supertuxkart (racing)" --ask
games() {
    color green "Installing supertux and supertuxcart..."
    my_install supertux supertuxkart
}

register_module science "chemistry and astronomy programs" --ask
science() {
    color green "Installing stellarium gelemental avogadro..."
    my_install stellarium gelemental avogadro
}

register_module cad "computer aided design" --ask
cad() {
    color green "Installing blender freecad eagle..."
    my_install blender freecad eagle
}

register_module pdf "tools to manipulate pdf files" --ask
pdf() {
    color green "Installing pdf manipulation tools..."
    my_install scribus pdfshuffler pdfmod pdfsam pdfchain pdftk pdfcrack pdfgrep
}

register_module Bible "xiphos Bible database" --ask
Bible() {
    color green "Installing xiphos..."
    my_install xiphos
}

register_module bacakgrounds "extra bacakgrounds for Linux Mint" --ask
backgrounds() {
    color green "Installing ..."
    my_install mint-backgrounds-maya mint-backgrounds-nadia mint-backgrounds-olivia \
    mint-backgrounds-petra mint-backgrounds-qiana mint-backgrounds-rafaela \
    mint-backgrounds-rebecca mint-backgrounds-retro mint-backgrounds-rosa \
    mint-backgrounds-sarah mint-backgrounds-serena mint-backgrounds-sonya \
    mint-backgrounds-sylvia mint-backgrounds-xfce
}

register_module cool-retro-term "retro terminal emulator" --ask
cool-retro-term() {
    color green "adding repositories"
    sudo add-apt-repository -y ppa:noobslab/apps || error "Error adding ppa repository"
    sudo apt-get update || error "Error with apt-get update"
    color green "Installing cool-retro-term..."
    my_install cool-retro-term qml-module-qt-labs-folderlistmodel qml-module-qt-labs-settings
}

register_module oh-my-zsh "themes and fancy options manager for zsh" --ask
oh-my-zsh() {
    color green "Installing zsh..."
    my_install zsh
    color green "Installing oh-my-zsh..."
    sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)" || error "Error installing oh-my-zsh"
}

register_module eclipse "ide for java and other languages" --ask
eclipse() {
    color green "Installing eclipse.."
    my_install eclipse
}

EDITING_PACKAGES="audacity lmms kdenlive openshot kazam inkscape kolourpaint"
register_module editing "$EDITING_PACKAGES" --ask
editing() {
    color green "Installing $EDITING_PACKAGES.."
    my_install audacity lmms kdenlive kazam inkscape kolourpaint4
}

#Tilp and Tilem
register_module emulator "tilp (Ti Calculator Linking Program) and tilem (Ti Calculator Emulator)" --ask
emulator(){
    color green "Installing tilp and tilem.."
    my_install tilp2 tilem
}

register_module virtualbox "general-purpose full virtualizer" --ask
virtualbox(){
    color green "Downloading virtualbox.."
    wget "$VIRTUALBOX_URL" || error "Error downloading virtualbox"
    dpkg -i `basename "$VIRTUALBOX_URL"` || error "Error installing virtualbox"
}

#http://jes.st/2015/compiling-playing-nethack-360-on-ubuntu/
register_module nethack "(version 3.6.0) dungeon crawler roguelike game" --ask
nethack() {
    color green "Installing dependencies.."
    my_install flex bison build-essential libncurses5-dev checkinstall
    if [[ -d "$NETHACK_DIR" ]]
    then
	color yellow "Deleting old source folder.."
	rm -r "$NETHACK_DIR"
    fi
    test -f "$NETHACK_FILE" || error "$NETHACK_FILE not found"
    color green "Extracting source..."
    tar xpvzf "$NETHACK_FILE" | awk '{printf "."}END{print ".done"}' || error "Error extracting source"
    color green "Modifying settings files.."
    cat "$NETHACK_DIR"/include/unixconf.h | sed 's,/\* #define LINUX \*/,#define LINUX,g' > tmp || error "Error modifying include/unixconf.h"
    mv tmp "$NETHACK_DIR"/include/unixconf.h || error "Error modifying include/unixconf.h"
    cat <<\EOF > "$NETHACK_DIR"/sys/unix/hints/linux || error "Error modifying $NETHACK_DIR/sys/unix/hints/linux"
#
# NetHack 3.6  linux $NHDT-Date: 1432512814 2015/05/25 00:13:34 $  $NHDT-Branch: master $:$NHDT-Revision: 1.12 $
# Copyright (c) Kenneth Lorber, Kensington, Maryland, 2007.
# NetHack may be freely redistributed.  See license for details. 
#
#-PRE
# Linux hints file
# This hints file provides a single-user tty build for Linux, specifically
# for Ubuntu dapper.

# install in the global folder, not a user folder
PREFIX=/usr
#PREFIX=$(wildcard ~)/nh/install
HACKDIR=$(PREFIX)/games/lib/$(GAME)dir
SHELLDIR = $(PREFIX)/games
INSTDIR=$(HACKDIR)
# a better location for game files
VARDIR = /var/games/nethack
# the global config file
SYSCONFFILE=/etc/nethackrc
# Ubuntu's group for games
GAMEGRP=games

# permissions on config file
POSTINSTALL=cp -n sys/unix/sysconf $(SYSCONFFILE); $(CHOWN) $(GAMEUID) $(SYSCONFFILE); $(CHGRP) $(GAMEGRP) $(SYSCONFFILE); chmod $(VARFILEPERM) $(SYSCONFFILE);

CFLAGS=-g -O -I../include -DNOTPARMDECL $(CFLAGS1) -DDLB
CFLAGS1=-DCOMPRESS=\"/bin/gzip\" -DCOMPRESS_EXTENSION=\".gz\"
# Point to the correct config file
CFLAGS+=-DSYSCF -DSYSCF_FILE=\"$(SYSCONFFILE)\" -DSECURE
CFLAGS+=-DHACKDIR=\"$(HACKDIR)\"
# tell nethack where the game files are
CFLAGS+=-DVAR_PLAYGROUND=\"$(VARDIR)\"

LINK=$(CC)
# Only needed for GLIBC stack trace:
LFLAGS=-rdynamic

WINSRC = $(WINTTYSRC)
WINOBJ = $(WINTTYOBJ)
WINLIB = $(WINTTYLIB)

# use ncurses
WINTTYLIB=-lncurses

# actually execute the chown
CHOWN=chown
# actually execute the chgrp
CHGRP=chgrp

VARDIRPERM = 0777
VARFILEPERM = 0777
GAMEPERM = 0777
EOF
    cat "$NETHACK_DIR"/include/config.h | sed 's,/\* #define STATUS_VIA_WINDOWPORT \*/,#define STATUS_VIA_WINDOWPORT,g' | sed 's,/\* #define STATUS_HILITES \*/,#define STATUS_HILITES,g' > tmp || error "Error modifying include/config.h"
    mv tmp "$NETHACK_DIR"/include/config.h || error "Error modifying include/config.h"
    cd "$NETHACK_DIR" || error "Error entering $NETHACK_DIR"
    color green "Running setup.."
    sh ./sys/unix/setup.sh sys/unix/hints/linux || error "Error running setup"
    color green "Running make.."
    make all || error "Error running make"
    color green "Running checkinstall.."
    echo "y
nethack 3.6.0

12
nethack-common

n
y
" | sudo checkinstall || error "Error running checkinstall"
    cd ..
}

register_module arduino_ide "editor for adruino microcontroller" --ask
arduino_ide(){
    ARDUINO_FILE=`basename "$ARDUINO_URL"`
    ARDUINO_DIR=`echo "$ARDUINO_FILE" | cut -f1-2 -d-`
    test -f "$ARDUINO_FILE" && mv "$ARDUINO_FILE" "${ARDUINO_FILE}.old"  
    wget "$ARDUINO_URL" -O "$ARDUINO_FILE" || error "Error downloading arduino"
    if [[ ! -d "$USER_HOME"/Apps ]]
    then
	color green "creating $USER_HOME/Apps"
	mkdir "$USER_HOME"/Apps
    fi
    color green "Unzipping arduino.."
    tar xvpaf "$ARDUINO_FILE" | awk '{printf "."}END{print ".done"}' || error "Error unzipping arduino"
    color green "Moving arduino to $USER_HOME/Apps.."
    mv "$ARDUINO_DIR" "$USER_HOME"/Apps || error "Error moving arduino to $USER_HOME/apps"
    color green "Creating desktop launcher.."
    cat <<EOF "$USER_HOME"/.local/share/applications/arduino.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Arduino
Exec=$USER_HOME/Apps/$ARDUINO_DIR/arduino
Icon=$USER_HOME/Apps/$ARDUINO_DIR/lib/arduino_icon.ico
Categories=Development;IDE;
Terminal=false
StartupNotify=true
StartupWMClass=arduino
EOF
}

register_module android_studio "(version 3.0.1) editor for android apps" --ask
android_studio(){
    color green "Installing unzip.."
    my_install unzip
    test -f "$ANDROID_STUDIO_FILE" && mv "$ANDROID_STUDIO_FILE" "${ANDROID_STUDIO_FILE}.old"
    color green "Downloading Android Studio.."
    wget "$ANDROID_STUDIO_URL" || error "Error downloading android studio"
    color green "Installing Android Studio.."
    sudo unzip `basename "$ANDROID_STUDIO_URL"` -d /opt || error "Error unzipping android studio"
    color green "Creating desktop launcher.."
    cat <<EOF "$USER_HOME"/.local/share/applications/androidstudio.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Exec="/opt/android-studio/bin/studio.sh" %f
Icon=/opt/android-studio/bin/studio.png
Categories=Development;IDE;
Terminal=false
StartupNotify=true
StartupWMClass=android-studio
EOF
}

register_module chrome "google chrome web browser" --ask
chrome(){
    CHROME_FILE=`basename "$CHROME_URL"`
    color green "Installing dependencies.."
    my_install libappindicator1 libindicator7
    test -f "$CHROME_FILE" && mv "$CHROME_FILE" "${CHROME_FILE}.old"
    color green "Downloading Google Chrome.."
    wget "$CHROME_URL" || error "Error downloading chrome"
    color green "Installing Google Chrome.."
    sudo dpkg -i "$CHROME_FILE" || error "Error installing chrome"
}

#register_module  "" --ask
#() {
#    color green "Installing ..."
#    my_install 
#}

#try to connect to the internet
test_internet(){
    wget -q --tries=10 --timeout=20 --spider http://example.com
}

############################
# main part of the program #
############################

color green "Welcome to Johan's custom install script version $VERSION"

#if not run as root, do not run
if [ $(id -u) -ne 0 ]
then
    error "Script must be run as root. Try 'sudo $0'"
fi

USER_HOME=`eval echo ~$SUDO_USER` #the home dir of the user who ran this script with sudo
USER_BIN="$USER_HOME"/bin/ #the user's ~/bin directory
PROFILE="$USER_HOME"/.profile #the user's .profile file

#if YOUR_NAME was not set by the auto run at login
if [[ -z "$YOUR_NAME" ]]
then
    #find the absolute path to this script
    cd `dirname $0`
    me=`pwd`/`basename $0`
else
    #take YOUR_NAME to be the absolute path to this script
    cd `dirname $YOUR_NAME`
    me="$YOUR_NAME"
fi

DONE=done.txt #the file that contains which modules are done
[[ ! -f "$DONE" ]] && > "$DONE"

#test the internet
if ! test_internet
then
    warning "Not connected to the internet. Waiting 10 seconds to try again."
    sleep 10
fi

if test_internet
then
    color green "You are connected to the internet."
else
    color yellow "You are NOT connected to the internet."
fi

sudo my_apt-get update
#go through each module and run it if it is not done/skipped
install_modules
