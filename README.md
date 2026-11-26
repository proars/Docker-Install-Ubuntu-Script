# Docker Install Ubuntu Script

One script that installs **Docker Engine, Buildx and Docker Compose** on Ubuntu from Docker's official apt repository.

Supports Ubuntu **26.04, 25.10, 24.04 and 22.04** (64-bit).

Full write-up: [Docker install script for Ubuntu 26.04, 24.04 and 22.04](https://arstech.net/docker-install-ubuntu-script/)

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/proars/Docker-Install-Ubuntu-Script/main/docker_install.sh -o docker_install.sh
less docker_install.sh      # read it before running it as root
sudo bash docker_install.sh
```

On a disposable VM, if you don't care about reading it first:

```bash
curl -fsSL https://raw.githubusercontent.com/proars/Docker-Install-Ubuntu-Script/main/docker_install.sh | sudo bash
```

## What it does

1. Checks that you're on Ubuntu and on a release Docker supports.
2. Removes conflicting packages if present: `docker.io`, `docker-compose`, `docker-compose-v2`, `docker-doc`, `docker-buildx`, `podman-docker`, `containerd`, `runc`.
3. Deletes `docker.list` and `docker.gpg` left by older install guides (and by the 2022/2023 version of this script).
4. Adds Docker's GPG key to `/etc/apt/keyrings/docker.asc`.
5. Adds the repository as `/etc/apt/sources.list.d/docker.sources` (deb822 format).
6. Installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`.
7. Enables `docker` and `containerd` on boot.
8. Prints versions and runs `hello-world`.

It does **not** add your user to the `docker` group unless you ask (see below).

## Options

Set these as environment variables after `sudo`:

| Variable | Effect |
|---|---|
| `ADD_USER=1` | Add the user who ran `sudo` to the `docker` group |
| `SKIP_TEST=1` | Skip the `hello-world` test container |
| `FORCE=1` | Continue on an Ubuntu release the script doesn't recognize |

```bash
sudo ADD_USER=1 bash docker_install.sh
sudo SKIP_TEST=1 bash docker_install.sh
```

## Upgrading from the old version of this script

If you used the old one-liner (`wget ... | bash`), your machine has `/etc/apt/sources.list.d/docker.list` and `/etc/apt/keyrings/docker.gpg`. Following Docker's current instructions on top of that makes `apt update` fail with:

```text
E: Conflicting values set for option Signed-By regarding source https://download.docker.com/linux/ubuntu/ ...
```

Just run the new script. It removes the old files before adding the new repository. After that, Docker updates with the rest of the system:

```bash
sudo apt update && sudo apt upgrade
```

## Two things to know

**The `docker` group is root.** Anyone in it can mount `/` into a container and edit the host. Fine on a personal dev box, not on a shared server. Use `sudo docker` or [rootless mode](https://docs.docker.com/engine/security/rootless/) there.

**Published ports bypass ufw.** `-p 9000:9000` is reachable from the internet even if ufw blocks 9000. Bind admin UIs to localhost (`-p 127.0.0.1:9000:9000`) or put them behind a reverse proxy.

## Check the install

```bash
docker --version
docker compose version
docker buildx version
sudo systemctl is-enabled docker
```

## Uninstall

This removes Docker **and all images, containers and volumes**:

```bash
sudo apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker /var/lib/containerd
sudo rm -f /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc
```

## Notes

- Ubuntu derivatives (Linux Mint, Pop!_OS) are not supported by this script. Docker doesn't officially support them either.
- Based on Docker's official guide: [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/).
- Issues and pull requests welcome.

More self-hosting guides at [arstech.net](https://arstech.net/).
