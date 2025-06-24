#!/bin/bash

# Nexus Node 관리 스크립트 v2.0
# Ubuntu 24+, MacOS, Windows WSL 지원
# 기능: 설치, 삭제, 모니터링, 정보 확인
# Ubuntu 22.04 → 24.04 자동 업그레이드 지원
# 
# 정보 저장 위치:
# - Nexus 설치 경로: ~/.nexus/
# - 사용자 입력 정보: ~/.nexus_manager/
#   - node_id: NodeID 저장
#   - wallet_address: 지갑 주소 저장

# 출력용 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # 색상 없음

# 색상이 있는 메시지 출력 함수
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# OS 및 환경 감지 함수
detect_environment() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL 환경
        if command -v apt &> /dev/null; then
            echo "wsl_ubuntu"
        else
            echo "unsupported"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt &> /dev/null; then
            echo "ubuntu"
        else
            echo "unsupported"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unsupported"
    fi
}

# Ubuntu 버전 확인 함수
check_ubuntu_version() {
    if [[ $OS == "ubuntu" ]] || [[ $OS == "wsl_ubuntu" ]]; then
        VERSION=$(lsb_release -rs 2>/dev/null)
        if [[ -z "$VERSION" ]]; then
            VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d'"' -f2)
        fi
        
        MAJOR_VERSION=$(echo $VERSION | cut -d'.' -f1)
        
        if [[ $MAJOR_VERSION -lt 24 ]]; then
            print_message "$RED" "========================================="
            print_message "$RED" "⚠️  경고: Ubuntu 버전 확인"
            print_message "$RED" "========================================="
            print_message "$RED" "현재 Ubuntu 버전: $VERSION"
            print_message "$RED" "Nexus는 GLIBC 2.39 이상이 필요하므로"
            print_message "$RED" "Ubuntu 24.04 이상을 권장합니다."
            print_message "$RED" ""
            print_message "$RED" "해결 방법:"
            print_message "$YELLOW" "1. VPS 제공업체에서 Ubuntu 24.04로 재설치"
            
            if [[ "$VERSION" == "22.04" ]]; then
                print_message "$YELLOW" "2. Ubuntu 24.04로 업그레이드 진행"
            elif [[ "$VERSION" == "20.04" ]]; then
                print_message "$YELLOW" "2. Ubuntu 업그레이드 (20.04→22.04→24.04는 VPS에서 직접 진행하세요)"
            else
                print_message "$YELLOW" "2. Ubuntu 업그레이드"
            fi
            
            print_message "$RED" "========================================="
            echo ""
            read -p "선택하세요 (1 또는 2): " upgrade_choice
            
            case $upgrade_choice in
                1)
                    print_message "$YELLOW" "VPS 제공업체에서 Ubuntu 24.04로 재설치 후 다시 실행하세요."
                    return
                    ;;
                2)
                    if [[ "$VERSION" == "22.04" ]]; then
                        print_message "$YELLOW" "Ubuntu 22.04에서 24.04로 업그레이드를 시작합니다..."
                        print_message "$YELLOW" "이 과정은 시간이 걸릴 수 있습니다. (약 30분~1시간)"
                        echo ""
                        read -p "업그레이드를 진행하시겠습니까? (y/n): " confirm_upgrade
                        if [[ $confirm_upgrade == "y" ]]; then
                            # 업그레이드 진행
                            print_message "$GREEN" "업그레이드를 시작합니다..."
                            print_message "$YELLOW" "모든 과정이 자동으로 진행됩니다. 중간에 아무것도 누르지 마세요!"
                            print_message "$YELLOW" "약 30분~1시간 소요됩니다..."
                            echo ""
                            sleep 3
                            
                            # 시스템 업데이트
                            sudo apt update && sudo apt upgrade -y
                            sudo apt install update-manager-core -y
                            
                            # do-release-upgrade 설정 변경
                            sudo sed -i 's/Prompt=lts/Prompt=normal/g' /etc/update-manager/release-upgrades
                            
                            print_message "$YELLOW" "자동 업그레이드를 시작합니다..."
                            print_message "$RED" "화면이 멈춘 것처럼 보여도 진행 중이니 기다려주세요!"
                            
                            # 자동 업그레이드 실행 (모든 프롬프트에 자동으로 yes)
                            sudo DEBIAN_FRONTEND=noninteractive \
                                 apt-get -o Dpkg::Options::="--force-confdef" \
                                 -o Dpkg::Options::="--force-confold" \
                                 dist-upgrade -y
                            
                            sudo DEBIAN_FRONTEND=noninteractive do-release-upgrade -f DistUpgradeViewNonInteractive
                            
                            # 업그레이드 성공 확인
                            if [ $? -eq 0 ]; then
                                print_message "$GREEN" "========================================="
                                print_message "$GREEN" "✅ 업그레이드가 완료되었습니다!"
                                print_message "$GREEN" "========================================="
                                print_message "$YELLOW" "다음 단계:"
                                print_message "$YELLOW" "1. 시스템이 5초 후 자동으로 재부팅됩니다"
                                print_message "$YELLOW" "2. 재부팅 후 다시 이 스크립트를 실행하세요:"
                                print_message "$GREEN" "   ./$(basename "$0")"
                                print_message "$GREEN" "========================================="
                                
                                sleep 5
                                sudo reboot
                            else
                                print_message "$RED" "업그레이드 중 오류가 발생했습니다."
                                print_message "$YELLOW" "수동으로 업그레이드를 진행해주세요: sudo do-release-upgrade"
                                return
                            fi
                        else
                            print_message "$YELLOW" "업그레이드가 취소되었습니다."
                            return
                        fi
                    elif [[ "$VERSION" == "20.04" ]]; then
                        print_message "$RED" "Ubuntu 20.04에서 24.04로의 직접 업그레이드는 권장하지 않습니다."
                        print_message "$YELLOW" "VPS 제공업체에서 Ubuntu 24.04로 재설치하시기 바랍니다."
                        return
                    else
                        print_message "$RED" "현재 버전에서의 업그레이드는 지원하지 않습니다."
                        print_message "$YELLOW" "VPS 제공업체에서 Ubuntu 24.04로 재설치하시기 바랍니다."
                        return
                    fi
                    ;;
                *)
                    print_message "$RED" "잘못된 선택입니다."
                    return
                    ;;
            esac
        fi
    fi
}

