// Match.swift
// FOOT2026
// 2026 tournament fixture data – source: public schedules

import Foundation

// MARK: - Enums

enum Group: String, CaseIterable, Codable {
    case A, B, C, D, E, F, G, H, I, J, K, L
}

enum Stage: String, Codable, CaseIterable {
    case groupStage   = "group"
    case roundOf32    = "r32"
    case roundOf16    = "r16"
    case quarterFinal = "qf"
    case semiFinal    = "sf"
    case thirdPlace   = "3rd"
    case final_       = "final"

    var localizedName: String {
        let fr = Locale.current.language.languageCode?.identifier == "fr"
        switch self {
        case .groupStage:   return fr ? "Phase de groupes"       : "Group Stage"
        case .roundOf32:    return fr ? "Seizièmes de finale"    : "Round of 32"
        case .roundOf16:    return fr ? "Huitièmes de finale"    : "Round of 16"
        case .quarterFinal: return fr ? "Quarts de finale"       : "Quarterfinals"
        case .semiFinal:    return fr ? "Demi-finales"           : "Semifinals"
        case .thirdPlace:   return fr ? "3e place"               : "3rd Place"
        case .final_:       return fr ? "Finale"                 : "Final"
        }
    }
}

// MARK: - Goal Scorer

struct GoalScorer: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var team: String
    var flag: String
    var goals: Int   // goals scored in this match (penalty-shootout conversions included)
    var isOwnGoal: Bool = false   // true if these goals are own goals (csc)
    var shootoutGoals: Int = 0    // subset of `goals` converted in the penalty shootout (t.a.b.)

    init(id: UUID = UUID(), name: String, team: String, flag: String,
         goals: Int, isOwnGoal: Bool = false, shootoutGoals: Int = 0) {
        self.id = id
        self.name = name
        self.team = team
        self.flag = flag
        self.goals = goals
        self.isOwnGoal = isOwnGoal
        self.shootoutGoals = shootoutGoals
    }

    // Custom decoding so scores saved before `shootoutGoals` existed still load
    // (the synthesized decoder would throw on the missing key, wiping every score).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        team = try c.decode(String.self, forKey: .team)
        flag = try c.decode(String.self, forKey: .flag)
        goals = try c.decode(Int.self, forKey: .goals)
        isOwnGoal = try c.decodeIfPresent(Bool.self, forKey: .isOwnGoal) ?? false
        shootoutGoals = try c.decodeIfPresent(Int.self, forKey: .shootoutGoals) ?? 0
    }
}

// MARK: - Lineup Data

struct LineupPlayer: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var number: Int?
    var position: String?
}

struct LineupData: Codable, Equatable {
    var homeStarting: [LineupPlayer] = []
    var homeBench:    [LineupPlayer] = []
    var homeCoach:    String         = ""
    var awayStarting: [LineupPlayer] = []
    var awayBench:    [LineupPlayer] = []
    var awayCoach:    String         = ""

    var isEmpty: Bool {
        homeStarting.isEmpty && awayStarting.isEmpty
    }
}

// MARK: - Match Model

struct Match: Identifiable, Codable {
    let id: UUID
    var homeTeam: String
    var awayTeam: String
    var homeFlag: String
    var awayFlag: String
    var date: Date
    var venue: String
    var city: String
    var stage: Stage
    var group: Group?
    var homeScore: Int?
    var awayScore: Int?
    /// Penalty-shootout score, only set for a knockout match level after extra time.
    var homePenalties: Int? = nil
    var awayPenalties: Int? = nil
    var homeScorers: [GoalScorer] = []
    var awayScorers: [GoalScorer] = []
    var matchLink: String? = nil
    var sofascoreLink: String? = nil
    var lineup: LineupData? = nil
    /// User-edited broadcaster list. `nil` means "use the default schedule" (see `broadcasters`).
    var customBroadcasters: [String]? = nil
    /// User-corrected kickoff date/time. `nil` means "use the official calendar" (`date`).
    /// When set, it is applied onto `date` at load time so the whole app (sorting,
    /// display, notifications) follows the corrected time.
    var customDate: Date? = nil

    /// True when the user has overridden the official kickoff date/time.
    var isDateCustomized: Bool { customDate != nil }

    /// Official (calendar) kickoff time for this match, ignoring any user correction.
    var defaultDate: Date {
        Match.allMatches.first { $0.id == id }?.date ?? date
    }

    var hasScore: Bool { homeScore != nil && awayScore != nil }

    /// True when the match went to a penalty shootout (both shootout scores set).
    var hasShootout: Bool { homePenalties != nil && awayPenalties != nil }

    enum WinnerSide { case home, away }

    /// The winning side, breaking a draw after extra time with the shootout score.
    /// `nil` while the match is unplayed or level with no shootout recorded.
    var winnerSide: WinnerSide? {
        guard let h = homeScore, let a = awayScore else { return nil }
        if h > a { return .home }
        if a > h { return .away }
        if let ph = homePenalties, let pa = awayPenalties {
            if ph > pa { return .home }
            if pa > ph { return .away }
        }
        return nil
    }

    /// "1 - 1 (t.a.b. 4 - 3)" when a shootout decided the match, else "1 - 1".
    var scoreTextWithShootout: String {
        guard hasShootout, let ph = homePenalties, let pa = awayPenalties else { return scoreText }
        return "\(scoreText) (t.a.b. \(ph) - \(pa))"
    }

    /// True once both teams are determined (group stage, or a knockout match whose
    /// participants are known). Placeholder fixtures use the 🏳️ flag.
    var teamsAreDetermined: Bool {
        homeFlag != "🏳️" && awayFlag != "🏳️"
    }

