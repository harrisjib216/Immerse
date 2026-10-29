/// Someone in the feed. Every language has the same eight lives, lived by people with local names in local cities,
/// so a nurse on night shifts in Osaka and one in Valencia post about the same kinds of things.
public struct Persona: Identifiable, Hashable, Sendable {
    /// The same in every language, such as `nurse`.
    public let id: String
    public let name: String
    public let handle: String
    public let city: String
    public let age: Int
    /// An SF Symbol for the avatar.
    public let symbol: String
    /// The avatar's hue, from 0 to 1.
    public let hue: Double
    let isWoman: Bool
    let life: String
}

public enum Cast {
    /// The people who post in `language`, in a fixed order.
    public static func people(in language: LearningLanguage) -> [Persona] {
        let locals = residents[language.id] ?? []
        return zip(lives, locals).map { life, local in
            Persona(
                id: life.id, name: local.name, handle: local.handle, city: local.city, age: life.age,
                symbol: life.symbol, hue: life.hue, isWoman: life.isWoman, life: life.text
            )
        }
    }

    public static func person(_ id: String, in language: LearningLanguage) -> Persona? {
        people(in: language).first { $0.id == id }
    }

    private struct Life {
        let id: String
        let age: Int
        let isWoman: Bool
        let symbol: String
        let hue: Double
        let text: String
    }

    // Written in the second person so the prompts never need a pronoun. The model still needs to know who's a woman,
    // since French, Spanish, Italian and Portuguese agree adjectives and participles with the speaker.
    private static let lives: [Life] = [
        Life(id: "nurse", age: 34, isWoman: false, symbol: "cross.case.fill", hue: 0.58, text: """
            You work night shifts as a nurse at a hospital. You sleep during the day, see the city at odd hours, \
            love late-night food and joke about how much coffee you drink.
            """),
        Life(id: "courier", age: 26, isWoman: true, symbol: "bicycle", hue: 0.07, text: """
            You are a bike courier. You ride in every kind of weather, know every shortcut and every café, and have \
            strong opinions about traffic.
            """),
        Life(id: "gardener", age: 68, isWoman: false, symbol: "leaf.fill", hue: 0.33, text: """
            You are a retired school teacher with a small garden. You write about your plants, the weather, your \
            neighbours and your grandchildren, a little old-fashioned and very kind.
            """),
        Life(id: "student", age: 20, isWoman: true, symbol: "pencil.and.ruler.fill", hue: 0.74, text: """
            You study architecture at university. You are always short on money and sleep, share a flat with two \
            friends, and know every cheap place to eat.
            """),
        Life(id: "baker", age: 45, isWoman: false, symbol: "birthday.cake.fill", hue: 0.11, text: """
            You are a baker and start work at four in the morning. You are proud of your bread, talk about your \
            regular customers, and are tired but cheerful.
            """),
        Life(id: "runner", age: 31, isWoman: true, symbol: "figure.run", hue: 0.96, text: """
            You work in an office and are training for your first marathon. You post about your runs, sore legs, \
            early mornings and small wins.
            """),
        Life(id: "parent", age: 36, isWoman: false, symbol: "stroller.fill", hue: 0.49, text: """
            You are a new father with a six-month-old baby. You get little sleep, share funny baby moments and are \
            learning to cook simple meals.
            """),
        Life(id: "musician", age: 28, isWoman: true, symbol: "guitars.fill", hue: 0.85, text: """
            You work in a record shop and play bass in a band on weekends. You recommend songs and talk about gigs, \
            rehearsals and your bandmates.
            """),
    ]

    private typealias Local = (name: String, handle: String, city: String)

