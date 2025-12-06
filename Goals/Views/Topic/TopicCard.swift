//
//  TopicCard.swift
//  GoalsV2
//
//  Created by Adolfo Gerard Montilla Gonzalez on 17-10-25.
//

import SwiftUI

struct TopicCard: View
{
    let title: String
    let value: String
    let subtitle: String?
    let isPrimary: Bool

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(isPrimary ? Color.white.opacity(0.85) : .secondary)

            Text(value)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isPrimary ? .white : .primary)

            if let subtitle
            {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(isPrimary ? Color.white.opacity(0.85) : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background
        {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(backgroundFill)
        }
        .overlay
        {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(isPrimary ? 0.18 : 0.08),
                radius: isPrimary ? 14 : 10,
                x: 0,
                y: isPrimary ? 10 : 6)
    }

    private var backgroundFill: LinearGradient
    {
        if isPrimary
        {
            return LinearGradient(
                colors: [
                    Color(red: 29/255, green: 53/255, blue: 87/255),
                    Color(red: 63/255, green: 167/255, blue: 214/255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        else
        {
            let baseColor = Color(.secondarySystemBackground)
            return LinearGradient(
                colors: [baseColor, baseColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color
    {
        if isPrimary
        {
            return Color.white.opacity(0.20)
        }
        else
        {
            return Color.white.opacity(0.05)
        }
    }
}

#Preview("Primary - Dark")
{
    TopicCard(
        title: "Today",
        value: "07h 09m",
        subtitle: "Study time today",
        isPrimary: true
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Secondary - Light")
{
    TopicCard(
        title: "Total",
        value: "32h 45m",
        subtitle: "Total time spent on this topic",
        isPrimary: false
    )
    .padding()
    .preferredColorScheme(.light)
}
