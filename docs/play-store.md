# Google Play-তে আমার এমপি

Play Console-এ যা যা লিখতে হয়, হুবহু। নীতিমালা যাচাই করা হয়েছে ১৮ সেপ্টেম্বর ২০২৬, সংস্করণ ১.২.৫ (+8)-এর উপর; ১.২.৪ প্রথম রিভিউতে ফিরে এসেছিল, নিচে দেখুন।

## অ্যাপ নিজে যা যা পূরণ করে

| Play-র নিয়ম | অ্যাপে |
|---|---|
| সরকারি তথ্য দেখানো অ্যাপকে জানাতে হবে যে সে সরকারের নয়, আর **প্রতিটি** সূত্র নামসহ দিতে হবে | প্রথমবার খুললেই "আমার এমপি সম্পর্কে" বার্তায় ৬টি সূত্র লিংকসহ; "আরও" ট্যাবে একই তালিকা; হোম পাতার নিচে এক লাইনে সব সূত্র, চাপলে তালিকা; প্রতিটি ফল ও জীবনীর নিচে নিজস্ব সূত্র (সংস্করণ ১.২.৫) |
| Target API | Android 16 (API 36), Flutter 3.44 |
| অনুমতি | শুধু INTERNET |
| গোপনীয়তা নীতি | https://mymp.bd/gopaniyota (অ্যাপের জন্য আলাদা অংশসহ) |
| অ্যাকাউন্ট মুছে ফেলার ব্যবস্থা | লাগে না, অ্যাকাউন্টই নেই |
| বিজ্ঞাপন, ট্র্যাকিং, অ্যানালিটিক্স | নেই |
| সংবাদ | শিরোনামের পাশে সংবাদমাধ্যমের নাম; চাপ দিলে সেই মাধ্যমের নিজের পাতা ব্রাউজারে খোলে |
| রিভিউয়ারের লগইন | লাগে না |

## Store listing

**App name** (৩০ অক্ষর): `My MP` (মালিকের সিদ্ধান্ত, ১৮ সেপ্টেম্বর ২০২৬; ফোনে নাম থাকে "আমার এমপি")

**Short description** (৮০ অক্ষর):

```
সংসদ সদস্য, মন্ত্রিসভা ও নির্বাচনী ফলের তথ্য। স্বাধীন, বেসরকারি তথ্যসেবা।
```

**Full description** (Google-এর প্রথম রিভিউ ২১ সেপ্টেম্বর ২০২৬-এ "Insufficient Sources Provided" বলে ফিরিয়ে দিয়েছিল: আগের লেখায় "কিছু তথ্য প্রকাশিত সংবাদ ও উইকিপিডিয়া থেকে" ছিল, কোন সংবাদমাধ্যম তা বলা ছিল না। এখন প্রতিটি সূত্র নামসহ, আর ঘোষণা একেবারে উপরে):