# screen 설치 함수
install_screen() {
    if ! command -v screen &> /dev/null; then
        print_message "$YELLOW" "Screen이 설치되어 있지 않습니다. 설치를 진행합니다..."
        if [[ $OS == "ubuntu" ]] || [[ $OS == "wsl_ubuntu" ]]; then
            sudo apt install -y screen
        elif [[ $OS == "macos" ]]; then
            brew install screen
        fi
    else
        print_message "$YELLOW" "Screen이 이미 설치되어 있습니다. 건너뜁니다..."
    fi
}

# 시스템 업데이트 함수
update_system() {
    print_message "$BLUE" "시스템 패키지를 업데이트합니다..."
    
    if [[ $OS == "ubuntu" ]] || [[ $OS == "wsl_ubuntu" ]]; then
        sudo apt update && sudo apt upgrade -y
    elif [[ $OS == "macos" ]]; then
        brew update && brew upgrade
    fi
    
    print_message "$GREEN" "시스템 업데이트가 완료되었습니다!"
}

# 스왑 설정 함수 (WSL은 제외)
setup_swap() {
    if [[ $OS == "wsl_ubuntu" ]]; then
        print_message "$YELLOW" "WSL 환경에서는 스왑 설정을 건너뜁니다..."
        return
    fi
    
    if [[ $OS != "ubuntu" ]]; then
        print_message "$YELLOW" "스왑 설정은 Ubuntu에서만 지원됩니다. 건너뜁니다..."
        return
    fi
    
    # 이미 30GB 스왑이 설정되어 있는지 확인
    if [ -f "/swapfile" ]; then
        SWAP_SIZE=$(sudo swapon --show | grep "/swapfile" | awk '{print $3}')
        if [[ "$SWAP_SIZE" == "30G" ]]; then
            print_message "$YELLOW" "30GB 스왑이 이미 설정되어 있습니다. 건너뜁니다..."
            return
        fi
    fi
    
    print_message "$BLUE" "스왑 설정을 시작합니다..."
    
    # 모든 스왑 비활성화
    sudo swapoff -a
    
    # 기존 스왑 파일 제거
    if [ -f "/swapfile" ]; then
        sudo rm -f /swapfile
    fi
    if [ -f "/swap.img" ]; then
        sudo rm -f /swap.img
    fi
    
    # /etc/fstab에서 스왑 항목 제거
    sudo sed -i '/swap/d' /etc/fstab
    
    # 새로운 30GB swapfile 생성
    print_message "$YELLOW" "30GB 스왑파일 생성 중..."
    sudo fallocate -l 30G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    
    # /etc/fstab에 추가
    echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab
    
    print_message "$GREEN" "스왑 설정이 완료되었습니다!"
}

