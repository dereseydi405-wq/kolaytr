from pathlib import Path
import base64
import os

# Android manifest izinleri ve app adı
manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()

text = text.replace('android:label="kolaytr"', 'android:label="KolayTR"')

permissions = [
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
    '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />',
    '<uses-permission android:name="android.permission.USE_EXACT_ALARM" />',
    '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />',
]

for permission in permissions:
    if permission not in text:
        text = text.replace(
            "\n    <application",
            f"\n    {permission}\n    <application",
            1,
        )

manifest.write_text(text)


# Keystore secrets kontrol
required = [
    "KEYSTORE_BASE64",
    "KEYSTORE_PASSWORD",
    "KEY_ALIAS",
    "KEY_PASSWORD",
]

missing = [name for name in required if not os.environ.get(name)]

if missing:
    raise SystemExit("Eksik signing secret: " + ", ".join(missing))

keystore_bytes = base64.b64decode(os.environ["KEYSTORE_BASE64"])

Path("android/app/upload-keystore.jks").write_bytes(keystore_bytes)

Path("android/key.properties").write_text(
    "storePassword={}\nkeyPassword={}\nkeyAlias={}\nstoreFile=upload-keystore.jks\n".format(
        os.environ["KEYSTORE_PASSWORD"],
        os.environ["KEY_PASSWORD"],
        os.environ["KEY_ALIAS"],
    )
)


# build.gradle.kts imzalama + desugaring
gradle = Path("android/app/build.gradle.kts")
g = gradle.read_text()

if "import java.util.Properties" not in g:
    g = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + g

if "val keystoreProperties = Properties()" not in g:
    g = g.replace(
        "\nandroid {",
        """
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {""",
        1,
    )

if 'create("release")' not in g:
    g = g.replace(
        "android {\n",
        """android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
""",
        1,
    )

g = g.replace(
    'signingConfig = signingConfigs.getByName("debug")',
    'signingConfig = signingConfigs.getByName("release")',
)

if "isCoreLibraryDesugaringEnabled = true" not in g:
    g = g.replace(
        "compileOptions {",
        """compileOptions {
        isCoreLibraryDesugaringEnabled = true""",
        1,
    )

g = g.replace("minSdk = flutter.minSdkVersion", "minSdk = 23")

if "coreLibraryDesugaring(" not in g:
    if "dependencies {" in g:
        g = g.replace(
            "dependencies {\n",
            'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n',
            1,
        )
    else:
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'

gradle.write_text(g)

print("Android release signing ve desugaring ayarlandı.")
