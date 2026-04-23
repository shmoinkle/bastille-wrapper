# Bastille Wrapper

![FreeBSD](https://img.shields.io/badge/FreeBSD-%23AB2B28?style=for-the-badge&logo=freebsd&logoColor=white)
![BastilleBSD](https://img.shields.io/badge/BastilleBSD-%23007ACC?style=for-the-badge&logo=freebsd&logoColor=white)
![XigmaNAS](https://img.shields.io/badge/XigmaNAS-%23F08521?style=for-the-badge&logo=freebsd&logoColor=white)

An orchestration wrapper for bastille to simplify the creation of a jail, given you have a list of things you plan to do with the jail after you make it.

## Usage

```bash
./bastille-wrapper.sh -n NAME -i IP [options]
```

### Options
- `-n NAME`: Jail name
- `-i IP`: Jail IP address (CIDR or 'DHCP').
- `-I IF`: Network interface (default in `config.conf`).
- `-R RELEASE`: FreeBSD release (default in `config.conf`).
- `-C FILE`: Consolidated configuration file (see below).
- `-b`: Enable boot after creation (default is `--no-boot`).
- `-B`: Bridge mode (requires a bridge interface).
- `-D`: Enable IPv4 and IPv6.
- `-M`: Static MAC address.
- `-V`: VNET mode.
- `-x`: Restart jail after creation.

---

## Configuration

- Define mounts, settings, `sysrc`, templates, and post-creation commands.
- Each section starts with `#!` header in ALL CAPS.
- A section ends when an empty line or a line starting with `#!` is encountered.

### Sections
- `#!SETTINGS`: Key-value pairs for `bastille config`.
- `#!MOUNTS`: Mount definitions (passed directly to `bastille mount`).
- `#!SYSRC`: Service configurations (uses `bastille sysrc`).
- `#!TEMPLATES`: Bastille templates to apply in order.
- `#!CMD`: Commands to execute IN jail.

## Example

### The command
- This will spin up your new jail **app1** with your blueprint **app1.conf**
```bash
bastille-wrapper.sh -bBDMx -n app1 -i 10.0.0.40/24 -I bridge1 -C app1.conf
```

### Jail Configuration File
- **app1.conf's** contents _(**jail.example.conf** is used in this example)_
```bash
#!SETTINGS
priority 50
allow.mlock 1

#!MOUNTS
tmpfs tmp tmpfs rw,nosuid,noexec,mode=01777 0 0
/usr/local/bastille/jails/mainjail/root/usr/local /usr/local nullfs ro 0 0
/home/app1 /root nullfs rw 0 0
# mount application configurations
/home/app1/configs /etc/app1 nullfs rw 0 0
"/home/app1/music\ files" /mnt/music nullfs rw 0 0

#!SYSRC
nginx_enable="YES"
php_fpm_enable="YES"

#!TEMPLATES
user/skeljail
user/my-custom-template

#!CMD
pw useradd checker -u 1001 -d /nonexistent -s /sbin/nologin
echo "* * * * * /root/lazy-check-that-thing.sh" | crontab -u checker -

```

### Result
- This is the the list of commands that will be run to make **app1**
```bash
bastille create -B -M -D app1 14.3-RELEASE 10.0.0.40/24 bridge1
bastille config app1 set priority 50
bastille config app1 set allow.mlock 1
bastille mount app1 tmpfs tmp tmpfs rw,nosuid,mode=01777 0 0
bastille mount app1 /usr/local/bastille/jails/mainjail/root/usr/local /usr/local nullfs ro 0 0
bastille mount app1 /home/app1 /root nullfs rw 0 0
bastille mount app1 /home/app1/configs /etc/app1 nullfs rw 0 0
bastille mount app1 "/home/app1/music\ files" /mnt/music nullfs rw 0 0
bastille sysrc app1 nginx_enable="YES"
bastille sysrc app1 php_fpm_enable="YES"
bastille template app1 user/skeljail
bastille template app1 user/my-custom-template
bastille template app1 me/skeljail
bastille cmd app1 /bin/sh -c "pw useradd checker -u 1001 -d /nonexistent -s /sbin/nologin"
bastille cmd app1 /bin/sh -c "echo \"* * * * * /root/lazy-check-that-thing.sh\" | crontab -u checker -"
bastille restart app1
```

---

## What it Does
- **Validates `config.conf`**: Ensures `BASTILLE_ROOT` and `RELEASE` exist as directories.
- **Validates Interface**: Checks if the interface (`-I`) exists on the host.
- **Bridge Check**: Verifies the interface is actually a bridge if `-B` is passed.
- **Network Exclusivity**: Prevents using both `-B` and `-V` at the same time.

## What it Doesn't Do
- **Error Handling**: If the script fails to create the jail or a mount fails, the script will exit immediately.
	- It will _not_ attempt to fix or clean.
	- It will _not_ stop on settings, sysrc, or command task errors.
	- You'll have to assess the errors and make the choice to `bastille destroy` and start over or apply some fixes manually.

## Todo / Nice to have's
- **Order of Operations**: Configure execution order for different tasks (e.g., applying templates before mounts or CMDs).
- **Dynamic Configuration (`#!ARG`)**: Allow host-side command execution to populate variables for use in `CMD` or `SETTINGS`.
	- *Example*: `#!ARG` -> `newuser=$(whoami)` then in `CMD` use `pw useradd $newuser`
- **More Validation**: Catch things like malformed jail names and IP addrs (and **ARGS** so we try our best to not bork the host).
- **Future Orchestration**: Support for more **bastille** commands.