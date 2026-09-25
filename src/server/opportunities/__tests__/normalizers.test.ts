import { describe, it, expect } from "vitest";
import { normalizeStudentSuite } from "../normalizers/studentSuite";
import { normalizeDevpost } from "../normalizers/devpost";
import { normalizeEventScraper } from "../normalizers/eventScraper";
import { normalizeScholarshipExtractor } from "../normalizers/scholarshipExtractor";
import { normalizeScholarshipFinder } from "../normalizers/scholarshipFinder";
import { normalizeOpportunity, validateOpportunity } from "../normalizers/index";

const FETCHED_AT = "2026-09-12T00:00:00.000Z";

// Sample payloads based on Phase 5.1 verification
const studentSuiteNormal = {
  id: "breakthrough-junior-challenge",
  name: "Breakthrough Junior Challenge",
  organizer: "Breakthrough Prize Foundation",
  organizer_url: "https://breakthroughjuniorchallenge.org",
  category: "stem",
  subjects: ["physics", "science communication"],
  description: "One to three sentences",
  format: "online",
  age_min: 13,
  age_max: 18,
  participation: "individual",
  region: "international",
  fee: { amount: 0, currency: "USD" },
  prize: "USD 250,000 scholarship",
  official_url: "https://breakthroughjuniorchallenge.org",
  cycle_year: 2026,
  dates: [
    { label: "Submission deadline", date: "2026-06-25", type: "deadline", timezone: "UTC-4", estimated: false, source_url: "https://example.com/rules" },
    { label: "Winners announced", date: "2026-11-15", type: "results", timezone: "UTC-5", estimated: false, source_url: "https://example.com/rules" },
  ],
  country_tracks: [{ country: "IN", track: "national" }],
  verified: { by: "yashkewlani", on: "2026-09-05" },
};

describe("StudentSuite normalizer", () => {
  it("normal competition", () => {
    const opp = normalizeStudentSuite(studentSuiteNormal as any, FETCHED_AT);
    expect(opp.id).toBe("studentSuite:breakthrough-junior-challenge");
    expect(opp.source).toBe("studentSuite");
    expect(opp.category).toBe("competition");
    expect(opp.title).toBe("Breakthrough Junior Challenge");
    expect(opp.subjects).toEqual(["physics", "science communication"]);
    expect(opp.location.type).toBe("online");
    expect(opp.cost.isFree).toBe(true);
    expect(opp.benefits.prizeText).toBe("USD 250,000 scholarship");
    expect(opp.provenance.fetchedAt).toBe(FETCHED_AT);
    const v = validateOpportunity(opp);
    expect(v.valid).toBe(true);
  });

  it("missing country_tracks", () => {
    const { country_tracks, ...rest } = studentSuiteNormal as any;
    const opp = normalizeStudentSuite(rest, FETCHED_AT);
    expect(opp.eligibility.countries).toBeNull();
    expect(validateOpportunity(opp).valid).toBe(true);
  });

  it("age range", () => {
    const opp = normalizeStudentSuite(studentSuiteNormal as any, FETCHED_AT);
    expect(opp.eligibility.minAge).toBe(13);
    expect(opp.eligibility.maxAge).toBe(18);
  });

  it("free fee", () => {
    const opp = normalizeStudentSuite(studentSuiteNormal as any, FETCHED_AT);
    expect(opp.cost.amount).toBe(0);
    expect(opp.cost.currency).toBe("USD");
    expect(opp.cost.isFree).toBe(true);
  });

  it("deadline extraction", () => {
    const opp = normalizeStudentSuite(studentSuiteNormal as any, FETCHED_AT);
    expect(opp.deadline).toBe("2026-06-25");
  });

  it("results date not mistaken for deadline", () => {
    const raw = {
      ...studentSuiteNormal,
      dates: [
        { label: "Winners announced", date: "2026-11-15", type: "results", timezone: "UTC-5", estimated: false, source_url: "https://example.com" },
      ],
    };
    const opp = normalizeStudentSuite(raw as any, FETCHED_AT);
    expect(opp.deadline).toBeNull();
  });

  it("missing optional fields must NOT fail", () => {
    const opp = normalizeStudentSuite({ id: "minimal", name: "Minimal" } as any, FETCHED_AT);
    expect(opp.title).toBe("Minimal");
    expect(validateOpportunity(opp).valid).toBe(true);
  });
});

