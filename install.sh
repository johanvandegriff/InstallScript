#!/bin/bash
VERSION="1.2"

CHROME_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
ANDROID_STUDIO_URL="https://dl.google.com/dl/android/studio/ide-zips/3.0.1.0/android-studio-ide-171.4443003-linux.zip"
#ARDUINO_URL="https://www.arduino.cc/download_handler.php?f=/arduino-1.8.5-linux64.tar.xz"
VIRTUALBOX_URL="https://download.virtualbox.org/virtualbox/5.2.6/virtualbox-5.2_5.2.6-120293~Ubuntu~xenial_amd64.deb"
MULTIBOOTUSB_URL="https://github.com/mbusb/multibootusb/releases/download/v9.1.0/python3-multibootusb_9.1.0-1_all.deb"
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
#        end) num=0;;
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
#        +([0-9])) num="$color";;
#        [0-9]+) num="$color";;
        *) num="$color";;
#        *) echo "$text"
#             return;;
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

#manage the errors of apt-get install
my_install(){
    #DEBIAN_FRONTEND disables interactive mode
    DEBIAN_FRONTEND=noninteractive apt-get --yes --force-yes install $@ || error "Error installing $@"
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

#change a file or files to be owned by the user that ran this script as sudo
my_chown(){
    chown "$USER_NAME:$USER_NAME" $@
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
	my_chown "$SKIP" || error "Error changing ownership of $SKIP"
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

###########
# modules #
###########

register_module apt_update "update package lists from software repositories"
apt_update() {
    DEBIAN_FRONTEND=noninteractive apt-get --yes --force-yes update
}

register_module basic "basic packages" --ask
basic() {
    color green "Installing basic packages.."
    my_install vlc git xautomation devede python3-pip winff mencoder alien checkinstall gpaco meld gparted testdisk smartmontools gsmartcontrol gnome-multi-writer clonezilla conky htop deluge w3m keepassx wipe pwgen pv tmux zsh ncdu powertop powerstat wcalc hardinfo xclip fortune-mod gtkhash i7z catfish gnome-system-monitor
}

register_module timeshift "backup and restore the system" --ask
timeshift(){
    add-apt-repository -y ppa:teejee2008/ppa || \
    echo "deb http://ppa.launchpad.net/teejee2008/ppa/ubuntu xenial main
deb-src http://ppa.launchpad.net/teejee2008/ppa/ubuntu xenial main" > /etc/apt/sources.list.d/teejee2008-ppa-xenial.list || error "Error adding ppa repository"
    apt_update
    my_install timeshift
}

register_module i3 "tiling window manger" --ask
i3() {
    color green "Installing i3..."
    my_install i3 i3status feh dmenu rofi compton i3lock
}

register_module clear_bloat "programs to find extraneous files" --ask
clear_bloat() {
    color green "Installing ..."
    my_install bleachbit fdupes packagesearch
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
    color green "Installing blender freecad..."
    my_install blender freecad
}

register_module pdf "tools to manipulate pdf files" --ask
pdf() {
    color green "Installing pdf manipulation tools..."
    my_install scribus pdfshuffler pdfmod pdfsam pdfchain pdftk pdfcrack pdfgrep
}

register_module Bible "BibleTime" --ask
Bible() {
    color green "Installing BibleTime..."
    my_install bibletime
}

register_module emacs "complex text editor with keyboard shortcuts" --ask
emacs(){
    color green "Installing emacs..."
    my_install emacs
}

register_module multibootusb "app that puts multiple bootable iso's on 1 USB drive" --ask
multibootusb(){
    MULTIBOOTUSB_FILE=`basename "$MULTIBOOTUSB_URL"`
    test -f "$MULTIBOOTUSB_FILE" && mv "$MULTIBOOTUSB_FILE" "${MULTIBOOTUSB_FILE}.old"
    color green "Downloading multibootusb.."
    wget "$MULTIBOOTUSB_URL" || error "Error downloading multibootusb"
    dpkg -i "$MULTIBOOTUSB_FILE" || sudo apt-get -fy install || error "Error installing multibootusb"
}

register_module backgrounds "extra backgrounds for Linux Mint" --ask
backgrounds() {
    color green "Installing ..."
    my_install mint-backgrounds-maya mint-backgrounds-nadia mint-backgrounds-olivia \
    mint-backgrounds-petra mint-backgrounds-qiana mint-backgrounds-rafaela \
    mint-backgrounds-rebecca mint-backgrounds-retro mint-backgrounds-rosa \
    mint-backgrounds-sarah mint-backgrounds-serena mint-backgrounds-sonya \
    mint-backgrounds-sylvia
}

#register_module cool-retro-term "retro terminal emulator" --ask
#cool-retro-term() {
#    color green "adding repositories"
#    add-apt-repository -y ppa:noobslab/apps || \
#    echo "deb http://ppa.launchpad.net/noobslab/apps/ubuntu xenial main
#deb-src http://ppa.launchpad.net/noobslab/apps/ubuntu xenial main" > /etc/apt/sources.list.d/noobslab-apps-xenial.list || error "Error adding ppa repository"
#    apt-get update || error "Error with apt-get update"
#    color green "Installing cool-retro-term..."
#    my_install cool-retro-term qml-module-qt-labs-folderlistmodel qml-module-qt-labs-settings
#}

register_module oh-my-zsh "themes and fancy options manager for zsh" --ask
oh-my-zsh() {
    color green "Installing zsh..."
    my_install zsh
    color green "Installing oh-my-zsh..."
    sudo -u "$USER_NAME" sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O - | grep -v 'env zsh') --unattended" || error "Error installing oh-my-zsh"
    sudo chsh "$USER_NAME" -s `which zsh`
    my_chown -R "$USER_HOME/.zshrc" "$USER_HOME/.oh-my-zsh" || error "Error changing ownership of zsh files."
}

#register_module eclipse "ide for java and other languages" --ask
#eclipse() {
#    color green "Installing eclipse.."
#    my_install eclipse
#}

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
    VIRTUALBOX_FILE=`basename "$VIRTUALBOX_URL"`
    test -f "$VIRTUALBOX_FILE" && mv "$VIRTUALBOX_FILE" "${VIRTUALBOX_FILE}.old"
    color green "Downloading virtualbox.."
    wget "$VIRTUALBOX_URL" || error "Error downloading virtualbox"
    dpkg -i "$VIRTUALBOX_FILE" || sudo apt-get -fy install || error "Error installing virtualbox"
    groupadd vboxusers || warning "vboxusers already exists"
    usermod -a -G vboxusers "$USER_NAME" || error "Error adding user to group 'vboxusers' to enable USB support"
}

