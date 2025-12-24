#!/bin/bash

# xenon-os: 03_gnome_desktop.sh
# Automated "God Tier" GNOME Customization
# Author: omdhage04

echo ">> STARTING GOD TIER GNOME SETUP..."

# 1. Update & Install Base Tools
echo ">> Installing dependencies..."
sudo apt update
sudo apt install -y git curl zsh gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager dconf-editor pipx python3-pip fonts-firacode

# 2. Install 'gnome-extensions-cli' to automate extension installation
echo ">> Installing Extension Installer..."
pipx install gnome-extensions-cli --system-site-packages
pipx ensurepath

# 3. Install Themes (Orchis Dark)
echo ">> Installing Orchis Theme..."
if [ ! -d "Orchis-theme" ]; then
    git clone https://github.com/vinceliuice/Orchis-theme.git
    cd Orchis-theme
    ./install.sh -t all -c dark --tweaks solid compact black
    cd ..
    rm -rf Orchis-theme
fi

# 4. Install Icons (Tela Circle)
echo ">> Installing Tela Circle Icons..."
if [ ! -d "Tela-circle-icon-theme" ]; then
    git clone https://github.com/vinceliuice/Tela-circle-icon-theme.git
    cd Tela-circle-icon-theme
    ./install.sh -c blue
    cd ..
    rm -rf Tela-circle-icon-theme
fi

# 5. Install The "God Tier" Extensions
echo ">> Installing Extensions..."
# User Themes (Required for Shell theme)
gext install user-theme@gnome-shell-extensions.gcampax.github.com
# Dash to Panel (The Windows Bar)
gext install dash-to-panel@jderose9.github.io
# ArcMenu (The Start Menu)
gext install arc-menu@linxgem33.com
# Blur My Shell (The Glass Effect)
gext install blur-my-shell@aunetx
# Burn My Windows (The Cool Animations)
gext install burn-my-windows@schneegans.github.com
# Gesture Improvements (Windows 11 Gestures)
gext install gestureImprovements@gestureImprovements.com

# 6. Apply The Visual Settings (Activating the Theme)
echo ">> Applying Themes..."
gsettings set org.gnome.desktop.interface gtk-theme "Orchis-Dark-Compact"
gsettings set org.gnome.desktop.interface icon-theme "Tela-circle-blue-dark"
gsettings set org.gnome.shell.extensions.user-theme name "Orchis-Dark-Compact"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# 7. Install Nerd Fonts (For the Terminal)
echo ">> Installing Meslo Nerd Font..."
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLo "MesloLGS NF Regular.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
curl -fLo "MesloLGS NF Bold.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
curl -fLo "MesloLGS NF Italic.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
fc-cache -f -v
cd -

# 8. Install Oh My Zsh & Powerlevel10k
echo ">> Installing Zsh & Powerlevel10k..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# Set Zsh theme in .zshrc
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

echo ">> DONE! Please restart your session (Log out & Log in) to see changes."
