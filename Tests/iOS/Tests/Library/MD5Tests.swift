// https://github.com/onmyway133/SwiftHash/blob/master/SwiftHashTests/Tests.swift

@testable import Cache
import XCTest

class Tests: XCTestCase {
    func testHelper() {
        XCTAssertEqual(str2rstr_utf8("hello"), [104, 101, 108, 108, 111])

        let hello = str2rstr_utf8("hello")
        let world = str2rstr_utf8("world")
        let google = str2rstr_utf8("https://www.google.com")

        XCTAssertEqual(rstr2tr(hello), "hello")
        XCTAssertEqual(rstr2tr(world), "world")
        XCTAssertEqual(rstr2tr(google), "https://www.google.com")

        XCTAssertEqual(rstr2binl(hello), [1_819_043_176, 111])
        XCTAssertEqual(rstr2binl(world), [1_819_438_967, 100])
        XCTAssertEqual(rstr2binl(google), [1_886_680_168, 791_624_307, 779_581_303, 1_735_356_263, 1_663_985_004, 28015])

        XCTAssertEqual(rstr2hex(hello), "68656C6C6F")
        XCTAssertEqual(rstr2hex(world), "776F726C64")
        XCTAssertEqual(rstr2hex(google), "68747470733A2F2F7777772E676F6F676C652E636F6D")

        XCTAssertEqual(Int32(-991_732_713) << Int32(12), 901_869_568)
        XCTAssertEqual(Int32(991_732_713) << Int32(12), -901_869_568)
        XCTAssertEqual(zeroFillRightShift(-991_732_713, 32 - 12), 3150)

        XCTAssertEqual(bit_rol(1_589_092_186, 17), 1_052_032_367)
        XCTAssertEqual(bit_rol(-991_732_713, 12), 901_872_718)

        XCTAssertEqual(md5_cmn(-617_265_063, -615_378_706, -617_265_106, 0, 17, -1_473_231_341), 434_767_261)

        XCTAssertEqual(md5_ff(271_733_878, -615_343_318, -271_733_879, -1_732_584_194, 32879, 12, -389_564_586), 286_529_400)

        XCTAssertEqual(binl_md5(rstr2binl(hello), hello.count * 8), [708_854_109, 1_982_483_388, -1_851_952_711, -1_832_577_264])
        XCTAssertEqual(binl_md5(rstr2binl(world), world.count * 8), [925_923_709, -2_046_724_448, -2_113_778_857, -415_894_286])
    }

    func testMD5() {
        XCTAssertEqual(MD5("hello"),
                       "5D41402ABC4B2A76B9719D911017C592")
        XCTAssertEqual(MD5("world"),
                       "7D793037A0760186574B0282F2F435E7")
        XCTAssertEqual(MD5("https://www.google.com"),
                       "8FFDEFBDEC956B595D257F0AAEEFD623")
        XCTAssertEqual(MD5("https://www.google.com/logos/doodles/2016/parents-day-in-korea-5757703554072576-hp2x.jpg"),
                       "0DFB10E8D2AE771B3B3ED4544139644E")
        XCTAssertEqual(MD5("https://unsplash.it/600/300/?image=1"),
                       "D59E956EBB1BE415970F04EC77F4C875")
        XCTAssertEqual(MD5(""),
                       "D41D8CD98F00B204E9800998ECF8427E")
        XCTAssertEqual(MD5("ABCDEFGHIJKLMNOPQRSTWXYZ1234567890"),
                       "B8F4F38629EC4F4A23F5DCC6086F8035")
        XCTAssertEqual(MD5("abcdefghijklmnopqrstwxyz1234567890"),
                       "B2E875F4D53CCF6CEFB5CDA3F86FC542")
        XCTAssertEqual(MD5("0123456789"),
                       "781E5E245D69B566979B86E28D23F2C7")
        XCTAssertEqual(MD5("0"),
                       "CFCD208495D565EF66E7DFF9F98764DA")
        XCTAssertEqual(MD5("https://twitter.com/_HairForceOne/status/745235759460810752"),
                       "40C2BFA3D7BFC7A453013ECD54022255")
        XCTAssertEqual(MD5("Det er et velkjent faktum at lesere distraheres av lesbart innhold på en side når man ser på dens layout. Poenget med å bruke Lorem Ipsum er at det har en mer eller mindre normal fordeling av bokstaver i ord, i motsetning til 'Innhold her, innhold her', og gir inntrykk av å være lesbar tekst. Mange webside- og sideombrekkingsprogrammer bruker nå Lorem Ipsum som sin standard for provisorisk tekst"),
                       "6B2880BCC7554CF07E72DB9C99BF3284")
        XCTAssertEqual(MD5("\\"),
                       "28D397E87306B8631F3ED80D858D35F0")
        XCTAssertEqual(MD5("http://res.cloudinary.com/demo/image/upload/w_300,h_200,c_crop/sample.jpg"),
                       "6E30D9CC4C08BE4EEA49076328D4C1F0")
        XCTAssertEqual(MD5("http://res.cloudinary.com/demo/image/upload/x_355,y_410,w_300,h_200,c_crop/brown_sheep.jpg"),
                       "019E9D72B5AF84EF114868875C1597ED")
        XCTAssertEqual(MD5("http://www.w3schools.com/tags/html_form_submit.asp?text=Hello+G%C3%BCnter"),
                       "C89A2146CD3DF34ECDA86B6E0709B3FD")
        XCTAssertEqual(MD5("!%40%23%24%25%5E%26*()%2C.%3C%3E%5C'1234567890-%3D"),
                       "09A1790760693160E74B9D6FCEC7EF64")
    }

    func testMD5_Data() {
        let data = "https://www.google.com".data(using: String.Encoding.utf8)
        XCTAssertEqual(MD5(String(data: data!, encoding: String.Encoding.utf8)!),
                       "8FFDEFBDEC956B595D257F0AAEEFD623")
    }
}