VIRTUALIZATION_PACKAGES="qemu wine-development playonlinux dosbox mednafen stella"
register_module virtualization "$VIRTUALIZATION_PACKAGES" --ask
virtualization() {
    color green "Installing $VIRTUALIZATION..."
    my_install $VIRTUALIZATION_PACKAGES
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
    test -f "$NETHACK_FILE" || error "$NETHACK_FILE not found. Download the nethack sources version 3.6.0 from nethack.org/v360/download-src.html and place it in the folder: $CURRENT_DIR"
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
" | checkinstall || error "Error running checkinstall"
    cd ..
}

register_module arduino_ide "editor for adruino microcontroller" --ask
arduino_ide(){
    #ARDUINO_FILE=`basename "$ARDUINO_URL"`
    ARDUINO_FILE=`ls -1 arduino-* | head -1`
    ARDUINO_DIR=`echo "$ARDUINO_FILE" | cut -f1-2 -d-`
    test -f "$ARDUINO_FILE" || error "Arduino IDE archive not found. Download the latest Arduino IDE from arduino.cc and place it in the folder: $CURRENT_DIR"
    #test -f "$ARDUINO_FILE" && mv "$ARDUINO_FILE" "${ARDUINO_FILE}.old"  
    #wget "$ARDUINO_URL" -O "$ARDUINO_FILE" || error "Error downloading arduino"
    if [[ ! -d "$USER_HOME"/Apps ]]
    then
	color green "creating $USER_HOME/Apps"
	mkdir "$USER_HOME/Apps"
    fi
    if [[ -d "$ARDUINO_DIR" ]]
    then
	color yellow "Deleting old $ARDUINO_DIR folder.."
	rm -r "$ARDUINO_DIR"
    fi
    color green "Unzipping arduino.."
    tar xvpaf "$ARDUINO_FILE" | awk '{printf "."}END{print ".done"}' || error "Error unzipping arduino"
    if [[ -d "$USER_HOME/Apps/$ARDUINO_DIR" ]]
    then
	color yellow "Deleting old $USER_HOME/Apps/$ARDUINO_DIR folder.."
	rm -r "$USER_HOME/Apps/$ARDUINO_DIR"
    fi
    color green "Moving arduino to $USER_HOME/Apps.."
    mv "$ARDUINO_DIR" "$USER_HOME/Apps" || error "Error moving arduino to $USER_HOME/Apps"
    my_chown -R "$USER_HOME/Apps" || error "Error changing ownership of $USER_HOME/Apps"
    color green "Creating desktop launcher.."
    mkdir -p "$USER_HOME/.local/share/applications"
    my_chown "$USER_HOME/.local/share/applications" || error "Error changing ownership of $USER_HOME/.local/share/applications"
    LAUNCHER="$USER_HOME/.local/share/applications/arduino.desktop"
    cat <<EOF > "$LAUNCHER"
[Desktop Entry]
Version=1.0
Type=Application
Name=Arduino
Terminal=false
Exec=$USER_HOME/Apps/$ARDUINO_DIR/arduino
Icon=$USER_HOME/Apps/$ARDUINO_DIR/lib/arduino_icon.ico
Categories=Development;IDE;
StartupNotify=true
StartupWMClass=arduino
EOF
    my_chown "$LAUNCHER" || error "Error changing ownership of $LAUNCHER"
}

