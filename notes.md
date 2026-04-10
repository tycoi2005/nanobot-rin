# server: 

ssh ssh-url

## install python packages

apt install python3-pip
apt install python3.13-venv pyenv
pyenv install 3.13

## create vitual environment

python3 -m venv /root/.pyenv/nanobot
source /root/.pyenv/nanobot/bin/activate

## install nanobot

pip install nanobot-ai

## use gmail to register openrouter and get api key

## init setup

nanobot onboard --wizard


$ which nanobot
/root/.pyenv/nanobot/bin/nanobot

mkdir ~/.config/systemd/user/ -p 

vim ~/.config/systemd/user/nanobot-gateway.service

```
[Unit]
Description=Nanobot Gateway
After=network.target

[Service]
Type=simple
Environment="VIRTUAL_ENV=/root/.pyenv/nanobot"
Environment="PATH=/root/.pyenv/nanobot/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=%h/.local/bin/nanobot gateway
Restart=always
RestartSec=10
NoNewPrivileges=yes
ProtectSystem=strict
ReadWritePaths=%h

[Install]
WantedBy=default.target
```

replace ExecStart with nanobot link

add config:

{
  "tools": {
    "exec": {
      "allowedEnvKeys": ["PATH", "VIRTUAL_ENV"]
    }
  }
}

Enable and start:

systemctl --user daemon-reload
systemctl --user enable --now nanobot-gateway


Common operations:

systemctl --user status nanobot-gateway        # check status
systemctl --user restart nanobot-gateway       # restart after config changes
journalctl --user -u nanobot-gateway -f        # follow logs

## Backup

Backup the remote `~/.nanobot/` folder to `./backups/nanobot-backup/` using git for deduplication:

```bash
bash scripts/backup.sh
```

- Excludes: `node_modules/`, `whatsapp-auth/`, `bridge/`, `.env`, `*.log`, caches
- Shows a file list before committing — type `y` to confirm
- Only changed files are stored (git diff-based, no duplicates)
- View history: `cd backups/nanobot-backup && git log --oneline`
