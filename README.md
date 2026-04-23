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
- `-F`: Force clean (destroys jail if creation or mounting fails).
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

### Example Configuration (`jail.example.conf`):
```text
#!SETTINGS
priority 50
allow.mlock 1

#!MOUNTS
"/usr/local/bastille/jails/mainjail/root/usr/local" "/usr/local" ro
"/home/app1" "/root" rw
"/home/my\ music" "/mnt/music" rw 0 0

#!TEMPLATES
user/skeljail
user/my-custom-template

#!SYSRC
nginx_enable="YES"

#!CMD
pw useradd checker -u 1001 -d /nonexistent -s /sbin/nologin
echo "* * * * * /root/lazy-check-that-thing.sh" | crontab -u checker -
```

---

## What it Does
- **Validates `config.conf`**: Ensures `BASTILLE_ROOT`, `TEMPLATE`, and `RELEASE` exist as directories.
- **Validates Interface**: Checks if the interface (`-I`) exists on the host.
- **Bridge Check**: Verifies the interface is actually a bridge if `-B` is passed.
- **Network Exclusivity**: Prevents using both `-B` and `-V` at the same time.
- **Force Clean (`-F`)**: Removes jail with `bastille destroy -f` after a failed create, mount, or template.

---

## Roadmap
See [ROADMAP.md](./ROADMAP.md) for planned features and improvements.
