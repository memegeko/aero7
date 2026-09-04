# Aero7 Optional Features

Open **Start > Turn Aero7 features on or off**, or use **Control Panel >
Programs > Programs and Features > Turn Aero7 features on or off**. These are
real package and service controls, not cosmetic check boxes.

| Feature | Purpose and behavior |
| --- | --- |
| Aero7 Desktop Core | Required desktop session, shell, Control Panel and File Explorer. It cannot be removed. |
| Programs Center Beta | Optional graphical software manager. It is not installed by default. Both Beta 2 ISO variants retain its checksum-verified package locally, so it can be enabled offline and removed independently. |
| Parental Controls | Installs `malcontent` for application restrictions on managed accounts; sign out after enabling it. |
| Backup and Restore | Installs Déjà Dup for scheduled personal-file backups and restores. Archives and settings are retained on removal. |
| System Recovery | Installs Snapper and Btrfs Assistant for snapshots; available only on Btrfs roots. Snapshots are retained on removal. |
| Advanced Accessibility Services | Installs Orca, Speech Dispatcher and eSpeak NG for screen reading and spoken feedback; sign out after enabling it. |
| Speech Recognition | Unavailable until Aero7 has a supported voice-control and dictation backend. Speech synthesis is not presented as recognition. |
| Sync Center | Installs Syncthing and its user service for trusted folder synchronization. Synced data and settings are retained. |
| Aero7 Defender | Installs ClamAV and its signature-update service for on-demand malware scanning. Signature data is retained. |
| Windows CardSpace | Hidden and unavailable because the historical Microsoft technology was discontinued and has no safe Aero7 equivalent. |
| Remote Desktop Connections | Installs the FreeRDP client. It does not enable incoming remote access. |
| File and Printer Sharing | Installs Samba and enables SMB services. No shares are created automatically; existing configuration is retained. |
| Mobile Broadband and Modem Support | Installs and enables ModemManager. It reports hardware not present when no compatible modem is detected. |
| Color Management | Installs colord for ICC profiles and color-corrected workflows; sign out after enabling it. Profiles are retained. |

Checked means installed. Unchecked means available but absent. A partial state
can be repaired by selecting the feature. Hardware-dependent and unavailable
entries explain their limitation. Aero7 asks for administrator approval before
making changes and never restarts automatically.
