#
# Author:: Chris Jones <cjones303@bloomberg.net>
# Cookbook Name:: ceph
#
# Copyright 2016, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# NOTE: Create the admin user. These variables MUST exist for this to work. The default values can be found in
# the radosgw.rb attributes file. They can also be overridden in multiple places.
# Admin user MUST have caps set properly. Without full rights, no admin functions can occur via the admin restful calls.

node['ceph']['radosgw']['users'].each do | user |
  # NOTE: Keys are always generated if the user is new! We do not want to ever store user credentials.
  access_key = ceph_chef_secure_password_alphanum_upper(20)
  secret_key = ceph_chef_secure_password(40)

  ruby_block "initialize-radosgw-user-#{user['name']}" do
    block do
      if user.attribute?('max_buckets') && user['max_buckets'] > 0
        max_buckets = "--max-buckets=#{user['max_buckets']}"
      else
        max_buckets = ''
      end

      rgw_admin = JSON.parse(%x[radosgw-admin user create --display-name="#{user['name']}" --uid="#{user['uid']}" "#{max_buckets}" --access_key="#{access_key}" --secret="#{secret_key}"])
      if user.attribute?('admin_caps') && !user['admin_caps'].empty?
        rgw_admin_cap = JSON.parse(%x[radosgw-admin caps add --uid="#{user['uid']}" --caps="#{user['admin_caps']}"])
      end

    end
    not_if "radosgw-admin user info --uid='#{user['uid']}'"
    ignore_failure true
  end

  if user.attribute?('buckets')
    user['buckets'].each do | bucket |
      execute "create-bucket-#{bucket}" do
        command "radosgw-admin2 --user #{user['uid']} --endpoint #{node['ceph']['radosgw']['default_url'] } --port #{node['ceph']['radosgw']['port']} --key #{access_key} --secret #{secret_key} --bucket #{bucket} --action create"
        ignore_failure true
      end
    end
  end
end
