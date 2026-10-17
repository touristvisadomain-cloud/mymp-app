# The mobile app's API

Everything the My MP app reads from mymp.bd. It is a read-only view of what
the website already publishes on its own pages, built from the same data, so
the app can never show something the site does not.

- Base address: `https://mymp.bd/api/app/v1` (the routes under `/api/app/v1`
  in this repository; `src/lib/app/*` shapes the answers).
- Every endpoint is `GET`, needs no key and returns JSON (UTF-8).
- Two routes the website itself uses are read by the app too:
  [`/api/feed/{slug}`](#get-apifeedslug) and [`/api/news/range`](#get-apinewsrange).
- `node scripts/app-api-check.mjs [base]` checks every endpoint below against
  a running site (status, headers, gzip, language, no Bangla in English).

## Contents

- [Conventions](#conventions): language, nulls, dates, headers, errors, colours
- [The member brief](#the-member-brief), used by most endpoints
- [The story](#the-story), used by the news endpoints
- Endpoints: [bootstrap](#get-bootstrap) · [mp](#get-mpslug) · [adviser](#get-adviserslug) ·
  [cabinet](#get-cabinet) · [election](#get-election) · [news](#get-news) ·
  [news/counts](#get-newscounts) · [sessions](#get-sessions) · [seats](#get-seats) ·
  [seat](#get-seatslug) · [district](#get-districtslug) · [reserved](#get-reserved) ·
  [party](#get-partyslug) · [committees](#get-committees) · [committee](#get-committeeslug)
- Shared with the website: [/api/feed/{slug}](#get-apifeedslug) · [/api/news/range](#get-apinewsrange)

---

## Conventions

### Language: `?lang=bn` (default) or `?lang=en`

Every endpoint takes `?lang=`. Anything other than `en` is Bangla, so the
first app versions, which never send it, get exactly what they always got.

**The field names do not change with the language.** The text fields are named
`…Bn` (`nameBn`, `seatBn`, `titleBn`…) because the first app was Bangla only;
on `?lang=en` **the same fields carry the English**. Every answer has
`"lang": "bn"` or `"lang": "en"` at its top level.

On an English answer:

- **A text with no English translation yet is `null`, never the Bangla.** The
  field tables below mark these with **en: null if untranslated**. Today almost
  everything is translated; the fields that are actually null for some records
  are a member's `fatherBn`/`motherBn` (about 90 members) and an adviser's
  `postNameBn` (always null in English, it is the cabinet list's Bangla key).
- **News headlines stay in Bangla** in both languages: a story's
  `lead.title` and `also[].title`, and a feed item's `title` and `summary`. They
  are the outlets' own words; show them with a Bangla font.
- **Search fields stay in Bangla** in both languages: a brief's `areaBn` (never
  shown, only searched), the `upazilaEn` table's second column, and the
  `nameAlt`/`seatAlt`/`districtAlt` fields that English answers add beside the
  English names, so the app's search matches a query in either script.
- Running text that was translated from Bangla (a biography, a summary, a
  seat's area) comes with a flag beside it, `…Translated: true`. The website
  shows "Translated from Bangla" under such text; the app should too.
- Numbers are numbers in both languages (`245`, not `"২৪৫"`); format them
  in the app.
- Some fields are the source's own English in both languages and are
  documented as such (`nameEn`, `seatEn`, `districtEn`). The source writes
  some `nameEn` in capitals ("TARIQUE RAHMAN"); for display use `nameBn` on an
  English answer, which is the cleaned-up English name.
- Codes stay codes in both languages: party `abbr` ("BNP"), `offices`
  ("pm"), officer `role` ("WHIP"), committee `type`, member `status`.

### Dates

- A **day** is `"YYYY-MM-DD"`, a calendar day in Bangladesh (Asia/Dhaka).
- An **instant** is ISO 8601 with an offset (`"2026-10-08T03:17:44.556+00:00"`).
- `version` (every endpoint) is the build stamp of the data snapshot, an
  instant. The app can keep a copy of an answer and replace it only when the
  bootstrap's `version` changes.
- A month is `"YYYY-MM"`.

### Headers

| Header | Value |
| --- | --- |
| `access-control-allow-origin` | `*` on every answer, errors included |
| `cache-control` | `public, s-maxage=3600, stale-while-revalidate=86400` for the data endpoints; `public, s-maxage=300, stale-while-revalidate=1800` for news; `public, s-maxage=60` for errors |
| `content-encoding` | `gzip` when the request sends `accept-encoding: gzip` and the answer is over 1 KB (then also `vary: Accept-Encoding`) |
| `content-type` | `application/json` |

The language is in the query string, so a cache keeps the two languages apart
by address.

### Errors

| Status | Body | When |
| --- | --- | --- |
| 404 | `{"error":"not found"}` | an unknown slug |
| 400 | `{"error":"bad range"}` | `/news` (or `/api/news/range`, `/api/feed/{slug}`) with a `from`/`to`/`before` that is not a valid span |
| 400 | `{"error":"bad month"}` | `/api/feed/{slug}?m=` that is not `YYYY-MM` |
| 500 | (not JSON) | a server fault; retry later |

An endpoint that reads the live news feed answers `"unavailable": true` with
empty lists while the feed's database tables do not exist (a new deployment).

### Party colours

`color` is the website's CSS colour token. Their values:

| Token | Hex | Party |
| --- | --- | --- |
| `var(--color-pbnp)` | `#1f7a4f` | BNP |
| `var(--color-pjamaat)` | `#8cbf2a` | BJEI |
| `var(--color-pind)` | `#5b6fb5` | Ind (independents) |
| `var(--color-pncp)` | `#e0641f` | NCP |
| `var(--color-pother)` | `#9a5fc7` | every other party |

### Slugs

Slugs are stable lowercase ASCII: members `tarique-rahman`, seats
`dhaka-17` and `women-seat-1`, districts `dhaka`, `coxs-bazar`, parties
`bnp` (the party's `slug`, the abbreviation in lower case), committees
`public-accounts-committee-pac`. They are the same as the website's addresses
(`/mp/{slug}`, `/ason/{slug}`, `/jela/{slug}`, `/dol/{slug}`, `/committee/{slug}`;
the English site prefixes `/en`).

---

## The member brief

The short form of a member, wherever a member appears (`member`, `members[]`,
`leader`, `chair`…). Abbreviated as `{brief: slug}` in the examples below.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | The Parliament Secretariat's id, `"013019001"`. |
| `slug` | string | For `/mp/{slug}`. |
| `nameBn` | string | The name in the answer's language. English: the cleaned-up English name. |
| `nameEn` | string \| null | The source's English spelling, in both languages (may be in capitals). |
| `photoUrl` | string \| null | parliament.gov.bd's photo. |
| `gender` | `"Male"` \| `"Female"` \| null | |
| `party` | string \| null | Party abbreviation, e.g. `"BNP"`; see `/party/{slug}` (slug = lower case). |
| `partyBn` | string \| null | The party's short name: `"বিএনপি"` / `"BNP"`. |
| `seatNo` | number \| null | 1–300 general seats, 301–350 reserved seats for women. |
| `seatBn` | string \| null | `"ঢাকা-১৭"` / `"Dhaka-17"`; reserved `"মহিলা আসন-১"` / `"Women's Seat-1"`. |
| `seatSlug` | string \| null | For `/seat/{slug}`. |
| `seatEn` | string \| null | The source's English seat name, both languages (`"Pabna 5"` as the source writes it; prefer `seatBn` on English). |
| `districtBn` | string \| null | The district, in the answer's language; null for reserved seats. |
| `districtEn` | string \| null | The source's English district name, both languages. |
| `districtSlug` | string \| null | For `/district/{slug}`; null for reserved seats. |
| `areaBn` | string \| null | The upazilas and wards the seat covers, **in Bangla in both languages**: for search only, never shown (a seat's area for display is `seat.boundaryBn` in `/mp`, or `/seats`). Null for reserved seats. |
| `officeBn` | string \| null | What the site shows beside the name: a House office ("প্রধানমন্ত্রী" / "Prime Minister", "Speaker"), else the government post with its ministries ("পানি সম্পদ প্রতিমন্ত্রী" / "State Minister, Ministry of Water Resources"), else null. |
| `reserved` | boolean | True for a member for a reserved seat for women. |
| `nameAlt` | string \| null | **English answers only** (absent on Bangla): the Bangla name, for search. |
| `seatAlt` | string \| null | **English answers only**: the Bangla seat name ("পঞ্চগড়-২"), for search. |
| `districtAlt` | string \| null | **English answers only**: the Bangla district name, for search; null for reserved seats. |

```json
{
  "id": "013000201",
  "slug": "forhad-hossain-azad",
  "nameBn": "Forhad Hossain Azad",
  "nameEn": "Forhad Hossain Azad",
  "photoUrl": "https://prp.parliament.gov.bd/api/files?_=MjAyNjAy…",
  "gender": "Male",
  "party": "BNP",
  "partyBn": "BNP",
  "seatNo": 2,
  "seatBn": "Panchagarh-2",
  "seatSlug": "panchagarh-2",
  "seatEn": "Panchagarh-2",
  "districtBn": "Panchagarh",
  "districtEn": "Panchagarh",
  "districtSlug": "panchagarh",
  "areaBn": "(ক) বোদা এবং (খ) দেবীগঞ্জ উপজেলা",
  "officeBn": "State Minister, Ministry of Water Resources",
  "reserved": false,
  "nameAlt": "ফরহাদ হোসেন আজাদ",
  "seatAlt": "পঞ্চগড়-২",
  "districtAlt": "পঞ্চগড়"
}
```

The same member with `?lang=bn` has `"nameBn": "ফরহাদ হোসেন আজাদ"`,
`"partyBn": "বিএনপি"`, `"seatBn": "পঞ্চগড়-২"`, `"officeBn": "পানি সম্পদ প্রতিমন্ত্রী"`, and no
`nameAlt`/`seatAlt`/`districtAlt`.

---

## The story

One news story or video, as the website's news page draws it. Used by
[`/news`](#get-news).

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | `"feed-103903"` for the live feed; other ids for older stories from the site's archive. |
| `date` | day | The day it was published, in Dhaka. |
| `dateLabel` | string | `"শুক্রবার, ১২ সেপ্টেম্বর ২০২৬"` / `"Friday, 12 September 2026"`. |
| `publishedAt` | instant \| day | Absent on some archive stories; a bare day when the outlet gave no time. |
| `lead` | link | The headline: `{title, source, url}`. |
| `lead.title` | string | **The outlet's headline, in Bangla in both languages.** |
| `lead.source` | string \| null | The outlet: `"বাংলা ট্রিবিউন"` / `"Bangla Tribune"`. **en: null if the site has no English name for the outlet.** |
| `lead.url` | string | The story on the outlet's site. |
| `also` | link[] | The same story in other outlets, same shape as `lead`. |
| `member` | story member \| null | The first member the story names. |
| `members` | story member[] | Everyone it names (absent on some archive stories). |
| `kind` | `"news"` \| `"video"` \| `"press"` | Absent means news. |
| `thumbnail` | string \| null | The outlet's own picture, on the outlet's server. |
| `durationSeconds` | number \| null | Videos. |

A story member: `{slug, name, nameEn, party, color}`. `name` is the Bangla
name, or on English the English name (null if none); `nameEn` is the English
name in both languages (may be absent on Bangla archive stories); `party` the
abbreviation; `color` a [colour token](#party-colours).

---

## GET /bootstrap

Everything the app keeps offline: the member list, the parties, the
districts. Fetch on first run, then whenever you want to check `version`.
About 270 KB (40 KB gzipped).

| Field | Type | Notes |
| --- | --- | --- |
| `version` | instant | The data snapshot's build stamp. |
| `lang` | `"bn"` \| `"en"` | |
| `parliamentNo` | number | `13`. |
| `counts` | object | `{members, territorial, reserved, resigned, parties, committees, committeesCurrent, sittings, notices, returningMembers}`, all numbers. `members` counts sitting members. |
| `parties[]` | object | Every party in the House: `abbr`, `slug`, `nameBn` (full name, English on en), `nameEn` (the source's English), `color` (token), `seats` (sitting members), `shortBn` (short name). |
| `districts` | string[] | The 64 district names in the answer's language, alphabetical. Kept for old apps; prefer `districtList`. |
| `districtList[]` | object | In seat order: `slug`, `nameBn` (answer's language), `nameEn` (English, both languages), `seats` (number of general seats). |
| `members[]` | brief | Every sitting member, in seat order (general seats, then reserved). |
| `former[]` | brief + `resignedOn` | Members who have resigned (`resignedOn`: day). Not in the House any more, but `/mp/{slug}` still answers for them. |
| `leaders[]` | object | The senior office holders, in this order: Prime Minister (Leader of the House), Speaker, Deputy Speaker, Leader of the Opposition, Chief Whip. `{roleBn, memberId}`; `memberId` matches `members[].id`. One whose office holder is not a member is left out. |
| `upazilaEn` | [string, string][] | Upazila names as `[English, Bangla]`, so an English search for an upazila can be matched against the Bangla `areaBn`. The second column is Bangla in both languages. About 21 KB. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "parliamentNo": 13,
  "counts": { "members": 347, "territorial": 298, "reserved": 49, "resigned": 2, "parties": 11, "committees": 72,
              "committeesCurrent": 57, "sittings": 61, "notices": 514, "returningMembers": 63 },
  "parties": [
    { "abbr": "BNP", "slug": "bnp", "nameBn": "Bangladesh Nationalist Party (BNP)", "nameEn": "Bangladesh Nationalist Party (BNP)",
      "color": "var(--color-pbnp)", "seats": 245, "shortBn": "BNP" },
    "… 10 more"
  ],
  "districts": ["Bagerhat", "… 63 more"],
  "districtList": [{ "slug": "panchagarh", "nameBn": "Panchagarh", "nameEn": "Panchagarh", "seats": 2 }, "… 63 more"],
  "members": ["{brief: barrister-muhammad-nawshad-zamir}", "… 346 more"],
  "former": [{ "…brief fields": "…", "slug": "mirza-fakhrul-islam-alamgir", "resignedOn": "2026-08-21" }, "… 1 more"],
  "leaders": [{ "roleBn": "Prime Minister", "memberId": "013019001" }, "… 3 more"],
  "upazilaEn": [["Abhaynagar", "অভয়নগর"], "… 514 more"]
}
```

---

## GET /mp/{slug}

One member, with the facts the member's page shows. Works for resigned members
too (the bootstrap's `former`). 404 for an unknown slug. The member's news is
separate: [`/api/feed/{slug}`](#get-apifeedslug).

All the [brief](#the-member-brief)'s fields, and:

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang` | | |
| `professionBn` | string \| null | **en: null if untranslated.** |
| `educationBn` | string \| null | Schools and degrees, separated by `"; "` (show one per line). **en: null if untranslated.** |
| `birthPlaceBn` | string \| null | **en: null if untranslated.** |
| `dateOfBirth` | day \| null | |
| `fatherBn`, `motherBn` | string \| null | English: the source's English name, else a translation. **en: null if neither** (about 90 members). |
| `isFreedomFighter` | boolean | |
| `email` | string \| null | The official address Parliament publishes. |
| `bioBn` | string \| null | The biography; paragraphs separated by a blank line (`"\n\n"`). **en: null if untranslated.** |
| `bioTranslated` | boolean | True when `bioBn` is a translation from Bangla. |
| `bioOnlyInBangla` | boolean | English only: a biography exists in Bangla but has no English yet (the site says "available in Bangla" and links the Bangla page). Always false on Bangla. |
| `summaryBn` | string \| null | The source's one-paragraph summary (presiding officers). **en: null if untranslated.** |
| `summaryTranslated` | boolean | |
| `showSummary` | boolean | Whether the page shows `summaryBn` (it does not when it repeats the biography). |
| `leadBn` | string | The page's opening sentence(s), the same as search results and link previews show. |
| `introBn` | string[] | For a member with neither a biography nor a summary: an introduction put together from the record, one string per paragraph. Empty otherwise. |
| `bioSource` | string \| null | The Wikipedia article(s) the starred facts came from, space-separated, percent-encoded. |
| `bioSources` | string[] | Where the biography was written from (URLs). |
| `bioSourceLinks[]` | object | The same, named: `{url, label}`, label as the page shows it (`"উইকিপিডিয়া (বাংলা)"` / `"Wikipedia (Bangla)"`). |
| `bioFromWiki` | string \| null | Which of `educationBn`, `birthPlaceBn`, `professionBn` came from Wikipedia, comma-separated (the page marks them with an asterisk). |
| `term` | `{start, end}` | Days; this parliament's term (oath to scheduled end, or to the resignation). |
| `termsCount` | number \| null | Times elected, this term included. |
| `status` | string \| null | The source's status code, e.g. `"Active"`, `"Resigned"`. |
| `resignedOn` | day \| null | |
| `partyRoleBn` | string \| null | Office in the party ("চেয়ারম্যান" / "Chairman"). **en: null if untranslated.** |
| `ministryBn` | string \| null | An editor's ministry entry. **en: null if untranslated.** |
| `partyNameBn` | string \| null | The party's full name. |
| `seat` | object \| null | `{no, slug, nameBn, reserved, districtSlug, districtBn, boundaryBn, boundaryTranslated, vacantSince}`. `boundaryBn` is the Election Commission's description of the area (**en: null if untranslated**; the page then says it is available in Bangla); `vacantSince` (day) is set when the seat's member resigned. |
| `offices` | string[] | Codes: `"pm"`, `"speaker"`, `"deputy-speaker"`, `"opposition-leader"`. |
| `rolesBn` | string[] | Every House office as the page's badges show it, whips included: `["প্রধানমন্ত্রী", "সংসদ নেতা"]` / `["Prime Minister", "Leader of the House"]`. |
| `postBadgesBn` | string[] | Government posts as the page's badges show them, except the PM's: `"প্রতিমন্ত্রী, পানি সম্পদ মন্ত্রণালয়"` / `"State Minister, Ministry of Water Resources"`. |
| `postsCheckedAt` | instant \| null | When the government posts were last checked against the Cabinet Division's list. |
| `socials[]` | object | `{key, icon, url, unverified, label}`. `key`/`icon`: `facebook`, `x`, `youtube`, `instagram`, `website` (`icon` `globe`). `unverified: true` for a Facebook page still being checked (show "Not verified" / "যাচাই করা হয়নি"). `label` in the answer's language. |
| `facebookNotice` | string \| null | Shown instead of a Facebook link that is disputed ("Facebook page not verified"). |
| `socialSource` | string \| null | The Wikipedia article(s) the links were read from, space-separated; null when an editor added them ("Checked and added by the editor of My MP"). |
| `governmentPosts[]` | object | `{title, ministryBn, fromDate}`: the rank ("প্রতিমন্ত্রী" / "State Minister"), the ministry (**en: null if untranslated**), the day of allocation. |
| `committees[]` | object | Up-to-date committees the member sits on: `{slug, nameBn, role}`, `role` `"সভাপতি"`/`"সদস্য"` / `"Chair"`/`"Member"`. |
| `committeeCounts` | `{total, current}` | Parliament's committees, and how many have a member list updated for this parliament (the page's note when `committees` is empty). |
| `priorTerms[]` | object | Earlier parliaments, newest first: `{parliamentNo, seatNo, seatNameBn, seatNameEn, partyAbbr, partyNameBn, labelBn}`. `labelBn`: `"নবম সংসদ, ২০০৮"` / `"9th Parliament, 2008"`. English `seatNameBn`/`partyNameBn` null when unknown. |
| `result` | object \| null | The seat's 2026 result (general seats with a published result): `{candidates[], sourceUrl, sourceNote, sourceBn, noteBn, won}`. `candidates[]`: `{name, party, partyBn, votes}`, most votes first; `name` on English is null when only a Bangla name is known; `partyBn` null for a party with no certain name. `sourceBn` names the publisher ("The Business Standard"). `noteBn` is the note the page shows; `sourceNote` is the raw note (Bangla answers, for old apps) or `noteBn` (English). `won`: false when this member is not the result's winner (after a by-election). |
| `notices[]` | object | The Parliament Secretariat's notices in the member's name: `{id, titleBn, date, categoryBn, pdfUrl}`. English `titleBn` is the source's English title (null if none). `categoryBn`: "No-objection certificate", "Government order", "Notification". |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "id": "013000301",
  "slug": "mirza-fakhrul-islam-alamgir",
  "nameBn": "Mirza Fakhrul Islam Alamgir",
  "…": "the other brief fields",
  "professionBn": null,
  "educationBn": null,
  "birthPlaceBn": null,
  "dateOfBirth": "1948-08-01",
  "fatherBn": "Mirza Ruhul Amin",
  "motherBn": null,
  "isFreedomFighter": false,
  "email": "thakurgaon.1@parliament.gov.bd",
  "bioBn": null,
  "bioTranslated": false,
  "bioOnlyInBangla": false,
  "summaryBn": null,
  "summaryTranslated": false,
  "showSummary": false,
  "leadBn": "Mirza Fakhrul Islam Alamgir was a member of the 13th Parliament elected from Thakurgaon…",
  "introBn": [
    "He was born on 1 August 1948.",
    "He has been elected an MP 3 times in all, this term included. In the 2026 election he was elected with 238,836 votes, 97,819 more than the nearest rival (according to The Business Standard's count)."
  ],
  "bioSource": null,
  "bioSources": [],
  "bioSourceLinks": [],
  "bioFromWiki": null,
  "term": { "start": "2026-02-17", "end": "2026-08-21" },
  "termsCount": 3,
  "status": "Resigned",
  "resignedOn": "2026-08-21",
  "partyRoleBn": null,
  "ministryBn": null,
  "partyNameBn": "Bangladesh Nationalist Party (BNP)",
  "seat": { "no": 3, "slug": "thakurgaon-1", "nameBn": "Thakurgaon-1", "reserved": false, "districtSlug": "thakurgaon",
            "districtBn": "Thakurgaon", "boundaryBn": "Thakurgaon Sadar upazila", "boundaryTranslated": true,
            "vacantSince": "2026-08-21" },
  "offices": [],
  "rolesBn": [],
  "postBadgesBn": [],
  "postsCheckedAt": "2026-10-08T03:17:44.556+00:00",
  "socials": [],
  "facebookNotice": null,
  "socialSource": null,
  "governmentPosts": [],
  "committees": [],
  "committeeCounts": { "total": 72, "current": 57 },
  "priorTerms": [],
  "result": {
    "candidates": [{ "name": "Mirza Fakhrul Islam Alamgir", "party": "BNP", "partyBn": "BNP", "votes": 238836 }, "… 2 more"],
    "sourceUrl": "https://www.tbsnews.net/election-2026-seat/thakurgaon-1",
    "sourceNote": "Not checked against the Election Commission's gazette. Wikipedia also gives the same vo…",
    "sourceBn": "The Business Standard",
    "noteBn": "Not checked against the Election Commission's gazette. Wikipedia also gives the same vo…",
    "won": true
  },
  "notices": []
}
```

A Bangla answer for a sitting minister, trimmed:

```json
{
  "lang": "bn",
  "slug": "tarique-rahman",
  "nameBn": "তারেক রহমান",
  "officeBn": "প্রধানমন্ত্রী",
  "bioBn": "তারেক রহমান বাংলাদেশের প্রধানমন্ত্রী, সংসদ নেতা এবং বাংলাদেশ জাতীয়তাবাদী দলের (বিএনপি)…",
  "bioTranslated": false,
  "leadBn": "তারেক রহমান ঢাকা-১৭ আসন থেকে নির্বাচিত ত্রয়োদশ জাতীয় সংসদের সদস্য এবং বাংলাদেশ জাতীয়…",
  "rolesBn": ["প্রধানমন্ত্রী", "সংসদ নেতা"],
  "socials": [{ "key": "facebook", "icon": "facebook", "url": "https://www.facebook.com/tariquerahman.bdbnp",
                "unverified": false, "label": "অফিসিয়াল ফেসবুক পেজ" }, "… 1 more"],
  "governmentPosts": [{ "title": "প্রধানমন্ত্রী", "ministryBn": "মন্ত্রিপরিষদ বিভাগ", "fromDate": "2026-02-17" }, "… 2 more"],
  "committees": [{ "slug": "business-advisory-committee", "nameBn": "কার্য উপদেষ্টা কমিটি", "role": "সদস্য" }, "… 2 more"],
  "result": {
    "candidates": [{ "name": "তারেক রহমান", "party": "BNP", "partyBn": "বিএনপি", "votes": 72699 }, "… 11 more"],
    "sourceUrl": "https://www.tbsnews.net/election-2026-seat/dhaka-17",
    "sourceNote": "উৎস: দ্য বিজনেস স্ট্যান্ডার্ড, নির্বাচন ২০২৬ পাতা, 2026-09-11 তারিখে পড়া। নির্বাচন কমি…",
    "sourceBn": "দ্য বিজনেস স্ট্যান্ডার্ড",
    "noteBn": "নির্বাচন কমিশনের গেজেটের সঙ্গে মিলিয়ে দেখা হয়নি। উইকিপিডিয়াতেও বিজয়ীর ভোট একই।",
    "won": true
  }
}
```

---

## GET /adviser/{slug}

Someone on the cabinet list from outside Parliament (an adviser or a
technocrat minister): the cabinet's `posts[].adviserSlug`. 404 for an unknown slug.

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang`, `slug` | | |
| `postNameBn` | string \| null | The name exactly as the cabinet list writes it ("জনাব হুমায়ুন কবির"). **Always null on English.** |
| `nameBn` | string \| null | The name. **en: null if no English name is known.** |
| `roleBn` | string | "পররাষ্ট্র প্রতিমন্ত্রী" / "State Minister for Foreign Affairs". |
| `rankBn` | string \| null | "টেকনোক্র্যাট প্রতিমন্ত্রী" / "Technocrat state minister". **en: null if untranslated.** |
| `bioBn` | string \| null | Paragraphs separated by `"\n\n"`. **en: null if untranslated.** |
| `bioTranslated` | boolean | |
| `professionBn`, `educationBn`, `birthPlaceBn`, `partyRoleBn` | string \| null | **en: null if untranslated.** |
| `sources` | string[] | Where the profile was written from. |
| `sourceLinks[]` | `{url, label}` | The same, named. |
| `checkedOn` | day | Checked against its sources up to this day. |
| `photoUrl` | string \| null | From the cabinet list. |
| `posts[]` | `{title, ministryBn, fromDate}` | Current posts, as in `/mp`'s `governmentPosts`. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "slug": "humayun-kabir",
  "postNameBn": null,
  "nameBn": "Humayun Kabir",
  "roleBn": "State Minister for Foreign Affairs",
  "rankBn": "Technocrat state minister",
  "bioBn": "Humayun Kabir is State Minister for Foreign Affairs, appointed under the technocrat quo…",
  "professionBn": null,
  "educationBn": "University of Sussex, UK (bachelor's with honours in International Relations); London S…",
  "birthPlaceBn": "Habashpur, Osmaninagar, Sylhet",
  "partyRoleBn": "Joint Secretary General (International Affairs)",
  "sources": ["https://bn.wikipedia.org/wiki/হুমায়ুন_কবির_(সিলেটের_রাজনীতিবিদ)", "… 5 more"],
  "checkedOn": "2026-09-17",
  "bioTranslated": true,
  "sourceLinks": [{ "url": "https://bn.wikipedia.org/wiki/হুমায়ুন_কবির_(সিলেটের_রাজনীতিবিদ)", "label": "Wikipedia (Bangla)" }, "… 5 more"],
  "photoUrl": "https://objectstorage.ap-dcc-gazipur-1.oraclecloud15.com/…",
  "posts": [{ "title": "State Minister", "ministryBn": "Ministry of Foreign Affairs", "fromDate": "2026-08-21" }]
}
```

---

## GET /cabinet

The cabinet, as the website's মন্ত্রিসভা / Cabinet page lists it.

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang` | | |
| `checkedAt` | instant \| null | When the list was last checked against the Cabinet Division's ("Last checked"). |
| `sourceUrl` | string | The Cabinet Division's page for readers ("Source: Cabinet Division"). |
| `posts[]` | object | One row per post and ministry, in the source list's order; a person with three ministries has three rows. |
| `posts[].title` | string \| null | The rank, exactly one of `"প্রধানমন্ত্রী"`, `"মন্ত্রী"`, `"প্রতিমন্ত্রী"`, `"উপমন্ত্রী"`, `"উপদেষ্টা"` / `"Prime Minister"`, `"Minister"`, `"State Minister"`, `"Deputy Minister"`, `"Adviser"` (the page's order). Should the Cabinet Division ever use another title, English gives `"Adviser to the Prime Minister"` or `"Political Adviser"` where it has the English, else null. |
| `posts[].ministryBn` | string \| null | The ministry or division; for an adviser, the kind of adviser ("রাজনৈতিক উপদেষ্টা" / "Political Adviser"). **en: null if untranslated.** |
| `posts[].fromDate` | day \| null | Day of allocation. |
| `posts[].member` | brief \| null | When the holder is an MP. |
| `posts[].holderBn` | string \| null | The holder's name (Bangla: as the list writes it, with "জনাব"). **en: null if no English name is known.** |
| `posts[].photoUrl` | string \| null | |
| `posts[].adviserSlug` | string \| null | For [`/adviser/{slug}`](#get-adviserslug) when the holder is not an MP and has a profile. |
| `posts[].rankNoteBn` | string \| null | "মন্ত্রীর পদমর্যাদা" / "With the rank of a minister". **en: null if untranslated.** |
| `posts[].sourceUrl` | string \| null | The Cabinet Division page the row was read from. |
| `pending[]` | object | On the list but not yet confirmed by an editor as an MP or not: `{titleBn, nameBn, ministries[]}`. `nameBn` is **always null on English** (the list gives these names in Bangla only); `ministries[]` en: null if untranslated. The page shows "N people being checked for whether they are MPs". |
| `changes[]` | object | The last 20 changes on the list, newest first: `{date, nameBn, memberSlug, kind, textBn}`. `kind`: `"start"` (took office), `"end"` (left), `"change"` (both on one day). `textBn` is the page's line ("পানি সম্পদ মন্ত্রণালয়: দায়িত্ব পেলেন" / "State Minister, Ministry of Water Resources: took office"). `nameBn` en: null if no English name. |

The page groups the rows into ranks (প্রধানমন্ত্রী, মন্ত্রী, প্রতিমন্ত্রী, উপমন্ত্রী, উপদেষ্টা)
by `title`, and a person by `member.id` or `holderBn`.

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "checkedAt": "2026-10-08T03:17:44.556+00:00",
  "sourceUrl": "https://cabinet.gov.bd/pages/static-pages/মাননীয়-প্রধানমন্ত্রী-ও-মন্ত্রীগণ-027qky-6995…",
  "posts": [
    {
      "title": "State Minister",
      "ministryBn": "Ministry of Foreign Affairs",
      "fromDate": "2026-08-21",
      "member": null,
      "holderBn": "Humayun Kabir",
      "photoUrl": "https://objectstorage.ap-dcc-gazipur-1.oraclecloud15.com/…",
      "adviserSlug": "humayun-kabir",
      "rankNoteBn": null,
      "sourceUrl": "https://cabinet.gov.bd/pages/static-pages/মাননীয়-প্রতিমন্ত্রীগণ-4fy3i5-6995891734f8c2d8…"
    },
    "… 85 more"
  ],
  "pending": [],
  "changes": [
    { "date": "2026-08-21", "nameBn": "Humayun Kabir", "memberSlug": null, "kind": "start",
      "textBn": "State Minister, Ministry of Foreign Affairs: took office" },
    "… 19 more"
  ]
}
```

---

## GET /election

The 2026 election and the House it produced: the website's নির্বাচন / Election
page (`/nirbachon`) and statistics page (`/parisonkhan`) in one answer.
About 270 KB (gzip ~45 KB).

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang`, `parliamentNo` | | |
| `dates` | object | `{election, gazette, oath, end}`, days. |
| `house` | object | `{total, generalSeats, territorial, reserved, majority, parties[]}`: sitting members, the 300 general seats, members in general and reserved seats, the 176 needed for a majority. `parties[]`: `{abbr, labelBn, seats, seatsTerritorial}`, most seats first. |
| `voters` | object | `{registered, male, female, womenShare, pollingCentres, registeredParties, sourceBn, sourceUrl, readOn}`. `womenShare` is per cent, one decimal (`49.2`). `readOn`: day the figures were read. |
| `results` | object | Seat-by-seat results summed: `{seatsCounted, totalVotes, voteShare[], closest[], widest[], sourceBn}`. |
| `results.voteShare[]` | object | `{abbr, labelBn, votes}`: the six parties with most votes, then `{abbr: "other", labelBn: "অন্যান্য"/"Other"}`. |
| `results.closest[]`, `results.widest[]` | object | Five seats each, by the winner's margin: `{seatNo, seatBn, margin, winnerVotes, runnerUpParty, member}`; `runnerUpParty` is a short party name (null if not certain), `member` a brief or null. |
| `members` | object | See below. |
| `members.women`, `womenTerritorial`, `womenReserved`, `medianAge`, `freedomFighters` | number | |
| `members.youngest`, `members.oldest` | `{age, member}` \| null | `member`: brief. |
| `members.ageBands[]` | `{label, count}` | "৩০-এর নিচে", "৩০-৩৯"… / "Under 30", "30–39"…, "70+". |
| `members.professions[]` | `{label, count}` | The eight commonest professions, as the statistics page shows them (spellings of one job folded). **en: `label` null if untranslated.** Shares are of `withProfession`. |
| `members.withProfession` | number | Members whose profession is on record. |
| `members.firstTime`, `members.returning` | number | First-time members and those who sat before. |
| `members.experience[]` | `{label, count}` | "প্রথমবার"… / "First term", "Second term", "Third term", "Fourth or more". |
| `members.mostTerms[]` | `{member, terms}` | The eight elected most often (brief, times elected). |
| `committees` | `{total, current}` | Parliamentary committees, and those with an up-to-date member list. |
| `seats[]` | object | Every general seat with its place on the map (300), for the map of the country and the district cards. |
| `seats[].no`, `slug` | number, string | |
| `seats[].seatBn` | string \| null | Seat name. |
| `seats[].districtSlug`, `districtBn` | string | |
| `seats[].lon`, `seats[].lat` | number \| null | Where the seat's pin goes (WGS 84). |
| `seats[].member` | brief \| null | The sitting member; null while the seat is vacant. |
| `seats[].party` | string \| null | The sitting member's party abbreviation (colour the pin by it). |
| `seats[].votes` | number \| null | The winner's votes; null when no result is published. |
| `seats[].margin` | number \| null | Winner's votes minus the runner-up's. |
| `seats[].runnerUp` | object \| null | `{name, party, partyBn, votes}`. On English, null when the runner-up's name is known only in Bangla. |
| `earlier[]` | object | Seats by party in each parliament the House's database records, newest first, the current one included (general seats only): `{parliamentNo, labelBn, recorded, parties[]}`; `parties[]`: `{abbr, labelBn, seats}`, most first; `recorded` is the number of members recorded (by-elections and gaps can make it differ from the official result; the database has nothing for the 1st–3rd and 6th). |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "bn",
  "parliamentNo": 13,
  "dates": { "election": "2026-02-12", "gazette": "2026-02-13", "oath": "2026-02-17", "end": "2031-02-16" },
  "house": { "total": 347, "generalSeats": 300, "territorial": 298, "reserved": 49, "majority": 176,
             "parties": [{ "abbr": "BNP", "labelBn": "বিএনপি", "seats": 245, "seatsTerritorial": 210 }, "… 10 more"] },
  "voters": { "registered": 127711899, "male": 64825154, "female": 62885525, "womenShare": 49.2, "pollingCentres": 42779,
              "registeredParties": 60, "sourceBn": "বাংলাদেশ নির্বাচন কমিশন", "sourceUrl": "https://ecs.gov.bd/", "readOn": "2026-09-09" },
  "results": {
    "seatsCounted": 297,
    "totalVotes": 73579794,
    "voteShare": [{ "abbr": "BNP", "labelBn": "বিএনপি", "votes": 37112972 }, "… 6 more"],
    "closest": [{ "seatNo": 218, "seatBn": "মাদারিপুর-১", "margin": 385, "winnerVotes": 64909, "runnerUpParty": "বিএনপি",
                  "member": "{brief: sayed-uddin-ahmad-hanzala}" }, "… 4 more"],
    "widest": ["… 5 rows"],
    "sourceBn": "দ্য বিজনেস স্ট্যান্ডার্ড ও উইকিপিডিয়ায় প্রকাশিত আসনভিত্তিক ফল; নির্বাচন কমিশনের গেজেট…"
  },
  "members": {
    "women": 56, "womenTerritorial": 7, "womenReserved": 49, "medianAge": 60,
    "youngest": { "age": 25, "member": "{brief: mst-nusrat-tabassum-joty}" },
    "oldest": { "age": 86, "member": "{brief: mushfiqur-rahman}" },
    "ageBands": [{ "label": "৩০-এর নিচে", "count": 6 }, "… 5 more"],
    "professions": [{ "label": "ব্যবসা", "count": 125 }, "… 7 more"],
    "withProfession": 303,
    "freedomFighters": 14,
    "firstTime": 259,
    "returning": 88,
    "experience": [{ "label": "প্রথমবার", "count": 259 }, "… 3 more"],
    "mostTerms": [{ "member": "{brief: hafiz-uddin-ahmad-bir-bikram}", "terms": 7 }, "… 7 more"]
  },
  "committees": { "total": 72, "current": 57 },
  "seats": [
    { "no": 1, "slug": "panchagarh-1", "seatBn": "পঞ্চগড়-১", "districtSlug": "panchagarh", "districtBn": "পঞ্চগড়",
      "lon": 88.499, "lat": 26.373, "member": "{brief: barrister-muhammad-nawshad-zamir}", "party": "BNP",
      "votes": 176169, "margin": 8120,
      "runnerUp": { "name": "Md Sarjis Alam", "party": "NCP", "partyBn": "এনসিপি", "votes": 168049 } },
    "… 299 more"
  ],
  "earlier": [
    { "parliamentNo": 13, "labelBn": "ত্রয়োদশ সংসদ, ২০২৬", "recorded": 298,
      "parties": [{ "abbr": "BNP", "labelBn": "বাংলাদেশ জাতীয়তাবাদী দল (বি.এন.পি)", "seats": 210 }, "… 9 more"] },
    "… 8 more"
  ]
}
```

On English the same answer has `"labelBn": "BNP"`, `"ageBands": [{"label": "Under 30", …}]`,
`"professions": [{"label": "Business", "count": 125}, …]`, `"experience": [{"label": "First term", …}]`,
`"labelBn": "13th Parliament, 2026"`, `"sourceBn": "Bangladesh Election Commission"`.

---

## GET /news

The whole-site news and video list, as the website's সংবাদ / News page draws
it. Five minutes at the edge.

| Parameter | Meaning |
| --- | --- |
| `limit` | How many stories, default 200, at most 400. |
| `type` | `news` (no videos) or `video` (videos only). Not with `from`/`to`. |
| `from`, `to` | A span of days, `YYYY-MM-DD`, both included (`from` ≤ `to`). Returns 300 stories at a time with a cursor; `limit` and `type` are ignored. |
| `before` | With `from`/`to`: the previous page's `next`, for the next page. |
| `counts=1` | Instead of stories, the news page's figures: the same answer as [`/news/counts`](#get-newscounts). |
| `lang` | `en`: everything but the headlines in English (see [the story](#the-story)). |

Without `from`/`to`:

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang` | | |
| `stories[]` | [story](#the-story) | Newest first. |

With `from`/`to`:

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang`, `from`, `to` | | |
| `stories[]` | story | Newest first, up to 300. A story on a page boundary may appear on both pages: drop repeats by `id`. |
| `next` | instant \| null | Pass as `before=` for the next page; null on the last page. |
| `counts` | `{news, video}` \| null | The span's totals, on the first page only (null when `before` is given). |
| `unavailable` | `true` | Only while the feed's tables do not exist; then `stories` is empty. |

A bad span answers 400 `{"error":"bad range"}`.

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "from": "2026-10-16",
  "to": "2026-10-16",
  "stories": [
    {
      "id": "feed-103286",
      "date": "2026-10-16",
      "dateLabel": "Friday, 16 October 2026",
      "publishedAt": "2026-10-16T17:55:52+00:00",
      "lead": {
        "title": "দলীয় প্রার্থী হারলে ওই ইউনিয়নে উন্নয়নকাজ করবেন না, বললেন চিফ হুইপ মনি",
        "source": "Daily Janakantha",
        "url": "https://www.dailyjanakantha.com/politics/news/917396"
      },
      "also": [],
      "member": { "slug": "nurul-islam-moni", "name": "Nurul Islam Moni", "nameEn": "Nurul Islam Moni", "party": "BNP",
                  "color": "var(--color-pbnp)" },
      "members": [{ "slug": "nurul-islam-moni", "name": "Nurul Islam Moni", "nameEn": "Nurul Islam Moni", "party": "BNP",
                    "color": "var(--color-pbnp)" }],
      "kind": "news",
      "thumbnail": "https://www.dailyjanakantha.com/media/imgAll/…",
      "durationSeconds": null
    },
    "… 299 more"
  ],
  "next": "2026-10-16T03:24:18+00:00",
  "counts": { "news": 267, "video": 66 }
}
```

---

## GET /news/counts

The news page's figures, counted by the database. Also `GET /news?counts=1`.

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang` | | The figures are the same in both languages. |
| `today` | `{news, video, outlets}` | Today (Dhaka): headlines, videos, and how many outlets published them. |
| `total` | `{news, video}` | Everything since the feed began. |
| `months[]` | `{month, news, video}` | Every month with anything in it, newest first. |
| `outletCount` | number | Outlets on the list the site reads. |
| `unavailable` | `true` | Only while the feed's tables do not exist (all figures 0). |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "bn",
  "today": { "news": 16, "video": 6, "outlets": 14 },
  "total": { "news": 15934, "video": 2110 },
  "months": [{ "month": "2026-10", "news": 2452, "video": 475 }, "… 10 more"],
  "outletCount": 125
}
```

---

## GET /sessions

The sessions of Parliament (the website's অধিবেশন / Sessions page, `/odhibeshon`).

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang` | | |
| `parliament` | object | `{no, electionDate, gazetteDate, oathDate, endDate}`, days. |
| `counts` | `{sessions, sittings}` | |
| `lastSittingDate` | day \| null | |
| `sessions[]` | object | Newest first; the first is the current one (the source does not close sessions). |
| `sessions[].id` | string | |
| `sessions[].titleBn` | string | "তৃতীয় অধিবেশন" / "3rd session". |
| `sessions[].startDate`, `endDate` | day \| null | |
| `sessions[].sittings[]` | object | Newest first; the n-th sitting of the session is `sittings[length - n]`: `{id, titleBn, date, weekdayBn, pdfUrl}`. `titleBn`: the source's title ("দিনের কার্যসূচী: ১০-০৯-২০২৬") / "Order of the day: 10 September 2026". `pdfUrl`: the order of the day. |
| `sessions[].circulars[]` | object | `{no, titleBn, date, pdfUrl}`; "পরিপত্র-১" / "Circular 1". |
| `generalNotices[]` | object | The Secretariat's notices that name no member or committee, newest first (the page shows the first 25): `{id, titleBn, date, categoryBn, pdfUrl}`. English `titleBn` is the source's English title, **null if it has none**. |
| `officers[]` | object | The presiding officers, leaders and whips: `{role, roleBn, member, nameBn, tenureBn}`. `role` codes: `SPEAKER`, `DEPUTY_SPEAKER`, `LEADER_OF_HOUSE`, `OPPOSITION_LEADER`, `CHIEF_WHIP`, `WHIP`. `member`: brief, or null when the source does not link the officer to a member. `tenureBn`: "১২ মার্চ ২০২৬ -" / "from 12 March 2026", or null. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "parliament": { "no": 13, "electionDate": "2026-02-12", "gazetteDate": "2026-02-13", "oathDate": "2026-02-17", "endDate": "2031-02-16" },
  "counts": { "sessions": 3, "sittings": 61 },
  "lastSittingDate": "2026-09-10",
  "sessions": [
    {
      "id": "1533",
      "titleBn": "3rd session",
      "startDate": "2026-08-27",
      "endDate": null,
      "sittings": [{ "id": "171", "titleBn": "Order of the day: 10 September 2026", "date": "2026-09-10", "weekdayBn": "Thursday",
                     "pdfUrl": "https://www.parliament.gov.bd/api/upload/30fb3290-eaf1-44d5-96d9-b4420e756f1e.pdf" }, "… 8 more"],
      "circulars": [{ "no": 1, "titleBn": "Circular 1", "date": "2026-08-11",
                      "pdfUrl": "https://www.parliament.gov.bd/api/upload/950ff17e-9273-4045-a6ca-98bb9408c2f5.pdf" }]
    },
    "… 2 more"
  ],
  "generalNotices": [{ "id": "975", "titleBn": "Mr. Md. Golzar Hossain (Retired)", "date": "2026-10-01", "categoryBn": "Notification",
                       "pdfUrl": "https://www.parliament.gov.bd/api/upload/069c1ff6-965b-45b3-9eef-83a5cbff2629.pdf" }, "… 102 more"],
  "officers": [{ "role": "SPEAKER", "roleBn": "Speaker", "member": null, "nameBn": "Mr. Hafiz Uddin Ahmad Bir Bikram",
                 "tenureBn": "from 12 March 2026" }, "… 10 more"]
}
```

---

## GET /seats

Every seat (350), general seats then reserved, in number order (the
website's আসন / Constituencies page, `/ason`).

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang` | | |
| `seats[].no`, `slug` | number, string | |
| `seats[].nameBn` | string \| null | |
| `seats[].nameEn` | string \| null | The source's English, both languages. |
| `seats[].reserved` | boolean | |
| `seats[].districtSlug`, `districtBn` | string \| null | Null for reserved seats. |
| `seats[].memberId` | string \| null | The member listed for the seat (one who resigned stays until it is filled; see `vacant`). Matches a brief's `id` in the bootstrap's `members` or `former`. |
| `seats[].vacant` | boolean | No sitting member. |
| `seats[].vacantSince` | day \| null | The day the member resigned. |
| `seats[].boundaryBn` | string \| null | The Election Commission's description of the area; null for reserved seats. **en: null if untranslated.** |
| `seats[].boundaryTranslated` | boolean | |
| `seats[].nameAlt`, `seats[].districtAlt` | string \| null | **English answers only** (absent on Bangla): the Bangla seat and district names, for search. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "seats": [
    { "no": 1, "slug": "panchagarh-1", "nameBn": "Panchagarh-1", "nameEn": "Panchagarh-1", "reserved": false,
      "districtSlug": "panchagarh", "districtBn": "Panchagarh", "memberId": "013000101", "vacant": false, "vacantSince": null,
      "boundaryBn": "(a) Panchagarh Sadar, (b) Tentulia and (c) Atwari upazilas", "boundaryTranslated": true,
      "nameAlt": "পঞ্চগড়-১", "districtAlt": "পঞ্চগড়" },
    "… 349 more"
  ]
}
```

---

## GET /seat/{slug}

One seat (the website's `/ason/{slug}`). 404 for an unknown slug.

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang` | | |
| `seat` | object | The row of [`/seats`](#get-seats). |
| `member` | brief \| null | The sitting member; null while vacant. |
| `resignedMember` | brief + `resignedOn` \| null | While the seat is vacant: the member elected for it who resigned ("… resigned on 21 August 2026; a new member will be shown here once elected"). |
| `holders[]` | object | Who held the seat in earlier parliaments, newest first (general seats only): `{parliamentNo, labelBn, nameBn, nameEn, partyAbbr, partyBn, member}`. `member` is a brief when the holder sits in this parliament (link to their profile). English `nameBn`: null if no English name; `nameEn`: the source's English, null if none. |
| `oldBoundary` | boolean | Some holders are from before the 2008 redrawing of boundaries: say "seats from before 2008 may have covered a different area". |
| `results[]` | object | Every published result, newest first: `{parliamentNo, labelBn, totalVotes, turnout, candidates[], sourceUrl, sourceBn, noteBn}`. `totalVotes`/`turnout` (per cent) null when not published (the page then shows the candidates' total). `candidates[]`: `{name, party, partyBn, votes}`, most votes first, as in [`/mp`'s `result`](#get-mpslug). |
| `neighbours[]` | object | The district's other seats: `{no, slug, nameBn, member}`. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "seat": { "no": 3, "slug": "thakurgaon-1", "nameBn": "Thakurgaon-1", "nameEn": "Thakurgaon-1", "reserved": false,
            "districtSlug": "thakurgaon", "districtBn": "Thakurgaon", "memberId": "013000301", "vacant": true,
            "vacantSince": "2026-08-21", "boundaryBn": "Thakurgaon Sadar upazila", "boundaryTranslated": true },
  "member": null,
  "resignedMember": { "…brief fields": "…", "slug": "mirza-fakhrul-islam-alamgir", "resignedOn": "2026-08-21" },
  "holders": [{ "parliamentNo": 12, "labelBn": "12th Parliament, 2024", "nameBn": "Ramesh Chandra Sen", "nameEn": "Ramesh Chandra Sen",
                "partyAbbr": "BAL", "partyBn": "Bangladesh Awami League", "member": null }, "… 2 more"],
  "oldBoundary": false,
  "results": [
    {
      "parliamentNo": 13,
      "labelBn": "13th Parliament, 2026",
      "totalVotes": null,
      "turnout": null,
      "candidates": [{ "name": "Mirza Fakhrul Islam Alamgir", "party": "BNP", "partyBn": "BNP", "votes": 238836 }, "… 2 more"],
      "sourceUrl": "https://www.tbsnews.net/election-2026-seat/thakurgaon-1",
      "sourceBn": "The Business Standard",
      "noteBn": "Not checked against the Election Commission's gazette. Wikipedia also gives the same vo…"
    }
  ],
  "neighbours": [{ "no": 4, "slug": "thakurgaon-2", "nameBn": "Thakurgaon-2", "member": "{brief: md-abdus-salam}" }, "… 1 more"]
}
```

---

## GET /district/{slug}

One district (the website's `/jela/{slug}`). 404 for an unknown slug. The
slugs are in the bootstrap's `districtList`.

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang`, `slug` | | |
| `nameBn` | string | In the answer's language. |
| `nameEn` | string | English, both languages. |
| `introBn` | string | The district in a paragraph, from the site's records (division, seats and their areas, who holds them, who held them last time). |
| `seats[]` | object | In number order: `{no, slug, nameBn, vacant, member}`. `member` is the member listed for the seat, a brief, which is the resigned member while `vacant` is true (as the page shows). |
| `parties[]` | object | `{abbr, nameBn, seats}`: the members listed above, by party, most first. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "bn",
  "slug": "thakurgaon",
  "nameBn": "ঠাকুরগাঁও",
  "nameEn": "Thakurgaon",
  "introBn": "ঠাকুরগাঁও জেলা রংপুর বিভাগের একটি জেলা, জাতীয় সংসদে যার ৩টি আসন: ঠাকুরগাঁও-১ (ঠাকুরগাঁ…",
  "seats": [{ "no": 3, "slug": "thakurgaon-1", "nameBn": "ঠাকুরগাঁও-১", "vacant": true,
              "member": "{brief: mirza-fakhrul-islam-alamgir}" }, "… 2 more"],
  "parties": [{ "abbr": "BNP", "nameBn": "বাংলাদেশ জাতীয়তাবাদী দল (বি.এন.পি)", "seats": 3 }]
}
```

---

## GET /reserved

The fifty seats reserved for women (the website's `/sangrakkhito-ason`).

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang` | | |
| `total` | number | 50. |
| `filled` | number | Seats with a member. |
| `women`, `womenTerritorial` | number | Women members in all, and those elected to general seats. |
| `parties[]` | object | Parties holding reserved seats, most first: `{abbr, slug, nameBn, held}`. |
| `members[]` | brief | The members, in seat order. |
| `questions[]` | object | The page's questions and answers: `{questionBn, answerBn}`. |
| `sourceBn` | string | The page's source line. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "total": 50,
  "filled": 49,
  "women": 56,
  "womenTerritorial": 7,
  "parties": [{ "abbr": "BNP", "slug": "bnp", "nameBn": "Bangladesh Nationalist Party (BNP)", "held": 35 }, "… 5 more"],
  "members": ["{brief: selima-rahman}", "… 48 more"],
  "questions": [{ "questionBn": "What are the reserved seats for women?",
                  "answerBn": "Under Article 65 of the Constitution, 50 seats in Parliament are reserved for women, in…" }, "… 3 more"],
  "sourceBn": "The Constitution of the People's Republic of Bangladesh, Article 65; members' names and…"
}
```

---

## GET /party/{slug}

One party (the website's `/dol/{slug}`). The slug is the party's `slug` from
the bootstrap (`bnp`, `bjei`, `ind`…). 404 for an unknown slug.

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang`, `abbr`, `slug` | | |
| `nameBn` | string \| null | The full name. |
| `nameEn` | string \| null | The source's English, both languages. |
| `shortBn` | string | The short name. |
| `color` | string | [Colour token](#party-colours). |
| `seats`, `seatsTerritorial`, `seatsReserved` | number | |
| `profile` | object \| null | Null for independents and a party with no profile. Each text field is **null on English if untranslated**: |
| `profile.summaryBn` | string \| null | One or two sentences. |
| `profile.originBn` | string[] | The party's story, one string per paragraph. |
| `profile.foundedOn` | string \| null | `YYYY-MM-DD`, or `YYYY` when only the year is known. |
| `profile.founderBn` | string \| null | Several founders joined with " ও " / " and ". |
| `profile.founderKind` | `"person"` \| `"org"` \| null | |
| `profile.symbolBn` | string \| null | The electoral symbol. |
| `profile.leaderTitleBn`, `leaderNameBn` | string \| null | The party's head and their title. |
| `profile.leader` | brief \| null | When the head sits in this parliament. |
| `profile.secretaryTitleBn`, `secretaryNameBn`, `secretary` | | The same for the general secretary. |
| `profile.headquartersBn` | string \| null | |
| `profile.website` | string \| null | |
| `profile.sources[]` | `{url, label}` | |
| `profile.checked` | day \| null | Checked against the sources up to this day. |
| `profile.edited` | boolean | An editor changed the profile, so it is not all from the sources. |
| `logo` | object \| null | `{url, width, height, kind, page, licenceBn, licenceUrl, author}`. `kind`: `"logo"` or `"flag"`. `page` is the file's page on Wikimedia, the credit link; a CC BY logo must name its `author`. |
| `members[]` | brief | The members elected to general seats in seat order, then those for reserved seats. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "abbr": "BNP",
  "slug": "bnp",
  "nameBn": "Bangladesh Nationalist Party (BNP)",
  "nameEn": "Bangladesh Nationalist Party (BNP)",
  "shortBn": "BNP",
  "color": "var(--color-pbnp)",
  "seats": 245,
  "seatsTerritorial": 210,
  "seatsReserved": 35,
  "profile": {
    "summaryBn": "Founded by Ziaur Rahman, the party has won five general elections and has been in gover…",
    "originBn": ["Ziaur Rahman, then President, launched the party on 1 September 1978 …", "… 2 more"],
    "foundedOn": "1978-09-01",
    "founderBn": "Ziaur Rahman",
    "founderKind": "person",
    "symbolBn": "Sheaf of paddy",
    "leaderTitleBn": "Chairman",
    "leaderNameBn": "Tarique Rahman",
    "leader": "{brief: tarique-rahman}",
    "secretaryTitleBn": "Acting Secretary General",
    "secretaryNameBn": "Ruhul Kabir Rizvi",
    "secretary": null,
    "headquartersBn": "28/1 Naya Paltan, Dhaka",
    "website": "https://www.bnpbd.org",
    "sources": [{ "url": "https://bn.wikipedia.org/wiki/%E0%A6%AC%E0%A6%BE…", "label": "Wikipedia (Bangla)" }, "… 1 more"],
    "checked": "2026-09-11",
    "edited": false
  },
  "logo": { "url": "https://mymp.bd/party/bnp.webp", "width": 256, "height": 256, "kind": "logo",
            "page": "https://commons.wikimedia.org/wiki/File:BNP_logo.png", "licenceBn": "CC0",
            "licenceUrl": "https://creativecommons.org/publicdomain/zero/1.0/", "author": null },
  "members": ["{brief: barrister-muhammad-nawshad-zamir}", "… 244 more"]
}
```

---

## GET /committees

Parliament's committees (the website's `/committee`).

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang` | | |
| `total`, `current` | number | All committees, and those whose member list is updated for this parliament. |
| `membersOnCommittees` | number | MPs on at least one up-to-date committee. |
| `committees[]` | object | Up-to-date committees first, then the rest, each in the source's order. |
| `committees[].slug` | string | For `/committee/{slug}`. |
| `committees[].nameBn` | string \| null | |
| `committees[].nameEn` | string \| null | The source's English, both languages (untidied). |
| `committees[].type` | string \| null | `"Parliamentary Committee"` or `"Ministry Related Standing Committee"`. |
| `committees[].typeBn` | string \| null | "সংসদীয় কমিটি" / "Parliamentary committee"; "মন্ত্রণালয় সম্পর্কিত স্থায়ী কমিটি" / "Standing committee on a ministry". |
| `committees[].rosterCurrent` | boolean | False while the member list still holds the previous parliament's members: show no members then. |
| `committees[].memberCount` | number | |
| `committees[].startDate` | day \| null | When it was formed. |
| `committees[].chair` | brief \| null | Only for an up-to-date committee. |
| `committees[].summaryBn` | string \| null | What the committee does, in a sentence or two, where the Rules of Procedure say. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "bn",
  "total": 72,
  "current": 57,
  "membersOnCommittees": 345,
  "committees": [
    { "slug": "business-advisory-committee", "nameBn": "কার্য উপদেষ্টা কমিটি", "nameEn": "Business Advisory Committee",
      "type": "Parliamentary Committee", "typeBn": "সংসদীয় কমিটি", "rosterCurrent": true, "memberCount": 15,
      "startDate": "2026-09-01", "chair": "{brief: hafiz-uddin-ahmad-bir-bikram}",
      "summaryBn": "সংসদে সরকারি বিল ও অন্যান্য কাজের কোন ধাপে কত সময় আলোচনা হবে, তার সুপারিশ করে। স্পিকার…" },
    "… 71 more"
  ]
}
```

---

## GET /committee/{slug}

One committee (the website's `/committee/{slug}`). 404 for an unknown slug.

| Field | Type | Notes |
| --- | --- | --- |
| `version`, `lang`, `slug`, `nameBn`, `nameEn`, `type`, `typeBn`, `rosterCurrent`, `memberCount`, `startDate` | | As in [`/committees`](#get-committees). |
| `previousStartDate` | day \| null | When the same committee also has a record from the previous parliament. |
| `duty` | object \| null | What the committee does, from Parliament's Rules of Procedure: `{summaryBn, dutiesBn[], noteBn, ruleBn, rulesUrl, parent}`. `ruleBn`: where in the rules ("বিধি ২৩৩-২৩৪"). `parent`: `{slug, nameBn}` for a sub-committee's parent committee, else null. |
| `members[]` | object | The chair first, then the members: `{role, roleBn, member}`. `role`: `"Chairman"`, `"Member"` or another source role; `roleBn`: "সভাপতি"/"সদস্য" / "Chair"/"Member". **Empty when `rosterCurrent` is false.** |
| `notices[]` | object | Meeting notices, newest first: `{id, titleBn, date, pdfUrl}`. English `titleBn` is the source's English title, null if none. |

```json
{
  "version": "2026-10-10T08:58:17.257Z",
  "lang": "en",
  "slug": "public-accounts-committee-pac",
  "nameBn": "Public Accounts Committee (PAC)",
  "nameEn": "Public Accounts Committee (PAC)",
  "type": "Parliamentary Committee",
  "typeBn": "Parliamentary committee",
  "rosterCurrent": false,
  "memberCount": 15,
  "startDate": "2024-02-07",
  "previousStartDate": null,
  "duty": {
    "summaryBn": "Examines, with the reports of the Comptroller and Auditor-General, whether the Governme…",
    "dutiesBn": ["Examining the accounts showing the appropriation of sums granted by Parliament …", "… 3 more"],
    "noteBn": null,
    "ruleBn": "Article 76 of the Constitution; rules 233–234",
    "rulesUrl": "https://www.parliament.gov.bd/parliament-business/rules-of-procedure",
    "parent": null
  },
  "members": [],
  "notices": []
}
```

---

## Shared with the website

These two routes are the website's own; the app reads them as they are. They
send `access-control-allow-origin: *` on every answer and are gzipped. Five
minutes at the edge.

### GET /api/feed/{slug}

A member's news and videos (`/api/feed/tarique-rahman`, not under
`/api/app/v1`). 404 `{"error":"not found"}` for an unknown slug.

| Parameter | Answer |
| --- | --- |
| (none) | `{month, pinned[], items[], months[], total, news, video, outlets[], startsAt}`: the current month (Dhaka, `YYYY-MM`) and the pinned items, every month's counts (`months[]`: `{month, total, news, video}`, newest first), the totals, the outlets that carried the member (names), and the day the member's feed starts (`startsAt`, day or null). |
| `recent=N` | `{pinned[], items[]}`: the newest N items whatever their month (what the app's profile shows). |
| `m=YYYY-MM` | `{month, items[]}`: one month. |
| `from=YYYY-MM-DD&to=YYYY-MM-DD` | `{from, to, items[], more}`: a span, at most 1,000 items; `more: true` when there were more. |
| `type=news` \| `video` | Only headlines, or only videos (with any of the above). |
| `lang=en` | Adds `"lang": "en"`; every `outletName` (and `outlets[]`) in English, **null when the site has no English name for the outlet**. Titles and summaries stay as the outlets wrote them. |

An item: `{id, type, title, url, summary, outletName, thumbnailUrl,
durationSeconds, publishedAt, alsoIn[], pinned, lowConfidence}`. `type`:
`"news"`, `"video"`, `"press"` or `"social"`. `title` and `summary` are the
outlet's words (Bangla in both languages). `alsoIn[]`: `{outletName, url}`,
the same story elsewhere. `lowConfidence`: the member match is less certain.
Before the feed's tables exist the answer has `"unavailable": true` and empty
lists.

```json
{
  "pinned": [],
  "items": [
    { "id": 103726, "type": "news", "title": "প্রধানমন্ত্রীর শুভেচ্ছা বার্তা: ‘নিশ্চিন্তে দুর্গাপূজা উদযাপন করুন’",
      "url": "https://bangla.bdnews24.com/bangladesh/zt02l3usas", "summary": null, "outletName": "bdnews24",
      "thumbnailUrl": "https://media.assettype.com/bdnews24/…", "durationSeconds": null,
      "publishedAt": "2026-10-16T19:18:29.915+00:00", "alsoIn": [], "pinned": false, "lowConfidence": true },
    "… 1 more"
  ],
  "lang": "en"
}
```

### GET /api/news/range

`?from=YYYY-MM-DD&to=YYYY-MM-DD[&before=…]`: the same as
[`/api/app/v1/news?from=…&to=…`](#get-news) but always in Bangla and without
`version`/`lang`: `{from, to, stories[], next, counts}`.
The app should prefer `/api/app/v1/news`.
