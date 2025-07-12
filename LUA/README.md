

## Building and Using the K3s Airgap Debian Package

This repository contains files for building a Debian package that enables K3s installation in air-gapped environments.

cd /home/vmadmin/OAK3S/k3s-airgap-deb/usr/share/k3s-airgap/install-k3s-airgap.sh

### Creating the .deb Package

1. First, ensure you have the `dpkg` tools installed:

   ```sh
   sudo apt install dpkg-dev
   ```

2. Navigate to the parent directory containing the `k3s-airgap-deb` folder:

   ```sh
   cd /home/vmadmin/OAK3S
   ```

3. Set the correct permissions for the maintainer scripts (required):

   ```sh
   chmod 755 k3s-airgap-deb/DEBIAN/{postinst,prerm}
   ```

4. Build the Debian package:

   ```sh
   dpkg-deb --build k3s-airgap-deb
   ```

5. This will create `k3s-airgap-deb.deb` in the current directory. You may want to rename it:

   ```sh
   mv k3s-airgap-deb.deb k3s-airgap_1.0.0_amd64.deb
   ```

### Installing the Package

1. Install the package using `dpkg`:

   ```sh
   sudo dpkg -i k3s-airgap_1.0.0_amd64.deb
   ```

2. After installation, the package will set up the necessary files but won't start K3s automatically.

3. To complete the K3s installation, run:

   ```sh
   sudo k3s-airgap-install
   ```

   This will execute the /usr/local/bin/k3s-airgap-install script.

### Uninstalling K3s and the Package

1. To uninstall K3s before removing the package:

   ```sh
   sudo k3s-airgap-uninstall
   ```

   This will execute the /usr/local/bin/k3s-airgap-uninstall script.

2. To remove the Debian package:

   ```sh
   sudo dpkg -r k3s-airgap
   ```

Note that removing the package will not automatically uninstall K3s. You should run `k3s-airgap-uninstall` first if you want to completely remove K3s from the system.
