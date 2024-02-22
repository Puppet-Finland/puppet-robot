#
# @summary set up Robot Framework
#
# @url https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-20-04
#
# @param manage_pip3_install
#   Install pip3 (required to install Robot Framework and its libraries)
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
  String        $deployment_key,
  Boolean       $manage_pip3_install = true
) {
  $robot_home          = '/home/robot'

  if $manage_pip3_install {
    package { 'python3-pip':
      ensure => 'present',
    }
  }

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

  # Prerequisites for robotframework-browser
  #
  # Default node.js in Ubuntu 20.04 is too old for the Browser library so
  # we use packages from nodesource.
  #
  class { 'nodejs':
    repo_url_suffix => '18.x',
  }

  $pip3_packages = ['robotframework', 'robotframework-seleniumlibrary', 'robotframework-browser', 'robotframework-imaplibrary2']

  # Install the packages with Exec. On Ubuntu 22.04 installing these as root
  # using the pip3 package provider would make "rfbrowser init" fail later in
  # this manifects.
  $pip3_packages.each |String $package| {
    exec { "install ${package}":
      user    => 'robot',
      command => "/usr/bin/pip3 install ${package}",
      unless  => "/usr/bin/pip3 show ${package}",
      before  => Exec['rfbrowser init'],
    }
  }

  # Install embedded browsers for the Browser library
  exec { 'rfbrowser init':
    command => "${robot_home}/.local/bin/rfbrowser init",
    unless  => "/usr/bin/find ${robot_home}/.local/lib -name .local-browsers|grep .local-browsers",
    user    => 'robot',
    require => [Package['nodejs'], Exec['install robotframework-browser']],
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
