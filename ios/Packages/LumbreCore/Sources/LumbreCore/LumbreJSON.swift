import Foundation

/// JSON del backend: snake_case, timestamps de Postgres (con y sin fracciones, con `T` o con espacio)
/// y días `YYYY-MM-DD` (`sparks.scheduled_for`), que se leen como el comienzo de ese día en la zona del usuario.
enum LumbreJSON {
    static func decoder(dayTimeZone: TimeZone = .current) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = date(from: text, dayTimeZone: dayTimeZone) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Fecha con un formato desconocido")
            }
            return date
        }
        return decoder
    }

    /// Para los cuerpos de las Edge Functions y la caché.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(timestamp(date))
        }
        return encoder
    }

    /// ISO 8601 en UTC con milisegundos, como lo acepta Postgres.
    static func timestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    /// Día local como lo guarda `sparks.scheduled_for`.
    static func day(_ date: Date, timeZone: TimeZone = .current) -> String {
        var style = Date.ISO8601FormatStyle().year().month().day()
        style.timeZone = timeZone
        return date.formatted(style)
    }

    static func date(from text: String, dayTimeZone: TimeZone) -> Date? {
        text.count == 10 ? parseDay(text, timeZone: dayTimeZone) : parseTimestamp(text)
    }

    /// `2026-10-09` → las 00:00 de ese día en `timeZone`.
    static func parseDay(_ text: String, timeZone: TimeZone) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// `2026-10-09T21:11:05.123456+00:00`, `2026-10-09 21:11:05+00`, `2026-10-09T21:11:05Z`…
    /// Sin zona, se toma como UTC. Las fracciones pueden tener cualquier cantidad de dígitos.
    static func parseTimestamp(_ text: String) -> Date? {
        let chars = Array(text.utf8)
        var index = 0

        func number(_ length: Int) -> Int? {
            guard index + length <= chars.count else { return nil }
            var value = 0
            for char in chars[index..<index + length] {
                guard (48...57).contains(char) else { return nil }
                value = value * 10 + Int(char - 48)
            }
            index += length
            return value
        }
        func expect(_ options: Set<UInt8>) -> Bool {
            guard index < chars.count, options.contains(chars[index]) else { return false }
            index += 1
            return true
        }

        guard let year = number(4), expect([45]), let month = number(2), expect([45]), let day = number(2),
              expect([84, 116, 32]), // T, t o espacio
              let hour = number(2), expect([58]), let minute = number(2), expect([58]), let second = number(2)
        else { return nil }

        var fraction = 0.0
        if index < chars.count, chars[index] == 46 { // .
            index += 1
            var scale = 0.1
            while index < chars.count, (48...57).contains(chars[index]) {
                fraction += Double(chars[index] - 48) * scale
                scale /= 10
                index += 1
            }
        }

        var offset = 0
        if index < chars.count {
            switch chars[index] {
            case 90, 122: // Z
                index += 1
            case 43, 45: // + o -
                let sign = chars[index] == 45 ? -1 : 1
                index += 1
                guard let hours = number(2) else { return nil }
                var minutes = 0
                if index < chars.count {
                    _ = expect([58])
                    guard let value = number(2) else { return nil }
                    minutes = value
                }
                offset = sign * (hours * 3600 + minutes * 60)
            default:
                return nil
            }
        }
        guard index == chars.count else { return nil }

        guard let base = utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)) else {
            return nil
        }
        return base.addingTimeInterval(fraction - Double(offset))
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
