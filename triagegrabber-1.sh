#!/bin/bash

# Linux Triage Script 
# Created by: Julian Lindsey
# 10/12/2024
# Used in combination with an IP address to capture all relevant information for blue teaming

clear

user=$1
ip=$2
verbose=$3

# Function to handle verbose output
vprint() {
  if [ "$verbose" = "-v" ]; then
    echo "$1"
  fi
}

# Verify that user and ip arguments are provided
if [ -z "$user" ] || [ -z "$ip" ]; then
  echo "Error: User and IP address must be provided."
  echo "Usage: ./triagegrabber-1.sh [user] [ip]"
  echo "Adding '-v' to the end is optional"
  exit 1
fi

echo "Would you like to create an SSH key? (Y)es or (N)o"
read option
if [ "$option" = "Yes" ] || [ "$option" = "Y" ] || [ "$option" = "y" ] || [ "$option" = "yes" ]; then
  echo "Generating SSH key..."
  yes '' | ssh-keygen -t rsa -f ~/.ssh/id_rsa
  echo "SSH key generated and placed in ~/.ssh/"
  cat ~/.ssh/id_rsa.pub | ssh $user@$ip 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
else
  echo "Continuing without SSH key..."
fi

echo "Triaging $ip..."

# Making directory for system information and adding all information into it
if [ ! -d "$2" ]; then
  mkdir $2 && cd $2
else
  cd $2
fi

echo ""
echo "Capturing all system information..."
touch sysinfo.txt
vprint "OS information..."
echo "//OS information" >> sysinfo.txt
ssh $user@$ip "uname -a" >> sysinfo.txt
echo "" >> sysinfo.txt

vprint "Viewing OS Release..."
echo "//OS Release" >> sysinfo.txt
ssh $user@$ip "cat /etc/os-release" >> sysinfo.txt
echo "" >> sysinfo.txt

vprint "Total uptime..."
echo "//Total uptime" >> sysinfo.txt
ssh $user@$ip "uptime" >> sysinfo.txt
echo "" >> sysinfo.txt

vprint "Time/Date of the machine..."
echo "//Time/Date of the machine" >> sysinfo.txt
ssh $user@$ip "timedatectl" >> sysinfo.txt
echo "" >> sysinfo.txt

vprint "Mount devices on the machine..."
echo "//Mount devices on the machine" >> sysinfo.txt
ssh $user@$ip "mount" >> sysinfo.txt
echo "" >> sysinfo.txt

vprint "Environment variables on the machine..."
echo "//Environment variables on the machine" >> sysinfo.txt
ssh $user@$ip "echo $PATH" >> sysinfo.txt
echo "" >> sysinfo.txt

echo "System information complete!"
echo ""

# Capturing all user information
echo "Capturing all user information..."
touch userinfo.txt

vprint "Grabbing logged in users..."
echo "//Logged in users" >> userinfo.txt
ssh $user@$ip "w" >> userinfo.txt
echo "" >> userinfo.txt

vprint "Finding if a user has ever logged in remotely..."
echo "//If a user has logged in remotely" >> userinfo.txt
ssh $user@$ip lastlog >> userinfo.txt
echo "" >> userinfo.txt
ssh $user@$ip last >> userinfo.txt
echo "" >> userinfo.txt

vprint "Grabbing failed logins..."
echo "//View failed logins" >> userinfo.txt
ssh $user@$ip faillog -a >> userinfo.txt
echo "" >> userinfo.txt

vprint "Grabbing local user accounts..."
echo "//Local user accounts" >> userinfo.txt
ssh $user@$ip cat /etc/passwd >> userinfo.txt
echo "" >> userinfo.txt
ssh $user@$ip cat /etc/shadow >> userinfo.txt
echo "" >> userinfo.txt

vprint "Grabbing local groups..."
echo "//Local groups" >> userinfo.txt
ssh $user@$ip cat /etc/group >> userinfo.txt
echo "" >> userinfo.txt

vprint "Viewing who has sudo access..."
echo "//Sudo access" >> userinfo.txt
ssh $user@$ip cat /etc/sudoers >> userinfo.txt
echo "" >> userinfo.txt

vprint "Viewing accounts with UID 0..."
echo "//Accounts with UID 0" >> userinfo.txt
ssh $user@$ip "awk -F: '(\$3 == \"0\") {print}' /etc/passwd" >> userinfo.txt
echo "" >> userinfo.txt

