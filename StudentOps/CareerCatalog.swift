import Foundation

// MARK: - Deterministic Career Catalog + Skill Graph (Phase 11A)
// DEMO/CATALOG DATA — clearly marked, not live labor-market data.
// All skills use canonical Skill IDs via Skill.normalizeID().

enum CareerCatalog {

    static let all: [Career] = [
        Career(
            id: "software-engineering",
            title: "Software Engineering",
            description: "Design, build, and maintain software systems — from apps to infrastructure. (Catalog demo data)",
            fields: ["Computer Science", "Engineering"],
            industries: ["Technology", "Software"],
            skills: ["Programming", "Programming Fundamentals", "Computational Thinking", "Software Development", "Version Control", "Git", "Debugging", "APIs", "Unit Testing"],
            relatedSkills: ["Technical Communication", "Project Planning", "Problem Solving"],
            interests: ["Technology", "Engineering", "Building things"],
            educationRequirements: ["High school + post-secondary CS or equivalent experience"],
            commonActivities: ["Write code", "Debug", "Review pull requests", "Design APIs"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "data-science",
            title: "Data Science",
            description: "Extract insights from data using statistics, programming, and visualization. (Catalog demo data)",
            fields: ["Computer Science", "Statistics", "Mathematics"],
            industries: ["Technology", "Analytics"],
            skills: ["Python", "Data Analysis", "Data Collection", "Statistics", "Mathematics", "Model Evaluation"],
            relatedSkills: ["Research Methods", "Technical Communication", "Critical Thinking"],
            interests: ["Technology", "Science", "Mathematics"],
            educationRequirements: ["High school + quantitative post-secondary"],
            commonActivities: ["Clean data", "Build models", "Visualize insights"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "ai-ml",
            title: "AI/ML Engineering",
            description: "Build systems that learn from data — models, evaluation, and AI applications. (Catalog demo data)",
            fields: ["Computer Science", "AI", "Mathematics"],
            industries: ["Technology", "AI"],
            skills: ["Python", "Machine Learning", "Model Evaluation", "AI Application Development", "AI Literacy", "Data Analysis", "Statistics"],
            relatedSkills: ["Research Methods", "Technical Communication", "Computational Thinking"],
            interests: ["Technology", "AI", "Engineering"],
            educationRequirements: ["High school + CS/AI post-secondary"],
            commonActivities: ["Train models", "Evaluate models", "Build AI apps"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "cybersecurity",
            title: "Cybersecurity",
            description: "Protect systems and data — assess risks, secure networks, respond to incidents. (Catalog demo data)",
            fields: ["Computer Science", "Engineering"],
            industries: ["Technology", "Security"],
            skills: ["Version Control", "Technical Exploration", "Research Methods", "Problem Solving", "Quality Assurance"],
            relatedSkills: ["Communication", "Critical Thinking", "Technical Writing"],
            interests: ["Technology", "Engineering"],
            educationRequirements: ["High school + security-focused post-secondary"],
            commonActivities: ["Assess vulnerabilities", "Monitor threats", "Harden systems"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "mechanical-engineering",
            title: "Mechanical Engineering",
            description: "Design mechanical systems — from prototypes to manufacturing. (Catalog demo data)",
            fields: ["Engineering", "Physics"],
            industries: ["Engineering", "Manufacturing"],
            skills: ["Technical Exploration", "Building Things", "Prototyping", "Problem Solving", "Technical Skills"],
            relatedSkills: ["Project Planning", "Communication", "Mathematics"],
            interests: ["Engineering", "Building things"],
            educationRequirements: ["High school + engineering post-secondary"],
            commonActivities: ["Prototype", "Test", "Iterate"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "electrical-engineering",
            title: "Electrical Engineering",
            description: "Design electrical systems — circuits, embedded, and power. (Catalog demo data)",
            fields: ["Engineering", "Physics"],
            industries: ["Engineering", "Electronics"],
            skills: ["Technical Exploration", "Technical Skills", "Building Things", "Problem Solving", "Mathematics"],
            relatedSkills: ["Project Planning", "Technical Communication"],
            interests: ["Engineering", "Technology"],
            educationRequirements: ["High school + engineering post-secondary"],
            commonActivities: ["Design circuits", "Test hardware", "Build prototypes"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "biomedical-engineering",
            title: "Biomedical Engineering",
            description: "Apply engineering to medicine — devices, research, and health solutions. (Catalog demo data)",
            fields: ["Engineering", "Biology", "Medicine"],
            industries: ["Engineering", "Healthcare"],
            skills: ["Scientific Method", "Research Methods", "Data Analysis", "Technical Exploration", "Problem Solving"],
            relatedSkills: ["Technical Writing", "Communication", "Scientific Communication"],
            interests: ["Engineering", "Science", "Medicine"],
            educationRequirements: ["High school + biomedical post-secondary"],
            commonActivities: ["Research", "Prototype devices", "Analyze data"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "product-design",
            title: "Product Design",
            description: "Design products that people love — research, prototyping, and iteration. (Catalog demo data)",
            fields: ["Design", "Engineering", "Business"],
            industries: ["Technology", "Design"],
            skills: ["Prototyping", "User Research", "Technical Communication", "Creativity", "Product Thinking"],
            relatedSkills: ["Iteration", "Communication", "Technical Exploration"],
            interests: ["Design", "Technology", "Entrepreneurship"],
            educationRequirements: ["High school + design/business post-secondary"],
            commonActivities: ["Research users", "Prototype", "Test with users"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "business-entrepreneurship",
            title: "Business / Entrepreneurship",
            description: "Build and operate ventures — strategy, product, and leadership. (Catalog demo data)",
            fields: ["Business", "Entrepreneurship"],
            industries: ["Business", "Entrepreneurship"],
            skills: ["Business Fundamentals", "Project Planning", "Leadership", "Communication", "Product Thinking", "Initiative"],
            relatedSkills: ["Iteration", "Decision Making", "Collaboration", "Creativity"],
            interests: ["Business", "Entrepreneurship"],
            educationRequirements: ["High school + business post-secondary or equivalent experience"],
            commonActivities: ["Plan business", "Build product", "Lead team"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        // Additional for breadth (to reach >9, but keep deterministic)
        Career(
            id: "research-science",
            title: "Research Science",
            description: "Investigate questions — design studies, collect data, and share findings. (Catalog demo data)",
            fields: ["Biology", "Chemistry", "Physics"],
            industries: ["Research", "Science"],
            skills: ["Research Methods", "Scientific Method", "Data Collection", "Data Analysis", "Source Evaluation", "Technical Writing"],
            relatedSkills: ["Question Formation", "Scientific Communication", "Critical Thinking"],
            interests: ["Science", "Research"],
            educationRequirements: ["High school + science post-secondary"],
            commonActivities: ["Form questions", "Collect data", "Write papers"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "cybersecurity-analyst",
            title: "Cybersecurity Analyst",
            description: "Monitor and defend — analysis and incident response. (Catalog demo data)",
            fields: ["Computer Science", "Security"],
            industries: ["Technology", "Security"],
            skills: ["Research Methods", "Problem Solving", "Technical Exploration", "Source Evaluation", "Quality Assurance"],
            relatedSkills: ["Communication", "Critical Thinking"],
            interests: ["Technology", "Engineering"],
            educationRequirements: ["High school + security post-secondary"],
            commonActivities: ["Analyze logs", "Respond to incidents"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
        Career(
            id: "design-engineering",
            title: "Design Engineering",
            description: "Blend design and engineering — build functional, beautiful systems. (Catalog demo data)",
            fields: ["Engineering", "Design"],
            industries: ["Engineering", "Design"],
            skills: ["Prototyping", "Building Things", "Technical Exploration", "Creativity", "Project Planning"],
            relatedSkills: ["Technical Communication", "Iteration"],
            interests: ["Engineering", "Design"],
            educationRequirements: ["High school + design/engineering post-secondary"],
            commonActivities: ["Sketch", "Prototype", "Test"],
            source: CareerSourceMetadata(sourceID: "catalog-demo", sourceName: "Student OPS Catalog (Demo)", sourceType: "catalog", publisher: "Student OPS"),
            status: .catalog
        ),
    ]

    static var byID: [String: Career] {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }

    static func career(for id: String) -> Career? {
        let nid = Career.normalizeID(title: id)
        return byID[nid] ?? byID[id]
    }

    // MARK: - Deterministic Catalog Helpers

    static var sortedTitles: [String] { all.map(\.title).sorted() }
}

// MARK: - Career ↔ Skill Graph (deterministic, reuse Skill.normalizeID)

enum CareerSkillGraph {

    // All relationships — built deterministically from catalog + explicit type mapping
    static var allRelationships: [CareerSkillRelationship] = {
        var out: [CareerSkillRelationship] = []
        var seen = Set<String>() // "careerID|skillID"
        for career in CareerCatalog.all {
            // Map catalog skills to relationship types
            // First 3 skills = foundational, next 3 = core, next = supporting, relatedSkills = supporting, etc.
            // Documented: foundational > core > supporting > advanced
            // For demo, assign types deterministically based on position
            for (idx, raw) in career.skills.enumerated() {
                let nid = Skill.normalizeID(raw)
                guard !nid.isEmpty else { continue }
                let key = "\(career.id)|\(nid)"
                if seen.contains(key) { continue }
                seen.insert(key)
                let type: CareerSkillRelationshipType
                if idx < 2 { type = .foundational }
                else if idx < 5 { type = .core }
                else if idx < 7 { type = .supporting }
                else { type = .advanced }
                out.append(CareerSkillRelationship(careerID: career.id, skillID: nid, relationshipType: type))
            }
            for raw in career.relatedSkills {
                let nid = Skill.normalizeID(raw)
                guard !nid.isEmpty else { continue }
                let key = "\(career.id)|\(nid)"
                if seen.contains(key) { continue }
                seen.insert(key)
                out.append(CareerSkillRelationship(careerID: career.id, skillID: nid, relationshipType: .supporting))
            }
        }
        // Deterministic ordering: careerID asc, importance desc, skillID asc
        out.sort {
            if $0.careerID != $1.careerID { return $0.careerID < $1.careerID }
            if $0.importance != $1.importance { return $0.importance > $1.importance }
            return $0.skillID < $1.skillID
        }
        return out
    }()

    static func relationships(for careerID: String) -> [CareerSkillRelationship] {
        let nid = Career.normalizeID(title: careerID)
        return allRelationships.filter { $0.careerID == nid }
    }

    static func skills(for careerID: String) -> [String] {
        relationships(for: careerID).map(\.skillID)
    }

    static func requiredSkills(for careerID: String) -> [String] {
        relationships(for: careerID).filter { $0.relationshipType == .foundational || $0.relationshipType == .core }.map(\.skillID)
    }

    static func careerIDs(for skillID: String) -> [String] {
        let sid = Skill.normalizeID(skillID)
        return allRelationships.filter { $0.skillID == sid }.map(\.careerID).sorted()
    }

    // Prerequisites — small deterministic graph where explicitly defined
    static let prerequisites: [SkillPrerequisite] = [
        SkillPrerequisite(skillID: "Data Structures", prerequisiteSkillID: "Programming Fundamentals"),
        SkillPrerequisite(skillID: "Algorithms", prerequisiteSkillID: "Data Structures"),
        SkillPrerequisite(skillID: "Databases", prerequisiteSkillID: "Programming Fundamentals"),
        SkillPrerequisite(skillID: "APIs", prerequisiteSkillID: "Programming Fundamentals"),
        SkillPrerequisite(skillID: "Software Architecture", prerequisiteSkillID: "Software Development"),
        SkillPrerequisite(skillID: "Machine Learning", prerequisiteSkillID: "Python"),
        SkillPrerequisite(skillID: "AI Application Development", prerequisiteSkillID: "Machine Learning"),
        SkillPrerequisite(skillID: "Data Analysis", prerequisiteSkillID: "Statistics"),
        SkillPrerequisite(skillID: "Research Methods", prerequisiteSkillID: "Question Formation"),
    ]

    static func prerequisites(for skillID: String) -> [String] {
        let sid = Skill.normalizeID(skillID)
        return prerequisites.filter { $0.skillID == sid }.map(\.prerequisiteSkillID).sorted()
    }

    static func hasPrerequisite(_ skillID: String) -> Bool {
        !prerequisites(for: skillID).isEmpty
    }
}
