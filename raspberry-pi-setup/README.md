# Raspberry Pi setup: kiosk GUI, LAMP/WordPress web interface, boot automation

The setup runbook for the Raspberry Pi 3 that acts as the host for the Arduino **System Controller** (see the `arduino-showcase` repo). It covers the display, OS maintenance, a LAMP + WordPress web interface, and starting the control GUI automatically at boot.

**Problem it solves:** rebuilding a headless or kiosk Pi from memory is error-prone. This runbook makes the setup repeatable.

> **Credentials must be supplied by the user.** Every host address, username and password below is a placeholder. Real values belong in your own local `.env` (template: `.env.example`) or a password manager, never in this repo.

## 1. Display and base system

```bash
# Rotate the official 7" touchscreen 180° (add to /boot/config.txt)
sudo nano /boot/config.txt
lcd_rotate=2

# Interactive configuration (locale, interfaces, serial port, SSH...)
sudo raspi-config

# Update
sudo apt update
sudo apt full-upgrade

# Remove software
sudo apt-get remove  <package>
sudo apt-get purge   <package>
sudo apt-get clean
```

## 2. Network

Give the Pi fixed addresses (router DHCP reservation or `/etc/dhcpcd.conf`) and keep them in your local notes:

| Interface | Address |
|---|---|
| Wi-Fi | `${PI_WIFI_IP}` |
| Ethernet (direct link) | `${PI_LAN_IP}` |

## 3. Accounts (placeholders only)

| Account | Username | Password |
|---|---|---|
| Pi OS user | `${PI_USER}` | `${PI_PASSWORD}` |
| MySQL / MariaDB (WordPress DB) | `${MYSQL_USER}` | `${MYSQL_PASSWORD}` |
| WordPress admin | `${WP_ADMIN_USER}` | `${WP_ADMIN_PASSWORD}` |
| WordPress admin email | `${WP_ADMIN_EMAIL}` | |

Use a different, strong password for each account. Change the default Pi password on first boot (`passwd`).

## 4. Web interface (LAMP + WordPress)

After installing Apache, PHP, MariaDB and WordPress, finish the install in a browser at `http://localhost/wp-admin`. `wordpress-install-redacted.jpg` shows the install screen with the credential fields redacted. **Discourage search engines** stays ticked, because this is a LAN-only control interface.

To enable CGI scripts, used for simple control endpoints called over HTTP:

```bash
sudo a2enconf serve-cgi-bin
sudo a2enmod cgi
sudo systemctl restart apache2

# test an endpoint from the terminal
curl 'http://localhost/cgi-bin/<script>.sh'
```

## 5. Shell scripts

```bash
#!/bin/sh                         # first line of every script
sudo chmod +x "scriptName.sh"     # make it executable
./scriptName.sh                   # run it
cp file.sh file_backup.sh         # copy / back up
```

## 6. Start the control GUI at boot

```bash
# Desktop session autostart (LXDE)
sudo nano /etc/xdg/lxsession/LXDE-pi/autostart
@/usr/bin/python3 /home/pi/Desktop/guiCustom.py

# Or with cron at boot (the optional delay waits for the network and serial devices)
sudo crontab -e
@reboot /home/pi/myProgram
@reboot sleep 60 && /home/pi/myProgram
```