# Nexus CLI 설치 함수
install_nexus_cli() {
    print_message "$BLUE" "Nexus Network CLI를 설치합니다..."
    
    # 기존 프로세스 종료
    pkill -f nexus-network 2>/dev/null || true
    
    # 이전 설치 제거
    rm -rf ~/.nexus/bin/nexus-network 2>/dev/null || true
    
    # Nexus CLI 설치
    curl -sSL https://cli.nexus.xyz/ | sh
    
    sleep 3
    
    # 설치 경로 찾기
    NEXUS_PATH=""
    if [[ -f "$HOME/.nexus/bin/nexus-network" ]]; then
        NEXUS_PATH="$HOME/.nexus/bin"
    elif [[ -f "$HOME/.nexus/nexus-network" ]]; then
        NEXUS_PATH="$HOME/.nexus"
    elif [[ -f "/root/.nexus/bin/nexus-network" ]]; then
        NEXUS_PATH="/root/.nexus/bin"
    fi
    
    # PATH 설정
    if [[ -n "$NEXUS_PATH" ]]; then
        export PATH="$NEXUS_PATH:$PATH"
        
        if [[ $OS == "ubuntu" ]] || [[ $OS == "wsl_ubuntu" ]]; then
            echo "export PATH=\"$NEXUS_PATH:\$PATH\"" >> ~/.bashrc
            source ~/.bashrc
        elif [[ $OS == "macos" ]]; then
            if [[ -f ~/.zshrc ]]; then
                echo "export PATH=\"$NEXUS_PATH:\$PATH\"" >> ~/.zshrc
                source ~/.zshrc
            else
                echo "export PATH=\"$NEXUS_PATH:\$PATH\"" >> ~/.bash_profile
                source ~/.bash_profile
            fi
        fi
        
        echo "$NEXUS_PATH" > ~/.nexus_path
        print_message "$GREEN" "Nexus CLI 설치가 완료되었습니다!"
        return 0
    else
        print_message "$RED" "오류: Nexus CLI 설치가 실패했습니다!"
        return 1
    fi
}

