![emergency_food](https://github.com/bocchi-the-dev/banners/blob/main/notFound.png?raw=true)

# To compile (Android NDK should be present):
- Change these following variables according to the toolchain path: ANDROID_NDK_CLANG_PATH
- Don't forget to change it, else the program won't get compiled or will have any random issues.
```bash
cd Tsukika
make SDK=<sdk version here> setupCustomizer
```

## What does this do?
- This program switches the theme of the software from Light to Dark before the setup wizard.
- And this program spoofs some properties to spoof device status