    /// Google search URL that opens Google's live match panel (score, scorers).
    /// Built from the team names — no manual paste needed.
    var googleLiveURL: URL? {
        guard teamsAreDetermined else { return nil }
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "\(homeTeam) \(awayTeam) score")]
        return components?.url
    }

    var scoreText: String {
        guard let h = homeScore, let a = awayScore else { return "-" }
        return "\(h) - \(a)"
    }

    /// Broadcasters shown for this match. Returns the user-edited list when set,
    /// otherwise the default French TV schedule (`defaultBroadcasters`).
    var broadcasters: [String] {
        customBroadcasters ?? defaultBroadcasters
    }

    /// Default French broadcasters for this match.
    /// - beIN Sports broadcasts all 104 matches (pay TV).
    /// - M6 broadcasts 54 selected matches free-to-air (source: official schedule, "+" marker).
    var defaultBroadcasters: [String] {
        var result: [String] = []
        if let n = matchNumber, Match.m6MatchNumbers.contains(n) {
            result.append("M6")
        }
        result.append("beIN Sports")
        return result
    }

    /// Deterministic match number (1–104) extracted from the UUID generated by mID().
    private var matchNumber: Int? {
        let s = id.uuidString
        guard s.hasPrefix("00000000-0000-4000-8000-") else { return nil }
        return Int(s.suffix(12))
    }

    /// Exhaustive set of match numbers broadcast on M6 (free-to-air).
    /// Source: official 2026 tournament calendar – "+" marker.
    private static let m6MatchNumbers: Set<Int> = [
        // ── Phase de groupes ──
        1,  // Mexique - Afrique du Sud (match d'ouverture)
        3,  // Canada - Bosnie-Herzégovine
        7,  // Brésil - Maroc
        8,  // Qatar - Suisse
        10, // Allemagne - Curaçao
        11, // Pays-Bas - Japon
        13, // Arabie Saoudite - Uruguay
        14, // Espagne - Cap-Vert
        16, // Belgique - Égypte
        17, // France - Sénégal
        18, // Irak - Norvège
        22, // Angleterre - Croatie
        23, // Portugal - RD Congo
        25, // Tchéquie - Afrique du Sud
        26, // Suisse - Bosnie-Herzégovine
        29, // Brésil - Haïti
        30, // Écosse - Maroc
        32, // États-Unis - Australie
        33, // Allemagne - Côte d'Ivoire
        35, // Pays-Bas - Suède
        38, // Espagne - Arabie Saoudite
        39, // Belgique - Iran
        42, // France - Irak
        43, // Argentine - Autriche
        45, // Angleterre - Ghana
        47, // Portugal - Ouzbékistan
        51, // Suisse - Canada
        56, // Équateur - Allemagne
        58, // Tunisie - Pays-Bas
        61, // Norvège - France
        66, // Uruguay - Espagne
        67, // Panama - Angleterre
        71, // Colombie - Portugal
        // ── Seizièmes de finale ──
        73, // 2e Gr.A - 2e Gr.B
        74, // 1er Gr.E - 3e (A/B/C/D/F)
        76, // 1er Gr.C - 2e Gr.F
        77, // 1er Gr.I - 3e (C/D/F/G/H)
        78, // 2e Gr.E - 2e Gr.I
        80, // 1er Gr.L - 3e (E/H/I/J/K)
        82, // 1er Gr.G - 3e (A/E/H/I/J)
        84, // 1er Gr.H - 2e Gr.J
        88, // 2e Gr.D - 2e Gr.G
        // ── Huitièmes de finale ──
        89, 90, 91, 93, 95, 96,
        // ── Quarts de finale ──
        97, 98, 99,
        // ── Demi-finales ──
        101, 102,
        // ── 3e place + Finale ──
        103, 104
    ]

    var parisDate: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateStyle = .full
        fmt.timeStyle = .none
        fmt.timeZone = TimeZone(identifier: "Europe/Paris")
        return fmt.string(from: date).capitalized
    }

    var parisTime: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "Europe/Paris")
        return fmt.string(from: date)
    }
}

// MARK: - Fixture Data (source: public schedules)

extension Match {

    /// Build a Date from Paris local time (CEST = UTC+2 in summer)
    private static func parisDate(day: Int, month: Int, year: Int,
                                  hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute
        c.timeZone = TimeZone(identifier: "Europe/Paris")
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }

    /// Deterministic UUID from match number (preserves score persistence)
    private static func mID(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", n))!
    }

