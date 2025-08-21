![tsukika](https://github.com/ayumi-aiko/banners/blob/main/explore01.png?raw=true)

# OTA Update XML Guide

This guide details how to create an XML file for ROM updates.  
Special thanks to [@salvogiangri](https://github.com/salvogiangri) for the OTA Updater app.

---

## XML Field Reference

| Field                | Description                                 | Example                                                      |
|----------------------|---------------------------------------------|--------------------------------------------------------------|
| `<RomName>`          | Name of your ROM                            | `<RomName>Tsukika</RomName>`                                 |
| `<VersionName>`      | ROM version name                            | `<VersionName>Eternal Bliss</VersionName>`                   |
| `<BuildNumber>`      | Build identifier (`YYYYMMDD` format)        | `<BuildNumber type="integer">20250602</BuildNumber>`         |
| `<DownloadURL>`      | Direct HTTPS link to ROM file               | `<DownloadURL>https://example.com/rom.zip</DownloadURL>`     |
| `<AndroidVer>`       | Target Android version                      | `<AndroidVer>15</AndroidVer>`                                |
| `<OneUIVer>`         | Target OneUI version                        | `<OneUIVer>7.0</OneUIVer>`                                   |
| `<CheckMD5>`         | MD5 checksum of ROM file                    | `<CheckMD5>5df3e06f9ecd48e78544ed2a6ba5bc1b</CheckMD5>`      |
| `<FileSize>`         | File size in bytes                          | `<FileSize type="long">480000000</FileSize>`                 |
| `<ChangelogHeader>`  | HTTPS link to changelog header image        | `<ChangelogHeader>https://example.com/header.png</ChangelogHeader>` |
| `<ChangelogURL>`     | HTTPS link to changelog text file           | `<ChangelogURL>https://example.com/changelog.txt</ChangelogURL>` |

---

## Important Notes

- Use HTTPS for all links.
- Increment `BuildNumber` for each release.
- Verify MD5 and file size.
- Test all URLs before publishing.
- `WebsiteURL` is optional.
- Host your XML file on GitHub or any service with raw file access.

---

## XML Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<OnOTAInfo>
    <RomName>YOUR_ROM_NAME</RomName>
    <VersionName>YOUR_VERSION_NAME</VersionName>
    <BuildNumber type="integer">YYYYMMDD</BuildNumber>
    <DownloadURL>https://your-download-link.com/rom.zip</DownloadURL>
    <AndroidVer>ANDROID_VERSION</AndroidVer>
    <OneUIVer>ONE_UI_VERSION</OneUIVer>
    <CheckMD5>YOUR_MD5_HASH</CheckMD5>
    <FileSize type="long">FILE_SIZE_IN_BYTES</FileSize>
    <WebsiteURL>https://google.com</WebsiteURL>
    <ChangelogHeader>https://your-header-image.com/image.png</ChangelogHeader>
    <ChangelogURL>https://your-changelog.com</ChangelogURL>
</OnOTAInfo>
```

---

## Uploading & Using the OTA XML

> **Note:** If building the ROM with `build.sh`, skip steps 2 and 3.

1. **Upload the XML file:**  
   Host your XML file on GitHub or a similar service.
   To get the raw URL on GitHub, open the XML file and append `?raw=true` to the end of the URL.

2. **Configure and Build the Updater:**  
    Edit the variables in your configuration file to use your own keystore values.  
    **Do not use public keys. Generate your own.**

Update these variables:

| Field                | Description                                 | Example                                                      |
|----------------------|---------------------------------------------|--------------------------------------------------------------|
| `MY_KEYSTORE_ALIAS`  | Your java keystore's alias                  | `MY_KEYSTORE_ALIAS = your-key-alias`                         |
| `MY_KEYSTORE_PASSWORD`| Your java keystore password                | `MY_KEYSTORE_PASSWORD = your-key-password`                   |
| `MY_KEYSTORE_PATH`   | Your java keystore path                     | `MY_KEYSTORE_PATH = /path/to/your-keystore.jks`              |
| `MY_KEYSTORE_ALIAS_KEY_PASSWORD`| Your java keystore alias password| `MY_KEYSTORE_ALIAS_KEY_PASSWORD = your-alias-key-password`         |

Then build the updater:

    The APK will be located at:  
    `<cloned tsukika directory>/src/tsukika/packages/TsukikaUpdater/dist/TsukikaUpdater-aligned-signed.apk`

    Copy it to:  
    `/system/app/TsukikaUpdater/TsukikaUpdater.apk`

3. **Launch the Updater App:**  
   Start the updater via ADB shell or Termux:

   ```sh
   am start -n com.mesalabs.ten.update/com.mesalabs.ten.update.activity.home.MainActivity
   ```

   The app does not appear in the app drawer, but will notify you when updates are available.