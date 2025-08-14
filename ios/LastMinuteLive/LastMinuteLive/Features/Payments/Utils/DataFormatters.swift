import Foundation

// MARK: - Data Formatting Utilities
struct DataFormatters {
    
    // MARK: - Seat Formatting
    
    /// Convert seat IDs to human-readable seat numbers
    /// Input: ["uuid-1", "uuid-2"] (from selectedSeats)
    /// Output: "A12, A13" or "Row A: 12-13"
    static func formatSeatNumbers(seatIds: [String], seatNodes: [SeatNode]? = nil) -> String {
        // If we have seat nodes with row/number info, use that
        if let nodes = seatNodes, !nodes.isEmpty {
            let formattedSeats = nodes.compactMap { seat -> String? in
                // Look for row and number in seat data
                if let row = extractRow(from: seat),
                   let number = extractNumber(from: seat) {
                    return "\(row)\(number)"
                }
                return nil
            }
            
            if !formattedSeats.isEmpty {
                return formatSeatList(formattedSeats)
            }
        }
        
        // Fallback: try to extract from seat IDs or use count
        if seatIds.count <= 5 {
            let readable = seatIds.compactMap { seatId -> String? in
                return extractReadableFromId(seatId)
            }
            
            if !readable.isEmpty {
                return readable.joined(separator: ", ")
            }
        }
        
        // Final fallback: just show count
        return "\(seatIds.count) seat\(seatIds.count == 1 ? "" : "s")"
    }
    
    // MARK: - Date/Time Formatting
    
    /// Format performance date/time to clean format
    /// Input: "2025-09-15T19:30:00Z" or "September 15, 2025 at 7:30 PM"
    /// Output: "Sept 15 • 19:30"
    static func formatPerformanceDateTime(_ dateString: String) -> String {
        // Try ISO8601 format first
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return formatDateToCleanString(date)
        }
        
