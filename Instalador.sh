#!/bin/bash

# ============================================================
# Instalador gráfico de aplicativos
#
# Suporta:
#   - Zorin OS
#   - Ubuntu
#   - Debian
#   - Linux Mint e derivados Debian/Ubuntu
#   - Fedora
#
# Interface:
#   - Zenity
#
# Aplicativos:
#   - VSCodium
#   - Pidgin + inicialização automática
#   - Firefox
#   - Git
#   - ChatGPT
#   - LibreOffice
#   - Flutter SDK + ambiente Linux Desktop
# ============================================================


LOG="/tmp/instalador-apps.log"
> "$LOG"


# ============================================================
# VERIFICAR ZENITY
# ============================================================

if ! command -v zenity >/dev/null 2>&1; then

    echo
    echo "Zenity não está instalado."
    echo

    if command -v apt >/dev/null 2>&1; then
        echo "Instale com:"
        echo
        echo "sudo apt install zenity"
    elif command -v dnf >/dev/null 2>&1; then
        echo "Instale com:"
        echo
        echo "sudo dnf install zenity"
    fi

    exit 1
fi


# ============================================================
# DETECTAR DISTRIBUIÇÃO
# ============================================================

if [ ! -f /etc/os-release ]; then

    zenity \
        --error \
        --title="Erro" \
        --text="Não foi possível identificar a distribuição Linux."

    exit 1
fi


source /etc/os-release

DISTRO_ID="${ID:-unknown}"
DISTRO_NAME="${PRETTY_NAME:-Linux}"
DISTRO_LIKE="${ID_LIKE:-}"


if [[ "$DISTRO_ID" == "fedora" ]] || \
   [[ "$DISTRO_LIKE" == *"fedora"* ]]; then

    DISTRO_FAMILY="fedora"
    PKG_MANAGER="dnf"

elif [[ "$DISTRO_ID" == "ubuntu" ]] || \
     [[ "$DISTRO_ID" == "debian" ]] || \
     [[ "$DISTRO_ID" == "zorin" ]] || \
     [[ "$DISTRO_ID" == "linuxmint" ]] || \
     [[ "$DISTRO_LIKE" == *"debian"* ]] || \
     [[ "$DISTRO_LIKE" == *"ubuntu"* ]]; then

    DISTRO_FAMILY="debian"
    PKG_MANAGER="apt"

else

    zenity \
        --error \
        --title="Distribuição não suportada" \
        --width=500 \
        --text="Distribuição detectada:

$DISTRO_NAME

Este instalador atualmente suporta:

• Zorin OS
• Ubuntu
• Debian
• Linux Mint
• Fedora"

    exit 1
fi


echo "Distribuição: $DISTRO_NAME" >> "$LOG"
echo "Família: $DISTRO_FAMILY" >> "$LOG"
echo "Gerenciador: $PKG_MANAGER" >> "$LOG"
echo >> "$LOG"


# ============================================================
# FUNÇÕES DO GERENCIADOR DE PACOTES
# ============================================================


update_packages()
{

    if [ "$PKG_MANAGER" = "apt" ]; then

        pkexec apt-get update >> "$LOG" 2>&1

    else

        pkexec dnf -y makecache --refresh >> "$LOG" 2>&1

    fi
}


install_packages()
{

    if [ "$PKG_MANAGER" = "apt" ]; then

        pkexec apt-get install -y "$@" >> "$LOG" 2>&1

    else

        pkexec dnf install -y "$@" >> "$LOG" 2>&1

    fi
}


install_package()
{

    PACKAGE="$1"
    NAME="$2"

    echo >> "$LOG"
    echo "Instalando $NAME..." >> "$LOG"

    if install_packages "$PACKAGE"; then

        echo "$NAME instalado com sucesso." >> "$LOG"
        return 0

    else

        echo "ERRO ao instalar $NAME." >> "$LOG"
        return 1

    fi
}


# ============================================================
# INTERFACE PRINCIPAL
# ============================================================


