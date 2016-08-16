os_user = node['env-122']['os_user']
os_installer_group = node['env-122']['os_installer_group']

mw_home = node['env-122']['home']
wl_home = "#{mw_home}/wlserver"
common_home = "#{mw_home}/oracle_common"
java_home = node['java']['java_home']

# Create directories
domain_home = "#{node['domain-packed']['domains_path']}/#{node['domain-packed']['name']}"

ENV['ORACLE_HOME'] = mw_home
ENV['TZ'] = node['env-122']['os_timezone']

# Getting the domain template
domain_template_jar = File.join('/software', node['domain-packed']['domain_template_file'])

remote_file domain_template_jar do
	source "#{node['domain-packed']['domain_pack_url']}"
	headers ({"AUTHORIZATION" => "Basic #{Base64.encode64("#{node['cloud']['cloud_username']}:#{node['cloud']['cloud_password']}")}"})
	action :create_if_missing
	owner os_user
	group os_installer_group
end

directory node['domain-packed']['domains_path'] do
	owner os_user
	group os_installer_group
	recursive true
	action :create
end

directory node['domain-packed']['apps_path'] do
	owner os_user
	group os_installer_group
	recursive true
	action :create
end

# Unpack command
unpack_exec = "#{common_home}/common/bin/unpack.sh -template #{domain_template_jar} -domain #{domain_home} -user_name=weblogic -password=welcome1"

execute unpack_exec do
	user os_user
	group os_installer_group
	environment ({
	'HOME' => "/home/#{os_user}",
	'USER' => os_user
})
	action :run
end

# Node Manager Properties file
nm_props = "#{domain_home}/nodemanager/nodemanager.properties"

template nm_props do
	source "node_manager-12c.properties.erb"
	variables({
		:domain_home => domain_home,
		:java_home => java_home
	})
end

systemd_service 'wls_nm' do
  description 'Weblogic Node Manager'
  after %w( network.target )
  install do
    wanted_by 'multi-user.target'
  end
  service do
    environment 'LANG' => 'C'
    exec_start "#{domain_home}/bin/startNodeManager.sh"
    kill_signal 'SIGWINCH'
    kill_mode 'mixed'
    private_tmp true
		user 'oracle'
  end
	action [:create, :enable, :start]
	only_if { systemd? }
end

template '/etc/init/wls_nm.conf' do
	source "start-node_manager-12c.sh.erb"
	variables({
		:os_user => os_user,
		:domain_home => domain_home
	})
  only_if { upstart? }
end

execute 'Start NodeManager' do
	command 'start wls_nm'
	only_if { upstart? }
end

systemd_service 'wls_admin' do
  description 'Weblogic Admin Server'
  after %w( network.target )
  install do
    wanted_by 'multi-user.target'
  end
  service do
    environment 'LANG' => 'C'
    exec_start "#{domain_home}/bin/startWebLogic.sh"
    kill_signal 'SIGWINCH'
    kill_mode 'mixed'
    private_tmp true
		user 'oracle'
  end
	action [:create, :enable, :start]
	only_if { systemd? }
end

template '/etc/init/wls_admin.conf' do
	source "start-admin_server-12c.sh.erb"
	variables({
		:os_user => os_user,
		:domain_home => domain_home
	})
  only_if { upstart? }
end

execute 'Start Admin Server' do
	command 'start wls_admin'
	only_if { upstart? }
end
