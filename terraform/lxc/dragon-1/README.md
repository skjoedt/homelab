# lxd

I'm using lxc to simulate physical nodes until I get my hands on more hardware.

## Set up

Configure lxd using the `lxd.yaml` config

```bash
cat lxd.yaml | lxd init --preseed
```

## Login

Add a new users on the lxc host using

```bash
lxc config trust add client.crt
```

where client.crt is found on the client machine (`~/.config/lxc/client.crt`).

Then login using

```bash
lxc remote add dragon-1 https://10.0.0.11:443 --accept-certificate
```

and switch using

```bash
lxc remote switch dragon-1
```

Now you should see the running vms with:

```bash
lxc ls --all-projects
```
