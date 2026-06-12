# Contributing

Below are everything needed to setup a local k3d test cluster.

# Prerequisites

Please install

- make
- helm
- kubectl
- mkcert
- k3d

# Install CA

In order to use the https://localho.st in base k3d test we need to install the CA.

```
mkcert -install
```