# 메뉴 1: 넥서스 설치
menu_install() {
    print_message "$BLUE" "========================================="
    print_message "$BLUE" "넥서스 노드 설치를 시작합니다"
    print_message "$BLUE" "========================================="
    
    # Ubuntu 버전 확인
    check_ubuntu_version
    
    # 시스템 업데이트
    update_system
    
    # 스왑 설정
    setup_swap
    
    # screen 설치
    install_screen
    
    # Nexus CLI 설치
    if ! install_nexus_cli; then
        return 1
    fi
    
    # 설치 옵션 선택
    print_message "$BLUE" "설치 옵션을 선택하세요:"
    print_message "$YELLOW" "1) NodeID로 등록"
    print_message "$YELLOW" "2) 지갑주소로 등록"
    
    read -p "선택 (1 또는 2): " choice
    
    case $choice in
        1)
            read -p "NodeID를 입력하세요: " node_id
            if [[ -z "$node_id" ]]; then
                print_message "$RED" "오류: NodeID는 비어있을 수 없습니다!"
                return 1
            fi
            start_with_nodeid "$node_id"
            echo ""
            print_message "$GREEN" "========================================="
            print_message "$GREEN" "✅ 설치가 완료되었습니다!"
            print_message "$GREEN" "========================================="
            print_message "$YELLOW" "입력한 정보가 저장되었습니다:"
            print_message "$YELLOW" "- NodeID: ~/.nexus_manager/node_id"
            print_message "$YELLOW" ""
            print_message "$YELLOW" "유용한 명령어:"
            print_message "$YELLOW" "- 스크린 확인: screen -r nexus_node"
            print_message "$YELLOW" "- 스크린 분리: Ctrl+A, D"
            print_message "$GREEN" "========================================="
            ;;
        2)
            read -p "지갑 주소를 입력하세요: " wallet_address
            if [[ -z "$wallet_address" ]]; then
                print_message "$RED" "오류: 지갑 주소는 비어있을 수 없습니다!"
                return 1
            fi
            start_with_wallet "$wallet_address"
            echo ""
            print_message "$GREEN" "========================================="
            print_message "$GREEN" "✅ 설치가 완료되었습니다!"
            print_message "$GREEN" "========================================="
            print_message "$YELLOW" "입력한 정보가 저장되었습니다:"
            print_message "$YELLOW" "- 지갑 주소: ~/.nexus_manager/wallet_address"
            print_message "$YELLOW" "- NodeID는 등록 후 자동 저장됩니다"
            print_message "$YELLOW" ""
            print_message "$YELLOW" "유용한 명령어:"
            print_message "$YELLOW" "- 스크린 확인: screen -r nexus_node"
            print_message "$YELLOW" "- 스크린 분리: Ctrl+A, D"
            print_message "$GREEN" "========================================="
            ;;
        *)
            print_message "$RED" "잘못된 선택입니다!"
            return 1
            ;;
    esac
}

# 메뉴 2: 완전삭제
menu_uninstall() {
    print_message "$RED" "========================================="
    print_message "$RED" "⚠️  경고: 완전 삭제"
    print_message "$RED" "========================================="
    print_message "$RED" "모든 Nexus 관련 파일과 설정이 삭제됩니다!"
    echo ""
    read -p "정말로 삭제하시겠습니까? (yes 입력): " confirm
    
    if [[ $confirm != "yes" ]]; then
        print_message "$YELLOW" "삭제가 취소되었습니다."
        return
    fi
    
    # 스크린 세션 종료
    screen -X -S nexus_node quit 2>/dev/null || true
    
    # 프로세스 종료
    pkill -f nexus-network 2>/dev/null || true
    
    # 파일 삭제
    rm -rf ~/.nexus
    rm -f ~/.nexus_path
    rm -rf ~/.nexus_manager  # 저장된 정보도 삭제
    
    # PATH에서 제거
    if [[ $OS == "ubuntu" ]] || [[ $OS == "wsl_ubuntu" ]]; then
        sed -i '/\.nexus/d' ~/.bashrc
    elif [[ $OS == "macos" ]]; then
        sed -i '/\.nexus/d' ~/.zshrc 2>/dev/null || true
        sed -i '/\.nexus/d' ~/.bash_profile 2>/dev/null || true
    fi
    
    print_message "$GREEN" "Nexus가 완전히 삭제되었습니다!"
}