```
গুরুত্বপূর্ণ: My MP (আমার এমপি) একটি স্বাধীন, বেসরকারি তথ্যসেবা। এটি বাংলাদেশ জাতীয় সংসদ, নির্বাচন কমিশন, মন্ত্রিপরিষদ বিভাগ বা সরকারের কোনো দপ্তরের অ্যাপ নয়, কোনো সরকারি প্রতিষ্ঠানের প্রতিনিধিত্ব করে না, এবং কোনো সরকারি প্রতিষ্ঠান, রাজনৈতিক দল বা সংসদ সদস্যের সঙ্গে যুক্ত নয়।

My MP (আমার এমপি, Amar MP) অ্যাপে এক জায়গায় পাবেন ত্রয়োদশ জাতীয় সংসদের সব সদস্যের তথ্য।

যা যা দেখা যায়
• নাম, আসন, জেলা বা উপজেলা দিয়ে খুঁজে নিজের এলাকার সংসদ সদস্য বের করুন; বাংলা ও ইংরেজি দুই বানানেই খোঁজা যায়
• প্রতিটি সদস্যের পরিচিতি: দল, আসন, মন্ত্রণালয়, শিক্ষা, পেশা, সংসদীয় কমিটি, আগের মেয়াদ, দাপ্তরিক যোগাযোগ
• আসনভিত্তিক নির্বাচনী ফল: প্রার্থী, প্রাপ্ত ভোট ও ব্যবধান
• ত্রয়োদশ জাতীয় সংসদ নির্বাচনের পরিসংখ্যান
• পূর্ণ মন্ত্রিসভা: মন্ত্রী, প্রতিমন্ত্রী ও উপদেষ্টা, কে কোন মন্ত্রণালয়ে
• দলভিত্তিক আসন ও সদস্য তালিকা
• সংবাদমাধ্যমে কোন সদস্যের নাম এসেছে, তার শিরোনাম; চাপ দিলে মূল সংবাদমাধ্যমের পাতায় খোলে
• নেটওয়ার্ক না থাকলেও সদস্যদের তালিকা খোলে

তথ্যের সূত্র (অ্যাপের প্রতিটি তথ্য এই সূত্রগুলো থেকে নেওয়া)
• বাংলাদেশ জাতীয় সংসদ, https://www.parliament.gov.bd: সংসদ সদস্যদের নাম, ছবি, আসন, দল, যোগাযোগ, সংসদীয় কমিটি, অধিবেশন ও সংসদ সচিবালয়ের প্রজ্ঞাপন
• বাংলাদেশ নির্বাচন কমিশন, https://www.ecs.gov.bd: নিবন্ধিত ভোটার ও ভোটকেন্দ্রের সংখ্যা
• মন্ত্রিপরিষদ বিভাগ, https://cabinet.gov.bd: মন্ত্রী, প্রতিমন্ত্রী ও উপদেষ্টাদের তালিকা
• দ্য বিজনেস স্ট্যান্ডার্ড, https://www.tbsnews.net: ২০২৬ সালের নির্বাচনের আসনভিত্তিক ভোটের ফল
• বাংলা উইকিপিডিয়া, https://bn.wikipedia.org ও ইংরেজি উইকিপিডিয়া, https://en.wikipedia.org: ভোটের ফল মিলিয়ে দেখা, দলের ইতিহাস, কিছু সদস্যের শিক্ষা, জন্মস্থান ও জীবনী
• সংবাদ অংশে প্রতিটি শিরোনামের পাশে সংবাদমাধ্যমের নাম লেখা থাকে; চাপ দিলে সেই সংবাদমাধ্যমের নিজের সাইটে খোলে। অ্যাপ নিজে কোনো সংবাদ লেখে না।
অ্যাপের ভেতরে প্রতিটি সূত্রের লিংক "আরও" ট্যাবে আছে, আর প্রতিটি ফল ও জীবনীর নিচে তার নিজস্ব সূত্র লেখা।

গোপনীয়তা
কোনো অ্যাকাউন্ট লাগে না, কোনো ব্যক্তিগত তথ্য নেওয়া হয় না, কোনো বিজ্ঞাপন নেই।

কোনো তথ্য ভুল মনে হলে সূত্রসহ জানান: mymp.bangladesh@gmail.com
```

**English (Add translation > English, ঐচ্ছিক)**

Short:

```
Bangladesh MPs, cabinet and election results. Independent, not a government app.
```

Full:

```
Important: My MP (Amar MP, আমার এমপি) is an independent, non-government information service. It is not an app of the Parliament of Bangladesh, the Election Commission, the Cabinet Division or any government office, does not represent any government entity, and is not affiliated with any government body, political party or MP.

My MP brings together information on every member of Bangladesh's 13th Jatiya Sangsad.

• Find your MP by name, seat, district or upazila, in Bangla or English
• Member profiles: party, seat, ministry, education, profession, parliamentary committees, earlier terms, official contacts
• Seat-by-seat election results: candidates, votes and margins
• Statistics for the 13th parliamentary election
• The full cabinet: ministers, state ministers and advisers, by ministry
• Seats and members by party
• Headlines that mention a member, each opening on the publisher's own page
• The member list opens without a network connection

Sources (everything in the app comes from these)
• Parliament of Bangladesh, https://www.parliament.gov.bd: members' names, photos, seats, parties, contacts, committees, sessions and Secretariat notices
• Bangladesh Election Commission, https://www.ecs.gov.bd: registered voters and polling centres
• Cabinet Division, https://cabinet.gov.bd: ministers, state ministers and advisers
• The Business Standard, https://www.tbsnews.net: seat-by-seat results of the 2026 election
• Bangla Wikipedia, https://bn.wikipedia.org, and English Wikipedia, https://en.wikipedia.org: cross-checking results, party history, and some members' education, birthplace and biography
• Every headline in the news section carries the publisher's name and opens on the publisher's own site; the app writes no news itself.
Each source is linked inside the app under "More", and every result and biography names its own source.

No account, no ads; the app itself collects no personal data. The maps are Google Maps.

Report an error, with a source: mymp.bangladesh@gmail.com
```

