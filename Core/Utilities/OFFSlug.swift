import Foundation

func offSlug(_ s: String) -> String {
    let lowered = s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    let replaced = lowered.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
    return replaced.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

private let storeSlugOverrides: [String:String] = [
    "sainsbury's": "sainsbury-s",
    "m&s": "marks-and-spencer",
    "marks & spencer": "marks-and-spencer",
    "co-op": "the-co-operative",
    "coop": "the-co-operative"
]

func offStoreSlug(_ name: String) -> String {
    let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return storeSlugOverrides[key] ?? offSlug(key)
}