# 메뉴 3: 스크린 들어가기
menu_attach_screen() {
    if screen -list | grep -q "nexus_node"; then
        print_message "$YELLOW" "스크린 세션에 연결합니다..."
        print_message "$YELLOW" "들어간 후 스크린에서 빠져나올 땐 Ctrl + A + D 를 누르세요!!! 제발요!!!"
        sleep 2
        screen -r nexus_node
    else
        print_message "$RED" "실행 중인 넥서스 노드가 없습니다!"
    fi
}

# 메뉴 4: 스크린 다시켜기
menu_restart_screen() {
    if screen -list | grep -q "nexus_node"; then
        print_message "$YELLOW" "이미 실행 중인 넥서스 노드가 있습니다!"
        return
    fi
    
    # 저장된 NodeID 확인
    if [[ -f "$HOME/.nexus_manager/node_id" ]]; then
        NODE_ID=$(cat "$HOME/.nexus_manager/node_id")
        print_message "$YELLOW" "저장된 NodeID로 재시작합니다: $NODE_ID"
        start_with_nodeid "$NODE_ID"
    elif [[ -f "$HOME/.nexus/config.toml" ]]; then
        # config.toml에서 NodeID 확인
        NODE_ID=$(grep "node_id" "$HOME/.nexus/config.toml" 2>/dev/null | cut -d'"' -f2)
        if [[ -n "$NODE_ID" ]]; then
            print_message "$YELLOW" "설정 파일의 NodeID로 재시작합니다: $NODE_ID"
            start_with_nodeid "$NODE_ID"
        else
            print_message "$RED" "저장된 NodeID를 찾을 수 없습니다!"
        fi
    else
        print_message "$RED" "Nexus 설정을 찾을 수 없습니다! 먼저 설치를 진행하세요."
    fi
}

# 메뉴 5: 노드 ID 확인
menu_show_nodeid() {
    print_message "$YELLOW" "저장된 정보를 확인합니다..."
    
    # 먼저 저장된 파일에서 확인
    if [[ -f "$HOME/.nexus_manager/node_id" ]]; then
        NODE_ID=$(cat "$HOME/.nexus_manager/node_id")
        print_message "$GREEN" "========================================="
        print_message "$GREEN" "나의 Nexus 노드 ID:"
        print_message "$BLUE" "$NODE_ID"
        print_message "$GREEN" "========================================="
        print_message "$YELLOW" "(저장 위치: ~/.nexus_manager/node_id)"
    elif [[ -f "$HOME/.nexus/config.toml" ]]; then
        print_message "$YELLOW" "config.toml에서 확인 중..."
        NODE_ID=$(grep "node_id" "$HOME/.nexus/config.toml" 2>/dev/null | cut -d'"' -f2)
        if [[ -n "$NODE_ID" ]]; then
            # 찾았으면 저장
            mkdir -p ~/.nexus_manager
            echo "$NODE_ID" > ~/.nexus_manager/node_id
            print_message "$GREEN" "========================================="
            print_message "$GREEN" "나의 Nexus 노드 ID:"
            print_message "$BLUE" "$NODE_ID"
            print_message "$GREEN" "========================================="
        else
            print_message "$RED" "NodeID를 찾을 수 없습니다!"
        fi
    else
        print_message "$RED" "저장된 정보를 찾을 수 없습니다!"
        print_message "$YELLOW" "확인한 경로:"
        print_message "$YELLOW" "- ~/.nexus_manager/node_id"
        print_message "$YELLOW" "- ~/.nexus/config.toml"
        print_message "$YELLOW" ""
        print_message "$YELLOW" "먼저 넥서스를 설치하고 실행하세요."
    fi
}

