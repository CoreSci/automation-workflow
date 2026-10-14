# Docker cleanup: reclaiming disk space safely

Docker keeps everything it has ever pulled or built until told otherwise: stopped containers, old images, unused volumes and networks, and build cache. On a Windows PC with Docker Desktop, all of it lives inside one virtual disk that grows but doesn't shrink on its own. This is the short list of commands to see what's using space and remove it, from safest to most thorough.

> **Before deleting volumes:** a volume can hold the only copy of a database or other data. Images and stopped containers can be rebuilt or re-pulled, but a deleted volume is gone. The commands below that touch volumes are marked ⚠️.

## 1. See what's using space

```bash
docker system df            # totals per type: images, containers, volumes, build cache, with RECLAIMABLE
docker system df -v         # the same, item by item
```

## 2. Remove unused things with the `prune` commands

Each `prune` asks for confirmation (skip it with `-f`) and reports the space reclaimed.

| Command | Removes | Keeps |
|---|---|---|
| `docker container prune` | All **stopped** containers | Running containers |
| `docker image prune` | **Dangling** images (untagged `<none>` layers left by rebuilds) | Every tagged image |
| `docker image prune -a` | All images **not used by any container** | Images used by any container, even a stopped one |
| `docker network prune` | Networks no container uses | The default `bridge`, `host` and `none` networks |
| ⚠️ `docker volume prune` | Unused **anonymous** volumes (Docker Engine 23+). Add `-a` to include unused **named** volumes | Volumes attached to any container |
| `docker builder prune` | Build cache | Nothing else |
| `docker system prune` | Stopped containers, unused networks, dangling images and build cache, in one go | Volumes, unless you add the next flag |
| ⚠️ `docker system prune -a --volumes` | All of the above, plus every unused image and unused anonymous volumes | Only what running or stopped containers use |

A good routine: `docker system df`, then `docker system prune`, then check `docker system df` again. Use `-a` and `--volumes` only when you've looked at what they'll remove.

Filters narrow a prune down, e.g. only things older than a week:

```bash
docker image prune -a --filter "until=168h"
docker container prune --filter "until=24h"
```

## 3. Remove specific items

```bash
docker ps -a                       # all containers, including stopped
docker rm <container>              # remove one (add -f to stop and remove a running one)
docker images                      # all images
docker rmi <image>                 # remove one
docker volume ls                   # all volumes
docker volume rm <volume>          # ⚠️ remove one
```

The older one-liners that feed one command's output into another still work, in bash, WSL or Git Bash:

```bash
docker rm $(docker ps -aq --filter "status=exited")               # all exited containers
docker rmi $(docker images -q --filter "dangling=true")           # all dangling images
```

The same in **PowerShell**:

```powershell
docker ps -aq --filter "status=exited" | ForEach-Object { docker rm $_ }
docker images -q --filter "dangling=true" | ForEach-Object { docker rmi $_ }
```

In most cases, though, the matching `prune` command does the same job in one step, and is safer.

## 4. Shrinking Docker Desktop's disk on Windows

Pruning frees space *inside* Docker's virtual disk, but Windows may not see the file get smaller right away.

- **Docker Desktop → Troubleshoot → Clean / Purge data** resets Docker completely: **every** image, container and volume is deleted.
- **Settings → Resources → Advanced → Disk image location / size** shows where the virtual disk lives, and lets you move it to a larger drive.
- On the WSL 2 backend, the disk is a `.vhdx` file that can stay large after a prune. To compact it, quit Docker Desktop, run `wsl --shutdown`, then use `diskpart` from an administrator prompt, with the `.vhdx` path from the setting above:

  ```
  diskpart
  select vdisk file="<disk image location>\<name>.vhdx"
  attach vdisk readonly
  compact vdisk
  detach vdisk
  exit
  ```

  Only compact while Docker Desktop and WSL are stopped. See also the `diskpart` notes in the network-infrastructure repo.

Guides from the Docker Toolbox era resize a `docker-machine` VirtualBox disk instead. Docker Desktop replaced that setup, and `docker-machine` is no longer maintained, so those steps don't apply.

## Credits

Adapted and updated from the widely shared GitHub gist [*docker cleanup guide: containers, images, volumes, networks*](https://gist.github.com/bastman/5b57ddb3c11942094f8d0a97d461b430) by **bastman**. It in turn credits [chadoe/docker-cleanup-volumes](https://github.com/chadoe/docker-cleanup-volumes) and a [Stack Overflow answer on removing old Docker images](https://stackoverflow.com/questions/32723111/how-to-remove-old-and-unused-docker-images). This version adds the `prune` commands, PowerShell equivalents and the Docker Desktop notes, and drops the obsolete `docker-machine` steps.