register_module android_studio "(version 3.0.1) editor for android apps" --ask
android_studio(){
    color green "Installing unzip.."
    my_install unzip
    if [[ -d /opt/android-studio ]]
    then
	color green "Android Studio already installed in /opt/android-studio"
    else
        test -f "$ANDROID_STUDIO_FILE" && mv "$ANDROID_STUDIO_FILE" "${ANDROID_STUDIO_FILE}.old"
        color green "Downloading Android Studio.."
        wget "$ANDROID_STUDIO_URL" || error "Error downloading android studio"
        color green "Installing Android Studio.."
        unzip `basename "$ANDROID_STUDIO_URL" | sed 's/.zip$//'` -d /opt || error "Error unzipping android studio"
        color green "Creating desktop launcher.."
        mkdir -p "$USER_HOME/.local/share/applications"
        my_chown "$USER_HOME/.local/share/applications" || error "Error changing ownership of $USER_HOME/.local/share/applications"
        LAUNCHER="$USER_HOME/.local/share/applications/androidstudio.desktop"
        cat <<EOF > "$LAUNCHER"
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Terminal=false
Exec="/opt/android-studio/bin/studio.sh" %f
Icon=/opt/android-studio/bin/studio.png
Categories=Development;IDE;
StartupNotify=true
StartupWMClass=android-studio
EOF
        my_chown "$LAUNCHER" || error "Error changing ownership of $LAUNCHER"
    fi
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
    dpkg -i "$CHROME_FILE" || error "Error installing chrome"
}

#register_module  "" --ask
#() {
#    color green "Installing ..."
#    my_install 
#}

register_module apt_autoremove "remove unnecessary packages"
apt_autoremove(){
    DEBIAN_FRONTEND=noninteractive apt-get --yes --force-yes autoremove
}

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

CURRENT_DIR=$(readlink -f $(dirname "$0")) #absolute path to the dir the script is in
USER_NAME=`who | awk '{print $1}' | head -1`
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
if [[ ! -f "$DONE" ]]
then
    > "$DONE"
    my_chown "$DONE" || error "Error changing ownership of $DONE"
fi

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

#go through each module and run it if it is not done/skipped
install_modules
