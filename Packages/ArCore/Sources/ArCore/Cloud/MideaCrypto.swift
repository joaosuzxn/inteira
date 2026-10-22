import CommonCrypto
import CryptoKit
import Foundation

/// Chave e IV de sessão (AES-128-CBC) devolvidos pelo login.
struct SessionKeys: Sendable, Equatable {
    let key: Data
    let iv: Data
}

enum MideaCryptoError: Error {
    case invalidHex
    case cryptorFailure(Int32)
    case notUTF8
}

/// Criptografia da MSmartHome, portada de `core/security.py`
/// (sususweet/midea_auto_cloud @ ce0c4b88224def0f6b53714312c19f71aa9c2a50, Apache-2.0).
enum MideaCrypto {
    /// HMAC-SHA256 hex de `iotKey + body + random`, com `hmacKey`.
    static func sign(body: String, random: String) -> String {
        let message = Data((MideaConstants.iotKey + body + random).utf8)
        let mac = HMAC<SHA256>.authenticationCode(
            for: message, using: SymmetricKey(data: Data(MideaConstants.hmacKey.utf8)))
        return Data(mac).hexString
    }

    /// SHA256(loginId + SHA256hex(password) + appKey).
    static func encryptPassword(loginId: String, password: String) -> String {
        sha256Hex(loginId + sha256Hex(password) + MideaConstants.appKey)
    }

    /// SHA256(loginId + MD5hex(MD5hex(password)) + appKey).
    static func encryptIAMPassword(loginId: String, password: String) -> String {
        let second = md5Hex(md5Hex(password))
        return sha256Hex(loginId + second + MideaConstants.appKey)
    }

    /// Primeiros 16 caracteres hex de MD5("Hello, <conta>!").
    static func deviceId(account: String) -> String {
        String(md5Hex("Hello, \(account)!").prefix(16))
    }

    static func aesCBCEncrypt(_ data: Data, key: Data, iv: Data) throws -> Data {
        try crypt(CCOperation(kCCEncrypt), data, key: key, iv: iv)
    }

    static func aesCBCDecrypt(_ data: Data, key: Data, iv: Data) throws -> Data {
        try crypt(CCOperation(kCCDecrypt), data, key: key, iv: iv)
    }

    /// Decifra chave e IV de sessão com a chave temporária derivada de SHA256hex(appKey).
    static func deriveSessionKeys(encryptedKeyHex: String, encryptedIVHex: String) throws -> SessionKeys {
        let digest = Array(sha256Hex(MideaConstants.appKey).utf8)
        let tmpKey = Data(digest[0..<16])
        let tmpIV = Data(digest[16..<32])
        guard let encKey = Data(hex: encryptedKeyHex), let encIV = Data(hex: encryptedIVHex) else {
            throw MideaCryptoError.invalidHex
        }
        return SessionKeys(
            key: try aesCBCDecrypt(encKey, key: tmpKey, iv: tmpIV),
            iv: try aesCBCDecrypt(encIV, key: tmpKey, iv: tmpIV))
    }

    /// Cifra o texto ASCII com a chave fixa; devolve hex minúsculo.
    static func encryptWithFixedKey(_ ascii: String) throws -> String {
        try aesCBCEncrypt(
            Data(ascii.utf8), key: Data(MideaConstants.fixedKey.utf8), iv: Data(MideaConstants.fixedIV.utf8)
        ).hexString
    }

    static func decryptWithSessionKeys(hex: String, keys: SessionKeys) throws -> String {
        guard let data = Data(hex: hex) else { throw MideaCryptoError.invalidHex }
        let plain = try aesCBCDecrypt(data, key: keys.key, iv: keys.iv)
        guard let text = String(data: plain, encoding: .utf8) else { throw MideaCryptoError.notUTF8 }
        return text
    }

    // MARK: - Privado

    private static func sha256Hex(_ text: String) -> String {
        Data(SHA256.hash(data: Data(text.utf8))).hexString
    }

    private static func md5Hex(_ text: String) -> String {
        Data(Insecure.MD5.hash(data: Data(text.utf8))).hexString
    }

    private static func crypt(_ operation: CCOperation, _ input: Data, key: Data, iv: Data) throws -> Data {
        // Chave e IV de sessão vêm da rede: exigir 16 bytes antes de passar ao CommonCrypto.
        guard key.count == kCCKeySizeAES128, iv.count == kCCBlockSizeAES128 else {
            throw MideaCryptoError.cryptorFailure(Int32(kCCParamError))
        }
        var output = Data(count: input.count + kCCBlockSizeAES128)
        let capacity = output.count
        var produced = 0
        let status = output.withUnsafeMutableBytes { out in
            input.withUnsafeBytes { inp in
                key.withUnsafeBytes { k in
                    iv.withUnsafeBytes { v in
                        CCCrypt(
                            operation, CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                            k.baseAddress, key.count, v.baseAddress,
                            inp.baseAddress, input.count,
                            out.baseAddress, capacity, &produced)
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw MideaCryptoError.cryptorFailure(Int32(status)) }
        output.removeSubrange(produced...)
        return output
    }
}

extension Data {
    /// Hex minúsculo.
    var hexString: String { map { String(format: "%02x", $0) }.joined() }

    /// Nil se o texto não for hex válido de tamanho par.
    init?(hex: String) {
        let chars = Array(hex.utf8)
        guard chars.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(chars.count / 2)
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let hi = Self.nibble(chars[i]), let lo = Self.nibble(chars[i + 1]) else { return nil }
            bytes.append(hi << 4 | lo)
        }
        self.init(bytes)
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 48...57: return c - 48
        case 97...102: return c - 87
        case 65...70: return c - 55
        default: return nil
        }
    }
}
