import Foundation

struct RoadmapService {
    static func roadmaps(for profile: StudentProfile, progress: [String: Int]) -> [ScoredRoadmap] {
        catalog.map { roadmap in
            ScoredRoadmap(roadmap: roadmap, matchScore: matchScore(for: roadmap, profile: profile), completedMilestones: min(progress[roadmap.id] ?? 0, roadmap.milestones.count))
        }.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            return lhs.matchScore > rhs.matchScore
        }
    }

    static func matchScore(for roadmap: Roadmap, profile: StudentProfile) -> Int {
        var score = 50
        score += profile.interests.filter { roadmap.relevantInterests.contains($0) }.count * 6
        score += (profile.strengths + profile.customSkills).filter { roadmap.relevantSkills.contains($0) }.count * 5
        score += profile.careers.filter { roadmap.relevantCareers.contains($0) }.count * 9
        score += profile.fields.filter { roadmap.relevantFields.contains($0) }.count * 8
        if roadmap.eligibleGrades.contains(profile.grade) { score += 7 }
        if roadmap.collegeFocused && (profile.collegePlan == .yesDefinitely || profile.collegePlan == .probably) { score += 8 }
        return min(max(score, 48), 99)
    }

    /// Complete catalog of all 10 roadmap templates.
    static var allRoadmaps: [Roadmap] { catalog }

    /// Returns the roadmap with the matching ID, if found.
    static func roadmap(for id: String) -> Roadmap? {
        catalog.first { $0.id == id }
    }

    private static let catalog: [Roadmap] = [
        Roadmap(id: "software-engineer", title: "Become a Software Engineer", goal: "Turn your technical interests into a project-ready software engineering foundation.", category: .career, description: "A practical sequence from programming fundamentals to a portfolio and career-ready next steps.", milestones: [
            .init(
                id: "software-1", title: "Explore Computer Science", subtitle: "Map the concepts and tools behind modern software.", estimatedTime: "30 min",
                whatItAccomplishes: "Build a mental model of what software engineering is, what software engineers do daily, and which areas interest you most.",
                whyItMatters: "Understanding the landscape before writing code helps you choose a focused path instead of wandering randomly through tutorials.",
                goal: "Develop a clear picture of what software engineering involves and identify the area that interests you most.",
                actions: [
                    MilestoneAction(id: "software-1-action-1", title: "Watch a day-in-the-life video", description: "Watch 2–3 videos of software engineers describing their daily work. Note what sounds interesting and what does not.", order: 1),
                    MilestoneAction(id: "software-1-action-2", title: "Explore subfields", description: "Read one-paragraph descriptions of web development, mobile apps, data science, AI/ML, game development, and cybersecurity. Pick 1–2 areas to investigate further.", order: 2),
                    MilestoneAction(id: "software-1-action-3", title: "Set up your development environment", description: "Install a code editor (VS Code), create a free GitHub account, and open your first file in the editor.", order: 3),
                    MilestoneAction(id: "software-1-action-4", title: "Write your first program", description: "Follow a 15-minute 'Hello World' tutorial in a beginner-friendly language (Python or JavaScript). Run it and see the output.", order: 4),
                ],
                skillsDeveloped: ["Computational Thinking", "Development Environment Setup", "Version Control Basics"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Articulate in 2–3 sentences what software engineering means to you.",
                    "Identify 1–2 subfields you want to explore next.",
                    "Have a working code editor and GitHub account.",
                ],
                learningResources: [
                    MilestoneResource(id: "sw1-res-1", title: "CS50: Introduction to Computer Science", provider: "Harvard / edX", url: "https://cs50.harvard.edu/x/", type: .course, description: "Free, high-quality introduction to computational thinking and the fundamentals of CS.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "sw1-res-2", title: "Getting Started with Visual Studio Code", provider: "Microsoft", url: "https://code.visualstudio.com/docs/getstarted/getting-started", type: .documentation, description: "Official guide to installing and configuring VS Code.", estimatedTime: "15 min"),
                    MilestoneResource(id: "sw1-res-3", title: "Hello World · GitHub Docs", provider: "GitHub", url: "https://docs.github.com/en/get-started/quickstart/hello-world", type: .documentation, description: "Create your first repository, commit, and push in under 10 minutes.", estimatedTime: "10 min"),
                ],
                assessment: MilestoneAssessment(id: "sw1-assessment", questions: [
                    ValidationQuestion(id: "sw1-q1", question: "What is an algorithm?", choices: [
                        "A type of computer hardware",
                        "A step-by-step procedure for solving a problem",
                        "A programming language",
                        "A website for learning code",
                    ], correctAnswer: 1, explanation: "An algorithm is a clear, step-by-step set of instructions for solving a problem or accomplishing a task."),
                    ValidationQuestion(id: "sw1-q2", question: "What is the main purpose of a development environment like VS Code?", choices: [
                        "To browse the internet",
                        "To write, edit, and organize code efficiently",
                        "To play video games",
                        "To send emails",
                    ], correctAnswer: 1, explanation: "A development environment provides tools for writing, editing, debugging, and organizing code in one place."),
                    ValidationQuestion(id: "sw1-q3", question: "What does version control (like Git) track?", choices: [
                        "Your school grades",
                        "Changes to files over time",
                        "Internet browsing history",
                        "Social media posts",
                    ], correctAnswer: 1, explanation: "Version control records every change made to your code, letting you revisit earlier versions and collaborate with others."),
                ])
            ),
            .init(
                id: "software-2", title: "Build Programming Fundamentals", subtitle: "Build fluency with core programming patterns.", estimatedTime: "2–4 weeks",
                whatItAccomplishes: "Develop working fluency with variables, conditions, loops, functions, and basic data structures — the building blocks of every software project.",
                whyItMatters: "Every programming language and framework builds on these patterns. Strong fundamentals make learning new tools faster and less frustrating.",
                goal: "Write programs that use variables, conditions, loops, and functions to solve small, concrete problems.",
                actions: [
                    MilestoneAction(id: "software-2-action-1", title: "Complete a structured beginner course", description: "Finish a free course like Codecademy's Python/JS track, freeCodeCamp's basic curriculum, or CS50's Week 0–2. Focus on exercises, not just watching.", order: 1),
                    MilestoneAction(id: "software-2-action-2", title: "Solve 10–15 practice problems", description: "Use a platform like Codewars (8kyu–7kyu), LeetCode (Easy), or Exercism to solve problems using loops, conditionals, and functions.", order: 2),
                    MilestoneAction(id: "software-2-action-3", title: "Build a command-line tool", description: "Create a small program that takes user input and produces output — such as a quiz game, a unit converter, or a to-do list that runs in the terminal.", order: 3),
                    MilestoneAction(id: "software-2-action-4", title: "Learn basic data structures", description: "Use arrays/lists and dictionaries/maps in at least two programs. Understand when to use each one.", order: 4),
                ],
                skillsDeveloped: ["Programming Fundamentals", "Problem Solving", "Python", "JavaScript", "Data Structures"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Write at least one program that uses conditionals, loops, and functions together.",
                    "Solve at least 10 practice problems on a coding platform.",
                    "Explain in plain language what a function does and why it is useful.",
                ],
                dependencies: ["software-1"],
                learningResources: [
                    MilestoneResource(id: "sw2-res-1", title: "Scientific Computing with Python", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/learn/scientific-computing-with-python/", type: .course, description: "Free, project-based Python certification covering variables, loops, functions, and data structures.", estimatedTime: "300 hrs (self-paced)"),
                    MilestoneResource(id: "sw2-res-2", title: "The Python Tutorial", provider: "Python.org", url: "https://docs.python.org/3/tutorial/", type: .documentation, description: "Official Python tutorial — covers the language from first concepts through classes.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "sw2-res-3", title: "Python Tutorial for Beginners", provider: "W3Schools", url: "https://www.w3schools.com/python/", type: .interactive, description: "Interactive, browser-based Python lessons with try-it-yourself editors.", estimatedTime: "Self-paced"),
                ],
                assessment: MilestoneAssessment(id: "sw2-assessment", questions: [
                    ValidationQuestion(id: "sw2-q1", question: "What is a variable in programming?", choices: [
                        "A fixed value that never changes",
                        "A named container that stores a value",
                        "A type of loop",
                        "A function that returns nothing",
                    ], correctAnswer: 1, explanation: "A variable is a named label that refers to a value stored in memory. The value can change as the program runs."),
                    ValidationQuestion(id: "sw2-q2", question: "What does a conditional statement (if/else) do?", choices: [
                        "Repeats code multiple times",
                        "Makes the program run faster",
                        "Chooses different actions based on whether a condition is true or false",
                        "Stores data in a file",
                    ], correctAnswer: 2, explanation: "Conditionals let your program make decisions — running one block of code when a condition is true and another when it is false."),
                    ValidationQuestion(id: "sw2-q3", question: "What is the purpose of a loop?", choices: [
                        "To delete old files",
                        "To repeat a set of instructions until a condition is met",
                        "To connect to the internet",
                        "To create a new variable",
                    ], correctAnswer: 1, explanation: "Loops let you repeat code efficiently instead of writing the same lines over and over."),
                    ValidationQuestion(id: "sw2-q4", question: "What does a function allow you to do?", choices: [
                        "Run your program without errors",
                        "Reuse a block of code by calling it by name",
                        "Store data permanently on a hard drive",
                        "Connect to a database",
                    ], correctAnswer: 1, explanation: "A function packages a set of instructions into a reusable block you can call whenever you need it."),
                ])
            ),
            .init(
                id: "software-3", title: "Learn Software Development", subtitle: "Understand how real software is built beyond single scripts.", estimatedTime: "3–5 weeks",
                whatItAccomplishes: "Move from writing isolated scripts to understanding how software systems work — version control, debugging, APIs, and basic testing.",
                whyItMatters: "Professional software is more than one file of code. These practices are what separate a student project from a maintainable, shareable one.",
                goal: "Use Git, debug effectively, call an API, and write a basic test — the core practices of software development.",
                actions: [
                    MilestoneAction(id: "software-3-action-1", title: "Learn Git fundamentals", description: "Complete a Git tutorial (GitHub's official guide or a free course). Practice init, add, commit, push, pull, branch, and merge in a personal repository.", order: 1),
                    MilestoneAction(id: "software-3-action-2", title: "Master your debugger", description: "Learn to set breakpoints, inspect variables, and step through code in VS Code. Fix a bug using the debugger instead of print statements.", order: 2),
                    MilestoneAction(id: "software-3-action-3", title: "Call a public API", description: "Use fetch/requests in your language to retrieve data from a public API (e.g., weather, Pokémon, Open Trivia). Display the results to the user.", order: 3),
                    MilestoneAction(id: "software-3-action-4", title: "Write your first test", description: "Learn the basics of unit testing with a framework like Jest (JavaScript) or pytest (Python). Write 3–5 tests for a function you wrote.", order: 4),
                ],
                skillsDeveloped: ["Git", "Debugging", "APIs", "Unit Testing", "Software Development"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Have at least 5 commits in a Git repository with clear commit messages.",
                    "Successfully retrieve and display data from an external API.",
                    "Write and run at least 3 unit tests that pass.",
                ],
                dependencies: ["software-2"],
                learningResources: [
                    MilestoneResource(id: "sw3-res-1", title: "Git & GitHub Skills", provider: "GitHub", url: "https://skills.github.com/", type: .interactive, description: "Interactive, browser-based Git exercises — practice branching, merging, and pull requests.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "sw3-res-2", title: "Use Git Version Control", provider: "GitHub Docs", url: "https://docs.github.com/en/get-started/using-git/about-git", type: .documentation, description: "Official guide to Git concepts, commands, and workflow basics.", estimatedTime: "20 min"),
                    MilestoneResource(id: "sw3-res-3", title: "HTTP Overview", provider: "MDN Web Docs", url: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Overview", type: .documentation, description: "Clear explanation of how HTTP requests and responses work — essential for calling APIs.", estimatedTime: "25 min"),
                ],
                assessment: MilestoneAssessment(id: "sw3-assessment", questions: [
                    ValidationQuestion(id: "sw3-q1", question: "In Git, what does a 'commit' represent?", choices: [
                        "A request to merge two branches",
                        "A saved snapshot of your code at a specific point in time",
                        "A bug in the program",
                        "A file that stores passwords",
                    ], correctAnswer: 1, explanation: "A commit is a saved snapshot of your project's files at a moment in time, with a message describing what changed."),
                    ValidationQuestion(id: "sw3-q2", question: "What is an API?", choices: [
                        "A type of computer virus",
                        "A set of rules that lets two software programs communicate",
                        "A programming language",
                        "A hardware component",
                    ], correctAnswer: 1, explanation: "An API (Application Programming Interface) defines how different software components request and exchange data."),
                    ValidationQuestion(id: "sw3-q3", question: "What is the main benefit of using a debugger instead of print statements?", choices: [
                        "Debuggers make your code run faster",
                        "Debuggers let you pause execution and inspect variables step by step",
                        "Debuggers automatically fix all bugs",
                        "Debuggers only work in Python",
                    ], correctAnswer: 1, explanation: "A debugger lets you pause your program at any point, look at variable values, and step through code one line at a time."),
                    ValidationQuestion(id: "sw3-q4", question: "What is the purpose of writing tests for your code?", choices: [
                        "To make the code look more professional",
                        "To verify that your code works correctly and catch bugs early",
                        "To slow down the program",
                        "To replace the need for documentation",
                    ], correctAnswer: 1, explanation: "Tests check that your code produces the expected output, helping you find and fix bugs before they reach users."),
                ])
            ),
            .init(
                id: "software-4", title: "Build Real Projects", subtitle: "Create a project that solves a real problem you or someone you know has.", estimatedTime: "4–6 weeks",
                whatItAccomplishes: "Apply everything you have learned to a real project from start to finish — planning, building, testing, and shipping something that works.",
                whyItMatters: "Projects are the strongest evidence of your skills. A single completed project teaches more than ten unfinished tutorials.",
                goal: "Complete and ship one functional project that you can show to others and explain how it works.",
                actions: [
                    MilestoneAction(id: "software-4-action-1", title: "Choose a real problem", description: "Identify a small problem you or someone you know faces — a tool, organizer, calculator, or simple game. Write a one-paragraph problem statement.", order: 1),
                    MilestoneAction(id: "software-4-action-2", title: "Plan the build", description: "Break the project into 4–6 milestones. Define what 'version 1' looks like so you know when to stop adding features.", order: 2),
                    MilestoneAction(id: "software-4-action-3", title: "Build incrementally", description: "Develop the project in stages, committing to Git after each milestone. Test as you go rather than at the end.", order: 3),
                    MilestoneAction(id: "software-4-action-4", title: "Write a README", description: "Create a README.md that explains what the project does, how to run it, and what you learned building it.", order: 4),
                ],
                skillsDeveloped: ["Software Development", "Project Planning", "Technical Communication", "Building Things"],
                completionCriteria: [
                    "Complete all four actions.",
                    "The project runs without critical errors.",
                    "The project has at least 10 Git commits showing incremental progress.",
                    "The README explains the project clearly enough for someone else to understand it.",
                ],
                dependencies: ["software-3"],
                learningResources: [
                    MilestoneResource(id: "sw4-res-1", title: "About READMEs", provider: "GitHub Docs", url: "https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes", type: .documentation, description: "What to include in a README and how to structure it for clarity.", estimatedTime: "10 min"),
                    MilestoneResource(id: "sw4-res-2", title: "GitHub Pages Quickstart", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: .documentation, description: "Set up a free, public website from any repository in minutes.", estimatedTime: "15 min"),
                    MilestoneResource(id: "sw4-res-3", title: "Awesome README", provider: "GitHub", url: "https://github.com/matiassingers/awesome-readme", type: .article, description: "Curated collection of excellent README examples for inspiration.", estimatedTime: "10 min"),
                ],
                assessment: MilestoneAssessment(id: "sw4-assessment", questions: [
                    ValidationQuestion(id: "sw4-q1", question: "When starting a real project, what is the first thing you should do?", choices: [
                        "Immediately start writing code",
                        "Define the problem you are trying to solve",
                        "Choose a programming language you have never used",
                        "Create a social media account for the project",
                    ], correctAnswer: 1, explanation: "Understanding the problem before coding helps you build the right solution and avoid wasted effort."),
                    ValidationQuestion(id: "sw4-q2", question: "Why is it useful to break a project into smaller milestones?", choices: [
                        "It makes the project take longer",
                        "It makes progress visible and helps you stay on track",
                        "It prevents you from using Git",
                        "It is required by programming languages",
                    ], correctAnswer: 1, explanation: "Breaking work into milestones makes large projects manageable, helps you track progress, and lets you test as you go."),
                    ValidationQuestion(id: "sw4-q3", question: "What is the purpose of a project README?", choices: [
                        "To hide your source code from others",
                        "To explain what the project does, how to run it, and what you learned",
                        "To replace the need for comments in code",
                        "To automatically fix bugs",
                    ], correctAnswer: 1, explanation: "A README helps others (and future you) understand what the project is, how to use it, and why it was built."),
                    ValidationQuestion(id: "sw4-q4", question: "What does 'iterating' on a project mean?", choices: [
                        "Deleting the project and starting over",
                        "Making small improvements and testing after each change",
                        "Waiting until the project is perfect before sharing it",
                        "Copying someone else's project exactly",
                    ], correctAnswer: 1, explanation: "Iteration means building in small cycles — make a change, test it, improve, and repeat."),
                ])
            ),
            .init(
                id: "software-5", title: "Gain External Experience", subtitle: "Put your skills to work in a real-world context beyond your own projects.", estimatedTime: "2–4 weeks",
                whatItAccomplishes: "Build credibility and experience by contributing to something outside your personal projects — a competition, open-source project, or hackathon.",
                whyItMatters: "External experience shows that you can work with others, meet deadlines, and produce under real constraints — qualities that matter to colleges and employers.",
                goal: "Participate in at least one external coding event or contribution that is evaluated or used by others.",
                actions: [
                    MilestoneAction(id: "software-5-action-1", title: "Join a hackathon or competition", description: "Register for a student hackathon (MLH, DevPost, local events) or coding competition (USACO, CyberPatriot, school-hosted). Attend and submit a project.", order: 1),
                    MilestoneAction(id: "software-5-action-2", title: "Contribute to open source", description: "Find a beginner-friendly issue on GitHub (look for 'good first issue' labels). Fork the repository, make the change, and submit a pull request.", order: 2),
                    MilestoneAction(id: "software-5-action-3", title: "Explain your work publicly", description: "Write a short blog post, tweet thread, or forum post explaining something you built or learned. Share it with a community.", order: 3),
                ],
                skillsDeveloped: ["Technical Communication", "Collaboration", "Software Development", "Competition Skills"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Submit a project to a hackathon or competition, OR have a pull request opened on GitHub.",
                    "Publish at least one public explanation of your work.",
                ],
                dependencies: ["software-4"],
                learningResources: [
                    MilestoneResource(id: "sw5-res-1", title: "MLH Student Hackathons", provider: "Major League Hacking", url: "https://mlh.io/", type: .interactive, description: "Find and register for student hackathons worldwide — beginner-friendly events welcome.", estimatedTime: "10 min"),
                    MilestoneResource(id: "sw5-res-2", title: "Devpost Hackathon Projects", provider: "Devpost", url: "https://devpost.com/", type: .interactive, description: "Browse past winning projects and find your next hackathon.", estimatedTime: "10 min"),
                    MilestoneResource(id: "sw5-res-3", title: "Finding Good First Issues", provider: "GitHub Docs", url: "https://docs.github.com/en/issues/tracking-your-work-with-issues/using-labels-and-milestones/filtering-your-issues-and-pull-requests-by-label", type: .documentation, description: "How to find beginner-friendly issues in open source repositories.", estimatedTime: "10 min"),
                ],
                assessment: MilestoneAssessment(id: "sw5-assessment", questions: [
                    ValidationQuestion(id: "sw5-q1", question: "What is a pull request?", choices: [
                        "A way to delete a repository",
                        "A proposal to merge your code changes into someone else's project",
                        "A type of bug report",
                        "A command to download files",
                    ], correctAnswer: 1, explanation: "A pull request lets you propose changes to a project and request that the maintainer review and merge them."),
                    ValidationQuestion(id: "sw5-q2", question: "Why is contributing to open source valuable for a student?", choices: [
                        "It guarantees a job offer",
                        "It builds real-world collaboration skills and visible evidence of your abilities",
                        "It is required for college applications",
                        "It automatically improves your grades",
                    ], correctAnswer: 1, explanation: "Open source contributions demonstrate collaboration, code quality, and initiative — skills that colleges and employers value."),
                    ValidationQuestion(id: "sw5-q3", question: "What is a good first step when looking for an open-source issue to work on?", choices: [
                        "Rewrite the entire project from scratch",
                        "Look for issues labeled 'good first issue' that match your skill level",
                        "Email the project owner directly",
                        "Ignore the issue description and submit whatever you want",
                    ], correctAnswer: 1, explanation: "Issues labeled 'good first issue' are curated by maintainers as approachable entry points for new contributors."),
                ])
            ),
            .init(
                id: "software-6", title: "Build a Technical Portfolio", subtitle: "Document your projects, process, and learning in a way others can explore.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Create a polished portfolio that presents your best work, explains your process, and demonstrates growth — ready to share with colleges or employers.",
                whyItMatters: "A portfolio is the single most effective way to show what you can do. It turns scattered projects into a coherent story of your growth.",
                goal: "Have a live, shareable portfolio that showcases at least 2 projects with clear explanations of your process and learning.",
                actions: [
                    MilestoneAction(id: "software-6-action-1", title: "Choose your best 2–3 projects", description: "Pick projects that show different skills or growth over time. For each, write a short case study: problem, approach, outcome, what you learned.", order: 1),
                    MilestoneAction(id: "software-6-action-2", title: "Build a portfolio page", description: "Create a simple portfolio website using GitHub Pages, Vercel, or a similar free platform. Include your projects, a short bio, and links to your GitHub.", order: 2),
                    MilestoneAction(id: "software-6-action-3", title: "Polish your GitHub profile", description: "Add a profile README, pin your best repositories, write clear descriptions, and ensure each project has a good README.", order: 3),
                    MilestoneAction(id: "software-6-action-4", title: "Share and get feedback", description: "Send your portfolio to a teacher, mentor, or peer. Ask one specific question about how it comes across and make one improvement based on feedback.", order: 4),
                ],
                skillsDeveloped: ["Technical Communication", "Portfolio Development", "Personal Branding", "Web Development"],
                completionCriteria: [
                    "Complete all four actions.",
                    "The portfolio website is live and accessible via a URL.",
                    "At least 2 projects are presented with case studies.",
                    "GitHub profile has a README and pinned repositories.",
                ],
                dependencies: ["software-5"],
                learningResources: [
                    MilestoneResource(id: "sw6-res-1", title: "Your First Portfolio Website", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: .documentation, description: "Step-by-step: publish a static portfolio site on GitHub Pages.", estimatedTime: "20 min"),
                    MilestoneResource(id: "sw6-res-2", title: "Managing Your Profile README", provider: "GitHub Docs", url: "https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile/customizing-your-profile/managing-your-profile-readme", type: .documentation, description: "Create a pinned README on your GitHub profile to highlight your best work.", estimatedTime: "15 min"),
                    MilestoneResource(id: "sw6-res-3", title: "How to Build a Developer Portfolio", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/news/how-to-build-a-developer-portfolio-website/", type: .article, description: "Practical guide to structuring and presenting a technical portfolio.", estimatedTime: "10 min"),
                ],
                assessment: MilestoneAssessment(id: "sw6-assessment", questions: [
                    ValidationQuestion(id: "sw6-q1", question: "What makes a project good evidence of your skills for a portfolio?", choices: [
                        "It uses the most popular programming language",
                        "It solves a real problem and shows your thinking process",
                        "It has the most lines of code",
                        "It was assigned by a teacher",
                    ], correctAnswer: 1, explanation: "Strong portfolio projects demonstrate problem-solving, not just technical complexity. Showing your process matters more than size."),
                    ValidationQuestion(id: "sw6-q2", question: "When presenting a project in your portfolio, what should you explain?", choices: [
                        "Only the final result",
                        "The problem, your approach, what you built, and what you learned",
                        "Only the code syntax you used",
                        "Nothing — the code should speak for itself",
                    ], correctAnswer: 1, explanation: "Explaining the problem, approach, and what you learned shows reflection and communication skills alongside technical ability."),
                    ValidationQuestion(id: "sw6-q3", question: "Why is it important to have a README in each of your portfolio projects?", choices: [
                        "It makes the project look bigger",
                        "It helps others quickly understand what the project does and how to use it",
                        "It is required by GitHub",
                        "It automatically improves your SEO",
                    ], correctAnswer: 1, explanation: "A clear README is the first thing viewers read. It should quickly explain the project's purpose, how to run it, and what you learned."),
                ])
            ),
        ], relevantInterests: ["Technology", "AI", "Engineering"], relevantSkills: ["Programming", "Problem solving", "Building things"], relevantCareers: ["Software Engineer", "AI Researcher"], relevantFields: ["Computer Science", "Engineering"], eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth], collegeFocused: true),
        // MARK: - AI Engineer
        Roadmap(id: "ai-engineer", title: "Become an AI Engineer", goal: "Build a foundation in artificial intelligence and machine learning from programming basics to a working AI project.", category: .career, description: "A practical path from programming fundamentals through machine learning concepts to building and evaluating real AI applications.", milestones: [
            .init(
                id: "ai-1", title: "Explore AI & ML", subtitle: "Understand what AI and machine learning are and where they are used.", estimatedTime: "1 hour",
                whatItAccomplishes: "Build a mental model of AI and machine learning, understand common applications, and identify which areas of AI interest you most.",
                whyItMatters: "AI is a broad field. Understanding the landscape before writing code helps you focus your learning on the most relevant areas.",
                goal: "Explain what AI and machine learning are, name 5 real-world applications, and identify 1–2 areas of AI you want to explore further.",
                actions: [
                    MilestoneAction(id: "ai-1-action-1", title: "Watch introductory AI videos", description: "Watch 2–3 short videos explaining what AI and machine learning are. Note examples of AI in everyday life — recommendations, image recognition, language translation.", order: 1),
                    MilestoneAction(id: "ai-1-action-2", title: "Explore AI applications", description: "Visit AI demos from Google, MIT, or other labs. Try an image classifier, a text generator, or a music generator. Write down what surprises you.", order: 2),
                    MilestoneAction(id: "ai-1-action-3", title: "Map the AI landscape", description: "Read about the main branches of AI: machine learning, natural language processing, computer vision, and robotics. Pick 1–2 that interest you most.", order: 3),
                ],
                skillsDeveloped: ["AI Literacy", "Technical Exploration", "Critical Thinking"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Name at least 3 real-world AI applications and explain how they work in simple terms.",
                    "Identify 1–2 areas of AI you want to learn more about.",
                ],
                learningResources: [
                    MilestoneResource(id: "ai1-res-1", title: "Elements of AI", provider: "University of Helsinki", url: "https://www.elementsofai.com/", type: .course, description: "Free, beginner-friendly introduction to AI concepts with no programming required.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "ai1-res-2", title: "AI For Everyone", provider: "Coursera / Andrew Ng", url: "https://www.coursera.org/learn/ai-for-everyone", type: .course, description: "Non-technical overview of AI — what it can and cannot do, and how to think about it.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "ai1-res-3", title: "Google AI Experiments", provider: "Google", url: "https://experiments.withgoogle.com/collection/ai", type: .interactive, description: "Interactive demos of AI in image, sound, and language — try them to see what AI can do.", estimatedTime: "20 min"),
                ],
                assessment: MilestoneAssessment(id: "ai1-assessment", questions: [
                    ValidationQuestion(id: "ai1-q1", question: "What is machine learning?", choices: [
                        "A type of computer hardware",
                        "A subset of AI where computers learn patterns from data",
                        "A programming language for AI",
                        "A website for AI research",
                    ], correctAnswer: 1, explanation: "Machine learning is a branch of AI where systems learn patterns from data rather than following explicitly programmed rules."),
                    ValidationQuestion(id: "ai1-q2", question: "Which of these is an example of machine learning in everyday life?", choices: [
                        "A calculator performing arithmetic",
                        "A streaming service recommending shows based on your viewing history",
                        "A word processor checking spelling",
                        "A clock displaying the time",
                    ], correctAnswer: 1, explanation: "Recommendation systems learn your preferences from data and predict what you might enjoy."),
                    ValidationQuestion(id: "ai1-q3", question: "What is computer vision?", choices: [
                        "A type of display screen",
                        "AI that lets computers interpret and understand images and video",
                        "A camera brand",
                        "Software for editing photos",
                    ], correctAnswer: 1, explanation: "Computer vision gives computers the ability to interpret visual information from the world, like identifying objects in images."),
                ])
            ),
            .init(
                id: "ai-2", title: "Build Programming & Math Foundations", subtitle: "Develop the Python and math skills needed for AI work.", estimatedTime: "3–5 weeks",
                whatItAccomplishes: "Gain working fluency in Python and the core math concepts — linear algebra, probability, and basic statistics — that underpin machine learning.",
                whyItMatters: "AI libraries are written in Python, and ML algorithms rely on math. Strong foundations here make every subsequent step easier.",
                goal: "Write Python programs that use data structures, functions, and libraries, and explain the basic math behind data analysis.",
                actions: [
                    MilestoneAction(id: "ai-2-action-1", title: "Learn Python fundamentals", description: "Complete a Python course covering variables, loops, functions, lists, dictionaries, and file I/O. Practice by solving 10–15 coding problems.", order: 1),
                    MilestoneAction(id: "ai-2-action-2", title: "Study core math for AI", description: "Review linear algebra basics (vectors, matrices), probability, and statistics (mean, median, standard deviation). Focus on understanding, not memorization.", order: 2),
                    MilestoneAction(id: "ai-2-action-3", title: "Learn NumPy and Pandas", description: "Use NumPy for array operations and Pandas for data manipulation. Load a CSV file, filter rows, compute averages, and create simple visualizations.", order: 3),
                    MilestoneAction(id: "ai-2-action-4", title: "Work with a real dataset", description: "Download a public dataset (e.g., from Kaggle or UCI). Clean it, explore it, and answer 3 questions using code.", order: 4),
                ],
                skillsDeveloped: ["Python", "Data Analysis", "Statistics", "Mathematics", "Programming Fundamentals"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Write Python programs using loops, functions, and data structures without referencing a tutorial.",
                    "Load and analyze a real dataset using Pandas.",
                    "Explain what a matrix is and how it relates to data.",
                ],
                dependencies: ["ai-1"],
                learningResources: [
                    MilestoneResource(id: "ai2-res-1", title: "Scientific Computing with Python", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/learn/scientific-computing-with-python/", type: .course, description: "Free Python course covering fundamentals through data structures and object-oriented programming.", estimatedTime: "300 hrs (self-paced)"),
                    MilestoneResource(id: "ai2-res-2", title: "Khan Academy: Statistics & Probability", provider: "Khan Academy", url: "https://www.khanacademy.org/math/statistics-probability", type: .interactive, description: "Free lessons on statistics and probability — essential background for machine learning.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "ai2-res-3", title: "Kaggle Learn: Pandas", provider: "Kaggle", url: "https://www.kaggle.com/learn/pandas", type: .interactive, description: "Short, hands-on course on data manipulation with Pandas.", estimatedTime: "5 hrs"),
                ],
                assessment: MilestoneAssessment(id: "ai2-assessment", questions: [
                    ValidationQuestion(id: "ai2-q1", question: "What does a Pandas DataFrame let you do?", choices: [
                        "Create websites",
                        "Store and manipulate tabular data like a spreadsheet in code",
                        "Run machine learning models",
                        "Generate images",
                    ], correctAnswer: 1, explanation: "A DataFrame is Pandas' core data structure for working with rows and columns of data programmatically."),
                    ValidationQuestion(id: "ai2-q2", question: "Why is linear algebra important for AI?", choices: [
                        "It helps you write faster loops",
                        "Data is represented as vectors and matrices, and ML operations use matrix math",
                        "It is only used in computer graphics",
                        "It is not important for AI",
                    ], correctAnswer: 1, explanation: "Machine learning algorithms represent data as numerical arrays and use matrix operations for computation."),
                    ValidationQuestion(id: "ai2-q3", question: "What is the purpose of exploratory data analysis (EDA)?", choices: [
                        "To delete data you do not need",
                        "To understand the structure, patterns, and quality of a dataset before modeling",
                        "To train a machine learning model",
                        "To publish a research paper",
                    ], correctAnswer: 1, explanation: "EDA helps you understand what your data looks like, find issues, and decide what preprocessing or modeling to do next."),
                ])
            ),
            .init(
                id: "ai-3", title: "Learn ML Fundamentals", subtitle: "Understand how machines learn from data.", estimatedTime: "4–6 weeks",
                whatItAccomplishes: "Learn the core machine learning concepts — supervised and unsupervised learning, model training, evaluation, and common algorithms.",
                whyItMatters: "Understanding how models learn and when they fail is what separates someone who can call a library from someone who can build real solutions.",
                goal: "Explain supervised vs. unsupervised learning, train a simple model, and evaluate its performance using standard metrics.",
                actions: [
                    MilestoneAction(id: "ai-3-action-1", title: "Study supervised learning", description: "Learn about classification and regression. Understand how models are trained on labeled data to make predictions.", order: 1),
                    MilestoneAction(id: "ai-3-action-2", title: "Study unsupervised learning", description: "Learn about clustering and dimensionality reduction. Understand how models find patterns in unlabeled data.", order: 2),
                    MilestoneAction(id: "ai-3-action-3", title: "Train your first model", description: "Use Scikit-learn to train a classifier on a simple dataset (e.g., Iris or Titanic). Split data into train/test sets and evaluate accuracy.", order: 3),
                    MilestoneAction(id: "ai-3-action-4", title: "Learn about overfitting", description: "Understand overfitting vs. underfitting, cross-validation, and regularization. Retrain a model using cross-validation.", order: 4),
                    MilestoneAction(id: "ai-3-action-5", title: "Evaluate model performance", description: "Learn about accuracy, precision, recall, and confusion matrices. Apply these metrics to your trained model.", order: 5),
                ],
                skillsDeveloped: ["Machine Learning", "Data Analysis", "Model Evaluation", "Python", "Statistics"],
                completionCriteria: [
                    "Complete all five actions.",
                    "Train a classifier on a real dataset and achieve at least 80% accuracy.",
                    "Explain the difference between overfitting and underfitting.",
                    "Use a confusion matrix to evaluate your model.",
                ],
                dependencies: ["ai-2"],
                learningResources: [
                    MilestoneResource(id: "ai3-res-1", title: "Google ML Crash Course", provider: "Google", url: "https://developers.google.com/machine-learning/crash-course", type: .course, description: "Free, fast-paced introduction to core ML concepts from Google.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "ai3-res-2", title: "Scikit-learn Tutorials", provider: "Scikit-learn", url: "https://scikit-learn.org/stable/tutorial/", type: .documentation, description: "Official tutorials on training models, evaluating performance, and using common algorithms.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "ai3-res-3", title: "Kaggle Learn: Intro to Machine Learning", provider: "Kaggle", url: "https://www.kaggle.com/learn/intro-to-machine-learning", type: .interactive, description: "Hands-on lessons training real models with Scikit-learn.", estimatedTime: "3 hrs"),
                ],
                assessment: MilestoneAssessment(id: "ai3-assessment", questions: [
                    ValidationQuestion(id: "ai3-q1", question: "What is supervised learning?", choices: [
                        "Learning without any data",
                        "Training a model on labeled data to predict outcomes",
                        "Finding hidden patterns in unlabeled data",
                        "Building websites with AI",
                    ], correctAnswer: 1, explanation: "Supervised learning uses labeled examples — data with known correct answers — to train a model to make predictions."),
                    ValidationQuestion(id: "ai3-q2", question: "What is overfitting?", choices: [
                        "When a model performs well on all data",
                        "When a model learns noise in training data and performs poorly on new data",
                        "When a model is too simple to capture patterns",
                        "When a model trains too slowly",
                    ], correctAnswer: 1, explanation: "Overfitting happens when a model memorizes training data instead of learning general patterns, so it fails on new data."),
                    ValidationQuestion(id: "ai3-q3", question: "What does a confusion matrix show?", choices: [
                        "How fast a model trains",
                        "The types of predictions a model got right and wrong",
                        "The size of the training dataset",
                        "The programming language used",
                    ], correctAnswer: 1, explanation: "A confusion matrix breaks down predictions into true positives, true negatives, false positives, and false negatives."),
                    ValidationQuestion(id: "ai3-q4", question: "Why do we split data into training and test sets?", choices: [
                        "To make training faster",
                        "To evaluate how well the model generalizes to unseen data",
                        "To reduce the amount of data needed",
                        "It is not necessary",
                    ], correctAnswer: 1, explanation: "Testing on unseen data tells you how the model will perform in the real world, not just on data it has already seen."),
                ])
            ),
            .init(
                id: "ai-4", title: "Build AI Applications", subtitle: "Apply ML to real-world problems using modern tools.", estimatedTime: "4–6 weeks",
                whatItAccomplishes: "Build working AI applications using real tools — training models on real data, making predictions, and building a simple interactive app.",
                whyItMatters: "Building real applications teaches you things tutorials cannot — data preprocessing, model tuning, debugging, and integrating ML into a working product.",
                goal: "Build and deploy at least one working AI application that processes data and makes predictions or classifications.",
                actions: [
                    MilestoneAction(id: "ai-4-action-1", title: "Choose a meaningful problem", description: "Pick a problem that matters to you — image classification, text analysis, recommendation, or prediction. Define what success looks like.", order: 1),
                    MilestoneAction(id: "ai-4-action-2", title: "Collect and preprocess data", description: "Find or create a dataset for your problem. Clean it, handle missing values, and prepare it for training.", order: 2),
                    MilestoneAction(id: "ai-4-action-3", title: "Train and tune your model", description: "Try at least 2 different algorithms. Tune hyperparameters and compare results. Document what worked best.", order: 3),
                    MilestoneAction(id: "ai-4-action-4", title: "Build a simple interface", description: "Create a basic web interface or command-line tool that lets someone interact with your model. Use Streamlit, Flask, or a similar framework.", order: 4),
                ],
                skillsDeveloped: ["Machine Learning", "Data Analysis", "APIs", "AI Application Development", "Software Development"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Train a model on real data and document your results.",
                    "Build a working interface that accepts input and returns predictions.",
                    "Compare at least 2 algorithms and explain which performed better and why.",
                ],
                dependencies: ["ai-3"],
                learningResources: [
                    MilestoneResource(id: "ai4-res-1", title: "Kaggle Learn: Intermediate Machine Learning", provider: "Kaggle", url: "https://www.kaggle.com/learn/intermediate-machine-learning", type: .interactive, description: "Handle missing data, encode categories, and improve model performance.", estimatedTime: "4 hrs"),
                    MilestoneResource(id: "ai4-res-2", title: "Streamlit Tutorial", provider: "Streamlit", url: "https://docs.streamlit.io/library/get-started/create-an-app", type: .documentation, description: "Build interactive web apps for data science and ML in minutes with Python.", estimatedTime: "30 min"),
                    MilestoneResource(id: "ai4-res-3", title: "Fast.ai: Practical Deep Learning", provider: "fast.ai", url: "https://course.fast.ai/", type: .course, description: "Free course on practical deep learning with real projects.", estimatedTime: "Self-paced"),
                ],
                assessment: MilestoneAssessment(id: "ai4-assessment", questions: [
                    ValidationQuestion(id: "ai4-q1", question: "What is hyperparameter tuning?", choices: [
                        "Changing the training data",
                        "Adjusting model settings before training to improve performance",
                        "Deleting a trained model",
                        "Writing documentation",
                    ], correctAnswer: 1, explanation: "Hyperparameters are settings you choose before training (like learning rate or tree depth). Tuning them affects model performance."),
                    ValidationQuestion(id: "ai4-q2", question: "Why is data preprocessing important?", choices: [
                        "It makes the dataset smaller",
                        "Clean, well-structured data leads to better model performance",
                        "It is required by Python",
                        "It replaces the need for model training",
                    ], correctAnswer: 1, explanation: "Models are only as good as their data. Cleaning and preparing data helps models learn more effectively."),
                    ValidationQuestion(id: "ai4-q3", question: "What is the purpose of building a model interface?", choices: [
                        "To make the model run faster",
                        "To let non-technical users interact with the model and get predictions",
                        "To reduce the size of the model",
                        "It serves no purpose",
                    ], correctAnswer: 1, explanation: "An interface makes your AI accessible — anyone can use it without writing code or understanding the underlying algorithms."),
                ])
            ),
            .init(
                id: "ai-5", title: "Work With Real Data", subtitle: "Learn to find, clean, analyze, and understand data at scale.", estimatedTime: "3–4 weeks",
                whatItAccomplishes: "Develop the critical skill of working with real-world data — messy, incomplete, and large — which is where most AI work actually happens.",
                whyItMatters: "Data preparation takes 80% of real AI project time. Learning to work with data well is what separates effective AI practitioners from those who get stuck.",
                goal: "Find, clean, analyze, and visualize a real-world dataset, and communicate what you learned from it.",
                actions: [
                    MilestoneAction(id: "ai-5-action-1", title: "Find a dataset that interests you", description: "Browse Kaggle Datasets, UCI Machine Learning Repository, or public government data. Choose one with at least 1,000 rows and a question worth exploring.", order: 1),
                    MilestoneAction(id: "ai-5-action-2", title: "Clean the data", description: "Handle missing values, fix inconsistencies, remove duplicates, and convert data types. Document every cleaning step.", order: 2),
                    MilestoneAction(id: "ai-5-action-3", title: "Analyze and visualize", description: "Compute summary statistics, create 3–5 visualizations (histograms, scatter plots, bar charts), and identify at least 3 insights from the data.", order: 3),
                    MilestoneAction(id: "ai-5-action-4", title: "Write a data report", description: "Write a 1–2 page report explaining your dataset, cleaning steps, key findings, and limitations. Include visualizations.", order: 4),
                ],
                skillsDeveloped: ["Data Analysis", "Data Collection", "Statistics", "Python", "Technical Communication"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Clean a real dataset with at least 1,000 rows.",
                    "Create at least 3 visualizations that reveal patterns.",
                    "Write a report explaining your findings clearly.",
                ],
                dependencies: ["ai-4"],
                learningResources: [
                    MilestoneResource(id: "ai5-res-1", title: "Kaggle Datasets", provider: "Kaggle", url: "https://www.kaggle.com/datasets", type: .interactive, description: "Browse and download thousands of free datasets on every topic imaginable.", estimatedTime: "10 min"),
                    MilestoneResource(id: "ai5-res-2", title: "Python Data Science Handbook", provider: "Jake VanderPlas", url: "https://jakevdp.github.io/PythonDataScienceHandbook/", type: .documentation, description: "Free online book covering NumPy, Pandas, Matplotlib, and Scikit-learn.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "ai5-res-3", title: "Khan Academy: Statistics & Probability", provider: "Khan Academy", url: "https://www.khanacademy.org/math/statistics-probability", type: .interactive, description: "Review statistical concepts essential for data analysis.", estimatedTime: "Self-paced"),
                ],
                assessment: MilestoneAssessment(id: "ai5-assessment", questions: [
                    ValidationQuestion(id: "ai5-q1", question: "Why is data cleaning important before analysis?", choices: [
                        "It is not important",
                        "Messy data leads to misleading or incorrect conclusions",
                        "It makes the dataset smaller",
                        "It is required by Python libraries",
                    ], correctAnswer: 1, explanation: "Dirty data — missing values, duplicates, inconsistencies — corrupts analysis and leads to wrong conclusions."),
                    ValidationQuestion(id: "ai5-q2", question: "What is the purpose of data visualization?", choices: [
                        "To make reports longer",
                        "To reveal patterns, trends, and relationships that numbers alone hide",
                        "To replace statistical analysis",
                        "It serves no purpose",
                    ], correctAnswer: 1, explanation: "Visualizations make patterns visible and help you communicate findings to others who may not read raw numbers."),
                    ValidationQuestion(id: "ai5-q3", question: "What should a good data report include?", choices: [
                        "Only the final results",
                        "The dataset source, cleaning steps, analysis methods, findings, and limitations",
                        "Just a list of charts",
                        "Only the code you wrote",
                    ], correctAnswer: 1, explanation: "A complete data report explains what you did, why, what you found, and what the limitations are — so others can evaluate and reproduce your work."),
                ])
            ),
            .init(
                id: "ai-6", title: "Build an AI Portfolio", subtitle: "Showcase your AI skills with a portfolio of projects.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Create a polished portfolio that demonstrates your AI capabilities — from data preparation to model building to communication of results.",
                whyItMatters: "A portfolio is the strongest evidence of your AI skills. It turns scattered projects into a coherent demonstration of your abilities.",
                goal: "Have a live, shareable portfolio that presents at least 2 AI projects with clear explanations of your approach and results.",
                actions: [
                    MilestoneAction(id: "ai-6-action-1", title: "Select your best 2 projects", description: "Choose projects that show different AI skills — one might focus on data analysis, another on model building. Write a case study for each.", order: 1),
                    MilestoneAction(id: "ai-6-action-2", title: "Build a portfolio page", description: "Create a simple portfolio website using GitHub Pages or Vercel. Include your projects, a short bio about your AI interests, and links to your code.", order: 2),
                    MilestoneAction(id: "ai-6-action-3", title: "Polish your GitHub", description: "Pin your best repositories, write clear READMEs for each project, and ensure your GitHub profile highlights your AI work.", order: 3),
                    MilestoneAction(id: "ai-6-action-4", title: "Share and get feedback", description: "Send your portfolio to a teacher, mentor, or online community. Ask for feedback on clarity and make one improvement.", order: 4),
                ],
                skillsDeveloped: ["Portfolio Development", "Technical Communication", "Personal Branding", "AI Application Development"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Portfolio website is live and accessible.",
                    "At least 2 AI projects are presented with case studies.",
                    "GitHub profile highlights AI work clearly.",
                ],
                dependencies: ["ai-5"],
                learningResources: [
                    MilestoneResource(id: "ai6-res-1", title: "GitHub Pages Quickstart", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: .documentation, description: "Set up a free portfolio site from any repository.", estimatedTime: "15 min"),
                    MilestoneResource(id: "ai6-res-2", title: "Your First Portfolio Website", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/news/how-to-build-a-developer-portfolio-website/", type: .article, description: "Practical guide to building a technical portfolio.", estimatedTime: "10 min"),
                ]
            ),
        ], relevantInterests: ["Technology", "AI", "Science", "Mathematics"], relevantSkills: ["Programming", "Mathematics", "Data Analysis", "Problem solving"], relevantCareers: ["AI Researcher", "Data Scientist", "Software Engineer"], relevantFields: ["Computer Science", "Mathematics", "Engineering"], eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth], collegeFocused: true),
        Roadmap(id: "research-builder", title: "Build a Research Profile", goal: "Move from curiosity to a documented research experience.", category: .academic, description: "Learn how to ask a strong question, investigate it, and communicate what you discover.", milestones: [
            .init(
                id: "research-1", title: "Explore Research", subtitle: "Understand what research is and how it works.", estimatedTime: "45 min",
                whatItAccomplishes: "Build a mental model of what research involves, learn how researchers ask questions, and identify topics that genuinely interest you.",
                whyItMatters: "Understanding the research process before starting helps you choose a meaningful topic and avoid common pitfalls.",
                goal: "Explain what research is, identify 2–3 topics that interest you, and understand the basic steps of a research project.",
                actions: [
                    MilestoneAction(id: "research-1-action-1", title: "Watch researchers describe their work", description: "Find 2–3 videos or talks where researchers explain their projects. Note what their daily work looks like and what questions drive them.", order: 1),
                    MilestoneAction(id: "research-1-action-2", title: "Read a research summary", description: "Find a science news article that summarizes a recent research paper. Identify the question the researchers asked and why it mattered.", order: 2),
                    MilestoneAction(id: "research-1-action-3", title: "List your curiosities", description: "Write down 5 questions you are genuinely curious about — about science, society, technology, or anything else. These become potential research topics.", order: 3),
                ],
                skillsDeveloped: ["Research Methods", "Question Formation", "Critical Thinking"],
                completionCriteria: [
                    "Complete all three actions.",
                    "List at least 5 questions you are curious about.",
                    "Explain in 2–3 sentences what makes research different from just reading about a topic.",
                ],
                learningResources: [
                    MilestoneResource(id: "r1-res-1", title: "Khan Academy: Research Methods", provider: "Khan Academy", url: "https://www.khanacademy.org/science/health-and-medicine/ethics", type: .course, description: "Introduction to scientific thinking and research principles.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "r1-res-2", title: "ScienceBuddies: Science Fair Project Ideas", provider: "ScienceBuddies", url: "https://www.sciencebuddies.org/science-fair-projects/ideas", type: .interactive, description: "Browse hundreds of research project ideas organized by topic and grade level.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "research-2", title: "Choose a Research Question", subtitle: "Narrow your curiosity into a focused, investigable question.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Transform a broad interest into a specific, answerable research question that you can investigate with available resources.",
                whyItMatters: "A well-formed question is the most important part of research. It determines what you will study, how you will study it, and what you can conclude.",
                goal: "Refine one of your curiosities into a clear, focused research question and write a brief proposal explaining why it matters.",
                actions: [
                    MilestoneAction(id: "research-2-action-1", title: "Research your topic", description: "Read 3–5 articles about your topic. Note what has already been studied and what questions remain open.", order: 1),
                    MilestoneAction(id: "research-2-action-2", title: "Narrow your question", description: "Take your broad curiosity and narrow it to something specific and measurable. For example, 'How does music affect study performance?' instead of 'How does music affect people?'", order: 2),
                    MilestoneAction(id: "research-2-action-3", title: "Write a mini-proposal", description: "Write a one-page proposal: your question, why it matters, what you plan to study, and how you will gather evidence.", order: 3),
                    MilestoneAction(id: "research-2-action-4", title: "Get feedback", description: "Share your proposal with a teacher, mentor, or parent. Ask one question: 'Is this researchable with the resources I have?'", order: 4),
                ],
                skillsDeveloped: ["Question Formation", "Source Evaluation", "Research Methods", "Writing"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Read at least 3 sources about your topic.",
                    "Write a one-page proposal with a clear, focused question.",
                    "Receive feedback from at least one person.",
                ],
                dependencies: ["research-1"],
                learningResources: [
                    MilestoneResource(id: "r2-res-1", title: "How to Read a Scientific Paper", provider: "Science", url: "https://www.science.org/content/article/how-read-scientific-paper", type: .article, description: "Guide to reading and understanding scientific papers effectively.", estimatedTime: "15 min"),
                    MilestoneResource(id: "r2-res-2", title: "Khan Academy: Asking Questions", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more/research-process", type: .interactive, description: "Lessons on forming research questions and understanding the scientific process.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "research-3", title: "Learn Research Methods", subtitle: "Understand evidence, sources, and responsible practice.", estimatedTime: "1 week",
                whatItAccomplishes: "Learn how to collect data ethically, evaluate sources critically, and plan a method that will give you meaningful answers.",
                whyItMatters: "Good methods are what make research credible. Without them, your findings cannot be trusted or built upon.",
                goal: "Choose a research method appropriate for your question, evaluate at least 5 sources for credibility, and write a methods plan.",
                actions: [
                    MilestoneAction(id: "research-3-action-1", title: "Choose your method", description: "Decide whether your research needs experiments, surveys, observations, interviews, or secondary source analysis. Justify your choice in writing.", order: 1),
                    MilestoneAction(id: "research-3-action-2", title: "Evaluate your sources", description: "For each source you plan to use, check: Is the author credible? Is the source peer-reviewed or from a reputable institution? Is the data current?", order: 2),
                    MilestoneAction(id: "research-3-action-3", title: "Plan data collection", description: "Write a step-by-step plan for how you will collect data. If doing a survey, write your questions. If doing experiments, define your variables.", order: 3),
                    MilestoneAction(id: "research-3-action-4", title: "Learn about ethics", description: "Read about research ethics — informed consent, privacy, and responsible data handling. Write a brief ethics statement for your project.", order: 4),
                ],
                skillsDeveloped: ["Research Methods", "Source Evaluation", "Data Collection", "Technical Writing"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Choose and justify a research method.",
                    "Evaluate at least 5 sources for credibility.",
                    "Write a methods plan and ethics statement.",
                ],
                dependencies: ["research-2"],
                learningResources: [
                    MilestoneResource(id: "r3-res-1", title: "Khan Academy: Research Methods in Psychology", provider: "Khan Academy", url: "https://www.khanacademy.org/test-prep/mcat/processing-the-environment/research-methods", type: .interactive, description: "Covers experimental design, controls, and ethical considerations.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "r3-res-2", title: "Purdue OWL: Research and Citation", provider: "Purdue University", url: "https://owl.purdue.edu/owl/research_and_citation/resources.html", type: .documentation, description: "Comprehensive guide to research methods, citation, and academic writing.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "research-4", title: "Conduct an Investigation", subtitle: "Collect, analyze, and reflect on a small body of evidence.", estimatedTime: "2–3 weeks",
                whatItAccomplishes: "Execute your research plan, collect real data, and begin analyzing what you find.",
                whyItMatters: "This is where your research becomes real. Collecting and analyzing data teaches you more about your topic than any amount of reading.",
                goal: "Collect data according to your plan, organize it systematically, and begin identifying patterns or findings.",
                actions: [
                    MilestoneAction(id: "research-4-action-1", title: "Collect your data", description: "Follow your methods plan exactly. Record everything — dates, conditions, responses. Keep a research log.", order: 1),
                    MilestoneAction(id: "research-4-action-2", title: "Organize your data", description: "Put your data in a spreadsheet or table. Label columns clearly. Check for errors or missing values.", order: 2),
                    MilestoneAction(id: "research-4-action-3", title: "Begin analysis", description: "Look for patterns in your data. Calculate basic statistics if appropriate. Create at least one visualization.", order: 3),
                    MilestoneAction(id: "research-4-action-4", title: "Reflect on what you found", description: "Write a brief reflection: What surprised you? What questions do your findings raise? What would you do differently?", order: 4),
                ],
                skillsDeveloped: ["Data Collection", "Data Analysis", "Scientific Method", "Technical Writing"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Collect data according to your methods plan.",
                    "Organize data in a structured format.",
                    "Write a reflection on your initial findings.",
                ],
                dependencies: ["research-3"],
                learningResources: [
                    MilestoneResource(id: "r4-res-1", title: "Google Sheets for Data Analysis", provider: "Google", url: "https://support.google.com/docs/answer/6000253", type: .documentation, description: "Free guide to using Google Sheets for organizing and analyzing research data.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "r4-res-2", title: "Khan Academy: Statistics & Probability", provider: "Khan Academy", url: "https://www.khanacademy.org/math/statistics-probability", type: .interactive, description: "Review statistics concepts for analyzing research data.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "research-5", title: "Analyze & Communicate Findings", subtitle: "Turn your data into a clear argument others can understand.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Analyze your results, draw conclusions, and create a presentation or paper that communicates your findings clearly.",
                whyItMatters: "Research is only valuable if others can understand and evaluate it. Clear communication is what turns data into knowledge.",
                goal: "Complete your analysis, draw evidence-based conclusions, and create a clear presentation of your findings.",
                actions: [
                    MilestoneAction(id: "research-5-action-1", title: "Complete your analysis", description: "Finish analyzing your data. Create any remaining visualizations. Write down your key findings.", order: 1),
                    MilestoneAction(id: "research-5-action-2", title: "Draw conclusions", description: "Write 2–3 paragraphs explaining what your data shows and what it means for your research question. Be honest about limitations.", order: 2),
                    MilestoneAction(id: "research-5-action-3", title: "Create a poster or paper", description: "Format your research as a science fair poster, a written report, or a slide presentation. Include: question, methods, results, discussion.", order: 3),
                    MilestoneAction(id: "research-5-action-4", title: "Practice presenting", description: "Rehearse explaining your research in 3–5 minutes. Practice answering questions about your methods and findings.", order: 4),
                ],
                skillsDeveloped: ["Data Analysis", "Scientific Communication", "Technical Writing", "Presentation"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Present your findings in a poster, paper, or slide deck.",
                    "Include question, methods, results, and discussion.",
                    "Practice presenting to at least one person.",
                ],
                dependencies: ["research-4"],
                learningResources: [
                    MilestoneResource(id: "r5-res-1", title: "How to Create a Scientific Poster", provider: "North Carolina State University", url: "https://www.lib.ncsu.edu/services/presenting/posters", type: .documentation, description: "Guide to designing effective scientific research posters.", estimatedTime: "20 min"),
                    MilestoneResource(id: "r5-res-2", title: "MIT OpenCourseWare: Communication Skills", provider: "MIT OCW", url: "https://ocw.mit.edu/", type: .course, description: "Free MIT course materials on technical communication and presentation.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "research-6", title: "Build a Research Portfolio", subtitle: "Document your research experience for future opportunities.", estimatedTime: "1 week",
                whatItAccomplishes: "Create a polished record of your research experience that you can share with colleges, mentors, or future employers.",
                whyItMatters: "A research portfolio turns your project from a school assignment into a demonstrated skill. It shows initiative, curiosity, and analytical ability.",
                goal: "Have a documented research portfolio that presents your project, process, and learning in a professional format.",
                actions: [
                    MilestoneAction(id: "research-6-action-1", title: "Write a research summary", description: "Write a 1–2 page summary of your research project: the question, methods, findings, and what you learned about research.", order: 1),
                    MilestoneAction(id: "research-6-action-2", title: "Create a digital portfolio", description: "Put your research summary, data, visualizations, and poster/presentation in a Google Doc, website, or PDF.", order: 2),
                    MilestoneAction(id: "research-6-action-3", title: "Reflect on growth", description: "Write a brief reflection on how your research skills developed through this project. What would you do differently next time?", order: 3),
                ],
                skillsDeveloped: ["Portfolio Development", "Technical Writing", "Scientific Communication", "Personal Branding"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Have a written research summary.",
                    "Assemble a digital portfolio of your research work.",
                    "Write a reflection on your growth as a researcher.",
                ],
                dependencies: ["research-5"],
                learningResources: [
                    MilestoneResource(id: "r6-res-1", title: "Google Docs", provider: "Google", url: "https://docs.google.com/", type: .interactive, description: "Free tool for creating and sharing research documents.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "r6-res-2", title: "GitHub Pages Quickstart", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: .documentation, description: "Create a free website to host your research portfolio.", estimatedTime: "15 min"),
                ]
            ),
        ], relevantInterests: ["Science", "Medicine", "Environment", "AI"], relevantSkills: ["Research", "Writing", "Communication"], relevantCareers: ["AI Researcher", "Biomedical Engineer"], relevantFields: ["Biology", "Medicine", "Engineering"], eligibleGrades: [.tenth, .eleventh, .twelfth], collegeFocused: true),
        Roadmap(id: "portfolio-projects", title: "Build a Technical Portfolio", goal: "Create a body of work that makes your strengths visible.", category: .projects, description: "A flexible project path for turning skills and interests into evidence you can share.", milestones: [
            .init(
                id: "portfolio-1", title: "Define Your Technical Direction", subtitle: "Choose the skills and areas you want your portfolio to showcase.", estimatedTime: "45 min",
                whatItAccomplishes: "Identify what skills, tools, and interests your portfolio should highlight so your projects tell a coherent story.",
                whyItMatters: "A portfolio without direction is just a collection of projects. Defining your direction helps you choose projects that build on each other.",
                goal: "Identify 2–3 technical areas you want to develop and decide what kind of projects would best demonstrate those skills.",
                actions: [
                    MilestoneAction(id: "portfolio-1-action-1", title: "Audit your current skills", description: "List everything you know how to do technically — programming languages, tools, design skills. Rate your confidence honestly.", order: 1),
                    MilestoneAction(id: "portfolio-1-action-2", title: "Research portfolio examples", description: "Look at 3–5 portfolios from people in fields you are interested in. Note what projects they show and how they present them.", order: 2),
                    MilestoneAction(id: "portfolio-1-action-3", title: "Define your direction", description: "Write a paragraph describing what you want your portfolio to demonstrate. This becomes your guide for choosing projects.", order: 3),
                ],
                skillsDeveloped: ["Project Planning", "Technical Exploration", "Personal Branding"],
                completionCriteria: [
                    "Complete all three actions.",
                    "List your current technical skills.",
                    "Review at least 3 example portfolios.",
                    "Write a paragraph defining your portfolio direction.",
                ],
                learningResources: [
                    MilestoneResource(id: "p1-res-1", title: "How to Build a Developer Portfolio", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/news/how-to-build-a-developer-portfolio-website/", type: .article, description: "Practical guide to building a technical portfolio.", estimatedTime: "10 min"),
                    MilestoneResource(id: "p1-res-2", title: "GitHub Profile README", provider: "GitHub Docs", url: "https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile/customizing-your-profile/managing-your-profile-readme", type: .documentation, description: "Create a pinned README on your GitHub profile.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "portfolio-2", title: "Build Strong Projects", subtitle: "Create projects that demonstrate real skills.", estimatedTime: "4–8 weeks",
                whatItAccomplishes: "Build 2–3 meaningful projects that showcase different aspects of your technical abilities.",
                whyItMatters: "Projects are the core of any portfolio. Each project should demonstrate a different skill or growth area.",
                goal: "Complete 2–3 projects that each demonstrate a different technical skill or area of knowledge.",
                actions: [
                    MilestoneAction(id: "portfolio-2-action-1", title: "Plan your first project", description: "Choose a problem to solve. Write a brief plan: what it will do, what technologies it will use, and what you will learn.", order: 1),
                    MilestoneAction(id: "portfolio-2-action-2", title: "Build and iterate", description: "Develop the project in stages. Test as you go. Commit to Git regularly. Aim for a working version before polishing.", order: 2),
                    MilestoneAction(id: "portfolio-2-action-3", title: "Plan and build a second project", description: "Choose a different type of project that uses different skills. Build it with the same structured approach.", order: 3),
                    MilestoneAction(id: "portfolio-2-action-4", title: "Get feedback early", description: "Show an early version of each project to a peer or mentor. Make one improvement based on their feedback.", order: 4),
                ],
                skillsDeveloped: ["Software Development", "Project Planning", "Building Things", "Version Control"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Build at least 2 projects from start to finish.",
                    "Each project uses different skills or technologies.",
                    "Get feedback on at least one project.",
                ],
                dependencies: ["portfolio-1"],
                learningResources: [
                    MilestoneResource(id: "p2-res-1", title: "freeCodeCamp Projects", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/learn", type: .course, description: "Build real projects as part of freeCodeCamp's certifications.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "p2-res-2", title: "CS50 Projects", provider: "Harvard", url: "https://cs50.harvard.edu/x/", type: .course, description: "Build projects as part of Harvard's CS50 course.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "portfolio-3", title: "Improve Project Quality", subtitle: "Polish your projects to professional standards.", estimatedTime: "2–3 weeks",
                whatItAccomplishes: "Refine your projects — fix bugs, improve design, add features, and ensure they work reliably.",
                whyItMatters: "The difference between a good project and a great one is polish. Quality work shows attention to detail and pride in your craft.",
                goal: "Improve at least 2 projects based on feedback and testing so they work reliably and look professional.",
                actions: [
                    MilestoneAction(id: "portfolio-3-action-1", title: "Test your projects thoroughly", description: "Use each project from a user's perspective. Find and fix bugs. Write down edge cases and test them.", order: 1),
                    MilestoneAction(id: "portfolio-3-action-2", title: "Improve the user experience", description: "Make your projects easier to use. Clean up the interface, add helpful messages, and fix anything confusing.", order: 2),
                    MilestoneAction(id: "portfolio-3-action-3", title: "Refactor your code", description: "Clean up your code — remove unused code, improve naming, add comments where needed. Make it readable.", order: 3),
                    MilestoneAction(id: "portfolio-3-action-4", title: "Add finishing touches", description: "Add error handling, loading states, or responsive design where appropriate. Make each project feel complete.", order: 4),
                ],
                skillsDeveloped: ["Software Development", "Quality Assurance", "Building Things", "Version Control"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Each project runs without critical bugs.",
                    "Code is clean and well-organized.",
                    "Projects feel polished and professional.",
                ],
                dependencies: ["portfolio-2"],
                learningResources: [
                    MilestoneResource(id: "p3-res-1", title: "MDN: Web Design and Accessibility", provider: "MDN", url: "https://developer.mozilla.org/en-US/docs/Learn/CSS/Building_blocks/Handling_content", type: .documentation, description: "Guides on creating clean, accessible user interfaces.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "p3-res-2", title: "Google: Web Fundamentals", provider: "Google", url: "https://developers.google.com/web/fundamentals", type: .documentation, description: "Best practices for building modern, fast, and accessible web applications.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "portfolio-4", title: "Document Your Work", subtitle: "Write clear explanations of what you built and why.", estimatedTime: "1 week",
                whatItAccomplishes: "Create thorough documentation for each project so others can understand your process and decisions.",
                whyItMatters: "Documentation shows you can communicate technical work clearly. It is often the first thing a viewer reads.",
                goal: "Write complete documentation for each project including a README with problem, approach, and results.",
                actions: [
                    MilestoneAction(id: "portfolio-4-action-1", title: "Write project READMEs", description: "For each project, write a README explaining: what it does, how to run it, what technologies it uses, and what you learned.", order: 1),
                    MilestoneAction(id: "portfolio-4-action-2", title: "Add code comments", description: "Add comments to explain non-obvious parts of your code. Focus on why you made decisions, not what the code does.", order: 2),
                    MilestoneAction(id: "portfolio-4-action-3", title: "Create screenshots or demos", description: "Take screenshots or create a short screen recording showing your project in action.", order: 3),
                ],
                skillsDeveloped: ["Documentation", "Technical Communication", "Writing"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Each project has a complete README.",
                    "Code has helpful comments explaining key decisions.",
                    "Each project includes screenshots or a demo.",
                ],
                dependencies: ["portfolio-3"],
                learningResources: [
                    MilestoneResource(id: "p4-res-1", title: "About READMEs", provider: "GitHub Docs", url: "https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes", type: .documentation, description: "What to include in a README and how to structure it.", estimatedTime: "10 min"),
                    MilestoneResource(id: "p4-res-2", title: "Awesome README", provider: "GitHub", url: "https://github.com/matiassingers/awesome-readme", type: .article, description: "Collection of excellent README examples for inspiration.", estimatedTime: "10 min"),
                ]
            ),
            .init(
                id: "portfolio-5", title: "Publish Your Portfolio", subtitle: "Put your work where others can see it.", estimatedTime: "1 week",
                whatItAccomplishes: "Create a live, shareable portfolio that presents your projects professionally.",
                whyItMatters: "A portfolio that no one can see does not help you. Publishing makes your work visible and shareable.",
                goal: "Have a live portfolio website accessible via a URL that presents your projects and skills.",
                actions: [
                    MilestoneAction(id: "portfolio-5-action-1", title: "Choose a publishing platform", description: "Pick a free platform: GitHub Pages, Vercel, Netlify, or a simple HTML site. Set it up with a clean template.", order: 1),
                    MilestoneAction(id: "portfolio-5-action-2", title: "Build your portfolio page", description: "Create pages for: a brief bio, your projects (with links and descriptions), and how to contact you.", order: 2),
                    MilestoneAction(id: "portfolio-5-action-3", title: "Link your projects", description: "For each project, include: a screenshot, a brief description, the technologies used, and a link to the live project or code.", order: 3),
                    MilestoneAction(id: "portfolio-5-action-4", title: "Test and launch", description: "Check every link, test on mobile and desktop, and ask a friend to look through it. Fix any issues.", order: 4),
                ],
                skillsDeveloped: ["Portfolio Development", "Web Development", "Personal Branding", "Technical Communication"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Portfolio website is live and accessible via a URL.",
                    "All project links work.",
                    "Portfolio looks good on mobile and desktop.",
                ],
                dependencies: ["portfolio-4"],
                learningResources: [
                    MilestoneResource(id: "p5-res-1", title: "GitHub Pages Quickstart", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: .documentation, description: "Publish a static site from any GitHub repository.", estimatedTime: "15 min"),
                    MilestoneResource(id: "p5-res-2", title: "Vercel Getting Started", provider: "Vercel", url: "https://vercel.com/docs/getting-started", type: .documentation, description: "Deploy web projects instantly with Vercel.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "portfolio-6", title: "Build a Public Technical Presence", subtitle: "Share your work and connect with a technical community.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Start building your public identity as a technical person by sharing your work and engaging with others.",
                whyItMatters: "A portfolio plus a public presence is more powerful than either alone. It shows initiative and community engagement.",
                goal: "Publish at least one public post about your work and engage with a technical community.",
                actions: [
                    MilestoneAction(id: "portfolio-6-action-1", title: "Write about a project", description: "Write a short blog post, Medium article, or social media thread about one of your projects. Focus on the problem, your approach, and what you learned.", order: 1),
                    MilestoneAction(id: "portfolio-6-action-2", title: "Join a community", description: "Join a Discord server, Reddit community, or online forum related to your technical interests. Introduce yourself and share your work.", order: 2),
                    MilestoneAction(id: "portfolio-6-action-3", title: "Contribute or help", description: "Answer a question, review someone's code, or share a resource. Building presence means contributing, not just posting.", order: 3),
                ],
                skillsDeveloped: ["Personal Branding", "Technical Communication", "Collaboration"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Publish at least one post about your work.",
                    "Join a technical community.",
                    "Contribute to a community discussion.",
                ],
                dependencies: ["portfolio-5"],
                learningResources: [
                    MilestoneResource(id: "p6-res-1", title: "Dev.to", provider: "DEV Community", url: "https://dev.to/", type: .interactive, description: "Free platform for writing and sharing technical articles.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "p6-res-2", title: "GitHub Community", provider: "GitHub", url: "https://github.com/community", type: .interactive, description: "Join GitHub discussions and connect with developers worldwide.", estimatedTime: "10 min"),
                ]
            ),
        ], relevantInterests: ["Technology", "Design", "Entrepreneurship", "Arts"], relevantSkills: ["Building things", "Creativity", "Problem solving", "Programming"], relevantCareers: ["Software Engineer", "Product Designer"], relevantFields: ["Computer Science", "Arts", "Business"], eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth], collegeFocused: false),
        Roadmap(id: "college-ready", title: "Prepare for College", goal: "Build an intentional academic and opportunity plan.", category: .collegePreparation, description: "Organize your direction, experiences, and next decisions without locking into one answer too early.", milestones: [
            .init(
                id: "college-1", title: "Understand Your Goals", subtitle: "Clarify what you want from college and why.", estimatedTime: "45 min",
                whatItAccomplishes: "Reflect on your interests, strengths, and goals to understand what you want college to help you achieve.",
                whyItMatters: "College preparation without clear goals leads to wasted time and missed opportunities. Knowing your direction makes every other decision easier.",
                goal: "Identify your top 3 interests, understand what you want from college, and write a personal goal statement.",
                actions: [
                    MilestoneAction(id: "college-1-action-1", title: "Reflect on your interests", description: "Write down 5 things you are genuinely interested in — subjects, activities, problems you want to solve. Circle your top 3.", order: 1),
                    MilestoneAction(id: "college-1-action-2", title: "Think about your strengths", description: "List 5 things you are good at — school subjects, skills, activities. Note which ones you enjoy using.", order: 2),
                    MilestoneAction(id: "college-1-action-3", title: "Write a goal statement", description: "Write 2–3 sentences about what you want college to help you achieve. This does not have to be final — it is a starting point.", order: 3),
                    MilestoneAction(id: "college-1-action-4", title: "Research college types", description: "Learn about the differences between community colleges, 4-year universities, liberal arts colleges, and technical schools.", order: 4),
                ],
                skillsDeveloped: ["Goal Setting", "Self-Advocacy", "Research"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Identify your top 3 interests and strengths.",
                    "Write a personal goal statement.",
                    "Understand the different types of colleges.",
                ],
                learningResources: [
                    MilestoneResource(id: "c1-res-1", title: "College Scorecard", provider: "U.S. Department of Education", url: "https://collegescorecard.ed.gov/", type: .interactive, description: "Free tool to compare colleges by cost, graduation rates, and outcomes.", estimatedTime: "20 min"),
                    MilestoneResource(id: "c1-res-2", title: "Khan Academy: College Admissions", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more/college-admissions", type: .interactive, description: "Free lessons on the college search and application process.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "college-2", title: "Strengthen Academic Foundations", subtitle: "Make sure your academic record reflects your potential.", estimatedTime: "Ongoing",
                whatItAccomplishes: "Understand what colleges look for academically and take concrete steps to strengthen your record.",
                whyItMatters: "Your academic record is one of the most important parts of a college application. Strong foundations now create opportunities later.",
                goal: "Identify your academic strengths and weaknesses, create a plan to improve, and take action on your plan.",
                actions: [
                    MilestoneAction(id: "college-2-action-1", title: "Review your transcript", description: "Look at your grades and courses. Identify your strongest and weakest areas. Talk to a counselor about what colleges want to see.", order: 1),
                    MilestoneAction(id: "college-2-action-2", title: "Plan challenging courses", description: "Choose the most rigorous courses you can handle — AP, IB, honors, or dual enrollment. Challenge shows colleges you are serious.", order: 2),
                    MilestoneAction(id: "college-2-action-3", title: "Build study habits", description: "Develop a consistent study routine. Use a planner, set regular study times, and seek help early when you struggle.", order: 3),
                    MilestoneAction(id: "college-2-action-4", title: "Seek help when needed", description: "Visit teachers during office hours, join study groups, or find a tutor for any subject where you need support.", order: 4),
                ],
                skillsDeveloped: ["Academic Planning", "Time Management", "Self-Advocacy", "Goal Setting"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Review your transcript and identify areas for improvement.",
                    "Plan your course schedule for the next year.",
                    "Establish a consistent study routine.",
                ],
                dependencies: ["college-1"],
                learningResources: [
                    MilestoneResource(id: "c2-res-1", title: "Khan Academy: Study Skills", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more", type: .interactive, description: "Free lessons on study skills, time management, and academic planning.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "c2-res-2", title: "College Board: Course Planning", provider: "College Board", url: "https://bigfuture.collegeboard.org/plan-for-college/planning-for-college", type: .documentation, description: "Guidance on choosing the right courses for college preparation.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "college-3", title: "Explore Colleges & Programs", subtitle: "Research colleges that fit your goals and interests.", estimatedTime: "2–3 weeks",
                whatItAccomplishes: "Research colleges, compare programs, and build a list of schools that match your academic goals and personal preferences.",
                whyItMatters: "Finding the right fit matters more than prestige. Understanding what different colleges offer helps you make an informed choice.",
                goal: "Research at least 5 colleges, compare their programs and costs, and identify 2–3 that fit your goals well.",
                actions: [
                    MilestoneAction(id: "college-3-action-1", title: "Use college search tools", description: "Use College Scorecard, Naviance, or other tools to search for colleges. Filter by your interests, location, and financial needs.", order: 1),
                    MilestoneAction(id: "college-3-action-2", title: "Research specific programs", description: "For colleges that interest you, look at specific departments, majors, and programs. Read course descriptions and faculty profiles.", order: 2),
                    MilestoneAction(id: "college-3-action-3", title: "Compare costs and financial aid", description: "Use net price calculators to estimate costs. Research scholarships, grants, and financial aid options at each school.", order: 3),
                    MilestoneAction(id: "college-3-action-4", title: "Visit or tour virtually", description: "If possible, visit campuses. If not, take virtual tours. Note what feels right about each place.", order: 4),
                    MilestoneAction(id: "college-3-action-5", title: "Create a preliminary list", description: "Write down 5–8 colleges with brief notes about why each one interests you.", order: 5),
                ],
                skillsDeveloped: ["Research", "Organization", "Decision Making", "Writing"],
                completionCriteria: [
                    "Complete all five actions.",
                    "Research at least 5 colleges in detail.",
                    "Compare costs and financial aid options.",
                    "Create a preliminary college list.",
                ],
                dependencies: ["college-2"],
                learningResources: [
                    MilestoneResource(id: "c3-res-1", title: "College Scorecard", provider: "U.S. Department of Education", url: "https://collegescorecard.ed.gov/", type: .interactive, description: "Compare colleges by cost, graduation rates, and student outcomes.", estimatedTime: "20 min"),
                    MilestoneResource(id: "c3-res-2", title: "BigFuture: College Search", provider: "College Board", url: "https://bigfuture.collegeboard.org/college-search", type: .interactive, description: "Search and compare colleges by size, location, majors, and more.", estimatedTime: "20 min"),
                ]
            ),
            .init(
                id: "college-4", title: "Build Experiences", subtitle: "Create a record of activities that show your interests and character.", estimatedTime: "Ongoing",
                whatItAccomplishes: "Build meaningful extracurricular experiences that demonstrate your interests, leadership, and commitment.",
                whyItMatters: "Colleges want students who contribute to their communities. Meaningful activities show passion and initiative beyond the classroom.",
                goal: "Participate in 2–3 meaningful activities that demonstrate your interests and develop real skills.",
                actions: [
                    MilestoneAction(id: "college-4-action-1", title: "Choose activities that matter to you", description: "Pick 2–3 activities aligned with your interests — clubs, sports, work, volunteering, or personal projects. Commitment matters more than variety.", order: 1),
                    MilestoneAction(id: "college-4-action-2", title: "Take on responsibility", description: "Look for ways to lead, organize, or contribute meaningfully — not just attend. Start something, lead a project, or take on a role.", order: 2),
                    MilestoneAction(id: "college-4-action-3", title: "Document what you do", description: "Keep a simple record of your activities, dates, and what you learned. This will be invaluable when filling out applications.", order: 3),
                    MilestoneAction(id: "college-4-action-4", title: "Seek meaningful summer experiences", description: "Look for summer programs, internships, camps, or jobs related to your interests. Apply to 2–3 programs.", order: 4),
                ],
                skillsDeveloped: ["Leadership", "Time Management", "Communication", "Planning"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Participate meaningfully in at least 2 activities.",
                    "Take on a leadership or organizational role in at least one.",
                    "Document your activities and what you learned.",
                ],
                dependencies: ["college-3"],
                learningResources: [
                    MilestoneResource(id: "c4-res-1", title: "College Board: Activities", provider: "College Board", url: "https://bigfuture.collegeboard.org/plan-for-college/activities", type: .documentation, description: "Guidance on choosing and documenting meaningful extracurricular activities.", estimatedTime: "10 min"),
                    MilestoneResource(id: "c4-res-2", title: "CoolWorks: Summer Jobs", provider: "CoolWorks", url: "https://www.coolworks.com/", type: .interactive, description: "Find meaningful summer jobs and internships in interesting locations.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "college-5", title: "Prepare Your Application Profile", subtitle: "Organize everything colleges will want to see.", estimatedTime: "2–3 weeks",
                whatItAccomplishes: "Create a complete profile of your achievements, activities, and goals that you can use when filling out applications.",
                whyItMatters: "Applications require specific information. Having everything organized in advance makes the process less stressful and more accurate.",
                goal: "Create a complete application profile with your activities, achievements, and personal statement draft.",
                actions: [
                    MilestoneAction(id: "college-5-action-1", title: "Organize your activities list", description: "Create a document listing all your activities with: name, dates, your role, hours per week, and what you learned.", order: 1),
                    MilestoneAction(id: "college-5-action-2", title: "Write a personal statement draft", description: "Write a first draft of a personal statement or college essay. Focus on a specific experience that shaped you.", order: 2),
                    MilestoneAction(id: "college-5-action-3", title: "Prepare for recommendations", description: "Identify 2–3 teachers or mentors who know you well. Ask them politely if they would write a recommendation.", order: 3),
                    MilestoneAction(id: "college-5-action-4", title: "Build a resume", description: "Create a simple, clean resume that includes your education, activities, skills, and achievements.", order: 4),
                ],
                skillsDeveloped: ["Writing", "Organization", "Communication", "Self-Advocacy"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Have a complete activities list.",
                    "Write a first draft personal statement.",
                    "Identify and ask recommenders.",
                ],
                dependencies: ["college-4"],
                learningResources: [
                    MilestoneResource(id: "c5-res-1", title: "Khan Academy: College Essays", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more/college-admissions/applying-to-college", type: .interactive, description: "Free guidance on writing effective college application essays.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "c5-res-2", title: "Purdue OWL: Writing Lab", provider: "Purdue University", url: "https://owl.purdue.edu/owl/general_writing/academic_writing/essay_writing.html", type: .documentation, description: "Free guide to writing clear, effective essays.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "college-6", title: "Plan Your Application Process", subtitle: "Create a timeline and stay on track.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Build a complete application timeline with all deadlines, requirements, and steps organized.",
                whyItMatters: "Missing a deadline can cost you an opportunity. A clear plan keeps you on track and reduces stress.",
                goal: "Create a complete application timeline with all deadlines and requirements for every college on your list.",
                actions: [
                    MilestoneAction(id: "college-6-action-1", title: "List all deadlines", description: "For each college on your list, write down: application deadline, financial aid deadline, test score deadlines, and recommendation deadlines.", order: 1),
                    MilestoneAction(id: "college-6-action-2", title: "Create a master timeline", description: "Put all deadlines on one calendar or timeline. Work backwards from each deadline to determine when you need to start each task.", order: 2),
                    MilestoneAction(id: "college-6-action-3", title: "Plan your testing", description: "Check which colleges require SAT, ACT, or other tests. Register for tests with enough time to retake if needed.", order: 3),
                    MilestoneAction(id: "college-6-action-4", title: "Set check-in points", description: "Schedule regular check-ins with yourself or a counselor to review progress and stay on track.", order: 4),
                ],
                skillsDeveloped: ["Time Management", "Organization", "Planning", "Goal Setting"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Have a complete timeline with all deadlines.",
                    "Register for required tests.",
                    "Schedule regular check-in points.",
                ],
                dependencies: ["college-5"],
                learningResources: [
                    MilestoneResource(id: "c6-res-1", title: "College Board: Application Timeline", provider: "College Board", url: "https://bigfuture.collegeboard.org/plan-for-college/application-timeline", type: .documentation, description: "Month-by-month timeline for college applications.", estimatedTime: "15 min"),
                    MilestoneResource(id: "c6-res-2", title: "Common App", provider: "Common Application", url: "https://www.commonapp.org/", type: .interactive, description: "Free platform to apply to multiple colleges with one application.", estimatedTime: "15 min"),
                ]
            ),
        ], relevantInterests: ["Technology", "Engineering", "Medicine", "Business", "Arts"], relevantSkills: ["Research", "Communication", "Writing", "Leadership"], relevantCareers: [], relevantFields: ["Computer Science", "Engineering", "Medicine", "Business", "Arts", "Law"], eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth], collegeFocused: true),
        // MARK: - STEM Explorer
        Roadmap(id: "stem-explorer", title: "Explore STEM & Engineering", goal: "Discover which areas of STEM interest you most and build foundations for further exploration.", category: .academic, description: "A broad exploration path across science, technology, engineering, and mathematics to help you find your direction.", milestones: [
            .init(
                id: "stem-1", title: "Discover STEM Fields", subtitle: "Learn what science, technology, engineering, and math actually involve.", estimatedTime: "1 hour",
                whatItAccomplishes: "Understand the major STEM fields, see how they connect, and identify which areas feel most exciting to you.",
                whyItMatters: "STEM is enormous. Understanding the landscape helps you focus your time on the areas that genuinely interest you.",
                goal: "Name at least 6 STEM subfields, explain how they connect, and identify 2–3 that interest you most.",
                actions: [
                    MilestoneAction(id: "stem-1-action-1", title: "Watch STEM career overviews", description: "Watch 2–3 videos about different STEM careers — engineering, biology, computer science, environmental science. Note what sounds exciting.", order: 1),
                    MilestoneAction(id: "stem-1-action-2", title: "Map the STEM fields", description: "Create a simple diagram showing how the major STEM fields (science, technology, engineering, math) relate to each other and to subfields.", order: 2),
                    MilestoneAction(id: "stem-1-action-3", title: "Talk to someone in STEM", description: "If possible, ask a teacher, parent, or professional about their STEM work. What do they do daily? What do they enjoy?", order: 3),
                ],
                skillsDeveloped: ["Technical Exploration", "Critical Thinking", "Communication"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Name at least 6 STEM subfields.",
                    "Create a diagram or list connecting STEM fields.",
                    "Identify 2–3 areas that interest you most.",
                ],
                learningResources: [
                    MilestoneResource(id: "st1-res-1", title: "Khan Academy: Science", provider: "Khan Academy", url: "https://www.khanacademy.org/science", type: .interactive, description: "Free lessons across biology, chemistry, physics, and earth science.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "st1-res-2", title: "NASA STEM Engagement", provider: "NASA", url: "https://www.nasa.gov/stem", type: .interactive, description: "Free STEM resources, activities, and career information from NASA.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "stem-2", title: "Identify Areas of Interest", subtitle: "Narrow your exploration to 2–3 specific STEM areas.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Dig deeper into your top STEM interests to understand what they actually involve day-to-day.",
                whyItMatters: "General interest becomes real motivation when you understand what the work actually looks like.",
                goal: "Research 2–3 STEM areas in depth and decide which one you want to explore further.",
                actions: [
                    MilestoneAction(id: "stem-2-action-1", title: "Deep-dive into your top areas", description: "For each of your 2–3 interests, read 3 articles or watch 2 videos about what people in that field actually do.", order: 1),
                    MilestoneAction(id: "stem-2-action-2", title: "Try a beginner project", description: "Do a small beginner activity in each area — a simple coding exercise, a science experiment, or a building challenge.", order: 2),
                    MilestoneAction(id: "stem-2-action-3", title: "Rank your interests", description: "After trying each area, rank them. Write a sentence about why your top choice excites you.", order: 3),
                ],
                skillsDeveloped: ["Technical Exploration", "Critical Thinking", "Decision Making"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Research 2–3 STEM areas in depth.",
                    "Try at least one beginner activity in each area.",
                    "Rank your interests with written reasons.",
                ],
                dependencies: ["stem-1"],
                learningResources: [
                    MilestoneResource(id: "st2-res-1", title: "ScienceBuddies", provider: "ScienceBuddies", url: "https://www.sciencebuddies.org/", type: .interactive, description: "Free STEM project ideas and career information across all science and engineering fields.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "st2-res-2", title: "Codecademy: Learn to Code", provider: "Codecademy", url: "https://www.codecademy.com/", type: .interactive, description: "Free coding lessons to try programming as part of your STEM exploration.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "stem-3", title: "Build Technical Foundations", subtitle: "Develop the math and programming skills needed for STEM work.", estimatedTime: "3–5 weeks",
                whatItAccomplishes: "Build foundational skills in math and programming that apply across all STEM fields.",
                whyItMatters: "Math and programming are the language of STEM. Strong foundations here open doors in every STEM field.",
                goal: "Solve math problems using algebra and basic statistics, write simple programs, and explain how math and coding apply to your STEM interest.",
                actions: [
                    MilestoneAction(id: "stem-3-action-1", title: "Review key math concepts", description: "Study algebra, basic statistics, and data interpretation. Practice with problems relevant to your STEM interest.", order: 1),
                    MilestoneAction(id: "stem-3-action-2", title: "Learn to code", description: "Learn basic Python or JavaScript. Write programs that process data, solve problems, or automate tasks.", order: 2),
                    MilestoneAction(id: "stem-3-action-3", title: "Apply math and code to your interest", description: "Use your math and coding skills to solve a small problem related to your STEM interest. Document what you did.", order: 3),
                    MilestoneAction(id: "stem-3-action-4", title: "Use online practice tools", description: "Complete practice exercises on Khan Academy (math) and a coding platform. Aim for 10–15 problems in each.", order: 4),
                ],
                skillsDeveloped: ["Mathematics", "Programming Fundamentals", "Data Analysis", "Problem Solving"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Solve math problems using algebra and statistics.",
                    "Write programs that process data or solve problems.",
                    "Apply both skills to a problem in your STEM interest.",
                ],
                dependencies: ["stem-2"],
                learningResources: [
                    MilestoneResource(id: "st3-res-1", title: "Khan Academy: Algebra", provider: "Khan Academy", url: "https://www.khanacademy.org/math/algebra", type: .interactive, description: "Free lessons and practice on algebra fundamentals.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "st3-res-2", title: "Python.org Tutorial", provider: "Python.org", url: "https://docs.python.org/3/tutorial/", type: .documentation, description: "Official Python tutorial covering fundamentals.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "st3-res-3", title: "freeCodeCamp", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/", type: .course, description: "Free, project-based coding curriculum.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "stem-4", title: "Complete Hands-On Projects", subtitle: "Build real things that demonstrate STEM skills.", estimatedTime: "4–6 weeks",
                whatItAccomplishes: "Apply your foundations to 2–3 hands-on projects that demonstrate real STEM skills.",
                whyItMatters: "Projects are where learning becomes real. Building something tangible shows you understand concepts, not just facts.",
                goal: "Complete 2–3 hands-on projects that apply STEM skills to solve real problems.",
                actions: [
                    MilestoneAction(id: "stem-4-action-1", title: "Choose projects that interest you", description: "Pick 2–3 projects that combine your STEM interests. They could be experiments, builds, apps, or designs.", order: 1),
                    MilestoneAction(id: "stem-4-action-2", title: "Plan and build", description: "For each project, define what success looks like, plan your approach, and build it step by step.", order: 2),
                    MilestoneAction(id: "stem-4-action-3", title: "Document your process", description: "For each project, write a brief summary: what you built, how it works, and what you learned.", order: 3),
                    MilestoneAction(id: "stem-4-action-4", title: "Get feedback", description: "Show your projects to a teacher, mentor, or peer. Ask for one suggestion to improve each project.", order: 4),
                ],
                skillsDeveloped: ["Building Things", "Project Planning", "Problem Solving", "Technical Communication"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Build at least 2 STEM projects.",
                    "Document each project with a summary.",
                    "Receive and apply feedback on at least one project.",
                ],
                dependencies: ["stem-3"],
                learningResources: [
                    MilestoneResource(id: "st4-res-1", title: "Arduino Project Hub", provider: "Arduino", url: "https://projecthub.arduino.cc/", type: .interactive, description: "Browse hundreds of electronics and engineering projects.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "st4-res-2", title: "ScienceBuddies Project Ideas", provider: "ScienceBuddies", url: "https://www.sciencebuddies.org/science-fair-projects/ideas", type: .interactive, description: "Find science and engineering project ideas by topic.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "stem-5", title: "Explore Real-World Applications", subtitle: "See how STEM is used in real careers and industries.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Connect your STEM skills to real-world applications and understand how professionals use these skills.",
                whyItMatters: "Understanding real-world applications helps you see where your STEM skills can take you and motivates continued learning.",
                goal: "Research 2–3 real-world STEM applications and explain how the skills you developed apply to them.",
                actions: [
                    MilestoneAction(id: "stem-5-action-1", title: "Research STEM careers", description: "For your top 2–3 STEM interests, research what professionals actually do. What skills do they use daily? What problems do they solve?", order: 1),
                    MilestoneAction(id: "stem-5-action-2", title: "Explore STEM in your community", description: "Identify STEM-related organizations, labs, or companies near you. Learn what they do and how they use STEM skills.", order: 2),
                    MilestoneAction(id: "stem-5-action-3", title: "Connect your projects to careers", description: "Write a paragraph for each of your projects explaining how it relates to real-world STEM work.", order: 3),
                ],
                skillsDeveloped: ["Technical Exploration", "Critical Thinking", "Research"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Research 2–3 STEM careers in depth.",
                    "Identify STEM applications in your community.",
                    "Connect your projects to real-world work.",
                ],
                dependencies: ["stem-4"],
                learningResources: [
                    MilestoneResource(id: "st5-res-1", title: "Bureau of Labor Statistics: STEM Careers", provider: "BLS", url: "https://www.bls.gov/ooh/math/", type: .documentation, description: "Free career information including job outlook, pay, and daily tasks.", estimatedTime: "20 min"),
                    MilestoneResource(id: "st5-res-2", title: "MIT OpenCourseWare", provider: "MIT OCW", url: "https://ocw.mit.edu/", type: .course, description: "Free MIT course materials to explore advanced STEM topics.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "stem-6", title: "Choose a Direction", subtitle: "Commit to a STEM area for deeper study.", estimatedTime: "1 week",
                whatItAccomplishes: "Make an informed decision about which STEM area to pursue further and create a plan for continued growth.",
                whyItMatters: "Exploration is valuable, but commitment is what leads to expertise. This milestone helps you turn exploration into a focused plan.",
                goal: "Choose one STEM area to focus on and write a plan for how to develop further in that area.",
                actions: [
                    MilestoneAction(id: "stem-6-action-1", title: "Review your exploration", description: "Look back at everything you explored — interests, projects, research. What excited you most? Where did you do your best work?", order: 1),
                    MilestoneAction(id: "stem-6-action-2", title: "Choose your direction", description: "Pick one STEM area to focus on. Write a paragraph explaining why this is your choice.", order: 2),
                    MilestoneAction(id: "stem-6-action-3", title: "Create a next-steps plan", description: "Write a plan for the next 3–6 months: what courses to take, what projects to build, what skills to develop.", order: 3),
                    MilestoneAction(id: "stem-6-action-4", title: "Share your direction", description: "Tell a teacher, mentor, or parent about your chosen direction and your plan. Ask for their input.", order: 4),
                ],
                skillsDeveloped: ["Goal Setting", "Academic Planning", "Decision Making", "Communication"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Choose one STEM area to focus on.",
                    "Write a 3–6 month plan for development.",
                    "Discuss your direction with at least one person.",
                ],
                dependencies: ["stem-5"],
                learningResources: [
                    MilestoneResource(id: "st6-res-1", title: "College Scorecard", provider: "U.S. Department of Education", url: "https://collegescorecard.ed.gov/", type: .interactive, description: "Explore colleges and their STEM programs to plan your academic path.", estimatedTime: "20 min"),
                ]
            ),
        ], relevantInterests: ["Technology", "Engineering", "Science", "Mathematics", "Environment"], relevantSkills: ["Mathematics", "Building things", "Problem solving", "Programming"], relevantCareers: ["Software Engineer", "Mechanical Engineer", "Civil Engineer", "Environmental Scientist"], relevantFields: ["Engineering", "Computer Science", "Biology", "Physics", "Mathematics"], eligibleGrades: [.seventh, .eighth, .ninth, .tenth, .eleventh, .twelfth], collegeFocused: false),
        // MARK: - Leadership
        Roadmap(id: "leadership", title: "Build Leadership Experience", goal: "Develop real leadership skills through hands-on initiative and collaboration.", category: .skills, description: "A practical path from understanding leadership to creating real impact through projects and teamwork.", milestones: [
            .init(
                id: "leadership-1", title: "Understand Leadership", subtitle: "Learn what leadership actually means beyond titles.", estimatedTime: "45 min",
                whatItAccomplishes: "Understand that leadership is about influence, initiative, and responsibility — not just being in charge.",
                whyItMatters: "True leadership is a skill, not a position. Understanding this early helps you lead from wherever you are.",
                goal: "Explain what leadership means to you and identify 3 examples of effective leadership you have seen.",
                actions: [
                    MilestoneAction(id: "leadership-1-action-1", title: "Watch leadership stories", description: "Watch 2–3 TED talks or videos about leadership. Note what the speakers say makes a good leader.", order: 1),
                    MilestoneAction(id: "leadership-1-action-2", title: "Identify leaders you admire", description: "Think of 3 people you consider good leaders — they could be teachers, community members, or public figures. Write why you admire them.", order: 2),
                    MilestoneAction(id: "leadership-1-action-3", title: "Write your leadership philosophy", description: "Write a paragraph about what you believe leadership means and what kind of leader you want to be.", order: 3),
                ],
                skillsDeveloped: ["Leadership", "Communication", "Critical Thinking"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Identify 3 leaders you admire and explain why.",
                    "Write a personal leadership philosophy paragraph.",
                ],
                learningResources: [
                    MilestoneResource(id: "l1-res-1", title: "TED Talks: Leadership", provider: "TED", url: "https://www.ted.com/topics/leadership", type: .video, description: "Free talks from leaders across every field sharing their insights.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "l1-res-2", title: "Khan Academy: Life Skills", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more", type: .interactive, description: "Free lessons on communication, decision-making, and personal development.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "leadership-2", title: "Take Initiative", subtitle: "Start something without being asked.", estimatedTime: "2–3 weeks",
                whatItAccomplishes: "Practice taking initiative by identifying a need and acting on it without waiting for permission.",
                whyItMatters: "Initiative is the foundation of leadership. The ability to see what needs doing and start doing it is a skill that transfers everywhere.",
                goal: "Identify a need in your school or community and take concrete action to address it.",
                actions: [
                    MilestoneAction(id: "leadership-2-action-1", title: "Observe your environment", description: "Look around your school, team, or community. What is missing? What could be better? Write down 5 things you notice.", order: 1),
                    MilestoneAction(id: "leadership-2-action-2", title: "Pick one thing to act on", description: "Choose one problem you can realistically address. Write a simple plan for what you will do.", order: 2),
                    MilestoneAction(id: "leadership-2-action-3", title: "Start small and act", description: "Take one concrete step toward solving the problem. It does not need to be perfect — it needs to exist.", order: 3),
                    MilestoneAction(id: "leadership-2-action-4", title: "Invite one person to help", description: "Ask one friend, classmate, or teammate to join you. Leadership is not about doing everything alone.", order: 4),
                ],
                skillsDeveloped: ["Initiative", "Problem Solving", "Communication", "Planning"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Identify a real need in your environment.",
                    "Take at least one concrete action.",
                    "Recruit at least one person to help.",
                ],
                dependencies: ["leadership-1"],
                learningResources: [
                    MilestoneResource(id: "l2-res-1", title: "DoSomething.org", provider: "Do Something", url: "https://www.dosomething.org/", type: .interactive, description: "Find ideas for making a difference in your community.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "leadership-3", title: "Lead a Small Project", subtitle: "Organize and deliver a project from start to finish.", estimatedTime: "3–5 weeks",
                whatItAccomplishes: "Practice leading a small project — planning, organizing, delegating, and delivering results.",
                whyItMatters: "Leading a project teaches you skills no amount of reading can: managing time, handling setbacks, and keeping people motivated.",
                goal: "Plan and complete a small project with at least 2 other people, delivering a tangible result.",
                actions: [
                    MilestoneAction(id: "leadership-3-action-1", title: "Define the project", description: "Choose a small project with a clear goal — an event, a fundraiser, a service project, or a creative project. Write a one-page plan.", order: 1),
                    MilestoneAction(id: "leadership-3-action-2", title: "Recruit and delegate", description: "Get 2–3 people to help. Assign clear roles and responsibilities. Set a schedule with deadlines.", order: 2),
                    MilestoneAction(id: "leadership-3-action-3", title: "Manage the work", description: "Check in regularly with your team. Solve problems as they come up. Adjust plans when needed.", order: 3),
                    MilestoneAction(id: "leadership-3-action-4", title: "Deliver and reflect", description: "Complete the project. Write a brief reflection: What worked? What was hard? What would you do differently?", order: 4),
                ],
                skillsDeveloped: ["Project Management", "Collaboration", "Planning", "Problem Solving"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Write a one-page project plan.",
                    "Lead at least 2 people to complete the project.",
                    "Write a reflection on what you learned.",
                ],
                dependencies: ["leadership-2"],
                learningResources: [
                    MilestoneResource(id: "l3-res-1", title: "Trello: Getting Started", provider: "Trello", url: "https://trello.com/guide", type: .documentation, description: "Free tool for organizing projects and tasks visually.", estimatedTime: "15 min"),
                    MilestoneResource(id: "l3-res-2", title: "Google Workspace", provider: "Google", url: "https://workspace.google.com/", type: .interactive, description: "Free tools for documents, spreadsheets, and collaboration.", estimatedTime: "10 min"),
                ]
            ),
            .init(
                id: "leadership-4", title: "Work With Others", subtitle: "Develop collaboration and communication skills.", estimatedTime: "2–3 weeks",
                whatItAccomplishes: "Practice working effectively with diverse people — listening, communicating, and building consensus.",
                whyItMatters: "Leadership is fundamentally about working with people. The best leaders are the best collaborators.",
                goal: "Work with a diverse group on a shared goal and practice specific collaboration skills.",
                actions: [
                    MilestoneAction(id: "leadership-4-action-1", title: "Join a team or group", description: "Join a club, team, or community group where you work with people who may think differently than you.", order: 1),
                    MilestoneAction(id: "leadership-4-action-2", title: "Practice active listening", description: "In your next group meeting, focus on listening fully before responding. Ask clarifying questions instead of interrupting.", order: 2),
                    MilestoneAction(id: "leadership-4-action-3", title: "Resolve a disagreement", description: "When a disagreement arises in a group, practice finding common ground. Focus on the problem, not the person.", order: 3),
                    MilestoneAction(id: "leadership-4-action-4", title: "Give constructive feedback", description: "Practice giving feedback that is specific, helpful, and kind. Focus on what could be improved, not what is wrong.", order: 4),
                ],
                skillsDeveloped: ["Collaboration", "Communication", "Public Speaking", "Responsibility"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Join and participate in a group or team.",
                    "Practice active listening in a real conversation.",
                    "Give constructive feedback to a peer.",
                ],
                dependencies: ["leadership-3"],
                learningResources: [
                    MilestoneResource(id: "l4-res-1", title: "Toastmasters Youth Leadership", provider: "Toastmasters", url: "https://www.toastmasters.org/", type: .interactive, description: "Free programs for developing public speaking and leadership skills.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "leadership-5", title: "Create Measurable Impact", subtitle: "Do something that makes a measurable difference.", estimatedTime: "3–5 weeks",
                whatItAccomplishes: "Lead an initiative that creates a measurable, positive impact on your school, community, or organization.",
                whyItMatters: "Impact is the ultimate measure of leadership. Creating real change demonstrates that your leadership has value beyond words.",
                goal: "Lead an initiative that creates a measurable positive outcome — people helped, money raised, problems solved, or resources created.",
                actions: [
                    MilestoneAction(id: "leadership-5-action-1", title: "Define measurable goals", description: "Choose an initiative with a clear, measurable goal. For example: 'Collect 100 books' or 'Help 20 students improve grades.'", order: 1),
                    MilestoneAction(id: "leadership-5-action-2", title: "Build a team and plan", description: "Recruit a team, create a detailed plan with deadlines, and assign roles. Make a timeline.", order: 2),
                    MilestoneAction(id: "leadership-5-action-3", title: "Execute the initiative", description: "Run the initiative, track your progress against your goals, and adjust when things do not go as planned.", order: 3),
                    MilestoneAction(id: "leadership-5-action-4", title: "Measure and report results", description: "Document your results: What did you accomplish? How many people were affected? What would you improve?", order: 4),
                ],
                skillsDeveloped: ["Leadership", "Project Management", "Impact Measurement", "Planning"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Set and track measurable goals.",
                    "Execute an initiative that creates real impact.",
                    "Document and report your results.",
                ],
                dependencies: ["leadership-4"],
                learningResources: [
                    MilestoneResource(id: "l5-res-1", title: "VolunteerMatch", provider: "VolunteerMatch", url: "https://www.volunteermatch.org/", type: .interactive, description: "Find volunteer opportunities to create community impact.", estimatedTime: "15 min"),
                    MilestoneResource(id: "l5-res-2", title: "Idealist", provider: "Idealist.org", url: "https://www.idealist.org/", type: .interactive, description: "Find opportunities for social impact and community service.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "leadership-6", title: "Document Your Leadership", subtitle: "Record your leadership experience for future opportunities.", estimatedTime: "1 week",
                whatItAccomplishes: "Create a documented record of your leadership experience that you can share with colleges or employers.",
                whyItMatters: "Undocumented experience is invisible experience. Recording your leadership turns your work into evidence of your abilities.",
                goal: "Create a leadership portfolio that documents your growth, impact, and learning.",
                actions: [
                    MilestoneAction(id: "leadership-6-action-1", title: "Write a leadership summary", description: "Write a 1–2 page summary of your leadership journey: what you did, what you learned, and how you grew.", order: 1),
                    MilestoneAction(id: "leadership-6-action-2", title: "Collect evidence", description: "Gather evidence of your leadership — photos, emails, thank-you notes, project results, or feedback from others.", order: 2),
                    MilestoneAction(id: "leadership-6-action-3", title: "Create a digital record", description: "Put your leadership summary and evidence in a document or website you can share.", order: 3),
                ],
                skillsDeveloped: ["Portfolio Development", "Technical Communication", "Personal Branding"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Write a leadership summary.",
                    "Collect at least 3 pieces of evidence.",
                    "Create a shareable digital record.",
                ],
                dependencies: ["leadership-5"],
                learningResources: [
                    MilestoneResource(id: "l6-res-1", title: "Google Docs", provider: "Google", url: "https://docs.google.com/", type: .interactive, description: "Free tool for creating and sharing documents.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "l6-res-2", title: "GitHub Pages", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: .documentation, description: "Create a free website to showcase your leadership portfolio.", estimatedTime: "15 min"),
                ]
            ),
        ], relevantInterests: ["Business", "Community Service", "Politics", "Education"], relevantSkills: ["Communication", "Leadership", "Planning"], relevantCareers: ["Business Manager", "Lawyer", "Teacher"], relevantFields: ["Business", "Education", "Law", "Political Science"], eligibleGrades: [.seventh, .eighth, .ninth, .tenth, .eleventh, .twelfth], collegeFocused: false),
        // MARK: - Community Impact
        Roadmap(id: "community-impact", title: "Build Community Impact", goal: "Create real, positive change in your community through structured service.", category: .skills, description: "Move from wanting to help to making a measurable difference through research, planning, and execution.", milestones: [
            .init(
                id: "community-1", title: "Understand Your Community", subtitle: "Learn the real needs and strengths of the community around you.", estimatedTime: "1 hour",
                whatItAccomplishes: "Understand the real needs, strengths, and challenges of your community — not assumptions, but facts.",
                whyItMatters: "Effective community work starts with understanding. Knowing what your community actually needs prevents wasted effort.",
                goal: "Identify 3 real needs in your community and understand the people affected by them.",
                actions: [
                    MilestoneAction(id: "community-1-action-1", title: "Walk your neighborhood", description: "Take a walk and observe. What do you notice? What seems to be working well? What seems to need attention?", order: 1),
                    MilestoneAction(id: "community-1-action-2", title: "Talk to people", description: "Ask 3–5 people in your community — neighbors, teachers, local workers — what they think the biggest needs are.", order: 2),
                    MilestoneAction(id: "community-1-action-3", title: "Research local data", description: "Look up your community's demographics, needs, and resources. Check local government websites, news, or community organizations.", order: 3),
                    MilestoneAction(id: "community-1-action-4", title: "Map community resources", description: "Make a list of existing organizations, services, and programs in your area. What is already being done?", order: 4),
                ],
                skillsDeveloped: ["Community Research", "Critical Thinking", "Communication", "Research"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Identify 3 real community needs.",
                    "Talk to at least 3 community members.",
                    "Create a map of existing community resources.",
                ],
                learningResources: [
                    MilestoneResource(id: "cm1-res-1", title: "DoSomething.org", provider: "Do Something", url: "https://www.dosomething.org/", type: .interactive, description: "Find ideas and organizations working on community issues.", estimatedTime: "15 min"),
                    MilestoneResource(id: "cm1-res-2", title: "VolunteerMatch", provider: "VolunteerMatch", url: "https://www.volunteermatch.org/", type: .interactive, description: "Discover local volunteer opportunities and organizations.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "community-2", title: "Identify a Real Need", subtitle: "Focus on one specific problem you can realistically address.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Choose one community need that you can realistically address with your available time, skills, and resources.",
                whyItMatters: "Focusing on one specific, achievable problem is more effective than trying to solve everything at once.",
                goal: "Select one community need, research it thoroughly, and write a brief needs assessment.",
                actions: [
                    MilestoneAction(id: "community-2-action-1", title: "Review your community research", description: "Look at the needs you identified. Which ones are important, achievable, and meaningful to you personally?", order: 1),
                    MilestoneAction(id: "community-2-action-2", title: "Choose one need to address", description: "Pick one specific, focused need. Write a clear problem statement: who is affected, what the problem is, and why it matters.", order: 2),
                    MilestoneAction(id: "community-2-action-3", title: "Research existing solutions", description: "Find out how others have addressed similar problems. What approaches worked? What did not? What can you learn?", order: 3),
                    MilestoneAction(id: "community-2-action-4", title: "Write a needs assessment", description: "Write a one-page document explaining the problem, who it affects, what has been tried, and why a response is needed.", order: 4),
                ],
                skillsDeveloped: ["Problem Solving", "Research", "Critical Thinking", "Writing"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Write a clear problem statement.",
                    "Research how others have addressed similar problems.",
                    "Write a one-page needs assessment.",
                ],
                dependencies: ["community-1"],
                learningResources: [
                    MilestoneResource(id: "cm2-res-1", title: "Khan Academy: Research Methods", provider: "Khan Academy", url: "https://www.khanacademy.org/science/health-and-medicine/ethics", type: .interactive, description: "Free lessons on research and ethical considerations.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "community-3", title: "Design a Response", subtitle: "Plan a realistic project to address the need you identified.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Design a realistic project plan that addresses the community need with available resources.",
                whyItMatters: "Good planning prevents wasted effort. A clear plan helps you rally support and track progress.",
                goal: "Create a detailed project plan with goals, timeline, resources needed, and success metrics.",
                actions: [
                    MilestoneAction(id: "community-3-action-1", title: "Define project goals", description: "Write specific, measurable goals for your project. What exactly will you accomplish? How will you know you succeeded?", order: 1),
                    MilestoneAction(id: "community-3-action-2", title: "Create a project plan", description: "Write a plan with: timeline, tasks, people needed, resources, and a budget if applicable.", order: 2),
                    MilestoneAction(id: "community-3-action-3", title: "Identify resources", description: "List everything you need: people, money, materials, space, permissions. Identify where each will come from.", order: 3),
                    MilestoneAction(id: "community-3-action-4", title: "Get approval and support", description: "Share your plan with a teacher, mentor, or community leader. Get feedback and any needed permissions.", order: 4),
                ],
                skillsDeveloped: ["Project Planning", "Communication", "Planning", "Organization"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Write a detailed project plan.",
                    "Identify all resources needed.",
                    "Get approval or support from at least one person.",
                ],
                dependencies: ["community-2"],
                learningResources: [
                    MilestoneResource(id: "cm3-res-1", title: "Trello: Getting Started", provider: "Trello", url: "https://trello.com/guide", type: .documentation, description: "Free visual tool for organizing project tasks and timelines.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "community-4", title: "Execute a Project", subtitle: "Carry out your plan and make a real difference.", estimatedTime: "3–6 weeks",
                whatItAccomplishes: "Execute your project, manage your team, and deliver the planned outcome.",
                whyItMatters: "Execution is where plans become reality. This is where you learn to handle setbacks, motivate others, and deliver results.",
                goal: "Execute your project according to plan, document what happens, and deliver a measurable outcome.",
                actions: [
                    MilestoneAction(id: "community-4-action-1", title: "Launch the project", description: "Start your project according to your plan. Communicate clearly with everyone involved about what is happening.", order: 1),
                    MilestoneAction(id: "community-4-action-2", title: "Track progress", description: "Keep a record of what you do, what happens, and any changes you make. Take photos and collect data.", order: 2),
                    MilestoneAction(id: "community-4-action-3", title: "Handle challenges", description: "When things do not go as planned — and they will — adapt and find solutions. Document what you did.", order: 3),
                    MilestoneAction(id: "community-4-action-4", title: "Complete the project", description: "Finish what you started. Make sure you have documented the results and thanked everyone who helped.", order: 4),
                ],
                skillsDeveloped: ["Project Management", "Collaboration", "Problem Solving", "Communication"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Execute the project from start to finish.",
                    "Document challenges and how you addressed them.",
                    "Collect results and outcomes.",
                ],
                dependencies: ["community-3"],
                learningResources: [
                    MilestoneResource(id: "cm4-res-1", title: "Google Workspace", provider: "Google", url: "https://workspace.google.com/", type: .interactive, description: "Free tools for documents, spreadsheets, and team collaboration.", estimatedTime: "10 min"),
                ]
            ),
            .init(
                id: "community-5", title: "Measure the Impact", subtitle: "Assess what your project actually accomplished.", estimatedTime: "1 week",
                whatItAccomplishes: "Evaluate your project's impact using data and feedback, and understand what worked and what did not.",
                whyItMatters: "Without measurement, you cannot know if your project actually helped. Measuring impact teaches you to evaluate your own work honestly.",
                goal: "Measure your project's impact using data, collect feedback, and write an impact report.",
                actions: [
                    MilestoneAction(id: "community-5-action-1", title: "Collect data", description: "Gather quantitative and qualitative data: how many people helped, what changed, what people said about your project.", order: 1),
                    MilestoneAction(id: "community-5-action-2", title: "Analyze results", description: "Compare your results to your original goals. What did you accomplish? What fell short? Why?", order: 2),
                    MilestoneAction(id: "community-5-action-3", title: "Get feedback", description: "Ask the people who benefited from your project what they thought. What was most helpful? What could be improved?", order: 3),
                    MilestoneAction(id: "community-5-action-4", title: "Write an impact report", description: "Write a 1–2 page report: what you set out to do, what you accomplished, what you learned, and what you would change.", order: 4),
                ],
                skillsDeveloped: ["Impact Measurement", "Data Analysis", "Technical Writing", "Critical Thinking"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Collect both quantitative and qualitative data.",
                    "Get feedback from project beneficiaries.",
                    "Write a 1–2 page impact report.",
                ],
                dependencies: ["community-4"],
                learningResources: [
                    MilestoneResource(id: "cm5-res-1", title: "Google Forms", provider: "Google", url: "https://docs.google.com/forms/", type: .interactive, description: "Free tool for creating surveys to collect feedback.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "community-6", title: "Document & Continue the Work", subtitle: "Preserve your work and plan for lasting impact.", estimatedTime: "1 week",
                whatItAccomplishes: "Document your project thoroughly so others can learn from it or continue the work.",
                whyItMatters: "Projects end, but their impact can last if documented well. Your work can inspire and guide others.",
                goal: "Create a complete project documentation package and a plan for sustaining or passing on the work.",
                actions: [
                    MilestoneAction(id: "community-6-action-1", title: "Write a project summary", description: "Write a complete summary of your project: the need, your response, the results, and what you learned about community work.", order: 1),
                    MilestoneAction(id: "community-6-action-2", title: "Create a handoff document", description: "If someone else might continue this work, write a guide: what was done, what works, what to watch out for.", order: 2),
                    MilestoneAction(id: "community-6-action-3", title: "Share your story", description: "Share your project story with a teacher, community group, or online. Your experience can inspire others to take action.", order: 3),
                ],
                skillsDeveloped: ["Technical Writing", "Portfolio Development", "Communication", "Leadership"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Write a complete project summary.",
                    "Create a handoff document for future work.",
                    "Share your story with at least one audience.",
                ],
                dependencies: ["community-5"],
                learningResources: [
                    MilestoneResource(id: "cm6-res-1", title: "Google Docs", provider: "Google", url: "https://docs.google.com/", type: .interactive, description: "Free tool for creating and sharing project documentation.", estimatedTime: "Self-paced"),
                ]
            ),
        ], relevantInterests: ["Community Service", "Environment", "Education", "Health"], relevantSkills: ["Communication", "Leadership", "Planning", "Problem solving"], relevantCareers: ["Social Worker", "Urban Planner", "Public Health"], relevantFields: ["Social Work", "Public Health", "Environmental Science", "Education"], eligibleGrades: [.seventh, .eighth, .ninth, .tenth, .eleventh, .twelfth], collegeFocused: false),
        // MARK: - Venture
        Roadmap(id: "venture", title: "Explore Entrepreneurship", goal: "Learn how to identify problems, develop solutions, and build something people actually want.", category: .career, description: "A practical path from identifying problems to building and presenting a venture idea.", milestones: [
            .init(
                id: "venture-1", title: "Identify Problems", subtitle: "Learn to see problems worth solving.", estimatedTime: "1 hour",
                whatItAccomplishes: "Train yourself to notice problems in everyday life and evaluate which ones are worth solving.",
                whyItMatters: "Entrepreneurship starts with noticing what is broken or missing. The ability to see problems is the first step to building solutions.",
                goal: "Identify 5 real problems in your daily life and evaluate which ones are most worth solving.",
                actions: [
                    MilestoneAction(id: "venture-1-action-1", title: "Observe your daily life", description: "For one week, write down every frustration, inconvenience, or problem you encounter. Aim for at least 10.", order: 1),
                    MilestoneAction(id: "venture-1-action-2", title: "Evaluate your problems", description: "For each problem, rate it: How common is it? How painful? How many people have it? Would someone pay to fix it?", order: 2),
                    MilestoneAction(id: "venture-1-action-3", title: "Research existing solutions", description: "For your top 3 problems, search for existing solutions. What exists? What is missing? What could be better?", order: 3),
                ],
                skillsDeveloped: ["Problem Discovery", "Critical Thinking", "Research"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Identify at least 10 problems from daily life.",
                    "Evaluate your top problems using clear criteria.",
                    "Research existing solutions for your top 3.",
                ],
                learningResources: [
                    MilestoneResource(id: "v1-res-1", title: "How to Start a Startup", provider: "Stanford / Y Combinator", url: "https://www.ycombinator.com/library/6g-how-to-start-a-startup", type: .course, description: "Stanford lectures on finding problems and building solutions.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "v1-res-2", title: "Khan Academy: Entrepreneurship", provider: "Khan Academy", url: "https://www.khanacademy.org/economics-finance-domain", type: .interactive, description: "Free lessons on economics, finance, and business fundamentals.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "venture-2", title: "Understand Users", subtitle: "Learn who you are building for and what they actually need.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Develop the skill of understanding users — their needs, behaviors, and pain points — before building anything.",
                whyItMatters: "Building something nobody wants is the most common startup failure. Understanding users first saves time and effort.",
                goal: "Interview 3–5 people about a problem you identified and document their needs and behaviors.",
                actions: [
                    MilestoneAction(id: "venture-2-action-1", title: "Define who has the problem", description: "For your top problem, describe exactly who experiences it. Be specific: age, situation, frequency, context.", order: 1),
                    MilestoneAction(id: "venture-2-action-2", title: "Interview potential users", description: "Talk to 3–5 people who have the problem. Ask open-ended questions about how they currently deal with it.", order: 2),
                    MilestoneAction(id: "venture-2-action-3", title: "Map user needs", description: "Write down the key needs, frustrations, and desires your interviews revealed. Look for patterns.", order: 3),
                    MilestoneAction(id: "venture-2-action-4", title: "Validate the problem", description: "Based on your interviews, confirm: Is this really a problem? How do people currently solve it? Would they switch to a better solution?", order: 4),
                ],
                skillsDeveloped: ["User Research", "Communication", "Critical Thinking", "Empathy"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Interview at least 3 people about the problem.",
                    "Document user needs and pain points.",
                    "Validate whether the problem is worth solving.",
                ],
                dependencies: ["venture-1"],
                learningResources: [
                    MilestoneResource(id: "v2-res-1", title: "IDEO Design Thinking", provider: "IDEO", url: "https://www.designkit.org/", type: .interactive, description: "Free design thinking resources for understanding users.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "venture-3", title: "Develop Solutions", subtitle: "Brainstorm and evaluate possible solutions.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Generate multiple potential solutions and evaluate them based on feasibility, impact, and user needs.",
                whyItMatters: "The first idea is rarely the best. brainstorming multiple solutions and evaluating them leads to better outcomes.",
                goal: "Generate at least 5 potential solutions, evaluate them, and select the most promising one to develop.",
                actions: [
                    MilestoneAction(id: "venture-3-action-1", title: "Brainstorm solutions", description: "Write down at least 5 different ways to solve the problem. Do not judge — just generate ideas.", order: 1),
                    MilestoneAction(id: "venture-3-action-2", title: "Evaluate each idea", description: "Rate each idea: Can you build it? Would people use it? Is it different from existing solutions? Could it make money?", order: 2),
                    MilestoneAction(id: "venture-3-action-3", title: "Choose your best solution", description: "Select the most promising idea. Write a clear description of what it is, who it is for, and why it is better.", order: 3),
                    MilestoneAction(id: "venture-3-action-4", title: "Describe your value proposition", description: "Write one sentence that explains why someone would choose your solution over alternatives.", order: 4),
                ],
                skillsDeveloped: ["Product Thinking", "Critical Thinking", "Decision Making", "Communication"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Generate at least 5 potential solutions.",
                    "Evaluate each idea against clear criteria.",
                    "Write a clear value proposition.",
                ],
                dependencies: ["venture-2"],
                learningResources: [
                    MilestoneResource(id: "v3-res-1", title: "Lean Startup Methodology", provider: "Lean Startup", url: "https://theleanstartup.com/", type: .article, description: "Introduction to building and testing business ideas efficiently.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "venture-4", title: "Build a Prototype", subtitle: "Create a simple version of your solution people can interact with.", estimatedTime: "2–3 weeks",
                whatItAccomplishes: "Build a basic prototype that demonstrates how your solution works, without spending months on development.",
                whyItMatters: "A prototype lets you test your idea quickly and cheaply. It is better to learn fast than to build the wrong thing perfectly.",
                goal: "Build a working prototype that someone can interact with and provide feedback on.",
                actions: [
                    MilestoneAction(id: "venture-4-action-1", title: "Define your prototype scope", description: "Decide what the minimum version of your solution looks like. What is the one thing it must do to demonstrate the idea?", order: 1),
                    MilestoneAction(id: "venture-4-action-2", title: "Choose your tool", description: "Pick a tool for building your prototype: a landing page, a paper prototype, a simple app, or a slide deck.", order: 2),
                    MilestoneAction(id: "venture-4-action-3", title: "Build the prototype", description: "Create a basic version that demonstrates the core idea. It does not need to be perfect — it needs to be testable.", order: 3),
                    MilestoneAction(id: "venture-4-action-4", title: "Test with one person", description: "Show your prototype to one person and watch them try to use it. Note where they get confused or frustrated.", order: 4),
                ],
                skillsDeveloped: ["Prototyping", "Building Things", "User Research", "Product Thinking"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Build a prototype someone can interact with.",
                    "Test it with at least one person.",
                    "Document feedback and issues found.",
                ],
                dependencies: ["venture-3"],
                learningResources: [
                    MilestoneResource(id: "v4-res-1", title: "Figma: Getting Started", provider: "Figma", url: "https://help.figma.com/hc/en-us/articles/360040318013", type: .documentation, description: "Free tool for designing and prototyping digital products.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "v4-res-2", title: "InVision: Prototyping", provider: "InVision", url: "https://www.invisionapp.com/inside-design/how-to-prototype/", type: .article, description: "Guide to building effective prototypes.", estimatedTime: "10 min"),
                ]
            ),
            .init(
                id: "venture-5", title: "Test & Iterate", subtitle: "Improve your solution based on real feedback.", estimatedTime: "2–3 weeks",
                whatItAccomplishes: "Gather feedback from multiple people, identify improvements, and iterate on your prototype.",
                whyItMatters: "Iteration is how good ideas become great ones. Testing with real people reveals what you cannot see on your own.",
                goal: "Get feedback from 3–5 people, identify the top improvements, and update your prototype.",
                actions: [
                    MilestoneAction(id: "venture-5-action-1", title: "Show your prototype to more people", description: "Let 3–5 people try your prototype. Ask them: What do you think this does? Would you use it? What is missing?", order: 1),
                    MilestoneAction(id: "venture-5-action-2", title: "Collect and organize feedback", description: "Write down all feedback. Group similar comments together. Identify the most common themes.", order: 2),
                    MilestoneAction(id: "venture-5-action-3", title: "Prioritize improvements", description: "Choose the 2–3 most important improvements based on frequency and impact. Update your prototype.", order: 3),
                    MilestoneAction(id: "venture-5-action-4", title: "Test again", description: "Show the updated prototype to 1–2 new people. See if the improvements addressed the issues.", order: 4),
                ],
                skillsDeveloped: ["Iteration", "User Research", "Product Thinking", "Communication"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Get feedback from at least 3 people.",
                    "Make at least 2 improvements based on feedback.",
                    "Test the updated prototype with new people.",
                ],
                dependencies: ["venture-4"],
                learningResources: [
                    MilestoneResource(id: "v5-res-1", title: "Google Ventures: Sprint", provider: "Google Ventures", url: "https://www.thesprintbook.com/", type: .article, description: "Guide to rapid prototyping and testing of ideas.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "venture-6", title: "Present the Venture", subtitle: "Communicate your idea clearly and convincingly.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Create a clear, compelling presentation of your venture idea that demonstrates the problem, solution, and potential.",
                whyItMatters: "Even the best idea fails if you cannot explain it. The ability to communicate your vision is essential for any venture.",
                goal: "Create and deliver a clear presentation of your venture that explains the problem, solution, users, and potential.",
                actions: [
                    MilestoneAction(id: "venture-6-action-1", title: "Write your pitch", description: "Write a 1–2 page description of your venture: the problem, your solution, who it is for, and why it matters.", order: 1),
                    MilestoneAction(id: "venture-6-action-2", title: "Create a presentation", description: "Build a 5–10 slide presentation covering: problem, solution, prototype demo, user feedback, and next steps.", order: 2),
                    MilestoneAction(id: "venture-6-action-3", title: "Practice your pitch", description: "Rehearse presenting your venture in 3–5 minutes. Practice answering tough questions.", order: 3),
                    MilestoneAction(id: "venture-6-action-4", title: "Present to someone", description: "Present your venture to a teacher, mentor, parent, or class. Ask for honest feedback on your idea and presentation.", order: 4),
                ],
                skillsDeveloped: ["Presentation", "Communication", "Technical Communication", "Business Fundamentals"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Write a clear venture description.",
                    "Create a 5–10 slide presentation.",
                    "Present to at least one person and get feedback.",
                ],
                dependencies: ["venture-5"],
                learningResources: [
                    MilestoneResource(id: "v6-res-1", title: "SlidesCarnival", provider: "SlidesCarnival", url: "https://www.slidescarnival.com/", type: .interactive, description: "Free presentation templates for Google Slides and PowerPoint.", estimatedTime: "10 min"),
                    MilestoneResource(id: "v6-res-2", title: "Guy Kawasaki: The 10/20/30 Rule", provider: "Guy Kawasaki", url: "https://guykawasaki.com/the-only-10-slides-you-need-in-your-pitch/", type: .article, description: "Simple framework for effective venture presentations.", estimatedTime: "10 min"),
                ]
            ),
        ], relevantInterests: ["Business", "Technology", "Design", "Entrepreneurship"], relevantSkills: ["Problem solving", "Building things", "Communication", "Creativity"], relevantCareers: ["Product Designer", "Business Manager", "Software Engineer"], relevantFields: ["Business", "Computer Science", "Design"], eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth], collegeFocused: false),
        // MARK: - Competitive Profile
        Roadmap(id: "competitive-profile", title: "Build a Competitive Student Profile", goal: "Develop a well-rounded profile that demonstrates your abilities across academics, activities, and personal qualities.", category: .career, description: "A comprehensive path to building the experiences, skills, and documentation that make you stand out.", milestones: [
            .init(
                id: "profile-1", title: "Define Your Direction", subtitle: "Understand what makes you unique and where you want to go.", estimatedTime: "1 hour",
                whatItAccomplishes: "Clarify your interests, strengths, and goals so you can build a focused, authentic profile.",
                whyItMatters: "A competitive profile is not about doing everything — it is about doing the right things well. Direction prevents scattered effort.",
                goal: "Identify your top 3 interests, your strongest skills, and write a brief personal mission statement.",
                actions: [
                    MilestoneAction(id: "profile-1-action-1", title: "Audit your interests and strengths", description: "List everything you are interested in and good at. Circle the 3 that matter most to you.", order: 1),
                    MilestoneAction(id: "profile-1-action-2", title: "Research what makes profiles competitive", description: "Look at profiles of students who got into programs you admire. What did they do? What patterns do you see?", order: 2),
                    MilestoneAction(id: "profile-1-action-3", title: "Write a personal mission statement", description: "Write 2–3 sentences about what you want to accomplish and what kind of person you want to become.", order: 3),
                ],
                skillsDeveloped: ["Goal Setting", "Self-Advocacy", "Critical Thinking"],
                completionCriteria: [
                    "Complete all three actions.",
                    "Identify your top 3 interests and strengths.",
                    "Research competitive profiles.",
                    "Write a personal mission statement.",
                ],
                learningResources: [
                    MilestoneResource(id: "pr1-res-1", title: "Khan Academy: College Admissions", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more/college-admissions", type: .interactive, description: "Free lessons on what colleges look for in applicants.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "profile-2", title: "Build Strong Foundations", subtitle: "Strengthen your academic record and core skills.", estimatedTime: "Ongoing",
                whatItAccomplishes: "Ensure your academic record and core skills are as strong as possible.",
                whyItMatters: "Strong academics are the foundation everything else builds on. Without them, other achievements have less impact.",
                goal: "Improve your weakest academic areas and establish strong study habits.",
                actions: [
                    MilestoneAction(id: "profile-2-action-1", title: "Review your grades", description: "Look at your transcript. Identify your weakest subjects and create a plan to improve them.", order: 1),
                    MilestoneAction(id: "profile-2-action-2", title: "Challenge yourself academically", description: "Take the most rigorous courses you can handle. Show colleges you push yourself.", order: 2),
                    MilestoneAction(id: "profile-2-action-3", title: "Build foundational skills", description: "Develop strong writing, math, and communication skills. These apply everywhere.", order: 3),
                    MilestoneAction(id: "profile-2-action-4", title: "Develop a study system", description: "Create a consistent study routine that works for you. Track your progress and adjust as needed.", order: 4),
                ],
                skillsDeveloped: ["Academic Planning", "Time Management", "Writing", "Goal Setting"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Identify and address your weakest academic areas.",
                    "Take challenging courses.",
                    "Establish a consistent study system.",
                ],
                dependencies: ["profile-1"],
                learningResources: [
                    MilestoneResource(id: "pr2-res-1", title: "Khan Academy: Study Skills", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more", type: .interactive, description: "Free lessons on study skills and academic planning.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "pr2-res-2", title: "College Board: Course Planning", provider: "College Board", url: "https://bigfuture.collegeboard.org/plan-for-college/planning-for-college", type: .documentation, description: "Guidance on choosing courses for college preparation.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "profile-3", title: "Develop Demonstrable Skills", subtitle: "Build skills you can prove through work, not just claims.", estimatedTime: "4–8 weeks",
                whatItAccomplishes: "Develop specific, demonstrable skills that set you apart — technical, creative, or analytical.",
                whyItMatters: "Claims about skills are weak. Evidence of skills is strong. Build things, create work, and develop proof.",
                goal: "Develop 2–3 demonstrable skills and create evidence of your abilities.",
                actions: [
                    MilestoneAction(id: "profile-3-action-1", title: "Choose skills to develop", description: "Pick 2–3 skills that align with your interests and goals — coding, design, writing, research, or analysis.", order: 1),
                    MilestoneAction(id: "profile-3-action-2", title: "Learn through projects", description: "Build projects that demonstrate each skill. A project is stronger evidence than a certificate.", order: 2),
                    MilestoneAction(id: "profile-3-action-3", title: "Get certified or recognized", description: "Pursue certifications, competition results, or teacher recognition for your skills.", order: 3),
                    MilestoneAction(id: "profile-3-action-4", title: "Document your skills", description: "Create a skills inventory with evidence: projects, certificates, grades, or recommendations.", order: 4),
                ],
                skillsDeveloped: ["Technical Skills", "Building Things", "Portfolio Development", "Documentation"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Develop 2–3 demonstrable skills.",
                    "Create evidence of each skill.",
                    "Document your skills inventory.",
                ],
                dependencies: ["profile-2"],
                learningResources: [
                    MilestoneResource(id: "pr3-res-1", title: "freeCodeCamp", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/", type: .course, description: "Free certifications in web development and programming.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "pr3-res-2", title: "Coursera: Free Courses", provider: "Coursera", url: "https://www.coursera.org/courses", type: .course, description: "Free courses from top universities on many topics.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "profile-4", title: "Create Meaningful Experiences", subtitle: "Build a record of activities that demonstrate your character.", estimatedTime: "Ongoing",
                whatItAccomplishes: "Participate in meaningful activities that show leadership, initiative, and commitment.",
                whyItMatters: "Activities show who you are beyond grades. They demonstrate passion, leadership, and contribution to your community.",
                goal: "Participate meaningfully in 2–3 activities and take on leadership roles where possible.",
                actions: [
                    MilestoneAction(id: "profile-4-action-1", title: "Choose activities that align with your interests", description: "Pick 2–3 activities that connect to your interests and goals. Commit deeply rather than spreading thin.", order: 1),
                    MilestoneAction(id: "profile-4-action-2", title: "Take on leadership roles", description: "Look for ways to lead, organize, or create within your activities. Start something if nothing exists.", order: 2),
                    MilestoneAction(id: "profile-4-action-3", title: "Document your experiences", description: "Keep a record of what you do, your roles, hours, and what you learn. This is invaluable for applications.", order: 3),
                    MilestoneAction(id: "profile-4-action-4", title: "Seek summer experiences", description: "Apply for summer programs, internships, camps, or jobs that develop your skills and interests.", order: 4),
                ],
                skillsDeveloped: ["Leadership", "Time Management", "Communication", "Planning"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Participate in 2–3 meaningful activities.",
                    "Take on a leadership role in at least one.",
                    "Document all experiences.",
                ],
                dependencies: ["profile-3"],
                learningResources: [
                    MilestoneResource(id: "pr4-res-1", title: "College Board: Activities", provider: "College Board", url: "https://bigfuture.collegeboard.org/plan-for-college/activities", type: .documentation, description: "Guidance on choosing meaningful extracurricular activities.", estimatedTime: "10 min"),
                    MilestoneResource(id: "pr4-res-2", title: "CoolWorks: Summer Jobs", provider: "CoolWorks", url: "https://www.coolworks.com/", type: .interactive, description: "Find meaningful summer experiences.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "profile-5", title: "Build Leadership & Impact", subtitle: "Demonstrate that you can lead and create positive change.", estimatedTime: "4–8 weeks",
                whatItAccomplishes: "Lead projects or initiatives that create measurable impact in your school or community.",
                whyItMatters: "Leadership and impact are what separate good students from exceptional ones. They show you can do more than follow instructions.",
                goal: "Lead at least one initiative that creates a measurable positive outcome.",
                actions: [
                    MilestoneAction(id: "profile-5-action-1", title: "Identify a leadership opportunity", description: "Find a problem in your school or community that you can address. It could be a club, event, service project, or campaign.", order: 1),
                    MilestoneAction(id: "profile-5-action-2", title: "Plan and organize", description: "Create a detailed plan with goals, timeline, team, and resources. Present it to an authority figure for support.", order: 2),
                    MilestoneAction(id: "profile-5-action-3", title: "Execute and measure", description: "Run the initiative, track your progress against goals, and document the results.", order: 3),
                    MilestoneAction(id: "profile-5-action-4", title: "Reflect and report", description: "Write about what you accomplished, what you learned, and how you grew as a leader.", order: 4),
                ],
                skillsDeveloped: ["Leadership", "Project Management", "Impact Measurement", "Communication"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Lead an initiative from planning to completion.",
                    "Measure and document your impact.",
                    "Reflect on your growth as a leader.",
                ],
                dependencies: ["profile-4"],
                learningResources: [
                    MilestoneResource(id: "pr5-res-1", title: "DoSomething.org", provider: "Do Something", url: "https://www.dosomething.org/", type: .interactive, description: "Find opportunities for community impact.", estimatedTime: "15 min"),
                ]
            ),
            .init(
                id: "profile-6", title: "Document Your Achievements", subtitle: "Organize everything into a compelling narrative.", estimatedTime: "2–3 weeks",
                whatItAccomplishes: "Create a complete record of your achievements that tells a clear, compelling story about who you are.",
                whyItMatters: "Undocumented achievements are invisible. Organizing your work into a clear narrative makes your profile powerful.",
                goal: "Create a complete achievements portfolio with activities, skills, leadership, and personal statement.",
                actions: [
                    MilestoneAction(id: "profile-6-action-1", title: "Compile your activities list", description: "Create a comprehensive list of all activities, roles, dates, and impact. Quantify where possible.", order: 1),
                    MilestoneAction(id: "profile-6-action-2", title: "Write your personal statement", description: "Write a compelling personal statement that ties your experiences together into a clear narrative.", order: 2),
                    MilestoneAction(id: "profile-6-action-3", title: "Prepare recommendations", description: "Identify 2–3 recommenders. Ask them early and provide them with information about your achievements.", order: 3),
                    MilestoneAction(id: "profile-6-action-4", title: "Build a resume", description: "Create a clean, professional resume that includes education, activities, skills, and achievements.", order: 4),
                ],
                skillsDeveloped: ["Writing", "Organization", "Communication", "Self-Advocacy"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Have a complete activities list.",
                    "Write a compelling personal statement.",
                    "Prepare recommenders and resume.",
                ],
                dependencies: ["profile-5"],
                learningResources: [
                    MilestoneResource(id: "pr6-res-1", title: "Khan Academy: College Essays", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more/college-admissions/applying-to-college", type: .interactive, description: "Free guidance on writing effective application essays.", estimatedTime: "Self-paced"),
                    MilestoneResource(id: "pr6-res-2", title: "Purdue OWL: Writing Lab", provider: "Purdue University", url: "https://owl.purdue.edu/", type: .documentation, description: "Free writing resources for clear, effective communication.", estimatedTime: "Self-paced"),
                ]
            ),
            .init(
                id: "profile-7", title: "Build a Strong Student Portfolio", subtitle: "Create a polished presentation of your complete profile.", estimatedTime: "1–2 weeks",
                whatItAccomplishes: "Create a comprehensive, polished portfolio that presents your complete student profile.",
                whyItMatters: "A complete portfolio lets you see your full picture and share it easily. It turns scattered achievements into a powerful story.",
                goal: "Have a complete, polished portfolio website or document that presents your full profile.",
                actions: [
                    MilestoneAction(id: "profile-7-action-1", title: "Choose a portfolio format", description: "Decide whether to create a website, a PDF portfolio, or a Google Doc. Consider what your audience expects.", order: 1),
                    MilestoneAction(id: "profile-7-action-2", title: "Assemble your portfolio", description: "Include: personal statement, activities, skills, achievements, leadership, projects, and recommendations.", order: 2),
                    MilestoneAction(id: "profile-7-action-3", title: "Polish and review", description: "Review every section for clarity, accuracy, and impact. Fix any inconsistencies or gaps.", order: 3),
                    MilestoneAction(id: "profile-7-action-4", title: "Get feedback", description: "Show your portfolio to a teacher, counselor, or mentor. Ask for honest feedback and make improvements.", order: 4),
                ],
                skillsDeveloped: ["Portfolio Development", "Personal Branding", "Technical Communication", "Writing"],
                completionCriteria: [
                    "Complete all four actions.",
                    "Have a complete portfolio with all sections.",
                    "Portfolio is polished and error-free.",
                    "Get feedback and make improvements.",
                ],
                dependencies: ["profile-6"],
                learningResources: [
                    MilestoneResource(id: "pr7-res-1", title: "GitHub Pages", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: .documentation, description: "Create a free portfolio website.", estimatedTime: "15 min"),
                    MilestoneResource(id: "pr7-res-2", title: "Google Sites", provider: "Google", url: "https://sites.google.com/", type: .interactive, description: "Free tool for creating simple portfolio websites.", estimatedTime: "Self-paced"),
                ]
            ),
        ], relevantInterests: ["Technology", "Engineering", "Medicine", "Business", "Arts", "Science"], relevantSkills: ["Programming", "Research", "Writing", "Leadership", "Communication"], relevantCareers: ["Software Engineer", "Doctor", "Lawyer", "Business Manager"], relevantFields: ["Computer Science", "Engineering", "Medicine", "Business", "Arts"], eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth], collegeFocused: true)
    ]
}