APPS=$(zenity \
    --list \
    --checklist \
    --title="Instalador de Aplicativos" \
    --text="Sistema detectado: $DISTRO_NAME

Selecione os aplicativos que deseja instalar:" \
    --width=780 \
    --height=600 \
    --column="Instalar" \
    --column="Aplicativo" \
    --column="Descrição" \
    FALSE "VSCodium" "Editor de código baseado no VS Code" \
    FALSE "Pidgin" "Cliente de mensagens - inicia automaticamente no login" \
    FALSE "Firefox" "Navegador Mozilla Firefox" \
    FALSE "Git" "Sistema de controle de versão" \
    FALSE "ChatGPT" "Aplicativo oficial do ChatGPT para Linux" \
    FALSE "LibreOffice" "Pacote de escritório" \
    FALSE "Flutter" "SDK Flutter stable + ferramentas para Linux Desktop" \
    --print-column=2 \
    --separator="|"
)


# Cancelou

if [ $? -ne 0 ]; then
    exit 0
fi


# Nenhum selecionado

if [ -z "$APPS" ]; then

    zenity \
        --warning \
        --title="Nenhum aplicativo selecionado" \
        --text="Selecione pelo menos um aplicativo."

    exit 0
fi


selected()
{
    [[ "|$APPS|" == *"|$1|"* ]]
}


# ============================================================
# VSCODIUM
# ============================================================


install_vscodium()
{

    echo >> "$LOG"
    echo "=====================================" >> "$LOG"
    echo "VSCodium" >> "$LOG"
    echo "=====================================" >> "$LOG"


    # --------------------------------------------------------
    # DEBIAN / UBUNTU / ZORIN
    # --------------------------------------------------------

    if [ "$DISTRO_FAMILY" = "debian" ]; then

        install_packages wget gnupg

        TMP_KEY="/tmp/vscodium-key.gpg"
        TMP_KEYRING="/tmp/vscodium-archive-keyring.gpg"
        TMP_SOURCE="/tmp/vscodium.sources"

        rm -f \
            "$TMP_KEY" \
            "$TMP_KEYRING" \
            "$TMP_SOURCE"


        wget -q \
            https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
            -O "$TMP_KEY"


        if [ $? -ne 0 ]; then

            echo "Erro ao baixar chave do VSCodium." >> "$LOG"
            return 1

        fi


        gpg \
            --batch \
            --yes \
            --dearmor \
            -o "$TMP_KEYRING" \
            "$TMP_KEY"


        pkexec install \
            -m 0644 \
            "$TMP_KEYRING" \
            /usr/share/keyrings/vscodium-archive-keyring.gpg


        cat > "$TMP_SOURCE" <<EOF
Types: deb
URIs: https://download.vscodium.com/debs
Suites: vscodium
Components: main
Architectures: amd64 arm64
Signed-by: /usr/share/keyrings/vscodium-archive-keyring.gpg
EOF


        pkexec install \
            -m 0644 \
            "$TMP_SOURCE" \
            /etc/apt/sources.list.d/vscodium.sources


        pkexec apt-get update >> "$LOG" 2>&1

        pkexec apt-get install \
            -y codium \
            >> "$LOG" 2>&1


        RESULT=$?


        rm -f \
            "$TMP_KEY" \
            "$TMP_KEYRING" \
            "$TMP_SOURCE"


    # --------------------------------------------------------
    # FEDORA
    # --------------------------------------------------------

    else

        TMP_REPO="/tmp/vscodium.repo"

        cat > "$TMP_REPO" <<EOF
[gitlab.com_paulcarroty_vscodium_repo]
name=VSCodium
baseurl=https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
metadata_expire=1h
EOF


        pkexec install \
            -m 0644 \
            "$TMP_REPO" \
            /etc/yum.repos.d/vscodium.repo


        rm -f "$TMP_REPO"


        pkexec dnf install \
            -y codium \
            >> "$LOG" 2>&1


        RESULT=$?

    fi


    if [ $RESULT -eq 0 ]; then

        echo "VSCodium instalado com sucesso." >> "$LOG"
        return 0

    else

        echo "Erro na instalação do VSCodium." >> "$LOG"
        return 1

    fi
}


# ============================================================
# PIDGIN - INICIAR AUTOMATICAMENTE
# ============================================================


configure_pidgin_autostart()
{

    AUTOSTART="$HOME/.config/autostart"

    mkdir -p "$AUTOSTART"


    cat > "$AUTOSTART/pidgin.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Pidgin
Comment=Iniciar Pidgin automaticamente no login
Exec=pidgin
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
EOF


    chmod 644 "$AUTOSTART/pidgin.desktop"

    echo "Pidgin configurado para iniciar no login." >> "$LOG"
}


