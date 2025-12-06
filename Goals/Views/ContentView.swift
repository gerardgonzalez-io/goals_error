//
//  ContentView.swift
//  GoalsV2
//
//  Created by Adolfo Gerard Montilla Gonzalez on 12-10-25.
//

import SwiftUI
import SwiftData

struct ContentView: View
{
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var timer = Timer()

    var body: some View
    {
        NavigationStack
        {
            ScrollView
            {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Summary")
                        .font(.largeTitle.bold())
                        .padding(.top, 8)

                    Text("Your only job: be a bit better than yesterday.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 16)
                    {

                        NavigationLink
                        {
                            TopicListView(timer: timer)
                        }
                        label:
                        {
                            SummaryCard(
                                title: "Topics",
                                subtitle: "Manage what you study and start focus sessions.",
                                systemImage: "list.bullet.rectangle",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink
                        {
                            StreakView()
                        }
                        label:
                        {
                            SummaryCard(
                                title: "Study goal",
                                subtitle: "Track today’s minutes and keep your streak alive.",
                                systemImage: "flame.fill",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
        }
        .onAppear
        {
            UserDefaults.standard.set(UUID().uuidString, forKey: "currentLaunchID")
        }
        .onChange(of: scenePhase)
        { oldPhase, newPhase in
            switch newPhase
            {
            case .background:
                UserDefaults.standard.set(UUID().uuidString, forKey: "lastSessionID")
                timer.saveSnapshot()
            case .active:
                let lastSessionID = UserDefaults.standard.string(forKey: "lastSessionID")
                let currentLaunchID = UserDefaults.standard.string(forKey: "currentLaunchID")
                if lastSessionID == currentLaunchID
                {
                    timer.restoreFromSnapshotAndResume()
                }
                else
                {
                    UserDefaults.standard.removeObject(forKey: "timer.snapshot.v1")
                }
            default:
                break
            }
        }
    }
}

private struct SummaryCard: View
{
    let title: String
    let subtitle: String
    let systemImage: String
    let showsChevron: Bool

    private var brandLight: Color
    {
        Color(red: 63/255, green: 167/255, blue: 214/255) // #3FA7D6
    }
    private var brandDark: Color
    {
        Color(red: 29/255, green: 53/255, blue: 87/255)   // #1D3557
    }

    var body: some View
    {
        HStack(spacing: 14)
        {
            ZStack
            {
                LinearGradient(
                    colors: [brandDark, brandLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4)
            {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if showsChevron
            {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}

#Preview
{
    ContentView()
        .modelContainer(SampleData.shared.modelContainer)
        .preferredColorScheme(.dark)
}
