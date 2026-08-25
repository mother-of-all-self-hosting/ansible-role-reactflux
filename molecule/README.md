<!--
SPDX-FileCopyrightText: 2018-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## What the scenarios can and cannot claim

ReactFlux is a compiled single-page application and nothing else: a bundle of HTML, CSS and JavaScript baked into an image whose other half is [Caddy](https://caddyserver.com/) serving it out of `/srv`. It has no backend. The Miniflux server it reads from is typed into its login form and kept in the browser's local storage — it is not baked in at build time, and this role does not configure it. Nothing here therefore needs a Miniflux instance, and nothing here may claim that ReactFlux can reach one.

One consequence is worth knowing before reading or extending [`verify_tasks.yml`](./verify_tasks.yml). The Caddyfile inside the image is four lines long and the third is `try_files {path} {path}/ /index.html`, so **every** path answers `200` with the application shell — including a hashed `.js` asset that does not exist. A status code proves nothing here. What survives the fallback is the **content type** of a real hashed asset, and the suite asks for a deliberately absent asset of the same shape and requires it to come back as HTML, so that the content-type check is known to discriminate rather than assumed to.

The other consequence is that there is no version to assert: ReactFlux publishes no versioned images, and the image's OCI labels describe the `caddy:2` base image rather than ReactFlux (`org.opencontainers.image.title` is literally `Caddy`). What the compiled bundle does carry is a build stamp — the abbreviated commit hash and commit date of the checkout it was built from, written by ReactFlux's `prebuild` script into `src/version-info.json` and compiled in by Vite. The `default-selfbuild` scenario compares that hash against the checkout the role made, which is a real identity check; the `default` scenario reports it.

## Scenarios

Currently these testing scenarios are available:

### `default`

Runs the pre-built `electh/reactflux` image the role pulls by default, with the Traefik labels turned on so that [`../templates/labels.j2`](../templates/labels.j2) is exercised. Asserts that the container is the image `reactflux_version` names, on the network the role creates, publishing the role's HTTP port and nothing else (the image also exposes Caddy's admin API on 2019), running as the role's user with every capability except `NET_BIND_SERVICE` dropped, carrying the environment the role rendered — and that what comes back over that port is ReactFlux's application shell and its compiled bundle.

### `default-selfbuild`

Builds the image from a checkout of ReactFlux instead of pulling one, under an image name that exists in no registry, and asserts that the build stamp in the served bundle is the commit the role's checkout is on. Leaves the Traefik labels off and asserts that none are rendered, which is the negative control for the `default` scenario's label assertions.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