# ============================================================
# CHATGPT
# ============================================================


prepare_chatgpt()
{

    if [ "$DISTRO_FAMILY" = "fedora" ]; then

        PACKAGE_TYPE="RPM"
        PACKAGE_EXTENSION="*.rpm"

    else

        PACKAGE_TYPE="DEB"
        PACKAGE_EXTENSION="*.deb"

    fi


    zenity \
        --info \
        --title="ChatGPT para Linux" \
        --width=520 \
        --text="Será aberta a página oficial do ChatGPT para Linux.

Sistema detectado:

$DISTRO_NAME

Baixe o pacote:

$PACKAGE_TYPE

Depois volte para esta janela."


    xdg-open \
        "https://learn.chatgpt.com/docs/linux/linux-app" \
        >/dev/null 2>&1 &


    zenity \
        --question \
        --title="ChatGPT" \
        --width=480 \
        --text="Após terminar o download do ChatGPT, clique em:

Selecionar arquivo

para localizar o instalador." \
        --ok-label="Selecionar arquivo" \
        --cancel-label="Pular ChatGPT"


    if [ $? -ne 0 ]; then
        return 1
    fi


    CHATGPT_PACKAGE=$(zenity \
        --file-selection \
        --title="Selecione o instalador do ChatGPT" \
        --filename="$HOME/Downloads/" \
        --file-filter="Pacote $PACKAGE_TYPE | $PACKAGE_EXTENSION"
    )


    if [ -z "$CHATGPT_PACKAGE" ]; then
        return 1
    fi


    echo "$CHATGPT_PACKAGE"
}


install_chatgpt()
{

    PACKAGE="$1"

    echo >> "$LOG"
    echo "Instalando ChatGPT..." >> "$LOG"


    if [ "$DISTRO_FAMILY" = "fedora" ]; then

        pkexec dnf install \
            -y "$PACKAGE" \
            >> "$LOG" 2>&1

    else

        pkexec apt-get install \
            -y "$PACKAGE" \
            >> "$LOG" 2>&1

    fi


    if [ $? -eq 0 ]; then

        echo "ChatGPT instalado com sucesso." >> "$LOG"

    else

        echo "Erro ao instalar ChatGPT." >> "$LOG"

    fi
}


# ============================================================
# FLUTTER
# ============================================================


