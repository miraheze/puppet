# == Define: ollama::nvidia
class ollama::nvidia (
  Enum['ubuntu','debian'] $os_family_guess = $facts['os']['name'] ? {
    /(Ubuntu)/ => 'ubuntu',
    /(Debian)/ => 'debian',
    default    => 'debian',
  },

  Boolean $use_cuda_repo = false,   # true = add NVIDIA CUDA repo to get newer drivers
  Optional[String] $pin_driver_pkg = undef,  # e.g. 'nvidia-driver-550'; default uses ubuntu-drivers autoinstall

  Boolean $blacklist_nouveau = true,
  Boolean $handle_secure_boot = true,  # leave true; we’ll hint user action if SB is on
) {

  # --- Base prerequisites (gcc toolchain, headers for DKMS) ---
  package { [
    'build-essential',
    "linux-headers-${facts['kernelrelease']}",
    'dkms',
    'pciutils',
  ]:
    ensure => present,
  }

  exec { 'update-initramfs-pre':
    command     => '/usr/sbin/update-initramfs -u',
    refreshonly => true,
  }

  # --- Optional: Nouveau blacklist (prevents conflicts) ---
  if $blacklist_nouveau {
    file { '/etc/modprobe.d/blacklist-nouveau.conf':
      ensure => file,
      mode   => '0644',
      source => 'puppet:///modules/ollama/blacklist-nouveau.conf'
    }

    # Ubuntu/Debian use initramfs-tools; dracut on some Debian variants
    exec { 'dracut-or-initramfs':
      command     => '/bin/sh -c \'if command -v dracut >/dev/null 2>&1; then dracut -f; else update-initramfs -u; fi\'',
      refreshonly => true,
    }
  }

  # --- Option A (default): Use Ubuntu/Debian vendor workflow ---
  if $os_family_guess == 'ubuntu' and $use_cuda_repo == false and $pin_driver_pkg == undef {
    package { 'ubuntu-drivers-common': ensure => present }
    -> exec { 'ubuntu-drivers-autoinstall':
      command => '/usr/bin/ubuntu-drivers autoinstall',
      creates => '/usr/bin/nvidia-smi',
      path    => ['/usr/bin','/usr/sbin','/bin','/sbin'],
    }
  }

  # --- Option B: Pin a specific driver from the distro repos ---
  if $pin_driver_pkg and $use_cuda_repo == false {
    package { $pin_driver_pkg:
      ensure => present,
    }
  }

  # --- Option C: Add NVIDIA CUDA repo (to track newer drivers) ---
  if $use_cuda_repo {
    # Add NVIDIA cuda-keyring (APT) – this manages the repo file + keys
    # See official CUDA Linux install docs + blog about key rotation.
    # (We tolerate re-run with 'creates' so it stays idempotent)
    exec { 'add-cuda-keyring':
      command => '/usr/bin/curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/$(. /etc/os-release; echo $ID)/$(. /etc/os-release; echo $VERSION_CODENAME)/cuda-keyring_1.1-1_all.deb -o /tmp/cuda-keyring.deb && /usr/bin/dpkg -i /tmp/cuda-keyring.deb',
      environment => [
        'HTTPS_PROXY=http://bastion.fsslc.wtnet:8080',
      ],
      creates => '/etc/apt/keyrings/cuda-archive-keyring.gpg',
      path    => ['/usr/bin','/usr/sbin','/bin','/sbin'],
    }
    -> exec { 'apt-update-cuda':
      command => '/usr/bin/apt-get update',
      path    => ['/usr/bin','/usr/sbin','/bin','/sbin'],
    }

    # If no pin was provided, install the recommended meta-driver from CUDA repo.
    # Otherwise install $pin_driver_pkg (e.g., nvidia-driver-570).
    if $pin_driver_pkg {
      package { $pin_driver_pkg: ensure => present }
    } else {
      # Use distro’s recommendation even with CUDA repo present
      if $os_family_guess == 'ubuntu' {
        package { 'ubuntu-drivers-common': ensure => present }
        -> exec { 'ubuntu-drivers-autoinstall-cuda':
          command => '/usr/bin/ubuntu-drivers autoinstall',
          creates => '/usr/bin/nvidia-smi',
          path    => ['/usr/bin','/usr/sbin','/bin','/sbin'],
        }
      } else {
        # Debian path: pick a recent meta (adjust if you want to be explicit)
        package { 'nvidia-driver': ensure => present }
      }
    }
  }

  # --- Post-install checks / secure boot heads-up ---
  if $handle_secure_boot {
    # Non-fatal notify if Secure Boot is ON; user may need MOK enrollment for signed modules
    $secure_boot = $facts.dig('dmi','bios','vendor') ? {
      default => inline_epp('<%- |$enabled| -%><%= $enabled %>', {'enabled' => 'unknown'}),
    }
    # This is just a log message; real detection of SB varies; we give guidance either way.
    notify { 'secure_boot_note':
      message => 'If Secure Boot is enabled, you may need to enroll a Machine Owner Key (MOK) so the NVIDIA DKMS module loads. Run `sudo mokutil --sb-state` and if enabled, reconfigure the driver package to sign the module, then enroll at reboot.',
    }
  }

  # --- Sanity check command as a noop probe (will fail gracefully pre-reboot) ---
  exec { 'probe-nvidia-smi':
    command     => '/usr/bin/nvidia-smi || true',
    refreshonly => false,
    path        => ['/usr/bin','/usr/sbin','/bin','/sbin'],
  }

}
