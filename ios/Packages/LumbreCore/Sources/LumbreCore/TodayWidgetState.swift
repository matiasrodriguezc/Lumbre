import Foundation

/// Qué muestra el widget de la chispa de hoy, a partir de lo que dejó la app en el App Group.
/// El widget no habla con el servidor: si la app no cargó Hoy, invita a abrirla.
public enum TodayWidgetState: Hashable, Sendable {
    /// La chispa de hoy, ya revelada.
    case spark(LumbreShared.TodaySnapshot)
    /// La chispa de hoy existe pero no se reveló: se muestran las dos neuronas y se invita a encenderla en la app.
    case pending(LumbreShared.TodaySnapshot)
    /// Ya pasó la hora de la chispa y la app todavía no la cargó.
    case ready
    /// La próxima chispa llega a esta hora.
    case waiting(Date)
    /// Sin datos (nunca se abrió la app, o se cerró la sesión).
    case empty

    public init(snapshot: LumbreShared.TodaySnapshot?, nextSparkAt: Date?, now: Date = .now, calendar: Calendar = .current) {
        if let snapshot, snapshot.isCurrent(at: now, calendar: calendar) {
            self = snapshot.isPending ? .pending(snapshot) : .spark(snapshot)
        } else if let nextSparkAt {
            self = nextSparkAt <= now ? .ready : .waiting(nextSparkAt)
        } else {
            self = .empty
        }
    }

    /// Lee el App Group.
    public static func current(now: Date = .now) -> TodayWidgetState {
        TodayWidgetState(snapshot: LumbreShared.readTodaySnapshot(), nextSparkAt: LumbreShared.nextSparkAt, now: now)
    }

    /// La chispa que abre el widget al tocarlo, si hay una de hoy.
    public var sparkID: UUID? {
        switch self {
        case .spark(let snapshot), .pending(let snapshot): snapshot.sparkID
        case .ready, .waiting, .empty: nil
        }
    }

    /// Cuándo puede cambiar lo que se muestra sin que la app escriba nada: a la hora de la chispa y a medianoche.
    public static func refreshDates(after now: Date, nextSparkAt: Date?, calendar: Calendar = .current) -> [Date] {
        var dates: [Date] = []
        if let nextSparkAt, nextSparkAt > now { dates.append(nextSparkAt) }
        if let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            dates.append(midnight)
        }
        return Array(Set(dates)).sorted()
    }
}
