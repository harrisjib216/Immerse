import Testing
@testable import ImmerseKit

@Suite struct LanguageTests {
    @Test(arguments: [
        (LearningLanguage.spanish, "Hoy fui al mercado con mi hermana. Compramos fruta y pan."),
        (.french, "Je suis allée au marché ce matin. Il faisait très froid."),
        (.german, "Heute war ich im Garten. Die Tomaten sind endlich rot."),
        (.japanese, "今日は朝から雨でした。パンを焼きました。"),
        (.korean, "오늘 아침에 공원에서 달렸어요. 다리가 아파요."),
        (.chinese, "我今天早上去跑步了，天气很好。"),
        (.turkish, "Bugün markete gittim ve ekmek aldım."),
        (.vietnamese, "Hôm nay trời mưa nên tôi ở nhà nấu ăn."),
    ])
    func recognizesItsOwnLanguage(_ language: LearningLanguage, _ text: String) {
        #expect(language.wrote(text))
    }

    @Test(arguments: LearningLanguage.all)
    func rejectsEnglish(_ language: LearningLanguage) {
        #expect(!language.wrote("Today I went to the market with my sister and we bought some bread."))
    }

    @Test func rejectsAPostThatEndsInATranslation() {
        let text = "Hoy fui al mercado. (Today I went to the market and bought some fruit for the whole week.)"
        #expect(!LearningLanguage.spanish.wrote(text))
    }
}