# 메뉴 6: 지갑 주소 확인
menu_show_wallet() {
    print_message "$YELLOW" "저장된 정보를 확인합니다..."
    
    # 먼저 저장된 파일에서 확인
    if [[ -f "$HOME/.nexus_manager/wallet_address" ]]; then
        WALLET=$(cat "$HOME/.nexus_manager/wallet_address")
        print_message "$GREEN" "========================================="
        print_message "$GREEN" "나의 Nexus 지갑 주소:"
        print_message "$BLUE" "$WALLET"
        print_message "$GREEN" "========================================="
        print_message "$YELLOW" "(저장 위치: ~/.nexus_manager/wallet_address)"
    elif [[ -f "$HOME/.nexus/config.toml" ]]; then
        print_message "$YELLOW" "config.toml에서 확인 중..."
        WALLET=$(grep "wallet_address" "$HOME/.nexus/config.toml" 2>/dev/null | cut -d'"' -f2)
        if [[ -n "$WALLET" ]]; then
            # 찾았으면 저장
            mkdir -p ~/.nexus_manager
            echo "$WALLET" > ~/.nexus_manager/wallet_address
            print_message "$GREEN" "========================================="
            print_message "$GREEN" "나의 Nexus 지갑 주소:"
            print_message "$BLUE" "$WALLET"
            print_message "$GREEN" "========================================="
        else
            print_message "$RED" "지갑 주소를 찾을 수 없습니다!"
            print_message "$YELLOW" "NodeID로 실행한 경우 지갑 주소가 저장되지 않을 수 있습니다."
        fi
    else
        print_message "$RED" "저장된 정보를 찾을 수 없습니다!"
        print_message "$YELLOW" "확인한 경로:"
        print_message "$YELLOW" "- ~/.nexus_manager/wallet_address"
        print_message "$YELLOW" "- ~/.nexus/config.toml"
        print_message "$YELLOW" ""
        print_message "$YELLOW" "먼저 넥서스를 설치하고 실행하세요."
    fi
}