install_flutter()
{

    echo >> "$LOG"
    echo "=====================================" >> "$LOG"
    echo "FLUTTER" >> "$LOG"
    echo "=====================================" >> "$LOG"


    # --------------------------------------------------------
    # Verificar arquitetura
    # --------------------------------------------------------

    ARCH=$(uname -m)


    if [ "$ARCH" != "x86_64" ]; then

        echo \
            "Flutter Linux SDK automático configurado para x86_64." \
            >> "$LOG"

        return 2

    fi


    # --------------------------------------------------------
    # Dependências
    # --------------------------------------------------------

    echo "Instalando dependências do Flutter..." >> "$LOG"


    if [ "$DISTRO_FAMILY" = "debian" ]; then

        install_packages \
            curl \
            git \
            unzip \
            xz-utils \
            zip \
            libglu1-mesa \
            clang \
            cmake \
            ninja-build \
            pkg-config \
            libgtk-3-dev \
            g++ \
            python3

    else

        install_packages \
            curl \
            git \
            unzip \
            xz \
            zip \
            mesa-libGLU \
            clang \
            cmake \
            ninja-build \
            pkgconf-pkg-config \
            gtk3-devel \
            gcc-c++ \
            python3

    fi


    if [ $? -ne 0 ]; then

        echo \
            "Erro ao instalar dependências do Flutter." \
            >> "$LOG"

        return 1

    fi


    # --------------------------------------------------------
    # Diretórios
    # --------------------------------------------------------

    FLUTTER_PARENT="$HOME/develop"
    FLUTTER_DIR="$FLUTTER_PARENT/flutter"

    mkdir -p "$FLUTTER_PARENT"


    # --------------------------------------------------------
    # Se já existe Flutter, apenas atualizar
    # --------------------------------------------------------

    if [ -x "$FLUTTER_DIR/bin/flutter" ]; then

        echo "Flutter já instalado." >> "$LOG"
        echo "Atualizando Flutter..." >> "$LOG"

        "$FLUTTER_DIR/bin/flutter" \
            channel stable \
            >> "$LOG" 2>&1

        "$FLUTTER_DIR/bin/flutter" \
            upgrade \
            >> "$LOG" 2>&1

    else

        # ----------------------------------------------------
        # Descobrir automaticamente versão stable mais recente
        # ----------------------------------------------------

        RELEASES_JSON="/tmp/flutter_releases.json"


        echo \
            "Consultando versão stable do Flutter..." \
            >> "$LOG"


        curl \
            -fsSL \
            https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json \
            -o "$RELEASES_JSON"


        if [ $? -ne 0 ]; then

            echo \
                "Não foi possível consultar as versões do Flutter." \
                >> "$LOG"

            return 1

        fi


        FLUTTER_INFO=$(python3 - "$RELEASES_JSON" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

stable_hash = data["current_release"]["stable"]

release = next(
    item
    for item in data["releases"]
    if item["hash"] == stable_hash
)

print(
    data["base_url"]
    + "|"
    + release["archive"]
    + "|"
    + release["sha256"]
    + "|"
    + release["version"]
)
PY
)


        IFS="|" read -r \
            FLUTTER_BASE_URL \
            FLUTTER_ARCHIVE \
            FLUTTER_SHA256 \
            FLUTTER_VERSION \
            <<< "$FLUTTER_INFO"


        if [ -z "$FLUTTER_ARCHIVE" ]; then

            echo \
                "Não foi possível determinar a versão do Flutter." \
                >> "$LOG"

            return 1

        fi


        FLUTTER_URL="$FLUTTER_BASE_URL/$FLUTTER_ARCHIVE"

        DOWNLOAD_FILE="/tmp/flutter.tar.xz"


        echo \
            "Versão Flutter stable: $FLUTTER_VERSION" \
            >> "$LOG"

        echo \
            "Download: $FLUTTER_URL" \
            >> "$LOG"


        # ----------------------------------------------------
        # Download
        # ----------------------------------------------------

        curl \
            -fL \
            "$FLUTTER_URL" \
            -o "$DOWNLOAD_FILE"


        if [ $? -ne 0 ]; then

            echo \
                "Erro ao baixar Flutter." \
                >> "$LOG"

            return 1

        fi


        # ----------------------------------------------------
        # Verificar SHA256
        # ----------------------------------------------------

        echo \
            "$FLUTTER_SHA256  $DOWNLOAD_FILE" \
            | sha256sum -c - \
            >> "$LOG" 2>&1


        if [ $? -ne 0 ]; then

            echo \
                "Falha na verificação SHA256 do Flutter." \
                >> "$LOG"

            rm -f "$DOWNLOAD_FILE"

            return 1

        fi


        # ----------------------------------------------------
        # Extrair
        # ----------------------------------------------------

        echo \
            "Extraindo Flutter para $FLUTTER_PARENT..." \
            >> "$LOG"


        tar \
            -xf "$DOWNLOAD_FILE" \
            -C "$FLUTTER_PARENT" \
            >> "$LOG" 2>&1


        RESULT=$?


        rm -f \
            "$DOWNLOAD_FILE" \
            "$RELEASES_JSON"


        if [ $RESULT -ne 0 ]; then

            echo \
                "Erro ao extrair Flutter." \
                >> "$LOG"

            return 1

        fi

    fi


    # --------------------------------------------------------
    # Adicionar Flutter ao PATH
    # --------------------------------------------------------

    PATH_LINE='export PATH="$HOME/develop/flutter/bin:$PATH"'


    if ! grep \
        -qxF "$PATH_LINE" \
        "$HOME/.profile" \
        2>/dev/null; then

        echo >> "$HOME/.profile"
        echo "# Flutter SDK" >> "$HOME/.profile"
        echo "$PATH_LINE" >> "$HOME/.profile"

    fi


    if [ -f "$HOME/.bashrc" ]; then

        if ! grep \
            -qxF "$PATH_LINE" \
            "$HOME/.bashrc" \
            2>/dev/null; then

            echo >> "$HOME/.bashrc"
            echo "# Flutter SDK" >> "$HOME/.bashrc"
            echo "$PATH_LINE" >> "$HOME/.bashrc"

        fi

    fi


    if [ -f "$HOME/.zshrc" ]; then

        if ! grep \
            -qxF "$PATH_LINE" \
            "$HOME/.zshrc" \
            2>/dev/null; then

            echo >> "$HOME/.zshrc"
            echo "# Flutter SDK" >> "$HOME/.zshrc"
            echo "$PATH_LINE" >> "$HOME/.zshrc"

        fi

    fi


    export PATH="$HOME/develop/flutter/bin:$PATH"


    # --------------------------------------------------------
    # Flutter version
    # --------------------------------------------------------

    flutter --version >> "$LOG" 2>&1


    # --------------------------------------------------------
    # Flutter Doctor
    # --------------------------------------------------------

    echo >> "$LOG"
    echo "Executando flutter doctor..." >> "$LOG"

    flutter doctor -v >> "$LOG" 2>&1


    echo \
        "Flutter instalado com sucesso em $FLUTTER_DIR" \
        >> "$LOG"


    return 0
}


