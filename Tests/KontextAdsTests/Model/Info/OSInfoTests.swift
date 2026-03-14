import Testing
@testable import KontextSwiftSDK

struct OSInfoTests {
    @Test
    func bcp47LocaleConvertsUnderscoreToHyphen() {
        #expect(OSInfo.bcp47Locale("cs_CZ") == "cs-CZ")
        #expect(OSInfo.bcp47Locale("en_US") == "en-US")
        #expect(OSInfo.bcp47Locale("zh_Hans_CN") == "zh-Hans-CN")
    }

    @Test
    func bcp47LocaleLeavesBcp47FormatUnchanged() {
        #expect(OSInfo.bcp47Locale("cs-CZ") == "cs-CZ")
        #expect(OSInfo.bcp47Locale("en-US") == "en-US")
    }

    @Test
    func bcp47LocaleLeavesSimpleLocaleUnchanged() {
        #expect(OSInfo.bcp47Locale("en") == "en")
    }
}
