import Foundation
import Testing
@testable import ArCore

@Test func signMatchesReference() {
    #expect(MideaCrypto.sign(body: #"{"reqId":"00","stamp":"20261021120000"}"#, random: "1792630000")
            == "76cb5377d27ce9ae21133feab18c7a500f2b9121a73c7b1bd557d8e40f0bc685")
}

@Test func passwordHashes() {
    #expect(MideaCrypto.encryptPassword(loginId: "login-id-test", password: "senha-de-teste")
            == "6dd7f291d67317511f9d4e2fe1bd93f01cda26acf8aa820a2eef52cad03712ec")
    #expect(MideaCrypto.encryptIAMPassword(loginId: "login-id-test", password: "senha-de-teste")
            == "818af74bc0d5b79f12f1e8f0e2546efb617d6a62f07bf9a11eee808361086185")
}

@Test func deviceIdIsDeterministic() {
    #expect(MideaCrypto.deviceId(account: "dono@example.com") == "67658409a1c26d55")
}

@Test func deriveSessionKeysDecryptsLoginResponse() throws {
    let k = try MideaCrypto.deriveSessionKeys(
        encryptedKeyHex: "9c3cbae92cde658a41a2f053cd8c2daff954fb0103abc6dbb2776efddfe43629",
        encryptedIVHex: "c34d95602a528c4968ff15e7ca105d2dbe6ccfa58d0bf985b65f045fc142e318")
    #expect(k == SessionKeys(key: Data("0123456789abcdef".utf8), iv: Data("fedcba9876543210".utf8)))
}

@Test func fixedKeyEncryptsSerial() throws {
    #expect(try MideaCrypto.encryptWithFixedKey("000000P0000000Q1ABCDEF012345")
            == "b636386b775375f7d742dde104552417095302f402fe5a90165206a3fea14115")
}

@Test func aesRoundTripAndBadHex() throws {
    let keys = SessionKeys(key: Data("0123456789abcdef".utf8), iv: Data("fedcba9876543210".utf8))
    let enc = try MideaCrypto.aesCBCEncrypt(Data("olá".utf8), key: keys.key, iv: keys.iv)
    #expect(try MideaCrypto.decryptWithSessionKeys(hex: enc.hexString, keys: keys) == "olá")
    #expect(throws: MideaCryptoError.self) { try MideaCrypto.decryptWithSessionKeys(hex: "zz", keys: keys) }
}