**Graphics** (এই রিপোর `store/` ফোল্ডারে):

- App icon: `store/icon-512.png` (512×512)
- Feature graphic: `store/feature-graphic.png` (1024×500)। বদলাতে হলে `store/feature-graphic.html` এডিট করে headless Chrome দিয়ে 1024×500 স্ক্রিনশট নিন।
- Phone screenshots: `store/screenshots/` ফোল্ডারের ৮টা (Play-র সর্বোচ্চ সীমা; 1080×1920, ঠিক 9:16; Play এখন শুধু 9:16 বা 16:9 নেয়, আর এখনকার ফোনের নিজের স্ক্রিনশট তার চেয়ে লম্বা)। অ্যাপের web build হেডলেস Chrome-এ 405×720 ভিউপোর্টে ৮/৩ স্কেলে তোলা। সংবাদ ট্যাব ইচ্ছা করে বাদ: কোনো সদস্যের বিরুদ্ধে যায় এমন শিরোনাম স্ক্রিনশটে না রাখাই ভালো।

**Category:** Books & Reference। **Contact:** email `mymp.bangladesh@gmail.com`, website `https://mymp.bd`।

## App content (Policy > App content)

| ফর্ম | উত্তর |
|---|---|
| Privacy policy | `https://mymp.bd/gopaniyota` |
| App access | All functionality is available without special access |
| Ads | No, my app does not contain ads |
| Content rating | Category: **Reference, News, or Educational**। সহিংসতা, যৌনতা, মাদক, জুয়া, গালি: No। User interaction বা content sharing: No। Location sharing: No। Digital purchases: No |
| Target audience | **13-15, 16-17, 18 and over** তিনটাই টিক; ১৩-র নিচের কোনো বয়স নয় (তাহলে Families নীতির বাড়তি শর্ত আসে)। "Appeals to children" প্রশ্নে: No। এটা শুধু ঘোষণা, কে ইনস্টল করতে পারবে তা ঠিক করে content rating, আর এই অ্যাপের rating সবার জন্য খোলা |
| News apps | No। অ্যাপের মূল কাজ সংসদ সদস্যদের তথ্য; সংবাদ শুধু শিরোনাম, যা মূল সংবাদমাধ্যমে খোলে |
| Data safety | ১.৩.৪ থেকে মানচিত্র Google Maps-এর (owner, 2026-10-17)। অ্যাপ নিজে কিছু সংগ্রহ করে না, কিন্তু Maps SDK Google-এ তথ্য পাঠায়, তাই উত্তর আর শুধু **No** নয়: docs/play-listing.md-এর "Data safety" অংশ দেখে Google-এর Maps SDK disclosure অনুযায়ী পূরণ করুন |
| Government apps | No (সরকারের পক্ষে বানানো নয়) |
| Financial features | My app doesn't provide any financial features |
| Health | কোনোটাই নয় |
| Advertising ID | No |

## Release notes (bn-BD)

```
প্রথম সংস্করণ: সংসদ সদস্য, মন্ত্রিসভা, নির্বাচনী ফল ও সংবাদ। তথ্যের প্রতিটি সূত্র অ্যাপেই লিংকসহ দেওয়া।
```

## যা এড়িয়ে চলবেন

- লিস্টিং বা স্ক্রিনশটে "সরকারি", "অফিসিয়াল অ্যাপ", সংসদের লোগো বা সরকারি প্রতীক (শাপলা) নয়।
- বর্ণনায় কোনো দল বা নেতার পক্ষে-বিপক্ষে কথা, "সেরা", "#১" ধরনের দাবি বা কিওয়ার্ডের লম্বা তালিকা নয়।
- যে ফিচার অ্যাপে নেই, তা বর্ণনায় নয়।

## নতুন personal ডেভেলপার অ্যাকাউন্ট হলে

Production-এ যাওয়ার আগে closed testing-এ অন্তত ১২ জন টেস্টারকে টানা ১৪ দিন opt-in রাখতে হয়। টেস্টারদের Gmail একটা Google Group-এ রেখে সেই গ্রুপ track-এ দিলে সহজ হয়। ১৪ দিন পর Dashboard থেকে "Apply for production"-এ কয়েকটা প্রশ্নের উত্তর দিতে হয়: কারা পরীক্ষা করেছেন, কী ফিডব্যাক পেয়েছেন, কী বদলেছেন।