describe("Devpost normalizer", () => {
  const base = {
    id: 29377,
    title: "Build with MeDo Hackathon",
    url: "https://medo.devpost.com/",
    organizationName: "Baidu",
    location: "Online",
    openState: "open",
    submissionPeriodDates: "Apr 09 - May 20, 2026",
    timeLeftToSubmission: "19 days left",
    themes: ["Beginner Friendly", "Machine Learning/AI"],
    prizeAmount: "$50,000",
    cashPrizesCount: 10,
    otherPrizesCount: 1,
    registrationsCount: 5159,
    featured: false,
    winnersAnnounced: false,
    inviteOnly: false,
    thumbnailUrl: "https://example.com/thumb.png",
    submissionGalleryUrl: "https://medo.devpost.com/project-gallery",
  };

  it("normal hackathon", () => {
    const opp = normalizeDevpost(base as any, FETCHED_AT);
    expect(opp.id).toBe("devpost:29377");
    expect(opp.category).toBe("hackathon");
    expect(opp.topics).toEqual(["Beginner Friendly", "Machine Learning/AI"]);
    expect(opp.location.type).toBe("online");
    expect(opp.location.online).toBe(true);
    expect(opp.benefits.prizeText).toBe("$50,000");
    expect(validateOpportunity(opp).valid).toBe(true);
  });

  it("online location", () => {
    const opp = normalizeDevpost({ ...base, location: "Online" } as any, FETCHED_AT);
    expect(opp.location.type).toBe("online");
  });

  it("themes", () => {
    const opp = normalizeDevpost(base as any, FETCHED_AT);
    expect(opp.topics).toEqual(["Beginner Friendly", "Machine Learning/AI"]);
  });

  it("prize text", () => {
    const opp = normalizeDevpost(base as any, FETCHED_AT);
    expect(opp.benefits.prizeText).toBe("$50,000");
    expect(opp.cost.amount).toBeNull();
  });

  it("parseable submission period", () => {
    const opp = normalizeDevpost(base as any, FETCHED_AT);
    expect(opp.startDate).toBe("2026-04-09");
    expect(opp.deadline).toBe("2026-05-20");
  });

  it("unparseable submission period", () => {
    const opp = normalizeDevpost({ ...base, submissionPeriodDates: "TBD" } as any, FETCHED_AT);
    expect(opp.startDate).toBeNull();
    expect(opp.deadline).toBeNull();
  });

  it("no invented deadline from timeLeftToSubmission", () => {
    const opp = normalizeDevpost({ ...base, submissionPeriodDates: undefined, timeLeftToSubmission: "19 days left" } as any, FETCHED_AT);
    expect(opp.deadline).toBeNull();
  });

  it("missing optional fields", () => {
    const opp = normalizeDevpost({ id: "1", title: "T" } as any, FETCHED_AT);
    expect(validateOpportunity(opp).valid).toBe(true);
  });
});

