# Recovery and Logs

## Open recovery

Press **Alt+F2** to switch to the recovery console. Press **Alt+F1** to return to
the graphical setup. On the Install now page, **Repair your computer** confirms
the action and performs the same TTY2 handoff.

## Live installer logs

```bash
journalctl -u aero7-installer --no-pager
cat /var/log/aero7-kiosk.log
cat /var/log/aero7-installer.log
```

Useful device information:

```bash
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,RO,RM,MODEL,SERIAL
findmnt
ip address
```

## First-boot logs

After the disk phase has succeeded:

```bash
journalctl -u aero7-oobe.service --no-pager
journalctl -u sddm.service --no-pager
cat /var/log/aero7-installer.log
```

The embedded shell state and logs are normally under `/var/lib/aero7` and the
selected user's Aero7 state directory. The exact signed package request is:

```text
/var/lib/aero7/requested-aero7-packages.txt
```

## Installed-system checks

Once the account is available:

```bash
aero7 status
aero7 doctor
aero7 repo status
aero7 apps status
```

## Safety warning

Do not copy commands from random recovery guides that disable signature checks,
erase a broader disk path, or install a passwordless sudo rule. Capture logs
first and file an issue when the correct recovery action is unclear.