        // Try various other formats
        let formatters = [
            createFormatter(format: "yyyy-MM-dd'T'HH:mm:ss"),
            createFormatter(format: "MMMM dd, yyyy 'at' h:mm a"),
            createFormatter(format: "yyyy-MM-dd HH:mm:ss")
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return formatDateToCleanString(date)
            }
        }
        
        // Fallback: try to extract readable parts
        return extractCleanDateFromString(dateString)
    }
    
    // MARK: - Order Reference Formatting
    
    /// Format full order ID to shortened reference
    /// Input: "b55c7a7f-c552-4ce0-aba0-e4f4a7414e65"
    /// Output: "B55C7A...4E65"
    static func formatOrderReference(_ fullId: String) -> String {
        let cleaned = fullId.replacingOccurrences(of: "-", with: "").uppercased()
        
        if cleaned.count > 12 {
            let prefix = String(cleaned.prefix(6))
            let suffix = String(cleaned.suffix(4))
            return "\(prefix)...\(suffix)"
        }
        
        return cleaned
    }
    
    // MARK: - Private Helper Methods
    
    private static func extractRow(from seat: SeatNode) -> String? {
        // Use the row property directly
        if let row = seat.row, !row.isEmpty {
            return row
        }
        
        // Fallback: try to parse from seat ID
        let components = seat.id.components(separatedBy: "_")
        if components.count >= 2 {
            return components[1] // Assuming format like "section_A_12"
        }
        
        return nil
    }
    
    private static func extractNumber(from seat: SeatNode) -> String? {
        // Use the number property directly
        if let number = seat.number, !number.isEmpty {
            return number
        }
        
        // Fallback: try to parse from seat ID
        let components = seat.id.components(separatedBy: "_")
        if components.count >= 3 {
            return components[2] // Assuming format like "section_A_12"
        }
        
        return nil
    }
    
    private static func extractReadableFromId(_ seatId: String) -> String? {
        // Try to extract readable format from UUID or other ID formats
        // This is a fallback when we don't have seat node data
        
        // If it looks like "seat_123" format
        if seatId.hasPrefix("seat_") {
            let number = String(seatId.dropFirst(5))
            return "S\(number)" // Convert "seat_123" to "S123"
        }
        
        // If it's a UUID, we can't extract readable info
        if seatId.count == 36 && seatId.contains("-") {
            return nil
        }
        
        return seatId // Use as-is if it's already readable
    }
    
    private static func formatSeatList(_ seats: [String]) -> String {
        if seats.count <= 3 {
            return seats.joined(separator: ", ")
        }
        
        // Try to group consecutive seats
        let grouped = groupConsecutiveSeats(seats)
        if grouped.count < seats.count {
            return grouped.joined(separator: ", ")
        }
        
        // If no grouping benefit, show first few + count
        return "\(seats.prefix(2).joined(separator: ", ")) +\(seats.count - 2) more"
    }
    
    private static func groupConsecutiveSeats(_ seats: [String]) -> [String] {
        // Group consecutive seats like ["A12", "A13", "A14"] -> ["A12-14"]
        var grouped: [String] = []
        
        let sortedSeats = seats.sorted()
        var currentGroup: [String] = []
        var currentRow: String?
        
        for seat in sortedSeats {
            let row = String(seat.prefix(1))
            let numberStr = String(seat.dropFirst())
            
            if let number = Int(numberStr) {
                if currentRow == row && !currentGroup.isEmpty {
                    // Check if this is consecutive
                    let lastSeat = currentGroup.last!
                    let lastNumber = Int(String(lastSeat.dropFirst()))!
                    
                    if number == lastNumber + 1 {
                        currentGroup.append(seat)
                    } else {
                        // End current group, start new one
                        grouped.append(formatGroup(currentGroup))
                        currentGroup = [seat]
                    }
                } else {
                    // Start new group
                    if !currentGroup.isEmpty {
                        grouped.append(formatGroup(currentGroup))
                    }
                    currentGroup = [seat]
                    currentRow = row
                }
            } else {
                // Non-numeric seat, treat individually
                if !currentGroup.isEmpty {
                    grouped.append(formatGroup(currentGroup))
                    currentGroup = []
                }
                grouped.append(seat)
            }
        }
        
        if !currentGroup.isEmpty {
            grouped.append(formatGroup(currentGroup))
        }
        
        return grouped
    }
    
    private static func formatGroup(_ group: [String]) -> String {
        if group.count == 1 {
            return group[0]
        } else if group.count <= 3 {
            return group.joined(separator: ", ")
        } else {
            let row = String(group[0].prefix(1))
            let firstNum = String(group[0].dropFirst())
            let lastNum = String(group.last!.dropFirst())
            return "\(row)\(firstNum)-\(lastNum)"
        }
    }
    
    private static func formatDateToCleanString(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd"
        let dateStr = dateFormatter.string(from: date)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: date)
        
        return "\(dateStr) • \(timeStr)"
    }
    
    private static func createFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    private static func extractCleanDateFromString(_ dateString: String) -> String {
        // Fallback parsing for various string formats
        if dateString.contains("September") || dateString.contains("Sept") {
            // Try to extract month, day, and time
            let components = dateString.components(separatedBy: .whitespacesAndNewlines)
            var month = ""
            var day = ""
            var time = ""
            
            for component in components {
                if component.contains("Sept") || component.contains("September") {
                    month = "Sept"
                } else if component.contains(",") && component.count <= 4 {
                    day = component.replacingOccurrences(of: ",", with: "")
                } else if component.contains(":") {
                    time = convertTo24Hour(component)
                }
            }
            
            if !month.isEmpty && !day.isEmpty && !time.isEmpty {
                return "\(month) \(day) • \(time)"
            }
        }
        
        return dateString // Return as-is if we can't parse it
    }
    
    private static func convertTo24Hour(_ timeStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        if let time = formatter.date(from: timeStr) {
            let output = DateFormatter()
            output.dateFormat = "HH:mm"
            return output.string(from: time)
        }
        
        return timeStr
    }
}

// MARK: - SeatNode Extension (if needed)
extension DataFormatters {
    /// Helper to extract seat display info from SeatNode
    static func getSeatDisplayText(from seatNode: SeatNode) -> String? {
        if let row = extractRow(from: seatNode),
           let number = extractNumber(from: seatNode) {
            return "\(row)\(number)"
        }
        // Fallback to ID if row/number not available
        return seatNode.id
    }
}
