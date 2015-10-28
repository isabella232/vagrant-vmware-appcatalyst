# encoding: utf-8
# Copyright (c) 2015 VMware, Inc.  All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License.  You may obtain a copy of
# the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed
# under the License is distributed on an "AS IS" BASIS, without warranties or
# conditions of any kind, EITHER EXPRESS OR IMPLIED.  See the License for the
# specific language governing permissions and limitations under the License.

module VagrantPlugins
  module AppCatalyst
    module Cap
      class MountAppCatalystSharedFolder
        def self.mount_appcatalyst_shared_folder(machine, name, guestpath, options)
          expanded_guest_path = machine.guest.capability(
            :shell_expand_guest_path, guestpath)

          mount_commands = []

          if options[:owner].is_a? Integer
            mount_uid = options[:owner]
          else
            mount_uid = "`id -u #{options[:owner]}`"
          end

          if options[:group].is_a? Integer
            mount_gid = options[:group]
            mount_gid_old = options[:group]
          else
            mount_gid = "`getent group #{options[:group]} | cut -d: -f3`"
            mount_gid_old = "`id -g #{options[:group]}`"
          end

          # First mount command uses vmhgfs FUSE which is the preferred mount
          # style.
          #mount_options = "-o allow_other,uid=#{mount_uid},gid=#{mount_gid}"
          #mount_options += ",#{options[:mount_options].join(",")}" if options[:mount_options]
          #mount_commands << "/usr/bin/vmhgfs-fuse #{mount_options} .host:/#{name} #{expanded_guest_path}"

          # second mount command fallsback to the kernel vmhgfs module and uses
          # getent to get the group.
          mount_options = "-o uid=#{mount_uid},gid=#{mount_gid}"
          mount_options += ",#{options[:mount_options].join(",")}" if options[:mount_options]
          mount_commands << "mount -t vmhgfs #{mount_options} .host:/#{name} #{expanded_guest_path}"

          # Second mount command uses the old style `id -g`
          mount_options = "-o uid=#{mount_uid},gid=#{mount_gid_old}"
          mount_options += ",#{options[:mount_options].join(",")}" if options[:mount_options]
          mount_commands << "mount -t vmhgfs #{mount_options} .host:/#{name} #{expanded_guest_path}"

          # Create the guest path if it doesn't exist
          machine.communicate.sudo("mkdir -p #{expanded_guest_path}")

          # Get rid of the default /mnt/hgfs mount point
          machine.communicate.sudo('mountpoint -q /mnt/hgfs && umount /mnt/hgfs || true')

          # Attempt to mount the folder. We retry here a few times because
          # it can fail early on.
          attempts = 0
          loop do
            success = true

            stderr = ""
            mount_commands.each do |command|
              no_such_device = false
              stderr = ""
              status = machine.communicate.sudo(command, error_check: false) do |type, data|
                if type == :stderr
                  no_such_device = true if data =~ /No such device/i
                  stderr += data.to_s
                end
              end

              success = status == 0 && !no_such_device
              break if success
            end

            break if success

            attempts += 1
            if attempts > 10
              raise Vagrant::Errors::LinuxMountFailed,
                command: mount_commands.join("\n"),
                output: stderr
            end

            sleep(2*attempts)
          end

          # Emit an upstart event if we can
          if machine.communicate.test("test -x /sbin/initctl")
            machine.communicate.sudo(
              "/sbin/initctl emit --no-wait vagrant-mounted MOUNTPOINT=#{expanded_guest_path}")
          end
        end

        def self.unmount_appcatalyst_shared_folder(machine, guestpath, options)
          result = machine.communicate.sudo(
            "umount #{guestpath}", error_check: false)
          if result == 0
            machine.communicate.sudo("rmdir #{guestpath}", error_check: false)
          end
        end
      end
    end
  end
end
