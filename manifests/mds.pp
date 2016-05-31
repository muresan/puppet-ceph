#   Copyright (C) 2013, 2014 iWeb Technologies Inc.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Author: David Moreau Simard <dmsimard@iweb.com>
#
# == Class: ceph::mds
#
# Installs and configures MDSs (ceph metadata servers)
#
# === Parameters:
#
# [*mds_activate*] Switch to activate the '[mds]' section in the config.
#   Optional. Defaults to 'true'.
#
# [*mds_data*] The path to the MDS data.
#   Optional. Default provided by Ceph is '/var/lib/ceph/mds/$cluster-$id'.
#
# [*keyring*] The location of the keyring used by MDSs
#   Optional. Defaults to /var/lib/ceph/mds/$cluster-$id/keyring.
#
class ceph::mds (
  $mds_activate = true,
  $mds_data     = '/var/lib/ceph/mds/$cluster-$id',
  $keyring      = '/var/lib/ceph/mds/$cluster-$id/keyring',
) {

  $id = $::hostname

  if $cluster {
    $cluster_name = $cluster
    $cluster_option = "--cluster ${cluster_name}"
  } else {
    $cluster_name = 'ceph'
  }

  case $::ceph::params::service_provider {
    "upstart": {
      $init = 'upstart'
      $mds_service = "ceph-mds-${id}"
      Service {
        name     => "ceph-mds-${id}",
        provider => $::ceph::params::service_provider,
        start    => "start ceph-mds id=${id}",
        stop     => "stop ceph-mds id=${id}",
        status   => "status ceph-mds id=${id}",
      }
    }
    "redhat": {
      $mds_service = "ceph-mds-${id}"
      $init = 'sysvinit'
      Service {
        name     => "ceph-mds-${id}",
        provider => $::ceph::params::service_provider,
        start    => "service ceph start mds.${id}",
        stop     => "service ceph stop mds.${id}",
        status   => "service ceph status mds.${id}",
      }
    }
    "systemd": {
      $init = 'sysvinit'
      $mds_service = "ceph-mds@${id}"
    }
  }

  # [mds]
  if $mds_activate {
    ceph_config {
      "mds.${id}/mds_data": value => $mds_data;
      "mds.${id}/keyring":  value => $keyring;
    }
    file { "/var/lib/ceph/mds/${cluster_name}-${id}":
      ensure => directory,
      owner  => $::ceph::params::ceph_user,
      group  => $::ceph::params::ceph_user,
      mode   => '0750',
    } ->    
    file { "/var/lib/ceph/mds/${cluster_name}-${id}/sysvinit":
      ensure => present,
      owner  => $::ceph::params::ceph_user,
      group  => $::ceph::params::ceph_user,
      before => Service[$mds_service],
    }
    
  } else {
    ceph_config {
      "mds.${id}/mds_data": ensure => absent;
      "mds.${id}/keyring":  ensure => absent;
    }
    file { "/var/lib/ceph/mds/${cluster_name}-${id}":
      ensure  => absent,
      recurse => true,
      purge   => true,
      force   => true,
    }
  }

  exec { 'ceph-mds-keyring':
    command =>"/bin/true # comment to satisfy puppet syntax requirements
set -ex
ceph --cluster ${cluster_name} --name client.bootstrap-mds --keyring /var/lib/ceph/bootstrap-mds/${cluster_name}.keyring auth get-or-create mds.${id} mds 'allow' osd 'allow rwx' mon 'allow profile mds' -o /var/lib/ceph/mds/${cluster_name}-${id}/keyring",
    creates => "/var/lib/ceph/mds/${cluster_name}-${id}/keyring",
    user      => $::ceph::params::ceph_user,
    require => [ Package['ceph'], File["/var/lib/ceph/bootstrap-mds/${cluster_name}.keyring"], File["/var/lib/ceph/mds/${cluster_name}-${id}"], ],
  } -> 
  service { $mds_service:
    ensure => running,
  }


}