describe("Event Scraper normalizer", () => {
  const onlineEvent = {
    platform: "meetup",
    title: "AI Series: Stanford",
    startsAt: "2026-07-15T17:00:00.000Z",
    timezone: "Europe/Berlin",
    isOnline: true,
    venueName: null,
    address: null,
    city: "Berlin",
    country: "DE",
    latitude: null,
    longitude: null,
    rsvpCount: 196,
    capacity: 250,
    organizerName: "BLISS AI",
    organizerUrl: "https://meetup.com/bliss",
    ticketStatus: "free",
    currency: null,
    priceMin: null,
    topics: ["Ai", "Machine Learning"],
    category: "AI",
    coverImageUrl: "https://example.com/cover.png",
    eventUrl: "https://meetup.com/event/123",
  };
  const inPersonEvent = {
    ...onlineEvent,
    isOnline: false,
    venueName: "C130, TU Berlin",
    address: "Str. des 17. Juni 115",
    city: "Berlin",
    country: "DE",
    latitude: 52.52,
    longitude: 13.405,
    ticketStatus: "on_sale",
    currency: "EUR",
    priceMin: 10,
  };

  it("online event", () => {
    const opp = normalizeEventScraper(onlineEvent as any, FETCHED_AT);
    expect(opp.location.type).toBe("online");
    expect(opp.location.online).toBe(true);
    expect(opp.cost.isFree).toBe(true);
    expect(opp.startDate).toBe("2026-07-15T17:00:00.000Z");
    expect(opp.deadline).toBeNull();
  });

  it("in-person event", () => {
    const opp = normalizeEventScraper(inPersonEvent as any, FETCHED_AT);
    expect(opp.location.type).toBe("inPerson");
    expect(opp.location.city).toBe("Berlin");
    expect(opp.location.latitude).toBe(52.52);
  });

  it("null platform fields", () => {
    const opp = normalizeEventScraper({ title: "T", startsAt: "2026-07-15T17:00:00.000Z", eventUrl: "https://example.com" } as any, FETCHED_AT);
    expect(opp.location.type).toBe("unknown");
    expect(validateOpportunity(opp).valid).toBe(true);
  });

  it("start date", () => {
    const opp = normalizeEventScraper(onlineEvent as any, FETCHED_AT);
    expect(opp.startDate).toBe("2026-07-15T17:00:00.000Z");
  });

  it("price/free handling", () => {
    const free = normalizeEventScraper(onlineEvent as any, FETCHED_AT);
    expect(free.cost.isFree).toBe(true);
    const paid = normalizeEventScraper(inPersonEvent as any, FETCHED_AT);
    expect(paid.cost.isFree).toBe(false);
    expect(paid.cost.amount).toBe(10);
    expect(paid.cost.currency).toBe("EUR");
  });

  it("coordinates", () => {
    const opp = normalizeEventScraper(inPersonEvent as any, FETCHED_AT);
    expect(opp.location.latitude).toBe(52.52);
    expect(opp.location.longitude).toBe(13.405);
  });
});

describe("Scholarship Extractor normalizer", () => {
  it("scholarship", () => {
    const opp = normalizeScholarshipExtractor(
      { title: "Mastercard Scholarship", description: "Graduate", deadline: "2026-05-15", awards: "$869,000", challengeLink: "https://example.com", category: "Scholarships" } as any,
      FETCHED_AT
    );
    expect(opp.category).toBe("scholarship");
    expect(opp.benefits.awardText).toBe("$869,000");
    expect(opp.deadline).toBe("2026-05-15");
  });

  it("internship", () => {
    const opp = normalizeScholarshipExtractor({ title: "Intern", category: "Internships", challengeLink: "https://example.com" } as any, FETCHED_AT);
    expect(opp.category).toBe("internship");
  });

  it("competition via App Challenge", () => {
    const opp = normalizeScholarshipExtractor({ title: "App Challenge Title", category: "App Challenge", challengeLink: "https://example.com" } as any, FETCHED_AT);
    expect(opp.category).toBe("competition");
  });

  it("Not specified deadline", () => {
    const opp = normalizeScholarshipExtractor(
      { title: "T", category: "Scholarships", deadline: "Not specified", challengeLink: "https://example.com" } as any,
      FETCHED_AT
    );
    expect(opp.deadline).toBeNull();
  });

  it("Not specified award", () => {
    const opp = normalizeScholarshipExtractor(
      { title: "T", category: "Scholarships", awards: "Not specified", challengeLink: "https://example.com" } as any,
      FETCHED_AT
    );
    expect(opp.benefits.awardText).toBeNull();
  });

  it("missing optional fields", () => {
    const opp = normalizeScholarshipExtractor({ title: "Minimal", category: "Scholarships", challengeLink: "https://example.com/min" } as any, FETCHED_AT);
    expect(validateOpportunity(opp).valid).toBe(true);
  });
});

