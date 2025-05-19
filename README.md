# Docker Free

This guide is for you if you want to use docker with Windows but cannot live with the [license restrictions](https://docs.docker.com/subscription/desktop-license/) of [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/).

If you are anything like me then you just want the ability to run some Linux containers on your Windows workstation,
for example, so that you can make build scripts that use [TestContainers](https://testcontainers), work.

With the recipe here, you will run the docker engine inside WSL2. But you can use that engine from Windows too as it will
be accessible on `localhost:2376`.

Result: You'll get a safe, well-performing docker environment without license restrictions. 
You can use it from Windows or WSL2/Linux applications alike. It will only be able to run Linux containers, not Windows
containers. However, the latter is really, really rare, so it shouldn't be something you would miss.


## Prerequisites

This guide assumes that you already have WSL2 running with an Ubuntu distro, v22 or later.

## Installation


### Step 1 - Install docker engine inside WSL

1. Install docker engine inside WSL (Ubuntu) by following the [guide from Docker Inc.](https://docs.docker.com/engine/install/ubuntu).
1. Post-installation:   `sudo usermod -aG docker $USER`
1. Logout of your Ubuntu shell and login in again. You should now be a member of the `docker` group.
   This can be verified with the `groups` command. This means you want have to use sudo everytime you want to use the `docker` command in
   Ubuntu.



### Step 2 - Generate certificates for docker engine

(In WSL/Ubuntu)

Execute the [docker-create-certs.sh](docker-create-certs.sh) script. It will generate the keys and certificates
and put them in their right place.

It should output something like this:

```
Generating CA's root key
Generating CA certificate

Generating server-side key
Generating server-side certificate
Certificate files for docker engine now exist in /etc/docker/certs

Generating client-side key
Generating client-side certificate
Certificate files for docker CLI now exist in /home/john/.docker
Certificate files for docker CLI now exist in C:\Users\john\.docker

Done!

Set the following environment variables in Windows OS:
  DOCKER_HOST=tcp://localhost:2376
  DOCKER_TLS_VERIFY=1
  DOCKER_CERT_PATH=%USERPROFILE%\.docker

```




### Step 3 - Make the docker daemon run on TCP (too)

(In WSL/Ubuntu)

In order for an application executing in Windows to reach the docker daemon in WSL, it must be exposed on a TCP port.
For this, we need to change the daemon's startup options. The easiest way to do this is
by overriding the Systemd service named `docker`.

Now, before we make any changes, it may be worth knowing what the existing command line to start the docker daemon is:

```bash
sudo systemctl cat docker.service | grep ExecStart -m 1
```

which will give you:

```
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
```

We want to add some extra command line options, in particular what we want to **add
an additional `-H` option**. This option controls what sockets the daemon listens too, and it can be applied
multiple times on the command line. We also want to add some TLS stuff to make the daemon secure.

Create and apply an override on the Systemd service named `docker`:

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo cat <<EOF > /etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd \
    --host=fd:// \
    --host=tcp://:2376 \
    --containerd=/run/containerd/containerd.sock \
    --tlsverify=true \
    --tlscacert=/etc/docker/certs/ca.pem \
    --tlscert=/etc/docker/certs/cert.pem \
    --tlskey=/etc/docker/certs/key.pem
EOF
sudo systemctl daemon-reload --system
sudo systemctl restart docker.service
```


:information_source: If you use a value of `"tcp://:2376"` (i.e., leaving out the hostname part) for the `--host` option
it will bind to the *IPv4* loopback interface. This is most likely what you want. 
By contrast, if you use a value of `"tcp://0.0.0.0:2376"` it will only bind to the *IPv6* loopback interface.
Which is most likely not what you want.

:information_source: In Systemd, the `ExecStart` directive is additive. This is why it needs to be 
set to an empty string first.

Verify:

```bash
ps -efd | grep dockerd
```

### Step 4 - Define Windows environment variables



### Step 5a - Verify your docker engine installation (from WSL/Ubuntu)

(In WSL/Ubuntu)

```
docker run hello-world
```

This should print a lot of stuff on the console, most importantly, "Hello from Docker!


### Step 5b - Verify your docker engine installation (from Windows)

(In Windows)


```
docker run hello-world
```

This should print a lot of stuff on the console, most importantly, "Hello from Docker!

