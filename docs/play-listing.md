# Google Play: the listing, the answers, and what a reviewer will look for

Everything here is ready to paste. What only the owner can do is marked **(you)**.
Version in this document: **1.1.0 (build 2)**.

## The entry

| field | value |
|---|---|
| App name | আমার এমপি |
| Package name | `bd.mymp.app` (permanent: cannot be changed after the first upload) |
| Default language | বাংলা (বাংলাদেশ), bn-BD |
| App or game | App |
| Free or paid | Free |
| Category | Books & Reference |
| Tags | Reference, Government |
| Contact email | **(you)** the address you want shown publicly |
| Website | https://mymp.bd |
| Privacy policy | https://mymp.bd/gopaniyota |

**Category.** Do not pick News & Magazines. Play treats a news app as a
publisher and asks for publisher credentials. This app links to other people's
reporting and publishes none of its own; it is a reference work about
parliament, which is what Books & Reference is for.

## The one rule most likely to cause a rejection: government information

Play's policy on misleading claims covers apps that show information about a
government or its officials. Such an app must:

1. **say plainly that it does not represent any government body**, and
2. **name the official source of its information**, with a link,

**both in the store description and inside the app.** The app already does its
part in version 1.1.0:

- A notice on first launch says it is an independent, non-government service
  and names its sources.
- The "আরও" tab opens with a "সরকারি অ্যাপ নয়" card linking parliament.gov.bd,
  ecs.gov.bd and cabinet.gov.bd.
- The member list's header says "স্বাধীন, বেসরকারি তথ্যসেবা; সরকারি অ্যাপ নয়".
- Every member's page lists the sources of their biography.

The description below opens with the same statement. **Keep it at the top when
you paste it**, and do not use a government emblem, the parliament's logo or
the national flag in the icon, screenshots or feature graphic (none of the
supplied graphics do).

## Short description (80 characters max, this one is 65)

```
সংসদ সদস্যদের পরিচিতি, সংবাদ ও ভিডিও। স্বাধীন, বেসরকারি তথ্যসেবা।
```

## Full description

```
দ্রষ্টব্য: আমার এমপি একটি স্বাধীন, বেসরকারি তথ্যসেবা। এটি বাংলাদেশ জাতীয় সংসদ, নির্বাচন
কমিশন, মন্ত্রিপরিষদ বিভাগ বা সরকারের কোনো দপ্তরের অ্যাপ নয় এবং কোনো সরকারি প্রতিষ্ঠানের
সঙ্গে যুক্ত নয়।

তথ্যের সরকারি সূত্র:
• বাংলাদেশ জাতীয় সংসদ: https://www.parliament.gov.bd
• বাংলাদেশ নির্বাচন কমিশন: https://www.ecs.gov.bd
• মন্ত্রিপরিষদ বিভাগ: https://cabinet.gov.bd

আমার এমপি: বাংলাদেশের ত্রয়োদশ জাতীয় সংসদের সব সদস্যের তথ্য, হাতের মুঠোয়।

আপনার আসনের সংসদ সদস্য কে, তিনি কোন দলের, কী করেন, কোন কমিটিতে আছেন, আর তাঁকে নিয়ে
সংবাদমাধ্যম কী লিখছে, সব এক জায়গায়, বাংলায়।

• ৩৪৮ জন সংসদ সদস্য: নাম, আসন বা জেলা দিয়ে সহজে খুঁজুন
• দল ও জেলা ধরে ছেঁকে দেখুন
• প্রত্যেকের বিস্তারিত পরিচিতি: জন্ম, শিক্ষা, পেশা, রাজনৈতিক জীবন, সংসদীয় কমিটি ও আগের
  মেয়াদ, প্রতিটি তথ্যের সূত্রসহ
• সংবাদ ও ভিডিও: দেশের সংবাদমাধ্যমের শিরোনাম ও টেলিভিশনের ভিডিও, প্রতিটির সঙ্গে মূল
  খবরের লিংক
• মন্ত্রিসভা: কে কোন মন্ত্রণালয়ের দায়িত্বে
• দল অনুযায়ী সদস্যতালিকা

সংবাদের ক্ষেত্রে শুধু শিরোনাম, সংবাদমাধ্যমের নাম ও মূল খবরের লিংক দেখানো হয়; পুরো খবর
কপি করা হয় না। ভিডিও চলে যে চ্যানেল প্রকাশ করেছে তার নিজস্ব পাতায়।

কোনো অ্যাকাউন্ট লাগে না। অ্যাপ নিজে কোনো ব্যক্তিগত তথ্য সংগ্রহ করে না, কোনো বিজ্ঞাপন নেই।
মানচিত্রগুলো Google Maps-এর; মানচিত্র দেখাতে Google সাধারণ কারিগরি তথ্য পায়।
সদস্যতালিকাটি ফোনেই রাখা হয়, তাই নেটওয়ার্ক দুর্বল হলেও অ্যাপ খোলে।

ভুল চোখে পড়লে জানান: https://mymp.bd/jogajog
ওয়েবসাইট: https://mymp.bd
```

