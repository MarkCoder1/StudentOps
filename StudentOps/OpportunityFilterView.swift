import SwiftUI

struct OpportunityFilterView: View {
    @Binding var selectedCategory: OpportunityCategory
    let categories: [OpportunityCategory]
    let onClear: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories) { category in Text(category.rawValue).tag(category) }
                    }
                    .pickerStyle(.inline)
                }
                Section {
                    Button("Clear filters", action: onClear).foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            .navigationTitle("Filter opportunities")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
