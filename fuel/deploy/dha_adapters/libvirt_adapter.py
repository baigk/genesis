import common
from lxml import etree
from hardware_adapter import HardwareAdapter

log = common.log
exec_cmd = common.exec_cmd
err = common.err

DEV = {'pxe': 'network',
       'disk': 'hd',
       'iso': 'cdrom'}

class LibvirtAdapter(HardwareAdapter):

    def __init__(self, yaml_path):
        super(LibvirtAdapter, self).__init__(yaml_path)
        self.parser = etree.XMLParser(remove_blank_text=True)

    def node_power_off(self, node_id):
        vm_name = self.get_node_property(node_id, 'libvirtName')
        log('Power OFF Node %s' % vm_name)
        state = exec_cmd('virsh domstate %s' % vm_name)
        if state == 'running':
            exec_cmd('virsh destroy %s' % vm_name, False)

    def node_power_on(self, node_id):
        vm_name = self.get_node_property(node_id, 'libvirtName')
        log('Power ON Node %s' % vm_name)
        state = exec_cmd('virsh domstate %s' % vm_name)
        if state == 'shut off':
            exec_cmd('virsh start %s' % vm_name)

    def node_reset(self, node_id):
        vm_name = self.get_node_property(node_id, 'libvirtName')
        log('Reset Node %s' % vm_name)
        exec_cmd('virsh reset %s' % vm_name)

    def translate(self, boot_order_list):
        translated = []
        for boot_dev in boot_order_list:
            if boot_dev in DEV:
                translated.append(DEV[boot_dev])
            else:
                err('Boot device %s not recognized' % boot_dev)
        return translated

    def node_set_boot_order(self, node_id, boot_order_list):
        boot_order_list = self.translate(boot_order_list)
        vm_name = self.get_node_property(node_id, 'libvirtName')
        temp_dir = exec_cmd('mktemp -d')
        log('Set boot order %s on Node %s' % (boot_order_list, vm_name))
        resp = exec_cmd('virsh dumpxml %s' % vm_name)
        xml_dump = etree.fromstring(resp, self.parser)
        os = xml_dump.xpath('/domain/os')
        for o in os:
            for bootelem in ['boot', 'bootmenu']:
                boot = o.xpath(bootelem)
                for b in boot:
                    o.remove(b)
            for dev in boot_order_list:
                b = etree.Element('boot')
                b.set('dev', dev)
                o.append(b)
            bmenu = etree.Element('bootmenu')
            bmenu.set('enable', 'no')
            o.append(bmenu)
        tree = etree.ElementTree(xml_dump)
        xml_file = temp_dir + '/%s.xml' % vm_name
        with open(xml_file, 'w') as f:
            tree.write(f, pretty_print=True, xml_declaration=True)
        exec_cmd('virsh define %s' % xml_file)
        exec_cmd('rm -fr %s' % temp_dir)

    def node_zero_mbr(self, node_id):
        vm_name = self.get_node_property(node_id, 'libvirtName')
        resp = exec_cmd('virsh dumpxml %s' % vm_name)
        xml_dump = etree.fromstring(resp)
        disks = xml_dump.xpath('/domain/devices/disk')
        for disk in disks:
            if disk.get('device') == 'disk':
                sources = disk.xpath('source')
                for source in sources:
                    disk_file = source.get('file')
                    disk_size = exec_cmd('ls -l %s' % disk_file).split()[4]
                    exec_cmd('rm -f %s' % disk_file)
                    exec_cmd('fallocate -l %s %s' % (disk_size, disk_file))

    def node_eject_iso(self, node_id):
        vm_name = self.get_node_property(node_id, 'libvirtName')
        device = self.get_name_of_device(vm_name, 'cdrom')
        exec_cmd('virsh change-media %s --eject %s' % (vm_name, device), False)

    def node_insert_iso(self, node_id, iso_file):
        vm_name = self.get_node_property(node_id, 'libvirtName')
        device = self.get_name_of_device(vm_name, 'cdrom')
        exec_cmd('virsh change-media %s --insert %s %s'
                 % (vm_name, device, iso_file))

    def get_disks(self):
        return self.dha_struct['disks']

    def get_node_role(self, node_id):
        return self.get_node_property(node_id, 'role')

    def get_node_pxe_mac(self, node_id):
        mac_list = []
        vm_name = self.get_node_property(node_id, 'libvirtName')
        resp = exec_cmd('virsh dumpxml %s' % vm_name)
        xml_dump = etree.fromstring(resp)
        interfaces = xml_dump.xpath('/domain/devices/interface')
        for interface in interfaces:
            macs = interface.xpath('mac')
            for mac in macs:
                mac_list.append(mac.get('address').lower())
        return mac_list

    def get_name_of_device(self, vm_name, device_type):
        resp = exec_cmd('virsh dumpxml %s' % vm_name)
        xml_dump = etree.fromstring(resp)
        disks = xml_dump.xpath('/domain/devices/disk')
        for disk in disks:
            if disk.get('device') == device_type:
                targets = disk.xpath('target')
                for target in targets:
                    device = target.get('dev')
                    if device:
                        return device
