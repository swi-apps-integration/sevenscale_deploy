#!/usr/bin/env bash
set -e

operatingsystem() {
  if [ -f /etc/fedora-release ]; then
    echo "fedora"
  else
    echo "unknown"
  fi
}

install_yum_repo() {
  if [ ! -f /etc/yum.repos.d/papertrail.repo ]; then
    cat <<EOF > /etc/yum.repos.d/papertrail.repo
[papertrail]
name=Papertrail Packages for Fedora \$releasever - \$basearch
baseurl=https://s3.amazonaws.com/yum.papertrailapp.com/fedora/\$releasever/
enabled=1
EOF
  fi
}

install_ree() {
  yum install --nogpgcheck -y ruby-enterprise-edition
}

install_rubygems() {
  local tempdir="$(mktemp -d)"
  trap "rm -rf ${tempdir}" INT TERM EXIT

  local dir="rubygems-1.6.2"
  local archive="${dir}.tgz"

  pushd "$tempdir"
  curl -O http://production.cf.rubygems.org/rubygems/${archive}
  tar zxvf ${archive}

  pushd ${dir}
  ruby setup.rb

  popd
  popd

  trap - INT TERM EXIT
}

uninstall_system_ruby() {
  local os="$(operatingsystem)"

  case "$os" in
    "fedora")
      yum erase -y ruby ruby-libs
      ;;
  esac
}

install_ruby() {
  local os="$(operatingsystem)"

  case "$os" in
    "fedora")
      uninstall_system_ruby
      install_yum_repo
      install_ree
      ;;
  esac
}

install_ruby