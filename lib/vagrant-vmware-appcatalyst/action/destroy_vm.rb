# encoding: utf-8
# Copyright (c) 2015 VMware, Inc.  All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License.  You may obtain a copy of
# the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, without
# warranties or conditions of any kind, EITHER EXPRESS OR IMPLIED.  See the
# License for the specific language governing permissions and limitations under
# the License.

module VagrantPlugins
  module AppCatalyst
    module Action
      class DestroyVM
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new('vagrant_appcatalyst::action::destroy_vm')
        end

        def call(env)
          env[:ui].info I18n.t("vagrant.actions.vm.destroy.destroying")
          env[:appcatalyst_cnx].delete_vm(env[:machine].id)
          env[:machine].id = nil

          @app.call(env)
        end
      end
    end
  end
end
