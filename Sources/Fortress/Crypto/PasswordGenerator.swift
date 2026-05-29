import Foundation

public struct PasswordGenerator {
    
    // A clean list of easy-to-type, memorable words
    private static let wordList = [
        "apple", "apricot", "banana", "beacon", "berries", "blanket", "breeze", "bucket", 
        "cabin", "camel", "candle", "canyon", "castle", "cherry", "chimney", "clover", 
        "coffee", "copper", "crater", "desert", "dolphin", "dragon", "eagle", "earth", 
        "elbow", "engine", "falcon", "forest", "fossil", "galaxy", "garden", "gecko", 
        "glacier", "guitar", "harbor", "helmet", "honey", "island", "jacket", "jungle", 
        "kettle", "koala", "lantern", "lemon", "lizard", "magnet", "maple", "meadow", 
        "melon", "meteor", "monkey", "morning", "mountain", "nebula", "necklace", "needle", 
        "ocean", "olive", "orchid", "oxygen", "palace", "pebble", "penguin", "pepper", 
        "pillow", "planet", "pocket", "puzzle", "rabbit", "radar", "rainbow", "river", 
        "saddle", "safari", "salmon", "shadow", "shield", "silver", "sketch", "spring", 
        "summit", "sunflower", "sunset", "temple", "timber", "tornado", "tunnel", "valley", 
        "velvet", "volcano", "walnut", "whisper", "willow", "winter", "wizard", "zebra",
        "actor", "anchor", "arrow", "badge", "baker", "basket", "biscuit", "bottle",
        "bridge", "brush", "butter", "camera", "canvas", "carpet", "carrot", "castle",
        "circle", "cushion", "doctor", "donkey", "drawer", "feather", "finger", "flower",
        "hammer", "hammer", "hunter", "kettle", "kitten", "lizard", "marble", "monkey",
        "napkin", "needle", "office", "oyster", "pencil", "picture", "pocket", "purple",
        "rabbit", "ribbon", "saddle", "sailor", "scissors", "shadow", "spider", "sponge",
        "square", "ticket", "turtle", "window", "yellow", "zipper"
    ]
    
    /// Generates a memorable, easy-to-type passphrase of N words separated by hyphens.
    public static func generatePassphrase(wordCount: Int = 3) -> String {
        guard wordCount > 0 else { return "" }
        var chosenWords = [String]()
        for _ in 0..<wordCount {
            if let randomWord = wordList.randomElement() {
                chosenWords.append(randomWord)
            }
        }
        return chosenWords.joined(separator: "-")
    }
    
    /// Generates a complex password based on the specified character recipe.
    public static func generateComplexPassword(
        length: Int = 16,
        includeUppercase: Bool = true,
        includeLowercase: Bool = true,
        includeDigits: Bool = true,
        includeSymbols: Bool = true
    ) -> String {
        let lowercase = "abcdefghijklmnopqrstuvwxyz"
        let uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let digits = "0123456789"
        let symbols = "!@#$%^&*()-_=+[]{}|;:,.<>?"
        
        var characterPool = ""
        var requiredChars = [Character]()
        
        if includeLowercase {
            characterPool += lowercase
            if let char = lowercase.randomElement() { requiredChars.append(char) }
        }
        if includeUppercase {
            characterPool += uppercase
            if let char = uppercase.randomElement() { requiredChars.append(char) }
        }
        if includeDigits {
            characterPool += digits
            if let char = digits.randomElement() { requiredChars.append(char) }
        }
        if includeSymbols {
            characterPool += symbols
            if let char = symbols.randomElement() { requiredChars.append(char) }
        }
        
        // Fallback in case everything is disabled
        if characterPool.isEmpty {
            characterPool = lowercase + digits
            if let char = lowercase.randomElement() { requiredChars.append(char) }
            if let char = digits.randomElement() { requiredChars.append(char) }
        }
        
        let remainingLength = max(0, length - requiredChars.count)
        var result = [Character]()
        
        // Fill remaining characters from pool
        for _ in 0..<remainingLength {
            if let char = characterPool.randomElement() {
                result.append(char)
            }
        }
        
        // Add the required characters to guarantee coverage
        result.append(contentsOf: requiredChars)
        
        // Shuffle to distribute the required characters
        result.shuffle()
        
        return String(result)
    }
    
    /// Generates a standard Apple-style strong password: 3 groups of 6 alphanumeric characters
    /// separated by hyphens (total 20 chars), avoiding ambiguous characters like 1, l, 0, O.
    public static func generateAppleStylePassword() -> String {
        let allowedChars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        func randomGroup() -> String {
            var group = ""
            for _ in 0..<6 {
                if let char = allowedChars.randomElement() {
                    group.append(char)
                }
            }
            return group
        }
        return "\(randomGroup())-\(randomGroup())-\(randomGroup())"
    }
}
