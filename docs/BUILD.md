![tsukika](https://github.com/ikuyo-kita07/banners/blob/main/explore00.png?raw=true)

> NOTE: You should look into other docs to get an idea of what's happening and what to do with this "tool"

# Tsukika (月華) | Build

> Assuming that you have all of the mentioned dependencies in your local system, if you are not sure about dependencies, checkout [this page](https://github.com/ikuyo-kita07/Tsukika/blob/main/docs/BUILD_DEPENDENCIES.md).

- Switch to the cloned directory, and give the "build.sh" executable permission
```bash
chmod +x ./src/build.sh
```

- [Windows] Convert everything back to LF to get the scripts working properly
```bash
for i in $(find); do dos2unix $i &>/dev/null done
```

## Generating Personal Build Key

Before you build the forked ROM, you need to generate *YOUR* own key to proceed building because the publically available key is not safe for public builds.

For generating key, copy the command below, edit the storepass value and paste it in the terminal window.

```bash
keytool -genkeypair \
  -alias Tsukika-USER-private \
  -keyalg RSA \
  -keysize 2048 \
  -validity 3650 \
  -keystore tsukika-USER.jks \
  -storepass theDawnJKSPass \
  -dname "CN=Tsukika-Private-$(id -un), OU=Tsukika-Privatekey-$(id -un), O=Tsukika-Privatekey"
```

Copy the keystore file named tsukika-USER.jks and put it in test-keys directory found in the cloned directory.

## Edit src/makeconfigs.prop & makefile

You need to edit the mentioned files to switch signing keys from Tsukika's public Key to your own Tsukika private key.

- In makeconfigs.prop, change the following variables value from this:
```bash
MY_KEYSTORE_ALIAS="tsukika-public"
MY_KEYSTORE_PASSWORD="theDawnJKSPass"
MY_KEYSTORE_PATH="./test-keys/tsukika.jks"
MY_KEYSTORE_ALIAS_KEY_PASSWORD="theDawnJKSPass"
```

- To this:
```bash
MY_KEYSTORE_ALIAS="Tsukika-USER-private"
MY_KEYSTORE_PASSWORD="<password here again>"
MY_KEYSTORE_PATH="./test-keys/tsukika-USER.jks"
MY_KEYSTORE_ALIAS_KEY_PASSWORD="<password here again>"
```

> Remember, you can change the value to your own need. This is just an example.

## Build Types

There are like dozens of way to build your own Tsukika fork but here are some:

```bash
sudo ./src/build.sh <firmware zip path>
```

> No need to extract the zip file as the script will handle the extracting process.

```bash
sudo ./src/build.sh <firmware zip link>
```

> The firmware will get downloaded, extracted and modified without having the user to type some prompts. Ensure that you have a stable internet connection and patience.

```bash
sudo ./src/build.sh
```

> If you have the firmware extracted in CRB/MIO tool, you can just copy the path of system, vendor, product, prism, optics and put them into the src/makeconfigs.prop

- In makeconfigs.prop, change these lines from:
```bash
SYSTEM_DIR=
SYSTEM_EXT_DIR=
VENDOR_DIR=
PRODUCT_DIR=
PRISM_DIR=
OPTICS_DIR=
```

- To this:
```bash
SYSTEM_DIR=/home/joshua/a40/system/system/
SYSTEM_EXT_DIR=/home/joshua/a40/system/system/system_ext
VENDOR_DIR=/home/joshua/a40/vendor
PRODUCT_DIR=/home/joshua/a40/product
PRISM_DIR=/home/joshua/a40/prism
OPTICS_DIR=/home/joshua/a40/optics
```

> Ignore adding prism and optics if your device doesn't have it

> Remember, you can change the value to your own need. This is just an example.

## Doubts
Upload `local_build/logs/tsuki_build.log` `./local_build/logs/makeErrors.log` in the discussion tab if you are having any issues building the forked ROM.

Thank you 🥰