# ============================================================
# PREPARAR CHATGPT ANTES DA BARRA DE PROGRESSO
# ============================================================


CHATGPT_FILE=""


if selected "ChatGPT"; then

    CHATGPT_FILE=$(prepare_chatgpt)

fi


# ============================================================
# INSTALAÇÃO
# ============================================================


(

    echo "3"
    echo "# Sistema detectado: $DISTRO_NAME"


    sleep 1


    # --------------------------------------------------------
    # ATUALIZAR PACOTES
    # --------------------------------------------------------

    echo "8"
    echo "# Atualizando repositórios..."

    update_packages


    # --------------------------------------------------------
    # VSCODIUM
    # --------------------------------------------------------

    if selected "VSCodium"; then

        echo "18"
        echo "# Instalando VSCodium..."

        install_vscodium

    fi


    # --------------------------------------------------------
    # PIDGIN
    # --------------------------------------------------------

    if selected "Pidgin"; then

        echo "30"
        echo "# Instalando Pidgin..."


        if install_package \
            "pidgin" \
            "Pidgin"; then

            configure_pidgin_autostart

        fi

    fi


    # --------------------------------------------------------
    # FIREFOX
    # --------------------------------------------------------

    if selected "Firefox"; then

        echo "42"
        echo "# Instalando Firefox..."

        install_package \
            "firefox" \
            "Firefox"

    fi


    # --------------------------------------------------------
    # GIT
    # --------------------------------------------------------

    if selected "Git"; then

        echo "52"
        echo "# Instalando Git..."

        install_package \
            "git" \
            "Git"

    fi


    # --------------------------------------------------------
    # LIBREOFFICE
    # --------------------------------------------------------

    if selected "LibreOffice"; then

        echo "62"
        echo "# Instalando LibreOffice..."

        install_package \
            "libreoffice" \
            "LibreOffice"

    fi


    # --------------------------------------------------------
    # FLUTTER
    # --------------------------------------------------------

    if selected "Flutter"; then

        echo "72"
        echo "# Instalando Flutter SDK..."

        install_flutter

        FLUTTER_RESULT=$?


        if [ $FLUTTER_RESULT -eq 2 ]; then

            echo \
                "Arquitetura não suportada pelo instalador automático do Flutter." \
                >> "$LOG"

        fi

    fi


    # --------------------------------------------------------
    # CHATGPT
    # --------------------------------------------------------

    if selected "ChatGPT"; then

        echo "90"
        echo "# Instalando ChatGPT..."


        if [ -n "$CHATGPT_FILE" ] && \
           [ -f "$CHATGPT_FILE" ]; then

            install_chatgpt "$CHATGPT_FILE"

        else

            echo \
                "ChatGPT não instalado: pacote não selecionado." \
                >> "$LOG"

        fi

    fi


    # --------------------------------------------------------

    echo "100"
    echo "# Instalação concluída!"

    sleep 1


) | zenity \
        --progress \
        --title="Instalador de Aplicativos" \
        --text="Preparando..." \
        --percentage=0 \
        --width=520 \
        --auto-close \
        --no-cancel


# ============================================================
# FINAL
# ============================================================


zenity \
    --info \
    --title="Instalação concluída" \
    --width=550 \
    --text="Processo concluído.

Sistema:

$DISTRO_NAME

Os aplicativos selecionados foram processados.

Se o Flutter foi instalado:

• SDK: ~/develop/flutter
• PATH configurado automaticamente
• flutter doctor -v executado

O Pidgin foi configurado para iniciar automaticamente no login.

Log completo:

$LOG"
