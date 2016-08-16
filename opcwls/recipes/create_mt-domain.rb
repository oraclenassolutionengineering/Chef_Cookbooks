os_user = node['env-122']['os_user']
os_installer_group = node['env-122']['os_installer_group']

# Prepare Template
create_mt_domain_py = File.join(Chef::Config[:file_cache_path], "create_mt-domain.py")
mw_home = node['env-122']['home']
wl_home = "#{mw_home}/wlserver"
common_home = "#{mw_home}/oracle_common"
java_home = node['java']['java_home']

template create_mt_domain_py do
	source "create_mt-domain.py.erb"
	variables({
		:domains_path => node['domain-mt']['domains_path'],
		:domain_name => node['domain-mt']['name'],
		:admin_server => node['domain-mt']['admin_server'],
		:wl_home => wl_home,
		:common_home => common_home,
	})
end

# Create directories
domain_home = "#{node['domain-mt']['domains_path']}/#{node['domain-mt']['name']}"

directory node['domain-mt']['domains_path'] do
	owner os_user
	group os_installer_group
	recursive true
	action :create
end

directory node['domain-mt']['apps_path'] do
	owner os_user
	group os_installer_group
	recursive true
	action :create
end

# Run WLST script
wlst_exec = "#{mw_home}/oracle_common/common/bin/wlst.sh #{create_mt_domain_py}"

ENV['ORACLE_HOME'] = mw_home
ENV['TZ'] = node['env-122']['os_timezone']

execute wlst_exec do
	user os_user
	group os_installer_group
	action :run
	creates "#{domain_home}/config/config.xml"
end

# Upstart script
start_nm_script = "/etc/init/nodemanager.conf"

template start_nm_script do
	source "start-node_manager-12c.sh.erb"
	variables({
		:os_user => os_user,
		:domain_home => domain_home
	})
end

start_admin_server_script = "/etc/init/#{node['domain-mt']['name']}-admin_server.conf"

template start_admin_server_script do
	source "start-admin_server-12c.sh.erb"
	variables({
		:os_user => os_user,
		:domain_home => domain_home
	})
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

#Start Node Manager
nm_exec  = "initctl start nodemanager"
execute nm_exec do
	action :run
end

#Start Node Manager
admin_server_exec  = "initctl start #{node['domain-mt']['name']}-admin_server"
execute admin_server_exec do
	action :run
end
