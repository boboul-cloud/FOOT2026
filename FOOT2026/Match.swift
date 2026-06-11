// Match.swift
// FOOT2026
// Model for a World Cup 2026 match

import Foundation

// MARK: - Group Stage

enum Group: String, CaseIterable, Codable {
    case A, B, C, D, E, F, G, H, I, J, K, L
}

enum Stage: String, Codable, CaseIterable {
    case groupStage = "Phase de groupes"
    case roundOf32 = "Huitièmes de finale"
    case roundOf16 = "Quarts de finale"
    case semiFinal = "Demi-finales"
    case thirdPlace = "Match pour la 3e place"
    case final_ = "Finale"

    var localizedName: String {
        switch self {
        case .groupStage:  return Locale.current.language.languageCode?.identifier == "fr" ? "Phase de groupes" : "Group Stage"
        case .roundOf32:   return Locale.current.language.languageCode?.identifier == "fr" ? "Huitièmes de finale" : "Round of 32"
        case .roundOf16:   return Locale.current.language.languageCode?.identifier == "fr" ? "Quarts de finale" : "Quarter-finals"
        case .semiFinal:   return Locale.current.language.languageCode?.identifier == "fr" ? "Demi-finales" : "Semi-finals"
        case .thirdPlace:  return Locale.current.language.languageCode?.identifier == "fr" ? "Match 3e place" : "3rd Place Match"
        case .final_:      return Locale.current.language.languageCode?.identifier == "fr" ? "Finale" : "Final"
        }
    }
}

// MARK: - Match Model

struct Match: Identifiable, Codable {
    let id: UUID
    var homeTeam: String
    var awayTeam: String
    var homeFlag: String
    var awayFlag: String
    var date: Date           // stored as UTC, displayed in Europe/Paris
    var venue: String
    var city: String
    var stage: Stage
    var group: Group?
    var homeScore: Int?
    var awayScore: Int?

    init(
        id: UUID = UUID(),
        homeTeam: String, awayTeam: String,
        homeFlag: String, awayFlag: String,
        date: Date,
        venue: String, city: String,
        stage: Stage, group: Group? = nil,
        homeScore: Int? = nil, awayScore: Int? = nil
    ) {
        self.id = id
        self.homeTeam = homeTeam; self.awayTeam = awayTeam
        self.homeFlag = homeFlag; self.awayFlag = awayFlag
        self.date = date
        self.venue = venue; self.city = city
        self.stage = stage; self.group = group
        self.homeScore = homeScore; self.awayScore = awayScore
    }

    var hasScore: Bool { homeScore != nil && awayScore != nil }

    var scoreText: String {
        guard let h = homeScore, let a = awayScore else { return "-" }
        return "\(h) - \(a)"
    }

    // Date formatted for Paris timezone
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

// MARK: - World Cup 2026 fixture data

extension Match {

    // Helper: build a Date from day/month/year + hour:min in Paris time
    private static func parisDate(day: Int, month: Int, year: Int, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        comps.timeZone = TimeZone(identifier: "Europe/Paris")
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
    }

