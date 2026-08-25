<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024, 2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up ReactFlux

This is an [Ansible](https://www.ansible.com/) role which installs [ReactFlux](https://github.com/electh/ReactFlux) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

ReactFlux is a third-party web frontend for Miniflux, aimed at providing a more user-friendly reading experience.

See the project's [documentation](https://github.com/electh/ReactFlux/blob/main/README.md) to learn what ReactFlux does and why it might be useful to you.

[<img src="assets/reactflux.png" title="UI in both light and dark themes" width="600" alt="UI in both light and dark themes">](assets/reactflux.png)

## Prerequisites

To run a ReactFlux instance it is necessary to prepare a [Miniflux](https://miniflux.app/) instance.

If you are looking for an Ansible role for Miniflux, you can check out [this role (ansible-role-miniflux)](https://github.com/mother-of-all-self-hosting/ansible-role-miniflux) maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team.

## Adjusting the playbook configuration

To enable ReactFlux with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# reactflux                                                            #
#                                                                      #
########################################################################

reactflux_enabled: true

########################################################################
#                                                                      #
# /reactflux                                                           #
#                                                                      #
########################################################################
```

### Set the hostname

To enable ReactFlux you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
reactflux_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting ReactFlux under a subpath (by configuring the `reactflux_path_prefix` variable) does not seem to be possible due to ReactFlux's technical limitations.

### About the version and the port

Two variables in [`defaults/main.yml`](../defaults/main.yml) behave differently than their names suggest, and both are worth knowing about before you change them.

`reactflux_version` is the literal `latest`, because ReactFlux publishes no versioned container images. `electh/reactflux` on Docker Hub carries `latest`, one tag per commit named after the full git hash, and a `YYYY-MM-DD` series that was discontinued on 2026-01-22. The project's own repository is tagged (`v2026.08.22` and so on), but those tags are pushed with the repository's `GITHUB_TOKEN`, which by design does not start another workflow run — so the image build that would publish them as image tags never runs. If you would rather install a fixed build than "whatever is current", pin one of the commit-hash tags:

```yaml
reactflux_version: cebdc310b6940688b020570f3992a81a08a6509c
```

`reactflux_container_http_port` describes the container image rather than configuring it. The Caddyfile baked into the image listens on `:2000` literally, so changing this variable does not move the port ReactFlux listens on — it only points the port mapping and the Traefik service label at a port that nothing is listening on. The role rejects any other value rather than letting that happen silently.

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `reactflux_environment_variables_additional_variables` variable

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, ReactFlux becomes available at the specified hostname like `https://example.com`.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu reactflux` (or how you/your playbook named the service, e.g. `mash-reactflux`).
