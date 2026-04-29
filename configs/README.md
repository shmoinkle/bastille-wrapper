# Configuration Examples

This directory contains configuration blueprints for orchestrating jails with `bastille-wrapper`. While some `.example.conf` files are purely fabricated examples, the following ones are real-world examples of complex deployments.

## FlareSolverr (`flaresolverr.example.conf`)

This configuration orchestrates a FlareSolverr jail that works out of the box with one command.

`bastille-wrapper.sh -cbDx -n flare -i 192.168.1.254/24 -I em0 -C flaresolverr.example.conf`

- **Environment Setup**: Configures system settings (`sysvipc`) and basic services.
- **X11 & Browser Stack**: Installs `chromium`, `xorg-vfbserver`, and `python313` 
- **Custom Launch Script**: Copies and configures a specialized launcher script (`assets/flaresolverr.launcher.sh`) to manage it.
    - I couldn't squeeze this stack into a native `rc.d` script, so this deployment relies on `flaresolverr.launcher.sh`.
    - It handles starting the Xvfb (virtual frame buffer) and running the application within its virtual environment.
- **Application Configuration**:
    - Creates a dedicated `flaresolverr` user.
    - Clones the repository and initializes a Python Virtual Environment (`venv`).
    - Installs dependencies via `pip`.
- **Persistence**: Configures `crontab` entries to ensure the service starts on boot and remains running via the launcher script.Example