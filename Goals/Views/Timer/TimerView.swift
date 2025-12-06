//
//  TimerView.swift
//  GoalsV2
//
//  Created by Adolfo Gerard Montilla Gonzalez on 18-10-25.
//

import SwiftUI
import SwiftData

struct TimerView: View
{
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Goal.createdAt, order: .forward) private var goals: [Goal]

    @Bindable var timer: Timer

    /// Topic que viene desde TopicDetailView
    let preselectedTopic: Topic

    @State private var selectedTopic: Topic? = nil
    @State private var sessionStartDate: Date? = nil
    @State private var didAutoConfigureFromPreselection = false

    init(timer: Timer, preselectedTopic: Topic)
    {
        self._timer = Bindable(wrappedValue: timer)
        self.preselectedTopic = preselectedTopic
    }

    var body: some View
    {
        GeometryReader { geo in
            let dialSize = min(geo.size.width, geo.size.height) * 0.82

            VStack(spacing: 28)
            {
                topicHeader

                Divider()
                    .opacity(0.15)

                Group
                {
                    let t = timer.displayTime()

                    TimerDialView(time: t)
                        .frame(width: dialSize, height: dialSize)
                        .padding(.top, 4)

                    Text(timer.formatted(t))
                        .font(.system(size: 40, weight: .medium, design: .monospaced))
                        .padding(.top, 8)
                }

                Spacer(minLength: 16)

                controlButtons
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .background(Color(.systemBackground).ignoresSafeArea())
        }
        .onAppear
        {
            guard !didAutoConfigureFromPreselection else { return }

            if selectedTopic == nil {
                selectedTopic = preselectedTopic
            }

            if !timer.isRunning && timer.elapsed == 0
            {
                createStartDateForSession()
                timer.toggle()
            }

            didAutoConfigureFromPreselection = true
        }
    }
}

private extension TimerView
{
    var topicHeader: some View
    {
        HStack(spacing: 14)
        {
            ZStack
            {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(brandGradient)

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4)
            {
                Text("Focus on")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(preselectedTopic.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)

                Text("This session will be tracked for this topic")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    var controlButtons: some View
    {
        HStack
        {
            let doneEnabled = timer.elapsed > 0 && selectedTopic != nil
            let startEnabled = selectedTopic != nil

            Button
            {
                if let topic = selectedTopic
                {
                    timer.done(for: topic)
                    createAndPersistSession(for: topic)
                    selectedTopic = nil
                    sessionStartDate = nil
                }
            }
            label:
            {
                Circle()
                    .fill(doneEnabled
                          ? AnyShapeStyle(successGradient)
                          : AnyShapeStyle(Color(.secondarySystemFill)))
                    .frame(width: 96, height: 96)
                    .shadow(color: doneEnabled ? successShadow : .clear,
                            radius: 16, x: 0, y: 8)
                    .overlay(
                        Text("Done")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(doneEnabled ? Color.white : Color.secondary)
                    )
            }
            .disabled(!doneEnabled)

            Spacer()

            Button
            {
                createStartDateForSession()
                timer.toggle()
            }
            label:
            {
                let running = timer.isRunning

                Circle()
                    .fill(
                        !startEnabled
                        ? AnyShapeStyle(Color(.secondarySystemFill))
                        : (running
                           ? AnyShapeStyle(brandGradient)
                           : AnyShapeStyle(successGradient))
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: startEnabled ? brandShadow : .clear,
                            radius: 16, x: 0, y: 8)
                    .overlay(
                        Text(running ? "Pause"
                                     : (timer.elapsed == 0 ? "Start" : "Resume"))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(startEnabled ? Color.white : Color.secondary)
                    )
            }
            .disabled(!startEnabled)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 32)
    }
}

private extension TimerView
{
    var brandGradient: LinearGradient
    {
        LinearGradient(
            colors: [
                Color(red: 63/255, green: 167/255, blue: 214/255), // #3FA7D6
                Color(red: 29/255, green: 53/255,  blue: 87/255)   // #1D3557
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var successGradient: LinearGradient
    {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.65, blue: 0.45),
                Color(red: 0.16, green: 0.80, blue: 0.60)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var brandShadow: Color
    {
        Color.black.opacity(0.25)
    }

    var successShadow: Color
    {
        Color.black.opacity(0.25)
    }
}

extension TimerView
{
    private func createStartDateForSession()
    {
        if !timer.isRunning && timer.elapsed == 0
        {
            var calendarWithTimeZone = Calendar.current
            calendarWithTimeZone.timeZone = .current
            let now = Date()
            let normalizedStart = calendarWithTimeZone.date(bySetting: .nanosecond, value: 0, of: now) ?? now
            sessionStartDate = normalizedStart
        }
    }

    private func createAndPersistSession(for topic: Topic)
    {
        guard let capturedStart = sessionStartDate
        else
        {
            return
        }

        guard let goal = goals.last
        else
        {
            return
        }

        var calendarWithTimeZone = Calendar.current
        calendarWithTimeZone.timeZone = .current

        let now = Date()
        let normalizedEnd = calendarWithTimeZone.date(bySetting: .nanosecond, value: 0, of: now) ?? now

        let session = StudySession(topic: topic,
                                   goal: goal,
                                   startDate: capturedStart,
                                   endDate: normalizedEnd)
        
        modelContext.insert(session)

        do
        {
            try modelContext.save()
        }
        catch
        {
            #if DEBUG
            print("Failed to save StudySession: \(error)")
            #endif
        }
    }
}

#Preview("Dark")
{
    TimerView(timer: Timer(), preselectedTopic: SampleData.shared.topic)
        .modelContainer(SampleData.shared.modelContainer)
        .preferredColorScheme(.dark)
}

#Preview("Light")
{
    TimerView(timer: Timer(), preselectedTopic: SampleData.shared.topic)
        .modelContainer(SampleData.shared.modelContainer)
        .preferredColorScheme(.light)
}