    // Full FIFA World Cup 2026 group stage + knockout fixtures
    // Sources: official FIFA schedule (UTC), converted to Paris (CEST = UTC+2)
    static let allMatches: [Match] = [

        // ── GROUP A ──
        Match(homeTeam: "Mexique",     awayTeam: "Équateur",     homeFlag: "🇲🇽", awayFlag: "🇪🇨", date: parisDate(day:12,month:6,year:2026,hour:22,minute:0),  venue:"SoFi Stadium",            city:"Los Angeles",     stage:.groupStage, group:.A),
        Match(homeTeam: "États-Unis",  awayTeam: "Bolivie",      homeFlag: "🇺🇸", awayFlag: "🇧🇴", date: parisDate(day:13,month:6,year:2026,hour:3,minute:0),   venue:"Rose Bowl",               city:"Los Angeles",     stage:.groupStage, group:.A),
        Match(homeTeam: "États-Unis",  awayTeam: "Équateur",     homeFlag: "🇺🇸", awayFlag: "🇪🇨", date: parisDate(day:17,month:6,year:2026,hour:22,minute:0),  venue:"AT&T Stadium",            city:"Dallas",          stage:.groupStage, group:.A),
        Match(homeTeam: "Mexique",     awayTeam: "Bolivie",      homeFlag: "🇲🇽", awayFlag: "🇧🇴", date: parisDate(day:18,month:6,year:2026,hour:1,minute:0),   venue:"Empower Field",           city:"Denver",          stage:.groupStage, group:.A),
        Match(homeTeam: "Équateur",    awayTeam: "Bolivie",      homeFlag: "🇪🇨", awayFlag: "🇧🇴", date: parisDate(day:22,month:6,year:2026,hour:1,minute:0),   venue:"Levi's Stadium",          city:"San Francisco",   stage:.groupStage, group:.A),
        Match(homeTeam: "États-Unis",  awayTeam: "Mexique",      homeFlag: "🇺🇸", awayFlag: "🇲🇽", date: parisDate(day:22,month:6,year:2026,hour:1,minute:0),   venue:"MetLife Stadium",         city:"New York",        stage:.groupStage, group:.A),

        // ── GROUP B ──
        Match(homeTeam: "Argentine",   awayTeam: "Albanie",      homeFlag: "🇦🇷", awayFlag: "🇦🇱", date: parisDate(day:13,month:6,year:2026,hour:19,minute:0),  venue:"MetLife Stadium",         city:"New York",        stage:.groupStage, group:.B),
        Match(homeTeam: "Maroc",       awayTeam: "Irak",         homeFlag: "🇲🇦", awayFlag: "🇮🇶", date: parisDate(day:14,month:6,year:2026,hour:0,minute:0),   venue:"SoFi Stadium",            city:"Los Angeles",     stage:.groupStage, group:.B),
        Match(homeTeam: "Argentine",   awayTeam: "Irak",         homeFlag: "🇦🇷", awayFlag: "🇮🇶", date: parisDate(day:18,month:6,year:2026,hour:22,minute:0),  venue:"Hard Rock Stadium",       city:"Miami",           stage:.groupStage, group:.B),
        Match(homeTeam: "Maroc",       awayTeam: "Albanie",      homeFlag: "🇲🇦", awayFlag: "🇦🇱", date: parisDate(day:19,month:6,year:2026,hour:0,minute:0),   venue:"Gillette Stadium",        city:"Boston",          stage:.groupStage, group:.B),
        Match(homeTeam: "Albanie",     awayTeam: "Irak",         homeFlag: "🇦🇱", awayFlag: "🇮🇶", date: parisDate(day:23,month:6,year:2026,hour:1,minute:0),   venue:"Lincoln Financial Field", city:"Philadelphie",    stage:.groupStage, group:.B),
        Match(homeTeam: "Argentine",   awayTeam: "Maroc",        homeFlag: "🇦🇷", awayFlag: "🇲🇦", date: parisDate(day:23,month:6,year:2026,hour:1,minute:0),   venue:"Mercedes-Benz Stadium",  city:"Atlanta",         stage:.groupStage, group:.B),

        // ── GROUP C ──
        Match(homeTeam: "Pays-Bas",    awayTeam: "Yémen",        homeFlag: "🇳🇱", awayFlag: "🇾🇪", date: parisDate(day:13,month:6,year:2026,hour:22,minute:0),  venue:"Levi's Stadium",          city:"San Francisco",   stage:.groupStage, group:.C),
        Match(homeTeam: "Tchéquie",    awayTeam: "Turquie",      homeFlag: "🇨🇿", awayFlag: "🇹🇷", date: parisDate(day:14,month:6,year:2026,hour:19,minute:0),  venue:"Empower Field",           city:"Denver",          stage:.groupStage, group:.C),
        Match(homeTeam: "Pays-Bas",    awayTeam: "Turquie",      homeFlag: "🇳🇱", awayFlag: "🇹🇷", date: parisDate(day:18,month:6,year:2026,hour:19,minute:0),  venue:"SoFi Stadium",            city:"Los Angeles",     stage:.groupStage, group:.C),
        Match(homeTeam: "Tchéquie",    awayTeam: "Yémen",        homeFlag: "🇨🇿", awayFlag: "🇾🇪", date: parisDate(day:18,month:6,year:2026,hour:22,minute:0),  venue:"AT&T Stadium",            city:"Dallas",          stage:.groupStage, group:.C),
        Match(homeTeam: "Yémen",       awayTeam: "Turquie",      homeFlag: "🇾🇪", awayFlag: "🇹🇷", date: parisDate(day:22,month:6,year:2026,hour:20,minute:0),  venue:"Rose Bowl",               city:"Los Angeles",     stage:.groupStage, group:.C),
        Match(homeTeam: "Pays-Bas",    awayTeam: "Tchéquie",     homeFlag: "🇳🇱", awayFlag: "🇨🇿", date: parisDate(day:22,month:6,year:2026,hour:20,minute:0),  venue:"MetLife Stadium",         city:"New York",        stage:.groupStage, group:.C),

        // ── GROUP D ──
        Match(homeTeam: "Brésil",      awayTeam: "Japon",        homeFlag: "🇧🇷", awayFlag: "🇯🇵", date: parisDate(day:14,month:6,year:2026,hour:22,minute:0),  venue:"Rose Bowl",               city:"Los Angeles",     stage:.groupStage, group:.D),
        Match(homeTeam: "Égypte",      awayTeam: "Malawi",       homeFlag: "🇪🇬", awayFlag: "🇲🇼", date: parisDate(day:15,month:6,year:2026,hour:1,minute:0),   venue:"Lincoln Financial Field", city:"Philadelphie",    stage:.groupStage, group:.D),
        Match(homeTeam: "Brésil",      awayTeam: "Malawi",       homeFlag: "🇧🇷", awayFlag: "🇲🇼", date: parisDate(day:19,month:6,year:2026,hour:19,minute:0),  venue:"Hard Rock Stadium",       city:"Miami",           stage:.groupStage, group:.D),
        Match(homeTeam: "Égypte",      awayTeam: "Japon",        homeFlag: "🇪🇬", awayFlag: "🇯🇵", date: parisDate(day:19,month:6,year:2026,hour:22,minute:0),  venue:"Levi's Stadium",          city:"San Francisco",   stage:.groupStage, group:.D),
        Match(homeTeam: "Japon",       awayTeam: "Malawi",       homeFlag: "🇯🇵", awayFlag: "🇲🇼", date: parisDate(day:23,month:6,year:2026,hour:20,minute:0),  venue:"Empower Field",           city:"Denver",          stage:.groupStage, group:.D),
        Match(homeTeam: "Brésil",      awayTeam: "Égypte",       homeFlag: "🇧🇷", awayFlag: "🇪🇬", date: parisDate(day:23,month:6,year:2026,hour:20,minute:0),  venue:"SoFi Stadium",            city:"Los Angeles",     stage:.groupStage, group:.D),

        // ── GROUP E ──
        Match(homeTeam: "Allemagne",   awayTeam: "Arabie Saoudite", homeFlag: "🇩🇪", awayFlag: "🇸🇦", date: parisDate(day:15,month:6,year:2026,hour:19,minute:0), venue:"MetLife Stadium",         city:"New York",        stage:.groupStage, group:.E),
        Match(homeTeam: "Espagne",     awayTeam: "Indonésie",    homeFlag: "🇪🇸", awayFlag: "🇮🇩", date: parisDate(day:15,month:6,year:2026,hour:22,minute:0),  venue:"Rose Bowl",               city:"Los Angeles",     stage:.groupStage, group:.E),
        Match(homeTeam: "Espagne",     awayTeam: "Arabie Saoudite", homeFlag: "🇪🇸", awayFlag: "🇸🇦", date: parisDate(day:20,month:6,year:2026,hour:0,minute:0), venue:"AT&T Stadium",            city:"Dallas",          stage:.groupStage, group:.E),
        Match(homeTeam: "Allemagne",   awayTeam: "Indonésie",    homeFlag: "🇩🇪", awayFlag: "🇮🇩", date: parisDate(day:20,month:6,year:2026,hour:22,minute:0),  venue:"Mercedes-Benz Stadium",  city:"Atlanta",         stage:.groupStage, group:.E),
        Match(homeTeam: "Arabie Saoudite", awayTeam: "Indonésie", homeFlag: "🇸🇦", awayFlag: "🇮🇩", date: parisDate(day:24,month:6,year:2026,hour:1,minute:0), venue:"Gillette Stadium",        city:"Boston",          stage:.groupStage, group:.E),
        Match(homeTeam: "Espagne",     awayTeam: "Allemagne",    homeFlag: "🇪🇸", awayFlag: "🇩🇪", date: parisDate(day:24,month:6,year:2026,hour:1,minute:0),   venue:"MetLife Stadium",         city:"New York",        stage:.groupStage, group:.E),

        // ── GROUP F ──
        Match(homeTeam: "France",      awayTeam: "Afrique du Sud", homeFlag: "🇫🇷", awayFlag: "🇿🇦", date: parisDate(day:16,month:6,year:2026,hour:0,minute:0),  venue:"Mercedes-Benz Stadium",  city:"Atlanta",         stage:.groupStage, group:.F),
        Match(homeTeam: "Canada",      awayTeam: "Ukraine",      homeFlag: "🇨🇦", awayFlag: "🇺🇦", date: parisDate(day:15,month:6,year:2026,hour:22,minute:0),  venue:"BC Place",                city:"Vancouver",       stage:.groupStage, group:.F),
        Match(homeTeam: "France",      awayTeam: "Ukraine",      homeFlag: "🇫🇷", awayFlag: "🇺🇦", date: parisDate(day:20,month:6,year:2026,hour:1,minute:0),   venue:"Lincoln Financial Field", city:"Philadelphie",    stage:.groupStage, group:.F),
        Match(homeTeam: "Canada",      awayTeam: "Afrique du Sud", homeFlag: "🇨🇦", awayFlag: "🇿🇦", date: parisDate(day:19,month:6,year:2026,hour:19,minute:0), venue:"BC Place",                city:"Vancouver",       stage:.groupStage, group:.F),
        Match(homeTeam: "Afrique du Sud", awayTeam: "Ukraine",   homeFlag: "🇿🇦", awayFlag: "🇺🇦", date: parisDate(day:24,month:6,year:2026,hour:22,minute:0),  venue:"Hard Rock Stadium",       city:"Miami",           stage:.groupStage, group:.F),
        Match(homeTeam: "France",      awayTeam: "Canada",       homeFlag: "🇫🇷", awayFlag: "🇨🇦", date: parisDate(day:24,month:6,year:2026,hour:22,minute:0),  venue:"Empower Field",           city:"Denver",          stage:.groupStage, group:.F),

        // ── GROUP G ──
        Match(homeTeam: "Angleterre",  awayTeam: "Panama",       homeFlag: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", awayFlag: "🇵🇦", date: parisDate(day:16,month:6,year:2026,hour:19,minute:0),  venue:"Empower Field",           city:"Denver",          stage:.groupStage, group:.G),
        Match(homeTeam: "Sénégal",     awayTeam: "Corée du Sud", homeFlag: "🇸🇳", awayFlag: "🇰🇷", date: parisDate(day:16,month:6,year:2026,hour:22,minute:0),  venue:"AT&T Stadium",            city:"Dallas",          stage:.groupStage, group:.G),
        Match(homeTeam: "Angleterre",  awayTeam: "Corée du Sud", homeFlag: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", awayFlag: "🇰🇷", date: parisDate(day:21,month:6,year:2026,hour:1,minute:0),   venue:"SoFi Stadium",            city:"Los Angeles",     stage:.groupStage, group:.G),
        Match(homeTeam: "Sénégal",     awayTeam: "Panama",       homeFlag: "🇸🇳", awayFlag: "🇵🇦", date: parisDate(day:20,month:6,year:2026,hour:22,minute:0),  venue:"Gillette Stadium",        city:"Boston",          stage:.groupStage, group:.G),
        Match(homeTeam: "Corée du Sud", awayTeam: "Panama",      homeFlag: "🇰🇷", awayFlag: "🇵🇦", date: parisDate(day:25,month:6,year:2026,hour:1,minute:0),   venue:"Lincoln Financial Field", city:"Philadelphie",    stage:.groupStage, group:.G),
        Match(homeTeam: "Angleterre",  awayTeam: "Sénégal",      homeFlag: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", awayFlag: "🇸🇳", date: parisDate(day:25,month:6,year:2026,hour:1,minute:0),   venue:"MetLife Stadium",         city:"New York",        stage:.groupStage, group:.G),

        // ── GROUP H ──
        Match(homeTeam: "Portugal",    awayTeam: "Mozambique",   homeFlag: "🇵🇹", awayFlag: "🇲🇿", date: parisDate(day:17,month:6,year:2026,hour:1,minute:0),   venue:"AT&T Stadium",            city:"Dallas",          stage:.groupStage, group:.H),
        Match(homeTeam: "Uruguay",     awayTeam: "Nigéria",      homeFlag: "🇺🇾", awayFlag: "🇳🇬", date: parisDate(day:17,month:6,year:2026,hour:19,minute:0),  venue:"Hard Rock Stadium",       city:"Miami",           stage:.groupStage, group:.H),
        Match(homeTeam: "Portugal",    awayTeam: "Nigéria",      homeFlag: "🇵🇹", awayFlag: "🇳🇬", date: parisDate(day:21,month:6,year:2026,hour:19,minute:0),  venue:"Rose Bowl",               city:"Los Angeles",     stage:.groupStage, group:.H),
        Match(homeTeam: "Uruguay",     awayTeam: "Mozambique",   homeFlag: "🇺🇾", awayFlag: "🇲🇿", date: parisDate(day:21,month:6,year:2026,hour:22,minute:0),  venue:"Mercedes-Benz Stadium",  city:"Atlanta",         stage:.groupStage, group:.H),
        Match(homeTeam: "Nigéria",     awayTeam: "Mozambique",   homeFlag: "🇳🇬", awayFlag: "🇲🇿", date: parisDate(day:25,month:6,year:2026,hour:20,minute:0),  venue:"BC Place",                city:"Vancouver",       stage:.groupStage, group:.H),
        Match(homeTeam: "Portugal",    awayTeam: "Uruguay",      homeFlag: "🇵🇹", awayFlag: "🇺🇾", date: parisDate(day:25,month:6,year:2026,hour:20,minute:0),  venue:"Empower Field",           city:"Denver",          stage:.groupStage, group:.H),

        // ── GROUP I ──
        Match(homeTeam: "Italie",      awayTeam: "Bangladesh",   homeFlag: "🇮🇹", awayFlag: "🇧🇩", date: parisDate(day:17,month:6,year:2026,hour:22,minute:0),  venue:"Levi's Stadium",          city:"San Francisco",   stage:.groupStage, group:.I),
        Match(homeTeam: "Mexique",     awayTeam: "Cameroun",     homeFlag: "🇲🇽", awayFlag: "🇨🇲", date: parisDate(day:18,month:6,year:2026,hour:3,minute:0),   venue:"Gillette Stadium",        city:"Boston",          stage:.groupStage, group:.I),
        Match(homeTeam: "Italie",      awayTeam: "Cameroun",     homeFlag: "🇮🇹", awayFlag: "🇨🇲", date: parisDate(day:22,month:6,year:2026,hour:22,minute:0),  venue:"Rose Bowl",               city:"Los Angeles",     stage:.groupStage, group:.I),
        Match(homeTeam: "Mexique",     awayTeam: "Bangladesh",   homeFlag: "🇲🇽", awayFlag: "🇧🇩", date: parisDate(day:22,month:6,year:2026,hour:19,minute:0),  venue:"Lincoln Financial Field", city:"Philadelphie",    stage:.groupStage, group:.I),
        Match(homeTeam: "Cameroun",    awayTeam: "Bangladesh",   homeFlag: "🇨🇲", awayFlag: "🇧🇩", date: parisDate(day:26,month:6,year:2026,hour:20,minute:0),  venue:"MetLife Stadium",         city:"New York",        stage:.groupStage, group:.I),
        Match(homeTeam: "Italie",      awayTeam: "Mexique",      homeFlag: "🇮🇹", awayFlag: "🇲🇽", date: parisDate(day:26,month:6,year:2026,hour:20,minute:0),  venue:"AT&T Stadium",            city:"Dallas",          stage:.groupStage, group:.I),

        // ── GROUP J ──
        Match(homeTeam: "Belgique",    awayTeam: "Congo",        homeFlag: "🇧🇪", awayFlag: "🇨🇩", date: parisDate(day:18,month:6,year:2026,hour:19,minute:0),  venue:"Hard Rock Stadium",       city:"Miami",           stage:.groupStage, group:.J),
        Match(homeTeam: "Croatie",     awayTeam: "Venezuela",    homeFlag: "🇭🇷", awayFlag: "🇻🇪", date: parisDate(day:18,month:6,year:2026,hour:22,minute:0),  venue:"SoFi Stadium",            city:"Los Angeles",     stage:.groupStage, group:.J),
        Match(homeTeam: "Belgique",    awayTeam: "Venezuela",    homeFlag: "🇧🇪", awayFlag: "🇻🇪", date: parisDate(day:23,month:6,year:2026,hour:19,minute:0),  venue:"Rose Bowl",               city:"Los Angeles",     stage:.groupStage, group:.J),
        Match(homeTeam: "Croatie",     awayTeam: "Congo",        homeFlag: "🇭🇷", awayFlag: "🇨🇩", date: parisDate(day:23,month:6,year:2026,hour:22,minute:0),  venue:"Empower Field",           city:"Denver",          stage:.groupStage, group:.J),
        Match(homeTeam: "Congo",       awayTeam: "Venezuela",    homeFlag: "🇨🇩", awayFlag: "🇻🇪", date: parisDate(day:27,month:6,year:2026,hour:20,minute:0),  venue:"Mercedes-Benz Stadium",  city:"Atlanta",         stage:.groupStage, group:.J),
        Match(homeTeam: "Belgique",    awayTeam: "Croatie",      homeFlag: "🇧🇪", awayFlag: "🇭🇷", date: parisDate(day:27,month:6,year:2026,hour:20,minute:0),  venue:"AT&T Stadium",            city:"Dallas",          stage:.groupStage, group:.J),

        // ── GROUP K ──
        Match(homeTeam: "Autriche",    awayTeam: "Chili",        homeFlag: "🇦🇹", awayFlag: "🇨🇱", date: parisDate(day:19,month:6,year:2026,hour:1,minute:0),   venue:"MetLife Stadium",         city:"New York",        stage:.groupStage, group:.K),
        Match(homeTeam: "Serbite",     awayTeam: "Philippines",  homeFlag: "🇷🇸", awayFlag: "🇵🇭", date: parisDate(day:19,month:6,year:2026,hour:0,minute:0),   venue:"Levi's Stadium",          city:"San Francisco",   stage:.groupStage, group:.K),
        Match(homeTeam: "Autriche",    awayTeam: "Philippines",  homeFlag: "🇦🇹", awayFlag: "🇵🇭", date: parisDate(day:23,month:6,year:2026,hour:22,minute:0),  venue:"Gillette Stadium",        city:"Boston",          stage:.groupStage, group:.K),
        Match(homeTeam: "Serbite",     awayTeam: "Chili",        homeFlag: "🇷🇸", awayFlag: "🇨🇱", date: parisDate(day:23,month:6,year:2026,hour:19,minute:0),  venue:"Hard Rock Stadium",       city:"Miami",           stage:.groupStage, group:.K),
        Match(homeTeam: "Chili",       awayTeam: "Philippines",  homeFlag: "🇨🇱", awayFlag: "🇵🇭", date: parisDate(day:27,month:6,year:2026,hour:1,minute:0),   venue:"SoFi Stadium",            city:"Los Angeles",     stage:.groupStage, group:.K),
        Match(homeTeam: "Autriche",    awayTeam: "Serbite",      homeFlag: "🇦🇹", awayFlag: "🇷🇸", date: parisDate(day:27,month:6,year:2026,hour:1,minute:0),   venue:"Rose Bowl",               city:"Los Angeles",     stage:.groupStage, group:.K),

        // ── GROUP L ──
        Match(homeTeam: "Côte d'Ivoire", awayTeam: "Mexique",   homeFlag: "🇨🇮", awayFlag: "🇲🇽", date: parisDate(day:20,month:6,year:2026,hour:3,minute:0),   venue:"Lincoln Financial Field", city:"Philadelphie",    stage:.groupStage, group:.L),
        Match(homeTeam: "Australie",   awayTeam: "Serbie",       homeFlag: "🇦🇺", awayFlag: "🇷🇸", date: parisDate(day:19,month:6,year:2026,hour:22,minute:0),  venue:"BC Place",                city:"Vancouver",       stage:.groupStage, group:.L),
        Match(homeTeam: "Côte d'Ivoire", awayTeam: "Serbie",    homeFlag: "🇨🇮", awayFlag: "🇷🇸", date: parisDate(day:24,month:6,year:2026,hour:19,minute:0),  venue:"Mercedes-Benz Stadium",  city:"Atlanta",         stage:.groupStage, group:.L),
        Match(homeTeam: "Australie",   awayTeam: "Mexique",      homeFlag: "🇦🇺", awayFlag: "🇲🇽", date: parisDate(day:24,month:6,year:2026,hour:3,minute:0),   venue:"Rose Bowl",               city:"Los Angeles",     stage:.groupStage, group:.L),
        Match(homeTeam: "Serbie",      awayTeam: "Mexique",      homeFlag: "🇷🇸", awayFlag: "🇲🇽", date: parisDate(day:28,month:6,year:2026,hour:20,minute:0),  venue:"Hard Rock Stadium",       city:"Miami",           stage:.groupStage, group:.L),
        Match(homeTeam: "Côte d'Ivoire", awayTeam: "Australie", homeFlag: "🇨🇮", awayFlag: "🇦🇺", date: parisDate(day:28,month:6,year:2026,hour:20,minute:0),  venue:"Gillette Stadium",        city:"Boston",          stage:.groupStage, group:.L),

        // ── ROUND OF 32 (32 matchs - placeholders avec dates officielles) ──
        Match(homeTeam: "1A",  awayTeam: "3D/E/F", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:30,month:6,year:2026,hour:19,minute:0),  venue:"MetLife Stadium",         city:"New York",        stage:.roundOf32),
        Match(homeTeam: "1C",  awayTeam: "3A/B",   homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:30,month:6,year:2026,hour:22,minute:0),  venue:"AT&T Stadium",            city:"Dallas",          stage:.roundOf32),
        Match(homeTeam: "1B",  awayTeam: "3G/H/I", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:1,month:7,year:2026,hour:1,minute:0),    venue:"Rose Bowl",               city:"Los Angeles",     stage:.roundOf32),
        Match(homeTeam: "1D",  awayTeam: "2C",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:1,month:7,year:2026,hour:19,minute:0),   venue:"Empower Field",           city:"Denver",          stage:.roundOf32),
        Match(homeTeam: "1E",  awayTeam: "3J/K/L", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:1,month:7,year:2026,hour:22,minute:0),   venue:"Levi's Stadium",          city:"San Francisco",   stage:.roundOf32),
        Match(homeTeam: "1F",  awayTeam: "2E",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:2,month:7,year:2026,hour:1,minute:0),    venue:"Hard Rock Stadium",       city:"Miami",           stage:.roundOf32),
        Match(homeTeam: "1G",  awayTeam: "2F",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:2,month:7,year:2026,hour:19,minute:0),   venue:"Gillette Stadium",        city:"Boston",          stage:.roundOf32),
        Match(homeTeam: "1H",  awayTeam: "2G",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:2,month:7,year:2026,hour:22,minute:0),   venue:"Lincoln Financial Field", city:"Philadelphie",    stage:.roundOf32),
        Match(homeTeam: "1I",  awayTeam: "2H",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:3,month:7,year:2026,hour:1,minute:0),    venue:"Mercedes-Benz Stadium",  city:"Atlanta",         stage:.roundOf32),
        Match(homeTeam: "1J",  awayTeam: "2I",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:3,month:7,year:2026,hour:19,minute:0),   venue:"BC Place",                city:"Vancouver",       stage:.roundOf32),
        Match(homeTeam: "1K",  awayTeam: "2J",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:3,month:7,year:2026,hour:22,minute:0),   venue:"SoFi Stadium",            city:"Los Angeles",     stage:.roundOf32),
        Match(homeTeam: "1L",  awayTeam: "2K",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:4,month:7,year:2026,hour:1,minute:0),    venue:"MetLife Stadium",         city:"New York",        stage:.roundOf32),
        Match(homeTeam: "2A",  awayTeam: "2B",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:4,month:7,year:2026,hour:19,minute:0),   venue:"AT&T Stadium",            city:"Dallas",          stage:.roundOf32),
        Match(homeTeam: "2D",  awayTeam: "2L",     homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:4,month:7,year:2026,hour:22,minute:0),   venue:"Hard Rock Stadium",       city:"Miami",           stage:.roundOf32),
        Match(homeTeam: "3C/D", awayTeam: "3H/I",  homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:5,month:7,year:2026,hour:1,minute:0),    venue:"Rose Bowl",               city:"Los Angeles",     stage:.roundOf32),
        Match(homeTeam: "3A/B", awayTeam: "3F/G",  homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:5,month:7,year:2026,hour:19,minute:0),   venue:"Empower Field",           city:"Denver",          stage:.roundOf32),

        // ── QUARTER-FINALS ──
        Match(homeTeam: "QF1-1", awayTeam: "QF1-2", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:10,month:7,year:2026,hour:22,minute:0), venue:"MetLife Stadium",         city:"New York",       stage:.roundOf16),
        Match(homeTeam: "QF2-1", awayTeam: "QF2-2", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:11,month:7,year:2026,hour:22,minute:0), venue:"AT&T Stadium",            city:"Dallas",         stage:.roundOf16),
        Match(homeTeam: "QF3-1", awayTeam: "QF3-2", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:12,month:7,year:2026,hour:22,minute:0), venue:"Rose Bowl",               city:"Los Angeles",    stage:.roundOf16),
        Match(homeTeam: "QF4-1", awayTeam: "QF4-2", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:13,month:7,year:2026,hour:22,minute:0), venue:"SoFi Stadium",            city:"Los Angeles",    stage:.roundOf16),

        // ── SEMI-FINALS ──
        Match(homeTeam: "SF1-1", awayTeam: "SF1-2", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:19,month:7,year:2026,hour:22,minute:0), venue:"MetLife Stadium",         city:"New York",       stage:.semiFinal),
        Match(homeTeam: "SF2-1", awayTeam: "SF2-2", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:22,month:7,year:2026,hour:22,minute:0), venue:"Rose Bowl",               city:"Los Angeles",    stage:.semiFinal),

        // ── 3RD PLACE ──
        Match(homeTeam: "3PL-1", awayTeam: "3PL-2", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:25,month:7,year:2026,hour:22,minute:0), venue:"Hard Rock Stadium",       city:"Miami",          stage:.thirdPlace),

        // ── FINAL ──
        Match(homeTeam: "FIN-1", awayTeam: "FIN-2", homeFlag: "🏳️", awayFlag: "🏳️", date: parisDate(day:19,month:7,year:2026,hour:22,minute:0), venue:"MetLife Stadium",         city:"New York",       stage:.final_),
    ]
}