vprint "Seeing who has root authorized SSH key authentications..."
echo "//Root authorized SSH key authentications" >> userinfo.txt
ssh $user@$ip cat /root/.ssh/authorized_keys >> userinfo.txt
echo "" >> userinfo.txt

vprint "Seeing what files are opened by $user..."
echo "//List of files opened by user" >> userinfo.txt
ssh $user@$ip lsof -u $user >> userinfo.txt
echo "" >> userinfo.txt

vprint "Viewing root bash history..."
echo "//Viewing root user bash history" >> userinfo.txt
if ssh $user@$ip test -f /root/.bash_history; then
  ssh $user@$ip cat /root/.bash_history >> userinfo.txt
else
  echo "/root/.bash_history file does not exist, continuing..." >> userinfo.txt
  vprint "/root/.bash_history file does not exist, continuing..."
fi
echo "User information complete!"
echo ""

# Capturing all network information
echo "Capturing all network information..."
touch networkinfo.txt

vprint "Viewing network interfaces..."
echo "//Network interfaces" >> networkinfo.txt
ssh $user@$ip ifconfig >> networkinfo.txt
echo "" >> networkinfo.txt

vprint "Viewing network connections..."
echo "//Network connections" >> networkinfo.txt
ssh $user@$ip netstat -antup >> networkinfo.txt
echo "" >> networkinfo.txt

vprint "View listening ports..."
echo "//Listening ports" >> networkinfo.txt
ssh $user@$ip netstat -nap >> networkinfo.txt
echo "" >> networkinfo.txt

vprint "Viewing routes..."
echo "//Routes" >> networkinfo.txt
ssh $user@$ip route >> networkinfo.txt
echo "" >> networkinfo.txt

vprint "Viewing ARP table..."
echo "//Arp table" >> networkinfo.txt
ssh $user@$ip arp -a >> networkinfo.txt
echo "" >> networkinfo.txt

vprint "Viewing processes listening on ports..."
echo "//Processes listening on ports" >> networkinfo.txt
ssh $user@$ip lsof -i >> networkinfo.txt
echo "Network information complete!"
echo ""

# Capturing all service information
echo "Capturing all service information..."
touch serviceinfo.txt

vprint "Viewing processes..."
echo "//Processes" >> serviceinfo.txt
ssh $user@$ip ps -aux >> serviceinfo.txt
echo "" >> serviceinfo.txt

vprint "Listing load modules..."
echo "//Load modules" >> serviceinfo.txt
ssh $user@$ip lsmod >> serviceinfo.txt
echo "" >> serviceinfo.txt

vprint "Listing open files..."
echo "//Open files" >> serviceinfo.txt
ssh $user@$ip lsof >> serviceinfo.txt
echo "" >> serviceinfo.txt

vprint "Listing open files using the network..."
echo "//Open files using the network" >> serviceinfo.txt
ssh $user@$ip "lsof -nPi | cut -f 1 -d ' ' | uniq | tail -n +2 >/dev/null 2>&1 || true" >> serviceinfo.txt
echo "" >> serviceinfo.txt

vprint "Listing unlinked processes running..."
echo "//Unlinked processes running" >> serviceinfo.txt
ssh $user@$ip lsof +L1 >> serviceinfo.txt
echo "" >> serviceinfo.txt

vprint "Listing services..."
echo "//Services" >> serviceinfo.txt
ssh $user@$ip "chkconfig --list >/dev/null 2>&1 || true" >> serviceinfo.txt
echo "Service information complete! Recommend using less +F /var/log/messages to continue monitoring logs!"
echo ""

# Capturing policy information
echo "Capturing all policy information..."
touch policyinfo.txt

vprint "Viewing pam.d files..."
echo "//Pam.d files" >> policyinfo.txt
for file in /etc/pam.d/common*; do
  echo "File: $file" >> policyinfo.txt
  cat "$file" >> policyinfo.txt
  echo -e "\n\n" >> policyinfo.txt
done
echo "Policy information complete!"
echo ""


# Capturing autorun and autoload information
echo "Capturing all autorun and autoload information..."
touch autoinfo.txt

vprint "Listing cron jobs..."
echo "//Cron jobs" >> autoinfo.txt
ssh $user@$ip crontab -l >> autoinfo.txt 2>/dev/null
echo "" >> autoinfo.txt

