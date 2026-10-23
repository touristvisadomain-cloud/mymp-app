# আমার এমপি — Android app

The mymp.bd reader, in Flutter. Four screens: every member of the thirteenth
parliament, the news and videos written about them, the cabinet, and the
parties. No account, no ads; the app collects nothing. Its maps are Google
Maps (owner, 2026-10-17), so Google's map service receives the usual technical
data to show them.

```bash
flutter pub get
flutter run                       # a connected phone or emulator
flutter test                      # 32 tests
flutter analyze                   # must be clean before any release build
flutter build appbundle --release # what Play takes
```

## How it gets its data

Everything comes from mymp.bd, read-only and unauthenticated:

| what | route |
|---|---|
| the member list, the parties, the districts | `/api/app/v1/bootstrap` |
| one member's page | `/api/app/v1/mp/<slug>` |
| the cabinet, an adviser | `/api/app/v1/cabinet`, `/api/app/v1/adviser/<slug>` |
| the election and the statistics | `/api/app/v1/election` |
| news and videos, the whole house; today's and each month's counts | `/api/app/v1/news`, `/api/app/v1/news/counts` |
| one member's news and videos | `/api/feed/<slug>` |
| sessions, committees, a party | `/api/app/v1/sessions`, `/committees`, `/committee/<slug>`, `/party/<slug>` |
| seats, a seat, a district, the reserved seats | `/api/app/v1/seats`, `/seat/<slug>`, `/district/<slug>`, `/reserved` |
| a seat's and the country's map outlines | `/geo/<district>.json`, `/geo/overview.json` |

Every route answers in English with `?lang=en` (the app adds it when the
reader picks English). Each route's JSON, field by field, is in
`docs/app-api.md` (a copy of the site repo's own).

`bootstrap` is stored on the phone (`shared_preferences`) and shown at once on
the next launch while a fresh copy is fetched behind it; the list is replaced
only when the site's `version` changes. That is what makes the app open
instantly, and open at all with no signal.

In English every request carries `lang=en`: the site answers with the same
JSON keys holding English text (null where it has none; news headlines stay
Bangla). Each language's `bootstrap` is stored under its own key.

To try the app against a local copy of the site:

```bash
flutter run --dart-define=MYMP_BASE=http://localhost:3000
```

The site decides what the app may show, in one file: `src/lib/app/payload.ts`
in the mymp repo. It carries exactly what the website already publishes —
members' home addresses and mobile numbers are in the source data and on
neither.

## The shape of the code

```
lib/
  main.dart        the shell and its four tabs
  theme.dart       the site's palette and type, in one place
  models.dart      what the API answers, parsed defensively
  api.dart         fetching, and the copy kept on the phone
  i18n.dart        the two languages: the `t` toolkit, dates and times, the switch
  bn.dart          the older number and date helpers, now following the language
  widgets.dart     avatar, party chip, member tile, empty and error states
  screens/         members, member, news, cabinet, party, more
```

Two rules worth keeping:

* **Bangla first, English beside it.** Bangla is the default and reads exactly
  as it always has; a reader can switch to English on the আরও tab or on the
  first-run notice, and the choice is kept on the phone. Every word on screen
  goes through `t('বাংলা', 'English')` in lib/i18n.dart, and numbers and dates
  through `t.n`, `t.group`, `t.date`, `t.when`: Bengali digits and dates the
  way a Bengali reader writes them in Bangla; Latin digits, thousands commas
  and "17 February 2026" in English (British spelling, sentence case; the
  website's glossary in src/i18n/README.md of the mymp repo). Links to the
  website go to its /en pages in English. The avatar letter skips the
  honorific in either script: মোঃ আবুল হাসনাত is filed under আ, Md. Abul
  Hasnat under A. The font is bundled, not fetched; it carries Latin too.
* **Nothing is collected by the app.** No analytics, no crash reporter, no
  account. The one exception the owner chose (2026-10-17) is Google Maps: the
  election, district and seat maps are Google's when the build has a key, and
  Google's map service then receives the usual technical data from the phone.
  No analytics, and no other dependency that collects data.
* **"আমি কি এই আসনে?" (owner, 2026-10-23).** The seat map's button and the
  election map's "আমার আসন কোনটি?" ask the phone where it is, with the
  location permission (foreground only, approximate allowed), only when
  tapped. The point is checked against the seats' boundaries on the phone
  (lib/locate.dart, `placeAt` in lib/data/member.dart) and sent nowhere, not
  to mymp.bd and not to Google; Google's own "my location" layer stays off.
  The app's privacy texts (lib/disclaimer.dart, the More tab) say so; the
  Play data-safety answer has to follow (docs/play-listing.md).
* **The Maps key.** Android reads `MAPS_API_KEY` from `android/local.properties`
  (git-ignored) or the environment variable `MAPS_API_KEY` (Codemagic), and
  puts it into the manifest's `com.google.android.geo.API_KEY`. iOS reads it
  from `ios/Flutter/MapsKey.xcconfig` (`MAPS_API_KEY=…`, git-ignored) into
  Info.plist's `GMSApiKey`. Before the first frame the app asks the phone
  whether the key is there (`bd.mymp.app/maps`, MainActivity and AppDelegate);
  without one, and on the web and in the tests, it draws its own maps, as
  before, and never opens a Google map. `--dart-define=MAPS=0` forces the
  drawn maps in a build that has a key. The Android key is restricted in
  Google Cloud to "Maps SDK for Android", the package `bd.mymp.app` and the
  SHA-1 of each signing key (`keytool -list -v -keystore <file> -alias <alias>`;
  the debug key is `%USERPROFILE%\.android\debug.keystore`, alias
  `androiddebugkey`, password `android`). An app installed from Play is
  signed by Google's app-signing key: add that SHA-1 too (Play Console, Test
  and release > App integrity).

## Releasing

The upload key is not in this repository. To build a bundle Play will accept:

1. Create the key once, and keep the file and the passwords safe — losing them
   means never being able to update this app again:

   ```bash
   keytool -genkey -v -keystore mymp-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Write `android/key.properties` (git-ignored):

   ```properties
   storeFile=../../mymp-upload.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```

3. Raise `version:` in `pubspec.yaml` — the number after `+` must be higher
   than every build already uploaded — then:

   ```bash
   flutter analyze && flutter test && flutter build appbundle --release
   ```

   The bundle lands at `build/app/outputs/bundle/release/app-release.aab`.

Without `key.properties` the release build signs with the debug key so the
command still works on a fresh clone; Play will refuse that bundle.

`docs/play-listing.md` has the store listing, the data-safety answers and the
notes for the reviewer.

## The web build

`flutter run -d chrome` works and is used to look at screens while developing.
It is not a shipped target: on the web the news outlets' own images and the
site's feed route are subject to CORS, so some pictures are blank there and not
on a phone.
