#!/bin/bash

# ============================================
#  Script de Instalação - Mesa-Mapa C4I v0.1
#  Testado no Linux Mint 22.2 (Zara)
# ============================================

# Cores para output
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
AZUL='\033[0;34m'
SEM_COR='\033[0m'

echo -e "${AZUL}============================================${SEM_COR}"
echo -e "${AZUL}   MESA-MAPA C4I - INSTALAÇÃO COMPLETA    ${SEM_COR}"
echo -e "${AZUL}============================================${SEM_COR}"
echo ""

# Função para mostrar progresso
progresso() {
    echo -e "${AMARELO}[$(date +%H:%M:%S)]${SEM_COR} $1"
}

# Função para tratar erros sem parar o script
check_soft() {
    if [ $? -ne 0 ]; then
        echo -e "${VERMELHO}  ⚠ Aviso: $1${SEM_COR}"
        echo -e "${AMARELO}  Continuando mesmo assim...${SEM_COR}"
    fi
}

# ============================================
# 1. Verificar se não é root
# ============================================
if [ "$EUID" -eq 0 ]; then
    echo -e "${VERMELHO}Por favor, execute como usuário normal (não root)${SEM_COR}"
    exit 1
fi

sudo -v
check_soft "Senha sudo incorreta"

# ============================================
# 2. Corrigir repositório CD-ROM do Mint
# ============================================
progresso "Corrigindo repositório CD-ROM..."

# Remove linhas 'deb cdrom' do sources.list principal
if [ -f /etc/apt/sources.list ]; then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
    sudo grep -v "^deb cdrom" /etc/apt/sources.list | sudo tee /etc/apt/sources.list > /dev/null
fi

