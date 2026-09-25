#!/usr/bin/env fish

set host $argv[1]
set version $argv[2]

if test -z "$host"
    echo "Usage: extract-ma-credentials.fish <ssh-host> [ma-version]" >&2
    echo "  e.g. extract-ma-credentials.fish augusto@home.local 2.10.3" >&2
    exit 1
end

if test -z "$version"
    set version "2.10.3"
end

set image "ghcr.io/music-assistant/server:$version"
set container ma-secrets-tmp
set tmpdir (mktemp -d)

function cleanup --on-event fish_exit
    rm -rf $tmpdir
    podman rm $container 2>/dev/null
end

echo "Pulling $image..."
podman pull $image

echo "Extracting app_secrets.json..."
podman create --name $container $image >/dev/null
podman cp "$container:/app/venv/lib/python3.14/site-packages/music_assistant/helpers/app_secrets.json" "$tmpdir/app_secrets.json"

echo "Decoding to plaintext app_vars.json..."
python3 -c "
import json, base64, hmac, hashlib

data = json.load(open('$tmpdir/app_secrets.json'))
salt = base64.b64decode(data['salt'])
tag = b'music-assistant/app-vars/v1'

def decode(salt, name, token):
    raw = base64.b64decode(token)
    seed = b'\\x00'.join((salt, name.encode(), tag))
    out, ctr = bytearray(), 0
    while len(out) < len(raw):
        out += hmac.new(seed, ctr.to_bytes(4, 'big'), hashlib.sha256).digest()
        ctr += 1
    return bytes(b ^ k for b, k in zip(raw, out[:len(raw)])).decode()

result = {name: decode(salt, name, tok) for name, tok in data['secrets'].items()}
json.dump(result, open('$tmpdir/app_vars.json', 'w'))
print('Decoded keys:', ', '.join(result.keys()))
"

echo "Copying to $host..."
scp "$tmpdir/app_vars.json" "$host:/tmp/app_vars.json"
ssh $host 'sudo mkdir -p /etc/music-assistant && sudo mv /tmp/app_vars.json /etc/music-assistant/app_vars.json && sudo chmod 644 /etc/music-assistant/app_vars.json'

echo "Cleaning up image..."
podman rmi $image >/dev/null

echo "Done. Restart music-assistant:"
echo "  ssh $host 'sudo systemctl restart music-assistant'"