vprint "Listing cron jobs by root and other UID 0 accounts..."
echo "//Cron jobs by root and other UID 0 accounts" >> autoinfo.txt
ssh $user@$ip crontab -u root -l >> autoinfo.txt 2>/dev/null
echo "" >> autoinfo.txt

vprint "Reviewing for unusual cron jobs..."
echo "//Unusual cron jobs" >> autoinfo.txt
ssh $user@$ip cat /etc/crontab >> autoinfo.txt
echo "" >> autoinfo.txt
ssh $user@$ip ls /etc/cron.* >/dev/null 2>&1 >> autoinfo.txt
echo "Autorun and Autoload information complete! Remember to keep monitoring for anything malicious..."
echo ""


# Capturing log information
echo "Capturing all log information..."
touch loginfo.txt

vprint "Viewing root user command history..."
echo "//Root user command history" >> loginfo.txt
ssh $user@$ip cat /root/.*history >> loginfo.txt
echo "" >> loginfo.txt

vprint "Viewing last logins..."
echo "//Last logins" >> loginfo.txt
ssh $user@$ip last >> loginfo.txt

# Directory to store logs on the host machine
LOG_DIR="./remote_logs"
# Create the directory if it doesn't exist
mkdir -p $LOG_DIR
# Find all .log files on the remote server and store them in a temporary file
ssh $user@$ip 'find /var/log -type f -name "*.log"' > log_files.txt
vprint "Downloading logs... (This will take a while)"
# Download each .log file to the host machine, silencing scp output
while IFS= read -r log_file; do
  scp $user@$ip:"$log_file" "$LOG_DIR/$(basename "$log_file")" >/dev/null 2>&1
done < log_files.txt
# Clean up
rm log_files.txt
echo "Log files have been collected and stored in $LOG_DIR."
echo "Log information complete! Make sure to go and backup logs specific to services"
echo ""


# Capturing files, drives, and shares information
echo "Capturing all files, drives, and shares information..."
touch filesinfo.txt

vprint "Viewing disk space..."
echo "//Disk space" >> filesinfo.txt
ssh $user@$ip df -ah >> filesinfo.txt
echo "" >> filesinfo.txt

vprint "Viewing directory listing of /etc/init.d..."
echo "//Directory listing of /etc/init.d" >> filesinfo.txt
ssh $user@$ip ls -la /etc/init.d >> filesinfo.txt
echo "" >> filesinfo.txt

vprint "Looking for immutable files... (This will take a while...)"
echo "//Immutable files" >> filesinfo.txt
ssh $user@$ip lsattr -R / >/dev/null 2>&1 | grep "\-i-"  >> filesinfo.txt
echo "" > filesinfo.txt

vprint "Listing directory for /root..."
echo "//Root directory" >> filesinfo.txt
ssh $user@$ip ls -al /root >/dev/null 2>&1 >> filesinfo.txt
echo "" >> filesinfo.txt

vprint "Looking for files recently modified in current directory..."
echo "//Recently modified files" >> filesinfo.txt
ssh $user@$ip ls -alt  | head  >> filesinfo.txt
echo "" >> filesinfo.txt

vprint "Looking for world writable files..."
echo "//World writable files" >> filesinfo.txt
ssh $user@$ip "find / -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print" >> filesinfo.txt
echo "" >> filesinfo.txt

vprint "Looking for files with no user owner..."
echo "//Files with no user owner" >> filesinfo.txt
ssh $user@$ip find / -nouser 2>/dev/null >> filesinfo.txt
echo "" >> filesinfo.txt

vprint "Listing all files and attributes... (This will take a while!!!)"
echo "//All files and attributes" >> filesinfo.txt
ssh $user@$ip find / -printf "%m;%Ax;%AT;%Tx;%TT;%Cx;%CT;%U;%G;%s;%p\n" 2>/dev/null >> filesinfo.txt
echo "" >> filesinfo.txt

vprint "Listing files over 100MB..."
echo "//Files over 100MB" >> filesinfo.txt
ssh $user@$ip "find / -size +100000k -print 2>/dev/null" >> filesinfo.txt
echo "" >> filesinfo.txt

echo "File, drive, and share information complete! It is imperative to look into any file share if present."
echo "All information capture complete! Check this directory and look for $ip for all information."