    // In the order of `lives`.
    private static let residents: [String: [Local]] = [
        "es": [
            ("Javier", "javier.valencia", "Valencia"), ("Lucía", "lucia.madrid", "Madrid"),
            ("Antonio", "antonio.granada", "Granada"), ("Paula", "paula.salamanca", "Salamanca"),
            ("Diego", "diego.bilbao", "Bilbao"), ("Marta", "marta.bcn", "Barcelona"),
            ("Pablo", "pablo.sevilla", "Sevilla"), ("Irene", "irene.zaragoza", "Zaragoza"),
        ],
        "fr": [
            ("Julien", "julien.marseille", "Marseille"), ("Camille", "camille.lyon", "Lyon"),
            ("Michel", "michel.tours", "Tours"), ("Léa", "lea.lille", "Lille"),
            ("Thomas", "thomas.bordeaux", "Bordeaux"), ("Chloé", "chloe.paris", "Paris"),
            ("Nicolas", "nicolas.nantes", "Nantes"), ("Manon", "manon.toulouse", "Toulouse"),
        ],
        "de": [
            ("Lukas", "lukas.koeln", "Köln"), ("Lena", "lena.berlin", "Berlin"),
            ("Jürgen", "juergen.hamburg", "Hamburg"), ("Anna", "anna.leipzig", "Leipzig"),
            ("Felix", "felix.muenchen", "München"), ("Sophie", "sophie.ffm", "Frankfurt"),
            ("Jonas", "jonas.stuttgart", "Stuttgart"), ("Marie", "marie.dresden", "Dresden"),
        ],
        "it": [
            ("Marco", "marco.napoli", "Napoli"), ("Giulia", "giulia.milano", "Milano"),
            ("Giuseppe", "giuseppe.firenze", "Firenze"), ("Sofia", "sofia.bologna", "Bologna"),
            ("Luca", "luca.torino", "Torino"), ("Chiara", "chiara.roma", "Roma"),
            ("Andrea", "andrea.verona", "Verona"), ("Francesca", "francesca.palermo", "Palermo"),
        ],
        "pt-BR": [
            ("Rafael", "rafael.recife", "Recife"), ("Ana", "ana.sampa", "São Paulo"),
            ("José", "jose.curitiba", "Curitiba"), ("Beatriz", "bia.bh", "Belo Horizonte"),
            ("Lucas", "lucas.poa", "Porto Alegre"), ("Camila", "camila.rio", "Rio de Janeiro"),
            ("Gabriel", "gabriel.salvador", "Salvador"), ("Larissa", "larissa.fortaleza", "Fortaleza"),
        ],
        "ja": [
            ("悠斗", "haruto.osaka", "大阪"), ("美咲", "misaki.tokyo", "東京"),
            ("茂", "shigeru.kyoto", "京都"), ("さくら", "sakura.sendai", "仙台"),
            ("健太", "kenta.sapporo", "札幌"), ("葵", "aoi.yokohama", "横浜"),
            ("翔太", "shota.fukuoka", "福岡"), ("結衣", "yui.nagoya", "名古屋"),
        ],
        "ko": [
            ("민준", "minjun.busan", "부산"), ("서연", "seoyeon.seoul", "서울"),
            ("영수", "youngsoo.jeonju", "전주"), ("지우", "jiwoo.daejeon", "대전"),
            ("현우", "hyunwoo.daegu", "대구"), ("하은", "haeun.incheon", "인천"),
            ("도윤", "doyoon.suwon", "수원"), ("수아", "sua.gwangju", "광주"),
        ],
        "zh-Hans": [
            ("王磊", "wanglei.sh", "上海"), ("李娜", "lina.chengdu", "成都"),
            ("张建国", "zhangjianguo.hz", "杭州"), ("刘佳怡", "liujiayi.wuhan", "武汉"),
            ("陈浩", "chenhao.gz", "广州"), ("赵敏", "zhaomin.bj", "北京"),
            ("杨帆", "yangfan.nj", "南京"), ("林晓雨", "linxiaoyu.xian", "西安"),
        ],
        "nl": [
            ("Daan", "daan.rotterdam", "Rotterdam"), ("Emma", "emma.amsterdam", "Amsterdam"),
            ("Henk", "henk.groningen", "Groningen"), ("Sanne", "sanne.utrecht", "Utrecht"),
            ("Bram", "bram.eindhoven", "Eindhoven"), ("Fleur", "fleur.denhaag", "Den Haag"),
            ("Ruben", "ruben.haarlem", "Haarlem"), ("Lotte", "lotte.nijmegen", "Nijmegen"),
        ],
        "tr": [
            ("Emre", "emre.izmir", "İzmir"), ("Elif", "elif.istanbul", "İstanbul"),
            ("Mehmet", "mehmet.bursa", "Bursa"), ("Zeynep", "zeynep.ankara", "Ankara"),
            ("Burak", "burak.trabzon", "Trabzon"), ("Defne", "defne.antalya", "Antalya"),
            ("Can", "can.eskisehir", "Eskişehir"), ("Ece", "ece.gaziantep", "Gaziantep"),
        ],
        "vi": [
            ("Minh", "minh.hue", "Huế"), ("Linh", "linh.saigon", "TP. Hồ Chí Minh"),
            ("Hùng", "hung.dalat", "Đà Lạt"), ("Mai", "mai.hanoi", "Hà Nội"),
            ("Tuấn", "tuan.haiphong", "Hải Phòng"), ("Trang", "trang.danang", "Đà Nẵng"),
            ("Nam", "nam.cantho", "Cần Thơ"), ("Hương", "huong.nhatrang", "Nha Trang"),
        ],
    ]
}
