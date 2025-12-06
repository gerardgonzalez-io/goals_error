//
//  TopicListView.swift
//  GoalsV2
//
//  Created by Adolfo Gerard Montilla Gonzalez on 17-10-25.
//

import SwiftUI
import SwiftData

struct TopicListView: View
{
    @Query(sort: \Topic.name) private var topics: [Topic]
    @Environment(\.modelContext) private var context
    @State private var newTopic: Topic?

    @Bindable var timer: Timer

    var body: some View
    {
        List
        {
            ForEach(topics)
            { topic in
                NavigationLink(topic.name)
                {
                    TopicDetailView(topic: topic, timer: timer)
                }
            }
            .onDelete(perform: deteleTopic(indexes:))
        }
        .navigationTitle("Topics")
        .toolbar
        {
            ToolbarItem
            {
                Button("Add topic", systemImage: "plus", action: addTopic)
            }
            ToolbarItem(placement: .topBarTrailing)
            {
                EditButton()
            }
        }
        .sheet(item: $newTopic)
        { topic in
            NavigationStack
            {
                NewTopicView(topic: topic)
            }
            .interactiveDismissDisabled()
        }
    }
    
    private func addTopic()
    {
        let newTopic = Topic(name: "")
        context.insert(newTopic)
        self.newTopic = newTopic
    }

    private func deteleTopic(indexes: IndexSet)
    {
        for index in indexes
        {
            context.delete(topics[index])
        }
    }
}

#Preview("Dark")
{
    NavigationStack
    {
        TopicListView(timer: Timer())
            .modelContainer(SampleData.shared.modelContainer)
            .preferredColorScheme(.dark)
    }
}

#Preview("Light")
{
    NavigationStack
    {
        TopicListView(timer: Timer())
            .modelContainer(SampleData.shared.modelContainer)
            .preferredColorScheme(.light)
    }
}
