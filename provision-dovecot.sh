#!/bin/sh

. mail-toaster.sh || exit

install_dovecot()
{
    stage_pkg_install dovecot2 || exit

    stage_make_conf dovecot2_SET 'mail_dovecot2_SET=VPOPMAIL LIBWRAP EXAMPLES'
    stage_exec pw groupadd -n vpopmail -g 89
    stage_exec pw useradd -n vpopmail -s /nonexistent -d /usr/local/vpopmail -u 89 -g 89 -m -h-

    stage_exec make -C /usr/ports/mail/dovecot2 deinstall install clean || exit
}

configure_dovecot()
{
    local _dcdir="$STAGE_MNT/usr/local/etc/dovecot"
    fetch -o $_dcdir/local.conf http://mail-toaster.org/etc/mt6-dovecot.conf || exit

    cp -R $_dcdir/example-config/ $_dcdir/ || exit
    sed -i .bak -e 's/^#listen = \*, ::/listen = \*/' $_dcdir/dovecot.conf
    sed -i .bak -e 's/certs\/dovecot.pem/certs\/server.crt/' $_dcdir/conf.d/10-ssl.conf
    sed -i .bak -e 's/private\/dovecot.pem/private\/server.key/' $_dcdir/conf.d/10-ssl.conf
    sed -i .bak -e 's/^\!include auth-system/#\!include auth-system/' $_dcdir/conf.d/10-auth.conf
}

start_dovecot()
{
    stage_sysrc dovecot_enable=YES
    stage_exec service dovecot start || exit
}

test_dovecot()
{
    stage_exec sockstat -l -4 | grep 143 || exit
}

base_snapshot_exists \
    || (echo "$BASE_SNAP must exist, use provision-base.sh to create it" \
    && exit)

umount $STAGE_MNT/usr/local/vpopmail
create_staged_fs dovecot

mkdir -p $STAGE_MNT/usr/local/vpopmail
mount_nullfs $ZFS_DATA_MNT/vpopmail $STAGE_MNT/usr/local/vpopmail

stage_sysrc hostname=dovecot
start_staged_jail
install_dovecot
configure_dovecot
start_dovecot
test_dovecot
umount $STAGE_MNT/usr/local/vpopmail
promote_staged_jail dovecot