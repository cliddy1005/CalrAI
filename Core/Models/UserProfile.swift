import Foundation

struct UserProfile: Codable {
    enum Sex: String, CaseIterable, Identifiable, Codable { case male, female; var id: Self { self } }
    enum Activity: String, CaseIterable, Identifiable, Codable {
        case sedentary, light, moderate, active, veryActive
        var factor: Double {
            switch self {
            case .sedentary: 1.2, .light: 1.375, .moderate: 1.55, .active: 1.725, .veryActive: 1.9
            }
        }
        var id: Self { self }
    }
    enum Goal: String, CaseIterable, Identifiable, Codable { case maintain, lose, gain; var id: Self { self } }

    var age = 30, sex = Sex.male
    var heightCm = 175, weightKg = 75
    var activity = Activity.moderate
    var goal = Goal.maintain

    func macroTargets() -> (kcal: Double, p: Double, f: Double, c: Double) {
        let w = Double(weightKg), h = Double(heightCm), a = Double(age)
        let bmr = sex == .male ? (10*w + 6.25*h - 5*a + 5) : (10*w + 6.25*h - 5*a - 161)
        var kcal = bmr * activity.factor
        if goal == .lose { kcal *= 0.85 }
        if goal == .gain { kcal *= 1.15 }
        let lb = w * 2.20462
        let pG = lb * 1.0
        let fG = lb * 0.4
        let cG = max(0, (kcal - pG*4 - fG*9) / 4)
        return (kcal.rounded(), pG.rounded(), fG.rounded(), cG.rounded())
    }
}