describe("Scholarship Finder normalizer", () => {
  it("detailed record", () => {
    const opp = normalizeScholarshipFinder(
      {
        title: "Test Scholarship",
        detail_url: "https://collegescholarships.org/s/1",
        award: "$5,000",
        award_amount: 5000,
        deadline: "2026-06-01",
        description: "For engineering majors",
        geographic_restrictions: "US",
        enrollment_level: "Undergraduate",
        majors: ["Engineering", "Computer Science"],
        min_award: 1000,
        max_award: 5000,
      } as any,
      FETCHED_AT
    );
    expect(opp.category).toBe("scholarship");
    expect(opp.benefits.awardText).toBe("$5,000");
    expect(opp.benefits.awardAmount).toBe(5000);
    expect(opp.deadline).toBe("2026-06-01");
    expect(opp.eligibility.geographicRestrictions).toBe("US");
    expect(opp.eligibility.majors).toEqual(["Engineering", "Computer Science"]);
    expect(opp.subjects).toEqual(["Engineering", "Computer Science"]);
  });

  it("missing optional details", () => {
    const opp = normalizeScholarshipFinder({ title: "Minimal", detail_url: "https://example.com/s/2" } as any, FETCHED_AT);
    expect(opp.benefits.awardText).toBeNull();
    expect(validateOpportunity(opp).valid).toBe(true);
  });

  it("award amount", () => {
    const opp = normalizeScholarshipFinder(
      { title: "T", detail_url: "https://example.com", award: "$1,000", award_amount: 1000 } as any,
      FETCHED_AT
    );
    expect(opp.benefits.awardAmount).toBe(1000);
  });

  it("geographic restrictions", () => {
    const opp = normalizeScholarshipFinder(
      { title: "T", detail_url: "https://example.com", geographic_restrictions: "California" } as any,
      FETCHED_AT
    );
    expect(opp.eligibility.geographicRestrictions).toBe("California");
  });

  it("enrollment level", () => {
    const opp = normalizeScholarshipFinder(
      { title: "T", detail_url: "https://example.com", enrollment_level: "Graduate" } as any,
      FETCHED_AT
    );
    expect(opp.eligibility.enrollmentLevels).toEqual(["Graduate"]);
  });
});

describe("central dispatcher + validation", () => {
  it("dispatches studentSuite", () => {
    const opp = normalizeOpportunity("studentSuite", { id: "x", name: "Y" }, FETCHED_AT);
    expect(opp.source).toBe("studentSuite");
  });
  it("dispatches devpost", () => {
    const opp = normalizeOpportunity("devpost", { id: 1, title: "H" }, FETCHED_AT);
    expect(opp.category).toBe("hackathon");
  });
  it("missing optional fields must NOT fail", () => {
    const opp = normalizeOpportunity("eventScraper", { title: "T", eventUrl: "https://example.com" }, FETCHED_AT);
    expect(validateOpportunity(opp).valid).toBe(true);
  });
  it("id deterministic", () => {
    const a = normalizeOpportunity("studentSuite", { id: "same", name: "A" }, FETCHED_AT);
    const b = normalizeOpportunity("studentSuite", { id: "same", name: "B" }, FETCHED_AT);
    expect(a.id).toBe(b.id);
    expect(a.id).toBe("studentSuite:same");
  });
  it("invalid URL fails validation", () => {
    const opp = normalizeOpportunity("studentSuite", { id: "x", name: "Y", official_url: "not a url" }, FETCHED_AT);
    const v = validateOpportunity(opp);
    expect(v.valid).toBe(false);
    expect(v.errors.join()).toContain("officialUrl");
  });
});