# Remove linhas 'deb cdrom' de arquivos em sources.list.d/
for file in /etc/apt/sources.list.d/*; do
    if [ -f "$file" ]; then
        sudo cp "$file" "$file.backup" 2>/dev/null
        sudo grep -v "^deb cdrom" "$file" | sudo tee "$file" > /dev/null
        # Se o arquivo ficou vazio, remove
        if [ ! -s "$file" ]; then
            sudo rm "$file"
        fi
    fi
done

# Remove backups antigos que possam atrapalhar o apt
sudo rm -f /etc/apt/sources.list.d/*.backup 2>/dev/null
sudo rm -f /etc/apt/sources.list.d/*.save 2>/dev/null

echo -e "${VERDE}  ✔ Repositório CD-ROM corrigido!${SEM_COR}"

# ============================================
# 3. Atualizar lista de pacotes
# ============================================
progresso "Atualizando repositórios..."
sudo apt update -y 2>&1 | grep -v "cdrom" || true
echo -e "${VERDE}  ✔ Atualização concluída!${SEM_COR}"

# ============================================
# 4. Instalar pacotes essenciais de compilação
# ============================================
progresso "Instalando compilador e ferramentas..."
sudo apt install -y \
    build-essential \
    cmake \
    pkg-config \
    git \
    wget \
    curl \
    unzip \
    htop \
    net-tools
check_soft "Falha ao instalar ferramentas de compilação"

# ============================================
# 5. Instalar GTKmm 3 e Champlain (mapas)
# ============================================
progresso "Instalando GTKmm 3 e Champlain..."
sudo apt install -y \
    libgtkmm-3.0-dev \
    libchamplain-0.12-dev \
    libchamplain-gtk-0.12-dev \
    libcairo2-dev \
    libglib2.0-dev
check_soft "Falha ao instalar GTKmm/Champlain"

# ============================================
# 6. Instalar Mosquitto (MQTT)
# ============================================
progresso "Instalando Mosquitto (broker MQTT)..."
sudo apt install -y \
    mosquitto \
    mosquitto-clients \
    libmosquitto-dev \
    libmosquittopp-dev
check_soft "Falha ao instalar Mosquitto"

# ============================================
# 7. Instalar MariaDB (evita conflito com MySQL)
# ============================================
progresso "Instalando MariaDB Connector..."

# Remove qualquer MySQL client que possa conflitar
sudo apt remove -y libmysqlclient-dev libmysqlclient21 2>/dev/null
sudo apt autoremove -y 2>/dev/null

# Instala MariaDB
sudo apt install -y \
    libmariadb-dev \
    libmariadb-dev-compat \
    default-libmysqlclient-dev
check_soft "Falha ao instalar MariaDB"

# ============================================
# 8. Instalar JSON (nlohmann/json + fallback)
# ============================================
progresso "Instalando JSON (nlohmann)..."
sudo apt install -y nlohmann-json3-dev 2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${AMARELO}  Pacote nlohmann não encontrado no repositório. Baixando manualmente...${SEM_COR}"
    sudo mkdir -p /usr/local/include/nlohmann
    cd /tmp
    wget -q https://github.com/nlohmann/json/releases/download/v3.11.2/json.hpp
    if [ $? -eq 0 ]; then
        sudo cp json.hpp /usr/local/include/nlohmann/json.hpp
        echo -e "${VERDE}  ✔ nlohmann/json instalado manualmente!${SEM_COR}"
    else
        echo -e "${VERMELHO}  ⚠ Não foi possível baixar nlohmann/json. O sistema funcionará sem JSON por enquanto.${SEM_COR}"
    fi
    cd - > /dev/null
else
    echo -e "${VERDE}  ✔ nlohmann/json instalado via apt!${SEM_COR}"
fi

# ============================================
# 9. Instalar Python e ferramentas
# ============================================
progresso "Instalando Python..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev
check_soft "Falha ao instalar Python"

# ============================================
# 10. Configurar Mosquitto
# ============================================
progresso "Configurando Mosquitto..."

# Backup da configuração original
if [ -f /etc/mosquitto/mosquitto.conf ]; then
    sudo cp /etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf.backup
fi

# Configuração básica para uso local
sudo tee /etc/mosquitto/mosquitto.conf > /dev/null << 'EOF'
# Configuração Mesa-Mapa C4I
listener 1883
allow_anonymous true
persistence true
persistence_location /var/lib/mosquitto/
log_dest file /var/log/mosquitto/mosquitto.log
EOF

# Inicia e habilita o serviço
sudo systemctl enable mosquitto
sudo systemctl restart mosquitto
check_soft "Falha ao configurar Mosquitto"

# ============================================
# 11. Criar ambiente Python virtual
# ============================================
progresso "Criando ambiente Python para simulador..."

mkdir -p ~/mesa_mapa
cd ~/mesa_mapa

if [ ! -d "venv" ]; then
    python3 -m venv venv
    check_soft "Falha ao criar ambiente virtual"
fi

source venv/bin/activate
pip install --upgrade pip > /dev/null 2>&1
pip install paho-mqtt > /dev/null 2>&1
check_soft "Falha ao instalar Paho MQTT"
deactivate

# ============================================
# 12. Criar estrutura de diretórios
# ============================================
progresso "Criando estrutura de diretórios do projeto..."

mkdir -p ~/mesa_mapa/{src,simulador,build,data,assets,docs}

cat > ~/mesa_mapa/.gitignore << 'EOF'
build/
venv/
*.o
*.a
*.so
data/*.db
EOF

# ============================================
# 13. Verificação final
# ============================================
progresso "Verificando instalação..."

echo -e "\n${AZUL}=== RESULTADO DA VERIFICAÇÃO ===${SEM_COR}"

# GTKmm
echo -n "GTKmm 3: "
if pkg-config --exists gtkmm-3.0; then
    echo -e "${VERDE}OK ($(pkg-config --modversion gtkmm-3.0))${SEM_COR}"
else
    echo -e "${VERMELHO}FALHOU${SEM_COR}"
fi

# Champlain
echo -n "Champlain: "
if pkg-config --exists champlain-0.12; then
    echo -e "${VERDE}OK ($(pkg-config --modversion champlain-0.12))${SEM_COR}"
else
    echo -e "${VERMELHO}FALHOU${SEM_COR}"
fi

# Mosquitto
echo -n "Mosquitto: "
if systemctl is-active --quiet mosquitto; then
    echo -e "${VERDE}OK (ativo)${SEM_COR}"
else
    echo -e "${AMARELO}Não está rodando - execute: sudo systemctl start mosquitto${SEM_COR}"
fi

# MariaDB
echo -n "MariaDB Connector: "
if mysql_config --version > /dev/null 2>&1; then
    echo -e "${VERDE}OK ($(mysql_config --version))${SEM_COR}"
else
    echo -e "${AMARELO}Não encontrado (verifique LAMPP)${SEM_COR}"
fi

# nlohmann/json
echo -n "JSON (nlohmann): "
if [ -f /usr/include/nlohmann/json.hpp ] || [ -f /usr/local/include/nlohmann/json.hpp ]; then
    echo -e "${VERDE}OK${SEM_COR}"
else
    echo -e "${AMARELO}Não encontrado (opcional para v0.1)${SEM_COR}"
fi

# Teste MQTT rápido
echo -e "\n${AZUL}=== TESTE MQTT ===${SEM_COR}"
timeout 5 mosquitto_sub -t "teste_mesa_mapa" -C 1 > /tmp/mqtt_test.txt &
SUB_PID=$!
sleep 1
mosquitto_pub -t "teste_mesa_mapa" -m "instalacao_ok"
wait $SUB_PID 2>/dev/null

if grep -q "instalacao_ok" /tmp/mqtt_test.txt 2>/dev/null; then
    echo -e "${VERDE}✔ MQTT funcionando perfeitamente!${SEM_COR}"
else
    echo -e "${AMARELO}⚠ MQTT não respondeu ao teste (pode ser normal)${SEM_COR}"
fi
rm -f /tmp/mqtt_test.txt

# ============================================
# 14. Resumo final
# ============================================
echo -e "\n${VERDE}============================================${SEM_COR}"
echo -e "${VERDE}   INSTALAÇÃO CONCLUÍDA COM SUCESSO!      ${SEM_COR}"
echo -e "${VERDE}============================================${SEM_COR}"
echo ""
echo -e "${AZUL}Próximos passos:${SEM_COR}"
echo -e "1. Acesse o diretório do projeto: ${AMARELO}cd ~/mesa_mapa${SEM_COR}"
echo -e "2. Crie os arquivos de código-fonte (main.cpp, etc.)"
echo -e "3. Compile usando o build.sh (ou CMake)"
echo -e "4. Execute: ${AMARELO}./mesamapa${SEM_COR}"
echo -e "5. Teste o simulador: ${AMARELO}source ~/mesa_mapa/venv/bin/activate && python3 simulador/simulador.py${SEM_COR}"
echo ""
echo -e "${AZUL}O centro de comando está pronto para a batalha!${SEM_COR}"
echo -e "${AZUL}🎯 Boa sorte, Comandante!${SEM_COR}"