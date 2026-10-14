# SUSE's openQA tests
#
# Copyright 2021-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: fwupd
# Summary: fwupd smoke test
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Backends 'is_pvm';
use version_utils 'is_sle';
use package_utils 'install_package';
use Mojo::JSON 'decode_json';

sub run {
    select_serial_terminal;

    # Install and start fwupd
    install_package("fwupd", trup_reboot => 1);
    systemctl "start fwupd";

    assert_script_run "fwupdmgr --version";
    # Make sure that the daemon loads its plugins
    assert_script_run "fwupdmgr get-plugins";

    # Get all devices that support firmware updates
    if (!is_pvm && is_sle('15-sp3+')) {
        assert_script_run "fwupdmgr get-devices";
        decode_json(script_output "fwupdmgr get-devices --json");
        # fwupdtool does not use the daemon
        assert_script_run "fwupdtool get-devices";
    }

    # Gets the configured remotes
    validate_script_output "fwupdmgr get-remotes", qr/lvfs/i;
    check_remote_toggle("lvfs");
}

sub remote_enabled {
    my ($remote) = @_;
    my $json = script_output "fwupdmgr get-remotes --json";
    my ($entry) = grep { $_->{Id} eq $remote } @{decode_json($json)->{Remotes}};
    die "Remote '$remote' not found" unless $entry;
    return $entry->{Enabled} ? 1 : 0;
}

sub check_remote_toggle {
    my ($remote) = @_;
    my $initial = remote_enabled($remote);
    my $toggle = $initial ? "disable-remote" : "enable-remote";
    my $restore = $initial ? "enable-remote" : "disable-remote";

    assert_script_run "fwupdmgr $toggle $remote -y";
    die "Remote '$remote' state did not change" if remote_enabled($remote) == $initial;
    assert_script_run "fwupdmgr $restore $remote -y";
    die "Remote '$remote' state was not restored" if remote_enabled($remote) != $initial;
}

sub test_flags {
    return {fatal => 0};
}

1;
