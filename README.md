# puppet-robot

Opinionated module for managing automation for Robot Framework-based Robots. 

The assumption is that Robot tasks and tests are stored in separate repositories, hence
the (currently mandatory) installation of the SSH deployment key.

# What this module affects

* Creation of local "robot" user with deployment key and authorized keys
* installing a desktop environment (for browser-based Robot tasks and tests)
* Setting up VNC to start up as a systemd service

# Usage

Example use:

```
class { 'robot':
  robot_user_password => 'login-secret',
  robot_user_sshkeys  => [<list of public SSH keys>],
  vnc_password        => 'vnc-secret',
  deployment_key      => '<private key used to clone Robot task/test repositories>',
}
```

You can connect to the default VNC port to get access to "robot" user's VNC
session which has xfce4 running.
