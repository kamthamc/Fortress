import SwiftUI

public struct CardView: View {
    let cardholderName: String
    let cardNumber: String
    let expirationDate: String
    let cvv: String
    let cardPin: String
    
    @State private var isRevealed = false
    
    public init(cardholderName: String, cardNumber: String, expirationDate: String, cvv: String, cardPin: String) {
        self.cardholderName = cardholderName
        self.cardNumber = cardNumber
        self.expirationDate = expirationDate
        self.cvv = cvv
        self.cardPin = cardPin
    }
    
    private var formattedCardNumber: String {
        let clean = cardNumber.replacingOccurrences(of: " ", with: "")
        if !isRevealed {
            let masked = String(repeating: "•••• ", count: 3)
            let lastDigits = clean.suffix(4)
            return masked + (lastDigits.isEmpty ? "••••" : lastDigits)
        }
        
        // Group by 4
        var result = ""
        for (idx, char) in clean.enumerated() {
            if idx > 0 && idx % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result.isEmpty ? "•••• •••• •••• ••••" : result
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Chip & Visibility Toggle
            HStack {
                // Simulating a smart card chip
                VStack(alignment: .leading, spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                        )
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRevealed.toggle()
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 16))
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Card Number
            Text(formattedCardNumber)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .tracking(1.5)
                .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer: Cardholder details, Exp & CVV/PIN
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CARDHOLDER")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1.0)
                    Text(cardholderName.isEmpty ? "FULL NAME" : cardholderName.uppercased())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXPIRES")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1.0)
                        Text(expirationDate.isEmpty ? "MM/YY" : expirationDate)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVV")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1.0)
                        Text(isRevealed ? (cvv.isEmpty ? "•••" : cvv) : "•••")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    if !cardPin.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PIN")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(1.0)
                            Text(isRevealed ? cardPin : "••••")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: 380, minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.15, blue: 0.3), Color(red: 0.05, green: 0.05, blue: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}
