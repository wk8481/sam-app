#!/bin/bash

# Cloud9 Bootstrap Script
#
# Testing on Amazon Linux 2
#
# 1. Installs homebrew
# 2. Upgrades to latest AWS CLI
# 3. Upgrades AWS SAM CLI
#
# Usually takes about 8 minutes to complete

set -euxo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SAM_INSTALL_DIR="sam-installation"

function _logger() {
    echo -e "$(date) ${YELLOW}[*] $@ ${NC}"
}

function update_system() {
    _logger "[+] Updating system packages"
    sudo pacman -Syu --noconfirm  # Replacing yum with pacman
}

function update_python_packages() {
    _logger "[+] Upgrading Python pip and setuptools"
    python3 -m pip install --upgrade pip setuptools --user

    _logger "[+] Installing latest AWS CLI"
    python3 -m pip install --upgrade --user awscli
    if [[ -f /usr/bin/aws ]]; then
        sudo rm -rf /usr/bin/aws*
    fi
}

function install_pyenv() {
    sudo pacman -S --noconfirm base-devel openssl zlib bzip2 libffi  # Replacing yum with pacman
    curl https://pyenv.run | bash
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc

    CPPFLAGS="$(pkg-config --cflags openssl11)" \
    LDFLAGS="$(pkg-config --libs openssl11)" \
    pyenv install -v 3.10.11
}

function install_utility_tools() {
    _logger "[+] Installing jq"
    sudo pacman -S --noconfirm jq  # Replacing yum with pacman
}

function upgrade_sam_cli() {
    if [[ ! -f aws-sam-cli-linux-x86_64.zip ]]; then
        _logger "[+] Dowloading latest SAM version"
        curl -Ls -O https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
    fi

    if [[ ! -d $SAM_INSTALL_DIR ]]; then
        unzip aws-sam-cli-linux-x86_64.zip -d $SAM_INSTALL_DIR
    fi

    _logger "[+] Updating SAM..."
    sudo ./$SAM_INSTALL_DIR/install --update

    _logger "[+] Updating Cloud9 SAM binary"
    # Allows for local invoke within IDE (except debug run)
    ln -sf $(which sam) ~/.c9/bin/sam
}

function cleanup() {
    if [[ -d $SAM_INSTALL_DIR ]]; then
        rm -rf $SAM_INSTALL_DIR
    fi
}

function install_maven() {
    _logger "[+] Installing maven"
    sudo pacman -S --noconfirm wget tar  # Replacing yum with pacman
    sudo wget https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz
    sudo tar xf apache-maven-*.tar.gz -C /opt
    sudo ln -s /opt/apache-maven-3.9.6 /opt/maven
    sudo touch /etc/profile.d/maven.sh
    echo "export M2_HOME=/opt/maven" | sudo tee -a /etc/profile.d/maven.sh
    echo "export MAVEN_HOME=/opt/maven" | sudo tee -a /etc/profile.d/maven.sh
    echo "export PATH=${PATH}:/opt/maven/bin" | sudo tee -a /etc/profile.d/maven.sh
    sudo chmod +x /etc/profile.d/maven.sh
    source /etc/profile.d/maven.sh
}

function main() {
    update_system
    update_python_packages
    install_utility_tools
    upgrade_sam_cli
    install_maven
    cleanup

    echo -e "${RED} [!!!!!!!!!] To be safe, I suggest closing this terminal and opening a new one! ${NC}"
    _logger "[+] Restarting Shell to reflect changes"
    exec ${SHELL}
}

main

