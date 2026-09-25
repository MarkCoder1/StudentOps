# Student OPS Opportunity API — Phase 5.8

Read-only catalog backed by SQLite `opportunities.db` via Phase 5.7 storage. No scraping, no auth, no student-specific matching.

## Base URL

```
http://localhost:3000
```

## Endpoints

### `GET /api/opportunities`

List canonical opportunities.

**Query params:**

| Param | Type | Default | Max | Notes |
|-------|------|---------|-----|-------|
| `limit` | integer `>=1` | `50` | `100` | capped at 100 if higher, `400` if `<1` or non-integer |
| `offset` | integer `>=0` | `0` | — | `400` if `<0` or non-integer |
| `source` | `studentSuite` \| `devpost` \| `eventScraper` \| `scholarshipExtractor` \| `scholarshipFinder` | — | `400` `INVALID_SOURCE` if invalid, not silent 0 results |
| `category` | `competition` \| `hackathon` \| `scholarship` \| `internship` \| `fellowship` \| `research` \| `leadership` \| `volunteering` \| `summerProgram` \| `academicProgram` \| `workshop` \| `conference` \| `creative` \| `other` | — | `400` if invalid |
| `onlyActive` | `true` \| `false` | `false` | — | `400` if `banana`; when `true` uses Phase 5.6 `evaluateFreshness(opportunity, asOf)` (`asOf = now`), excludes `expired` only |

Combined example: `GET /api/opportunities?category=competition&source=studentSuite&onlyActive=true&limit=20&offset=0`

**Success 200:**

```json
{
  "data": [
    {
      "id": "studentSuite:breakthrough-junior-challenge",
      "source": "studentSuite",
      "externalId": "breakthrough-junior-challenge",
      "title": "Breakthrough Junior Challenge",
      "description": "...",
      "organization": "Breakthrough Prize Foundation",
      "officialUrl": "https://...",
      "applicationUrl": "https://...",
      "sourceUrl": "https://...",
      "category": "competition",
      "sourceCategory": "stem",
      "subjects": ["physics"],
      "topics": ["science communication"],
      "skills": [],
      "deadline": "2026-06-25",
      "startDate": null,
      "endDate": null,
      "location": { "type": "online", "city": null, "country": null, "online": true, "latitude": null, "longitude": null },
      "cost": { "amount": 0, "currency": "USD", "isFree": true },
      "benefits": { "awardText": "...", "awardAmount": null, "awardCurrency": null, "prizeText": "..." },
      "eligibility": { "minAge": 13, "maxAge": 18, "countries": ["IN"], "geographicRestrictions": "international", "enrollmentLevels": null, "majors": null, "requirements": null, "gradeMin": null, "gradeMax": null },
      "provenance": { "source": "studentSuite", "externalId": "breakthrough-junior-challenge", "fetchedAt": "2026-09-12T00:00:00.000Z", "sourceUpdatedAt": "2026-09-05" },
      "sourceMetadata": { "originalCategory": "stem", "cycle_year": 2026 },
      "sourceRecords": [{ "source": "studentSuite", "externalId": "breakthrough-junior-challenge" }]
    }
  ],
  "pagination": { "limit": 20, "offset": 0, "total": 1 }
}
```

`total` is count **matching filters** before pagination.

Empty DB: `200` `{ "data": [], "pagination": { "limit": 50, "offset": 0, "total": 0 } }`

**Errors 400:**

```json
{ "error": { "code": "INVALID_LIMIT", "message": "Invalid limit: must be integer >= 1" } }
{ "error": { "code": "INVALID_SOURCE", "message": "Invalid source: not-a-real-source" } }
{ "error": { "code": "INVALID_ONLYACTIVE", "message": "Invalid onlyActive: must be true or false" } }
```

**500:** never exposes stack/`APIFY_API_TOKEN`/`opportunities.db` path — logs server-side only.

### `GET /api/opportunities/[id]`

`id` is canonical `source:externalId` (may contain `: / - _`). Must be URL-encoded by client, server does `decodeURIComponent`.

**Success 200:**

```json
{ "data": { "id": "studentSuite:breakthrough-junior-challenge", "title": "...", ... } }
```

**Not found 404:**

```json
{ "error": { "code": "OPPORTUNITY_NOT_FOUND", "message": "Opportunity not found" } }
```

**Invalid id 400:** `code: "INVALID_ID"`

## Service layer

`src/server/opportunities/service.ts` — `OpportunityService` (`validateParams`, `getOpportunities`, `getOpportunityById`) → `OpportunityRepository` (`storage/repository.ts`) → `better-sqlite3` `opportunities.db`. Routes are thin, no SQL.

## Security

- Read-only `GET` only (no POST/PUT/PATCH/DELETE)
- No `APIFY_API_TOKEN`, `.env.local`, `opportunities.db` path, stack traces exposed
- No auth (public catalog per Phase 5.8)
- No CORS `*` added (same-origin; iOS will use `URLSession` to backend origin)

## Notes

- `GET /api/opportunities` never scrapes `StudentSuite`/`Apify`/`Devpost`/`EventScraper` — reads SQLite via storage. Verified by test `no external source calls`.
- `onlyActive` uses Phase 5.6 `evaluateFreshness(opportunity, new Date())` (`deadline`/`startDate`/`endDate` explicit `asOf`, no `Date.now()` scattered).
- Nested `subjects/topics/skills/location/cost/benefits/eligibility/provenance/sourceRecords` are real JSON objects (not stringified), verified by storage tests.