    static let allMatches: [Match] = [

        // ── GROUPE A : Mexique · Afrique du Sud · Corée du Sud · Tchéquie ──
        Match(id:mID(1),  homeTeam:"Mexique",        awayTeam:"Afrique du Sud", homeFlag:"🇲🇽", awayFlag:"🇿🇦",
              date:parisDate(day:11,month:6,year:2026,hour:21,minute:0),
              venue:"Estadio Azteca",         city:"Mexico City",    stage:.groupStage, group:.A),
        Match(id:mID(2),  homeTeam:"Corée du Sud",   awayTeam:"Tchéquie",       homeFlag:"🇰🇷", awayFlag:"🇨🇿",
              date:parisDate(day:12,month:6,year:2026,hour:4,minute:0),
              venue:"Estadio Akron",          city:"Zapopan",        stage:.groupStage, group:.A),
        Match(id:mID(25), homeTeam:"Tchéquie",        awayTeam:"Afrique du Sud", homeFlag:"🇨🇿", awayFlag:"🇿🇦",
              date:parisDate(day:18,month:6,year:2026,hour:18,minute:0),
              venue:"Mercedes-Benz Stadium",  city:"Atlanta",        stage:.groupStage, group:.A),
        Match(id:mID(28), homeTeam:"Mexique",         awayTeam:"Corée du Sud",   homeFlag:"🇲🇽", awayFlag:"🇰🇷",
              date:parisDate(day:19,month:6,year:2026,hour:3,minute:0),
              venue:"Estadio Akron",          city:"Zapopan",        stage:.groupStage, group:.A),
        Match(id:mID(53), homeTeam:"Tchéquie",        awayTeam:"Mexique",        homeFlag:"🇨🇿", awayFlag:"🇲🇽",
              date:parisDate(day:25,month:6,year:2026,hour:3,minute:0),
              venue:"Estadio Azteca",         city:"Mexico City",    stage:.groupStage, group:.A),
        Match(id:mID(54), homeTeam:"Afrique du Sud",  awayTeam:"Corée du Sud",   homeFlag:"🇿🇦", awayFlag:"🇰🇷",
              date:parisDate(day:25,month:6,year:2026,hour:3,minute:0),
              venue:"Estadio BBVA",           city:"Guadalupe",      stage:.groupStage, group:.A),

        // ── GROUPE B : Canada · Bosnie-Herzégovine · Qatar · Suisse ──
        Match(id:mID(3),  homeTeam:"Canada",           awayTeam:"Bosnie-Herzégovine", homeFlag:"🇨🇦", awayFlag:"🇧🇦",
              date:parisDate(day:12,month:6,year:2026,hour:21,minute:0),
              venue:"BMO Field",              city:"Toronto",        stage:.groupStage, group:.B),
        Match(id:mID(8),  homeTeam:"Qatar",             awayTeam:"Suisse",             homeFlag:"🇶🇦", awayFlag:"🇨🇭",
              date:parisDate(day:13,month:6,year:2026,hour:21,minute:0),
              venue:"Levi's Stadium",         city:"Santa Clara",    stage:.groupStage, group:.B),
        Match(id:mID(26), homeTeam:"Suisse",             awayTeam:"Bosnie-Herzégovine", homeFlag:"🇨🇭", awayFlag:"🇧🇦",
              date:parisDate(day:18,month:6,year:2026,hour:21,minute:0),
              venue:"SoFi Stadium",           city:"Inglewood",      stage:.groupStage, group:.B),
        Match(id:mID(27), homeTeam:"Canada",             awayTeam:"Qatar",              homeFlag:"🇨🇦", awayFlag:"🇶🇦",
              date:parisDate(day:19,month:6,year:2026,hour:0,minute:0),
              venue:"BC Place",               city:"Vancouver",      stage:.groupStage, group:.B),
        Match(id:mID(51), homeTeam:"Suisse",             awayTeam:"Canada",             homeFlag:"🇨🇭", awayFlag:"🇨🇦",
              date:parisDate(day:24,month:6,year:2026,hour:21,minute:0),
              venue:"BC Place",               city:"Vancouver",      stage:.groupStage, group:.B),
        Match(id:mID(52), homeTeam:"Bosnie-Herzégovine", awayTeam:"Qatar",              homeFlag:"🇧🇦", awayFlag:"🇶🇦",
              date:parisDate(day:24,month:6,year:2026,hour:21,minute:0),
              venue:"Lumen Field",            city:"Seattle",        stage:.groupStage, group:.B),

        // ── GROUPE C : Brésil · Maroc · Haïti · Écosse ──
        Match(id:mID(7),  homeTeam:"Brésil",  awayTeam:"Maroc",  homeFlag:"🇧🇷", awayFlag:"🇲🇦",
              date:parisDate(day:14,month:6,year:2026,hour:0,minute:0),
              venue:"MetLife Stadium",        city:"East Rutherford", stage:.groupStage, group:.C),
        Match(id:mID(5),  homeTeam:"Haïti",   awayTeam:"Écosse", homeFlag:"🇭🇹", awayFlag:"🏴󠁧󠁢󠁳󠁣󠁴󠁿",
              date:parisDate(day:14,month:6,year:2026,hour:3,minute:0),
              venue:"Gillette Stadium",       city:"Foxborough",    stage:.groupStage, group:.C),
        Match(id:mID(30), homeTeam:"Écosse",  awayTeam:"Maroc",  homeFlag:"🏴󠁧󠁢󠁳󠁣󠁴󠁿", awayFlag:"🇲🇦",
              date:parisDate(day:20,month:6,year:2026,hour:0,minute:0),
              venue:"Gillette Stadium",       city:"Foxborough",    stage:.groupStage, group:.C),
        Match(id:mID(29), homeTeam:"Brésil",  awayTeam:"Haïti",  homeFlag:"🇧🇷", awayFlag:"🇭🇹",
              date:parisDate(day:20,month:6,year:2026,hour:2,minute:30),
              venue:"Lincoln Financial Field",city:"Philadelphie",  stage:.groupStage, group:.C),
        Match(id:mID(49), homeTeam:"Écosse",  awayTeam:"Brésil", homeFlag:"🏴󠁧󠁢󠁳󠁣󠁴󠁿", awayFlag:"🇧🇷",
              date:parisDate(day:25,month:6,year:2026,hour:0,minute:0),
              venue:"Hard Rock Stadium",      city:"Miami Gardens", stage:.groupStage, group:.C),
        Match(id:mID(50), homeTeam:"Maroc",   awayTeam:"Haïti",  homeFlag:"🇲🇦", awayFlag:"🇭🇹",
              date:parisDate(day:25,month:6,year:2026,hour:0,minute:0),
              venue:"Mercedes-Benz Stadium",  city:"Atlanta",       stage:.groupStage, group:.C),

        // ── GROUPE D : États-Unis · Paraguay · Australie · Turquie ──
        Match(id:mID(4),  homeTeam:"États-Unis", awayTeam:"Paraguay",  homeFlag:"🇺🇸", awayFlag:"🇵🇾",
              date:parisDate(day:13,month:6,year:2026,hour:3,minute:0),
              venue:"SoFi Stadium",           city:"Inglewood",     stage:.groupStage, group:.D),
        Match(id:mID(6),  homeTeam:"Australie",  awayTeam:"Turquie",   homeFlag:"🇦🇺", awayFlag:"🇹🇷",
              date:parisDate(day:14,month:6,year:2026,hour:6,minute:0),
              venue:"BC Place",               city:"Vancouver",     stage:.groupStage, group:.D),
        Match(id:mID(32), homeTeam:"États-Unis", awayTeam:"Australie", homeFlag:"🇺🇸", awayFlag:"🇦🇺",
              date:parisDate(day:19,month:6,year:2026,hour:21,minute:0),
              venue:"Lumen Field",            city:"Seattle",       stage:.groupStage, group:.D),
        Match(id:mID(31), homeTeam:"Turquie",    awayTeam:"Paraguay",  homeFlag:"🇹🇷", awayFlag:"🇵🇾",
              date:parisDate(day:20,month:6,year:2026,hour:5,minute:0),
              venue:"Levi's Stadium",         city:"Santa Clara",   stage:.groupStage, group:.D),
        Match(id:mID(59), homeTeam:"Turquie",    awayTeam:"États-Unis",homeFlag:"🇹🇷", awayFlag:"🇺🇸",
              date:parisDate(day:26,month:6,year:2026,hour:4,minute:0),
              venue:"SoFi Stadium",           city:"Inglewood",     stage:.groupStage, group:.D),
        Match(id:mID(60), homeTeam:"Paraguay",   awayTeam:"Australie", homeFlag:"🇵🇾", awayFlag:"🇦🇺",
              date:parisDate(day:26,month:6,year:2026,hour:4,minute:0),
              venue:"Levi's Stadium",         city:"Santa Clara",   stage:.groupStage, group:.D),

        // ── GROUPE E : Allemagne · Curaçao · Côte d'Ivoire · Équateur ──
        Match(id:mID(10), homeTeam:"Allemagne",     awayTeam:"Curaçao",        homeFlag:"🇩🇪", awayFlag:"🇨🇼",
              date:parisDate(day:14,month:6,year:2026,hour:19,minute:0),
              venue:"NRG Stadium",            city:"Houston",       stage:.groupStage, group:.E),
        Match(id:mID(9),  homeTeam:"Côte d'Ivoire", awayTeam:"Équateur",       homeFlag:"🇨🇮", awayFlag:"🇪🇨",
              date:parisDate(day:15,month:6,year:2026,hour:1,minute:0),
              venue:"Lincoln Financial Field",city:"Philadelphie",  stage:.groupStage, group:.E),
        Match(id:mID(33), homeTeam:"Allemagne",     awayTeam:"Côte d'Ivoire",  homeFlag:"🇩🇪", awayFlag:"🇨🇮",
              date:parisDate(day:20,month:6,year:2026,hour:22,minute:0),
              venue:"BMO Field",              city:"Toronto",       stage:.groupStage, group:.E),
        Match(id:mID(34), homeTeam:"Équateur",      awayTeam:"Curaçao",        homeFlag:"🇪🇨", awayFlag:"🇨🇼",
              date:parisDate(day:21,month:6,year:2026,hour:2,minute:0),
              venue:"Arrowhead Stadium",      city:"Kansas City",   stage:.groupStage, group:.E),
        Match(id:mID(55), homeTeam:"Curaçao",       awayTeam:"Côte d'Ivoire",  homeFlag:"🇨🇼", awayFlag:"🇨🇮",
              date:parisDate(day:25,month:6,year:2026,hour:22,minute:0),
              venue:"Lincoln Financial Field",city:"Philadelphie",  stage:.groupStage, group:.E),
        Match(id:mID(56), homeTeam:"Équateur",      awayTeam:"Allemagne",      homeFlag:"🇪🇨", awayFlag:"🇩🇪",
              date:parisDate(day:25,month:6,year:2026,hour:22,minute:0),
              venue:"MetLife Stadium",        city:"East Rutherford",stage:.groupStage, group:.E),

        // ── GROUPE F : Pays-Bas · Japon · Suède · Tunisie ──
        Match(id:mID(11), homeTeam:"Pays-Bas", awayTeam:"Japon",   homeFlag:"🇳🇱", awayFlag:"🇯🇵",
              date:parisDate(day:14,month:6,year:2026,hour:22,minute:0),
              venue:"AT&T Stadium",           city:"Arlington",     stage:.groupStage, group:.F),
        Match(id:mID(12), homeTeam:"Suède",    awayTeam:"Tunisie", homeFlag:"🇸🇪", awayFlag:"🇹🇳",
              date:parisDate(day:15,month:6,year:2026,hour:4,minute:0),
              venue:"Estadio BBVA",           city:"Guadalupe",     stage:.groupStage, group:.F),
        Match(id:mID(35), homeTeam:"Pays-Bas", awayTeam:"Suède",   homeFlag:"🇳🇱", awayFlag:"🇸🇪",
              date:parisDate(day:20,month:6,year:2026,hour:19,minute:0),
              venue:"NRG Stadium",            city:"Houston",       stage:.groupStage, group:.F),
        Match(id:mID(36), homeTeam:"Tunisie",  awayTeam:"Japon",   homeFlag:"🇹🇳", awayFlag:"🇯🇵",
              date:parisDate(day:21,month:6,year:2026,hour:6,minute:0),
              venue:"Estadio BBVA",           city:"Guadalupe",     stage:.groupStage, group:.F),
        Match(id:mID(57), homeTeam:"Japon",    awayTeam:"Suède",   homeFlag:"🇯🇵", awayFlag:"🇸🇪",
              date:parisDate(day:26,month:6,year:2026,hour:1,minute:0),
              venue:"AT&T Stadium",           city:"Arlington",     stage:.groupStage, group:.F),
        Match(id:mID(58), homeTeam:"Tunisie",  awayTeam:"Pays-Bas",homeFlag:"🇹🇳", awayFlag:"🇳🇱",
              date:parisDate(day:26,month:6,year:2026,hour:1,minute:0),
              venue:"Arrowhead Stadium",      city:"Kansas City",   stage:.groupStage, group:.F),

        // ── GROUPE G : Belgique · Égypte · Iran · Nouvelle-Zélande ──
        Match(id:mID(16), homeTeam:"Belgique",         awayTeam:"Égypte",          homeFlag:"🇧🇪", awayFlag:"🇪🇬",
              date:parisDate(day:15,month:6,year:2026,hour:21,minute:0),
              venue:"Lumen Field",            city:"Seattle",       stage:.groupStage, group:.G),
        Match(id:mID(15), homeTeam:"Iran",              awayTeam:"Nouvelle-Zélande",homeFlag:"🇮🇷", awayFlag:"🇳🇿",
              date:parisDate(day:16,month:6,year:2026,hour:3,minute:0),
              venue:"SoFi Stadium",           city:"Inglewood",     stage:.groupStage, group:.G),
        Match(id:mID(39), homeTeam:"Belgique",          awayTeam:"Iran",            homeFlag:"🇧🇪", awayFlag:"🇮🇷",
              date:parisDate(day:21,month:6,year:2026,hour:21,minute:0),
              venue:"SoFi Stadium",           city:"Inglewood",     stage:.groupStage, group:.G),
        Match(id:mID(40), homeTeam:"Nouvelle-Zélande",  awayTeam:"Égypte",          homeFlag:"🇳🇿", awayFlag:"🇪🇬",
              date:parisDate(day:22,month:6,year:2026,hour:3,minute:0),
              venue:"BC Place",               city:"Vancouver",     stage:.groupStage, group:.G),
        Match(id:mID(63), homeTeam:"Égypte",            awayTeam:"Iran",            homeFlag:"🇪🇬", awayFlag:"🇮🇷",
              date:parisDate(day:27,month:6,year:2026,hour:5,minute:0),
              venue:"BC Place",               city:"Vancouver",     stage:.groupStage, group:.G),
        Match(id:mID(64), homeTeam:"Nouvelle-Zélande",  awayTeam:"Belgique",        homeFlag:"🇳🇿", awayFlag:"🇧🇪",
              date:parisDate(day:27,month:6,year:2026,hour:5,minute:0),
              venue:"Lumen Field",            city:"Seattle",       stage:.groupStage, group:.G),

        // ── GROUPE H : Espagne · Cap-Vert · Arabie Saoudite · Uruguay ──
        Match(id:mID(14), homeTeam:"Espagne",         awayTeam:"Cap-Vert",        homeFlag:"🇪🇸", awayFlag:"🇨🇻",
              date:parisDate(day:15,month:6,year:2026,hour:18,minute:0),
              venue:"Mercedes-Benz Stadium",  city:"Atlanta",       stage:.groupStage, group:.H),
        Match(id:mID(13), homeTeam:"Arabie Saoudite", awayTeam:"Uruguay",          homeFlag:"🇸🇦", awayFlag:"🇺🇾",
              date:parisDate(day:16,month:6,year:2026,hour:0,minute:0),
              venue:"Hard Rock Stadium",      city:"Miami Gardens", stage:.groupStage, group:.H),
        Match(id:mID(38), homeTeam:"Espagne",         awayTeam:"Arabie Saoudite",  homeFlag:"🇪🇸", awayFlag:"🇸🇦",
              date:parisDate(day:21,month:6,year:2026,hour:18,minute:0),
              venue:"Mercedes-Benz Stadium",  city:"Atlanta",       stage:.groupStage, group:.H),
        Match(id:mID(37), homeTeam:"Uruguay",         awayTeam:"Cap-Vert",         homeFlag:"🇺🇾", awayFlag:"🇨🇻",
              date:parisDate(day:22,month:6,year:2026,hour:0,minute:0),
              venue:"Hard Rock Stadium",      city:"Miami Gardens", stage:.groupStage, group:.H),
        Match(id:mID(65), homeTeam:"Cap-Vert",        awayTeam:"Arabie Saoudite",  homeFlag:"🇨🇻", awayFlag:"🇸🇦",
              date:parisDate(day:27,month:6,year:2026,hour:2,minute:0),
              venue:"NRG Stadium",            city:"Houston",       stage:.groupStage, group:.H),
        Match(id:mID(66), homeTeam:"Uruguay",         awayTeam:"Espagne",          homeFlag:"🇺🇾", awayFlag:"🇪🇸",
              date:parisDate(day:27,month:6,year:2026,hour:2,minute:0),
              venue:"Estadio Akron",          city:"Zapopan",       stage:.groupStage, group:.H),

        // ── GROUPE I : France · Sénégal · Irak · Norvège ──
        Match(id:mID(17), homeTeam:"France",  awayTeam:"Sénégal", homeFlag:"🇫🇷", awayFlag:"🇸🇳",
              date:parisDate(day:16,month:6,year:2026,hour:21,minute:0),
              venue:"MetLife Stadium",        city:"East Rutherford",stage:.groupStage, group:.I),
        Match(id:mID(18), homeTeam:"Irak",    awayTeam:"Norvège",  homeFlag:"🇮🇶", awayFlag:"🇳🇴",
              date:parisDate(day:17,month:6,year:2026,hour:0,minute:0),
              venue:"Gillette Stadium",       city:"Foxborough",    stage:.groupStage, group:.I),
        Match(id:mID(42), homeTeam:"France",  awayTeam:"Irak",     homeFlag:"🇫🇷", awayFlag:"🇮🇶",
              date:parisDate(day:22,month:6,year:2026,hour:23,minute:0),
              venue:"Lincoln Financial Field",city:"Philadelphie",  stage:.groupStage, group:.I),
        Match(id:mID(41), homeTeam:"Norvège", awayTeam:"Sénégal",  homeFlag:"🇳🇴", awayFlag:"🇸🇳",
              date:parisDate(day:23,month:6,year:2026,hour:2,minute:0),
              venue:"MetLife Stadium",        city:"East Rutherford",stage:.groupStage, group:.I),
        Match(id:mID(61), homeTeam:"Norvège", awayTeam:"France",   homeFlag:"🇳🇴", awayFlag:"🇫🇷",
              date:parisDate(day:26,month:6,year:2026,hour:21,minute:0),
              venue:"Gillette Stadium",       city:"Foxborough",    stage:.groupStage, group:.I),
        Match(id:mID(62), homeTeam:"Sénégal", awayTeam:"Irak",     homeFlag:"🇸🇳", awayFlag:"🇮🇶",
              date:parisDate(day:26,month:6,year:2026,hour:21,minute:0),
              venue:"BMO Field",              city:"Toronto",       stage:.groupStage, group:.I),

        // ── GROUPE J : Argentine · Algérie · Autriche · Jordanie ──
        Match(id:mID(19), homeTeam:"Argentine", awayTeam:"Algérie",  homeFlag:"🇦🇷", awayFlag:"🇩🇿",
              date:parisDate(day:17,month:6,year:2026,hour:3,minute:0),
              venue:"Arrowhead Stadium",      city:"Kansas City",   stage:.groupStage, group:.J),
        Match(id:mID(20), homeTeam:"Autriche",  awayTeam:"Jordanie", homeFlag:"🇦🇹", awayFlag:"🇯🇴",
              date:parisDate(day:17,month:6,year:2026,hour:6,minute:0),
              venue:"Levi's Stadium",         city:"Santa Clara",   stage:.groupStage, group:.J),
        Match(id:mID(43), homeTeam:"Argentine", awayTeam:"Autriche", homeFlag:"🇦🇷", awayFlag:"🇦🇹",
              date:parisDate(day:22,month:6,year:2026,hour:19,minute:0),
              venue:"AT&T Stadium",           city:"Arlington",     stage:.groupStage, group:.J),
        Match(id:mID(44), homeTeam:"Jordanie",  awayTeam:"Algérie",  homeFlag:"🇯🇴", awayFlag:"🇩🇿",
              date:parisDate(day:23,month:6,year:2026,hour:5,minute:0),
              venue:"Levi's Stadium",         city:"Santa Clara",   stage:.groupStage, group:.J),
        Match(id:mID(69), homeTeam:"Algérie",   awayTeam:"Autriche", homeFlag:"🇩🇿", awayFlag:"🇦🇹",
              date:parisDate(day:28,month:6,year:2026,hour:4,minute:0),
              venue:"Arrowhead Stadium",      city:"Kansas City",   stage:.groupStage, group:.J),
        Match(id:mID(70), homeTeam:"Jordanie",  awayTeam:"Argentine",homeFlag:"🇯🇴", awayFlag:"🇦🇷",
              date:parisDate(day:28,month:6,year:2026,hour:4,minute:0),
              venue:"AT&T Stadium",           city:"Arlington",     stage:.groupStage, group:.J),

        // ── GROUPE K : Portugal · RD Congo · Ouzbékistan · Colombie ──
        Match(id:mID(23), homeTeam:"Portugal",    awayTeam:"RD Congo",     homeFlag:"🇵🇹", awayFlag:"🇨🇩",
              date:parisDate(day:17,month:6,year:2026,hour:19,minute:0),
              venue:"NRG Stadium",            city:"Houston",       stage:.groupStage, group:.K),
        Match(id:mID(24), homeTeam:"Ouzbékistan", awayTeam:"Colombie",     homeFlag:"🇺🇿", awayFlag:"🇨🇴",
              date:parisDate(day:18,month:6,year:2026,hour:4,minute:0),
              venue:"Estadio Azteca",         city:"Mexico City",   stage:.groupStage, group:.K),
        Match(id:mID(47), homeTeam:"Portugal",    awayTeam:"Ouzbékistan",  homeFlag:"🇵🇹", awayFlag:"🇺🇿",
              date:parisDate(day:23,month:6,year:2026,hour:19,minute:0),
              venue:"NRG Stadium",            city:"Houston",       stage:.groupStage, group:.K),
        Match(id:mID(48), homeTeam:"Colombie",    awayTeam:"RD Congo",     homeFlag:"🇨🇴", awayFlag:"🇨🇩",
              date:parisDate(day:24,month:6,year:2026,hour:4,minute:0),
              venue:"Estadio Akron",          city:"Zapopan",       stage:.groupStage, group:.K),
        Match(id:mID(71), homeTeam:"Colombie",    awayTeam:"Portugal",     homeFlag:"🇨🇴", awayFlag:"🇵🇹",
              date:parisDate(day:28,month:6,year:2026,hour:1,minute:30),
              venue:"Hard Rock Stadium",      city:"Miami Gardens", stage:.groupStage, group:.K),
        Match(id:mID(72), homeTeam:"RD Congo",    awayTeam:"Ouzbékistan",  homeFlag:"🇨🇩", awayFlag:"🇺🇿",
              date:parisDate(day:28,month:6,year:2026,hour:1,minute:30),
              venue:"Mercedes-Benz Stadium",  city:"Atlanta",       stage:.groupStage, group:.K),

        // ── GROUPE L : Angleterre · Croatie · Ghana · Panama ──
        Match(id:mID(22), homeTeam:"Angleterre", awayTeam:"Croatie", homeFlag:"🏴󠁧󠁢󠁥󠁮󠁧󠁿", awayFlag:"🇭🇷",
              date:parisDate(day:17,month:6,year:2026,hour:22,minute:0),
              venue:"AT&T Stadium",           city:"Arlington",     stage:.groupStage, group:.L),
        Match(id:mID(21), homeTeam:"Ghana",      awayTeam:"Panama",  homeFlag:"🇬🇭", awayFlag:"🇵🇦",
              date:parisDate(day:18,month:6,year:2026,hour:1,minute:0),
              venue:"BMO Field",              city:"Toronto",       stage:.groupStage, group:.L),
        Match(id:mID(45), homeTeam:"Angleterre", awayTeam:"Ghana",   homeFlag:"🏴󠁧󠁢󠁥󠁮󠁧󠁿", awayFlag:"🇬🇭",
              date:parisDate(day:23,month:6,year:2026,hour:22,minute:0),
              venue:"Gillette Stadium",       city:"Foxborough",    stage:.groupStage, group:.L),
        Match(id:mID(46), homeTeam:"Panama",     awayTeam:"Croatie", homeFlag:"🇵🇦", awayFlag:"🇭🇷",
              date:parisDate(day:24,month:6,year:2026,hour:1,minute:0),
              venue:"BMO Field",              city:"Toronto",       stage:.groupStage, group:.L),
        Match(id:mID(67), homeTeam:"Panama",     awayTeam:"Angleterre",homeFlag:"🇵🇦", awayFlag:"🏴󠁧󠁢󠁥󠁮󠁧󠁿",
              date:parisDate(day:27,month:6,year:2026,hour:23,minute:0),
              venue:"MetLife Stadium",        city:"East Rutherford",stage:.groupStage, group:.L),
        Match(id:mID(68), homeTeam:"Croatie",    awayTeam:"Ghana",   homeFlag:"🇭🇷", awayFlag:"🇬🇭",
              date:parisDate(day:27,month:6,year:2026,hour:23,minute:0),
              venue:"Lincoln Financial Field",city:"Philadelphie",  stage:.groupStage, group:.L),

        // ── SEIZIÈMES DE FINALE ──
        Match(id:mID(73),  homeTeam:"2e Gr.A",         awayTeam:"2e Gr.B",          homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:28,month:6,year:2026,hour:21,minute:0),
              venue:"SoFi Stadium",           city:"Inglewood",     stage:.roundOf32),
        Match(id:mID(76),  homeTeam:"1er Gr.C",        awayTeam:"2e Gr.F",          homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:29,month:6,year:2026,hour:19,minute:0),
              venue:"NRG Stadium",            city:"Houston",       stage:.roundOf32),
        Match(id:mID(74),  homeTeam:"1er Gr.E",        awayTeam:"3e (A/B/C/D/F)",   homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:29,month:6,year:2026,hour:22,minute:30),
              venue:"Gillette Stadium",       city:"Foxborough",    stage:.roundOf32),
        Match(id:mID(75),  homeTeam:"1er Gr.F",        awayTeam:"2e Gr.C",          homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:30,month:6,year:2026,hour:3,minute:0),
              venue:"Estadio BBVA",           city:"Guadalupe",     stage:.roundOf32),
        Match(id:mID(78),  homeTeam:"2e Gr.E",         awayTeam:"2e Gr.I",          homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:30,month:6,year:2026,hour:19,minute:0),
              venue:"AT&T Stadium",           city:"Arlington",     stage:.roundOf32),
        Match(id:mID(77),  homeTeam:"1er Gr.I",        awayTeam:"3e (C/D/F/G/H)",   homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:30,month:6,year:2026,hour:23,minute:0),
              venue:"MetLife Stadium",        city:"East Rutherford",stage:.roundOf32),
        Match(id:mID(79),  homeTeam:"1er Gr.A",        awayTeam:"3e (C/E/F/H/I)",   homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:1,month:7,year:2026,hour:3,minute:0),
              venue:"Estadio Azteca",         city:"Mexico City",   stage:.roundOf32),
        Match(id:mID(80),  homeTeam:"1er Gr.L",        awayTeam:"3e (E/H/I/J/K)",   homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:1,month:7,year:2026,hour:18,minute:0),
              venue:"Mercedes-Benz Stadium",  city:"Atlanta",       stage:.roundOf32),
        Match(id:mID(82),  homeTeam:"1er Gr.G",        awayTeam:"3e (A/E/H/I/J)",   homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:1,month:7,year:2026,hour:22,minute:0),
              venue:"Lumen Field",            city:"Seattle",       stage:.roundOf32),
        Match(id:mID(81),  homeTeam:"1er Gr.D",        awayTeam:"3e (B/E/F/I/J)",   homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:2,month:7,year:2026,hour:0,minute:0),
              venue:"Lumen Field",            city:"Seattle",       stage:.roundOf32),
        Match(id:mID(84),  homeTeam:"1er Gr.H",        awayTeam:"2e Gr.J",          homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:2,month:7,year:2026,hour:21,minute:0),
              venue:"SoFi Stadium",           city:"Inglewood",     stage:.roundOf32),
        Match(id:mID(83),  homeTeam:"2e Gr.K",         awayTeam:"2e Gr.L",          homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:3,month:7,year:2026,hour:1,minute:0),
              venue:"BMO Field",              city:"Toronto",       stage:.roundOf32),
        Match(id:mID(85),  homeTeam:"1er Gr.B",        awayTeam:"3e (E/F/G/I/J)",   homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:3,month:7,year:2026,hour:3,minute:0),
              venue:"BC Place",               city:"Vancouver",     stage:.roundOf32),
        Match(id:mID(88),  homeTeam:"2e Gr.D",         awayTeam:"2e Gr.G",          homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:3,month:7,year:2026,hour:19,minute:0),
              venue:"BC Place",               city:"Vancouver",     stage:.roundOf32),
        Match(id:mID(86),  homeTeam:"1er Gr.J",        awayTeam:"2e Gr.H",          homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:4,month:7,year:2026,hour:0,minute:0),
              venue:"Hard Rock Stadium",      city:"Miami Gardens", stage:.roundOf32),
        Match(id:mID(87),  homeTeam:"1er Gr.K",        awayTeam:"3e (D/E/I/J/L)",   homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:4,month:7,year:2026,hour:2,minute:30),
              venue:"AT&T Stadium",           city:"Arlington",     stage:.roundOf32),

        // ── HUITIÈMES DE FINALE ──
        Match(id:mID(90),  homeTeam:"V.M73", awayTeam:"V.M75", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:4,month:7,year:2026,hour:19,minute:0),
              venue:"NRG Stadium",            city:"Houston",       stage:.roundOf16),
        Match(id:mID(89),  homeTeam:"V.M74", awayTeam:"V.M77", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:4,month:7,year:2026,hour:23,minute:0),
              venue:"Lincoln Financial Field",city:"Philadelphie",  stage:.roundOf16),
        Match(id:mID(91),  homeTeam:"V.M76", awayTeam:"V.M78", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:5,month:7,year:2026,hour:22,minute:0),
              venue:"Lincoln Financial Field",city:"Philadelphie",  stage:.roundOf16),
        Match(id:mID(92),  homeTeam:"V.M79", awayTeam:"V.M80", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:6,month:7,year:2026,hour:2,minute:0),
              venue:"Estadio Azteca",         city:"Mexico City",   stage:.roundOf16),
        Match(id:mID(93),  homeTeam:"V.M83", awayTeam:"V.M84", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:6,month:7,year:2026,hour:20,minute:0),
              venue:"AT&T Stadium",           city:"Arlington",     stage:.roundOf16),
        Match(id:mID(94),  homeTeam:"V.M81", awayTeam:"V.M82", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:7,month:7,year:2026,hour:0,minute:0),
              venue:"Lumen Field",            city:"Seattle",       stage:.roundOf16),
        Match(id:mID(95),  homeTeam:"V.M86", awayTeam:"V.M88", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:7,month:7,year:2026,hour:18,minute:0),
              venue:"Mercedes-Benz Stadium",  city:"Atlanta",       stage:.roundOf16),
        Match(id:mID(96),  homeTeam:"V.M85", awayTeam:"V.M87", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:7,month:7,year:2026,hour:21,minute:0),
              venue:"BC Place",               city:"Vancouver",     stage:.roundOf16),

        // ── QUARTS DE FINALE ──
        Match(id:mID(97),  homeTeam:"V.M89", awayTeam:"V.M90", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:9,month:7,year:2026,hour:22,minute:0),
              venue:"Gillette Stadium",       city:"Foxborough",    stage:.quarterFinal),
        Match(id:mID(98),  homeTeam:"V.M93", awayTeam:"V.M94", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:10,month:7,year:2026,hour:21,minute:0),
              venue:"SoFi Stadium",           city:"Inglewood",     stage:.quarterFinal),
        Match(id:mID(99),  homeTeam:"V.M91", awayTeam:"V.M92", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:11,month:7,year:2026,hour:23,minute:0),
              venue:"Hard Rock Stadium",      city:"Miami Gardens", stage:.quarterFinal),
        Match(id:mID(100), homeTeam:"V.M95", awayTeam:"V.M96", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:12,month:7,year:2026,hour:2,minute:0),
              venue:"Arrowhead Stadium",      city:"Kansas City",   stage:.quarterFinal),

        // ── DEMI-FINALES ──
        Match(id:mID(101), homeTeam:"V.M97",  awayTeam:"V.M98",  homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:14,month:7,year:2026,hour:21,minute:0),
              venue:"AT&T Stadium",           city:"Arlington",     stage:.semiFinal),
        Match(id:mID(102), homeTeam:"V.M99",  awayTeam:"V.M100", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:15,month:7,year:2026,hour:21,minute:0),
              venue:"Mercedes-Benz Stadium",  city:"Atlanta",       stage:.semiFinal),

        // ── 3E PLACE ──
        Match(id:mID(103), homeTeam:"P.M101", awayTeam:"P.M102", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:18,month:7,year:2026,hour:23,minute:0),
              venue:"Hard Rock Stadium",      city:"Miami Gardens", stage:.thirdPlace),

        // ── FINALE ──
        Match(id:mID(104), homeTeam:"V.M101", awayTeam:"V.M102", homeFlag:"🏳️",awayFlag:"🏳️",
              date:parisDate(day:19,month:7,year:2026,hour:21,minute:0),
              venue:"MetLife Stadium",        city:"East Rutherford",stage:.final_),
    ]
}
