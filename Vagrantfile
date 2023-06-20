# -*- mode: ruby -*-
# vi: set ft=ruby :
home = ENV['HOME']

Vagrant.configure("2") do |config|

    config.vm.define "pxeserver" do |server|
      server.vm.box = 'almalinux/9'
    
      server.vm.host_name = 'pxeserver'
      server.vm.network :private_network, 
                         ip: '10.0.0.20',
                         adapter: 2, 
                         virtualbox__intnet: 'pxenet'
    
      server.vm.network "private_network", adapter: 3, ip: '192.168.50.100'
    
      server.vm.provider "virtualbox" do |vb|
        vb.name = 'pxeserver'
        vb.memory = "1024"
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 2, "--device", 0, "--type", "dvddrive", "--medium", home + '/Downloads/AlmaLinux-9-latest-x86_64-minimal.iso']
        vb.customize [
            'modifyvm', :id,
            '--firmware', 'bios',
            '--boot1', 'disk',
            '--boot2', 'none',
            '--boot3', 'none',
            '--boot4', 'none'
          ]
      end
    
      server.vm.provision "ansible" do |ansible|
        ansible.playbook = 'ansible/pxeserver.yml'
        ansible.compatibility_mode = "2.0"
      end
    end

      config.vm.define "pxeclient" do |pxeclient|
        pxeclient.vm.box = 'almalinux/9'
        pxeclient.vm.host_name = 'pxeclient'
        pxeclient.vm.boot_timeout = 1200
        pxeclient.vm.network :private_network, ip: '10.0.0.21', adapter: 2, virtualbox__intnet: 'pxenet'
        pxeclient.vm.provider :virtualbox do |vb|
          vb.memory = "2048"
          vb.name = 'pxeclient'
          vb.customize [
              'modifyvm', :id,
              '--firmware', 'bios',
              '--graphicscontroller', 'vmsvga',
              '--nic1', 'intnet',
              '--intnet1', 'pxenet',
              '--nic2', 'nat',
              '--boot1', 'net',
              '--boot2', 'none',
              '--boot3', 'none',
              '--boot4', 'none'
            ]
        end
      end
end