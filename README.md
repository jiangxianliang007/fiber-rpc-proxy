# Fiber RPC proxy

NGINX + Lua filters restricted Fiber RPC methods and authenticates upstream requests using a server-side Biscuit token. Clients do not need the upstream token. This is a shared public RPC proxy, not a tenant-authenticated LSP gateway.

## Configuration

1. Enable `rpc.biscuit_public_key` on Fiber. Keep the backend RPC private and reachable only from trusted hosts.
2. Generate a dedicated least-privilege Biscuit token using the [Fiber authentication guide](https://github.com/nervosnetwork/fiber/blob/develop/docs/biscuit-auth.md). For a public read-only proxy, start with:

```
read("node");
read("graph");
```

Grant other read permissions only if their data is intended to be public. Do not use an admin, tenant, or write-capable token for this public proxy.
3. Replace the example upstream address `192.168.1.100:8117` in `nginx.conf` and create a local `.env` file with restrictive permissions (do not commit it):

```sh
umask 077
cp .env.example .env
chmod 600 .env
```

Edit `.env` to set the published host port and raw Biscuit token (without the Bearer prefix):

```dotenv
FIBER_RPC_PORT=8117
FIBER_RPC_TOKEN=your_biscuit_token
```

The container listens on port 80 internally; only the host port is configurable. Then run:

```sh
docker compose build --pull
docker compose up -d
docker compose exec fiber-rpc-proxy nginx -t
```

Missing or malformed token configuration prevents NGINX startup. Fiber validates the signature, expiry and method permissions. Rotate the token by updating the local file and running `docker compose up -d --force-recreate`. Environment variables are visible to privileged Docker operators. Do not enable debug logging or expose backend traffic to untrusted networks.

## Restricted methods

The existing denylist remains in effect for single and batch requests:

```
open_channel
accept_channel
shutdown_channel
update_channel
commitment_signed
add_tlc
remove_tlc
submit_commitment_transaction
cancel_invoice
send_payment
connect_peer
disconnect_peer
```

The denylist is not a complete authorization policy; the upstream token must enforce least privilege, including for newly introduced RPC methods.

## Verify

Replace `8117` with your configured host port. To refresh the upstream `latest` image, run `docker compose build --pull` followed by `docker compose up -d`.

```sh
curl -sS http://127.0.0.1:8117/ -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"node_info","params":[]}'
```

Expect a successful response with a valid token granting node read access. A client-supplied Authorization header is replaced, not forwarded. A denied method such as open_channel must return HTTP 403 even if included in a batch. Invalid, expired or insufficiently privileged upstream tokens must be rejected by Fiber.
