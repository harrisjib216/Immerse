import Foundation
#if canImport(AppKit)
import AppKit
#endif
import Testing
@testable import ImmerseKit

@Suite struct CastTests {
    @Test(arguments: LearningLanguage.all)
    func everyLanguageHasTheWholeCast(_ language: LearningLanguage) {
        let people = Cast.people(in: language)
        #expect(people.map(\.id) == ["nurse", "courier", "gardener", "student", "baker", "runner", "parent", "musician"])
        #expect(Set(people.map(\.name)).count == people.count)
        #expect(people.allSatisfy { !$0.city.isEmpty })
    }

    @Test func handlesAreUniqueLowercaseASCII() {
        let handles = LearningLanguage.all.flatMap { Cast.people(in: $0) }.map(\.handle)
        #expect(Set(handles).count == handles.count)
        for handle in handles {
            #expect(handle.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "." || $0 == "_") }, "\(handle)")
        }
    }

    #if canImport(AppKit)
    @Test func avatarSymbolsExist() {
        for person in Cast.people(in: .spanish) {
            #expect(NSImage(systemSymbolName: person.symbol, accessibilityDescription: nil) != nil, "\(person.symbol)")
        }
    }
    #endif

    @Test func languagesNameThemselves() {
        #expect(LearningLanguage.spanish.nativeName == "Español")
        #expect(LearningLanguage.japanese.nativeName == "日本語")
        #expect(LearningLanguage.portuguese.nativeName.hasPrefix("Português"))
        #expect(LearningLanguage.german.name(in: Locale(identifier: "en")) == "German")
    }
}
