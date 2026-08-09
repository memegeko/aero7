# Security Policy

## Supported releases

| Release | Supported |
| --- | --- |
| Beta 1 | Security fixes are accepted for supported UEFI test systems |
| Older development snapshots | No |

Beta 1 is test software. Do not use it on production systems or install
it to a disk that contains valuable data without a separate, verified backup.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could expose credentials,
bypass the installer disk guards, erase an unintended device, or compromise an
installed system.

Use GitHub's **Report a vulnerability** button in the Security tab when it is
available. If that private reporting channel is unavailable, contact the
repository owner privately through their GitHub profile rather than disclosing
the vulnerability in a public issue. Non-sensitive bugs may use the normal
bug-report form.

Please include the affected commit or release, hardware or VM configuration, a minimal
reproduction, expected and actual behavior, and whether the issue can affect a
host or physical disk. Remove passwords, tokens, machine identifiers, and other
personal information from logs.

The project will acknowledge a complete private report as soon as practical,
coordinate a fix and disclosure window, and credit the reporter if requested.