# NodeID로 시작
start_with_nodeid() {
    local node_id=$1
    local nexus_path=$(cat ~/.nexus_path 2>/dev/null || echo "$HOME/.nexus/bin")
    
    print_message "$BLUE" "NodeID로 Nexus를 시작합니다: $node_id"
    
    # NodeID 저장
    mkdir -p ~/.nexus_manager
    echo "$node_id" > ~/.nexus_manager/node_id
    
    screen -dmS nexus_node bash -c "
        source ~/.bashrc 2>/dev/null || true
        export PATH=\"$nexus_path:\$PATH\"
        
        if [[ -f \"$nexus_path/nexus-network\" ]]; then
            \"$nexus_path/nexus-network\" start --node-id $node_id
        else
            echo '오류: nexus-network를 찾을 수 없습니다!'
        fi
        
        echo '종료하려면 Enter를 누르세요...'
        read
    "
    
    sleep 2
    print_message "$GREEN" "Nexus 노드가 시작되었습니다!"
}

# 지갑 주소로 시작
start_with_wallet() {
    local wallet_address=$1
    local nexus_path=$(cat ~/.nexus_path 2>/dev/null || echo "$HOME/.nexus/bin")
    
    print_message "$BLUE" "지갑 주소로 Nexus를 등록합니다: $wallet_address"
    
    # 지갑 주소 저장
    mkdir -p ~/.nexus_manager
    echo "$wallet_address" > ~/.nexus_manager/wallet_address
    
    screen -dmS nexus_node bash -c "
        source ~/.bashrc 2>/dev/null || true
        export PATH=\"$nexus_path:\$PATH\"
        
        run_nexus() {
            local cmd=\$1
            shift
            if [[ -f \"$nexus_path/nexus-network\" ]]; then
                \"$nexus_path/nexus-network\" \$cmd \"\$@\"
            else
                echo '오류: nexus-network를 찾을 수 없습니다!'
                return 1
            fi
        }
        
        echo '단계 1: 사용자 등록 중...'
        if run_nexus register-user --wallet-address $wallet_address; then
            echo '사용자 등록 성공!'
            
            echo '단계 2: 노드 등록 중...'
            if run_nexus register-node; then
                echo '노드 등록 성공!'
                
                # 노드 등록 후 NodeID 추출 시도
                if [[ -f \"$HOME/.nexus/config.toml\" ]]; then
                    NODE_ID=\$(grep -oP 'node_id\s*=\s*\"\K[^\"]+' \"$HOME/.nexus/config.toml\" 2>/dev/null)
                    if [[ -n \"\$NODE_ID\" ]]; then
                        echo \"\$NODE_ID\" > ~/.nexus_manager/node_id
                    fi
                fi
                
                echo '단계 3: 노드 시작 중...'
                run_nexus start
            else
                echo '오류: 노드 등록 실패!'
            fi
        else
            echo '오류: 사용자 등록 실패!'
        fi
        
        echo '종료하려면 Enter를 누르세요...'
        read
    "
    
    sleep 2
    print_message "$GREEN" "Nexus 노드 등록이 시작되었습니다!"
}

# 메인 메뉴
show_main_menu() {
    clear
    print_message "$PURPLE" "========================================="
    print_message "$PURPLE" "    Nexus Node 설치 프로그램 V.katimad"
    print_message "$PURPLE" "========================================="
    print_message "$YELLOW" "📱 https://t.me/katimad (텔레그램 카티마드)"
    print_message "$PURPLE" "========================================="
    print_message "$GREEN" "환경: $OS_DISPLAY"
    print_message "$GREEN" ""
    print_message "$GREEN" "1. 넥서스 설치 : 넥서스 웹사이트 가입후에 NodeID 또는 지갑 주소(EVM) 둘 중 하나를 미리 준비하세요"
    print_message "$YELLOW" "2. 완전삭제 : 경고!! 모든 넥서스 관련 파일 삭제 됩니다. 주의하세요~!! 완전히 다시 설치하고 싶은사람만 삭제하세요"
    print_message "$GREEN" "3. 설치 후 로그보기 : 넥서스 스크린 들어가보기  (빠져나올때는 컨트롤+A+D 누르세요)"
    print_message "$GREEN" "4. 재실행 : 스크린 및 넥서스 다시 켜기 (실수로 넥서스 스크린을 종료 했을 경우 실행하세요)"
    print_message "$GREEN" "5. 나의 넥서스 노드 ID 확인"
    print_message "$GREEN" "6. 나의 넥서스 지갑주소 확인"
    print_message "$RED" "0. 종료"
    print_message "$PURPLE" "========================================="
    echo ""
}

# 메인 함수
main() {
    # 환경 감지
    OS=$(detect_environment)
    
    if [[ $OS == "unsupported" ]]; then
        print_message "$RED" "오류: 지원하지 않는 운영체제입니다!"
        print_message "$RED" "Ubuntu, MacOS, Windows WSL만 지원합니다."
        exit 1
    fi
    
    # 표시용 OS 이름
    case $OS in
        "ubuntu") OS_DISPLAY="Ubuntu" ;;
        "wsl_ubuntu") OS_DISPLAY="Windows WSL (Ubuntu)" ;;
        "macos") OS_DISPLAY="MacOS" ;;
    esac
    
    while true; do
        show_main_menu
        read -p "메뉴를 선택하세요: " choice
        
        case $choice in
            1) menu_install ;;
            2) menu_uninstall ;;
            3) menu_attach_screen ;;
            4) menu_restart_screen ;;
            5) menu_show_nodeid ;;
            6) menu_show_wallet ;;
            0) 
                print_message "$GREEN" "프로그램을 종료합니다."
                exit 0
                ;;
            *)
                print_message "$RED" "잘못된 선택입니다!"
                sleep 1
                ;;
        esac
        
        echo ""
        read -p "계속하려면 Enter를 누르세요..."
    done
}

# 스크립트 시작
main