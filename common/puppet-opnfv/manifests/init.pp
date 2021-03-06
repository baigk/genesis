#Copyright 2015 Open Platform for NFV Project, Inc. and its contributors
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


class opnfv {
     if $::osfamily == 'Fuel' {
	include opnfv::resolver
	include opnfv::ntp
	include opnfv::add_packages
	include opnfv::odl_docker
	include opnfv::opncheck
    }

   if $::osfamily == 'RedHat' {

    	include stdlib
    	stage { 'presetup':
      		before => Stage['setup'],
    	}

      class { '::ntp':
        stage => presetup,
      }

    	class { "opnfv::repo":
     		stage => presetup,
    	}
      ->
      package { "python-rados":
        ensure => latest,
      }
   }
}
