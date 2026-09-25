import SwiftUI

struct ProfileHeaderView: View {
    let profile: StudentProfile
    let onEdit: () -> Void
    var onSettings: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(StudentOPSTheme.success)
                .frame(width: 64, height: 64)
                .overlay(Text(initials).font(DashFont.headlineSm()).foregroundColor(.white))
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName).font(DashFont.headlineSm()).foregroundColor(.white)
                Text(gradeLine).font(DashFont.bodySm()).foregroundColor(.white.opacity(0.7))
                Text(factualSummary).font(DashFont.bodySm()).foregroundColor(.white.opacity(0.7)).lineLimit(2)
                if !profile.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(profile.location, systemImage: "mappin").font(DashFont.labelMono()).foregroundColor(.white.opacity(0.6)).labelStyle(.titleAndIcon)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: onEdit) { Image(systemName: "pencil").foregroundColor(.white).frame(width: 36, height: 36).background(.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain).accessibilityLabel("Edit profile")
                if let onSettings {
                    Button(action: onSettings) { Image(systemName: "gearshape").foregroundColor(.white).frame(width: 36, height: 36).background(.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain).accessibilityLabel("Open Settings")
                }
            }
        }
        .padding(18)
        .background(Color(hex: "0F172A"))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var initials: String { String((profile.firstName.isEmpty ? "S" : profile.firstName).prefix(1)).uppercased() }
    private var displayName: String { StudentProfileSnapshot.displayName(for: profile) }
    private var gradeLine: String {
        var parts: [String] = []
        if !profile.grade.rawValue.isEmpty { parts.append(profile.grade.rawValue) }
        if !profile.schoolLevel.rawValue.isEmpty { parts.append(profile.schoolLevel.rawValue) }
        if !profile.age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append("age \(profile.age)") }
        return parts.isEmpty ? "Student" : parts.joined(separator: " · ")
    }
    private var factualSummary: String {
        StudentProfileSnapshot.factualHeadline(for: profile) ?? "Building a personalized Student OPS path"
    }
}