## Data safety

**Changed with version 1.3.4 (owner, 2026-10-17): the maps are Google Maps.**
The app itself still collects nothing:

- there is no account, no analytics, no crash reporter and no advertising id;
- the only Android permission is `INTERNET` (no location permission);
- the phone keeps a copy of the public member list, which is app content, not
  user data, and one on/off flag that the first-launch notice was seen, which
  never leaves the phone.

But the Google Maps SDK in the app sends data to Google to show the maps, and
Play counts what an SDK in the app collects. So the answer is no longer simply
"No". Before submitting 1.3.4, fill the form from Google's own disclosure for
the SDK: "Google Play data disclosure requirements" for the Maps SDK for
Android (developers.google.com/maps/documentation/android-sdk/play-data-disclosure),
which lists the data types the SDK collects and why. Declare those, as
collected by the SDK for app functionality, and nothing else.

Two more questions on the form:
- **Is all user data encrypted in transit?** As Google's disclosure page for
  the Maps SDK says; the app's own requests all use HTTPS.
- **Do you provide a way to delete data?** The app holds nothing; what Google
  receives for the maps is under Google's privacy policy.

## Content rating

Fill in the IARC questionnaire truthfully:
- no violence, no sexual content and no profanity;
- no gambling and no purchases;
- no user-to-user communication and no location sharing.

It rates 3+ (everyone).

The questionnaire asks whether the app contains **news or user-generated
content**. Answer that it links to news published by third parties and hosts
none. The rating stays "everyone".

## App content declarations

| Declaration | Answer |
|---|---|
| Ads | No ads |
| App access | All functionality is available without special access. There is no login, so the reviewer needs no credentials. |
| Target audience | 18 and over, or 13 and over. Not designed for children. |
| News app | **No**. It is a reference app that links to third-party news; it is not a news publisher. |
| Government apps | **No**. It is not developed by or on behalf of a government. The disclaimer above is what the policy asks of an app that shows government information. |
| Financial features, health, COVID-19, VPN, data deletion | Not applicable |

## Notes for the reviewer (the "Instructions" box)

```
This app is an independent, non-government reader for mymp.bd, a
public-interest reference site about the members of the Bangladesh parliament.
It is not affiliated with the parliament, the Election Commission or any
government body. It says so on first launch, on the member list, and in the
"আরও" (More) tab, which links the official sources: parliament.gov.bd,
ecs.gov.bd and cabinet.gov.bd.

There is no login and no account, and the app itself collects no user data.
Its maps are Google Maps (Maps SDK for Android), which receives the usual
technical data from the phone to show them; the app asks for no location.

News and videos: the app shows only headlines, the outlet's or channel's name
and a link. Tapping one opens the outlet's own page or the channel's video in
the browser or the YouTube app. No article text or video is copied or hosted.

Photographs of members are the ones the parliament secretariat publishes.
```

## Graphics (ready)

| asset | size | file |
|---|---|---|
| App icon | 512×512 PNG, no transparency | `docs/play/icon-512.png` |
| Feature graphic | 1024×500 PNG | `docs/play/feature-graphic-1024x500.png` |
| Phone screenshots | 1080×1920 (9:16) | `docs/screenshots/1-members.png` to `6-more.png` |

The screenshots were taken from the app's web build. News pictures show as grey
boxes there, because news sites do not allow their images inside a web page
from another site. On a phone the pictures load. When you have the app on a
phone, screenshots taken on it (Power + Volume down) are better for the news
tab.

## Before the first upload

1. **(you)** Create the upload key and `android/key.properties` (see the
   README). Only you should ever hold that password.
2. Run `flutter analyze && flutter test`; both must be clean.
3. Run `flutter build appbundle --release`.
4. Upload `build/app/outputs/bundle/release/app-release.aab` to a **closed
   test** track first. A new personal developer account must run a closed test
   with **at least 12 testers opted in for 14 days in a row** before it can
   apply for production. Invite 12 or more people (a Google Group is easiest),
   and ask them to keep the app installed.
5. Fill in the listing above, the data-safety form, the content rating and the
   app content declarations.
6. Send the closed test for review. After the 14 days, apply for production
   access from the dashboard and answer its questions about the test.

## After it is live

- Every later upload needs a higher build number in `pubspec.yaml`'s `version:`.
- The site's API is versioned at `/api/app/v1`. Never change what a field means
  for a phone that already has the app; add a new field instead, and let older
  versions ignore it.

## What changed in 1.1.0

- The news tab opens with a row of the newest member videos, as the website's
  home page does. A video opens on its channel; the member's name opens their
  page.
- Every member has a detailed, sourced biography. The data comes from the
  website, so no app update was needed for that part.
- A notice on first launch, a card in "আরও" and a line on the member list say
  that the app is independent and non-government, and link the official
  sources.
- On a member's page, the photo no longer slides over the tab names while
  scrolling.
