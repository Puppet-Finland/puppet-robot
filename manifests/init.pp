#
# @summary set up Robot Framework
#
# @url https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-20-04
#
# @param robot_user_password
#   Password hash for user "robot"
# @param robot_user_sshkeys
#   A list of authorized SSH keys for the "robot" user
# @param vnc_password
#   VNC password
# @param deployment_key
#   SSH key used to fetch Git repository/repositories which contain robot tasks
#
class robot (
  String        $robot_user_password,
  Array[String] $robot_user_sshkeys,
  String        $vnc_password,
  String        $deployment_key
) {
  $robot_home          = '/home/robot'

  # We use a light-weight desktop to reduce memory and CPU footprint
  package { ['xfce4', 'xfce4-goodies']:
    ensure => present,
  }

  ::accounts::user { 'robot':
    ensure   => present,
    comment  => 'User for running Robot Framework',
    password => $robot_user_password,
    sshkeys  => $robot_user_sshkeys,
  }

  # Enable remote access via VPN.
  package { 'tightvncserver':
    ensure => present,
  }

  file { "${robot_home}/.vnc":
    ensure  => directory,
    owner   => 'robot',
    group   => 'robot',
    mode    => '0700',
    require => Accounts::User['robot'],
  }

  exec { 'create-vnc-password':
    command => "echo ${vnc_password}|vncpasswd -f > ${robot_home}/.vnc/passwd",
    user    => 'robot',
    creates => "${robot_home}/.vnc/passwd",
    path    => ['/bin', '/usr/bin'],
    require => [File["${robot_home}/.vnc"], Package['tightvncserver']],
  }

  file { "${robot_home}/.vnc/passwd":
    owner   => 'robot',
    group   => 'robot',
    mode    => '0600',
    require => Exec['create-vnc-password'],
  }

  # Ensure that when we connect to VNC we get a proper desktop (xfce4)
  file { "${robot_home}/.vnc/xstartup":
    ensure  => file,
    owner   => 'robot',
    group   => 'robot',
    mode    => '0755',
    content => template('robot/xstartup.erb'),
    require => File["${robot_home}/.vnc"],
  }

  file { '/etc/X11/Xvnc-session':
    ensure  => file,
    content => template('robot/Xvnc-session.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Package['xfce4'],
  }

  ::systemd::unit_file { 'robot-tightvnc.service':
    content => template('robot/tightvnc.service.erb'),
    before  => Service['robot-tightvnc'],
  }

  service { 'robot-tightvnc':
    ensure => 'running',
    enable => true,
  }

  package { ['robotframework', 'robotframework-seleniumlibrary']:
    ensure   => present,
    provider => 'pip3',
  }

  # Install the gecko test driver (for Firefox Selenium tests)
  exec { 'get geckodriver':
    command => 'curl -L https://github.com/mozilla/geckodriver/releases/download/v0.30.0/geckodriver-v0.30.0-linux64.tar.gz|tar -C /usr/local/bin -xz',
    user    => 'root',
    creates => '/usr/local/bin/geckodriver',
    path    => ['/bin', '/usr/bin'],
  }

  file { '/usr/local/bin/geckodriver':
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Exec['get geckodriver'],
  }

  # Install deployment key used to clone Robot script repos
  file { '/home/robot/.ssh/id_rsa':
    ensure  => file,
    owner   => 'robot',
    group   => 'robot',
    mode    => '0600',
    content => $deployment_key,
    require => Accounts::User['robot'],
  }
}
